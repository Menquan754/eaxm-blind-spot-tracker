import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { initDb } from '../database/AppDatabase';
import { seedIfEmpty } from '../service/SeedService';
import { syncThemeToDark } from '../common/Theme';

const DOMAIN = 0x0000;
// PersistentStorage 为全局声明，无需 import

/** PC 2in1 窗口形态限制（vp），与 module.json5 min/maxWindowWidth/Height 保持一致 */
const MIN_W = 640;
const MIN_H = 480;
const MAX_W = 1680;
const MAX_H = 1000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 深色模式选择持久化（用户可在设置页切换）
    try {
      PersistentStorage.persistProp('darkMode', false);
      // 三态主题：0=跟随系统 1=浅色 2=深色（持久化）
      PersistentStorage.persistProp('themeMode', 0);
      // 系统当前深色状态（由 onColorModeUpdated 回调刷新）
      PersistentStorage.persistProp('sysDark', false);
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'persistProp darkMode failed: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 数据库初始化 -> 种子写入 -> 通知首页刷新 -> 加载页面。
   * 在 loadContent 之前完成，彻底消除"页面早于 DB 就绪"导致的空数据/异常竞态。
   */
  private initDbThenLoad(windowStage: window.WindowStage): void {
    const load = (): void => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    };
    initDb(this.context).then((ok: boolean) => {
      hilog.info(DOMAIN, 'testTag', 'initDb result: %{public}s', '' + ok);
      if (!ok) {
        load();
        return;
      }
      // 种子检查完成后无条件通知首页刷新（无论是否写入种子数据，避免"已有数据"时 seedTick 不增导致首页统计停留在 0）
      seedIfEmpty().then((seeded: boolean) => {
        hilog.info(DOMAIN, 'testTag', 'seed result: %{public}s', '' + seeded);
        this.notifyDbReady();
        load();
      }).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, 'testTag', 'seedIfEmpty failed: %{public}s', JSON.stringify(e));
        this.notifyDbReady();
        load();
      });
    }).catch((e: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', 'initDb threw: %{public}s', JSON.stringify(e));
      load();
    });
  }

  /** DB 就绪信号：递增 seedTick，驱动首页（@StorageLink+@Watch）刷新 */
  private notifyDbReady(): void {
    let cur = AppStorage.get<number>('seedTick');
    let v = 0;
    if (cur !== undefined && cur !== null) v = cur;
    AppStorage.setOrCreate('seedTick', v + 1);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 先完成数据库初始化与种子写入，再加载页面，彻底消除"页面早于 DB 就绪"的竞态
    this.initDbThenLoad(windowStage);

    // --- PC 2in1 窗口形态适配（符合 UX 规范） ---
    // 约束窗口尺寸范围（最小可操作性 / 最大避免超宽内容拉伸），并监听尺寸变化便于布局自适应
    try {
      const mainWinPromise = windowStage.getMainWindow();
      mainWinPromise.then((mainWindow: window.Window) => {
        const limits: window.WindowLimits = {
          minWidth: MIN_W,
          minHeight: MIN_H,
          maxWidth: MAX_W,
          maxHeight: MAX_H,
          pixelUnit: window.PixelUnit.VP
        };
        mainWindow.setWindowLimits(limits).then(() => {
          hilog.info(DOMAIN, 'testTag', '%{public}s', 'setWindowLimits ok');
        }).catch((err: BusinessError) => {
          hilog.warn(DOMAIN, 'testTag', 'setWindowLimits failed: %{public}s', JSON.stringify(err));
        });
        mainWindow.on('windowSizeChange', (size: window.Size) => {
          hilog.info(DOMAIN, 'testTag', 'windowSizeChange %{public}dx%{public}d', size.width, size.height);
        });
      }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, 'testTag', 'getMainWindow failed: %{public}s', JSON.stringify(err));
      });
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'window adapt setup failed: %{public}s', JSON.stringify(e));
    }

    try {
      // 应用默认跟随系统深色模式（不强制指定），并注册系统颜色模式变更监听
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // --- 深色模式适配（符合 UX 规范：跟随系统 + 应用内三态选择） ---
    try {
      const appCtx = this.context.getApplicationContext();
      // 首次启动：读取系统当前 colorMode 初始化 sysDark，并据此计算 darkMode
      const cfg = this.context.config;
      if (cfg.colorMode !== undefined) {
        const sysDark = cfg.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        AppStorage.setOrCreate('sysDark', sysDark);
      }
      syncThemeToDark();
      // 监听系统深色/浅色切换，实时同步主题
      appCtx.onSystemConfigurationUpdated({
        onColorModeUpdated: (mode: ConfigurationConstant.ColorMode) => {
          const sysDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
          AppStorage.setOrCreate('sysDark', sysDark);
          syncThemeToDark();
          hilog.info(DOMAIN, 'testTag', 'onColorModeUpdated sysDark=%{public}s', '' + sysDark);
        }
      });
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'dark mode subscribe failed: %{public}s', JSON.stringify(e));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}