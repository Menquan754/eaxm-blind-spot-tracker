/**
 * 种子数据：首次启动 / 版本升级时写入大学课程库
 * - seedIfEmpty：增量补齐缺失的预置学科/知识点/题目，保留用户数据与练习记录
 * - reseedNow：清空后完整重建（设置页“重置预置大学课程”）
 * 数据内容见 SeedData.ets，升级 SEED_VERSION 即可自动补齐新增内容
 */
import {
  insertSubject, insertKp, insertQuestion, insertQuestionKp, setKpDescription,
  getMeta, setMeta, getSubjects, getKps, getQuestions, getStore
} from '../database/AppDatabase';
import { SEED_SUBJECTS, SeedSubject, SeedKp, SeedQ, kpDescription } from './SeedData';
import { Question } from '../model/Entities';
import { relationalStore } from '@kit.ArkData';

export const SEED_VERSION: string = '4';

/** 幂等种子：版本不一致或库为空时补齐预置内容（增量，不删除已有数据） */
export async function seedIfEmpty(): Promise<boolean> {
  try {
    const v = await getMeta('seedVersion');
    if (v === SEED_VERSION) {
      const subs = await getSubjects();
      if (subs.length > 0) return false;
    }
    await seedLibrary();
    await setMeta('seedVersion', SEED_VERSION);
    return true;
  } catch (e) {
    console.error('seed failed: ' + JSON.stringify(e));
    return false;
  }
}

/** 从设置页可手动调用：清空后重新预置大学课程库 */
export async function reseedNow(): Promise<boolean> {
  await resetSeedData();
  await seedLibrary();
  await setMeta('seedVersion', SEED_VERSION);
  return true;
}

async function resetSeedData(): Promise<void> {
  const st = getStore();
  const tables: string[] = ['review_task', 'practice_item', 'practice', 'mastered_question',
    'question_kp', 'question', 'knowledge_point', 'subject'];
  for (let i = 0; i < tables.length; i++) {
    const p = new relationalStore.RdbPredicates(tables[i]);
    await st.delete(p);
  }
}

/** 按“学科名 / 知识点名 / 题干”去重，只补充库中缺失的条目 */
async function seedLibrary(): Promise<void> {
  const seededSubjects = await getSubjects();
  for (let i = 0; i < SEED_SUBJECTS.length; i++) {
    const ss: SeedSubject = SEED_SUBJECTS[i];
    let sid = 0;
    for (let j = 0; j < seededSubjects.length; j++) {
      if (seededSubjects[j].name === ss.name) {
        sid = seededSubjects[j].id;
        break;
      }
    }
    if (sid === 0) {
      sid = await insertSubject(ss.name);
    }
    const kps = await getKps(sid);
    const questions: Question[] = await getQuestions(sid);
    for (let k = 0; k < ss.kps.length; k++) {
      const skp: SeedKp = ss.kps[k];
      let kid = 0;
      for (let m = 0; m < kps.length; m++) {
        if (kps[m].name === skp.name) {
          kid = kps[m].id;
          break;
        }
      }
      if (kid === 0) {
        kid = await insertKp(sid, skp.name, 0, skp.description);
      } else {
        // 已有知识点：补写要点内容（不覆盖用户自定义非空描述）
        let oldDesc = '';
        for (let m = 0; m < kps.length; m++) {
          if (kps[m].id === kid) {
            oldDesc = kps[m].description;
            break;
          }
        }
        if (oldDesc === '') {
          await setKpDescription(kid, skp.description);
        }
      }
      for (let n = 0; n < skp.questions.length; n++) {
        const sq: SeedQ = skp.questions[n];
        let duplicated = false;
        for (let p = 0; p < questions.length; p++) {
          if (questions[p].content === sq.content) {
            duplicated = true;
            break;
          }
        }
        if (duplicated) {
          continue;
        }
        const qq = new Question();
        qq.subjectId = sid;
        qq.type = sq.type;
        qq.content = sq.content;
        qq.options = JSON.stringify(sq.options);
        qq.answer = sq.answer;
        qq.explanation = sq.explanation;
        const qid = await insertQuestion(qq);
        await insertQuestionKp(qid, kid);
        // 同一次种子中避免重复写入同一题干
        questions.push(qq);
      }
    }
  }
  // 补全历史知识点（名称不在预置清单中）的要点内容
  const all = await getSubjects();
  for (let i = 0; i < all.length; i++) {
    const list = await getKps(all[i].id);
    for (let j = 0; j < list.length; j++) {
      if (list[j].description === '') {
        const d = kpDescription(list[j].name);
        if (d !== '') {
          await setKpDescription(list[j].id, d);
        }
      }
    }
  }
}
