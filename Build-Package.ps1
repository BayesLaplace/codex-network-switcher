param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference = 'Stop'
$files = @('Switch-CodexNetwork.ps1','Install-Shortcut.ps1','自动切换.cmd','安装桌面快捷方式.cmd','README.md','CHANGELOG.md')
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw ('Missing package file: ' + $name) }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archivePath = Join-Path $OutputDirectory 'codex-network-switcher-v1.0.0.zip'
$paths = @($files | ForEach-Object { Join-Path $PSScriptRoot $_ })
Compress-Archive -LiteralPath $paths -DestinationPath $archivePath -Force
Write-Output $archivePath
