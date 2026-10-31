/**
 * 复习计划：月度复习日历（可切月/选日）+ 自定义复习日程 + 到期任务 + 未来计划 + 练习/考试记录
 * - 日历任意日期可点击查看当日计划，并可为该日新建复习安排
 * - 支持删除计划、顺延一天、完成复习推进艾宾浩斯轮次
 * - 最近练习/考试记录可点击查看逐题解析
 */
import { getReviewTasks, getPractices, getSubjects, getKps, insertReviewTask,
  deleteReviewTask, updateReviewTaskDue, getPracticeItemsByPractice } from '../../database/AppDatabase';
import { completeReview } from '../../service/ReviewService';
import { ReviewTask, PracticeRecord, Subject, KnowledgePoint, PracticeItem } from '../../model/Entities';
import { themeOf, ThemeColors } from '../../common/Theme';
import { pad2 } from '../../common/Utils';

const WEEK_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

@Component
export struct ReviewPage {
  @StorageLink('darkMode') darkMode: boolean = false;
  @State tasks: ReviewTask[] = [];
  @State records: PracticeRecord[] = [];
  @State monthOffset: number = 0;
  /** 当前选中日期时间戳（当天 0 点），0 表示未选择 */
  @State selectedDayTs: number = 0;
  @State busyId: number = -1;
  // ---------- 新建计划弹窗 ----------
  @State showPlan: boolean = false;
  @State planSubjects: Subject[] = [];
  @State planSubject: number = 0;
  @State planKps: KnowledgePoint[] = [];
  @State planKp: number = 0;
  @State planDateTs: number = 0;
  @State planHour: number = 9;
  @State planMinute: number = 0;
  // 备注使用普通成员（非受控输入），避免每次击键触发整页重建
  planNote: string = '';
  @State saving: boolean = false;
  // ---------- 派生数据缓存：加载后一次性计算，避免 build 期间重复遍历/排序 ----------
  // 注意：需为 @State，否则异步 load 完成后界面不会刷新
  @State dueList: ReviewTask[] = [];
  @State upcomingList: ReviewTask[] = [];
  @State dayCount: Map<number, number> = new Map<number, number>();
  // ---------- 记录详情弹窗 ----------
  @State showRecord: boolean = false;
  @State recordTitle: string = '';
  @State recordSub: string = '';
  @State recordItems: PracticeItem[] = [];
  @State recordLoading: boolean = false;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    try {
      this.tasks = await getReviewTasks();
    } catch (e) {
      console.error('load review tasks failed: ' + JSON.stringify(e));
      this.tasks = [];
    }
    this.rebuildDerived();
    try {
      this.records = await getPractices();
    } catch (e) {
      console.error('load practices failed: ' + JSON.stringify(e));
      this.records = [];
    }
  }

  /** 一次性计算到期任务、未来 14 天计划与每日计划数量，供 build 直接读取 */
  rebuildDerived(): void {
    const now = Date.now();
    const end = now + 14 * 86400000;
    const due: ReviewTask[] = [];
    const upcoming: ReviewTask[] = [];
    const counts: Map<number, number> = new Map<number, number>();
    for (let i = 0; i < this.tasks.length; i++) {
      const task = this.tasks[i];
      if (task.dueAt <= now) {
        due.push(task);
      } else if (task.dueAt <= end) {
        upcoming.push(task);
      }
      const d = new Date(task.dueAt);
      const dayTs = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      const c = counts.get(dayTs);
      counts.set(dayTs, c === undefined ? 1 : c + 1);
    }
    due.sort((a: ReviewTask, b: ReviewTask) => a.dueAt - b.dueAt);
    upcoming.sort((a: ReviewTask, b: ReviewTask) => a.dueAt - b.dueAt);
    this.dueList = due;
    this.upcomingList = upcoming;
    this.dayCount = counts;
  }

  async complete(task: ReviewTask): Promise<void> {
    if (this.busyId >= 0) return;
    this.busyId = task.id;
    try {
      await completeReview(task.id, task.stage, task.knowledgePointId, task.dueAt);
      await this.load();
    } catch (e) {
      console.error('complete review failed: ' + JSON.stringify(e));
    } finally {
      this.busyId = -1;
    }
  }

  async removeTask(task: ReviewTask): Promise<void> {
    if (this.busyId >= 0) return;
    this.busyId = task.id;
    try {
      await deleteReviewTask(task.id);
      await this.load();
    } catch (e) {
      console.error('delete review failed: ' + JSON.stringify(e));
    } finally {
      this.busyId = -1;
    }
  }

  async postpone(task: ReviewTask): Promise<void> {
    if (this.busyId >= 0) return;
    this.busyId = task.id;
    try {
      const base = task.dueAt > Date.now() ? task.dueAt : Date.now();
      await updateReviewTaskDue(task.id, base + 86400000);
      await this.load();
    } catch (e) {
      console.error('postpone review failed: ' + JSON.stringify(e));
    } finally {
      this.busyId = -1;
    }
  }

  confirmDelete(task: ReviewTask): void {
    AlertDialog.show({
      title: '删除复习计划',
      message: '确认删除「' + task.kpName + '」的这条计划？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: this.t().bad,
        action: () => {
          this.removeTask(task);
        }
      }
    });
  }

  /** 距今天数文案 */
  dueLabel(ts: number): string {
    const diff = ts - Date.now();
    if (diff <= 0) return '已到期';
    const days = Math.ceil(diff / 86400000);
    if (days === 1) return '明天';
    return days + ' 天后';
  }

  monthTitle(): string {
    const base = new Date();
    const d = new Date(base.getFullYear(), base.getMonth() + this.monthOffset, 1);
    return d.getFullYear() + ' 年 ' + (d.getMonth() + 1) + ' 月';
  }

  changeMonth(delta: number): void {
    this.monthOffset += delta;
    this.selectedDayTs = 0;
  }

  /** 当月日历格子 */
  monthCells(): CalendarCell[] {
    const base = new Date();
    const y = base.getFullYear();
    const m = base.getMonth() + this.monthOffset;
    const daysInMonth = new Date(y, m + 1, 0).getDate();
    const firstWeekday = new Date(y, m, 1).getDay(); // 0=周日
    const cells: CalendarCell[] = [];
    // 月首补位空格
    for (let i = 0; i < firstWeekday; i++) {
      cells.push(this.blankCell());
    }
    const today = new Date();
    for (let day = 1; day <= daysInMonth; day++) {
      const c = new CalendarCell();
      c.day = day;
      c.dayTs = new Date(y, m, day).getTime();
      const cnt = this.dayCount.get(c.dayTs);
      c.count = cnt === undefined ? 0 : cnt;
      c.hasReview = c.count > 0;
      c.isToday = this.monthOffset === 0 && today.getDate() === day;
      c.selected = this.selectedDayTs === c.dayTs;
      cells.push(c);
    }
    return cells;
  }

  blankCell(): CalendarCell {
    const c = new CalendarCell();
    c.day = 0;
    return c;
  }

  /** 某天（0 点时间戳）的计划 */
  tasksOn(dayTs: number): ReviewTask[] {
    if (dayTs <= 0) return [];
    const end = dayTs + 86400000;
    const out: ReviewTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].dueAt >= dayTs && this.tasks[i].dueAt < end) out.push(this.tasks[i]);
    }
    out.sort((a, b) => a.dueAt - b.dueAt);
    return out;
  }

  selectCell(cell: CalendarCell): void {
    if (cell.day === 0) return;
    this.selectedDayTs = cell.selected ? 0 : cell.dayTs;
  }

  dayTitle(ts: number): string {
    const d = new Date(ts);
    return (d.getMonth() + 1) + ' 月 ' + d.getDate() + ' 日';
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('🔁 复习计划')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('＋ 新建计划')
            .fontSize(13)
            .fontColor(this.t().primary)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.t().selectedBg)
            .borderRadius(16)
            .onClick(() => {
              this.openPlan(0);
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        Scroll() {
          Column() {
            this.renderCalendar()
            if (this.selectedDayTs > 0) {
              this.renderDayPlan()
            }
            this.renderDue()
            this.renderUpcoming()
            this.renderRecords()
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

      if (this.showPlan) {
        this.renderPlanDialog()
      }
      if (this.showRecord) {
        this.renderRecordDialog()
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  renderCalendar() {
    Column() {
      Row() {
        Text('◀')
          .fontSize(14)
          .fontColor(this.t().subText)
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.t().chipBg)
          .borderRadius(15)
          .onClick(() => {
            this.changeMonth(-1);
          })
        Text(this.monthTitle())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12, right: 12 })
        Text('▶')
          .fontSize(14)
          .fontColor(this.t().subText)
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.t().chipBg)
          .borderRadius(15)
          .onClick(() => {
            this.changeMonth(1);
          })
        Blank()
        Text('点击日期查看 / 安排复习')
          .fontSize(11)
          .fontColor(this.t().muted)
      }
      .width('100%')
      .margin({ bottom: 10 })

      // 星期表头
      Row() {
        ForEach(WEEK_LABELS, (w: string) => {
          Text(w)
            .fontSize(12)
            .fontColor(this.t().muted)
            .width('14.28%')
            .textAlign(TextAlign.Center)
        }, (w: string) => w)
      }
      .width('100%')

      // 日历网格：单层 Flex 换行，避免嵌套 ForEach 点击事件失效
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.monthCells(), (cell: CalendarCell, index: number) => {
          Column() {
            if (cell.day === 0) {
              Text('')
                .width(34).height(34)
            } else {
              Text(cell.day + '')
                .fontSize(13)
                .fontWeight(cell.isToday ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(cell.selected || cell.isToday ? '#FFFFFF' : this.t().text)
                .width(30).height(30)
                .textAlign(TextAlign.Center)
                .borderRadius(15)
                .backgroundColor(cell.selected ? this.t().primary :
                  (cell.isToday ? this.t().warn : Color.Transparent))
              if (cell.hasReview) {
                Text(cell.count + '')
                  .fontSize(9)
                  .fontColor(cell.selected || cell.isToday ? '#FFFFFF' : this.t().primary)
                  .width(14).height(12)
                  .textAlign(TextAlign.Center)
              } else {
                Text('')
                  .height(12)
              }
            }
          }
          .width('14.28%')
          .height(52)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.selectCell(cell);
          })
        }, (cell: CalendarCell, index: number) => 'cell' + index.toString() + '_' + cell.day.toString())
      }
      .width('100%')
      .margin({ top: 6 })
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(this.t().panel)
      .borderRadius(8)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  @Builder
  renderDayPlan() {
    Column() {
      Row() {
        Text('📌 ' + this.dayTitle(this.selectedDayTs) + ' 计划 · ' + this.tasksOn(this.selectedDayTs).length + ' 项')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('＋ 添加')
          .fontSize(12)
          .fontColor(this.t().primary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.t().selectedBg)
          .borderRadius(12)
          .onClick(() => {
            this.openPlan(this.selectedDayTs);
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      if (this.tasksOn(this.selectedDayTs).length === 0) {
        Text('当日暂无复习安排，可点击「＋ 添加」自由安排')
          .fontSize(13)
          .fontColor(this.t().muted)
          .margin({ top: 6, bottom: 6 })
          .alignSelf(ItemAlign.Start)
      } else {
        ForEach(this.tasksOn(this.selectedDayTs), (task: ReviewTask) => {
          Column() {
            Row() {
              Text(task.kpName === '' ? '全部知识点' : task.kpName)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Text(task.stage === 0 ? ' 首轮' : ' 第 ' + (task.stage + 1) + ' 轮')
                .fontSize(11)
                .fontColor(this.t().primary)
                .margin({ left: 6 })
              Blank()
              Text(this.timeText(task.dueAt))
                .fontSize(12)
                .fontColor(this.t().muted)
            }
            .width('100%')
            if (task.note !== '') {
              Text('📝 ' + task.note)
                .fontSize(12)
                .fontColor(this.t().subText)
                .margin({ top: 4 })
                .width('100%')
            }
            Row() {
              if (task.dueAt <= Date.now()) {
                Text('完成复习')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor(this.t().primary)
                  .borderRadius(12)
                  .onClick(() => {
                    this.complete(task);
                  })
              }
              Text('顺延 1 天')
                .fontSize(12)
                .fontColor(this.t().subText)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.t().chipBg)
                .borderRadius(12)
                .margin({ left: 8 })
                .onClick(() => {
                  this.postpone(task);
                })
              Text('删除')
                .fontSize(12)
                .fontColor(this.t().bad)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.t().dangerBg)
                .borderRadius(12)
                .margin({ left: 8 })
                .onClick(() => {
                  this.confirmDelete(task);
                })
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .margin({ top: 8 })
          .backgroundColor(this.t().panel)
          .borderRadius(8)
        }, (task: ReviewTask) => task.id.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.t().card)
    .borderRadius(12)
    .margin({ top: 16 })
  }

  @Builder
  renderDue() {
    Column() {
      Row() {
        Text('⏰ 今日到期 · ' + this.dueList.length + ' 项')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('完成后自动进入下一复习轮')
          .fontSize(11)
          .fontColor(this.t().muted)
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.dueList.length === 0) {
        Text('🎉 今天没有到期任务，保持住！')
          .fontSize(14)
          .fontColor(this.t().muted)
          .margin({ top: 8, bottom: 8 })
          .alignSelf(ItemAlign.Start)
      } else {
        ForEach(this.dueList, (task: ReviewTask) => {
          Row() {
            Column() {
              Text(task.kpName === '' ? '全部知识点' : task.kpName)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Text('第 ' + (task.stage + 1) + ' / 5 轮 · ' + this.dueLabel(task.dueAt) +
                (task.note !== '' ? ' · ' + task.note : ''))
                .fontSize(12)
                .fontColor(this.t().muted)
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('完成复习')
              .fontSize(12)
              .fontColor('#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.t().primary)
              .borderRadius(14)
              .onClick(() => {
                this.complete(task);
              })
            Text('删除')
              .fontSize(12)
              .fontColor(this.t().bad)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .margin({ left: 8 })
              .onClick(() => {
                this.confirmDelete(task);
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.t().dangerBg)
          .borderRadius(10)
          .border({ width: 1, color: this.t().dangerBorder })
          .margin({ top: 8 })
        }, (task: ReviewTask) => task.id.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.t().card)
    .borderRadius(12)
    .margin({ top: 16 })
  }

  @Builder
  renderUpcoming() {
    Column() {
      Text('📅 未来 14 天计划')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })

      if (this.upcomingList.length === 0) {
        Text('未来 14 天暂无复习安排，可点击日历或右上角「＋ 新建计划」添加')
          .fontSize(13)
          .fontColor(this.t().muted)
          .margin({ top: 8, bottom: 8 })
          .alignSelf(ItemAlign.Start)
      } else {
        ForEach(this.upcomingList, (task: ReviewTask) => {
          Row() {
            Column() {
              Text(task.kpName === '' ? '全部知识点' : task.kpName)
                .fontSize(14)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (task.note !== '') {
                Text(task.note)
                  .fontSize(11)
                  .fontColor(this.t().muted)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(this.dueDate(task.dueAt))
              .fontSize(12)
              .fontColor(this.t().subText)
            Text(this.dueLabel(task.dueAt))
              .fontSize(12)
              .fontColor(this.t().warn)
              .width(56)
              .textAlign(TextAlign.End)
            Text('删除')
              .fontSize(11)
              .fontColor(this.t().bad)
              .margin({ left: 10 })
              .onClick(() => {
                this.confirmDelete(task);
              })
          }
          .width('100%')
          .height(44)
        }, (task: ReviewTask) => task.id.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.t().card)
    .borderRadius(12)
    .margin({ top: 16 })
  }

  dueDate(ts: number): string {
    const d = new Date(ts);
    return (d.getMonth() + 1) + '/' + d.getDate() + ' ' + pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }

  timeText(ts: number): string {
    const d = new Date(ts);
    return pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }

  @Builder
  renderRecords() {
    Column() {
      Text('📋 最近练习 / 考试记录')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })

      if (this.records.length === 0) {
        Text('暂无练习记录')
          .fontSize(13)
          .fontColor(this.t().muted)
          .margin({ top: 8, bottom: 8 })
          .alignSelf(ItemAlign.Start)
      } else {
        ForEach(this.records.slice(0, 10), (rec: PracticeRecord) => {
          Row() {
            Text(rec.subjectName === '' ? '未知学科' : rec.subjectName)
              .fontSize(13)
              .fontColor(this.t().primary)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(8)
              .backgroundColor(this.t().selectedBg)
            Text(this.recordTime(rec.createdTime))
              .fontSize(12)
              .fontColor(this.t().muted)
              .margin({ left: 10 })
            Blank()
            Text(rec.mode === 1 ? '模拟考' : '练习')
              .fontSize(12)
              .fontColor(this.t().muted)
              .margin({ right: 12 })
            Text(rec.correctCount + '/' + rec.totalCount + ' · ' + rec.rate + '分')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.rateColor(rec.rate))
            Text('查看')
              .fontSize(12)
              .fontColor(this.t().primary)
              .margin({ left: 12 })
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.t().selectedBg)
              .borderRadius(10)
              .onClick(() => {
                this.openRecord(rec);
              })
          }
          .width('100%')
          .height(44)
        }, (rec: PracticeRecord) => rec.id.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.t().card)
    .borderRadius(12)
    .margin({ top: 16 })
  }

  recordTime(ts: number): string {
    const d = new Date(ts);
    return d.getMonth() + 1 + '/' + d.getDate() + ' ' + pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }

  rateColor(rate: number): string {
    if (rate >= 80) return this.t().ok;
    if (rate >= 60) return this.t().warn;
    return this.t().bad;
  }

  // ==================== 新建计划弹窗 ====================
  async openPlan(dayTs: number): Promise<void> {
    try {
      if (this.planSubjects.length === 0) {
        this.planSubjects = await getSubjects();
      }
    } catch (e) {
      console.error('load plan subjects failed: ' + JSON.stringify(e));
      this.planSubjects = [];
    }
    if (this.planSubjects.length === 0) {
      AlertDialog.show({ message: '暂无学科，请先到知识点页创建' });
      return;
    }
    this.planSubject = this.planSubjects[0].id;
    await this.loadPlanKps();
    const base = dayTs > 0 ? new Date(dayTs) : new Date(Date.now() + 86400000);
    this.planDateTs = new Date(base.getFullYear(), base.getMonth(), base.getDate()).getTime();
    this.planHour = 9;
    this.planMinute = 0;
    this.planNote = '';
    this.showPlan = true;
  }

  async loadPlanKps(): Promise<void> {
    try {
      this.planKps = await getKps(this.planSubject);
    } catch (e) {
      console.error('load plan kps failed: ' + JSON.stringify(e));
      this.planKps = [];
    }
    this.planKp = this.planKps.length > 0 ? this.planKps[0].id : 0;
  }

  planDateText(): string {
    const d = new Date(this.planDateTs);
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
  }

  shiftDays(delta: number): void {
    this.planDateTs = this.planDateTs + delta * 86400000;
  }

  async savePlan(): Promise<void> {
    if (this.saving) return;
    if (this.planKp === 0) {
      AlertDialog.show({ message: '请选择知识点' });
      return;
    }
    const d = new Date(this.planDateTs);
    const due = new Date(d.getFullYear(), d.getMonth(), d.getDate(),
      this.planHour, this.planMinute, 0, 0).getTime();
    if (due <= Date.now()) {
      AlertDialog.show({ message: '计划时间需晚于当前时间' });
      return;
    }
    this.saving = true;
    try {
      await insertReviewTask(this.planKp, due, 0, this.planNote.trim());
      this.showPlan = false;
      await this.load();
    } catch (e) {
      console.error('save plan failed: ' + JSON.stringify(e));
      AlertDialog.show({ message: '保存失败，请重试' });
    } finally {
      this.saving = false;
    }
  }

  @Builder
  planDateChip(delta: number, label: string) {
    Text(label)
      .fontSize(12)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .margin({ right: 8 })
      .backgroundColor(this.planDateTs === this.quickDateTs(delta) ? this.t().primary : this.t().chipBg)
      .fontColor(this.planDateTs === this.quickDateTs(delta) ? '#FFFFFF' : this.t().subText)
      .borderRadius(12)
      .onClick(() => {
        this.planDateTs = this.quickDateTs(delta);
      })
  }

  quickDateTs(delta: number): number {
    const d = new Date(Date.now() + delta * 86400000);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  }

  hourText(): string {
    return pad2(this.planHour) + ':' + pad2(this.planMinute);
  }

  @Builder
  renderPlanDialog() {
    Column() {
      Row() {
        Text('🗓 新建复习计划')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('✕')
          .fontSize(16)
          .fontColor(this.t().muted)
          .padding(6)
          .onClick(() => {
            this.showPlan = false;
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column() {
          Text('学科')
            .fontSize(12)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
          Scroll() {
            Row() {
              ForEach(this.planSubjects, (s: Subject) => {
                Text(s.name)
                  .fontSize(13)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .margin({ right: 8 })
                  .backgroundColor(this.planSubject === s.id ? this.t().primary : this.t().chipBg)
                  .fontColor(this.planSubject === s.id ? '#FFFFFF' : this.t().subText)
                  .borderRadius(14)
                  .onClick(() => {
                    this.planSubject = s.id;
                    this.loadPlanKps();
                  })
              }, (s: Subject) => s.id.toString())
            }
            .padding({ top: 4, bottom: 4 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%')
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)

          Text('知识点')
            .fontSize(12)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 10 })
          if (this.planKps.length === 0) {
            Text('该学科暂无知识点')
              .fontSize(13)
              .fontColor(this.t().muted)
              .margin({ top: 6 })
              .alignSelf(ItemAlign.Start)
          } else {
            Scroll() {
              Row() {
                ForEach(this.planKps, (kp: KnowledgePoint) => {
                  Text(kp.name)
                    .fontSize(13)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .margin({ right: 8 })
                    .backgroundColor(this.planKp === kp.id ? this.t().primary : this.t().chipBg)
                    .fontColor(this.planKp === kp.id ? '#FFFFFF' : this.t().subText)
                    .borderRadius(14)
                    .onClick(() => {
                      this.planKp = kp.id;
                    })
                }, (kp: KnowledgePoint) => kp.id.toString())
              }
              .padding({ top: 4, bottom: 4 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .scrollBar(BarState.Off)
          }

          Text('计划日期')
            .fontSize(12)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 12 })
          Row() {
            Text('◀ 前一天')
              .fontSize(12)
              .fontColor(this.t().subText)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.t().chipBg)
              .borderRadius(12)
              .onClick(() => {
                this.shiftDays(-1);
              })
            Text(this.planDateText())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 12, right: 12 })
            Text('后一天 ▶')
              .fontSize(12)
              .fontColor(this.t().subText)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.t().chipBg)
              .borderRadius(12)
              .onClick(() => {
                this.shiftDays(1);
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 6 })

          Row() {
            this.planDateChip(0, '今天')
            this.planDateChip(1, '明天')
            this.planDateChip(3, '3 天后')
            this.planDateChip(7, '1 周后')
            this.planDateChip(14, '2 周后')
          }
          .width('100%')
          .margin({ top: 8 })

          Text('计划时间 · ' + this.hourText())
            .fontSize(12)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 12 })
          Row() {
            Text('小时')
              .fontSize(12)
              .fontColor(this.t().subText)
            Slider({ value: this.planHour, min: 0, max: 23, step: 1 })
              .layoutWeight(1)
              .margin({ left: 8 })
              .onChange((v: number) => {
                this.planHour = Math.round(v);
              })
          }
          .width('100%')
          .margin({ top: 4 })
          Row() {
            Text('分钟')
              .fontSize(12)
              .fontColor(this.t().subText)
            Slider({ value: this.planMinute, min: 0, max: 55, step: 5 })
              .layoutWeight(1)
              .margin({ left: 8 })
              .onChange((v: number) => {
                this.planMinute = Math.round(v);
              })
          }
          .width('100%')

          Text('备注（可选）')
            .fontSize(12)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 10 })
          TextInput({ placeholder: '例如：错题重做、公式默写' })
            .fontSize(13)
            .width('100%')
            .margin({ top: 4 })
            .enterKeyType(EnterKeyType.Done)
            .onChange((v: string) => {
              this.planNote = v;
            })

          Row() {
            Button('取消')
              .width(120)
              .backgroundColor(this.t().chipBg)
              .fontColor(this.t().subText)
              .onClick(() => {
                this.showPlan = false;
              })
            Button(this.saving ? '保存中...' : '保存计划')
              .width(150)
              .margin({ left: 12 })
              .backgroundColor(this.t().primary)
              .onClick(() => {
                this.savePlan();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 18 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
    }
    .width(580)
    .height('86%')
    .backgroundColor(this.t().card)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 8 })
  }

  // ==================== 记录详情弹窗 ====================
  async openRecord(rec: PracticeRecord): Promise<void> {
    this.recordTitle = (rec.mode === 1 ? '📝 模拟考试详情' : '📝 练习详情') + ' · ' + rec.rate + ' 分';
    this.recordSub = (rec.subjectName === '' ? '未知学科' : rec.subjectName) + ' · ' +
      this.recordTime(rec.createdTime) + ' · 答对 ' + rec.correctCount + '/' + rec.totalCount;
    this.recordItems = [];
    this.recordLoading = true;
    this.showRecord = true;
    try {
      this.recordItems = await getPracticeItemsByPractice(rec.id);
    } catch (e) {
      console.error('load record detail failed: ' + JSON.stringify(e));
      this.recordItems = [];
    } finally {
      this.recordLoading = false;
    }
  }

  recordOptions(item: PracticeItem): string[] {
    if (item.type === 2) return ['A. 正确', 'B. 错误'];
    try {
      const arr = JSON.parse(item.options) as string[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  recordAnswer(item: PracticeItem, letters: string): string {
    if (letters === undefined || letters === '') return '未作答';
    const opts = this.recordOptions(item);
    let out = '';
    for (let i = 0; i < letters.length; i++) {
      const ch = letters.charAt(i);
      const idx = ch.charCodeAt(0) - 65;
      let text = ch;
      if (idx >= 0 && idx < opts.length) text = opts[idx];
      out += (out === '' ? '' : '；') + text;
    }
    return out;
  }

  @Builder
  renderRecordDialog() {
    Column() {
      Row() {
        Column() {
          Text(this.recordTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
          Text(this.recordSub)
            .fontSize(12)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('✕')
          .fontSize(16)
          .fontColor(this.t().muted)
          .padding(6)
          .onClick(() => {
            this.showRecord = false;
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Divider()

      if (this.recordLoading) {
        Text('加载中...')
          .fontSize(14)
          .fontColor(this.t().muted)
          .margin({ top: 24, bottom: 24 })
      } else if (this.recordItems.length === 0) {
        Text('暂无答题明细')
          .fontSize(14)
          .fontColor(this.t().muted)
          .margin({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.recordItems, (item: PracticeItem, index: number) => {
              Column() {
                Row() {
                  Text(item.isCorrect === 1 ? '✅' : '❌')
                    .fontSize(14)
                  Text('第 ' + (index + 1) + ' 题 · ' + (item.type === 2 ? '判断' : (item.type === 1 ? '多选' : '单选')))
                    .fontSize(12)
                    .fontColor(this.t().muted)
                    .margin({ left: 8 })
                  Blank()
                  Text(item.spentSeconds + ' 秒')
                    .fontSize(11)
                    .fontColor(this.t().muted)
                }
                .width('100%')
                Text(item.questionContent)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .lineHeight(21)
                  .margin({ top: 6 })
                  .width('100%')
                Text('你的答案：' + this.recordAnswer(item, item.userAnswer))
                  .fontSize(12)
                  .fontColor(item.isCorrect === 1 ? this.t().ok : this.t().bad)
                  .margin({ top: 6 })
                  .width('100%')
                Text('正确答案：' + this.recordAnswer(item, item.answer))
                  .fontSize(12)
                  .fontColor(this.t().ok)
                  .margin({ top: 4 })
                  .width('100%')
                Text('解析：' + (item.explanation === '' ? '暂无解析' : item.explanation))
                  .fontSize(12)
                  .fontColor(this.t().subText)
                  .lineHeight(19)
                  .margin({ top: 4 })
                  .width('100%')
                if (item.kpNames !== '') {
                  Text('关联知识点：' + item.kpNames)
                    .fontSize(11)
                    .fontColor(this.t().primary)
                    .margin({ top: 4 })
                    .width('100%')
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .margin({ top: 10 })
              .backgroundColor(this.t().panel)
              .borderRadius(8)
            }, (item: PracticeItem) => item.id.toString())

            Row() {
              Button('关闭')
                .width(120)
                .backgroundColor(this.t().chipBg)
                .fontColor(this.t().subText)
                .onClick(() => {
                  this.showRecord = false;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.End)
            .margin({ top: 6, bottom: 6 })
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 16 })
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
      }
    }
    .width(760)
    .height('84%')
    .backgroundColor(this.t().card)
    .borderRadius(16)
    .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 8 })
  }
}

/** 日历格子 */
class CalendarCell {
  day: number = 0; // 0 表示空白
  dayTs: number = 0;
  count: number = 0;
  hasReview: boolean = false;
  isToday: boolean = false;
  selected: boolean = false;
}
