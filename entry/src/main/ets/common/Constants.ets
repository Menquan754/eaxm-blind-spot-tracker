/**
 * 全局常量：配色、题型、评分权重
 */
export const C_PRIMARY: string = '#0A59F7';
export const C_BG: string = '#F1F3F5';
export const C_CARD: string = '#FFFFFF';
export const C_TEXT: string = '#182431';
export const C_MUTED: string = '#86909C';
export const C_BORDER: string = '#E5E8EF';
export const C_OK: string = '#00B96B';
export const C_BAD: string = '#F5313D';
export const C_WARN: string = '#FF8800';
export const C_CHART1: string = '#0A59F7';
export const C_CHART2: string = '#00B96B';
export const C_CHART3: string = '#FF8800';
export const C_CHART4: string = '#7B61FF';

/** 题型：0 单选 | 1 多选 | 2 判断 | 3 简答 */
export const QT_SINGLE: number = 0;
export const QT_MULTI: number = 1;
export const QT_JUDGE: number = 2;
export const QT_SHORT: number = 3;

export function typeName(t: number): string {
  if (t === QT_SINGLE) return '单选';
  if (t === QT_MULTI) return '多选';
  if (t === QT_JUDGE) return '判断';
  return '简答';
}

/** 薄弱度评分权重 */
export const W_ERR_RATE: number = 0.5;
export const W_STREAK: number = 0.3;
export const W_RECENT: number = 0.2;

/** 复习间隔（天）：阶段 0..4 */
export const REVIEW_STAGES: number[] = [1, 3, 7, 15, 30];