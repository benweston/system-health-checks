# System Health Checks (`system-health-checks`) - Agent Instructions

## Project Overview

This repository contains automated bare-metal diagnostic scripts and agentic   
forensic analysis workflows for an enterprise Linux mobile workstation.   
Its purpose is to execute privileged telemetry collection scripts that output   
structured diagnostic reports into `system-reports/`, followed by a deeply   
technical forensic evaluation and actionable engineering recommendations.   
Over time, iterative manual diagnostic runs and targeted remediations   
progressively harden kernel stability, firmware security posture, and   
redundant storage reliability.   

---

## Target Platform & Architecture Context

- **Hardware Platform:** Lenovo ThinkPad mobile workstation (ThinkPad P16   
  series) featuring hybrid graphics (Intel integrated graphics + discrete   
  NVIDIA RTX Laptop GPU), TPM 2.0, and Thunderbolt / USB4 controllers.   
- **Operating System & Boot:** Fedora Linux Workstation, UEFI Secure Boot   
  (MOK enforced), and `GRUB2` / `shim` (with `systemd-boot` fallback).   
- **Storage Stack:** Dual physical NVMe SSDs (`/dev/nvme0`, `/dev/nvme1`)   
  configured with Linux `mdadm` Software RAID1 (`md0` backing `/boot` as   
  `ext4`; `md127` backing a `LUKS2` encrypted container formatted with   
  `Btrfs` for `/`), paired with `zram` swap.   
- **Operational Power & Lid Policy:** Operated primarily on continuous AC   
  power (with EC battery conservation thresholds capped at `75%–80%`).   
  `HandleLidSwitch=lock` (`S0` session persistence with the lid closed,   
  including brief unplugged room-to-room moves) and the `performance`   
  (`throughput-performance`) ACPI/`TuneD` profile are intentional choices   
  to prevent interruption of running scripts and workloads; do **not**   
  penalise these in health scores unless thermal throttling occurs.   

> [!IMPORTANT]
> **Diagnostic Tone & Analytical Rigour:** Maintain a grounded, objective,   
> and deeply technical engineering tone across all analyses. Avoid generic   
> troubleshooting advice, introductory fluff, or surface-level definitions;   
> evaluate telemetry strictly against bare-metal Linux, UEFI/ACPI, PCIe,   
> and storage architectural realities.   

---

## Directory Structure

```text
system-health-checks/
├── forensic-reports/             # Local Markdown forensic reports (ignored)
│   └── YYYY-MM-DD-HHMM-forensic-report.md
├── system-checks/                # Privileged diagnostic shell scripts (.sh)
│   ├── 01_01_system_check.sh     # System, kernel, suspend & logind checks
│   ├── 02_01_firmware_check.sh   # BIOS, EC, Secure Boot, TPM2 & LVFS checks
│   └── 03_01_nvme_raid_check.sh  # NVMe SMART, PCIe, mdadm RAID1 & Btrfs
├── system-reports/               # Raw diagnostic text dumps (git-ignored)
│   ├── 01_01_system_report.txt
│   ├── 02_01_firmware_report.txt
│   └── 03_01_nvme_raid_report.txt
├── .gitignore                    # Excludes reports, workspace & secrets
├── run_checks.sh                 # Root master runner for all check scripts
├── README.md                     # Project overview & operator documentation
├── GEMINI.md                     # Canonical instructions & playbooks
└── AGENTS.md                     # Symlink to GEMINI.md for compatibility
```

---

## Diagnostic Workflow & Commands

All diagnostic collection scripts require root privileges (`sudo`) to query   
SMBIOS/DMI tables, kernel ring buffers, NVMe controller logs, SMART   
attributes, `mdadm` metadata, and TPM 2.0 PCR banks. Scripts dynamically   
resolve `system-reports/` within the project root and restore `$SUDO_USER`   
file ownership upon completion.   

| Script (`system-checks/`)  | Generated Report (`system-reports/`) |
| :------------------------- | :----------------------------------- |
| `01_01_system_check.sh`    | `01_01_system_report.txt`            |
| `02_01_firmware_check.sh`  | `02_01_firmware_report.txt`          |
| `03_01_nvme_raid_check.sh` | `03_01_nvme_raid_report.txt`         |

- **Master Runner (All Checks):** `sudo ./run_checks.sh` — Dynamically   
  discovers and executes all numbered scripts in `system-checks/` in sorted   
  order.   
- **Execution (`01_01`):** `sudo ./system-checks/01_01_system_check.sh` —   
  Suspend/wake, `systemd-logind`, MCEs, `dmesg` faults, PCIe/NVMe errors,   
  failed units, and recent coredumps.   
- **Execution (`02_01`):** `sudo ./system-checks/02_01_firmware_check.sh` —   
  SMBIOS/DMI, BIOS/EC sync, Secure Boot/TPM2 PCRs, `fwupd`/LVFS,   
  `thinkpad_acpi`, dGPU VBIOS, microcode, and USB4/Thunderbolt.   
- **Execution (`03_01`):** `sudo ./system-checks/03_01_nvme_raid_check.sh` —   
  Block, LUKS, and Btrfs layout, `mdadm` RAID1 status, NVMe SMART & error   
  logs, PCIe `LnkCap`/`LnkSta`, and storage I/O logs.   

### Standard Iterative Run Lifecycle

1. **Collect Telemetry:** Execute `sudo ./run_checks.sh` (or individual   
   scripts in `system-checks/`, with user consent for `sudo` or run manually   
   by the user) to refresh `system-reports/`.   
2. **Prior-Run Lookup:** List `forensic-reports/` in chronological order and   
   read the immediately preceding `YYYY-MM-DD-HHMM-forensic-report.md`   
   snapshot (when available) to establish the comparison baseline.   
3. **Forensic Audit & Delta Analysis:** Parse all generated reports in   
   `system-reports/` systematically against the three domain playbooks and   
   the **Longitudinal Delta Protocol** below, correlating cross-subsystem   
   events and quantifying progression from the prior run.   
4. **Engineering Remediation Plan:** Deliver prioritised, non-destructive   
   engineering recommendations to improve reliability, performance, or   
   security posture.   
5. **Persist Immutable Snapshot & Executive Triage:** Save the full Markdown   
   evaluation to `forensic-reports/YYYY-MM-DD-HHMM-forensic-report.md`   
   (keyed to the `HHMM` capture timestamp in `system-reports/` so same-day   
   runs never overwrite each other), wrapped strictly at `<= 80` columns,   
   and explicitly answer both mandatory closing evaluation questions.   

### Longitudinal Delta Protocol

Whenever at least one historical report exists in `forensic-reports/`, every   
new forensic evaluation **must** open with a structured **Longitudinal Delta   
Summary** (`Previous Run -> Current Run`) auditing four dimensions:   

1. **Health Score Progression:** Track overall and per-domain numerical   
   sub-score deltas (`+/-`) alongside any shift in the Critical Issues Gate.   
2. **Remediation & Anomaly State:** Verify whether previously open actions   
   or upstream driver quirks are **Resolved**, **Unchanged**, or   
   **Regressed**, and isolate newly emerged anomalies since the last run.   
3. **Platform & Firmware Drift:** Record changes across kernel version, CPU   
   microcode patch level, NVIDIA driver/VBIOS, system BIOS/EC versions, and   
   LVFS device firmware payloads.   
4. **PCIe-Keyed NVMe Monotonic Counters (CRITICAL):** Because asynchronous   
   Linux PCIe probing swaps `/dev/nvme0` and `/dev/nvme1` device nodes   
   across reboots, **always** match physical SSDs by **PCIe BDF address**   
   (`0000:04:00.0` CPU Root Port vs `0000:81:00.0` PCH Root Port via   
   `nvme list-subsys`), **never** by `/dev/nvmeX` name. Diff monotonic SMART   
   counters (`Unsafe Shutdowns`, `Percentage Used`, `Available Spare`,   
   `Media and Data Integrity Errors`, `Error Information Log Entries`, and   
   `Data Units Written`) strictly per physical PCIe slot.   

---

## Forensic Analysis Playbooks

When analysing reports in `system-reports/`, adopt the specialised   
engineering lens for each domain and evaluate every required layer   
systematically.   

### 1. System, Kernel & Session Forensics (`01_01_system_report.txt`)

**Analytical Lens:** Senior Linux Kernel Engineer and Systems Forensic   
Analyst specialising in enterprise hardware architectures, hybrid graphics   
pipelines (Intel/NVIDIA discrete architectures), and `systemd` user-session   
management.   

1. **Executive Timeline Snapshot:**   
   - Map exact timestamps of major operational milestones captured in the   
     log (e.g. Boot/Session Init, Lid Closed, Lid Opened, Suspend/Resume   
     transitions, Script Execution).   
   - Calculate the precise duration of any silent periods, hangs, or   
     session lockouts.   
2. **Forensic Root Cause Analysis (RCA):**   
   - Isolate primary hardware or software subsystem anomalies.   
   - Distinguish explicitly between a hard kernel deadlock / PCIe bus   
     timeout versus a user-space rendering delay or `systemd-logind` /   
     Wayland session state lag.   
   - Decode low-level error patterns (e.g. driver code mismatches, Intel   
     PHY/DDI buffer state failures, ACPI quirks, or NVIDIA GSP/SBIOS   
     handshakes).   
3. **Silicon & Storage Lifeline Assessment:**   
   - Audit Machine Check Exceptions (MCE), failed `systemd` units,   
     application coredumps (`coredumpctl`), and Storage Topology data.   
   - Provide a definitive health assessment: verify whether physical   
     silicon or memory lanes suffered thermal or voltage trauma, and   
     whether storage layers or device-mapper targets experienced dirty   
     drops or corruption.   
4. **Operational Verdict & Next Actions:**   
   - State clearly whether observed anomalies represent known driver/kernel   
     regressions, hardware faults, or transient software lag.   
   - Provide clear, actionable, non-destructive recommendations or   
     workarounds to protect operational uptime.   

### 2. Firmware, UEFI/BIOS & Security (`02_01_firmware_report.txt`)

**Analytical Lens:** Principal Firmware Security Architect and Linux   
Hardware Enablement Engineer specialising in UEFI/BIOS specifications,   
Embedded Controller (EC) state machines, platform security primitives   
(TPM 2.0, Secure Boot, MOK), and PCIe/Thunderbolt subsystem firmware on   
enterprise mobile workstations.   

1. **Platform Topology & SMBIOS/DMI Integrity:**   
   - Parse SMBIOS/DMI table dumps: audit system identity, chassis   
     enclosure, baseboard revision, product SKU, and family metadata.   
   - Cross-reference system BIOS build dates and versions against Embedded   
     Controller (EC) firmware releases to identify version   
     desynchronisation, incomplete board-level flashing, or mismatches.   
2. **Security Subsystem & Root-of-Trust Audit:**   
   - Evaluate UEFI Secure Boot operational state: confirm enrolment status,   
     Setup Mode vs User Mode, and Machine Owner Key (MOK) enforcement.   
   - Audit the TPM 2.0 hardware interface: verify character device node   
     exposure (`/dev/tpm0`, `/dev/tpmrm0`), subsystem driver binding, and   
     hardware descriptor state.   
   - Inspect bootloader and PCR telemetry (`GRUB2` / `shim` SHA-256 PCR   
     banks `4, 8, 9` via `tpm2_pcrread`, or `systemd-boot` / `bootctl`   
     primitives) to identify boot-path security gaps, PCR measurement   
     readiness, or NVRAM variable lockouts.   
3. **Cognate Firmware & Silicon Microcode Verification:**   
   - Audit CPU microcode revision: correlate `/proc/cpuinfo` patch levels   
     with early-boot `journalctl` microcode application events to verify   
     hardware mitigations against transient execution and architectural   
     side-channel vulnerabilities.   
   - Decode discrete GPU (dGPU) VBIOS metadata and driver handshakes:   
     evaluate VBIOS version strings, active PCIe link/P-states, thermal   
     boundaries, and power envelope telemetry.   
   - Parse storage controller (NVMe) vendor firmware revisions across all   
     exposed namespaces, flagging legacy revision baselines or known   
     controller errata.   
4. **ACPI, Peripheral Bus & LVFS Component Status:**   
   - Evaluate ThinkPad-specific ACPI driver (`thinkpad_acpi`) topology:   
     verify kernel module attachment, sub-driver hooks, and active   
     `platform_profile` state (`performance`, `balanced`, `low-power`).   
   - Audit Thunderbolt / USB4 controller firmware: verify host generation,   
     IOMMU DMA security level, and active domain enrolment via `boltctl`.   
   - Parse `fwupd` / LVFS device inventory and update queues: enumerate all   
     capsule-updateable devices, identify outdated firmware payloads, and   
     verify update readiness.   
5. **Kernel Firmware Pipeline & Anomaly Trace:**   
   - Conduct a granular audit of `dmesg` and `journalctl` events for   
     missing firmware blobs, direct firmware load failures, regulatory   
     domain timeouts, or ucode load retries.   
   - Isolate any ACPI method aborts, AML interpreter exceptions, or   
     bus-mastering handshake failures affecting peripheral components.   
6. **Operational Verdict & Firmware Remediation Roadmap:**   
   - Categorise platform firmware posture as **Nominal/Secured**,   
     **Non-Compliant/Exposed**, or **Desynchronised/Errant**.   
   - Provide a targeted, sequential engineering remediation checklist (e.g.   
     capsule deployment via `fwupdmgr`, manual BIOS/EC sync routines,   
     Secure Boot `db`/`dbx` key updates, or kernel module parameters).   

### 3. NVMe RAID1 & Storage Forensics (`03_01_nvme_raid_report.txt`)

**Analytical Lens:** Principal Linux Storage Systems Engineer and Hardware   
Reliability Architect specialising in NVMe protocol telemetry, PCIe fabric   
topology, and block-layer software RAID (`mdraid` / `dm-crypt` LUKS /   
`Btrfs`).   

1. **Array Integrity & Topology Audit:**   
   - Evaluate block-layer hierarchy (`lsblk`) and `mdstat`/`mdadm` status:   
     confirm array operational state (`clean`, `degraded`, `rebuilding`, or   
     `resyncing`), superblock version/persistence, chunk size, internal   
     intent bitmap, and per-device state flags (`[UU]`, active sync vs   
     spare/faulty).   
   - Evaluate EFI System Partition (`/boot/efi`) redundancy posture across   
     both drives, `LUKS` device-mapper status, and filesystem-level   
     (`Btrfs` / `ZFS`) pool redundancy and allocation state.   
2. **NVMe Physical Telemetry & Wear Profiles:**   
   - Conduct a side-by-side comparative health breakdown for both physical   
     NVMe controllers (`/dev/nvme0` and `/dev/nvme1`).   
   - Audit critical SMART telemetry: Critical Warnings (`0x00` bitmap   
     decode), Composite/Sensor Temperatures and throttling thresholds,   
     Available Spare vs Available Spare Threshold, Percentage Used (wear   
     endurance), Data Units Read/Written, Media and Data Integrity Errors,   
     Error Information Log Entries, and Unsafe Shutdown counters.   
   - Inspect NVMe controller error logs (`nvme error-log`) for   
     submission/completion queue timeouts, asynchronous event requests   
     (AER), or command aborts.   
3. **PCIe Fabric & Bus Negotiation Forensics:**   
   - Audit PCIe Link Capabilities (`LnkCap`) versus Link Status (`LnkSta`)   
     for each NVMe controller across the bus.   
   - Confirm whether each drive negotiates its maximum rated transfer speed   
     (GT/s) and lane width (e.g. PCIe Gen4/Gen5 x4 vs fallback).   
   - Detect any evidence of physical link degradation, uncorrectable AER   
     bus events, ASPM link-state oscillation, or controller reset   
     anomalies.   
4. **I/O Timing, Retries & System Log Trace:**   
   - Correlate `dmesg` and `journalctl` events to isolate any   
     `blk_update_request` errors, NVMe command aborts, host-memory buffer   
     (HMB) failures, or block-layer I/O wait spikes.   
   - Distinguish cleanly between benign platform quirks (e.g. `platform   
     quirk: setting simple suspend`), transient host delays, firmware   
     lockups, and unrecoverable NAND flash faults.   
5. **Operational Verdict & Reliability Roadmap:**   
   - Categorise storage subsystem health as **Nominal**,   
     **Degrading/Early-Warning**, or **Critically Compromised**.   
   - Provide clear, actionable engineering recommendations (e.g. periodic   
     `mdadm` scrub scheduling, EFI System Partition sync hooks, sysfs/I/O   
     tuning, firmware updates, or physical drive replacement timelines).   

---

## Mandatory Closing Evaluation Questions

At the conclusion of every comprehensive forensic analysis (and whenever   
prompted directly), always provide explicit, evidence-backed answers to   
both core evaluation questions:   

1. **System Health Score (`1–10`):**   
   *"On a scale of 1–10, how do you rate the system?"*   
   - Provide an overall numerical score (e.g. `9.2 / 10`) alongside   
     sub-scores across **System & Kernel Stability**, **Firmware & Security   
     Posture**, and **Storage & RAID Reliability**.   
   - Justify exact point deductions transparently based on observed   
     telemetry (e.g. pending LVFS security updates, `/boot/efi` sync   
     caveats, coredumps, thermal throttling, or driver warnings) and track   
     progression across runs when context is available.   
2. **Immediate Critical Issues Gate:**   
   *"Any critical issues that need to be fixed now?"*   
   - Deliver an unambiguous **Yes / No** verdict up front.   
   - Reserve **Critical (Fix Now)** strictly for active risks of data loss   
     (e.g. degraded RAID array, non-zero NVMe media integrity errors),   
     severe security exposure (e.g. Secure Boot disabled unexpectedly,   
     high-severity firmware CVEs with available LVFS fixes), or hardware   
     instability (e.g. MCEs, kernel panics, PCIe link drops).   
   - Separate routine hardening, housekeeping, and non-urgent upstream   
     driver quirks into a distinct preventative backlog.   

---

## Coding Standards, System Safety & Agent Guardrails

- **Host & Hardware Mutation Consent (CRITICAL):** Agents **must never**   
  execute state-mutating, firmware-flashing, storage-modifying,   
  bootloader-altering, or package-management commands (e.g.   
  `fwupdmgr update`, `mdadm --manage`, `nvme format`, `grub2-mkconfig`,   
  `mokutil --import`, `dnf install/remove`, `systemctl` state changes)   
  without explicit prior instruction and consent from the user for that   
  specific action. Privileged diagnostic collection   
  (`sudo ./run_checks.sh` or `sudo ./system-checks/0*.sh`) may only be run   
  when requested or approved by the user.   
- **Git, Release & Ticket Closure Consent (CRITICAL):** Agents **must   
  never** execute `git commit`, `git push`, `git tag`, or close GitHub   
  issues (including using `closes #<n>` in commit messages) without   
  explicit prior instruction and consent from the user for that specific   
  action. All work must remain in the local working tree unless explicitly   
  instructed otherwise.   
- **Report & Directory Boundaries:** Treat timestamped snapshots in   
  `forensic-reports/YYYY-MM-DD-HHMM-forensic-report.md` as **immutable   
  historical records**. Never delete, move, or overwrite prior forensic   
  assessments in `forensic-reports/` (or raw dumps in `system-reports/`   
  outside requested diagnostic runs) without explicit user instruction.   
- **Bash Scripting Standards:**   
  - Target `#!/bin/bash`, enforce `EUID -eq 0` checks on privileged   
    scripts, and validate clean syntax/linting via `bash -n` and   
    `shellcheck -S warning`.   
  - Resolve `REPORT_DIR` dynamically relative to the repository rather than   
    hardcoding external user paths, and restore file ownership to   
    `$SUDO_USER` when invoked under `sudo`.   
  - Degrade gracefully with clear diagnostic notes when optional CLI   
    utilities (`smartctl`, `nvme`, `fwupdmgr`, `boltctl`, `tpm2_pcrread`)   
    are absent rather than aborting mid-report.   
- **Language & Locale:** Standardise on British English (`en-GB`) for all   
  documentation, script comments, forensic reports, and user-facing text   
  (e.g. *optimised*, *synchronised*, *categorise*, *analyse*, *behaviour*,   
  *colour*).   
- **Privacy & Hardware Redaction:** Never include personal email addresses,   
  sensitive credentials, or raw unique hardware identifiers (such as   
  system/chassis/baseboard/NVMe serial numbers, LUKS/filesystem UUIDs, or   
  MAC addresses) in public-facing documentation, wikis, forensic artifacts,   
  commit messages, or committed instruction files. Use generic role titles   
  (e.g. *Project Owner*, *Systems Administrator*).   
- **Documentation Preservation:** Maintain documentation and script   
  integrity. Keep existing headers, section banners, comments, and licences   
  intact unless refactoring is explicitly requested.   
- **Markdown 80-Column Line Width & Hard Line Breaks:** Across all Markdown   
  files, forensic report artifacts, documentation, and GitHub issue/release   
  bodies (except `README.md`; see exception below):   
  - Enforce hard line breaks at a maximum width of **80 characters** per   
    line (including tables, diagrams, and code blocks; place long   
    unbreakable `file://` links on dedicated bullet lines).   
  - Explicitly enforce line endings on all non-heading, non-table, and   
    non-code-block text lines (including paragraphs, list items, and   
    blockquotes) by appending **3 trailing spaces** (`   `) at the end of   
    each line (so visible text is `<= 77` characters plus `3` trailing   
    spaces).   
  - **Root `README.md` Exception:** `README.md` wraps prose, lists,   
    blockquotes, and tables in `<div align="justify">` blocks (without   
    `---` section dividers) and keeps each paragraph or list item on a   
    single unwrapped line ending with `3` trailing spaces (`   `) so GitHub   
    renders full-width justification cleanly; fenced code blocks in   
    `README.md` still remain `<= 80` characters per line.   

---

## Release Workflow

If versioned in Git/GitHub, cut releases using annotated tags (standardised   
on the `sublime-font-checks` convention):   

1. **Commit Verified Changes (with explicit user consent):**   
   ```bash
   git add .
   git commit -m "chore(release): prepare release v<x.y.z>"
   git push origin main
   ```
2. **Create & Push Annotated Tag:**   
   ```bash
   git tag -a v<x.y.z> -m "Release v<x.y.z> - <Title>"
   git push origin v<x.y.z>
   ```
3. **Publish GitHub Release:**   
   Create a release from the tag on GitHub with structured notes:   
   - `## Highlights`   
   - `## Key Focus Areas`   
   - `## Next Steps`   

---

## Standardised Issue & Ticket Specification

All issues, remediation tasks, and project board cards MUST strictly follow   
the exact 4-section structure below (wrapped at `<= 80` characters with   
3 trailing spaces at the end of every non-heading/non-code line). No   
deviations or ad-hoc formats are permitted. Acceptance criteria represent   
hard requirements that must be verified prior to promoting work to Done.   

```markdown
### Overview

[Concise 1–2 sentence statement of purpose, context, and outcome]   

### Requirements & Scope

1. **[Area 1]:** [Specific deliverable or remediation step]   
2. **[Area 2]:** [Specific deliverable or remediation step]   
3. **[Area 3]:**   
   - **[Sub-item A]:** [Details]   
   - **[Sub-item B]:** [Details]   
4. **[Area 4]:** [Specific deliverable or verification step]   

### Technical Considerations

- [Kernel, firmware, ACPI, PCIe, or storage subsystem constraints]   
- [Non-destructive execution and rollback/backup considerations]   
- [Standards compliance (e.g. ShellCheck, root/sudo handling, en-GB)]   

---

### Acceptance Criteria

- [ ] Diagnostic scripts pass `bash -n` and `shellcheck -S warning` cleanly.   
- [ ] [Verifiable telemetry or system state check 1]   
- [ ] [Verifiable telemetry or system state check 2]   
- [ ] Verified via fresh `system-reports/` capture with zero regressions.   
```
