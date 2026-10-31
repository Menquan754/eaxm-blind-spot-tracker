/**
 * 简易全局仓储：保存最近一次练习/视图状态，避免跨页依赖复杂状态库
 */
import { Question, PracticeItem, WeakStat } from '../model/Entities';

export class GlobalData {
  static lastResultQuestions: Question[] = [];
  static lastResultAnswers: string[] = [];
  static lastResultCorrects: boolean[] = [];
  static lastResultScore: number = 0;
  static lastResultTotal: number = 0;
  static lastResultCorrectCount: number = 0;
  static lastKpName: string = '';
}