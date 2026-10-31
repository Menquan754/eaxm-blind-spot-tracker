import localUnitTest from './LocalUnit.test';
import knowledgeJumpTest from './KnowledgeJump.test';

export default function testsuite() {
  localUnitTest();
  knowledgeJumpTest();
}
