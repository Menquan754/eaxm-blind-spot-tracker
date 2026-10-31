/**
 * 知识点跳转的纯逻辑：与 UI / 数据库解耦，便于单元测试
 */
import { KnowledgePoint } from '../model/Entities';

/** 跳转参数是否有效：学科与知识点 ID 都必须大于 0 */
export function isValidKpJump(subjectId: number, kpId: number): boolean {
  return subjectId > 0 && kpId > 0;
}

/**
 * 解析跳转后应选中的知识点：
 * - 目标知识点存在于该学科列表 → 选中目标
 * - 目标不存在（例如已被删除或属于其他学科）→ 回退到第一个知识点
 * - 学科下没有知识点 → 返回 0（表示无选中）
 */
export function resolveKpTarget(kps: KnowledgePoint[], preferredKpId: number): number {
  for (let i = 0; i < kps.length; i++) {
    if (kps[i].id === preferredKpId) {
      return preferredKpId;
    }
  }
  return kps.length > 0 ? kps[0].id : 0;
}
