/**
 * 复习服务：到期任务、完成复习推进轮次
 */
import { getReviewTasks, deleteReviewTask, insertReviewTask } from '../database/AppDatabase';
import { ReviewTask } from '../model/Entities';
import { REVIEW_STAGES } from '../common/Constants';

export async function getDueTasks(): Promise<ReviewTask[]> {
  const all = await getReviewTasks();
  const now = Date.now();
  return all.filter(t => t.dueAt <= now);
}

export async function getUpcomingTasks(limit: number): Promise<ReviewTask[]> {
  const all = await getReviewTasks();
  const now = Date.now();
  const upcoming = all.filter(t => t.dueAt > now);
  return upcoming.slice(0, limit);
}

/** 完成一次复习：据此推算下一轮间隔，若已到最后阶段则删除任务 */
export async function completeReview(taskId: number, stage: number, kpId: number, dueAt: number): Promise<void> {
  await deleteReviewTask(taskId);
  const next = stage + 1;
  if (next >= REVIEW_STAGES.length) {
    // 已掌握，不再排期
    return;
  }
  const deltaDays = REVIEW_STAGES[next];
  const nextDue = Date.now() + deltaDays * 86400000;
  await insertReviewTask(kpId, nextDue, next);
}

export async function deleteTask(taskId: number): Promise<void> {
  await deleteReviewTask(taskId);
}