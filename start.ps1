param([switch]$NoBrowser)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    $taskNode=Join-Path $taskRoot 'runtime\node\node.exe'
    $taskPython=Join-Path $taskRoot 'runtime\python\python.exe'
    if(-not(Test-Path -LiteralPath $taskNode)){$taskNode=(Get-Command node.exe -ErrorAction Stop).Source}
    if(-not(Test-Path -LiteralPath $taskPython)){$taskPython=(Get-Command python.exe -ErrorAction Stop).Source}
    if(-not(Test-Path -LiteralPath (Join-Path $taskRoot 'companion\node_modules\tiktok-live-connector'))) {
        throw 'Dependencies are missing. Run npm ci --ignore-scripts in the companion folder first. See START-HERE.txt.'
    }
    $taskRunning=$false
    try {$taskResponse=Invoke-RestMethod -Uri 'http://127.0.0.1:8790/api/state' -TimeoutSec 2;$taskRunning=($null -ne $taskResponse.actions)}catch{}
    if(-not $taskRunning){
        $env:EGG_LIVE_PYTHON=$taskPython
        $env:EGG_LIVE_ALLOW_LIVE='1'
        Start-Process -FilePath $taskNode -ArgumentList 'server.mjs' -WorkingDirectory (Join-Path $taskRoot 'companion') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskRoot 'companion-output.log') -RedirectStandardError (Join-Path $taskRoot 'companion-error.log')
    }
    for($taskAttempt=0;$taskAttempt -lt 30;$taskAttempt++){
        try{$taskReady=Invoke-RestMethod -Uri 'http://127.0.0.1:8790/api/state' -TimeoutSec 1;if($null -ne $taskReady.actions){break}}catch{}
        Start-Sleep -Milliseconds 200
    }
    if($null -eq $taskReady){throw 'The companion could not start. See companion-error.log in this folder.'}
    if(-not $NoBrowser){Start-Process 'http://127.0.0.1:8790/#mappings'}
}catch{
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($_.Exception.Message,'Egg LIVE setup') | Out-Null
}

