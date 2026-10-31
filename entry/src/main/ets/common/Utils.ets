/**
 * 通用工具：日期、分数、排序、输入辅助
 */
export function pad2(n: number): string {
  return n < 10 ? ('0' + n) : ('' + n);
}

/** 时间戳 -> MM-DD（横轴标签） */
export function dateLabel(ts: number): string {
  const d = new Date(ts);
  return pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

/** 时间戳 -> YYYY-MM-DD HH:mm */
export function dateFull(ts: number): string {
  const d = new Date(ts);
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate())
    + ' ' + pad2(d.getHours()) + ':' + pad2(d.getMinutes());
}

/** 今天 0 点时间戳 */
export function todayStart(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** 距今天数（整数，>=0） */
export function daysSince(ts: number): number {
  const diff = Date.now() - ts;
  if (diff <= 0) return 0;
  return Math.floor(diff / 86400000);
}

export function clamp(v: number, lo: number, hi: number): number {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

/** 百分比显示 */
export function pctDisplay(rate: number): string {
  return Math.round(rate * 100) + '%';
}

/** 选项字母（0->A） */
export function letterOf(i: number): string {
  return String.fromCharCode(65 + i);
}

/** 排序字母串，保证多选比较稳定 */
export function sortedLetters(s: string): string {
  const arr = s.split('');
  arr.sort();
  return arr.join('');
}