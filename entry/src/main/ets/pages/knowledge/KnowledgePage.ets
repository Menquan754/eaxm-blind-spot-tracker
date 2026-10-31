/**
 * 知识点管理：学科选择 + 知识点树 + 题目维护 + 题目搜索
 * 2in1 双栏：左树 / 右题目列表 + 统计
 */
import { getStore, getSubjects, getKps, insertSubject, insertKp, insertQuestion,
  insertQuestionKp, deleteKp, deleteQuestion, deleteSubject } from '../../database/AppDatabase';
import { Subject, KnowledgePoint, Question } from '../../model/Entities';
import { themeOf, ThemeColors } from '../../common/Theme';
import { isValidKpJump, resolveKpTarget } from '../../service/KnowledgeJumpService';

@Component
export struct KnowledgePage {
  @StorageLink('darkMode') darkMode: boolean = false;
  @State subjects: Subject[] = [];
  @State selectedSubject: number = 0;
  @State kps: KnowledgePoint[] = [];
  @State questions: Question[] = [];
  @State selectedKp: number = 0;
  @State showAddSubject: boolean = false;
  @State showAddKp: boolean = false;
  @State showAddQuestion: boolean = false;
  // 输入字段改为普通成员：不参与状态观察，避免每次击键触发整页重建（打字更顺滑）
  newName: string = '';
  searchText: string = '';
  /** 当前知识点的全部题目缓存：搜索只在内存中过滤，不再逐键查库 */
  allQuestions: Question[] = [];
  /** 新增/删除进行中标记，防止快速重复点击造成重复写入 */
  busy: boolean = false;
  // 学科详情弹窗
  @State showSubjectDetail: boolean = false;
  @State detailName: string = '';
  @State detailKpCount: number = 0;
  @State detailQCount: number = 0;
  @State detailKps: KpBrief[] = [];
  detailSubjectId: number = 0;
  /** 右侧题目列表滚动控制器：点击知识点时回到题目顶部 */
  questionScroller: Scroller = new Scroller();
  // 知识卡片查看弹窗（页内浮层，避免系统弹窗在 2in1 窗口下不渲染）
  @State showCardDetail: boolean = false;
  @State cardDetailTitle: string = '';
  @State cardDetailBody: string = '';
  @State showAllCards: boolean = false;
  // 题目详情弹窗：点击题目查看完整题干、选项、答案与解析
  @State showQuestionDetail: boolean = false;
  @State qdType: string = '';
  @State qdContent: string = '';
  @State qdOptions: string[] = [];
  @State qdAnswer: string = '';
  @State qdExplanation: string = '';
  @State qdKps: string = '';

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  async aboutToAppear(): Promise<void> {
    try {
      this.subjects = await getSubjects();
      if (this.subjects.length > 0) {
        this.selectedSubject = this.subjects[0].id;
      }
      await this.loadKps();
    } catch (e) {
      console.error('knowledge init failed: ' + JSON.stringify(e));
      this.subjects = [];
      this.kps = [];
      this.questions = [];
    }
  }

  async loadKps(): Promise<void> {
    try {
      this.kps = await getKps(this.selectedSubject);
    } catch (e) {
      console.error('load kps failed: ' + JSON.stringify(e));
      this.kps = [];
    }
    // 切换学科时必须重置选中知识点，避免沿用上一学科的知识点 ID 查到错误题目
    this.selectedKp = resolveKpTarget(this.kps, this.selectedKp);
    await this.loadQuestions();
  }

  /** 仅在切换知识点/数据变更时查库，结果进入缓存 */
  async loadQuestions(): Promise<void> {
    if (this.selectedKp <= 0) {
      this.allQuestions = [];
      this.questions = [];
      return;
    }
    try {
      this.allQuestions = await getQuestionsByKp(this.selectedKp);
    } catch (e) {
      console.error('load questions failed: ' + JSON.stringify(e));
      this.allQuestions = [];
    }
    this.applyFilter();
  }

  /** 搜索词本地过滤：纯内存遍历，输入即时响应，避免逐键访问数据库 */
  applyFilter(): void {
    const kw = this.searchText.trim();
    if (kw === '') {
      this.questions = this.allQuestions;
      return;
    }
    const out: Question[] = [];
    for (let i = 0; i < this.allQuestions.length; i++) {
      if (this.allQuestions[i].content.indexOf(kw) >= 0) {
        out.push(this.allQuestions[i]);
      }
    }
    this.questions = out;
  }

  /** 点击知识点行 / 「题目」入口：切换到该知识点并把右侧题目列表滚回顶部 */
  async jumpToKp(kpId: number): Promise<void> {
    if (kpId <= 0) return;
    this.selectedKp = kpId;
    await this.loadQuestions();
    this.questionScroller.scrollEdge(Edge.Top);
  }

  /** 学科详情弹窗点击知识点：关闭弹窗、切换学科与该知识点并跳转题目 */
  async jumpToKpInSubject(subjectId: number, kpId: number): Promise<void> {
    if (!isValidKpJump(subjectId, kpId)) {
      return;
    }
    this.showSubjectDetail = false;
    this.selectedSubject = subjectId;
    try {
      this.kps = await getKps(subjectId);
    } catch (e) {
      console.error('load kps for jump failed: ' + JSON.stringify(e));
      this.kps = [];
    }
    // 目标知识点可能已被删除：回退到该学科第一个知识点
    this.selectedKp = resolveKpTarget(this.kps, kpId);
    await this.loadQuestions();
    this.questionScroller.scrollEdge(Edge.Top);
  }

  /** 知识小卡片：由当前知识点要点拆分为定理 / 公式 / 易错等卡片 */
  currentCards(): KnowledgeCard[] {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === this.selectedKp) {
        return buildKnowledgeCards(this.kps[i].description);
      }
    }
    return [];
  }

  cardColor(tone: number): string {
    if (tone === 2) return this.t().warn;
    if (tone === 1) return this.t().primary;
    return this.t().ok;
  }

  /** 打开单张知识卡片详情 */
  openCardDetail(card: KnowledgeCard): void {
    this.cardDetailTitle = card.icon + ' ' + card.title + ' · ' + this.currentKpName();
    this.cardDetailBody = card.body;
    this.showCardDetail = true;
  }

  /** 打开题目详情：完整题干 + 选项 + 答案 + 解析 */
  openQuestionDetail(q: Question): void {
    this.qdType = this.typeTag(q.type);
    this.qdContent = q.content;
    this.qdOptions = this.optionsOf(q);
    this.qdAnswer = q.answer === '' ? '未填写' : q.answer;
    this.qdExplanation = q.explanation;
    this.qdKps = q.kpNames === '' ? '无' : q.kpNames;
    this.showQuestionDetail = true;
  }

  /** 题目选项：判断题无选项时给出默认两项 */
  optionsOf(q: Question): string[] {
    if (q.type === 2 && q.options === '') {
      return ['A. 正确', 'B. 错误'];
    }
    if (q.options === '') {
      return [];
    }
    try {
      return JSON.parse(q.options) as string[];
    } catch (e) {
      console.error('parse question options failed: ' + JSON.stringify(e));
      return [];
    }
  }

  build() {
    Stack() {
    Row() {
      // 左栏：学科 + 知识点
      Column() {
        Row() {
          Text('学科')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text('增加')
            .width(48)
            .height(26)
            .fontSize(12)
            .textAlign(TextAlign.Center)
            .fontColor('#FFFFFF')
            .backgroundColor(this.t().primary)
            .borderRadius(13)
            .onClick(() => {
              this.showAddSubject = true;
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })

        // 学科列表
        Scroll() {
          Column() {
            ForEach(this.subjects, (s: Subject) => {
              Row() {
                Text(s.name)
                  .fontSize(14)
                  .width(168)
                  .height(40)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                  .padding({ left: 12 })
                  .backgroundColor(this.selectedSubject === s.id ? this.t().selectedBg : Color.Transparent)
                  .fontColor(this.selectedSubject === s.id ? this.t().primary : this.t().text)
                  .borderRadius(8)
                  .onClick(() => {
                    this.selectedSubject = s.id;
                    this.loadKps();
                  })
                  .gesture(LongPressGesture().onAction(() => {
                    this.confirmDeleteSubject(s);
                  }))
                // 详情入口：独立固定宽度，避免与左侧名称挤压缩成 0 宽
                Text('详情')
                  .fontSize(11)
                  .width(46)
                  .height(26)
                  .textAlign(TextAlign.Center)
                  .fontColor(this.t().primary)
                  .backgroundColor(this.t().selectedBg)
                  .borderRadius(13)
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.openSubjectDetail(s);
                  })
              }
              .width('100%')
              .height(40)
            }, (s: Subject) => s.id.toString())
            if (this.subjects.length > 0) {
              Text('点击学科切换 · 详情可直达题目 · 长按删除')
                .fontSize(11)
                .fontColor(this.t().muted)
                .margin({ top: 8 })
                .padding({ left: 8 })
                .alignSelf(ItemAlign.Start)
            }
          }
          .width('100%')
          .padding(8)
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)

        Divider()

        Row() {
          Text('知识点')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text('增加')
            .width(48)
            .height(26)
            .fontSize(12)
            .textAlign(TextAlign.Center)
            .fontColor('#FFFFFF')
            .backgroundColor(this.t().primary)
            .borderRadius(13)
            .onClick(() => {
              this.showAddKp = true;
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })

        Scroll() {
          Column() {
            ForEach(this.kps, (kp: KnowledgePoint) => {
              Row() {
                Text(kp.name)
                  .fontSize(14)
                  .width(168)
                  .height(40)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Start)
                  .padding({ left: 0 })
                  .fontColor(this.selectedKp === kp.id ? this.t().primary : this.t().text)
                // 「题目」快捷入口：点击即跳到该知识点的题目列表
                Text('题目')
                  .fontSize(11)
                  .width(42)
                  .height(24)
                  .textAlign(TextAlign.Center)
                  .fontColor(this.t().primary)
                  .backgroundColor(this.t().selectedBg)
                  .borderRadius(12)
                  .margin({ left: 6 })
              }
              .width('100%')
              .height(40)
              .padding({ left: 12, right: 8 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.selectedKp === kp.id ? this.t().selectedBg : Color.Transparent)
              .borderRadius(8)
              .onClick(() => {
                this.jumpToKp(kp.id);
              })
              .gesture(LongPressGesture().onAction(() => {
                this.confirmDeleteKp(kp);
              }))
            }, (kp: KnowledgePoint) => kp.id.toString())
            if (this.kps.length > 0) {
              Text('点击知识点直达题目 · 长按删除 · 右上角+新增')
                .fontSize(11)
                .fontColor(this.t().muted)
                .margin({ top: 8 })
                .padding({ left: 8, right: 8 })
                .alignSelf(ItemAlign.Start)
            } else {
              Text('长按删除，右上角+新增')
                .fontSize(12)
                .fontColor(this.t().muted)
                .margin({ top: 16 })
            }
          }
          .width('100%')
          .padding(8)
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
      }
      .width(280)
      .height('100%')
      .backgroundColor(this.t().sidebarBg)
      .border({ width: { right: 1 }, color: this.t().border })

      // 右栏：题目列表
      Column() {
        Row() {
          Text('题目列表' + (this.selectedKp > 0 ? ' · ' + this.currentKpName() : ''))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text('+ 新题')
            .fontSize(13)
            .width(84)
            .height(30)
            .textAlign(TextAlign.Center)
            .fontColor('#FFFFFF')
            .backgroundColor(this.t().primary)
            .borderRadius(8)
            .onClick(() => {
              this.showAddQuestion = true;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        // 当前知识点要点（概念 / 公式 / 易错提示）
        if (this.selectedKp > 0) {
          Column() {
            Text('📌 知识点要点')
              .fontSize(12)
              .fontColor(this.t().primary)
            Text(this.currentKpDesc())
              .fontSize(12)
              .fontColor(this.t().subText)
              .lineHeight(19)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .margin({ left: 16, right: 16, bottom: 10 })
          .backgroundColor(this.t().selectedBg)
          .borderRadius(10)
        }

        // 知识小卡片：把要点拆成定理 / 公式 / 易错提醒，点击查看完整内容
        if (this.selectedKp > 0 && this.currentCards().length > 0) {
          Row() {
            Text('🧠 知识小卡片')
              .fontSize(12)
              .fontColor(this.t().subText)
            Blank()
            Text('共 ' + this.currentCards().length + ' 张 · 查看全部 ›')
              .fontSize(11)
              .fontColor(this.t().primary)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.t().selectedBg)
              .borderRadius(10)
              .onClick(() => {
                this.showAllCards = true;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })

          Scroll() {
            Row() {
              ForEach(this.currentCards(), (card: KnowledgeCard, idx: number) => {
                Column() {
                  Row() {
                    Text(card.icon + ' ' + card.title)
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.cardColor(card.tone))
                    Blank()
                    Text('›')
                      .fontSize(15)
                      .fontColor(this.t().muted)
                  }
                  .width('100%')

                  Text(card.body)
                    .fontSize(12)
                    .lineHeight(18)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.t().subText)
                    .margin({ top: 6 })
                }
                .width(236)
                .height(110)
                .alignItems(HorizontalAlign.Start)
                .padding(12)
                .margin({ right: 10 })
                .backgroundColor(this.t().card)
                .border({ width: { left: 3 }, color: this.cardColor(card.tone) })
                .borderRadius(10)
                .onClick(() => {
                  this.openCardDetail(card);
                })
              }, (card: KnowledgeCard, idx: number) => this.selectedKp.toString() + '_' + idx.toString())
            }
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .margin({ bottom: 10 })
        }

        // 搜索
        Row() {
          Text('🔍')
            .fontSize(14)
            .fontColor(this.t().muted)
          TextInput({ placeholder: '按题干关键词搜索' })
            .layoutWeight(1)
            .fontSize(13)
            .margin({ left: 8 })
            .enterKeyType(EnterKeyType.Search)
            .onChange((v: string) => {
              this.searchText = v;
              this.applyFilter();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })

        Scroll(this.questionScroller) {
          Column() {
            ForEach(this.questions, (q: Question) => {
              Row() {
                Column() {
                  Text(this.typeTag(q.type))
                    .fontSize(12)
                    .fontColor(this.t().primary)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(6)
                    .backgroundColor(this.t().selectedBg)
                    .margin({ bottom: 6 })
                  Text(q.content)
                    .fontSize(14)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    Text('关联知识点：' + (q.kpNames === '' ? '无' : q.kpNames))
                      .fontSize(12)
                      .fontColor(this.t().muted)
                    Blank()
                    // 点击题目查看完整题干、选项、答案与解析
                    Text('查看详情 ›')
                      .fontSize(11)
                      .fontColor(this.t().primary)
                  }
                  .width('100%')
                  .margin({ top: 6 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .onClick(() => {
                  this.openQuestionDetail(q);
                })

                Column() {
                  Text('❌')
                    .fontSize(16)
                    .padding(6)
                    .onClick(() => {
                      this.confirmDeleteQuestion(q);
                    })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.t().card)
              .borderRadius(10)
              .margin({ top: 10 })
            }, (q: Question) => q.id.toString())
            if (this.questions.length === 0) {
              Text('当前知识点下暂无题目')
                .fontSize(13)
                .fontColor(this.t().muted)
                .margin({ top: 40 })
            }
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.t().bg)
    }
    .width('100%')
    .height('100%')

    // 新增学科弹窗
    if (this.showAddSubject) {
      this.addDialog('学科名称', () => {
        this.confirmAddSubject();
      })
    }
    if (this.showAddKp) {
      this.addDialog('知识点名称', () => {
        this.confirmAddKp();
      })
    }
    if (this.showAddQuestion) {
      QuestionDialog({
        subjectId: this.selectedSubject,
        kpId: this.selectedKp,
        onClose: () => {
          this.showAddQuestion = false;
          this.loadQuestions();
        }
      })
    }
    if (this.showSubjectDetail) {
      this.subjectDetailDialog()
    }
    if (this.showCardDetail) {
      this.cardDetailDialog()
    }
    if (this.showAllCards) {
      this.allCardsDialog()
    }
    if (this.showQuestionDetail) {
      this.questionDetailDialog()
    }
    }
  }

  /** 学科详情：知识点清单 + 题目数量统计 */
  @Builder
  subjectDetailDialog() {
    Column() {
      Row() {
        Text('📘 ' + this.detailName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.showSubjectDetail = false;
          })
      }
      .width('100%')

      Text('知识点 ' + this.detailKpCount + ' 个 · 题目 ' + this.detailQCount + ' 道')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 8 })
        .alignSelf(ItemAlign.Start)

      Text('点击知识点即可跳转到对应题目')
        .fontSize(11)
        .fontColor(this.t().muted)
        .margin({ top: 2 })
        .alignSelf(ItemAlign.Start)

      Scroll() {
        Column() {
          ForEach(this.detailKps, (kp: KpBrief) => {
            Row() {
              Text(kp.name)
                .fontSize(13)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Start)
              Text(kp.count + ' 题')
                .fontSize(11)
                .fontColor(this.t().muted)
              Text('›')
                .fontSize(16)
                .fontColor(this.t().muted)
                .margin({ left: 8 })
            }
            .width('100%')
            .height(40)
            .padding({ left: 4, right: 4 })
            .alignItems(VerticalAlign.Center)
            .border({ width: { bottom: 1 }, color: this.t().border })
            .onClick(() => {
              this.jumpToKpInSubject(this.detailSubjectId, kp.id);
            })
          }, (kp: KpBrief) => this.detailSubjectId.toString() + '_' + kp.id.toString())
        }
        .width('100%')
      }
      .width('100%')
      .height(280)
      .margin({ top: 10 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)

      Row() {
        Blank()
        Text('关闭')
          .fontSize(13)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .backgroundColor(this.t().primary)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => {
            this.showSubjectDetail = false;
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width(430)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  /** 单张知识卡片详情（页内浮层） */
  @Builder
  cardDetailDialog() {
    Column() {
      Row() {
        Text(this.cardDetailTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(2)
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.showCardDetail = false;
          })
      }
      .width('100%')

      Text(this.cardDetailBody)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.t().subText)
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ top: 12 })

      Row() {
        Blank()
        Text('关闭')
          .fontSize(13)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .backgroundColor(this.t().primary)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => {
            this.showCardDetail = false;
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width(480)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  /** 当前知识点的全部知识卡片（纵向列表，查看完整内容） */
  @Builder
  allCardsDialog() {
    Column() {
      Row() {
        Text('🧠 知识小卡片 · ' + this.currentKpName())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.showAllCards = false;
          })
      }
      .width('100%')

      Scroll() {
        Column() {
          ForEach(this.currentCards(), (card: KnowledgeCard, idx: number) => {
            Column() {
              Text(card.icon + ' ' + card.title)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.cardColor(card.tone))
              Text(card.body)
                .fontSize(13)
                .lineHeight(20)
                .fontColor(this.t().subText)
                .margin({ top: 4 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .margin({ top: 10 })
            .backgroundColor(this.t().panel)
            .border({ width: { left: 3 }, color: this.cardColor(card.tone) })
            .borderRadius(10)
          }, (card: KnowledgeCard, idx: number) => 'all_' + this.selectedKp.toString() + '_' + idx.toString())
        }
        .width('100%')
      }
      .width('100%')
      .height(380)
      .margin({ top: 6 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)

      Row() {
        Blank()
        Text('关闭')
          .fontSize(13)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .backgroundColor(this.t().primary)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => {
            this.showAllCards = false;
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width(520)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  /** 题目详情：完整题干 + 选项 + 答案 + 解析 */
  @Builder
  questionDetailDialog() {
    Column() {
      Row() {
        Text('📝 题目详情')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.showQuestionDetail = false;
          })
      }
      .width('100%')

      Scroll() {
        Column() {
          Row() {
            Text(this.qdType)
              .fontSize(12)
              .fontColor(this.t().primary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor(this.t().selectedBg)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          Text(this.qdContent)
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.t().text)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 10 })

          ForEach(this.qdOptions, (opt: string, idx: number) => {
            Text(opt)
              .fontSize(13)
              .fontColor(this.t().subText)
              .width('100%')
              .padding(10)
              .margin({ top: 8 })
              .backgroundColor(this.t().panel)
              .borderRadius(8)
          }, (opt: string, idx: number) => 'opt_' + idx.toString())

          Row() {
            Text('正确答案')
              .fontSize(13)
              .fontColor(this.t().muted)
            Text(this.qdAnswer)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.t().ok)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 14 })

          Text('解析')
            .fontSize(13)
            .fontColor(this.t().muted)
            .margin({ top: 12 })
          Text(this.qdExplanation === '' ? '暂无解析' : this.qdExplanation)
            .fontSize(13)
            .lineHeight(21)
            .fontColor(this.t().subText)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 4 })

          Text('关联知识点：' + this.qdKps)
            .fontSize(12)
            .fontColor(this.t().muted)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 12 })
        }
        .width('100%')
      }
      .width('100%')
      .height(380)
      .margin({ top: 6 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)

      Row() {
        Blank()
        Text('关闭')
          .fontSize(13)
          .padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .backgroundColor(this.t().primary)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => {
            this.showQuestionDetail = false;
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width(520)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  async openSubjectDetail(s: Subject): Promise<void> {
    try {
      const briefs = await getKpBriefs(s.id);
      let total = 0;
      for (let i = 0; i < briefs.length; i++) {
        total += briefs[i].count;
      }
      this.detailName = s.name;
      this.detailKpCount = briefs.length;
      this.detailQCount = total;
      this.detailSubjectId = s.id;
      this.detailKps = briefs;
      this.showSubjectDetail = true;
    } catch (e) {
      console.error('openSubjectDetail failed: ' + JSON.stringify(e));
    }
  }

  @Builder
  addDialog(placeholder: string, onOk: () => void) {
    Column() {
      Row() {
        Text('  请输入名称')
          .fontSize(15)
          .alignSelf(ItemAlign.Start)
        Blank()
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.showAddSubject = false;
            this.showAddKp = false;
            this.newName = '';
          })
      }
      .width('100%')

      TextInput({ placeholder: placeholder })
        .width('100%')
        .margin({ top: 12 })
        .enterKeyType(EnterKeyType.Done)
        .onSubmit(() => {
          onOk();
        })
        .onChange((v: string) => {
          this.newName = v;
        })

      Row() {
        Blank()
        Button('取消')
          .backgroundColor(this.t().chipBg)
          .fontColor(this.t().subText)
          .onClick(() => {
            this.showAddSubject = false;
            this.showAddKp = false;
            this.newName = '';
          })
        Button('确定')
          .backgroundColor(this.t().primary)
          .onClick(() => {
            onOk();
          })
      }
      .width('100%')
      .margin({ top: 16 })
      .justifyContent(FlexAlign.End)
    }
    .width(360)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
  }

  async confirmAddSubject(): Promise<void> {
    const name = this.newName.trim();
    if (name === '' || this.busy) return;
    this.busy = true;
    try {
      await insertSubject(name);
      this.newName = '';
      this.showAddSubject = false;
      this.subjects = await getSubjects();
      await this.loadKps();
    } catch (e) {
      console.error('add subject failed: ' + JSON.stringify(e));
      AlertDialog.show({ message: '新增学科失败，请重试' });
    } finally {
      this.busy = false;
    }
  }

  async confirmAddKp(): Promise<void> {
    const name = this.newName.trim();
    if (name === '' || this.busy) return;
    this.busy = true;
    try {
      await insertKp(this.selectedSubject, name, 0);
      this.newName = '';
      this.showAddKp = false;
      await this.loadKps();
    } catch (e) {
      console.error('add kp failed: ' + JSON.stringify(e));
      AlertDialog.show({ message: '新增知识点失败，请重试' });
    } finally {
      this.busy = false;
    }
  }

  confirmDeleteKp(kp: KnowledgePoint): void {
    this.alertDialog('删除知识点', '确定删除「' + kp.name + '」？关联题目将解除，复习计划一并删除。', async () => {
      try {
        await deleteKp(kp.id);
        await this.loadKps();
      } catch (e) {
        console.error('delete kp failed: ' + JSON.stringify(e));
        AlertDialog.show({ message: '删除失败，请重试' });
      }
    });
  }

  confirmDeleteSubject(s: Subject): void {
    AlertDialog.show({
      title: '删除学科',
      message: '确定删除「' + s.name + '」？其下所有知识点、题目与复习计划都将被删除！',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: this.t().bad,
        action: () => {
          this.doDeleteSubject(s.id);
        }
      }
    });
  }

  async doDeleteSubject(id: number): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await deleteSubject(id);
      this.subjects = await getSubjects();
      if (this.subjects.length > 0) {
        this.selectedSubject = this.subjects[0].id;
      } else {
        this.selectedSubject = 0;
      }
      await this.loadKps();
    } catch (e) {
      console.error('delete subject failed: ' + JSON.stringify(e));
      AlertDialog.show({ message: '删除学科失败，请重试' });
    } finally {
      this.busy = false;
    }
  }

  confirmDeleteQuestion(q: Question): void {
    this.alertDialog('删除题目', '确定删除该题目？', async () => {
      try {
        await deleteQuestion(q.id);
        await this.loadQuestions();
      } catch (e) {
        console.error('delete question failed: ' + JSON.stringify(e));
        AlertDialog.show({ message: '删除失败，请重试' });
      }
    });
  }

  alertDialog(title: string, msg: string, onOk: () => void): void {
    AlertDialog.show({
      title: title,
      message: msg,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: this.t().bad,
        action: () => {
          onOk();
        }
      }
    });
  }

  currentKpName(): string {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === this.selectedKp) {
        return this.kps[i].name;
      }
    }
    return '';
  }

  /** 当前选中的知识点要点，无内容时给出引导文案 */
  currentKpDesc(): string {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === this.selectedKp) {
        return this.kps[i].description === ''
          ? '暂无要点，可先通过右侧题目与解析巩固该知识点。'
          : this.kps[i].description;
      }
    }
    return '';
  }

  typeTag(t: number): string {
    if (t === 1) return '多选';
    if (t === 2) return '判断';
    return '单选';
  }
}

/** 该知识点的题目列表 */
async function getQuestionsByKp(kpId: number): Promise<Question[]> {
  const r = await getStore().querySql(
    `SELECT q.id, q.subjectId, q.type, q.content, q.options, q.answer, q.explanation,
            GROUP_CONCAT(kp.name) AS kpNames
     FROM question q
     INNER JOIN question_kp qk ON q.id = qk.questionId
     LEFT JOIN knowledge_point kp ON qk.knowledgePointId = kp.id
     WHERE qk.knowledgePointId = ${kpId}
     GROUP BY q.id
     ORDER BY q.id DESC`);
  const list: Question[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new Question();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.subjectId = r.getLong(r.getColumnIndex('subjectId'));
      it.type = r.getLong(r.getColumnIndex('type'));
      it.content = r.getString(r.getColumnIndex('content'));
      it.options = r.getString(r.getColumnIndex('options'));
      it.answer = r.getString(r.getColumnIndex('answer'));
      it.explanation = r.getString(r.getColumnIndex('explanation'));
      it.kpNames = r.getString(r.getColumnIndex('kpNames'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

/** 知识点及其题目数量 */
class KpBrief {
  id: number = 0;
  name: string = '';
  count: number = 0;
}

async function getKpBriefs(subjectId: number): Promise<KpBrief[]> {
  const r = await getStore().querySql(
    `SELECT kp.id AS id, kp.name AS name, COUNT(qk.questionId) AS cnt
     FROM knowledge_point kp
     LEFT JOIN question_kp qk ON kp.id = qk.knowledgePointId
     WHERE kp.subjectId = ${subjectId}
     GROUP BY kp.id
     ORDER BY kp.sortOrder ASC, kp.id ASC`);
  const list: KpBrief[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new KpBrief();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.name = r.getString(r.getColumnIndex('name'));
      it.count = r.getLong(r.getColumnIndex('cnt'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

/** 知识小卡片：由知识点要点拆分出的一张卡片 */
class KnowledgeCard {
  title: string = '';
  icon: string = '';
  body: string = '';
  /** 0=关键概念 1=定理/公式 2=易错提醒 */
  tone: number = 0;
}

/** 易错提醒类关键词 */
const CARD_WARN_KEYS: string[] = ['易错', '注意', '慎用', '警惕', '避免', '防止', '不要', '不能',
  '区分', '易混', '只适用', '必须'];
/** 定理 / 公式类关键词 */
const CARD_FORMULA_KEYS: string[] = ['=', '∫', 'lim', '→', '⟺', '√', 'Σ', '∬', '′', '≈', '∝', 'dx', 'dy'];

/** 按句拆解要点文本（；与。为句界） */
function splitCardText(desc: string): string[] {
  const out: string[] = [];
  let buf = '';
  for (let i = 0; i < desc.length; i++) {
    const ch = desc.charAt(i);
    if (ch === '；' || ch === '。') {
      const s = buf.trim();
      if (s !== '') {
        out.push(s);
      }
      buf = '';
    } else {
      buf += ch;
    }
  }
  const rest = buf.trim();
  if (rest !== '') {
    out.push(rest);
  }
  return out;
}

function classifyCard(text: string): number {
  for (let i = 0; i < CARD_WARN_KEYS.length; i++) {
    if (text.indexOf(CARD_WARN_KEYS[i]) >= 0) {
      return 2;
    }
  }
  for (let i = 0; i < CARD_FORMULA_KEYS.length; i++) {
    if (text.indexOf(CARD_FORMULA_KEYS[i]) >= 0) {
      return 1;
    }
  }
  return 0;
}

/** 将要点文本拆成最多 6 张知识小卡片 */
function buildKnowledgeCards(desc: string): KnowledgeCard[] {
  const cards: KnowledgeCard[] = [];
  if (desc.trim() === '') {
    return cards;
  }
  const sentences = splitCardText(desc);
  for (let i = 0; i < sentences.length && cards.length < 6; i++) {
    const c = new KnowledgeCard();
    c.tone = classifyCard(sentences[i]);
    if (c.tone === 2) {
      c.icon = '⚠️';
      c.title = '易错提醒';
    } else if (c.tone === 1) {
      c.icon = '📐';
      c.title = '定理 / 公式';
    } else {
      c.icon = '💡';
      c.title = '关键概念';
    }
    c.body = sentences[i];
    cards.push(c);
  }
  return cards;
}

@Component
export struct QuestionDialog {
  @StorageLink('darkMode') darkMode: boolean = false;
  @Prop subjectId: number;
  @Prop kpId: number;
  onClose: () => void = () => {
  };
  // 文本字段使用普通成员（非受控输入）：击键时不触发弹窗/整页重建，输入更跟手
  content: string = '';
  optA: string = '';
  optB: string = '';
  optC: string = '';
  answer: string = 'A';
  explanation: string = '';
  /** 保存进行中标记，防止重复提交 */
  saving: boolean = false;
  @State type: number = 0;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  build() {
    Column() {
      Row() {
        Text('  新增题目')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('✖')
          .fontSize(16)
          .padding(8)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')

      Text('题干')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 12 })
        .alignSelf(ItemAlign.Start)
      TextInput({ placeholder: '题目内容' })
        .width('100%')
        .onChange((v: string) => {
          this.content = v;
        })

      Text('题型')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 10 })
        .alignSelf(ItemAlign.Start)
      Row() {
        this.typeChip(0, '单选')
        this.typeChip(1, '多选')
        this.typeChip(2, '判断')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Text('选项')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 10 })
        .alignSelf(ItemAlign.Start)
      TextInput({ placeholder: '选项 A' })
        .width('100%')
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.optA = v;
        })
      TextInput({ placeholder: '选项 B' })
        .width('100%')
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.optB = v;
        })
      TextInput({ placeholder: '选项 C' })
        .width('100%')
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.optC = v;
        })

      Text('正确答案')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 10 })
        .alignSelf(ItemAlign.Start)
      TextInput({ placeholder: '如 A / AB / 正确 / 错误' })
        .width('100%')
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.answer = v;
        })

      Text('答案解析')
        .fontSize(12)
        .fontColor(this.t().muted)
        .margin({ top: 10 })
        .alignSelf(ItemAlign.Start)
      TextInput({ placeholder: '解析（可留空）' })
        .width('100%')
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.explanation = v;
        })

      Row() {
        Blank()
        Button('保存')
          .backgroundColor(this.t().primary)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width(420)
    .padding(20)
    .backgroundColor(this.t().card)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  typeChip(t: number, label: string) {
    Text(label)
      .fontSize(13)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.type === t ? this.t().primary : this.t().chipBg)
      .fontColor(this.type === t ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.type = t;
      })
  }

  async save(): Promise<void> {
    if (this.saving) return;
    const content = this.content.trim();
    if (content === '') {
      AlertDialog.show({ message: '请填写题干' });
      return;
    }
    this.saving = true;
    try {
      const q = new Question();
      q.subjectId = this.subjectId;
      q.type = this.type;
      q.content = content;
      const opts: string[] = [];
      if (this.optA !== '') opts.push('A. ' + this.optA);
      if (this.optB !== '') opts.push('B. ' + this.optB);
      if (this.optC !== '') opts.push('C. ' + this.optC);
      q.options = JSON.stringify(opts);
      q.answer = this.answer.trim() === '' ? 'A' : this.answer.trim();
      q.explanation = this.explanation;
      const id = await insertQuestion(q);
      await insertQuestionKp(id, this.kpId);
      this.onClose();
    } catch (e) {
      console.error('add question failed: ' + JSON.stringify(e));
      AlertDialog.show({ message: '保存失败，请重试' });
    } finally {
      this.saving = false;
    }
  }
}