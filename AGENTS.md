# AGENTS

## Purpose

Maintain `Get-SystemSummary.ps1` as a small, readable, privacy-conscious local reporting utility. Avoid introducing frameworks, external services, or unnecessary dependencies.

## Supported agents and entrypoint

This file is the primary agent entrypoint for:

- GitHub Copilot
- Hermes
- OpenCode

Agents should start here for implementation context, constraints, and validation expectations.

## Project layout

- `Get-SystemSummary.ps1` - main script and source of truth for behavior.
- `README.md` - human-oriented project overview, usage, and safety notes.
- `AGENTS.md` - agent-optimized execution context and guardrails.
- `.gitignore` - excludes local/editor artifacts and generated report output (`SystemSummary.md`).

## Current stable behavior

The script currently:

- Produces a Markdown report and writes it to `SystemSummary.md` by default.
- Supports `-OutputPath` and `-Clipboard`.
- Collects BIOS/baseboard/CPU/GPU/memory/storage details.
- Includes OS Name, Version (`<version> Build <build>`), and System Name.
- Includes local SMB share reporting (`Get-SmbShare`, excluding special shares).
- Includes raw `tailscale serve status` output in a fenced `text` block.

Treat the local script as the source of truth. Do not replace it wholesale when adding features.

## Non-negotiable constraints

- Keep Windows PowerShell 5.1 compatibility (`#Requires -Version 5.1`).
- Keep output consistent across file, console, and optional clipboard.
- Keep optional collectors best-effort: report failures, do not silently suppress them.
- Do not change machine configuration from the script (no execution-policy changes, no share/ACL/network/Serve configuration changes).
- Do not add telemetry, cloud upload, paid dependencies, or automatic elevation.

## Data and privacy boundaries

The report may include computer names, disk serials, share paths, tailnet hostnames, URLs, and local proxy targets. Preserve this as an inventory/reporting tool and avoid collecting unrelated sensitive data.

## Implementation notes to preserve

- OS version row must remain build-based (`Version + BuildNumber`), not marketing labels.
- SMB section scope is shares hosted on this PC only; user-created hidden shares remain eligible if not special.
- Tailscale section must use `tailscale serve status` (human-readable output), not `tailscale status` and not JSON substitution.

## Change workflow for future agents

1. Read `README.md`, then inspect `Get-SystemSummary.ps1`.
2. Preserve existing behavior and parameters.
3. Add only required changes; avoid unrelated refactors.
4. Validate syntax and execution before claiming behavior.
5. Update docs only for verified behavior.

## Validation checklist

- Default and custom output paths still work.
- Clipboard output matches saved Markdown content.
- OS name/version/system name render correctly.
- Drive-to-disk mapping remains intact.
- SMB reporting handles no shares and query failures gracefully.
- Tailscale reporting handles CLI present/missing and non-zero exit codes.
- No system configuration changes occur.
- Do not claim cross-version/platform validation unless executed.
