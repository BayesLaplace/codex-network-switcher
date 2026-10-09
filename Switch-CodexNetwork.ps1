param(
    [ValidateSet('Auto','Direct','Proxy')]
    [string]$Mode = 'Auto',
    [string]$CodexDirectory
)

$ErrorActionPreference = 'Stop'

function Convert-CodexEnvContent {
    param([AllowEmptyString()][string]$Content, [string]$SelectedMode)
    $values = [ordered]@{
        HTTP_PROXY = 'http://127.0.0.1:10808'
        HTTPS_PROXY = 'http://127.0.0.1:10808'
        ALL_PROXY = 'http://127.0.0.1:10808'
        NO_PROXY = 'localhost,127.0.0.1,::1'
    }
    $newline = if ($Content.Contains("`r`n")) { "`r`n" } elseif ($Content.Contains("`n")) { "`n" } else { "`r`n" }
    $result = $Content
    foreach ($key in $values.Keys) {
        $pattern = '(?m)^[ \t]*(?:export[ \t]+)?' + $key + '[ \t]*=[^\r\n]*(?:\r\n|\n|\r|$)'
        $result = [regex]::Replace($result, $pattern, '')
    }
    if ($SelectedMode -eq 'Proxy') {
        if ($result.Length -gt 0 -and -not $result.EndsWith("`n") -and -not $result.EndsWith("`r")) { $result += $newline }
        foreach ($key in $values.Keys) { $result += $key + '=' + $values[$key] + $newline }
    }
    return $result
}

function Test-CodexProxyPort {
    param([int]$Port = 10808)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.ConnectAsync('127.0.0.1',$Port)
        return ($connect.Wait(2000) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

# Dot-sourcing loads the helper functions without changing files.
if ($MyInvocation.InvocationName -eq '.') { return }

try {
    if ([string]::IsNullOrWhiteSpace($CodexDirectory)) {
        $explicitDirectory = [Environment]::GetEnvironmentVariable('CODEX_HOME','Process')
        $CodexDirectory = if ([string]::IsNullOrWhiteSpace($explicitDirectory)) {
            Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
        } else { $explicitDirectory }
    }
    $CodexDirectory = [IO.Path]::GetFullPath($CodexDirectory)
    $configPath = Join-Path $CodexDirectory 'config.toml'
    $sessionsPath = Join-Path $CodexDirectory 'sessions'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf) -or -not (Test-Path -LiteralPath $sessionsPath -PathType Container)) {
        throw '找不到同时包含 config.toml 和 sessions 的 Codex 配置目录，未执行切换。'
    }
    if ($Mode -eq 'Auto' -or $Mode -eq 'Proxy') {
        $reachable = Test-CodexProxyPort
        if ($Mode -eq 'Auto') {
            $Mode = if ($reachable) { 'Proxy' } else { 'Direct' }
            $portStatus = if ($reachable) { '可连接，选择代理模式' } else { '未开启，选择直连模式' }
            Write-Host ('10808 端口：' + $portStatus)
        } elseif (-not $reachable) {
            throw '代理端口 127.0.0.1:10808 无法连接。请先启动代理软件，再点击自动切换。当前配置未修改。'
        }
    }
    $envPath = Join-Path $CodexDirectory '.env'
    $strictUtf8 = [Text.UTF8Encoding]::new($false,$true)
    $file = [IO.File]::Open($envPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        $originalBytes = New-Object byte[] $file.Length
        $offset = 0
        while ($offset -lt $originalBytes.Length) {
            $read = $file.Read($originalBytes,$offset,$originalBytes.Length-$offset)
            if ($read -eq 0) { throw '读取配置文件失败，未执行切换。' }
            $offset += $read
        }
        $bomLength = if ($originalBytes.Length -ge 3 -and $originalBytes[0] -eq 239 -and $originalBytes[1] -eq 187 -and $originalBytes[2] -eq 191) { 3 } else { 0 }
        $original = $strictUtf8.GetString($originalBytes,$bomLength,$originalBytes.Length-$bomLength)
        $updated = Convert-CodexEnvContent -Content $original -SelectedMode $Mode
        if ($updated -cne $original) {
            $updatedBytes = $strictUtf8.GetBytes($updated)
            $file.Position = $bomLength
            try {
                $file.Write($updatedBytes,0,$updatedBytes.Length)
                $file.SetLength($bomLength+$updatedBytes.Length)
                $file.Flush($true)
            } catch {
                $file.Position = 0
                $file.Write($originalBytes,0,$originalBytes.Length)
                $file.SetLength($originalBytes.Length)
                $file.Flush($true)
                throw
            }
        }
    } finally { $file.Dispose() }
    $label = if ($Mode -eq 'Direct') { '直连模式' } else { '代理模式（127.0.0.1:10808）' }
    Write-Host ''
    Write-Host ('已切换为：' + $label) -ForegroundColor Green
    Write-Host ('配置文件：' + $envPath)
    Write-Host '请自行完全退出并重新启动 Codex，使切换生效。' -ForegroundColor Yellow
    Write-Host '切换工具不会关闭 Codex，也不会修改 Windows 全局代理或 config.toml。'
    exit 0
} catch {
    Write-Host ''
    Write-Host ('切换失败：' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
