/**
 * 实体模型定义
 */

/** 学科 */
export class Subject {
  id: number = 0;
  name: string = '';
  questionCount: number = 0;
}

/** 知识点（支持树形） */
export class KnowledgePoint {
  id: number = 0;
  subjectId: number = 0;
  name: string = '';
  parentId: number = 0;
  sortOrder: number = 0;
  /** 知识点要点（概念、公式、易错提示） */
  description: string = '';
  /** 统计字段（运行时填充） */
  attempts: number = 0;
  wrong: number = 0;
  errorRate: number = 0;
  streak: number = 0;
  lastWrongDays: number = 999;
  score: number = 0;
}

/** 题目 */
export class Question {
  id: number = 0;
  subjectId: number = 0;
  type: number = 0; // 0单选 1多选 2判断
  content: string = '';
  options: string = ''; // JSON 数组，如 ["A.xx","B.xx"]
  answer: string = ''; // 单选 "A"；多选 "AB"；判断 "对/错"
  explanation: string = '';
  kpIds: number[] = []; // 关联知识点（运行时）
  kpNames: string = ''; // 展示用
}

/** 练习会话 */
export class Practice {
  id: number = 0;
  subjectId: number = 0;
  createdTime: number = 0;
  totalCount: number = 0;
  correctCount: number = 0;
  mode: number = 0; // 0 练习 1 模拟考
}

/** 单题作答记录 */
export class PracticeItem {
  id: number = 0;
  practiceId: number = 0;
  questionId: number = 0;
  isCorrect: number = 0; // 0/1
  userAnswer: string = '';
  spentSeconds: number = 0;
  /** 联表展示字段 */
  subjectId: number = 0;
  type: number = 0;
  questionContent: string = '';
  options: string = '';
  answer: string = '';
  explanation: string = '';
  createdTime: number = 0;
  kpNames: string = '';
}

/** 复习任务 */
export class ReviewTask {
  id: number = 0;
  knowledgePointId: number = 0;
  kpName: string = '';
  dueAt: number = 0;
  stage: number = 0; // 复习轮次 0..4
  createdAt: number = 0;
  /** 自定义计划备注 */
  note: string = '';
}

/** 薄弱点统计结果 */
export class WeakStat {
  kpId: number = 0;
  kpName: string = '';
  attempts: number = 0;
  wrong: number = 0;
  errorRate: number = 0;
  streak: number = 0;
  lastWrongDays: number = 999;
  lastWrongTs: number = 0;
  score: number = 0;
}

/** 某知识点随练习场次的正确率趋势点 */
export class TrendPoint {
  label: string = ''; // 场次序号或日期
  rate: number = 0;
}

/** 每日热力 */
export class DailyHeat {
  day: string = '';
  practiceCount: number = 0;
  correctRate: number = 0;
}

/** 能力维度（雷达图） */
export class DimStat {
  name: string = '';
  score: number = 0; // 0-100
}

/** 总览统计 */
export class OverallStat {
  questionCount: number = 0;
  subjectCount: number = 0;
  kpCount: number = 0;
  practiceCount: number = 0;
  totalAnswered: number = 0;
  totalCorrect: number = 0;
  overallRate: number = 0; // 0-100
  streakDays: number = 0; // 连续打卡天数
}

/** 学科维度统计 */
export class SubjectStat {
  subjectId: number = 0;
  name: string = '';
  count: number = 0; // 作答次数
  correct: number = 0;
  rate: number = 0; // 0-100
}

/** 练习记录（结果页历史） */
export class PracticeRecord {
  id: number = 0;
  subjectId: number = 0;
  subjectName: string = '';
  createdTime: number = 0;
  totalCount: number = 0;
  correctCount: number = 0;
  mode: number = 0;
  rate: number = 0; // 0-100
}