/**
 * 应用主框架：2in1 侧边栏导航
 */
import { Sidebar } from '../components/Sidebar';
import { HomePage } from './home/HomePage';
import { KnowledgePage } from './knowledge/KnowledgePage';
import { PracticePage } from './practice/PracticePage';
import { WrongBookPage } from './wrongbook/WrongBookPage';
import { TrendPage } from './trend/TrendPage';
import { ReviewPage } from './review/ReviewPage';
import { SettingsPage } from './settings/SettingsPage';
import { themeOf, ThemeColors } from '../common/Theme';

/** 内容区最大宽度（vp），超宽屏时限宽居中避免过度拉伸 */
const MAX_CONTENT_W = 1280;

@Entry
@Component
struct Index {
  @State selected: number = 0;
  @State collapsed: boolean = false;
  @StorageLink('darkMode') darkMode: boolean = false;
  /** 窗口内容区宽度（vp），由根容器 onAreaChange 动态获取，用于超宽屏限宽居中 */
  @State contentW: number = MAX_CONTENT_W;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  /** 内容区实际宽度：窗口较窄时全宽，超宽时限宽居中 */
  contentWidth(): number {
    return this.contentW > MAX_CONTENT_W ? MAX_CONTENT_W : this.contentW;
  }

  build() {
    Row() {
      // 左侧导航
      Sidebar({
        selected: this.selected,
        onSelect: (i: number) => {
          this.collapsed = false;
          this.selected = i;
        },
        collapsed: this.collapsed
      })

      // 右侧内容（超宽屏限宽居中，符合 2in1 UX 规范）
      // 说明：2in1 布局引擎下 Column 子项 alignSelf 不生效，改用外层 Row justifyContent 居中
      Row() {
        Column() {
          // 顶部工具栏
          Row() {
            Text('☰')
              .fontSize(18)
              .padding(8)
              .onClick(() => {
                this.collapsed = !this.collapsed;
              })
              .margin({ right: 12 })

            Text(this.getTitle())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)

            Blank()

            Text('🔍')
              .fontSize(18)
              .padding(8)
              .onClick(() => {
                this.selected = 3;
              })
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.t().card)
          .border({ width: { bottom: 1 }, color: this.t().border })

          // 页面区
          Row() {
            Stack() {
              if (this.selected === 0) {
                HomePage({
                  onNavigate: (i: number) => {
                    this.selected = i;
                  }
                })
              } else if (this.selected === 1) {
                KnowledgePage()
              } else if (this.selected === 2) {
                PracticePage({
                  onNavigate: (i: number) => {
                    this.selected = i;
                  }
                })
              } else if (this.selected === 3) {
                WrongBookPage()
              } else if (this.selected === 4) {
                TrendPage()
              } else if (this.selected === 5) {
                ReviewPage()
              } else {
                SettingsPage()
              }
            }
            .width('100%')
            .height('100%')
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width(this.contentWidth())
        .height('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        // 取"扣除侧边栏后"的可用内容区宽度（vp）：Area.width 为 Length 类型，统一转为 number
        const w = Number(newArea.width);
        if (!isNaN(w) && Math.abs(w - this.contentW) > 1) {
          this.contentW = w;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t().bg)
  }

  getTitle(): string {
    const titles: string[] = ['首页概览', '知识点管理', '练习自测', '错题本', '趋势分析', '复习计划', '设置'];
    return titles[Math.min(this.selected, titles.length - 1)];
  }
}