# 매일 운세 전송: 한국천문연구원 음양력 + 기상청 단기예보(서울) Open API 로 오늘 정보를 모아
# fortune-writer 에이전트에게 넘기고, 에이전트가 카카오톡 나챗방(PlayMCP)으로 보낸다.
# 각 API 호출이 실패해도 해당 정보만 빼고 계속 진행한다. 키는 사용자 환경 변수 KASI_SERVICE_KEY 에서만 읽는다.
param(
    [string]$ClaudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source,
    [string]$Agent = 'daily-fortune:fortune-writer'
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logDir = Join-Path $env:USERPROFILE '.claude\state'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir 'daily-fortune.log'
Set-Location $env:USERPROFILE
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') start ===" | Out-File $log -Append -Encoding utf8
if (-not $ClaudePath) { "claude 실행 파일을 찾지 못함" | Out-File $log -Append -Encoding utf8; exit 1 }

$key = [Environment]::GetEnvironmentVariable('KASI_SERVICE_KEY', 'User')
$d = Get-Date

# 1) 오늘의 음양력 정보
$calendar = ''
try {
    if (-not $key) { throw 'KASI_SERVICE_KEY 없음' }
    $url = 'https://apis.data.go.kr/B090041/openapi/service/LrsrCldInfoService/getLunCalInfo' +
        "?solYear=$($d.Year)&solMonth=$($d.ToString('MM'))&solDay=$($d.ToString('dd'))&ServiceKey=" + [uri]::EscapeDataString($key)
    $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
    $xml = [xml][Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray())
    if ($xml.response.header.resultCode -ne '00') { throw "API 응답 코드 $($xml.response.header.resultCode)" }
    $i = $xml.response.body.items.item
    $calendar = "양력 $($i.solYear)-$($i.solMonth)-$($i.solDay)($($i.solWeek)), 음력 $($i.lunYear)년 $($i.lunMonth)월 $($i.lunDay)일, 일진 $($i.lunIljin), 월건 $($i.lunWolgeon), 세차 $($i.lunSecha)"
    "음양력 API 성공: $calendar" | Out-File $log -Append -Encoding utf8
} catch {
    "음양력 API 실패(달력 정보 없이 진행): $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}

# 2) 서울 오늘 날씨 (기상청 단기예보, 02시 발표분 사용)
$weather = ''
try {
    if (-not $key) { throw 'KASI_SERVICE_KEY 없음' }
    $today = $d.ToString('yyyyMMdd')
    $wurl = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst' +
        "?pageNo=1&numOfRows=1000&dataType=JSON&base_date=$today&base_time=0200&nx=60&ny=127&ServiceKey=" + [uri]::EscapeDataString($key)
    $wres = Invoke-WebRequest -Uri $wurl -UseBasicParsing -TimeoutSec 20
    $wj = [Text.Encoding]::UTF8.GetString($wres.RawContentStream.ToArray()) | ConvertFrom-Json
    if ($wj.response.header.resultCode -ne '00') { throw "API 응답 코드 $($wj.response.header.resultCode)" }
    $w = @($wj.response.body.items.item | Where-Object { $_.fcstDate -eq $today })
    $tmn = ($w | Where-Object { $_.category -eq 'TMN' } | Select-Object -First 1).fcstValue
    $tmx = ($w | Where-Object { $_.category -eq 'TMX' } | Select-Object -First 1).fcstValue
    $pop = ($w | Where-Object { $_.category -eq 'POP' } | ForEach-Object { [int]$_.fcstValue } | Measure-Object -Maximum).Maximum
    $sky = ($w | Where-Object { $_.category -eq 'SKY' -and $_.fcstTime -eq '0900' } | Select-Object -First 1).fcstValue
    $pty = ($w | Where-Object { $_.category -eq 'PTY' -and $_.fcstTime -eq '0900' } | Select-Object -First 1).fcstValue
    $skyText = switch ($sky) { '1' { '맑음' } '3' { '구름많음' } '4' { '흐림' } default { '확인 못 함' } }
    $ptyText = switch ($pty) { '0' { '강수 없음' } '1' { '비' } '2' { '비/눈' } '3' { '눈' } '4' { '소나기' } default { '확인 못 함' } }
    if (-not $tmn -and -not $tmx) { throw '기온 값 없음' }
    $weather = "서울 최저 $($tmn)도, 최고 $($tmx)도, 하늘 $skyText(오전 9시 기준), $ptyText, 강수확률 최대 $pop%"
    "날씨 API 성공: $weather" | Out-File $log -Append -Encoding utf8
} catch {
    "날씨 API 실패(날씨 없이 진행): $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}

# 3) 운세 생성 및 전송 (작성 규칙은 daily-fortune 스킬, 전송 검사는 훅이 맡는다)
$basis = if ($calendar) { "오늘의 달력 정보(한국천문연구원 Open API): $calendar" } else { '' }
$weatherBasis = if ($weather) { "오늘의 날씨(기상청 Open API): $weather" } else { '' }
$prompt = "오늘의 운세를 보내라.`n$basis`n$weatherBasis"
& $ClaudePath --agent $Agent -p $prompt --allowedTools 'Skill' 'mcp__claude_ai_PlayMCP__KakaotalkChat-MemoChat' 2>&1 | Out-File $log -Append -Encoding utf8
"=== end (exit $LASTEXITCODE) ===" | Out-File $log -Append -Encoding utf8
