#!/usr/bin/env node
/**
 * PreToolUse hook — 카카오톡 나챗방(KakaotalkChat-MemoChat) 전송 직전에 돈다.
 *
 * 「🔮」로 시작하는 운세 메시지만 검사한다. 증시 요약 등 다른 메시지는 그대로 통과시킨다.
 *
 * 막는 경우
 *   1. 200자를 넘는다 (나챗방 도구 한도)
 *   2. 「오락용」 안내가 없다
 *   3. 투자 추천 · 의료 · 법률 단정으로 읽히는 말이 들어 있다
 *   4. 오늘 이미 운세를 보냈다 (하루 1번)
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const PREFIX = '🔮';
const LIMIT = 200;
const ADVICE = /(매수|매도|목표가|종목\s*추천|투자\s*추천|진단|처방|소송|고소)/;
const STATE = path.join(os.homedir(), '.claude', 'state', 'fortune-sent.txt');

function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason,
    },
  }));
  process.exit(0);
}

function today() {
  // 한국 시간 기준 날짜 (예약 작업이 UTC 환경에서 돌아도 날짜가 어긋나지 않게)
  return new Date().toLocaleDateString('sv-SE', { timeZone: 'Asia/Seoul' });
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  let input;
  try { input = JSON.parse(raw); } catch { process.exit(0); }
  const args = input.tool_input || {};
  const msg = Object.values(args).find((v) => typeof v === 'string' && v.startsWith(PREFIX));
  if (!msg) process.exit(0);

  const length = [...msg].length;
  if (length > LIMIT) deny(`운세 메시지가 ${length}자입니다. ${LIMIT}자 이내로 줄여서 다시 보내세요.`);
  if (!msg.includes('오락용')) deny('마지막 줄에 「※오락용 운세입니다」 안내가 없습니다. 넣어서 다시 보내세요.');
  const hit = msg.match(ADVICE);
  if (hit) deny(`투자 추천·진단 등으로 읽히는 말(「${hit[0]}」)이 있습니다. 가벼운 오락용 표현으로 고쳐서 다시 보내세요.`);

  let last = '';
  try { last = fs.readFileSync(STATE, 'utf8').trim(); } catch { /* 첫 전송 */ }
  if (last === today()) deny('오늘은 이미 운세를 보냈습니다. 다시 보내지 말고 그 사실만 보고하세요.');

  fs.mkdirSync(path.dirname(STATE), { recursive: true });
  fs.writeFileSync(STATE, today());
  process.exit(0);
});
