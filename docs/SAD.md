# Software Architecture Document (SAD)
## Trusted Environment Bootstrap (RISC‑V)

**Version:** 0.1  
**Date:** 2025-10-19  
**Authors:** Daniil Smoli

---

## 0. Authors
- Daniil Smolin (DEMest) — docs, kernel implementation, project managment.
- Yuri Pivkin (alwenwhy) - kernel implementation, general decisions.
- Viktor Tumilevich (ViktorTum) - development on LicheePie 4A.
- Maxim Tokarev (Rakdat) - docs, development. 

---

## 1. Goals and limitations

### 1.1 Key functional requirements (architecturally significant)
- Build the bootstrap pipeline up to stage1/stage2 via CLI: `make all`, `make clean`.
- Run on QEMU virt: `make qemu`, UART0 output must confirm successful boot (e.g., “Stage1 OK”, “ENTER MAIN”).
- Verify reproducibility of artifacts: SHA256 hashing and comparison of results from independent rebuilds (double compilation / “divorce bootstrap”).
- Keep hardware execution on Lichee Pi 4A as an explicit target (roadmap), influencing platform separation in build/deploy.

### 1.2 Non-functional requirements
- Reproducibility: deterministic build, SHA256 verification.
- Portability (host): Linux x86_64 / WSL2.
- Portability (target): RISC‑V rv64.
- Performance: fast boot/run in QEMU (minimal overhead).
- Security/Trust: transparent trust chain, minimum opaque dependencies, logs/hashes for audit.

### 1.3 Architectural goals
- Separate the pipeline into stages (stage0/stage1/stage2) with clear inputs/outputs.
- Fix entry point and document memory map.
- Provide one consistent flow: **build → image → run → verify** driven from Make/CLI.

### 1.4 Additional goals, restrictions and preferences
- Prefer Make + C/ASM, minimal dependencies.
- Primary debugging platform: QEMU; real hardware testing later per schedule/roadmap.

---

## 2. Goals analysis

### 2.1. Security

The project is a trusted bootstrap pipeline for RISC‑V; therefore, “security” here is primarily about **artifact integrity**, **reproducibility**, and **build environment control**, rather than multi-user sessions.

#### Assets to protect
- Source code (stage1/stage2, linker scripts, Makefile).
- Build artifacts (`stage*.elf`, `stage*.bin`), memory map documents, build logs.
- The trust chain: which exact inputs/tools produced a given binary artifact.

#### Roles (project-level)
- **Developer:** builds and runs artifacts, changes sources.
// (todo) - **CI system:** performs automated build + verify on commits (optional but recommended).
- **Release maintainer:** approves updates of “known-good” hashes or tagged releases.

### 2.x Multi-platform
- One unified configuration for all targets.
- Platform variable + platform-specific configs.

---

## 3. Solution description

### 3.1 Modules and subsystems
- **Build**: Makefile + `riscv64-unknown-elf-gcc/ld` produce `stage*.elf`.
- **Image**: ELF → BIN conversion, fixed entry point (0x08048000), memory map extraction/documentation.
- **Run**: `make qemu` runs QEMU virt and exposes UART0 logs; hardware run path prepared via platform selection.
- **Verify**: SHA256 hashing, compare artifacts across rebuilds (reproducibility check).

Minimal flow:
`Sources → stage1.elf → stage1.bin → QEMU UART0 → SHA256/compare`

### 3.2 Deployment
- **Emulator target**: QEMU virt, UART0 115200 8N1 (console in terminal).
- **Hardware target**: Lichee Pi 4A (planned/roadmap; affects PLATFORM split).

---

## 4. Key architectural elements
- **Memory map + entry point**: fixed entry; memory layout documented.
- **Hash verification**: SHA256 for artifacts; “verify” scenario supports determinism checks.
- **Build configuration**: environment variables such as `RISCVPREFIX` and `PLATFORM` to keep builds reproducible across machines.

---

## 5. Platform
- **Target ISA**: RISC‑V rv64.
- **Toolchain**: `riscv64-unknown-elf-gcc` (+ binutils).
- **Emulator**: `qemu-system-riscv64` (virt machine).
- **Host OS**: Linux x86_64 / WSL2.

---
