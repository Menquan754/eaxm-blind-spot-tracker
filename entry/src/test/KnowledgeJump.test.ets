import { describe, it, expect } from '@ohos/hypium';
import { KnowledgePoint } from '../main/ets/model/Entities';
import { isValidKpJump, resolveKpTarget } from '../main/ets/service/KnowledgeJumpService';

function mkKp(id: number, name: string): KnowledgePoint {
  const kp = new KnowledgePoint();
  kp.id = id;
  kp.name = name;
  return kp;
}

export default function knowledgeJumpTest() {
  describe('knowledgeJumpTest', () => {
    it('jumpTest_targetExistsInSubject', 0, () => {
      const kps: KnowledgePoint[] = [mkKp(11, '函数与极限'), mkKp(12, '极限计算'), mkKp(13, '导数与微分')];
      // 目标知识点存在时直接选中
      expect(resolveKpTarget(kps, 12)).assertEqual(12);
    });

    it('jumpTest_targetNotInSubjectFallbackToFirst', 0, () => {
      const kps: KnowledgePoint[] = [mkKp(21, '行列式'), mkKp(22, '矩阵运算')];
      // 目标知识点不属于当前学科（或已被删除）时回退到第一个
      expect(resolveKpTarget(kps, 99)).assertEqual(21);
    });

    it('jumpTest_emptyKpListReturnsZero', 0, () => {
      const kps: KnowledgePoint[] = [];
      // 空学科没有可跳转目标
      expect(resolveKpTarget(kps, 12)).assertEqual(0);
    });

    it('jumpTest_invalidPreferredIdFallbackToFirst', 0, () => {
      const kps: KnowledgePoint[] = [mkKp(31, '随机事件与概率'), mkKp(32, '条件概率与独立性')];
      expect(resolveKpTarget(kps, 0)).assertEqual(31);
      expect(resolveKpTarget(kps, -5)).assertEqual(31);
    });

    it('jumpTest_singleKpAlwaysResolvesToIt', 0, () => {
      const kps: KnowledgePoint[] = [mkKp(41, '基础语法')];
      expect(resolveKpTarget(kps, 41)).assertEqual(41);
      expect(resolveKpTarget(kps, 42)).assertEqual(41);
    });

    it('jumpTest_validJumpParams', 0, () => {
      expect(isValidKpJump(1, 2)).assertTrue();
      expect(isValidKpJump(1, 0)).assertFalse();
      expect(isValidKpJump(0, 2)).assertFalse();
      expect(isValidKpJump(-1, -2)).assertFalse();
    });
  });
}
