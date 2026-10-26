param(
    [string]$LauncherPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
if (-not $LauncherPath) {
    $nearby = Join-Path $PSScriptRoot 'WESTSIDE TEST.exe'
    if (Test-Path -LiteralPath $nearby -PathType Leaf) {
        $LauncherPath = $nearby
    } else {
        $registered = Get-ItemProperty 'HKCU:\SOFTWARE\CitizenFX\WESTSIDE TEST' -ErrorAction SilentlyContinue
        $app = $registered.'Last Run Location'
        if ($app) {
            $LauncherPath = Join-Path (Split-Path $app.TrimEnd('\') -Parent) 'WESTSIDE TEST.exe'
        } else {
            $LauncherPath = Join-Path $env:LOCALAPPDATA 'WESTSIDE TEST\WESTSIDE TEST.exe'
        }
    }
}
if (-not (Test-Path -LiteralPath $LauncherPath -PathType Leaf)) {
    throw 'Khong tim thay launcher. Dung -LauncherPath voi duong dan WESTSIDE TEST.exe dang bi loi.'
}
$exe = (Resolve-Path -LiteralPath $LauncherPath).Path
$root = Split-Path $exe -Parent
$launcherLocatedInRuntime = ([IO.Path]::GetFileName($root) -eq 'WESTSIDE CITY.app')
if ($launcherLocatedInRuntime) { $root = Split-Path $root -Parent }
$runtime = Join-Path $root 'WESTSIDE CITY.app'
if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot ('KET_QUA_EAC_TEST_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json')
}
if (Test-Path -LiteralPath $OutputPath) { throw 'File ket qua da ton tai; khong ghi de.' }

$expected = [ordered]@{
    'WESTSIDE TEST.exe' = 'd4d00af024fb0a763ba48c5001a5bbea7185505bd2103d1aa8537b7e4d451125'
    'WESTSIDE CITY.app/EOSBootstrapper.exe' = '1ccec16db625a1e765eced6aa7e75f4178ce48ff9f8ddd832002e55b784ac6e7'
    'WESTSIDE CITY.app/EOSBootstrapper.ini' = 'ef4dcbde75f5b7ec85d4744c9690133a04d646ea5b7118d92dd710dad054d577'
    'WESTSIDE CITY.app/start_protected_game.exe' = '46d2552552ac95c436389a2c9f1aba6fda37ab998acf9b9ee026f3262dd70c53'
    'WESTSIDE CITY.app/westside-eac-client.json' = 'aed533fd90e7424dac8f009088d7e809ffcd8b3dff4f4f9b4266bf0f25e817e2'
    'WESTSIDE CITY.app/EasyAntiCheat/EasyAntiCheat_EOS_Setup.exe' = '8b60d4e8962ee5b4b7130afabb029673e284367bc22a590293d14f089c9f46a0'
    'WESTSIDE CITY.app/EasyAntiCheat/Settings.json' = '71565d1f8ebd53bf7204f282913db2a87e63ef058dad1ef01f1d00fd4a6d008c'
    'WESTSIDE CITY.app/EasyAntiCheat/Certificates/base.bin' = '1e6b29656ef10c873d9fe9b0bceebe9c53ab3fed563ba22cfab12f2f3e1b38bd'
    'WESTSIDE CITY.app/EasyAntiCheat/Certificates/base.cer' = '330f33dbe1054a3de4e963706cb9cabec86f85a688196b26652f65168efc4c6d'
    'WESTSIDE CITY.app/EasyAntiCheat/Certificates/runtime.conf' = '50ad2eda3080658344273de5bcc68a89f3148692820dfaffb3056edd7cff4e5d'
    'WESTSIDE CITY.app/citizen/ui.zip' = '6b0b9e3e3eecf4bf7c7a635f8e7ebcd04b7c0b5bd289e05d392c151fc85b580e'
    'WESTSIDE CITY.app/sticky.dll' = '8608964cae8474796230e05b78eb34b53824a1996f43c19a861bf7ae0d1607fe'
    'WESTSIDE CITY.app/citizen-anticheat.dll' = '7857082223fb3a3d9abea51a05f3edc9966e80bdb8cec07177103d360cbfc2cc'
    'WESTSIDE CITY.app/CitizenFX_SubProcess_game_3258_aslr.bin' = '0ba711b7180bd18fefc581f3e2f877c4b848ce92164be42909e5d274c6943ddb'
    'WESTSIDE CITY.app/data/cache/subprocess/WESTSIDE CITY_GameProcess.exe' = '0ba711b7180bd18fefc581f3e2f877c4b848ce92164be42909e5d274c6943ddb'
}

$files = foreach ($entry in $expected.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    $result = [ordered]@{ file = $entry.Key; status = 'missing'; expectedSha256 = $entry.Value }
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $item = Get-Item -LiteralPath $path -Force
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            $result['actualSha256'] = $hash
            $result['bytes'] = $item.Length
            $result['reparsePoint'] = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
            $result['status'] = if ($hash -eq $entry.Value) { 'match' } else { 'different' }
        } catch {
            $result['status'] = 'unreadable'
            $result['errorCode'] = $_.Exception.HResult
        }
    }
    [pscustomobject]$result
}

# Never export full command lines, config contents, tokens, or logs.
$processes = @()
$processQuerySucceeded = $false
try {
    $processes = @(Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)
    } | ForEach-Object {
        $cmd = [string]$_.CommandLine
        [pscustomobject]@{
            pid = $_.ProcessId
            name = $_.Name
            relativeImage = $_.ExecutablePath.Substring($root.Length + 1)
            hasEosMarker = $cmd.Contains('-westside_eos_bootstrapped')
            hasProtectedChildMarker = $cmd.Contains('-westside_eac_child=')
            hasCafeRequestMarker = $cmd.Contains('-westside_cafe_bootstrapped')
            hasCafeChildMarker = $cmd.Contains('-westside_cafe_child=')
            hasBootstrapReplaceFlag = [regex]::IsMatch($cmd, '(?i)(?:^|[\s"])-bootstrap(?:[\s"]|$)')
            buildFlags = @([regex]::Matches($cmd, '(?i)(?:^|[\s"])(-b\d+)(?=[\s"]|$)') | ForEach-Object { $_.Groups[1].Value })
            pureFlags = @([regex]::Matches($cmd, '(?i)(?:^|[\s"])(-pure_[012])(?=[\s"]|$)') | ForEach-Object { $_.Groups[1].Value })
            hasSwitchHandle = $cmd.Contains('-switchcl:')
        }
    })
    $processQuerySucceeded = $true
} catch { }

$logs = @(Get-ChildItem -LiteralPath (Join-Path $runtime 'logs') -Filter 'CitizenFX_log*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; bytes = $_.Length; modifiedUtc = $_.LastWriteTimeUtc.ToString('o') }
    })
$report = [ordered]@{
    expectedVersion = 1000092
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    launcherFileName = [IO.Path]::GetFileName($exe)
    launcherLocatedInRuntime = $launcherLocatedInRuntime
    installPathLength = $root.Length
    installPathHasNonAscii = [regex]::IsMatch($root, '[^\x00-\x7F]')
    runtimeExists = (Test-Path -LiteralPath $runtime -PathType Container)
    files = @($files)
    processQuerySucceeded = $processQuerySucceeded
    runningProcesses = $processes
    recentLogFiles = $logs
    configContentsCollected = $false
    credentialsCollected = $false
    installationModified = $false
}
$json = $report | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $json, (New-Object Text.UTF8Encoding($false)))
Write-Output ('Da tao bao cao: ' + $OutputPath)
Write-Output ('File khop: ' + @($files | Where-Object status -eq 'match').Count + '/' + $files.Count)
Write-Output 'Khong sua bo cai, khong mo launcher, khong gui du lieu len mang.'
