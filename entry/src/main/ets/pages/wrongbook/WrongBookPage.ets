/**
 * 错题本：按知识点筛选，展示错题及解析，可标记已掌握/导出 JSON
 */
import { getPracticeItems, getKps, insertMasteredQuestion, getMasteredQuestions } from '../../database/AppDatabase';
import { PracticeItem, KnowledgePoint } from '../../model/Entities';
import { themeOf, ThemeColors } from '../../common/Theme';
import { dateFull } from '../../common/Utils';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';

class WrongExportItem {
  question: string = '';
  userAnswer: string = '';
  answer: string = '';
  explanation: string = '';
  kpNames: string = '';
  time: string = '';
}

@Component
export struct WrongBookPage {
  @StorageLink('darkMode') darkMode: boolean = false;
  @State items: PracticeItem[] = [];
  @State kps: KnowledgePoint[] = [];
  @State filterKp: number = 0;
  @State elapsed: number = 0;

  t(): ThemeColors {
    return themeOf(this.darkMode);
  }

  async aboutToAppear(): Promise<void> {
    try {
      this.kps = await getKps(0);
    } catch (e) {
      console.error('load wrongbook kps failed: ' + JSON.stringify(e));
      this.kps = [];
    }
    await this.load();
  }

  async load(): Promise<void> {
    try {
      const all = await getPracticeItems();
      const mastered = await getMasteredQuestions();
      let wrong = all.filter(v => v.isCorrect === 0 && mastered.indexOf(v.questionId) < 0);
      if (this.filterKp > 0) {
        wrong = wrong.filter(v => v.kpNames !== undefined && v.kpNames !== '' &&
          v.kpNames.indexOf(this.kpName(this.filterKp)) >= 0);
      }
      this.items = wrong;
      this.elapsed += 1;
    } catch (e) {
      console.error('load wrongbook failed: ' + JSON.stringify(e));
      this.items = [];
    }
  }

  kpName(id: number): string {
    for (let i = 0; i < this.kps.length; i++) {
      if (this.kps[i].id === id) return this.kps[i].name;
    }
    return '';
  }

  build() {
    Column() {
      Row() {
        Text('📝 错题本（' + this.items.length + ' 题）')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('⬇ 导出')
          .height(30)
          .fontSize(12)
          .backgroundColor(this.t().chipBg)
          .fontColor(this.t().subText)
          .onClick(() => {
            this.exportJson();
          })
        // 筛选
        this.filterChip(0, '全部')
        Scroll() {
          Row() {
            ForEach(this.kps, (kp: KnowledgePoint) => {
              this.filterChip(kp.id, kp.name)
            }, (kp: KnowledgePoint) => kp.id.toString())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('40%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      Scroll() {
        Column() {
          if (this.items.length === 0) {
            Text('🎉 暂无错题，太棒了！')
              .fontSize(14)
              .fontColor(this.t().muted)
              .margin({ top: 60 })
          } else {
            ForEach(this.items, (it: PracticeItem) => {
              Column() {
                Row() {
                  Text(it.questionContent)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Start)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')

                Row() {
                  Text('你的答案：' + (it.userAnswer === '' ? '未作答' : it.userAnswer))
                    .fontSize(12)
                    .fontColor(this.t().bad)
                  Text(' 正确答案：' + it.answer)
                    .fontSize(12)
                    .fontColor(this.t().ok)
                }
                .width('100%')
                .margin({ top: 8 })

                if (it.explanation !== '') {
                  Text('解析：' + it.explanation)
                    .fontSize(13)
                    .fontColor(this.t().subText)
                    .width('100%')
                    .margin({ top: 6 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                Row() {
                  Text(it.kpNames === '' ? '未关联知识点' : '📌 ' + it.kpNames)
                    .fontSize(11)
                    .fontColor(this.t().muted)
                  Text(dateFull(it.createdTime))
                    .fontSize(11)
                    .fontColor(this.t().muted)
                    .margin({ left: 12 })
                }
                .width('100%')
                .margin({ top: 10 })

                // 操作行独立成行（避免 Row+Blank+尾部可点击 Text 组合下按钮不渲染）
                Row() {
                  Text('已掌握 ✓')
                    .fontSize(12)
                    .fontColor(this.t().primary)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10)
                    .backgroundColor(this.t().selectedBg)
                    .onClick(() => {
                      this.markMastered(it);
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
                .margin({ top: 8 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.t().card)
              .borderRadius(10)
              .margin({ top: 10 })
            }, (it: PracticeItem) => it.id.toString() + it.practiceId.toString())
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
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
  filterChip(id: number, name: string) {
    Text(name)
      .fontSize(13)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .backgroundColor(this.filterKp === id ? this.t().primary : this.t().chipBg)
      .fontColor(this.filterKp === id ? '#FFFFFF' : this.t().subText)
      .borderRadius(16)
      .onClick(() => {
        this.filterKp = id;
        this.load();
      })
  }

  /** 标记已掌握：持久化到 mastered_question，之后不再出现在错题本 */
  async markMastered(it: PracticeItem): Promise<void> {
    try {
      await insertMasteredQuestion(it.questionId);
      this.items = this.items.filter((v: PracticeItem) => v.id !== it.id);
      promptAction.showToast({ message: '已标记掌握', duration: 1200 });
    } catch (e) {
      console.error('markMastered failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
    }
  }

  /** 导出错题 JSON 到应用沙箱 */
  async exportJson(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const path = ctx.filesDir + '/wrong_book_' + Date.now() + '.json';
      const arr: WrongExportItem[] = [];
      for (let i = 0; i < this.items.length; i++) {
        const it = this.items[i];
        const e = new WrongExportItem();
        e.question = it.questionContent;
        e.userAnswer = it.userAnswer;
        e.answer = it.answer;
        e.explanation = it.explanation;
        e.kpNames = it.kpNames;
        e.time = dateFull(it.createdTime);
        arr.push(e);
      }
      const fd = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        fs.writeSync(fd.fd, JSON.stringify(arr));
      } finally {
        fs.closeSync(fd.fd);
      }
      promptAction.showToast({ message: '已导出 ' + this.items.length + ' 条错题', duration: 2000 });
    } catch (e) {
      console.error('exportJson failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '导出失败，请重试', duration: 2000 });
    }
  }
}