#Requires -Version 5.1
<#
.SYNOPSIS
  gcWeaselSettings one-click bootstrap.
  On a Windows machine: installs Weasel (if missing), installs Source Han Sans VF
  (if missing), applies this repo's RIME config, and deploys.
  Idempotent — safe to re-run; only installs what's missing.
  Use -NoElevate to skip UAC self-elevation (for testing on an already-admin box).
.NOTES
  Self-elevates (UAC) because the Weasel installer writes to Program Files.
  File must be UTF-8 with BOM (PowerShell 5.1 needs BOM to parse the Chinese).
#>

[CmdletBinding()] param([switch]$NoElevate)
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # 提速 Invoke-WebRequest
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12   # GitHub 要 TLS1.2
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # 让中文输出不乱码

# ---------- 日志 ----------
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn2($m){ Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "    [X]  $m" -ForegroundColor Red }

$Root = $PSScriptRoot
$Rime = Join-Path $env:APPDATA 'Rime'

# ---------- 自提权 ----------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin -and -not $NoElevate) {
    Write-Host "正在请求管理员权限（UAC）..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy","Bypass","-NoProfile","-File","`"$PSCommandPath`""
    exit
}
Write-Host "====== gcWeaselSettings 一键配置 ======" -ForegroundColor White

# ---------- 工具函数 ----------
function Find-WeaselExe($name) {
    foreach ($b in @("$env:ProgramFiles\Rime", "${env:ProgramFiles(x86)}\Rime")) {
        if (Test-Path $b) {
            $h = Get-ChildItem -Path $b -Filter $name -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($h) { return $h.FullName }
        }
    }
    return $null
}
function Test-Weasel { return [bool](Find-WeaselExe 'WeaselServer.exe') }
function Test-Font {
    foreach ($f in @((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts\SourceHanSans-VF.otf'), (Join-Path $env:WINDIR 'Fonts\SourceHanSans-VF.otf'))) {
        if (Test-Path $f) { return $true }
    }
    foreach ($p in @('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts','HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        try { $v = Get-ItemProperty $p; foreach ($n in $v.PSObject.Properties.Name) { if ($n -like '*Source Han Sans VF*') { return $true } } } catch {}
    }
    return $false
}
function Build-ColorScheme {
    $w = Join-Path $Rime 'build\weasel.yaml'
    if (Test-Path $w) {
        $l = Select-String -Path $w -Pattern '^\s*color_scheme:' | Select-Object -First 1
        if ($l) { return (($l.Line -split ':')[1]).Trim() }
    }
    return $null
}
function Ensure-Server($serverPath) {
    if (-not (Get-Process WeaselServer -ErrorAction SilentlyContinue) -and $serverPath) {
        Start-Process $serverPath | Out-Null; Start-Sleep -Seconds 2
    }
}

try {
# ========== 1. Weasel ==========
Step 'Weasel（小狼毫）'
$server = Find-WeaselExe 'WeaselServer.exe'
if (Test-Weasel) {
    Ok "已安装：$server"
} else {
    Get-Process WeaselServer -ErrorAction SilentlyContinue | Stop-Process -Force
    $url = $null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/rime/weasel/releases/latest' -Headers @{ 'User-Agent' = 'gcWeaselSettings' }
        $a = $rel.assets | Where-Object name -like '*-installer.exe' | Select-Object -First 1
        if ($a) { $url = $a.browser_download_url; Write-Host "    最新版：$($rel.tag_name)" }
    } catch { Warn2 "GitHub API 不可达，使用固定版本 URL" }
    if (-not $url) { $url = 'https://github.com/rime/weasel/releases/download/0.17.4/weasel-0.17.4.0-installer.exe' }
    $inst = Join-Path $env:TEMP 'weasel-installer.exe'
    Write-Host "    下载 $url"
    Invoke-WebRequest $url -OutFile $inst -UseBasicParsing
    Write-Host "    静默安装（NSIS /S）..."
    Start-Process $inst -ArgumentList '/S' -Wait
    Start-Sleep -Seconds 3
    if (-not (Test-Weasel)) {
        Warn2 '静默安装未成功，启动安装器 GUI，请点击完成'
        Start-Process $inst -Wait
    }
    if (Test-Weasel) { Ok '已安装' } else { Err 'Weasel 安装失败，终止'; pause; exit 1 }
}
$deployer = Find-WeaselExe 'WeaselDeployer.exe'
$server   = Find-WeaselExe 'WeaselServer.exe'

# ========== 2. 字体 ==========
Step 'Source Han Sans VF（思源黑体）'
if (Test-Font) {
    Ok '已安装'
} else {
    $src = Join-Path $Root 'fonts\SourceHanSans-VF.otf'
    if (-not (Test-Path $src)) { Err "仓库内缺字体：$src"; pause; exit 1 }
    $dstDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    $dst = Join-Path $dstDir 'SourceHanSans-VF.otf'
    Copy-Item $src $dst -Force
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' `
        -Name 'Source Han Sans VF (OpenType)' -Value $dst -PropertyType String -Force | Out-Null
    try {
        Add-Type -Namespace W32 -Name Nm -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern int SendMessageTimeout(IntPtr h,int m,IntPtr w,IntPtr l,int f,int t,out IntPtr r);'
        $r = [IntPtr]::Zero
        [W32.Nm]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r) | Out-Null
    } catch {}
    Ok '已安装（当前用户）'
}

# ========== 3. 配置 ==========
Step '应用配置'
New-Item -ItemType Directory -Force -Path $Rime | Out-Null
Copy-Item (Join-Path $Root 'weasel.custom.yaml')  (Join-Path $Rime 'weasel.custom.yaml')  -Force
Copy-Item (Join-Path $Root 'default.custom.yaml') (Join-Path $Rime 'default.custom.yaml') -Force
Copy-Item (Join-Path $Root 'luna_pinyin.custom.yaml') (Join-Path $Rime 'luna_pinyin.custom.yaml') -Force
Ok '配置已拷贝（外观 + 全局 + luna_pinyin 方案覆写）'

# ========== 3.5 Octagram 語言模型（八股文，可選）==========
# 提升整句/長句的候選排序準確度。luna_pinyin schema 已內建 __patch: grammar:/hant?
# （? = 數據在才啟用），故只需把數據放入用戶目錄、重新部署即自動激活。
# hant=繁（匹配 luna_pinyin 繁體詞典；簡出也由 hant 在 simplifier 之前排序繁候選，故繁/簡輸出都用 hant）。
# 不入倉庫（共約 99MB）——這裡按需下載，冪等：已有就跳過。失敗不阻塞（語言模型為可選）。
Step 'Octagram 語言模型（八股文，可選）'
$octaBranched = @{
    'zh-hant-t-essay-bgw.gram' = 'hant'; 'zh-hant-t-essay-bgc.gram' = 'hant'
    'zh-hans-t-essay-bgw.gram' = 'hans'; 'zh-hans-t-essay-bgc.gram' = 'hans'
}
$octaBase = 'https://raw.githubusercontent.com/lotem/rime-octagram-data'
$todo = @('grammar.yaml') + @($octaBranched.Keys) | Where-Object { -not (Test-Path (Join-Path $Rime $_)) }
if ($todo.Count -eq 0) {
    Ok '已齊全（grammar.yaml + hant/hans 模型）'
} else {
    Write-Host "    缺 $($todo.Count) 個檔，下載中（共約 99MB，首次較慢）…"
    foreach ($f in $todo) {
        $url = if ($f -eq 'grammar.yaml') { "$octaBase/master/grammar.yaml" } else { "$octaBase/$($octaBranched[$f])/$f" }
        try { Invoke-WebRequest $url -OutFile (Join-Path $Rime $f) -UseBasicParsing; Ok "下載 $f" }
        catch { Warn2 "下載失敗 $f（語言模型為可選，不影響基本輸入，可稍後重跑本腳本）" }
    }
}

# ========== 4. 部署（静默）==========
Step '部署（静默 /deploy）'
# 关键两条：
#  1) 必须带 /deploy 参数才真部署；裸跑 WeaselDeployer.exe 只弹维护 GUI、不部署。
#  2) 先停 WeaselServer：deployer 连不上 server 就跳过 maintenance、纯 headless 重建 build，
#     不弹任何窗（server 在跑时 /deploy 会触发 maintenance 模式弹窗）。
Get-Process WeaselServer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
# /deploy 静默部署；用 -PassThru + 轮询 build 就绪（Start-Process -Wait 对此 GUI 子系统程序会挂起）
$p = Start-Process $deployer -ArgumentList '/deploy' -PassThru
$w = Join-Path $Rime 'build\weasel.yaml'
for ($i = 0; $i -lt 60; $i++) {
    if ((Test-Path $w) -and (Build-ColorScheme)) { break }
    Start-Sleep -Milliseconds 500
}
if (-not $p.HasExited) { try { $p.Kill() } catch {} }
Start-Sleep -Milliseconds 500
# 重启 server 加载新 build
Ensure-Server $server
Start-Sleep -Seconds 2
$final = Build-ColorScheme
Ok "部署完成：color_scheme = $final (亮) / mocha (暗)；横排；font = Source Han Sans VF；page_size = 9；schema = luna_pinyin；左 Shift = commit_code"
if (-not $final) { Warn2 '未读到 color_scheme（部署可能未完成）：请右键托盘 Weasel -> 重新部署，或重跑本脚本。' }

# ========== 收尾 ==========
Write-Host ""
Write-Host "====== 完成 ======" -ForegroundColor Green
Write-Host "打几个字验证：Catppuccin 双配色（系统亮→Latte / 暗→Mocha）+ 思源黑体 + 横排候选 + 每页 9 候选；左 Shift 编码以西文直接上屏。" -ForegroundColor White
Write-Host "若语言栏里没出现 Rime，注销/重登一次（或去语言设置添加）即可。" -ForegroundColor White

} catch {
    Err "运行出错：$($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
pause
