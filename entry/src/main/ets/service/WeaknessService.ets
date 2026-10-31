/**
 * 薄弱点分析服务：聚合作答记录 -> 计算指标 -> 薄弱度评分 -> 趋势数据
 * score = W_ERR_RATE*错误率 + W_STREAK*min(连续出错,5)/5 + W_RECENT*(1/(最近出错天数+1))
 */
import { getPracticeItems, getKps, getStore } from '../database/AppDatabase';
import { PracticeItem, WeakStat, TrendPoint, DailyHeat, DimStat } from '../model/Entities';
import { clamp, daysSince } from '../common/Utils';

/** 读取题目 -> 知识点的映射 */
async function loadQuestionKpMap(): Promise<Map<number, number[]>> {
  const map: Map<number, number[]> = new Map<number, number[]>();
  const r = await getStore().querySql('SELECT questionId, knowledgePointId FROM question_kp');
  try {
    while (r.goToNextRow()) {
      const qid = r.getLong(r.getColumnIndex('questionId'));
      const kpid = r.getLong(r.getColumnIndex('knowledgePointId'));
      let arr = map.get(qid);
      if (arr === undefined) {
        arr = [];
        map.set(qid, arr);
      }
      arr.push(kpid);
    }
  } finally {
    r.close();
  }
  return map;
}

/**
 * 主入口：统计全部知识点的薄弱指标，按薄弱度降序
 */
export async function getWeakStats(): Promise<WeakStat[]> {
  const results: WeakStat[] = [];
  const qkMap = await loadQuestionKpMap();
  const items = await getPracticeItems();

  // 训练缓存：kpId -> {total, wrong, lastWrongTs}
  const cache: Map<number, WeakStat> = new Map<number, WeakStat>();
  // 每场练习中出错的 kpId 去重集合
  const practiceWrongKps: Map<number, number[]> = new Map<number, number[]>();
  const practiceOrder: Map<number, number> = new Map<number, number>();

  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    const kps = qkMap.get(it.questionId);
    if (kps === undefined) continue;
    for (let k = 0; k < kps.length; k++) {
      const kpid = kps[k];
      let ws = cache.get(kpid);
      if (ws === undefined) {
        ws = new WeakStat();
        ws.kpId = kpid;
        cache.set(kpid, ws);
      }
      ws.attempts += 1;
      if (it.isCorrect === 0) {
        ws.wrong += 1;
        if (it.createdTime > ws.lastWrongDays) {
          // 用 lastWrongDays 暂存最近出错时间戳
          ws.lastWrongTs = it.createdTime;
        }
        let arr = practiceWrongKps.get(it.practiceId);
        if (arr === undefined) {
          arr = [];
          practiceWrongKps.set(it.practiceId, arr);
        }
        if (arr.indexOf(kpid) < 0) arr.push(kpid);
      }
      if (!practiceOrder.has(it.practiceId)) {
        practiceOrder.set(it.practiceId, it.createdTime);
      }
    }
  }

  // 计算连续出错场次
  const practiceIds: number[] = Array.from(practiceOrder.keys());
  practiceIds.sort((a, b) => {
    const ta = practiceOrder.get(a) as number;
    const tb = practiceOrder.get(b) as number;
    return tb - ta;
  });

  const kpRows = await getStore().querySql('SELECT id, name FROM knowledge_point');
  try {
    while (kpRows.goToNextRow()) {
      const kpid = kpRows.getLong(kpRows.getColumnIndex('id'));
      const ws = cache.get(kpid);
      if (ws === undefined) continue;
      ws.kpName = kpRows.getString(kpRows.getColumnIndex('name'));
      ws.errorRate = ws.attempts > 0 ? ws.wrong / ws.attempts : 0;
      ws.streak = calcStreak(kpid, practiceIds, practiceWrongKps);
      ws.lastWrongDays = ws.lastWrongTs > 0 ? daysSince(ws.lastWrongTs) : 999;
      ws.score = calcScore(ws);
      results.push(ws);
    }
  } finally {
    kpRows.close();
  }
  results.sort((a, b) => b.score - a.score);
  return results;
}

/** 连续出错场次数：倒序遍历练习，直到遇到该知识点没出错的场次为止（最多统计近 10 场） */
function calcStreak(kpid: number, practiceIds: number[], practiceWrongKps: Map<number, number[]>): number {
  let streak = 0;
  const maxScan = Math.min(practiceIds.length, 10);
  for (let i = 0; i < maxScan; i++) {
    const arr = practiceWrongKps.get(practiceIds[i]);
    if (arr !== undefined && arr.indexOf(kpid) >= 0) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

export function calcScore(ws: WeakStat): number {
  const errPart = ws.errorRate * 0.5;
  const streakPart = clamp(ws.streak, 0, 5) / 5 * 0.3;
  const recentPart = clamp(1.0 / (ws.lastWrongDays + 1), 0, 1) * 0.2;
  return Math.round((errPart + streakPart + recentPart) * 100);
}

/** 某个知识点的趋势：最近 N 场练习的正确率 */
export async function getKpTrend(kpId: number): Promise<TrendPoint[]> {
  const qkMap = await loadQuestionKpMap();
  const items = await getPracticeItems();

  const qids: number[] = [];
  qkMap.forEach((v, k) => {
    if (v.indexOf(kpId) >= 0) qids.push(k);
  });
  if (qids.length === 0) return [];

  // 按练习场次聚合
  const byPractice: Map<number, number[]> = new Map<number, number[]>(); // practiceId -> [total, correct, ts]
  const practiceTs: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    if (qids.indexOf(it.questionId) < 0) continue;
    let agg = byPractice.get(it.practiceId);
    if (agg === undefined) {
      agg = [0, 0, it.createdTime];
      byPractice.set(it.practiceId, agg);
    }
    agg[0] += 1;
    if (it.isCorrect === 1) agg[1] += 1;
    practiceTs.set(it.practiceId, it.createdTime);
  }

  const keys: number[] = Array.from(byPractice.keys());
  keys.sort((a, b) => {
    const ta = practiceTs.get(a) as number;
    const tb = practiceTs.get(b) as number;
    return ta - tb;
  });

  const trend: TrendPoint[] = [];
  for (let i = 0; i < keys.length; i++) {
    const agg = byPractice.get(keys[i]);
    if (agg === undefined) continue;
    const d = new Date(agg[2]);
    const tp = new TrendPoint();
    tp.label = (d.getMonth() + 1) + '/' + d.getDate();
    tp.rate = agg[0] > 0 ? agg[1] / agg[0] : 0;
    trend.push(tp);
  }
  return trend;
}

/** 每日热力：近 N 天每日练习数与正确率 */
export async function getDailyHeat(subjectId: number, days: number): Promise<DailyHeat[]> {
  const items = await getPracticeItems();
  const map: Map<string, number[]> = new Map<string, number[]>(); // day -> [total, correct]
  const cutoff = Date.now() - days * 86400000;
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    if (it.createdTime < cutoff) continue;
    const d = new Date(it.createdTime);
    const day = (d.getMonth() + 1) + '/' + d.getDate();
    let agg = map.get(day);
    if (agg === undefined) {
      agg = [0, 0];
      map.set(day, agg);
    }
    agg[0] += 1;
    if (it.isCorrect === 1) agg[1] += 1;
  }
  const heat: DailyHeat[] = [];
  map.forEach((agg, day) => {
    const h = new DailyHeat();
    h.day = day;
    h.practiceCount = agg[0];
    h.correctRate = agg[0] > 0 ? agg[1] / agg[0] : 0;
    heat.push(h);
  });
  heat.sort((a, b) => (a.day < b.day ? -1 : 1));
  return heat;
}

/** 能力维度：按知识点上级分类聚合平均薄弱度（雷达图数据）
 *  纯内存聚合，避免嵌套 ResultSet 与 NULL 读取 */
export async function getDimStats(): Promise<DimStat[]> {
  const ws = await getWeakStats();
  const kps = await getKps(0);

  const nameById: Map<number, string> = new Map<number, string>();
  for (let i = 0; i < kps.length; i++) {
    nameById.set(kps[i].id, kps[i].name);
  }
  // kpId -> 上级分类名（无上级则归为“未分类”）
  const parentNameOf: Map<number, string> = new Map<number, string>();
  for (let i = 0; i < kps.length; i++) {
    const pid = kps[i].parentId;
    let parentName = '未分类';
    if (pid > 0) {
      const pn = nameById.get(pid);
      if (pn !== undefined && pn !== '') parentName = pn;
    }
    parentNameOf.set(kps[i].id, parentName);
  }

  const sumMap: Map<string, number> = new Map<string, number>();
  const cntMap: Map<string, number> = new Map<string, number>();
  for (let i = 0; i < ws.length; i++) {
    const key = parentNameOf.get(ws[i].kpId);
    if (key === undefined) continue;
    const curSum = sumMap.get(key);
    sumMap.set(key, (curSum === undefined ? 0 : curSum) + ws[i].score);
    const curCnt = cntMap.get(key);
    cntMap.set(key, (curCnt === undefined ? 0 : curCnt) + 1);
  }

  const dims: DimStat[] = [];
  sumMap.forEach((sum: number, name: string) => {
    const cnt = cntMap.get(name);
    const c = cnt === undefined ? 0 : cnt;
    const d = new DimStat();
    d.name = name;
    d.score = c > 0 ? Math.round(sum / c) : 0;
    dims.push(d);
  });
  return dims;
}