#requires -Version 5.1
<#
Read-only TEST94 safety snapshot. AppRoot is the existing *.app directory,
not its GAME subprocess directory. Never launches EAC, repairs, or recovery.
Default output is JSON on stdout. ReportPath optionally creates ONE NEW file
outside AppRoot; no directories are created and existing files are not replaced.
IncludeHoldText opts into a bounded, potentially private manual-hold preview.
This report NEVER authorizes a launch. Hardlink counts require a separate
bounded read-only metadata check; unknown counts must not be treated as clean.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AppRoot,
    [string]$ReportPath,
    [switch]$IncludeHoldText
)

$ErrorActionPreference = 'Stop'

function Get-ReadFailure($Record) {
    [ordered]@{
        Id = [string]$Record.FullyQualifiedErrorId
        Category = [string]$Record.CategoryInfo.Category
        Exception = $Record.Exception.GetType().FullName
        HResult = $Record.Exception.HResult
    }
}

function Convert-LocalPlainPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\' -or $full.StartsWith('\\')) {
        throw 'Only an existing local drive directory is accepted; no UNC paths.'
    }
    if ($full.Substring(2).Contains(':')) {
        throw 'Alternate data streams are not accepted.'
    }
    if ($full.Length -gt 3) { return $full.TrimEnd('\') }
    return $full
}

function Get-LocalPlainDirectory([string]$Path) {
    $full = Convert-LocalPlainPath $Path
    $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($full))
    if ($drive.DriveType -eq [IO.DriveType]::Network) { throw 'Network drive rejected.' }
    $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw 'Expected an existing directory.' }
    $current = $item
    while ($null -ne $current) {
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Directory or ancestor is a reparse point; stop for manual review.'
        }
        $current = $current.Parent
    }
    Convert-LocalPlainPath $item.FullName
}

function Convert-SafetyFileTime([byte[]]$Bytes, [datetime]$Now, [string]$Kind) {
    $r = [ordered]@{ Valid = $false; Reason = 'ExpectedExactly8Bytes'; Utc = $null; AgeSeconds = $null }
    if ($Bytes.Length -ne 8) { return $r }
    $raw = [BitConverter]::ToUInt64($Bytes, 0)
    if ($raw -eq 0 -or $raw -gt [long]::MaxValue) { $r.Reason = 'ZeroOrOutOfRange'; return $r }
    try { $time = [datetime]::FromFileTimeUtc([long]$raw) }
    catch { $r.Reason = 'InvalidFileTime'; return $r }
    $r.Utc = $time.ToString('o')
    $r.AgeSeconds = ($Now - $time).TotalSeconds
    if ($time -gt $Now) { $r.Reason = 'FutureTimestamp'; return $r }
    if ($Kind -eq 'Pending' -and $r.AgeSeconds -gt 604800) { $r.Reason = 'OlderThanSource7DayWindow'; return $r }
    $r.Valid = $true
    $r.Reason = 'TimestampValidOnly_NotAuthorization'
    if ($Kind -eq 'Quota') { $r.AutomaticRecovery24HourTimestampEligible = ($r.AgeSeconds -ge 86400) }
    return $r
}

function Get-SafetyFile([string]$Root, [string]$Name, [string]$Kind, [datetime]$Now, [bool]$ShowText) {
    $path = Join-Path $Root $Name
    $r = [ordered]@{ Name = $Name; Path = $path; Kind = $Kind; Status = 'Unknown'; Issues = @() }
    try { $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop }
    catch {
        if ($_.CategoryInfo.Category -eq 'ObjectNotFound') { $r.Status = 'Absent' }
        else { $r.Error = Get-ReadFailure $_ }
        return $r
    }
    $r.Status = 'Present'
    $r.Attributes = [string]$item.Attributes
    $r.CreationTimeUtc = $item.CreationTimeUtc.ToString('o')
    $r.LastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
    $r.LastAccessTimeUtc = $item.LastAccessTimeUtc.ToString('o')
    $r.IsDirectory = [bool]$item.PSIsContainer
    $r.IsReparsePoint = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
    $r.HardLinkCount = 'Unknown_NotCollected'
    $r.Issues += 'HardlinkCountRequiresSeparateReadOnlyVerification'
    try {
        $linkProperty = $item.PSObject.Properties['LinkType']
        $r.ProviderLinkType = if ($null -eq $linkProperty) { 'Unavailable' } else { [string]$linkProperty.Value }
        if ($r.ProviderLinkType -eq 'HardLink') { $r.Issues += 'ProviderReportsHardLink' }
    } catch { $r.LinkMetadataError = Get-ReadFailure $_ }
    if ($r.IsDirectory -or $r.IsReparsePoint) { $r.Issues += 'UnsafeFileType_NotRead'; return $r }
    $r.Length = $item.Length
    if ($item.Length -gt 65536) { $r.Issues += 'UnexpectedSizeOver64KiB_NotRead'; return $r }
    try {
        $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try {
            if ($stream.Length -ne $item.Length) { throw 'File changed before reading.' }
            $bytes = New-Object byte[] ([int]$stream.Length)
            $offset = 0
            while ($offset -lt $bytes.Length) {
                $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
                if ($read -le 0) { throw 'Unexpected end of file.' }
                $offset += $read
            }
        } finally { $stream.Dispose() }
        $after = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($after.Length -ne $item.Length -or $after.LastWriteTimeUtc -ne $item.LastWriteTimeUtc -or
            ($after.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'File metadata changed during snapshot.' }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $r.Sha256 = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
        if ($Kind -eq 'Hold') {
            $r.HoldClass = if ($bytes.Length -eq 0) { 'Empty_NotPermissionToRemove' } else { 'Nonempty_ManualOrUnknown_Stop' }
            $r.HoldText = 'Omitted_UseIncludeHoldTextOnlyForPrivateReview'
            if ($ShowText) {
                $r.HoldText = [Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min(2048, $bytes.Length))
                $r.HoldTextTruncated = ($bytes.Length -gt 2048)
            }
        } else {
            $r.RawHex = if ($bytes.Length -le 64) { ([BitConverter]::ToString($bytes)).Replace('-', '') } else { 'Omitted_UnexpectedLength' }
            $r.FileTime = Convert-SafetyFileTime $bytes $Now $Kind
            if (-not $r.FileTime.Valid) { $r.Issues += ('InvalidSafetyTimestamp:' + $r.FileTime.Reason) }
        }
    } catch { $r.Status = 'UnreadableOrChanged'; $r.Error = Get-ReadFailure $_ }
    return $r
}

function Get-WerSnapshot([datetime]$Now) {
    $r = [ordered]@{ Status = 'Unknown'; Provider = 'Microsoft-Windows-WER-SystemErrorReporting'; EventId = 1001;
        StartUtc = $Now.AddDays(-7).ToString('o'); EndUtc = $Now.ToString('o'); Events = @(); Truncated = $false }
    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = $r.Provider; Id = 1001;
            StartTime = $Now.AddDays(-7); EndTime = $Now } -MaxEvents 257 -ErrorAction Stop)
        $r.Truncated = ($events.Count -gt 256)
        $r.Status = if ($r.Truncated) { 'Truncated_StopForReview' } else { 'Read' }
        $r.Events = @($events | Select-Object -First 256 | ForEach-Object {
            [ordered]@{ RecordId = $_.RecordId; TimeCreatedUtc = $_.TimeCreated.ToUniversalTime().ToString('o'); Id = $_.Id }
        })
    } catch {
        $r.QueryResult = Get-ReadFailure $_
        $r.Status = if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { 'NoMatchingEventsFound' } else { 'QueryFailed_Unknown' }
    }
    return $r
}

function Get-ProcessServiceSnapshot([string]$Root) {
    $r = [ordered]@{ ProcessQuery = 'Unknown'; Processes = @(); ServiceQuery = 'Unknown'; Services = @() }
    try {
        $items = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'WESTSIDE%' OR Name LIKE 'EasyAntiCheat%' OR Name = 'start_protected_game.exe' OR Name = 'EOSBootstrapper.exe'" -ErrorAction Stop)
        $r.Processes = @($items | ForEach-Object {
            $image = [string]$_.ExecutablePath
            $scope = if (-not $image) { 'Unknown_ImagePathUnavailable' } elseif ($image.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { 'InsideDesignatedAppRoot' } else { 'OtherRootOrShared_DoNotTerminate' }
            [ordered]@{ Name = $_.Name; ProcessId = $_.ProcessId; ParentProcessId = $_.ParentProcessId;
                ImagePath = $image; Scope = $scope; CreationDate = [string]$_.CreationDate }
        })
        $r.ProcessQuery = 'Read'
    } catch { $r.ProcessQuery = 'Failed_Unknown'; $r.ProcessError = Get-ReadFailure $_ }
    try {
        $r.Services = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'EasyAntiCheat%'" -ErrorAction Stop | ForEach-Object {
            [ordered]@{ Name = $_.Name; State = $_.State; StartMode = $_.StartMode; ProcessId = $_.ProcessId; Status = $_.Status }
        })
        $r.ServiceQuery = 'Read'
    } catch { $r.ServiceQuery = 'Failed_Unknown'; $r.ServiceError = Get-ReadFailure $_ }
    return $r
}

function Invoke-WestsideReadOnlyPreflight([string]$RootPath, [bool]$ShowHoldText) {
    $now = [datetime]::UtcNow
    $root = Get-LocalPlainDirectory $RootPath
    if ($root -eq [IO.Path]::GetPathRoot($root)) { throw 'AppRoot must not be a drive root.' }
    $markers = @(
        (Get-SafetyFile $root 'westside-eac-session.pending' 'Pending' $now $false),
        (Get-SafetyFile $root 'westside-eac-safety.hold' 'Hold' $now $ShowHoldText),
        (Get-SafetyFile $root 'westside-eac-auto-recovery.stamp' 'Quota' $now $false)
    )
    $archives = @(); $archiveStatus = 'Read'; $archiveError = $null
    try {
        $names = @(Get-ChildItem -LiteralPath $root -Force -Filter 'westside-eac-*' -ErrorAction Stop |
            Where-Object { $_.Name -match '^westside-eac-(safety\.hold\.(retry|protected-retry)|session\.pending\.protected-retry)-[0-9]+-[0-9]+\.bak$' } |
            Sort-Object Name | Select-Object -First 65)
        if ($names.Count -gt 64) { $archiveStatus = 'Truncated_StopForReview' }
        $archives = @($names | Select-Object -First 64 | ForEach-Object {
            $kind = if ($_.Name.StartsWith('westside-eac-safety.hold.')) { 'Hold' } else { 'ArchivedPending' }
            Get-SafetyFile $root $_.Name $kind $now $ShowHoldText
        })
    } catch { $archiveStatus = 'Failed_Unknown'; $archiveError = Get-ReadFailure $_ }
    $wer = Get-WerSnapshot $now
    $activity = Get-ProcessServiceSnapshot $root
    $issues = @()
    foreach ($m in $markers) {
        if ($m.Status -notin @('Present', 'Absent')) { $issues += ('UnknownMarker:' + $m.Name) }
        foreach ($issue in $m.Issues) { $issues += ($m.Name + ':' + $issue) }
    }
    if ($markers[1].Status -ne 'Absent') { $issues += 'HoldExistsOrUnknown_NoManualRemovalOrCloneBypass' }
    if ($wer.Status -notin @('Read', 'NoMatchingEventsFound')) { $issues += 'EventCoverageUnknownOrTruncated' }
    if ($archiveStatus -ne 'Read') { $issues += 'ArchiveInventoryIncomplete' }
    if ($activity.ProcessQuery -ne 'Read' -or $activity.ServiceQuery -ne 'Read') { $issues += 'ActivitySnapshotUnknown' }
    if ($activity.Processes.Count -gt 0) { $issues += 'MatchingProcessesPresent_OwnershipNotProved_DoNotKill' }
    if (@($activity.Services | Where-Object { $_.State -ne 'Stopped' }).Count -gt 0) { $issues += 'EacServiceNotStopped_ReviewActiveSession' }
    $afterPending = $null
    $pending = $markers[0]
    if ($pending.FileTime -and $pending.FileTime.Valid -and $wer.Status -in @('Read', 'NoMatchingEventsFound')) {
        $start = [datetime]::Parse($pending.FileTime.Utc).ToUniversalTime()
        $afterPending = @($wer.Events | Where-Object { [datetime]::Parse($_.TimeCreatedUtc).ToUniversalTime() -ge $start }).Count
        if ($afterPending -gt 0) { $issues += 'Wer1001AfterPending_Stop_NotProofEacCausedCrash' }
    }
    $quota = $markers[2]
    if ($quota.FileTime -and $quota.FileTime.Valid -and -not $quota.FileTime.AutomaticRecovery24HourTimestampEligible) {
        $issues += 'AutomaticBugcheckRecovery24HourTimestampQuotaNotAvailable'
    }
    [ordered]@{
        Schema = 'westside-test94-readonly-preflight-v1'; CollectedUtc = $now.ToString('o'); AppRoot = $root;
        MachineLocalClock = [datetimeoffset]::Now.ToString('o'); TimeZoneId = [TimeZoneInfo]::Local.Id;
        Markers = $markers; Archives = $archives; ArchiveStatus = $archiveStatus; ArchiveError = $archiveError;
        Wer = $wer; MatchingWerAfterPending = $afterPending; Activity = $activity; Issues = $issues;
        Decision = if ($issues.Count) { 'STOP_FOR_REVIEW' } else { 'SNAPSHOT_ONLY_REQUIRES_REVIEW_AND_EXPLICIT_LAUNCH_CONSENT' };
        LaunchAuthorized = $false;
        Limits = @('Not a launcher or safety-recovery invocation; no EAC/game/service actions.',
            'No full process command lines, service executable paths, WER messages, or event XML collected.',
            'Hardlink counts and atomic file identity are not verified; separate bounded read-only metadata review required.',
            'One designated root only; other roots may retain safety state. Cloning/restoring markers can defeat per-root holds/quota.',
            'NoMatchingEventsFound is not proof of never crashing. Source checks latest eight matching events; this snapshot checks up to 256.',
            'A timestamp/quota result is not recovery eligibility or permission; never reset holds, stamps, clocks or pending files.')
    }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Windows PowerShell/PowerShell on Windows required.' }
$report = Invoke-WestsideReadOnlyPreflight $AppRoot ([bool]$IncludeHoldText)
$json = $report | ConvertTo-Json -Depth 12
if ($ReportPath) {
    $output = Convert-LocalPlainPath $ReportPath
    $parent = Get-LocalPlainDirectory ([IO.Path]::GetDirectoryName($output))
    if ($output.Equals($report.AppRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $output.StartsWith($report.AppRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Report must be outside AppRoot.' }
    $stream = [IO.File]::Open($output, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $data = (New-Object Text.UTF8Encoding $false).GetBytes($json + [Environment]::NewLine)
        $stream.Write($data, 0, $data.Length)
    } finally { $stream.Dispose() }
}
$json
