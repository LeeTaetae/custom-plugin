# daily-fortune

매일 아침 **오락용 오늘의 운세**를 만들어 카카오톡 **나챗방**으로 보내는 Claude Code 플러그인입니다.
한국천문연구원 음양력 Open API(음력 날짜·일진)와 기상청 단기예보 Open API(서울 날씨)를 근거로 쓰고,
전송 직전에 훅이 형식(200자·오락용 안내·금지 표현·하루 1회)을 검사합니다.

> 운세는 재미로 보는 오락용입니다. 투자·의료·법률 판단에 쓰지 마세요.

## 구성

| 종류 | 파일 | 역할 |
|---|---|---|
| 스킬 | `skills/daily-fortune/SKILL.md` | 운세 작성 규칙(6개 항목, 🔮 시작, 200자 이내, 오락용 안내) |
| 에이전트 | `agents/fortune-writer.md` | 운세를 쓰고 나챗방으로 보내는 전용 에이전트(도구: 스킬·나챗방 전송만) |
| 훅 | `hooks/fortune-guard.js` | 나챗방 전송 직전 검사. 🔮로 시작하는 메시지만 대상이라 다른 전송에는 영향 없음 |
| 스크립트 | `scripts/daily-fortune.ps1`, `scripts/install-schedule.ps1` | Open API 조회 → 에이전트 실행, 매일 실행 예약(Windows) |

## 설치

Claude Code 안에서 실행합니다.

```
/plugin marketplace add LeeTaetae/custom-plugin
/plugin install daily-fortune@custom-plugin
```

설치 후 Claude Code를 다시 시작하면 적용됩니다.

## 사전 준비

1. **PlayMCP 카카오톡 나챗방 연결** — [PlayMCP](https://playmcp.kakao.com)에서 *카카오톡 나챗방*을 도구함에 추가하고, claude.ai 커넥터로 연결합니다. 연결되면 `claude mcp list`에 `claude.ai PlayMCP … Connected`가 보입니다.
2. **Node.js** — 훅이 `node`로 실행됩니다.
3. **(선택) 공공데이터포털 인증키** — 음양력·날씨 정보를 쓰려면 [data.go.kr](https://www.data.go.kr)에서 아래 두 API를 각각 활용신청하고, 일반 인증키(Decoding)를 환경 변수로 저장합니다.
   - 한국천문연구원_음양력 정보
   - 기상청_단기예보((구)동네예보) 조회서비스

   ```
   setx KASI_SERVICE_KEY "발급받은키"
   ```

   키가 없거나 API가 실패하면 해당 정보만 빼고 운세를 만듭니다. 키는 코드에 쓰지 않고 환경 변수에서만 읽습니다.

## 사용

**대화에서 바로** — "오늘의 운세 보내줘"라고 하면 `daily-fortune` 스킬이 동작합니다. (이 경우 음양력·날씨는 자동 조회되지 않고, 스킬 규칙대로 작성합니다.)

**매일 자동 실행(Windows)** — 플러그인이 설치된 폴더의 스크립트를 한 번 실행하면 작업 스케줄러에 등록됩니다.

```powershell
# 설치 위치는 보통 ~\.claude\plugins\cache\custom-plugin\daily-fortune\<버전>\ 입니다.
powershell -ExecutionPolicy Bypass -File "<설치 폴더>\scripts\install-schedule.ps1" -Time 08:00
Start-ScheduledTask -TaskName DailyFortune   # 지금 한 번 시험
```

- 로그: `~\.claude\state\daily-fortune.log`
- 삭제: `Unregister-ScheduledTask -TaskName DailyFortune -Confirm:$false`

## 알아둘 점

- 예약 실행은 **PC가 켜져 있고 로그인된 상태**여야 합니다. 꺼져 있었다면 켠 뒤에 한 번 실행됩니다.
- 하루에 한 번만 전송됩니다(훅이 같은 날 두 번째 전송을 막음). 다시 보내려면 `~\.claude\state\fortune-sent.txt`를 지우세요. 전송 직전에 기록하므로, 전송이 실패해도 그날은 재시도가 막힙니다.
- 날씨는 서울(nx=60, ny=127) 고정입니다. 다른 지역은 `scripts/daily-fortune.ps1`의 좌표를 바꾸세요.
- 일진·음력은 해석의 소재일 뿐, 전통 사주 풀이가 아닙니다.
- 스케줄 스크립트는 Windows 전용입니다. 스킬·에이전트·훅은 OS와 무관합니다.

## 라이선스

MIT
