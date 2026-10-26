# 매일 정해진 시각에 daily-fortune.ps1 을 실행하는 Windows 작업 스케줄러 작업을 등록한다.
# 사용: powershell -ExecutionPolicy Bypass -File install-schedule.ps1 [-Time 08:00]
# 삭제: Unregister-ScheduledTask -TaskName DailyFortune -Confirm:$false
param(
    [string]$Time = '08:00',
    [string]$TaskName = 'DailyFortune'
)
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { Write-Error 'claude 실행 파일을 PATH 에서 찾지 못했습니다. Claude Code 설치를 확인하세요.'; exit 1 }

$script = Join-Path $PSScriptRoot 'daily-fortune.ps1'
$taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -ClaudePath `"$claude`""
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
$trigger  = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "이미 '$TaskName' 작업이 있어 덮어씁니다."
}
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force `
    -Description "매일 $Time 오락용 운세를 카카오톡 나챗방으로 전송" | Out-Null
$next = (Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo).NextRunTime
Write-Host "등록 완료: $TaskName, 다음 실행 $next"
Write-Host "지금 한 번 시험하려면: Start-ScheduledTask -TaskName $TaskName"
Write-Host "실행 로그: $env:USERPROFILE\.claude\state\daily-fortune.log"
