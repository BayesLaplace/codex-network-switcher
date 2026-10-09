$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectPath 'Switch-CodexNetwork.ps1'
$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
. $scriptPath

function Assert-Equal($Actual, $Expected, $Label) {
    if ($Actual -cne $Expected) { throw ('Test failed: ' + $Label) }
}

function Invoke-FixtureSwitch([string]$SelectedMode, [string]$Directory, [int]$ExpectedExit = 0) {
    $output = & $powerShellPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Mode $SelectedMode -CodexDirectory $Directory
    if ($LASTEXITCODE -ne $ExpectedExit) { throw ('Unexpected exit code for ' + $SelectedMode + ': ' + $LASTEXITCODE) }
}

$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryRoot ('codex-network-switcher-test-' + [guid]::NewGuid().ToString('N'))
$controlledProxy = $null
$probe = $null
try {
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'sessions') -Force | Out-Null
    $configPath = Join-Path $fixtureRoot 'config.toml'
    [IO.File]::WriteAllText($configPath, 'model_provider="unchanged"')
    $configHash = (Get-FileHash -LiteralPath $configPath).Hash
    $envPath = Join-Path $fixtureRoot '.env'
    $other = "# keep this comment`r`nTEST_SETTING=keep-this-value`r`n"
    $expectedProxy = $other + "HTTP_PROXY=http://127.0.0.1:10808`r`nHTTPS_PROXY=http://127.0.0.1:10808`r`nALL_PROXY=http://127.0.0.1:10808`r`nNO_PROXY=localhost,127.0.0.1,::1`r`n"
    $duplicates = $other + "HTTP_PROXY=old`r`nHTTP_PROXY=duplicate`r`nexport HTTPS_PROXY=old`r`nALL_PROXY=old`r`nNO_PROXY=old`r`n"
    [IO.File]::WriteAllText($envPath, $duplicates, [Text.UTF8Encoding]::new($true))
    Invoke-FixtureSwitch -SelectedMode Direct -Directory $fixtureRoot
    Assert-Equal ([IO.File]::ReadAllText($envPath)) $other 'direct preserves unrelated data and removes duplicates'
    $bytes = [IO.File]::ReadAllBytes($envPath)
    if ($bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) { throw 'UTF-8 BOM not preserved' }
    $directHash = (Get-FileHash -LiteralPath $envPath).Hash
    Invoke-FixtureSwitch -SelectedMode Direct -Directory $fixtureRoot
    Assert-Equal ((Get-FileHash -LiteralPath $envPath).Hash) $directHash 'repeated direct switch leaves bytes unchanged'

    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $probe.Start()
    $probePort = $probe.LocalEndpoint.Port
    Assert-Equal (Test-CodexProxyPort -Port $probePort) $true 'open port detection'
    $probe.Stop()
    $probe = $null
    Assert-Equal (Test-CodexProxyPort -Port $probePort) $false 'closed port detection'

    $existingProxy = Test-CodexProxyPort
    if (-not $existingProxy) {
        $controlledProxy = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 10808)
        $controlledProxy.Start()
    }
    Invoke-FixtureSwitch -SelectedMode Auto -Directory $fixtureRoot
    Assert-Equal ([IO.File]::ReadAllText($envPath)) $expectedProxy 'auto selects proxy with open listener'
    $proxyHash = (Get-FileHash -LiteralPath $envPath).Hash
    Invoke-FixtureSwitch -SelectedMode Auto -Directory $fixtureRoot
    Assert-Equal ((Get-FileHash -LiteralPath $envPath).Hash) $proxyHash 'repeated proxy switch leaves bytes unchanged'
    if ($null -ne $controlledProxy) {
        $controlledProxy.Stop()
        $controlledProxy = $null
        Invoke-FixtureSwitch -SelectedMode Auto -Directory $fixtureRoot
        Assert-Equal ([IO.File]::ReadAllText($envPath)) $other 'auto selects direct after listener stops'
        $beforeFailure = (Get-FileHash -LiteralPath $envPath).Hash
        Invoke-FixtureSwitch -SelectedMode Proxy -Directory $fixtureRoot -ExpectedExit 1
        Assert-Equal ((Get-FileHash -LiteralPath $envPath).Hash) $beforeFailure 'manual unavailable proxy does not write'
    } else {
        Write-Output '10808 already occupied: existing listener left running; closed auto branch skipped.'
    }

    $invalidDirectory = Join-Path $fixtureRoot 'invalid-home'
    New-Item -ItemType Directory -Path $invalidDirectory | Out-Null
    [IO.File]::WriteAllText((Join-Path $invalidDirectory 'config.toml'), 'placeholder')
    Invoke-FixtureSwitch -SelectedMode Direct -Directory $invalidDirectory -ExpectedExit 1
    Assert-Equal (Test-Path -LiteralPath (Join-Path $invalidDirectory '.env')) $false 'invalid home creates no env file'

    [IO.File]::WriteAllBytes($envPath, [byte[]]@(255, 255))
    $invalidHash = (Get-FileHash -LiteralPath $envPath).Hash
    Invoke-FixtureSwitch -SelectedMode Direct -Directory $fixtureRoot -ExpectedExit 1
    Assert-Equal ((Get-FileHash -LiteralPath $envPath).Hash) $invalidHash 'invalid UTF-8 is not overwritten'
    Assert-Equal ((Get-FileHash -LiteralPath $configPath).Hash) $configHash 'config.toml unchanged'
    Write-Output 'All network switch checks passed.'
} finally {
    if ($null -ne $controlledProxy) { $controlledProxy.Stop() }
    if ($null -ne $probe) { $probe.Stop() }
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $requiredPrefix = [IO.Path]::Combine($temporaryRoot, 'codex-network-switcher-test-')
    if (-not $resolvedFixture.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path' }
    if (Test-Path -LiteralPath $resolvedFixture) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
}
# Expected failure cases launch children that return 1. A successful test run
# must not leave that exit status for the GitHub Actions PowerShell wrapper.
$global:LASTEXITCODE = 0
