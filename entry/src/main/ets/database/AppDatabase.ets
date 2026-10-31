/**
 * RDB 数据库封装：建表 + 基础 DAO
 * 使用 relationalStore 本地关系型数据库
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Subject, KnowledgePoint, Question, Practice, PracticeItem, ReviewTask, PracticeRecord } from '../model/Entities';

const DB_NAME = 'mistake_book.db';
const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1,
};

let store: relationalStore.RdbStore | undefined = undefined;

/** 初始化数据库，创建表 */
export async function initDb(context: common.Context): Promise<boolean> {
  try {
    if (store) return true;
    store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await createTables();
    return true;
  } catch (e) {
    console.error('initDb failed: ' + JSON.stringify(e));
    return false;
  }
}

export function getStore(): relationalStore.RdbStore {
  if (!store) {
    throw new Error('DB not initialized');
  }
  return store;
}

async function createTables(): Promise<void> {
  const s = getStore();
  const sqls: string[] = [
    `CREATE TABLE IF NOT EXISTS subject (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL
     )`,
    `CREATE TABLE IF NOT EXISTS knowledge_point (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       subjectId INTEGER NOT NULL,
       name TEXT NOT NULL,
       parentId INTEGER DEFAULT 0,
       sortOrder INTEGER DEFAULT 0,
       description TEXT DEFAULT ''
     )`,
    `CREATE TABLE IF NOT EXISTS question (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       subjectId INTEGER NOT NULL,
       type INTEGER NOT NULL DEFAULT 0,
       content TEXT NOT NULL,
       options TEXT DEFAULT '',
       answer TEXT DEFAULT '',
       explanation TEXT DEFAULT ''
     )`,
    `CREATE TABLE IF NOT EXISTS question_kp (
       questionId INTEGER NOT NULL,
       knowledgePointId INTEGER NOT NULL
     )`,
    `CREATE TABLE IF NOT EXISTS practice (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       subjectId INTEGER NOT NULL,
       createdTime INTEGER NOT NULL,
       totalCount INTEGER NOT NULL,
       correctCount INTEGER NOT NULL,
       mode INTEGER NOT NULL DEFAULT 0
     )`,
    `CREATE TABLE IF NOT EXISTS practice_item (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       practiceId INTEGER NOT NULL,
       questionId INTEGER NOT NULL,
       isCorrect INTEGER NOT NULL DEFAULT 0,
       userAnswer TEXT DEFAULT '',
       spentSeconds INTEGER DEFAULT 0
     )`,
    `CREATE TABLE IF NOT EXISTS review_task (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       knowledgePointId INTEGER NOT NULL,
       dueAt INTEGER NOT NULL,
       stage INTEGER NOT NULL DEFAULT 0,
       createdAt INTEGER NOT NULL,
       note TEXT DEFAULT ''
     )`,
    `CREATE TABLE IF NOT EXISTS meta (
       key TEXT PRIMARY KEY,
       value TEXT NOT NULL DEFAULT ''
     )`,
    `CREATE TABLE IF NOT EXISTS mastered_question (
       questionId INTEGER PRIMARY KEY
     )`,
  ];
  for (let i = 0; i < sqls.length; i++) {
    await s.executeSql(sqls[i]);
  }
  // 兼容旧库：knowledge_point 新增 description（知识点要点）字段
  try {
    await s.executeSql(`ALTER TABLE knowledge_point ADD COLUMN description TEXT DEFAULT ''`);
  } catch (e) {
    // 字段已存在时忽略
  }
  // 兼容旧库：review_task 新增 note（自定义计划备注）字段
  try {
    await s.executeSql(`ALTER TABLE review_task ADD COLUMN note TEXT DEFAULT ''`);
  } catch (e) {
    // 字段已存在时忽略
  }
}

// ---------------- Subject DAO ----------------
export async function insertSubject(name: string): Promise<number> {
  const v: relationalStore.ValuesBucket = { 'name': name };
  return await getStore().insert('subject', v);
}

export async function getSubjects(): Promise<Subject[]> {
  const r = await getStore().querySql('SELECT * FROM subject ORDER BY id ASC');
  const list: Subject[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new Subject();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.name = r.getString(r.getColumnIndex('name'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

export async function deleteSubject(id: number): Promise<void> {
  // 级联：删除知识点 -> 题 -> 关联 -> 复习计划
  const kps = await getKps(id);
  for (let i = 0; i < kps.length; i++) {
    await deleteKp(kps[i].id);
  }
  const p = new relationalStore.RdbPredicates('subject');
  p.equalTo('id', id);
  await getStore().delete(p);
}

// ---------------- Meta（键值配置：种子版本等） ----------------
export async function getMeta(key: string): Promise<string> {
  const r = await getStore().querySql(
    `SELECT value FROM meta WHERE key = '${key}'`);
  try {
    if (r.goToNextRow()) {
      return r.getString(r.getColumnIndex('value'));
    }
  } finally {
    r.close();
  }
  return '';
}

export async function setMeta(key: string, value: string): Promise<void> {
  const v: relationalStore.ValuesBucket = { 'key': key, 'value': value };
  // key 为主键：重复写入需 REPLACE，否则触发 UNIQUE 约束失败导致重置流程中断
  await getStore().insert('meta', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
}

// ---------------- 已掌握错题 ----------------
export async function insertMasteredQuestion(questionId: number): Promise<void> {
  const v: relationalStore.ValuesBucket = { 'questionId': questionId };
  // questionId 为主键：同一题多次标记已掌握需 REPLACE，避免 UNIQUE 约束失败
  await getStore().insert('mastered_question', v, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
}

export async function getMasteredQuestions(): Promise<number[]> {
  const r = await getStore().querySql('SELECT questionId FROM mastered_question');
  const ids: number[] = [];
  try {
    while (r.goToNextRow()) {
      ids.push(r.getLong(r.getColumnIndex('questionId')));
    }
  } finally {
    r.close();
  }
  return ids;
}

// ---------------- KnowledgePoint DAO ----------------
export async function insertKp(subjectId: number, name: string, parentId: number,
  description: string = ''): Promise<number> {
  const v: relationalStore.ValuesBucket = {
    'subjectId': subjectId,
    'name': name,
    'parentId': parentId,
    'sortOrder': 0,
    'description': description
  };
  return await getStore().insert('knowledge_point', v);
}

/** 更新知识点要点（预置内容升级时补齐） */
export async function setKpDescription(id: number, description: string): Promise<void> {
  const v: relationalStore.ValuesBucket = { 'description': description };
  const p = new relationalStore.RdbPredicates('knowledge_point');
  p.equalTo('id', id);
  await getStore().update(v, p);
}

export async function getKps(subjectId: number): Promise<KnowledgePoint[]> {
  let r: relationalStore.ResultSet;
  if (subjectId > 0) {
    const p = new relationalStore.RdbPredicates('knowledge_point');
    p.equalTo('subjectId', subjectId);
    p.orderByAsc('sortOrder');
    p.orderByAsc('id');
    r = await getStore().query(p, ['id', 'subjectId', 'name', 'parentId', 'sortOrder', 'description']);
  } else {
    r = await getStore().querySql('SELECT id, subjectId, name, parentId, sortOrder, description FROM knowledge_point ORDER BY sortOrder ASC, id ASC');
  }
  const list: KnowledgePoint[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new KnowledgePoint();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.subjectId = r.getLong(r.getColumnIndex('subjectId'));
      it.name = r.getString(r.getColumnIndex('name'));
      it.parentId = r.getLong(r.getColumnIndex('parentId'));
      it.sortOrder = r.getLong(r.getColumnIndex('sortOrder'));
      it.description = r.getString(r.getColumnIndex('description'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

export async function deleteKp(id: number): Promise<void> {
  const p = new relationalStore.RdbPredicates('knowledge_point');
  p.equalTo('id', id);
  await getStore().delete(p);
  const p2 = new relationalStore.RdbPredicates('question_kp');
  p2.equalTo('knowledgePointId', id);
  await getStore().delete(p2);
  const p3 = new relationalStore.RdbPredicates('review_task');
  p3.equalTo('knowledgePointId', id);
  await getStore().delete(p3);
}

export async function deleteMasteredQuestion(questionId: number): Promise<void> {
  const p = new relationalStore.RdbPredicates('mastered_question');
  p.equalTo('questionId', questionId);
  await getStore().delete(p);
}

// ---------------- Question DAO ----------------
export async function insertQuestion(q: Question): Promise<number> {
  const v: relationalStore.ValuesBucket = {
    'subjectId': q.subjectId,
    'type': q.type,
    'content': q.content,
    'options': q.options,
    'answer': q.answer,
    'explanation': q.explanation
  };
  return await getStore().insert('question', v);
}

export async function insertQuestionKp(qid: number, kpid: number): Promise<void> {
  const v: relationalStore.ValuesBucket = { 'questionId': qid, 'knowledgePointId': kpid };
  await getStore().insert('question_kp', v);
}

export async function getQuestions(subjectId: number): Promise<Question[]> {
  const r = await getStore().querySql(
    `SELECT q.id, q.subjectId, q.type, q.content, q.options, q.answer, q.explanation,
            GROUP_CONCAT(kp.name) AS kpNames
     FROM question q
     LEFT JOIN question_kp qk ON q.id = qk.questionId
     LEFT JOIN knowledge_point kp ON qk.knowledgePointId = kp.id
     WHERE q.subjectId = ${subjectId}
     GROUP BY q.id
     ORDER BY q.id ASC`);
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
      const names = r.getString(r.getColumnIndex('kpNames'));
      it.kpNames = names;
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

export async function deleteQuestion(id: number): Promise<void> {
  const p = new relationalStore.RdbPredicates('question');
  p.equalTo('id', id);
  await getStore().delete(p);
  const p2 = new relationalStore.RdbPredicates('question_kp');
  p2.equalTo('questionId', id);
  await getStore().delete(p2);
}

// ---------------- Practice DAO ----------------
export async function insertPractice(p: Practice): Promise<number> {
  const v: relationalStore.ValuesBucket = {
    'subjectId': p.subjectId,
    'createdTime': p.createdTime,
    'totalCount': p.totalCount,
    'correctCount': p.correctCount,
    'mode': p.mode
  };
  return await getStore().insert('practice', v);
}

export async function insertPracticeItem(it: PracticeItem): Promise<number> {
  const v: relationalStore.ValuesBucket = {
    'practiceId': it.practiceId,
    'questionId': it.questionId,
    'isCorrect': it.isCorrect,
    'userAnswer': it.userAnswer,
    'spentSeconds': it.spentSeconds
  };
  return await getStore().insert('practice_item', v);
}

export async function getPracticeItems(): Promise<PracticeItem[]> {
  const r = await getStore().querySql(
    `SELECT pi.id, pi.practiceId, pi.questionId, pi.isCorrect, pi.userAnswer, pi.spentSeconds,
            p.createdTime AS createdTime, q.subjectId AS subjectId, q.content AS qContent,
            q.answer AS qAnswer, q.explanation AS qExplanation, kp.name AS kpNames
     FROM practice_item pi
     LEFT JOIN practice p ON pi.practiceId = p.id
     LEFT JOIN question q ON pi.questionId = q.id
     LEFT JOIN question_kp qk ON pi.questionId = qk.questionId
     LEFT JOIN knowledge_point kp ON qk.knowledgePointId = kp.id
     ORDER BY pi.id ASC`);
  const list: PracticeItem[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new PracticeItem();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.practiceId = r.getLong(r.getColumnIndex('practiceId'));
      it.questionId = r.getLong(r.getColumnIndex('questionId'));
      it.isCorrect = r.getLong(r.getColumnIndex('isCorrect'));
      it.userAnswer = r.getString(r.getColumnIndex('userAnswer'));
      it.spentSeconds = r.getLong(r.getColumnIndex('spentSeconds'));
      it.createdTime = r.getLong(r.getColumnIndex('createdTime'));
      it.subjectId = r.getLong(r.getColumnIndex('subjectId'));
      it.questionContent = r.getString(r.getColumnIndex('qContent'));
      it.answer = r.getString(r.getColumnIndex('qAnswer'));
      it.explanation = r.getString(r.getColumnIndex('qExplanation'));
      it.kpNames = r.getString(r.getColumnIndex('kpNames'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

// ---------------- ReviewTask DAO ----------------
export async function insertReviewTask(kpId: number, dueAt: number, stage: number,
  note: string = ''): Promise<number> {
  const v: relationalStore.ValuesBucket = {
    'knowledgePointId': kpId,
    'dueAt': dueAt,
    'stage': stage,
    'createdAt': Date.now(),
    'note': note
  };
  return await getStore().insert('review_task', v);
}

/** 调整计划时间（自由改期） */
export async function updateReviewTaskDue(id: number, dueAt: number): Promise<void> {
  const v: relationalStore.ValuesBucket = { 'dueAt': dueAt };
  const p = new relationalStore.RdbPredicates('review_task');
  p.equalTo('id', id);
  await getStore().update(v, p);
}

export async function getReviewTasks(): Promise<ReviewTask[]> {
  const r = await getStore().querySql(
    `SELECT t.id, t.knowledgePointId, t.dueAt, t.stage, t.createdAt, t.note, kp.name AS kpName
     FROM review_task t
     LEFT JOIN knowledge_point kp ON t.knowledgePointId = kp.id
     ORDER BY t.dueAt ASC`);
  const list: ReviewTask[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new ReviewTask();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.knowledgePointId = r.getLong(r.getColumnIndex('knowledgePointId'));
      it.dueAt = r.getLong(r.getColumnIndex('dueAt'));
      it.stage = r.getLong(r.getColumnIndex('stage'));
      it.createdAt = r.getLong(r.getColumnIndex('createdAt'));
      it.note = r.getString(r.getColumnIndex('note'));
      it.kpName = r.getString(r.getColumnIndex('kpName'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

export async function deleteReviewTask(id: number): Promise<void> {
  const p = new relationalStore.RdbPredicates('review_task');
  p.equalTo('id', id);
  await getStore().delete(p);
}

// ---------------- Practice 记录 ----------------
export async function getPractices(): Promise<PracticeRecord[]> {
  const r = await getStore().querySql(
    `SELECT p.id, p.subjectId, p.createdTime, p.totalCount, p.correctCount, p.mode, s.name AS subjectName
     FROM practice p
     LEFT JOIN subject s ON p.subjectId = s.id
     ORDER BY p.createdTime DESC`);
  const list: PracticeRecord[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new PracticeRecord();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.subjectId = r.getLong(r.getColumnIndex('subjectId'));
      it.createdTime = r.getLong(r.getColumnIndex('createdTime'));
      it.totalCount = r.getLong(r.getColumnIndex('totalCount'));
      it.correctCount = r.getLong(r.getColumnIndex('correctCount'));
      it.mode = r.getLong(r.getColumnIndex('mode'));
      it.subjectName = r.getString(r.getColumnIndex('subjectName'));
      it.rate = it.totalCount > 0 ? Math.round(it.correctCount / it.totalCount * 100) : 0;
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}

/** 单次练习/考试的答题明细（含题干、选项、答案、解析、知识点） */
export async function getPracticeItemsByPractice(practiceId: number): Promise<PracticeItem[]> {
  const r = await getStore().querySql(
    `SELECT pi.id, pi.practiceId, pi.questionId, pi.isCorrect, pi.userAnswer, pi.spentSeconds,
            q.type AS qType, q.content AS qContent, q.options AS qOptions,
            q.answer AS qAnswer, q.explanation AS qExplanation,
            GROUP_CONCAT(kp.name) AS kpNames
     FROM practice_item pi
     LEFT JOIN question q ON pi.questionId = q.id
     LEFT JOIN question_kp qk ON pi.questionId = qk.questionId
     LEFT JOIN knowledge_point kp ON qk.knowledgePointId = kp.id
     WHERE pi.practiceId = ${practiceId}
     GROUP BY pi.id
     ORDER BY pi.id ASC`);
  const list: PracticeItem[] = [];
  try {
    while (r.goToNextRow()) {
      const it = new PracticeItem();
      it.id = r.getLong(r.getColumnIndex('id'));
      it.practiceId = r.getLong(r.getColumnIndex('practiceId'));
      it.questionId = r.getLong(r.getColumnIndex('questionId'));
      it.isCorrect = r.getLong(r.getColumnIndex('isCorrect'));
      it.userAnswer = r.getString(r.getColumnIndex('userAnswer'));
      it.spentSeconds = r.getLong(r.getColumnIndex('spentSeconds'));
      it.type = r.getLong(r.getColumnIndex('qType'));
      it.questionContent = r.getString(r.getColumnIndex('qContent'));
      it.options = r.getString(r.getColumnIndex('qOptions'));
      it.answer = r.getString(r.getColumnIndex('qAnswer'));
      it.explanation = r.getString(r.getColumnIndex('qExplanation'));
      it.kpNames = r.getString(r.getColumnIndex('kpNames'));
      list.push(it);
    }
  } finally {
    r.close();
  }
  return list;
}