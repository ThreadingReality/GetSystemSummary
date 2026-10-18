# Development Handoff

## Goal

Continue development of `Get-SystemSummary.ps1` locally in Visual Studio with GitHub Copilot. Keep it a small, readable, privacy-conscious PowerShell utility rather than introducing an application framework or unnecessary dependencies.

The owner originally copied hardware details manually from Windows System Information. The script replaces that process with a Markdown report suitable for notes.

## Confirmed state versus proposed changes

### Confirmed by the owner

- The original generated script works well on the owner's machine.
- The downloaded unsigned script initially hit a PowerShell signature/execution-policy block.
- The owner subsequently reported that it was working; the precise policy/unblocking action used was not confirmed.

### Supplied later, not confirmed integrated or tested

Three insertion blocks were provided for:

1. OS Name, Version, and System Name.
2. Local SMB folder shares.
3. Tailscale Serve status.

Inspect the actual local script first. Do not assume those additions were applied. The local working copy is the source of truth; avoid replacing it wholesale or duplicating already-integrated blocks.

No automated tests or repository layout were established in the conversation. Do not claim PowerShell 5.1/7 cross-version validation or successful optional-feature testing without running it.

## Existing script interface

```powershell
.\Get-SystemSummary.ps1
.\Get-SystemSummary.ps1 -Clipboard
.\Get-SystemSummary.ps1 -OutputPath .\My-PC.md -Clipboard
```

Parameters:

- `OutputPath`: defaults to `SystemSummary.md` alongside the script.
- `Clipboard`: copies the same Markdown that is saved and displayed.

The script uses `#Requires -Version 5.1` and `$ErrorActionPreference = 'Stop'`.

Existing helpers:

- `Format-Size`: binary GiB/TiB formatting.
- `Escape-Cell`: flattens newlines and escapes Markdown table pipes.
- `Add-Row`: adds an Attribute/Value object to `$rows`.

The report begins as an Attribute/Value table assembled into `$lines`. The final section joins `$lines` into `$markdown`, saves UTF-8 output, optionally calls `Set-Clipboard`, and prints the report and output location.

## Original collection logic

- `Win32_BIOS`: BIOS details, SMBIOS version, embedded-controller version.
- `Win32_BaseBoard`: motherboard information.
- `Win32_ComputerSystem`: total physical memory and system information.
- `Win32_Processor`: name, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors.
- `Get-ComputerInfo -Property BiosFirmwareType`: firmware mode, with an Unknown fallback.
- `Win32_VideoController`: graphics names.
- `nvidia-smi.exe --query-gpu=name,memory.total --format=csv,noheader,nounits`: optional NVIDIA VRAM.
- `Get-Volume`, `Get-Partition`, `Get-Disk`: fixed volumes mapped to backing disks, not positional disk assumptions.

NVIDIA CLI lookup checks PATH and then `Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe`. If VRAM cannot be obtained, report names rather than deriving large VRAM values from legacy WMI AdapterRAM.

## Requested additions

### Windows identification

Insert after collecting `$system`, once `Add-Row` exists:

```powershell
$os = Get-CimInstance Win32_OperatingSystem
Add-Row 'OS Name' $os.Caption.Trim()
Add-Row 'Version' ('{0} Build {1}' -f $os.Version, $os.BuildNumber)
Add-Row 'System Name' $system.Name
```

Match System Information's formatting. Do not substitute a marketing release label such as 24H2 for the requested Version row. Do not confuse the Windows computer name with a Tailscale/MagicDNS name.

### Local SMB shares

Append a `## Network shares` section to `$lines`, before final Markdown assembly.

Collect:

```powershell
Get-SmbShare -ErrorAction Stop |
    Where-Object { -not $_.Special -and $_.Path } |
    Sort-Object Name
```

Columns: Share name, Local folder, Network path.

Construct UNC paths using:

```powershell
$unc = '\\{0}\{1}' -f $system.Name, $_.Name
```

Use `Escape-Cell` for each table cell. Exclude special administrative shares, not every share whose name ends with `$`. User-created hidden folder shares should remain eligible.

Scope is shares hosted on this PC, not mapped drives, remote machines visible in Explorer, ACLs, or permissions analysis. Distinguish no shares found from a collection failure. A failure should appear in the report without aborting the hardware summary.

### Tailscale Serve status

Append a `## Tailscale Serve status` section before final Markdown assembly.

- Look up `tailscale.exe` in PATH, then `Program Files\Tailscale\tailscale.exe`.
- Invoke only `tailscale serve status`.
- Preserve the human-readable output in a fenced `text` block.
- Capture exit status and report nonzero exit codes/errors without losing the rest of the inventory.
- Report missing CLI explicitly.
- Do not configure, start, reset, or otherwise change Serve.
- Do not silently replace this with `tailscale status` or JSON output: the requested result is the Serve mapping display.

The owner showed two HTTPS Serve endpoints with localhost proxy targets on ports 3000 and 4000. Those were examples of existing configuration, not defaults to hardcode.

## Design constraints

- Keep existing command-line behavior and Markdown output compatible.
- Preserve Windows PowerShell 5.1 syntax; avoid PowerShell 7-only operators.
- No downloads, cloud reporting, telemetry, paid dependencies, or automatic elevation.
- Do not change execution policy from inside the script.
- Do not request ACL collection or extra sensitive identifiers beyond the requested inventory.
- Keep optional collectors best-effort; failure should be visible, not silently interpreted as absence.
- Keep report text consistent between file, console, and clipboard.
- Do not truncate disk serial numbers to match the owner's earlier hand-typed notes.

## Suggested next steps

1. Inspect the local script and diff it against these requirements.
2. Integrate only missing additions.
3. Run PowerShell syntax parsing before execution.
4. Run locally and compare requested fields with Windows System Information.
5. Compare share output with `Get-SmbShare` and Serve output with `tailscale serve status`.
6. Verify saved report and clipboard contain both new sections.
7. Update README to mark additions implemented only after verification.

## Validation checklist

- Default and custom output paths work; existing-file overwrite behavior is understood.
- Output and clipboard match, apart from the console's separate saved-location message.
- OS name, version/build, and system name match the local system.
- Drive letters map to the correct disk models and volume labels.
- Graphics reporting handles absent NVIDIA tooling without aborting.
- SMB reporting handles spaces, hidden user shares, no shares, and query errors.
- Special administrative shares are excluded.
- Tailscale reporting handles installed CLI, missing CLI, no Serve configuration, and command failure.
- Markdown cells containing pipes/newlines remain valid.
- Both Windows PowerShell 5.1 and PowerShell 7 are tested if compatibility is claimed.
- No system configuration changes occur.

## Known limitations and possible follow-ups

These are candidates for review, not claims that the owner encountered defects:

- Startup CIM queries are mostly required and can still abort the script on failure.
- Custom output directories are not created automatically.
- Firmware-mode collection may be comparatively slow.
- System-reported physical memory can differ from the sum of installed DIMM capacities.
- Storage Spaces, dynamic/spanned volumes, USB bridges, or unusual drivers may complicate disk mapping or serial reporting.
- External CLI execution currently has no explicit timeout.
- Windows PowerShell 5.1 and PowerShell 7 may differ in native stderr handling; verify the Tailscale error path in both.
- Native CLI CSV parsing and culture-sensitive formatting deserve testing.
- Reports contain identifying information: review before publishing.

## Suggested Copilot starting prompt

> Read README.md and HANDOFF.md, then inspect Get-SystemSummary.ps1. Preserve the working hardware collection and existing parameters. Determine whether OS identification, local SMB shares, and Tailscale Serve status are already implemented. Add only missing functionality, retain Windows PowerShell 5.1 compatibility, and do not change machine configuration or execution policy. Show the proposed diff and validation plan before broader refactoring.
