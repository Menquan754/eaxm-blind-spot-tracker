/**
 * 练习服务：选题、判分、落库
 */
import { getQuestions, insertPractice, insertPracticeItem } from '../database/AppDatabase';
import { Question, Practice, PracticeItem } from '../model/Entities';
import { getStore } from '../database/AppDatabase';
import { sortedLetters } from '../common/Utils';
import { relationalStore } from '@kit.ArkData';

/** 练习配置 */
export interface PracticeConfig {
  subjectId: number;
  kpId: number; // 0 = 全部
  count: number;
  mode: number; // 0 练习 1 模拟考
}

/** 根据配置选取题目（智能出题：可传重点知识点列表加权，此处简化先随机） */
export async function pickQuestions(cfg: PracticeConfig): Promise<Question[]> {
  let all = await getQuestions(cfg.subjectId);
  if (cfg.kpId > 0) {
    // 只保留属于该知识点的题目
    const filtered: Question[] = [];
    const qk = await getStore().querySql(
      `SELECT questionId FROM question_kp WHERE knowledgePointId = ${cfg.kpId}`);
    const ownIds: number[] = [];
    try {
      while (qk.goToNextRow()) {
        ownIds.push(qk.getLong(qk.getColumnIndex('questionId')));
      }
    } finally {
      qk.close();
    }
    for (let i = 0; i < all.length; i++) {
      if (ownIds.indexOf(all[i].id) >= 0) filtered.push(all[i]);
    }
    all = filtered;
  }
  // Fisher-Yates 洗牌
  for (let i = all.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const t = all[i];
    all[i] = all[j];
    all[j] = t;
  }
  return all.slice(0, Math.min(cfg.count, all.length));
}

/** 判定单题对错。userAnswer: 单选字母 / 多选字母串 / 判断对错 / 简答文本 */
export function judge(question: Question, userAnswer: string): boolean {
  const type = question.type;
  if (type === 0 || type === 1) {
    return sortedLetters(question.answer) === sortedLetters(userAnswer);
  }
  if (type === 2) {
    return question.answer === userAnswer;
  }
  // 简答：当前简化——用户自评，内部统一返回 answer 非空视为需自评
  return question.answer === userAnswer || userAnswer.length === 0;
}

/** 提交练习：写入 practice + practice_item */
export async function submitPractice(cfg: PracticeConfig, questionIds: number[],
  answers: string[], results: boolean[], seconds: number[]): Promise<number> {
  const p = new Practice();
  p.subjectId = cfg.subjectId;
  p.createdTime = Date.now();
  p.totalCount = questionIds.length;
  let correct = 0;
  for (let i = 0; i < results.length; i++) {
    if (results[i]) correct += 1;
  }
  p.correctCount = correct;
  p.mode = cfg.mode;
  const pid = await insertPractice(p);
  for (let i = 0; i < questionIds.length; i++) {
    const it = new PracticeItem();
    it.practiceId = pid;
    it.questionId = questionIds[i];
    it.isCorrect = results[i] ? 1 : 0;
    it.userAnswer = answers[i];
    it.spentSeconds = seconds[i];
    await insertPracticeItem(it);

    // 答错的知识点自动进入复习计划
    if (!results[i]) {
      const kps = await kpIdsOf(questionIds[i]);
      const now = Date.now();
      for (let k = 0; k < kps.length; k++) {
        const due = now + 1 * 86400000; // 首轮复习：明天
        const v: relationalStore.ValuesBucket = {
          'knowledgePointId': kps[k],
          'dueAt': due,
          'stage': 0,
          'createdAt': now
        };
        try {
          await getStore().insert('review_task', v);
        } catch (e) {
          console.error('insert review failed: ' + JSON.stringify(e));
        }
      }
    }
  }
  return pid;
}

async function kpIdsOf(questionId: number): Promise<number[]> {
  const r = await getStore().querySql(
    `SELECT knowledgePointId FROM question_kp WHERE questionId = ${questionId}`);
  const ids: number[] = [];
  try {
    while (r.goToNextRow()) {
      ids.push(r.getLong(r.getColumnIndex('knowledgePointId')));
    }
  } finally {
    r.close();
  }
  return ids;
}