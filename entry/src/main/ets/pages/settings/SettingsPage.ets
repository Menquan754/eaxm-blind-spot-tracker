/**
 * 设置：主题切换 / 数据备份导出 / 重置预置大学课程 / 清空数据 / 关于
 */
import { getStore } from '../../database/AppDatabase';
import { getSubjects, getKps } from '../../database/AppDatabase';
import { themeOf, ThemeColors, syncThemeToDark } from '../../common/Theme';
import { getOverallStats } from '../../service/StatsService';
import { reseedNow } from '../../service/SeedService';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { OverallStat } from '../../model/Entities';

interface BackupJson {
  subjects: string[];
  knowledgePoints: string[];
  exportedAt: number;
}

@Component
export struct SettingsPage {
  /** 三态主题模式：0=跟随系统 1=浅色 2=深色（EntryAbility 已持久化） */
  @StorageLink('themeMode') themeMode: number = 0;
  /** 有效深色状态（由 EntryAbility 依据 themeMode+系统状态同步） */
  @StorageLink('darkMode') darkMode: boolean = false;
  @State stats: string = '';
  @State overall: OverallStat = new OverallStat();

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  async aboutToAppear(): Promise<void> {
    await this.refreshStats();
  }

  async refreshStats(): Promise<void> {
    try {
      const subs = await getSubjects();
      const kps = await getKps(0);
      this.overall = await getOverallStats();
      this.stats = '学科 ' + subs.length + ' 个 · 试题 ' + this.overall.questionCount + ' 道 · 知识点 ' + kps.length + ' 个';
    } catch (e) {
      console.error('settings stats load failed: ' + JSON.stringify(e));
    }
  }

  setThemeMode(mode: number): void {
    this.themeMode = mode;
    // 依据 themeMode+系统状态重算有效深色，并写回 darkMode（所有页面联动）
    syncThemeToDark();
    // 跟随系统时不强制应用颜色模式（-1=NOT_SET，由系统决定）；否则强制浅/深
    const ctx = getContext(this) as common.UIAbilityContext;
    const cm = mode === 2
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : (mode === 1 ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    ctx.getApplicationContext().setColorMode(cm);
  }

  build() {
    Column() {
      Text('⚙️ 设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 20, left: 20, bottom: 16 })

      Scroll() {
      Column() {
        Row() {
          Text(this.stats)
            .fontSize(14)
            .fontColor(this.t().subText)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.t().card)
        .borderRadius(12)

        // 学习统计总览
        Column() {
          Row() {
            Text('📊 学习统计')
              .fontSize(14)
          }
          .width('100%')
          Row() {
            StatChip({ title: '练习场次', value: this.overall.practiceCount + '' })
            StatChip({ title: '作答题目', value: this.overall.totalAnswered + '' })
            StatChip({ title: '平均正确率', value: this.overall.overallRate + '%' })
            StatChip({ title: '连续打卡', value: this.overall.streakDays + '天' })
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)

        // 外观主题
        Column() {
          Text('🌗 外观主题')
            .fontSize(14)
            .alignSelf(ItemAlign.Start)
          Text('可跟随系统深色模式，也可手动指定')
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
          Row() {
            this.themeChip(0, '跟随系统')
            this.themeChip(1, '浅色')
            this.themeChip(2, '深色')
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)

        Column() {
          Text('📦 导出备份')
            .fontSize(14)
            .alignSelf(ItemAlign.Start)
          Text('导出知识点与题目的 JSON 备份到应用沙箱')
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
          Row() {
            Text('导出')
              .fontSize(13)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.t().primary)
              .fontColor('#FFFFFF')
              .borderRadius(16)
              .onClick(() => {
                this.exportBackup();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)

        Column() {
          Text('🏫 重置预置大学课程')
            .fontSize(14)
            .alignSelf(ItemAlign.Start)
          Text('恢复 6 门预置课程与全部示例题目（现有数据将被清空）')
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
          Row() {
            Text('重置')
              .fontSize(13)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.t().warn)
              .fontColor('#FFFFFF')
              .borderRadius(16)
              .onClick(() => {
                this.resetSeed();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)

        Column() {
          Text('🗑 清空全部数据')
            .fontSize(14)
            .alignSelf(ItemAlign.Start)
          Text('删除所有练习记录、知识点与题目（不可恢复）')
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
          Row() {
            Text('清空')
              .fontSize(13)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.t().bad)
              .fontColor('#FFFFFF')
              .borderRadius(16)
              .onClick(() => {
                this.clearAll();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)

        Column() {
          Text('知踪 · v1.2')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
          Text('预置大学课程库 · 本地优先 · 数据不出设备 · 2in1 适配')
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 6 })
          Text('高等数学 · 线性代数 · 概率论 · 大学物理 · C语言 · 数据结构')
            .fontSize(11)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(24)
        .margin({ top: 16 })
        .backgroundColor(this.t().card)
        .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t().bg)
  }

  @Builder
  themeChip(mode: number, label: string) {
    Text(label)
      .fontSize(13)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.themeMode === mode ? this.t().primary : this.t().chipBg)
      .fontColor(this.themeMode === mode ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.setThemeMode(mode);
      })
  }

  /** 重置预置大学课程 */
  resetSeed(): void {
    AlertDialog.show({
      title: '重置预置课程',
      message: '将清空现有全部数据，恢复 6 门预置大学课程与示例题目，确定继续？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '重置',
        fontColor: this.t().warn,
        action: () => {
          this.doReseed();
        }
      }
    });
  }

  async doReseed(): Promise<void> {
    try {
      await reseedNow();
      await this.refreshStats();
      promptAction.showToast({ message: '已重置预置大学课程库', duration: 2000 });
    } catch (e) {
      console.error('doReseed failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '重置失败，请重试', duration: 2000 });
    }
  }

  /** 导出到应用文件目录 backup.json */
  async exportBackup(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const filePath = ctx.filesDir + '/mistake_backup.json';
      const data = await this.buildJson();
      const fd = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        fs.writeSync(fd.fd, data);
      } finally {
        fs.closeSync(fd.fd);
      }
      promptAction.showToast({ message: '已导出：' + filePath, duration: 2500 });
    } catch (e) {
      console.error('exportBackup failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '导出失败，请重试', duration: 2000 });
    }
  }

  async buildJson(): Promise<string> {
    const subs = await getSubjects();
    const kps = await getKps(0);
    const sRows: string[] = [];
    subs.forEach((s) => {
      sRows.push(s.name);
    });
    const kRows: string[] = [];
    kps.forEach((k) => {
      kRows.push(k.name);
    });
    const obj: BackupJson = {
      subjects: sRows,
      knowledgePoints: kRows,
      exportedAt: Date.now()
    };
    return JSON.stringify(obj);
  }

  clearAll(): void {
    AlertDialog.show({
      title: '清空数据',
      message: '确定删除全部数据？此操作不可恢复！',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: this.t().bad,
        action: () => {
          this.doClear();
        }
      }
    });
  }

  async doClear(): Promise<void> {
    try {
      const st = getStore();
      const tables: string[] = ['review_task', 'practice_item', 'practice', 'question_kp', 'question', 'knowledge_point', 'subject'];
      for (let i = 0; i < tables.length; i++) {
        const p = new relationalStore.RdbPredicates(tables[i]);
        await st.delete(p);
      }
      await this.refreshStats();
      promptAction.showToast({ message: '已清空全部数据' });
    } catch (e) {
      console.error('doClear failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '清空失败，请重试', duration: 2000 });
    }
  }
}

/**
 * 统计小卡：必须用 @Component + @Prop（@Builder 按值传参不会随状态刷新，
 * 会导致统计数值停留在 0）
 */
@Component
struct StatChip {
  @Prop title: string = '';
  @Prop value: string = '';
  @StorageLink('darkMode') darkMode: boolean = false;

  build() {
    Column() {
      Text(this.value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(themeOf(this.darkMode).primary)
        .margin({ top: 8 })
      Text(this.title)
        .fontSize(12)
        .fontColor(themeOf(this.darkMode).muted)
        .margin({ top: 2, bottom: 8 })
    }
    .layoutWeight(1)
    .margin({ right: 8 })
    .backgroundColor(themeOf(this.darkMode).panel)
    .borderRadius(10)
    .alignItems(HorizontalAlign.Center)
  }
}