# System Summary

A small, local PowerShell script that collects a Windows PC's hardware and system details into a Markdown report. Designed to replace manual copying from Windows System Information and make the results easy to paste into notes.

## Project status

The original hardware-report script has been run successfully by the owner. Windows identification, SMB shares, and Tailscale Serve status were subsequently supplied as additions; verify that they are present in the local script before assuming these features are available.

## Requirements

- Windows, with Windows PowerShell 5.1 or PowerShell 7.
- Windows CIM and Storage cmdlets used by the script.
- Optional: NVIDIA's `nvidia-smi.exe` for NVIDIA VRAM reporting.
- Optional: Tailscale CLI for Serve status.

The script is intended to operate locally without downloading dependencies or uploading its report. Optional status commands query locally installed software.

## Usage

Open PowerShell in the script's directory:

```powershell
.\Get-SystemSummary.ps1
```

Display the report, save it, and copy it to the clipboard:

```powershell
.\Get-SystemSummary.ps1 -Clipboard
```

Choose the output file:

```powershell
.\Get-SystemSummary.ps1 -OutputPath "$HOME\Desktop\My-PC.md" -Clipboard
```

The default report is `SystemSummary.md` beside the script. An existing output file is overwritten. A custom output directory must already exist.

## Report contents

Original hardware summary:

- Processor name, reported maximum clock speed, core count, and logical processor count.
- BIOS manufacturer, version, release date, SMBIOS version, embedded-controller version, and firmware mode.
- Motherboard manufacturer, product, and revision.
- Graphics adapter names and NVIDIA VRAM when available.
- System-reported physical memory.
- Fixed drive letters, backing disk models, serial numbers, disk capacity, volume capacity, and volume labels.

Requested additions, subject to local integration:

- OS Name, Version, and System Name.
- Local SMB folder shares: share name, local folder, and UNC path; no ACL reporting.
- Raw `tailscale serve status` output in a fenced text block.

Capacities use GiB and TiB. The CPU speed is a reported maximum, not a live clock measurement. The graphics fallback reports names without guessing VRAM.

## Unsigned-script execution

The distributed script is unsigned. The owner encountered a signature-policy block when running the downloaded file.

Review the script before trusting it. Under `RemoteSigned`, unblock this specific file and try again:

```powershell
Unblock-File -LiteralPath '.\Get-SystemSummary.ps1'
.\Get-SystemSummary.ps1 -Clipboard
```

If it remains blocked, inspect policy:

```powershell
Get-ExecutionPolicy
Get-ExecutionPolicy -List
```

`AllSigned` still requires a trusted signature. Do not override organizational policy. On a personally controlled machine without Group Policy enforcement, a session-only `RemoteSigned` policy was discussed as an option:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

Do not add automatic execution-policy changes to the script.

## Privacy and scope

The report can contain computer names, disk serial numbers, share paths, tailnet hostnames, URLs, and local proxy destinations. Review it before sharing publicly.

This is an inventory/reporting tool, not a configuration tool. It must not change shares, ACLs, firmware, network configuration, or Tailscale Serve settings.
