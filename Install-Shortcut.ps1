$ErrorActionPreference = 'Stop'
try {
    $launcherPath = Join-Path $PSScriptRoot '自动切换.cmd'
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) { throw '找不到自动切换.cmd，请先完整解压发布包。' }
    $desktopPath = [Environment]::GetFolderPath('DesktopDirectory')
    if ([string]::IsNullOrWhiteSpace($desktopPath)) { throw '无法确定当前用户的桌面目录。' }
    $shortcutPath = Join-Path $desktopPath 'Codex-自动切换.lnk'
    $shell = New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $shortcutPath) {
        $existing = $shell.CreateShortcut($shortcutPath)
        $expectedArguments = '/c ""' + $launcherPath + '""'
        if ($existing.TargetPath -ine (Join-Path $env:SystemRoot 'System32\cmd.exe') -or $existing.Arguments -cne $expectedArguments) {
            throw '桌面已有同名快捷方式且指向其他位置。请先重命名旧快捷方式，再重新安装。'
        }
    }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $shortcut.Arguments = '/c ""' + $launcherPath + '""'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = '检测 10808 端口，自动选择 Codex 直连或代理；切换后请重启 Codex。'
    $shortcut.Save()
    Write-Host '已创建桌面快捷方式：Codex-自动切换' -ForegroundColor Green
    Write-Host '请保持此文件夹的位置不变。移动文件夹后，请重新安装快捷方式。'
    exit 0
} catch {
    Write-Host ('安装失败：' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
