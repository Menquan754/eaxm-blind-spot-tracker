/**
 * 统计服务：总体统计 / 学科正确率 / 连续打卡 / 不同学科总体情况
 */
import { getStore, getPracticeItems, getSubjects } from '../database/AppDatabase';
import { OverallStat, SubjectStat, PracticeItem } from '../model/Entities';

function pad2(n: number): string {
  return n < 10 ? ('0' + n) : ('' + n);
}

function dayKey(d: Date): string {
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

/** 连续打卡天数（今天或昨天开始连续有练习） */
export function calcStreak(items: PracticeItem[]): number {
  const days = new Set<string>();
  for (let i = 0; i < items.length; i++) {
    days.add(dayKey(new Date(items[i].createdTime)));
  }
  let streak = 0;
  const d = new Date();
  if (!days.has(dayKey(d))) {
    d.setDate(d.getDate() - 1);
    if (!days.has(dayKey(d))) {
      return 0;
    }
  }
  while (days.has(dayKey(d))) {
    streak += 1;
    d.setDate(d.getDate() - 1);
  }
  return streak;
}

/** 总览统计卡片 */
export async function getOverallStats(): Promise<OverallStat> {
  const s = new OverallStat();
  const subs = await getSubjects();
  s.subjectCount = subs.length;
  const r = await getStore().querySql(
    `SELECT (SELECT COUNT(*) FROM question) AS qc,
            (SELECT COUNT(*) FROM knowledge_point) AS kc,
            (SELECT COUNT(*) FROM practice) AS pc`);
  try {
    if (r.goToNextRow()) {
      s.questionCount = r.getLong(r.getColumnIndex('qc'));
      s.kpCount = r.getLong(r.getColumnIndex('kc'));
      s.practiceCount = r.getLong(r.getColumnIndex('pc'));
    }
  } finally {
    r.close();
  }
  const items = await getPracticeItems();
  s.totalAnswered = items.length;
  let correct = 0;
  for (let i = 0; i < items.length; i++) {
    if (items[i].isCorrect === 1) correct += 1;
  }
  s.totalCorrect = correct;
  s.overallRate = s.totalAnswered > 0 ? Math.round(correct / s.totalAnswered * 100) : 0;
  s.streakDays = calcStreak(items);
  return s;
}

/** 按学科统计作答数与正确率 */
export async function getSubjectStats(): Promise<SubjectStat[]> {
  const subs = await getSubjects();
  const items = await getPracticeItems();
  const map: Map<number, number[]> = new Map<number, number[]>();
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    let agg = map.get(it.subjectId);
    if (agg === undefined) {
      agg = [0, 0];
      map.set(it.subjectId, agg);
    }
    agg[0] += 1;
    if (it.isCorrect === 1) agg[1] += 1;
  }
  const out: SubjectStat[] = [];
  for (let i = 0; i < subs.length; i++) {
    const st = new SubjectStat();
    st.subjectId = subs[i].id;
    st.name = subs[i].name;
    const agg = map.get(subs[i].id);
    st.count = agg !== undefined ? agg[0] : 0;
    st.correct = agg !== undefined ? agg[1] : 0;
    st.rate = st.count > 0 ? Math.round(st.correct / st.count * 100) : 0;
    out.push(st);
  }
  out.sort((a, b) => b.count - a.count);
  return out;
}

/** 学科题量统计（知识点页 / 首页用） */
export async function getSubjectQuestionCounts(): Promise<Map<number, number>> {
  const map: Map<number, number> = new Map<number, number>();
  const r = await getStore().querySql(
    `SELECT subjectId, COUNT(*) AS c FROM question GROUP BY subjectId`);
  try {
    while (r.goToNextRow()) {
      map.set(r.getLong(r.getColumnIndex('subjectId')), r.getLong(r.getColumnIndex('c')));
    }
  } finally {
    r.close();
  }
  return map;
}