/**
 * 侧边栏导航：分组式 PC 风格（学习 / 分析 / 系统）
 */
import { themeOf, ThemeColors } from '../common/Theme';

@Component
export struct Sidebar {
  @Prop selected: number = 0;
  onSelect: (index: number) => void = () => {
  };
  @Prop collapsed: boolean = false;
  @StorageLink('darkMode') darkMode: boolean = false;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  build() {
    Column() {
      // 品牌区
      Row() {
        Text(this.collapsed ? '📚' : '知踪')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.t().primary)
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.Center)

      // ---- 学习组 ----
      this.groupHeader('学习')
      this.navItem('🏠', '概览', 0)
      this.navItem('📚', '知识点', 1)
      this.navItem('✏️', '练习自测', 2)
      this.navItem('📝', '错题本', 3)

      // ---- 分析组 ----
      this.groupHeader('分析')
      this.navItem('📈', '趋势分析', 4)
      this.navItem('🔁', '复习计划', 5)

      // ---- 系统组 ----
      this.groupHeader('系统')
      this.navItem('⚙️', '设置', 6)

      Blank()

      // 底部版本
      if (!this.collapsed) {
        Column() {
          Text('v1.2.0')
            .fontSize(12)
            .fontColor(this.t().muted)
          Text('大学课程库 · 本地数据')
            .fontSize(11)
            .fontColor(this.t().muted)
            .margin({ top: 2 })
        }
        .margin({ bottom: 16 })
      }
    }
    .width(this.collapsed ? 64 : 200)
    .height('100%')
    .backgroundColor(this.t().sidebarBg)
    .border({ width: { right: 1 }, color: this.t().border })
  }

  @Builder
  groupHeader(title: string) {
    if (!this.collapsed) {
      Text(title)
        .fontSize(11)
        .fontColor(this.t().muted)
        .margin({ top: 14, bottom: 4, left: 16 })
        .alignSelf(ItemAlign.Start)
    }
  }

  @Builder
  navItem(icon: string, label: string, index: number) {
    Row() {
      Text(icon)
        .fontSize(16)
      if (!this.collapsed) {
        Text(label)
          .fontSize(14)
          .fontColor(this.selected === index ? this.t().primary : this.t().subText)
          .margin({ left: 10 })
      }
    }
    .width(this.collapsed ? 48 : '100%')
    .height(44)
    .borderRadius(8)
    .margin({ top: 2, left: 8, right: 8 })
    .justifyContent(this.collapsed ? FlexAlign.Center : FlexAlign.Start)
    .padding({ left: this.collapsed ? 0 : 16 })
    .backgroundColor(this.selected === index ? this.t().selectedBg : Color.Transparent)
    .onClick(() => {
      this.onSelect(index);
    })
  }
}