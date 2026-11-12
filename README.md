<a href="https://github.com/benweston/system-health-checks">
    <img
        src="/assets/banners/main-banner.png"
        alt="Ben Weston - Enterprise Linux · Systems & DevEx · Cloud Architecture"
        width="1100"
        height="217"
        loading="lazy"
    />
</a>

# System Health Checks

<div align="justify">

> Automated bare-metal diagnostic collection and longitudinal forensic analysis for enterprise Linux mobile workstations.   

</div>

<div align="justify">

`system-health-checks` executes privileged, read-only shell scripts in `system-checks/` to capture kernel, firmware, security, PCIe, and redundant NVMe RAID1 telemetry into `system-reports/`. Raw captures are then audited against structured engineering playbooks in `GEMINI.md` and persisted as immutable, timestamped evaluations in `forensic-reports/`.   

</div>

## Target Architecture & Operational Baseline

<div align="justify">

- **Hardware Platform:** Lenovo ThinkPad mobile workstation (P16 series) with hybrid graphics (Intel iGPU + discrete NVIDIA RTX Laptop GPU), discrete TPM 2.0, and Thunderbolt / USB4 controllers.   
- **Operating System & Boot Chain:** Fedora Linux Workstation with UEFI Secure Boot (MOK enforced) and `GRUB2` / `shim` (`systemd-boot` fallback supported).   
- **Storage Topology:** Dual physical NVMe SSDs configured with Linux `mdadm` Software RAID1 (`md0` backing `/boot` on `ext4`; `md127` backing a `LUKS2` container formatted with `Btrfs` for `/`), paired with `zram` swap.   
- **Power & Session Policy:** Continuous AC operation with Embedded Controller (EC) battery charge thresholds capped at `75%–80%`, `HandleLidSwitch=lock` (`S0` session persistence with the lid closed), and the `performance` (`throughput-performance`) ACPI/`TuneD` profile.   

</div>

## Repository Structure

```text
system-health-checks/
├── assets/                       # Repository visual & design assets
│   ├── banners/                  # Repository & profile banners
│   │   ├── README.md             # Banners directory documentation
│   │   └── main-banner.png       # Primary repository header banner
│   ├── diagrams/                 # Architecture & UML/ERD diagrams
│   │   └── README.md             # Diagrams directory documentation
│   ├── icons/                    # Logos, badges & iconography
│   │   └── README.md             # Icons directory documentation
│   ├── misc/                     # Miscellaneous static images
│   │   └── README.md             # Misc assets directory documentation
│   ├── screenshots/              # UI & CLI diagnostic screenshots
│   │   └── README.md             # Screenshots directory documentation
│   └── README.md                 # Assets directory documentation
├── forensic-reports/             # Local Markdown forensic reports (ignored)
│   ├── README.md                 # Forensic reports directory documentation
│   └── YYYY-MM-DD-HHMM-forensic-report.md
├── system-checks/                # Privileged diagnostic shell scripts (.sh)
│   ├── 01_01_system_check.sh     # System, kernel, suspend & logind checks
│   ├── 02_01_firmware_check.sh   # BIOS, EC, Secure Boot, TPM2 & LVFS checks
│   ├── 03_01_nvme_raid_check.sh  # NVMe SMART, PCIe, mdadm RAID1 & Btrfs
│   └── README.md                 # Diagnostic scripts directory documentation
├── system-reports/               # Raw diagnostic text dumps (git-ignored)
│   ├── 01_01_system_report.txt
│   ├── 02_01_firmware_report.txt
│   ├── 03_01_nvme_raid_report.txt
│   └── README.md                 # System reports directory documentation
├── .gitignore                    # Excludes reports, workspace & secrets
├── AGENTS.md                     # Symlink to GEMINI.md for compatibility
├── GEMINI.md                     # Canonical agent instructions & playbooks
├── LICENSE                       # MIT License terms & copyright notice
├── README.md                     # Project overview & operator documentation
└── run_checks.sh                 # Root master runner for all check scripts
```

## Prerequisites

<div align="justify">

Diagnostic scripts target `#!/bin/bash` on Fedora Linux Workstation and require `root` privileges (`sudo`) to read SMBIOS/DMI tables, kernel ring buffers, NVMe controller logs, SMART attributes, `mdadm` superblocks, and TPM 2.0 PCR banks.   

</div>

<div align="justify">

Each script degrades gracefully if optional utilities are absent, recording an inline diagnostic note rather than aborting execution. Full telemetry coverage uses the following packages:   

</div>

<div align="justify">

| Subsystem | CLI Utilities |
| :----- | :----- |
| Core & Kernel | `journalctl`, `dmesg`, `systemctl`, `coredumpctl` |
| Platform & UEFI/TPM2 | `dmidecode`, `mokutil`, `tpm2_pcrread`, `bootctl` |
| Firmware & Buses | `fwupdmgr`, `boltctl`, `lspci`, `nvidia-smi` |
| Storage & NVMe RAID1 | `lsblk`, `mdadm`, `btrfs`, `nvme`, `smartctl` |

</div>

<div align="justify">

On Fedora Workstation, ensure optional hardware inspection tools are present via:   

</div>

```bash
sudo dnf install dmidecode mokutil tpm2-tools fwupd bolt pciutils \
    mdadm btrfs-progs nvme-cli smartmontools
```

## Usage

### Run All Diagnostic Checks

<div align="justify">

Execute the master runner from the repository root to discover and run all numbered scripts (`[0-9][0-9]_[0-9][0-9]_*.sh`) in deterministic lexical order:   

</div>

```bash
sudo ./run_checks.sh
```

### Run Individual Domain Checks

<div align="justify">

Execute individual scripts when isolating a specific subsystem:   

</div>

```bash
sudo ./system-checks/01_01_system_check.sh
sudo ./system-checks/02_01_firmware_check.sh
sudo ./system-checks/03_01_nvme_raid_check.sh
```

<div align="justify">

| Script (`system-checks/`) | Output (`system-reports/`) | Scope |
| :----- | :----- | :----- |
| `01_01_system_check.sh` | `01_01_system_report.txt` | Kernel/Session |
| `02_01_firmware_check.sh` | `02_01_firmware_report.txt` | Firmware/TPM2 |
| `03_01_nvme_raid_check.sh` | `03_01_nvme_raid_report.txt` | NVMe/RAID1/PCIe |

</div>

<div align="justify">

When invoked via `sudo`, both `run_checks.sh` and each individual check script automatically restore `$SUDO_USER` ownership on `system-reports/` and generated report artefacts.   

</div>

## Forensic Audit Workflow

<div align="justify">

Full analytical playbooks, scoring rubrics, and agent guardrails are defined in `GEMINI.md` (exposed via `AGENTS.md` for multi-agent tooling).   

</div>

<div align="justify">

1. **System, Kernel & Session Forensics (`01_01`):** Reconstructs boot, lid, and suspend/wake timelines; distinguishes kernel/PCIe deadlocks from `systemd-logind` or Wayland rendering delays; and audits Machine Check Exceptions (MCEs), failed `systemd` units, and 30-day coredumps.   
2. **Firmware, UEFI/BIOS & Security (`02_01`):** Verifies SMBIOS/DMI integrity and BIOS/EC release synchronisation; audits Secure Boot, MOK, and SHA-256 TPM 2.0 PCR banks (`4, 8, 9`); and inspects CPU microcode, dGPU VBIOS, `thinkpad_acpi` profiles, USB4/IOMMU domains, and LVFS update queues.   
3. **NVMe RAID1 & Storage Forensics (`03_01`):** Audits `mdadm` RAID1 health (`[UU]`, intent bitmaps, superblocks), `LUKS2`/`Btrfs` mappings, per-drive NVMe SMART/error logs, and PCIe `LnkCap` vs `LnkSta` lane and transfer-speed negotiation.   
4. **Longitudinal Delta Tracking:** Compares each capture against the preceding `YYYY-MM-DD-HHMM-forensic-report.md` snapshot in `forensic-reports/`, keying physical NVMe monotonic counters strictly by PCIe BDF slot address (`nvme list-subsys`) rather than volatile `/dev/nvmeX` names.   
5. **Executive Triage:** Concludes every audit with a transparent **System Health Score (`1–10`)** across all three domains and an unambiguous **Immediate Critical Issues Gate (`Yes / No`)**.   

</div>

## Safety, Privacy & Coding Standards

<div align="justify">

- **Read-Only Telemetry Collection:** All scripts in `system-checks/` are strictly observational and perform zero state-mutating operations on firmware, bootloaders, storage arrays, or system packages.   
- **Telemetry Isolation & Redaction:** Host-specific outputs in `system-reports/` and `forensic-reports/` are excluded via `.gitignore`.  Never commit raw hardware serial numbers, filesystem/LUKS UUIDs, MAC addresses, or personal identifiers to versioned files or issues.   
- **Shell Quality Gates:** Validate all shell script modifications cleanly before staging:   

</div>

```bash
bash -n run_checks.sh system-checks/*.sh
shellcheck -S warning run_checks.sh system-checks/*.sh
```

<div align="justify">

- **Documentation Standards:** Standardise on British English (`en-GB`) and enforce a strict `<= 80` character line width with 3 trailing spaces on all non-heading, non-table, and non-code-block text lines across forensic reports, agent instructions, and issue/release bodies (`README.md` files are exempt from hard 80-column line breaks where `<div align="justify">` blocks require unwrapped single-line paragraphs and list items).   

</div>

## Licence

<div align="justify">

The `system-health-checks` source code and documentation are open source and provided under the [MIT License](https://github.com/benweston/system-health-checks/blob/main/LICENSE), excluding binary media in `assets/` and third-party photography noted below, which remain subject to their respective copyright and licence terms.   
Banner image taken from a photo by [Vishnu Mohanan](https://unsplash.com/@vishnumaiea) on [Unsplash](https://unsplash.com/photos/close-up-of-dark-blue-circuit-board-pfR18JNEMv8) and is licensed separately under the [Unsplash License](https://unsplash.com/license).   

</div>
