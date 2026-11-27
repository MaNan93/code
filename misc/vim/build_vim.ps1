$ErrorActionPreference = "Stop"

$SrcDir    = $PSScriptRoot
$DestDir   = $env:USERPROFILE
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 1. 确保自定义 .vim 脚本首行有 scriptencoding utf-8 且为 Unix LF 换行符
Get-ChildItem -Path "$SrcDir\.vim" -Recurse -Filter "*.vim" | Where-Object {
    $_.FullName -notmatch '\\pack\\'
} | ForEach-Object {
    $txt = [System.IO.File]::ReadAllText($_.FullName, $Utf8NoBom)
    if ($txt -notmatch '(?m)^scriptencoding\s+utf-8') {
        $txt = "scriptencoding utf-8`n" + $txt
    }
    [System.IO.File]::WriteAllText($_.FullName, ($txt -replace "`r`n", "`n"), $Utf8NoBom)
}

# 2. 同步到本地 Windows 用户主目录
if (Test-Path "$SrcDir\.vimrc") {
    $vimrcTxt = [System.IO.File]::ReadAllText("$SrcDir\.vimrc", $Utf8NoBom)
    [System.IO.File]::WriteAllText("$SrcDir\.vimrc", ($vimrcTxt -replace "`r`n", "`n"), $Utf8NoBom)
    Copy-Item -Path "$SrcDir\.vimrc" -Destination "$DestDir\.vimrc" -Force
    Write-Host "[OK] Updated $DestDir\.vimrc" -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path "$DestDir\.vim" | Out-Null
Copy-Item -Path "$SrcDir\.vim\*" -Destination "$DestDir\.vim\" -Recurse -Force
Write-Host "[OK] Synced .vim folder to $DestDir\.vim\" -ForegroundColor Green

# 3. 打包生成 Linux 离线压缩包 (UTF-8 No-BOM + Unix LF)
$StageDir = Join-Path $env:TEMP "vim_linux_stage"
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$StageDir\.vim" | Out-Null

Copy-Item "$SrcDir\.vimrc" "$StageDir\.vimrc" -Force
Copy-Item "$SrcDir\.vim\*" "$StageDir\.vim\" -Recurse -Force

Get-ChildItem -Path $StageDir -Recurse -File | Where-Object {
    $_.Extension -in @('.vim', '.vimrc', '') -and $_.FullName -notmatch '\\(swap|undo|backup|\.git)\\'
} | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName, $Utf8NoBom)
    [System.IO.File]::WriteAllText($_.FullName, ($c -replace "`r`n", "`n"), $Utf8NoBom)
}

$TarPath = Join-Path $SrcDir "vim_rtl_env_linux.tar.gz"
tar -czf $TarPath -C $StageDir .vimrc .vim
Remove-Item $StageDir -Recurse -Force

Write-Host "[OK] Created Linux archive (UTF-8 No-BOM + LF): $TarPath" -ForegroundColor Yellow