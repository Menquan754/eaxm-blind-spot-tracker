/**
 * 首页概览：问候 + 统计卡 + 学科正确率 + 薄弱点 Top5 + 复习待办 + 热力
 */
import { getWeakStats, getDailyHeat } from '../../service/WeaknessService';
import { getDueTasks } from '../../service/ReviewService';
import { getOverallStats, getSubjectStats } from '../../service/StatsService';
import { WeakStat, ReviewTask, DailyHeat, OverallStat, SubjectStat } from '../../model/Entities';
import { themeOf, ThemeColors } from '../../common/Theme';
import { pad2 } from '../../common/Utils';

@Component
export struct HomePage {
  onNavigate: (index: number) => void = () => {
  };
  @StorageLink('darkMode') darkMode: boolean = false;
  @StorageLink('seedTick') @Watch('onSeedTick') seedTick: number = 0;
  @State weakList: WeakStat[] = [];
  @State dueTasks: ReviewTask[] = [];
  @State heat: DailyHeat[] = [];
  @State overall: OverallStat = new OverallStat();
  @State subjects: SubjectStat[] = [];
  @State refreshed: number = 0;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  /** 种子数据写入完成后自动刷新（避免首启竞态显示空数据） */
  onSeedTick(): void {
    if (this.seedTick > 0) {
      this.refresh();
    }
  }

  aboutToAppear(): void {
    this.refresh();
  }

  /** 首启 DB 未就绪时的重试计数，避免异常时无限重试 */
  retryCount: number = 0;

  async refresh(): Promise<void> {
    // 首启竞态：页面早于数据库初始化创建时 getStore() 会抛错，此时自动重试直至 DB 就绪
    try {
      this.overall = await getOverallStats();
      this.subjects = await getSubjectStats();
      this.weakList = await getWeakStats();
      this.dueTasks = await getDueTasks();
      this.heat = await getDailyHeat(0, 14);
      this.refreshed += 1;
      this.retryCount = 0;
    } catch (e) {
      console.error('home refresh failed: ' + JSON.stringify(e));
      if (this.retryCount < 20) {
        this.retryCount += 1;
        setTimeout(() => {
          this.refresh();
        }, 150);
      }
    }
  }

  greeting(): string {
    const h = new Date().getHours();
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  todayText(): string {
    const d = new Date();
    return d.getFullYear() + ' 年 ' + (d.getMonth() + 1) + ' 月 ' + d.getDate() + ' 日 星期' + this.weekText(d.getDay());
  }

  weekText(w: number): string {
    const arr: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return arr[w];
  }

  build() {
    Scroll() {
      Column() {
        // ---- 问候区 ----
        Row() {
          Column() {
            Text(this.greeting() + '，同学 👋')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Start)
            Text(this.todayText() + ' · 坚持复习，薄弱点会越来越少')
              .fontSize(13)
              .fontColor(this.t().muted)
              .margin({ top: 6 })
              .alignSelf(ItemAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          // 连续打卡徽章
          Column() {
            Text('🔥')
              .fontSize(20)
            Text(this.overall.streakDays + ' 天')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.t().warn)
              .margin({ top: 2 })
            Text('连续打卡')
              .fontSize(11)
              .fontColor(this.t().muted)
              .margin({ top: 2 })
          }
          .width(88)
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(this.t().card)
          .borderRadius(12)
          .border({ width: 1, color: this.t().border })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.t().card)
        .borderRadius(12)
        .margin({ top: 16, bottom: 16 })

        // ---- 统计卡 ----
        Row() {
          StatCard({ title: '学科', value: this.overall.subjectCount + '', color: this.t().primary })
          StatCard({ title: '试题库', value: this.overall.questionCount + '', color: this.t().chart4 })
          StatCard({ title: '练习场次', value: this.overall.practiceCount + '', color: this.t().warn })
          StatCard({ title: '总正确率', value: this.overall.overallRate + '%', color: this.t().ok })
        }
        .width('100%')
        .margin({ bottom: 16 })

        // ---- 快速开始 ----
        Row() {
          Button('✏️ 开始练习')
            .width(120)
            .backgroundColor(this.t().primary)
            .onClick(() => {
              this.onNavigate(2);
            })
          Button('📝 错题本')
            .width(120)
            .margin({ left: 10 })
            .backgroundColor(this.t().card)
            .fontColor(this.t().primary)
            .border({ width: 1, color: this.t().primary })
            .onClick(() => {
              this.onNavigate(3);
            })
          Button('🔁 复习计划')
            .width(120)
            .margin({ left: 10 })
            .backgroundColor(this.t().card)
            .fontColor(this.t().warn)
            .border({ width: 1, color: this.t().warn })
            .onClick(() => {
              this.onNavigate(5);
            })
          Button('📈 趋势分析')
            .width(120)
            .margin({ left: 10 })
            .backgroundColor(this.t().card)
            .fontColor(this.t().chart4)
            .border({ width: 1, color: this.t().chart4 })
            .onClick(() => {
              this.onNavigate(4);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ bottom: 16 })

        // ---- 双栏：薄弱点 Top5 / 复习待办 ----
        Row() {
          // 薄弱点 Top5
          Column() {
            Text('🎯 弱项主题 Top5')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })
            if (this.weakList.length === 0) {
              Text('暂无数据，快去练习吧')
                .fontSize(14)
                .fontColor(this.t().muted)
                .margin({ top: 40 })
                .alignSelf(ItemAlign.Center)
            } else {
              ForEach(this.weakList.slice(0, 5), (w: WeakStat) => {
                Row() {
                  Text(w.kpName)
                    .fontSize(14)
                    .fontColor(this.t().text)
                    .maxLines(1)
                    .width(110)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Progress({ value: w.score, total: 100, type: ProgressType.Linear })
                    .width(110)
                    .color(this.rateColor(w.score))
                    .height(6)
                  Text(w.score + '')
                    .fontSize(12)
                    .fontColor(this.t().muted)
                    .width(32)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .height(36)
              }, (w: WeakStat) => w.kpId.toString() + w.kpName)
            }
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor(this.t().card)
          .borderRadius(12)
          .margin({ right: 12 })

          // 复习待办
          Column() {
            Row() {
              Text('⏰ 今日复习待办')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text(this.dueTasks.length + ' 项')
                .fontSize(12)
                .fontColor(this.t().warn)
            }
            .width('100%')
            .margin({ bottom: 8 })

            if (this.dueTasks.length === 0) {
              Text('今日无待办，太棒了！')
                .fontSize(14)
                .fontColor(this.t().muted)
                .margin({ top: 40 })
                .alignSelf(ItemAlign.Center)
            } else {
              ForEach(this.dueTasks.slice(0, 6), (t: ReviewTask) => {
                Row() {
                  Text('🔁')
                    .fontSize(14)
                  Text(t.kpName)
                    .fontSize(14)
                    .margin({ left: 8 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Blank()
                  Text('阶段' + (t.stage + 1))
                    .fontSize(12)
                    .fontColor(this.t().primary)
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(10)
                    .backgroundColor(this.t().selectedBg)
                }
                .width('100%')
                .height(36)
              }, (t: ReviewTask) => t.id.toString() + t.kpName)
            }
          }
          .layoutWeight(1)
          .padding(16)
          .backgroundColor(this.t().card)
          .borderRadius(12)
        }
        .width('100%')
        .margin({ bottom: 16 })

        // ---- 学科正确率 ----
        Column() {
          Text('📗 学科掌握情况')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })

          if (this.subjects.length === 0) {
            Text('暂无学科数据')
              .fontSize(13)
              .fontColor(this.t().muted)
              .alignSelf(ItemAlign.Start)
          } else {
            ForEach(this.subjects, (s: SubjectStat) => {
              Row() {
                Text(s.name)
                  .fontSize(13)
                  .width(140)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Progress({ value: s.rate, total: 100, type: ProgressType.Linear })
                  .layoutWeight(1)
                  .color(this.heatColor(s.rate / 100))
                  .height(8)
                  .margin({ left: 8, right: 8 })
                Text(s.count + '次 · ' + s.rate + '%')
                  .fontSize(12)
                  .fontColor(this.t().muted)
                  .width(90)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .height(28)
            }, (s: SubjectStat) => s.subjectId.toString())
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.t().card)
        .borderRadius(12)
        .margin({ bottom: 16 })

        // ---- 近 14 天热力条 ----
        Column() {
          Text('🔥 近 14 天练习热力')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })
          Column() {
            if (this.heat.length === 0) {
              Text('暂无记录')
                .fontSize(13)
                .fontColor(this.t().muted)
                .alignSelf(ItemAlign.Center)
            } else {
              ForEach(this.heat, (h: DailyHeat) => {
                Row() {
                  Text(h.day)
                    .fontSize(12)
                    .fontColor(this.t().muted)
                    .width(52)
                  Progress({ value: this.heatValue(h), total: 1, type: ProgressType.Linear })
                    .width('100%')
                    .color(this.heatColor(h.correctRate))
                    .height(10)
                    .layoutWeight(1)
                  Text(h.practiceCount + ' 题')
                    .fontSize(12)
                    .fontColor(this.t().muted)
                    .width(48)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .height(26)
              }, (h: DailyHeat) => h.day)
            }
          }
          .padding(12)
          .backgroundColor(this.t().panel)
          .borderRadius(8)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.t().card)
        .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
    .backgroundColor(this.t().bg)
  }

  heatValue(h: DailyHeat): number {
    return h.practiceCount > 0 ? 1 : 0;
  }

  heatColor(rate: number): string {
    if (rate >= 0.8) return this.t().ok;
    if (rate >= 0.5) return this.t().warn;
    return this.t().bad;
  }

  rateColor(score: number): string {
    if (score >= 60) return this.t().bad;
    if (score >= 30) return this.t().warn;
    return this.t().ok;
  }
}

@Component
struct StatCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop color: string = '#0A59F7';
  @StorageLink('darkMode') darkMode: boolean = false;

  build() {
    Column() {
      Text(this.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
        .margin({ top: 12 })
      Text(this.title)
        .fontSize(13)
        .fontColor(themeOf(this.darkMode).muted)
        .margin({ top: 4, bottom: 12 })
    }
    .layoutWeight(1)
    .margin({ right: 10 })
    .backgroundColor(themeOf(this.darkMode).card)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }
}