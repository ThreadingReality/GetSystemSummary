#Requires -Version 5.1
<#
.SYNOPSIS
Exports a local hardware summary as a Markdown table. No downloads required.
.EXAMPLE
.\Get-SystemSummary.ps1
.EXAMPLE
.\Get-SystemSummary.ps1 -OutputPath .\My-PC.md -Clipboard
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'SystemSummary.md'),
    [switch]$Clipboard
)
$ErrorActionPreference = 'Stop'

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1TB) { return ('{0:0.##} TiB' -f ($Bytes / 1TB)) }
    return ('{0:0.##} GiB' -f ($Bytes / 1GB))
}
function Escape-Cell([object]$Value) {
    return (([string]$Value -replace '\r?\n', ' ') -replace '\|', '\|')
}
$rows = [System.Collections.Generic.List[object]]::new()
function Add-Row([string]$Attribute, [object]$Value) {
    $rows.Add([pscustomobject]@{ Attribute = $Attribute; Value = $Value })
}

$bios = Get-CimInstance Win32_BIOS
$board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
$system = Get-CimInstance Win32_ComputerSystem
$processors = @(Get-CimInstance Win32_Processor | ForEach-Object {
    '{0}, {1} MHz, {2} Core(s), {3} Logical Processor(s)' -f `
        $_.Name.Trim(), $_.MaxClockSpeed, $_.NumberOfCores, $_.NumberOfLogicalProcessors
})
Add-Row 'Processor' ($processors -join '; ')
$date = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('MM/dd/yyyy') } else { 'Unknown' }
Add-Row 'BIOS Version/Date' ('{0} {1}, {2}' -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion, $date)
Add-Row 'SMBIOS Version' ('{0}.{1}' -f $bios.SMBIOSMajorVersion, $bios.SMBIOSMinorVersion)
Add-Row 'Embedded Controller Version' ('{0}.{1}' -f $bios.EmbeddedControllerMajorVersion, $bios.EmbeddedControllerMinorVersion)
try {
    $mode = [string](Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType
    if ([string]::IsNullOrWhiteSpace($mode)) { $mode = 'Unknown' }
} catch { $mode = 'Unknown' }
Add-Row 'BIOS Mode' $mode
Add-Row 'BaseBoard Manufacturer' $board.Manufacturer
Add-Row 'BaseBoard Product' $board.Product
Add-Row 'BaseBoard Version' $board.Version

# NVIDIA's utility reports VRAM without the legacy WMI AdapterRAM size limit.
$gpuNames = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
$smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
$smiPath = if ($smi) { $smi.Source } else {
    Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'
}
if (Test-Path -LiteralPath $smiPath) {
    try {
        $raw = @(& $smiPath '--query-gpu=name,memory.total' '--format=csv,noheader,nounits' 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $nvidia = @($raw | ConvertFrom-Csv -Header Name, MemoryMiB)
            foreach ($gpu in $nvidia) {
                $name = $gpu.Name.Trim()
                $vram = [double]::Parse($gpu.MemoryMiB.Trim(), [Globalization.CultureInfo]::InvariantCulture) / 1024
                $gpuNames = @($gpuNames | Where-Object { $_ -ne $name })
                $gpuNames += ('{0} ({1:0.##} GiB VRAM)' -f $name, $vram)
            }
        }
    } catch { Write-Warning 'Could not read NVIDIA VRAM; reporting graphics names only.' }
}
Add-Row 'Graphics' ($gpuNames -join '; ')
Add-Row 'Memory' (Format-Size $system.TotalPhysicalMemory)

# Resolve each drive letter to its backing disk, rather than assuming disk order.
$volumes = @(Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | Sort-Object DriveLetter)
foreach ($volume in $volumes) {
    $letter = [string]$volume.DriveLetter
    try {
        $disks = @(Get-Partition -DriveLetter $letter | Get-Disk | Sort-Object Number -Unique)
        $details = @($disks | ForEach-Object {
            $serial = ([string]$_.SerialNumber).Trim()
            if (!$serial) { $serial = 'Not reported' }
            '{0} (disk: {1}; SN:{2})' -f $_.FriendlyName, (Format-Size $_.Size), $serial
        })
        if (!$details.Count) { throw 'No backing disk found.' }
        $value = '{0} (volume: {1}) ({2})' -f ($details -join '; '), (Format-Size $volume.Size), $volume.FileSystemLabel
    } catch {
        $value = 'Volume: {0} ({1}); backing disk unavailable' -f (Format-Size $volume.Size), $volume.FileSystemLabel
        Write-Warning ('Could not resolve disk for {0}: {1}' -f $letter, $_.Exception.Message)
    }
    Add-Row ($letter + ': Drive') $value
}

$lines = @('| Attribute | Value |', '| --- | --- |')
$lines += @($rows | ForEach-Object {
    '| {0} | {1} |' -f (Escape-Cell $_.Attribute), (Escape-Cell $_.Value)
})
$markdown = $lines -join [Environment]::NewLine
$markdown | Set-Content -LiteralPath $OutputPath -Encoding UTF8
if ($Clipboard) { Set-Clipboard -Value $markdown }
Write-Output $markdown
Write-Host "`nSaved to: $OutputPath"
