/**
 * 趋势分析：总体统计 + 知识点选择 -> 正确率折线图（Canvas 自绘）+ 能力雷达图 + 反复出错主题榜
 */
import { getWeakStats, getKpTrend, getDimStats } from '../../service/WeaknessService';
import { getOverallStats } from '../../service/StatsService';
import { getKps } from '../../database/AppDatabase';
import { WeakStat, TrendPoint, KnowledgePoint, DimStat, OverallStat } from '../../model/Entities';
import { themeOf, ThemeColors } from '../../common/Theme';

@Component
export struct TrendPage {
  @StorageLink('darkMode') @Watch('onThemeChanged') darkMode: boolean = false;
  @State stats: WeakStat[] = [];
  @State kps: KnowledgePoint[] = [];
  @State selectedKp: number = 0;
  @State trend: TrendPoint[] = [];
  @State dims: DimStat[] = [];
  @State overall: OverallStat = new OverallStat();
  private chartCtrl: ChartCtrl = new ChartCtrl();
  private radarCtrl: RadarCtrl = new RadarCtrl();

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  aboutToAppear(): void {
    this.loadAll();
  }

  async loadAll(): Promise<void> {
    try {
      this.kps = await getKps(0);
    } catch (e) {
      console.error('load trend kps failed: ' + JSON.stringify(e));
      this.kps = [];
    }
    await this.refresh();
  }

  onThemeChanged(): void {
    this.chartCtrl.draw(this.trend, this.darkMode);
    this.radarCtrl.draw(this.dims, this.darkMode);
  }

  async refresh(): Promise<void> {
    try {
      this.stats = await getWeakStats();
      this.dims = await getDimStats();
    } catch (e) {
      console.error('trend weakness load failed: ' + JSON.stringify(e));
    }
    try {
      this.overall = await getOverallStats();
    } catch (e) {
      console.error('trend overall load failed: ' + JSON.stringify(e));
    }
    this.selectedKp = this.stats.length > 0 ? this.stats[0].kpId : 0;
    if (this.selectedKp > 0) {
      try {
        this.trend = await getKpTrend(this.selectedKp);
      } catch (e) {
        this.trend = [];
      }
    } else {
      this.trend = [];
    }
    setTimeout(() => {
      this.chartCtrl.draw(this.trend, this.darkMode);
      this.radarCtrl.draw(this.dims, this.darkMode);
    }, 120);
  }

  async selectKp(id: number): Promise<void> {
    this.selectedKp = id;
    this.trend = await getKpTrend(id);
    setTimeout(() => {
      this.chartCtrl.draw(this.trend, this.darkMode);
    }, 100);
  }

  kpName(id: number): string {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === id) return this.kps[i].name;
    }
    return '全部';
  }

  build() {
    Column() {
      Row() {
        Text('📈 趋势分析')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 知识点选择
      Scroll() {
        Row() {
          ForEach(this.kps, (kp: KnowledgePoint) => {
            Text(kp.name)
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ right: 8 })
              .backgroundColor(this.selectedKp === kp.id ? this.t().primary : this.t().chipBg)
              .fontColor(this.selectedKp === kp.id ? '#FFFFFF' : this.t().subText)
              .borderRadius(16)
              .onClick(() => {
                this.selectKp(kp.id);
              })
          }, (kp: KnowledgePoint) => kp.id.toString())
        }
        .padding({ left: 20, right: 20, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      // 总体统计横条
      Row() {
        MiniStat({ title: '练习场次', value: this.overall.practiceCount + '', color: this.t().chart1 })
        MiniStat({ title: '作答题目', value: this.overall.totalAnswered + '', color: this.t().chart4 })
        MiniStat({ title: '平均正确率', value: this.overall.overallRate + '%', color: this.t().chart2 })
        MiniStat({ title: '连续打卡', value: this.overall.streakDays + '天', color: this.t().chart3 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })

      Scroll() {
        Column() {
          // 折线图卡片（Canvas）
          Column() {
            Row() {
              Text(this.kpName(this.selectedKp) + ' · 正确率趋势')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
              Blank()
            }
            .width('100%')
            .margin({ bottom: 8 })

            if (this.trend.length === 0) {
              Text('暂无可绘制的练习数据，先去做几组练习吧')
                .fontSize(14)
                .fontColor(this.t().muted)
                .height(180)
                .margin({ top: 40 })
                .alignSelf(ItemAlign.Center)
            } else {
              Canvas(this.chartCtrl.ctx)
                .width('100%')
                .height(200)
                .onReady(() => {
                  this.chartCtrl.draw(this.trend, this.darkMode);
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.t().card)
          .borderRadius(12)

          // 能力雷达图
          Column() {
            Row() {
              Text('🧭 能力维度雷达')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text('得分越高越薄弱，需加强')
                .fontSize(11)
                .fontColor(this.t().muted)
            }
            .width('100%')
            .margin({ bottom: 8 })

            if (this.dims.length < 3) {
              Text('练习数据不足，至少覆盖 3 个主题后可查看雷达')
                .fontSize(14)
                .fontColor(this.t().muted)
                .height(220)
                .margin({ top: 40 })
                .alignSelf(ItemAlign.Center)
            } else {
              Canvas(this.radarCtrl.ctx)
                .width('100%')
                .height(220)
                .onReady(() => {
                  this.radarCtrl.draw(this.dims, this.darkMode);
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.t().card)
          .borderRadius(12)
          .margin({ top: 16 })

          // 反复出错主题榜
          Column() {
            Text('🔥 反复出错主题榜')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            if (this.stats.length === 0) {
              Text('暂无数据')
                .fontSize(13)
                .fontColor(this.t().muted)
            } else {
              ForEach(this.stats, (w: WeakStat, index: number) => {
                Row() {
                  Text((index + 1) + '')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(index < 3 ? this.t().bad : this.t().muted)
                    .width(28)
                  Column() {
                    Row() {
                      Text(w.kpName)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .layoutWeight(1)
                        .textAlign(TextAlign.Start)
                        .maxLines(1)
                      Text(w.score + ' 分')
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.scoreColor(w.score))
                    }
                    .width('100%')
                    Row() {
                      Text('错误率 ' + Math.round(w.errorRate * 100) + '%')
                        .fontSize(12)
                        .fontColor(this.t().muted)
                      Text('连续出错 ' + w.streak + ' 场')
                        .fontSize(12)
                        .fontColor(w.streak > 0 ? this.t().bad : this.t().muted)
                        .margin({ left: 16 })
                    }
                    .width('100%')
                    .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .margin({ top: 8 })
                .borderRadius(8)
                .backgroundColor(this.t().panel)
                .border({ width: 1, color: w.score >= 60 ? this.t().dangerBorder : this.t().border })
                .onClick(() => {
                  this.selectKp(w.kpId);
                })
              }, (w: WeakStat, index: number) => w.kpId.toString() + index.toString())
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.t().card)
          .borderRadius(12)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 20 })
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

  scoreColor(score: number): string {
    if (score >= 60) return this.t().bad;
    if (score >= 30) return this.t().warn;
    return this.t().ok;
  }

}

/**
 * 统计小卡：必须用 @Component + @Prop（@Builder 按值传参不会随状态刷新，
 * 会导致统计数值停留在 0）
 */
@Component
struct MiniStat {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop color: string = '#0A59F7';
  @StorageLink('darkMode') darkMode: boolean = false;

  build() {
    Column() {
      Text(this.value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
        .margin({ top: 10 })
      Text(this.title)
        .fontSize(12)
        .fontColor(themeOf(this.darkMode).muted)
        .margin({ top: 2, bottom: 10 })
    }
    .layoutWeight(1)
    .margin({ right: 10 })
    .backgroundColor(themeOf(this.darkMode).card)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }
}

/** 自绘折线图控制 */
class ChartCtrl {
  public settings: RenderingContextSettings = new RenderingContextSettings(true);
  public ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  draw(points: TrendPoint[], dark: boolean): void {
    const pal = themeOf(dark);
    const w = this.ctx.width > 0 ? this.ctx.width : 700;
    const h = this.ctx.height > 0 ? this.ctx.height : 190;
    const pad = 36;
    const ctx = this.ctx;
    ctx.clearRect(0, 0, w, h);
    if (points.length === 0) return;

    // 背景线
    ctx.strokeStyle = pal.border;
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = pad + (h - pad * 2) * i / 4;
      ctx.beginPath();
      ctx.moveTo(pad, y);
      ctx.lineTo(w - 10, y);
      ctx.stroke();
    }

    const n = points.length;
    const minRate = 0; // 固定 0-100%
    const x0 = pad;
    const x1 = w - 30;
    const yTop = pad;
    const yBot = h - 30;

    for (let i = 0; i < n; i++) {
      const x = n === 1 ? (x0 + x1) / 2 : x0 + (x1 - x0) * i / (n - 1);
      const y = yBot - (yBot - yTop) * clamp(points[i].rate);
      if (i === 0) {
        ctx.beginPath();
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.strokeStyle = pal.primary;
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';
    ctx.stroke();

    // 点 + 标签
    ctx.font = '11px sans-serif';
    for (let i = 0; i < n; i++) {
      const x = n === 1 ? (x0 + x1) / 2 : x0 + (x1 - x0) * i / (n - 1);
      const y = yBot - (yBot - yTop) * clamp(points[i].rate);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = pal.card;
      ctx.fill();
      ctx.strokeStyle = pal.primary;
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.fillStyle = pal.muted;
      ctx.textAlign = 'center';
      ctx.fillText(points[i].label, x, h - 12);
      ctx.fillStyle = pal.text;
      ctx.font = 'bold 11px sans-serif';
      ctx.fillText(Math.round(points[i].rate * 100) + '%', x, y - 10);
    }
  }
}

function clamp(v: number): number {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

/** 自绘雷达图控制 */
class RadarCtrl {
  public settings: RenderingContextSettings = new RenderingContextSettings(true);
  public ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  draw(dims: DimStat[], dark: boolean): void {
    const pal = themeOf(dark);
    const ctx = this.ctx;
    const w = ctx.width > 0 ? ctx.width : 700;
    const h = ctx.height > 0 ? ctx.height : 210;
    ctx.clearRect(0, 0, w, h);
    if (dims.length < 3) return;

    const n = dims.length;
    const cx = w / 2;
    const cy = h / 2 + 6;
    const R = Math.min(w / 2, h / 2) - 46;

    // 网格环
    ctx.lineWidth = 1;
    for (let ring = 1; ring <= 4; ring++) {
      const rr = R * ring / 4;
      ctx.beginPath();
      for (let i = 0; i <= n; i++) {
        const a = -Math.PI / 2 + i * 2 * Math.PI / n;
        const x = cx + Math.cos(a) * rr;
        const y = cy + Math.sin(a) * rr;
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.strokeStyle = pal.border;
      ctx.stroke();
    }

    // 轴线
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + i * 2 * Math.PI / n;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + Math.cos(a) * R, cy + Math.sin(a) * R);
      ctx.strokeStyle = pal.border;
      ctx.stroke();
    }

    // 数据多边形
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + i * 2 * Math.PI / n;
      const v = clamp(dims[i].score / 100);
      const x = cx + Math.cos(a) * R * v;
      const y = cy + Math.sin(a) * R * v;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();
    ctx.globalAlpha = 0.25;
    ctx.fillStyle = pal.primary;
    ctx.fill();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = pal.primary;
    ctx.lineWidth = 2;
    ctx.stroke();

    // 顶点
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + i * 2 * Math.PI / n;
      const v = clamp(dims[i].score / 100);
      const x = cx + Math.cos(a) * R * v;
      const y = cy + Math.sin(a) * R * v;
      ctx.beginPath();
      ctx.arc(x, y, 3.5, 0, Math.PI * 2);
      ctx.fillStyle = pal.primary;
      ctx.fill();
    }

    // 标签
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = pal.subText;
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + i * 2 * Math.PI / n;
      const lx = cx + Math.cos(a) * (R + 20);
      const ly = cy + Math.sin(a) * (R + 20);
      ctx.fillText(dims[i].name, lx, ly);
    }
  }
}