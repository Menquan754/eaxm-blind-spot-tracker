/**
 * 练习自测：配置 -> 答题 -> 结果
 * - 日常练习：可随时查看答案与解析
 * - 模拟考试：自定义考试时长，倒计时结束自动交卷，考试中不可查看答案
 * - 交卷后可查看全卷解析（你的答案 / 正确答案 / 完整解析 / 关联知识点）
 */
import { getSubjects, getKps } from '../../database/AppDatabase';
import { pickQuestions, judge, submitPractice } from '../../service/PracticeService';
import { Question, Subject, KnowledgePoint } from '../../model/Entities';
import { GlobalData } from '../../common/GlobalData';
import { themeOf, ThemeColors } from '../../common/Theme';
import { pad2 } from '../../common/Utils';

@Component
export struct PracticePage {
  @StorageLink('darkMode') darkMode: boolean = false;
  /** 外部导航回调：结果页跳转错题本等 */
  onNavigate: (index: number) => void = () => {
  };
  @State stage: number = 0; // 0 配置 1 答题 2 结果
  @State subjects: Subject[] = [];
  @State selecteSubject: number = 0;
  @State kps: KnowledgePoint[] = [];
  @State selectedKp: number = 0;
  @State count: number = 5;
  @State mode: number = 0;
  @State examMinutes: number = 30;
  @State questions: Question[] = [];
  @State currentIndex: number = 0;
  @State answers: string[] = [];
  @State results: boolean[] = [];
  @State seconds: number[] = [];
  @State spent: number[] = [];
  @State showAnswer: boolean = false;
  @State score: number = 0;
  @State correctCount: number = 0;
  @State isLoading: boolean = false;
  @State isSubmitting: boolean = false;
  /** 模拟考试剩余秒数 */
  @State remainSec: number = 0;
  /** 模拟考试已用秒数 */
  @State elapsedSec: number = 0;
  /** 是否因时间到自动交卷 */
  @State autoSubmitted: boolean = false;
  /** 结果页是否展开全卷解析 */
  @State showPaper: boolean = false;
  private timerId: number = -1;
  private lastSwitchTs: number = 0;
  private qSpent: number[] = [];

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  async aboutToAppear(): Promise<void> {
    try {
      this.subjects = await getSubjects();
      if (this.subjects.length > 0) {
        this.selecteSubject = this.subjects[0].id;
      }
      this.kps = await getKps(this.selecteSubject);
      this.selectedKp = 0;
    } catch (e) {
      console.error('PracticePage init failed: ' + JSON.stringify(e));
      this.subjects = [];
      this.kps = [];
    }
  }

  aboutToDisappear(): void {
    // 页面销毁时释放计时器，避免后台持续计时与状态泄漏
    this.stopTimer();
  }

  async choose(): Promise<void> {
    if (this.isLoading || this.isSubmitting) return;
    this.isLoading = true;
    try {
      this.questions = await pickQuestions({
        subjectId: this.selecteSubject,
        kpId: this.selectedKp,
        count: this.count,
        mode: this.mode
      });
    } catch (e) {
      console.error('pickQuestions failed: ' + JSON.stringify(e));
      this.questions = [];
    } finally {
      // 无论成功失败都恢复按钮可用，避免卡在"准备中..."
      this.isLoading = false;
    }
    if (this.questions.length === 0) {
      AlertDialog.show({ message: '暂无题目，请先去知识点页添加' });
      return;
    }
    this.currentIndex = 0;
    this.answers = [];
    this.results = [];
    this.seconds = [];
    this.spent = [];
    this.qSpent = [];
    for (let i = 0; i < this.questions.length; i++) {
      this.qSpent.push(0);
    }
    this.score = 0;
    this.correctCount = 0;
    this.showAnswer = false;
    this.showPaper = false;
    this.autoSubmitted = false;
    this.elapsedSec = 0;
    this.lastSwitchTs = Date.now();
    this.stage = 1;
    if (this.mode === 1) {
      this.remainSec = this.examMinutes * 60;
      this.startTimer();
    } else {
      this.remainSec = 0;
      this.stopTimer();
    }
  }

  /** 开始倒计时：每秒刷新，归零自动交卷 */
  startTimer(): void {
    this.stopTimer();
    this.timerId = setInterval(() => {
      if (this.stage !== 1) {
        this.stopTimer();
        return;
      }
      this.remainSec -= 1;
      this.elapsedSec += 1;
      if (this.remainSec <= 0) {
        this.remainSec = 0;
        this.stopTimer();
        this.autoSubmitted = true;
        this.submit();
      }
    }, 1000);
  }

  stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 累加当前题作答耗时（秒） */
  accumulateSpent(): void {
    if (this.qSpent.length !== this.questions.length) {
      this.qSpent = [];
      for (let i = 0; i < this.questions.length; i++) {
        this.qSpent.push(0);
      }
    }
    if (this.lastSwitchTs > 0 && this.currentIndex < this.qSpent.length) {
      const add = Math.floor((Date.now() - this.lastSwitchTs) / 1000);
      this.qSpent[this.currentIndex] += add > 0 ? add : 0;
    }
    this.lastSwitchTs = Date.now();
  }

  goPrev(): void {
    if (this.currentIndex > 0) {
      this.accumulateSpent();
      this.currentIndex -= 1;
      this.showAnswer = false;
    }
  }

  goNext(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.accumulateSpent();
      this.currentIndex += 1;
      this.showAnswer = false;
    } else {
      this.submit();
    }
  }

  submit(): void {
    if (this.isSubmitting || this.stage !== 1) return;
    this.isSubmitting = true;
    try {
      this.stopTimer();
      this.accumulateSpent();
      // 未作答的按错处理
      let correct = 0;
      for (let i = 0; i < this.questions.length; i++) {
        const ans = this.answers[i] !== undefined ? this.answers[i] : '';
        let isRight = false;
        try {
          isRight = judge(this.questions[i], ans);
        } catch (e) {
          isRight = false;
        }
        if (isRight) correct += 1;
        this.results[i] = isRight;
        this.spent[i] = this.qSpent[i] !== undefined ? this.qSpent[i] : 0;
      }
      this.score = this.questions.length > 0 ? Math.round(correct / this.questions.length * 100) : 0;
      this.correctCount = correct;
      this.stage = 2;
      this.showAnswer = false;
      // 记录上一次结果
      GlobalData.lastResultQuestions = this.questions;
      GlobalData.lastResultAnswers = this.answers;
      GlobalData.lastResultCorrects = this.results;
      GlobalData.lastResultScore = this.score;
      GlobalData.lastResultTotal = this.questions.length;
      GlobalData.lastResultCorrectCount = correct;
      GlobalData.lastKpName = this.kpNameOf(this.selectedKp);
      // 落库（异步，不阻塞结果页展示）
      this.saveRecords();
    } catch (e) {
      console.error('submit failed: ' + JSON.stringify(e));
    } finally {
      this.isSubmitting = false;
    }
  }

  async saveRecords(): Promise<void> {
    try {
      const ids: number[] = [];
      for (let i = 0; i < this.questions.length; i++) {
        ids.push(this.questions[i].id);
      }
      await submitPractice({
        subjectId: this.selecteSubject,
        kpId: this.selectedKp,
        count: this.questions.length,
        mode: this.mode
      }, ids, this.answers, this.results, this.spent);
    } catch (e) {
      // 落库失败不影响结果页展示
      console.error('submitPractice failed: ' + JSON.stringify(e));
    }
  }

  kpNameOf(id: number): string {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === id) return this.kps[i].name;
    }
    return '全部';
  }

  build() {
    Column() {
      if (this.stage === 0) {
        this.renderConfig();
      } else if (this.stage === 1) {
        this.renderQuiz();
      } else {
        this.renderResult();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t().bg)
  }

  @Builder
  renderConfig() {
    Scroll() {
      Column() {
        Text('📝 练习自测')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 20, bottom: 16 })
          .alignSelf(ItemAlign.Start)

        Text('学科')
          .fontSize(13)
          .fontColor(this.t().muted)
          .alignSelf(ItemAlign.Start)
          .margin({ top: 8 })
        Scroll() {
          Row() {
            ForEach(this.subjects, (s: Subject) => {
              Text(s.name)
                .fontSize(14)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .margin({ right: 8 })
                .backgroundColor(this.selecteSubject === s.id ? this.t().primary : this.t().chipBg)
                .fontColor(this.selecteSubject === s.id ? '#FFFFFF' : this.t().subText)
                .borderRadius(16)
                .onClick(() => {
                  this.selecteSubject = s.id;
                  this.selectedKp = 0;
                  this.getKpsAsync();
                })
            }, (s: Subject) => s.id.toString())
          }
          .padding({ top: 4, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)

        Text('知识点（空 = 全部/智能出题）')
          .fontSize(13)
          .fontColor(this.t().muted)
          .alignSelf(ItemAlign.Start)
          .margin({ top: 16 })
        Scroll() {
          Row() {
            Text('⚡全部·智能')
              .fontSize(14)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .margin({ right: 8 })
              .backgroundColor(this.selectedKp === 0 ? this.t().primary : this.t().chipBg)
              .fontColor(this.selectedKp === 0 ? '#FFFFFF' : this.t().subText)
              .borderRadius(16)
              .onClick(() => {
                this.selectedKp = 0;
              })
            ForEach(this.kps, (kp: KnowledgePoint) => {
              Text(kp.name)
                .fontSize(14)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .margin({ right: 8 })
                .backgroundColor(this.selectedKp === kp.id ? this.t().primary : this.t().chipBg)
                .fontColor(this.selectedKp === kp.id ? '#FFFFFF' : this.t().subText)
                .borderRadius(16)
                .onClick(() => {
                  this.selectedKp = kp.id;
                })
            }, (kp: KnowledgePoint) => kp.id.toString())
          }
          .padding({ top: 4, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)

        Text('模式')
          .fontSize(13)
          .fontColor(this.t().muted)
          .alignSelf(ItemAlign.Start)
          .margin({ top: 16 })
        Row() {
          this.modeChip(0, '📖 日常练习')
          this.modeChip(1, '⏱ 模拟考试')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        Text('题量')
          .fontSize(13)
          .fontColor(this.t().muted)
          .alignSelf(ItemAlign.Start)
          .margin({ top: 16 })
        Row() {
          this.countChip(5, '5 题')
          this.countChip(10, '10 题')
          this.countChip(15, '15 题')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        Row() {
          Slider({ value: this.count, min: 3, max: 15, step: 1 })
            .width(220)
            .onChange((v: number) => {
              this.count = Math.round(v);
            })
          Text('自定义 ' + this.count + ' 题')
            .fontSize(13)
            .margin({ left: 12 })
        }
        .width('100%')
        .margin({ top: 8 })

        // 模拟考试：考试时长设置
        if (this.mode === 1) {
          Text('考试时长')
            .fontSize(13)
            .fontColor(this.t().muted)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 16 })
          Row() {
            this.durationChip(15)
            this.durationChip(30)
            this.durationChip(45)
            this.durationChip(60)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          Row() {
            Slider({ value: this.examMinutes, min: 5, max: 120, step: 5 })
              .width(220)
              .onChange((v: number) => {
                this.examMinutes = Math.round(v);
              })
            Text('自定义 ' + this.examMinutes + ' 分钟')
              .fontSize(13)
              .margin({ left: 12 })
          }
          .width('100%')
          .margin({ top: 8 })

          Text('⏰ 倒计时结束自动交卷 · 考试中不可查看答案')
            .fontSize(12)
            .fontColor(this.t().warn)
            .margin({ top: 10 })
            .alignSelf(ItemAlign.Start)
        }

        Row() {
          Text('📊 薄弱 Top 知识点将优先出题')
            .fontSize(12)
            .fontColor(this.t().warn)
            .margin({ top: 4, bottom: 16 })
        }
        .width('100%')

        Button(this.isLoading ? '准备中...' : (this.mode === 1 ? '⏰ 开始模拟考试' : '🚀 开始练习'))
          .width(200)
          .height(44)
          .fontSize(16)
          .backgroundColor(this.t().primary)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.choose();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
  }

  getKpsAsync(): void {
    this.getKps();
  }

  @Builder
  modeChip(m: number, label: string) {
    Text(label)
      .fontSize(13)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.mode === m ? this.t().primary : this.t().chipBg)
      .fontColor(this.mode === m ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.mode = m;
      })
  }

  @Builder
  countChip(c: number, label: string) {
    Text(label)
      .fontSize(13)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.count === c ? this.t().primary : this.t().chipBg)
      .fontColor(this.count === c ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.count = c;
      })
  }

  @Builder
  durationChip(min: number) {
    Text(min + ' 分钟')
      .fontSize(13)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.examMinutes === min ? this.t().primary : this.t().chipBg)
      .fontColor(this.examMinutes === min ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.examMinutes = min;
      })
  }

  async getKps(): Promise<void> {
    try {
      this.kps = await getKps(this.selecteSubject);
    } catch (e) {
      console.error('getKps failed: ' + JSON.stringify(e));
      this.kps = [];
    }
    this.selectedKp = 0;
  }

  remainText(): string {
    const s = this.remainSec > 0 ? this.remainSec : 0;
    const m = Math.floor(s / 60);
    const r = s % 60;
    return pad2(m) + ':' + pad2(r);
  }

  elapsedText(): string {
    const m = Math.floor(this.elapsedSec / 60);
    const r = this.elapsedSec % 60;
    return m + ' 分 ' + pad2(r) + ' 秒';
  }

  @Builder
  renderQuiz() {
    // Column 根：题目可滚动，底部按钮固定（参考首页多按钮 Row 可正常渲染）
    Column() {
      Scroll() {
        Column() {
          // 顶部进度 + 倒计时
          Row() {
            Text('第 ' + (this.currentIndex + 1) + ' / ' + this.questions.length + ' 题')
              .fontSize(14)
              .fontColor(this.t().muted)
            Blank()
            if (this.mode === 1) {
              Row() {
                Text('⏱')
                  .fontSize(14)
                  .margin({ right: 4 })
                Text(this.remainText())
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.remainSec <= 60 ? this.t().bad : this.t().primary)
              }
            } else {
              Text('练习')
                .fontSize(14)
            }
          }
          .width('100%')
          .margin({ top: 16, bottom: 8 })

          Progress({ value: this.currentIndex + 1, total: this.questions.length, type: ProgressType.Linear })
            .width('100%')
            .color(this.t().primary)

          if (this.mode === 1 && this.remainSec <= 60) {
            Text('⚠️ 剩余时间不足 1 分钟，到时将自动交卷')
              .fontSize(12)
              .fontColor(this.t().bad)
              .margin({ top: 8 })
              .alignSelf(ItemAlign.Start)
          }

          // 题目卡片
          Column() {
            Text(this.questionTypeTag())
              .fontSize(12)
              .fontColor(this.t().primary)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(6)
              .backgroundColor(this.t().selectedBg)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 10 })
            Text(this.questionContent())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .lineHeight(24)
              .width('100%')
            // 选项
            this.renderOptions()
            if (this.showAnswer) {
              this.renderAnswerPanel()
            }
          }
          .width('100%')
          .padding(20)
          .backgroundColor(this.t().card)
          .borderRadius(12)
          .margin({ top: 16 })

          // 操作按钮（跟随内容流，参考首页多按钮 Row 已验证可正常渲染；不设 height/enabled）
          Row() {
            Button('上一题')
              .width(140)
              .backgroundColor(this.t().chipBg)
              .fontColor(this.t().subText)
              .onClick(() => {
                this.goPrev();
              })
            if (this.mode === 0) {
              Button('查看答案')
                .width(140)
                .margin({ left: 12 })
                .backgroundColor(this.t().chipBg)
                .fontColor(this.t().subText)
                .onClick(() => {
                  this.showAnswer = true;
                })
            }
            Button(this.currentIndex < this.questions.length - 1 ? '下一题' : '交卷')
              .width(140)
              .margin({ left: 12 })
              .backgroundColor(this.t().primary)
              .onClick(() => {
                this.goNext();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ top: 20 })
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
  }

  questionTypeTag(): string {
    if (this.questions.length === 0) return '';
    const t = this.questions[this.currentIndex].type;
    if (t === 1) return '多选';
    if (t === 2) return '判断';
    return '单选';
  }

  questionContent(): string {
    if (this.questions.length === 0) return '';
    return this.questions[this.currentIndex].content;
  }

  @Builder
  renderOptions() {
    Column() {
      ForEach(this.currentOptions(), (opt: string, index: number) => {
        Row() {
          Text(this.letterAt(index))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.t().okText)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(16)
            .backgroundColor(this.t().okBg)
          Text(opt)
            .fontSize(14)
            .margin({ left: 10 })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .margin({ top: 10 })
        .borderRadius(10)
        .backgroundColor(this.isSelected(this.letterAt(index)) ? this.t().selectedBg : this.t().panel)
        .border({ width: 1, color: this.isSelected(this.letterAt(index)) ? this.t().primary : Color.Transparent })
        .onClick(() => {
          this.toggleAnswer(this.letterAt(index));
        })
      }, (opt: string, index: number) => opt + index.toString())
    }
    .width('100%')
    .margin({ top: 12 })
  }

  letterAt(i: number): string {
    return String.fromCharCode(65 + i);
  }

  currentOptions(): string[] {
    if (this.questions.length === 0) return [];
    const q = this.questions[this.currentIndex];
    if (q.type === 2) {
      return ['A. 正确', 'B. 错误'];
    }
    try {
      const arr = JSON.parse(q.options) as string[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  currentAnswer(): string {
    if (this.questions.length === 0) return '';
    return this.questions[this.currentIndex].answer;
  }

  currentExplanation(): string {
    if (this.questions.length === 0) return '';
    return this.questions[this.currentIndex].explanation;
  }

  isSelected(letter: string): boolean {
    const cur = this.answers[this.currentIndex];
    return cur !== undefined && cur.indexOf(letter) >= 0;
  }

  /** 切换选项：单选覆盖，多选切换，判断覆盖 */
  toggleAnswer(letter: string): void {
    const q = this.questions[this.currentIndex];
    let cur = this.answers[this.currentIndex] !== undefined ? this.answers[this.currentIndex] : '';
    if (q.type === 1) {
      // 多选
      if (cur.indexOf(letter) >= 0) {
        cur = cur.replace(letter, '');
      } else {
        cur += letter;
      }
    } else {
      if (cur === letter) {
        cur = '';
      } else {
        cur = letter;
      }
    }
    this.answers[this.currentIndex] = cur;
  }

  /** 把答案字母转为可读文本，如 A -> A. xxx */
  answerDisplay(q: Question, letters: string): string {
    if (letters === undefined || letters === '') return '未作答';
    const opts = this.optionsOf(q);
    let out = '';
    for (let i = 0; i < letters.length; i++) {
      const ch = letters.charAt(i);
      const idx = ch.charCodeAt(0) - 65;
      let text = ch;
      if (idx >= 0 && idx < opts.length) {
        text = opts[idx];
      }
      out += (out === '' ? '' : '；') + text;
    }
    return out;
  }

  optionsOf(q: Question): string[] {
    if (q.type === 2) {
      return ['A. 正确', 'B. 错误'];
    }
    try {
      const arr = JSON.parse(q.options) as string[];
      return arr;
    } catch (e) {
      return [];
    }
  }

  @Builder
  renderAnswerPanel() {
    Column() {
      Text('你的答案：' + (this.answers[this.currentIndex] !== undefined ?
        this.answerDisplay(this.questions[this.currentIndex], this.answers[this.currentIndex]) : '未作答'))
        .fontSize(13)
        .fontColor(this.t().subText)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 4 })
      Text('正确答案：' + this.answerDisplay(this.questions[this.currentIndex], this.currentAnswer()))
        .fontSize(14)
        .fontColor(this.t().ok)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 4 })
      Text('解析：' + (this.currentExplanation() === '' ? '暂无解析' : this.currentExplanation()))
        .fontSize(13)
        .fontColor(this.t().subText)
        .lineHeight(20)
        .alignSelf(ItemAlign.Start)
      if (this.questions[this.currentIndex].kpNames !== '') {
        Text('关联知识点：' + this.questions[this.currentIndex].kpNames)
          .fontSize(12)
          .fontColor(this.t().primary)
          .alignSelf(ItemAlign.Start)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(12)
    .margin({ top: 16 })
    .borderRadius(8)
    .border({ width: 1, color: this.t().selectedBg })
  }

  @Builder
  renderResult() {
    // 整页使用 Scroll 根节点，底部按钮跟随内容，避免被裁剪不可点
    Scroll() {
      Column() {
        Text(this.autoSubmitted ? '⏰ 考试时间到，已自动交卷' :
          (this.score >= 80 ? '🎉 表现优秀' : (this.score >= 60 ? '😊 发挥不错' : '📚 再接再厉')))
          .fontSize(this.autoSubmitted ? 18 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.autoSubmitted ? this.t().warn : this.t().text)
          .margin({ top: 32 })
        Text(this.score + ' 分')
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.score >= 60 ? this.t().ok : this.t().bad)
          .margin({ top: 12 })
        Text('答对 ' + this.correctCount + ' / ' + this.questions.length + ' 题')
          .fontSize(15)
          .fontColor(this.t().muted)
          .margin({ top: 8 })
        if (this.mode === 1) {
          Text('本次考试用时 ' + this.elapsedText())
            .fontSize(13)
            .fontColor(this.t().muted)
            .margin({ top: 4 })
        }

        // 错题回顾（直接展开，不嵌套滚动容器）
        Column() {
          if (this.results.length > 0) {
            ForEach(this.results, (isRight: boolean, index: number) => {
              if (!isRight) {
                Row() {
                  Column() {
                    Text('❌ ' + this.questions[index].content)
                      .fontSize(14)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('你的答案：' + this.answerDisplay(this.questions[index],
                      this.answers[index] !== undefined ? this.answers[index] : ''))
                      .fontSize(12)
                      .fontColor(this.t().muted)
                      .margin({ top: 6 })
                    Text('正确答案：' + this.answerDisplay(this.questions[index], this.questions[index].answer))
                      .fontSize(12)
                      .fontColor(this.t().ok)
                      .margin({ top: 4 })
                    Text('解析：' + (this.questions[index].explanation === '' ? '暂无解析' : this.questions[index].explanation))
                      .fontSize(12)
                      .fontColor(this.t().subText)
                      .lineHeight(19)
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding(12)
                .margin({ top: 10 })
                .borderRadius(8)
                .backgroundColor(this.t().dangerBg)
                .border({ width: 1, color: this.t().dangerBorder })
              }
            }, (isRight: boolean, index: number) => index.toString() + (isRight ? 'r' : 'w'))
          }
        }
        .width('100%')
        .margin({ top: 16 })

        // 全卷解析（含所有题目，考试后可完整查看）
        Row() {
          Text(this.showPaper ? '📖 收起全卷解析' : '📖 查看全卷解析')
            .fontSize(14)
            .fontColor(this.t().primary)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.t().selectedBg)
            .borderRadius(16)
            .onClick(() => {
              this.showPaper = !this.showPaper;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: 18 })

        if (this.showPaper) {
          this.renderPaper()
        }

        Row() {
          Button('再练一组')
            .width(150)
            .backgroundColor(this.t().chipBg)
            .fontColor(this.t().subText)
            .onClick(() => {
              this.stage = 0;
              this.showPaper = false;
            })
          Button('查看错题本')
            .width(150)
            .margin({ left: 16 })
            .backgroundColor(this.t().primary)
            .onClick(() => {
              // 返回配置页并跳转错题本（由 Index 处理导航）
              this.stage = 0;
              this.showPaper = false;
              this.onNavigate(3);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ top: 20 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
  }

  @Builder
  renderPaper() {
    Column() {
      ForEach(this.questions, (q: Question, index: number) => {
        Column() {
          Row() {
            Text(this.results[index] === true ? '✅' : '❌')
              .fontSize(14)
            Text('第 ' + (index + 1) + ' 题 · ' + this.typeNameOf(q.type))
              .fontSize(12)
              .fontColor(this.t().muted)
              .margin({ left: 8 })
            Blank()
            Text(this.spent[index] !== undefined ? this.spent[index] + ' 秒' : '')
              .fontSize(11)
              .fontColor(this.t().muted)
          }
          .width('100%')
          Text(q.content)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .lineHeight(21)
            .margin({ top: 6 })
            .width('100%')
          // 选项：标出正确项与用户所选
          ForEach(this.optionsOf(q), (opt: string, oi: number) => {
            Row() {
              Text(this.letterAt(oi))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .width(24)
                .height(24)
                .textAlign(TextAlign.Center)
                .borderRadius(12)
                .fontColor(q.answer.indexOf(this.letterAt(oi)) >= 0 ? this.t().ok : this.t().subText)
                .backgroundColor(q.answer.indexOf(this.letterAt(oi)) >= 0 ? this.t().okBg : this.t().chipBg)
              Text(opt)
                .fontSize(12)
                .fontColor(this.optionColor(q, index, oi))
                .margin({ left: 8 })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 4 })
          }, (opt: string, oi: number) => index.toString() + oi.toString())
          Text('你的答案：' + this.answerDisplay(q, this.answers[index] !== undefined ? this.answers[index] : ''))
            .fontSize(12)
            .fontColor(this.results[index] === true ? this.t().ok : this.t().bad)
            .margin({ top: 8 })
            .width('100%')
          Text('正确答案：' + this.answerDisplay(q, q.answer))
            .fontSize(12)
            .fontColor(this.t().ok)
            .margin({ top: 4 })
            .width('100%')
          Text('解析：' + (q.explanation === '' ? '暂无解析' : q.explanation))
            .fontSize(12)
            .fontColor(this.t().subText)
            .lineHeight(19)
            .margin({ top: 4 })
            .width('100%')
          if (q.kpNames !== '') {
            Text('关联知识点：' + q.kpNames)
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
      }, (q: Question) => q.id.toString())
    }
    .width('100%')
    .margin({ top: 10 })
  }

  /** 选项文字颜色：正确项绿色，用户错选项红色，其余默认 */
  optionColor(q: Question, qIndex: number, oi: number): string {
    const letter = this.letterAt(oi);
    const picked = (this.answers[qIndex] !== undefined ? this.answers[qIndex] : '').indexOf(letter) >= 0;
    const right = q.answer.indexOf(letter) >= 0;
    if (right) return this.t().ok;
    if (picked) return this.t().bad;
    return this.t().subText;
  }

  typeNameOf(t: number): string {
    if (t === 1) return '多选';
    if (t === 2) return '判断';
    return '单选';
  }
}
