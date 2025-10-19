# SRS: Trusted Environment Bootstrap (RISC-V) — bootstrap
**Version:** 0.1  
**Date:** 2025-10-19  
**Author:** Daniil Smolin  

---

## 1. Introduction

### 1.1 Purpose of the Document
This document describes the requirements for the “bootstrap” system — a set of tools and artifacts for a reproducible and highly trusted initial bootstrapping process under the RISC-V architecture, including early-stage builds, image generation, and execution in QEMU/on hardware.

### 1.2 Scope
The SRS covers functional and non-functional requirements for:
- The builder pipeline (as of version 0.1 — stage1; stage2 planned later);
- Image generation (ELF → BIN, firmware, memory map);
- Execution environments (QEMU virt, Lichee Pi 4A, etc.);
- Verification (tests, hashes, reproducibility);
- Documentation and UX (CLI, logs, build artifacts).

### 1.3 Definitions and Abbreviations
- **Bootstrap** — the process of building a minimal trusted foundation of tools/software “from nothing/minimum.”
- **Stage-N** — a numbered stage in the build chain (stage1 builds stage2, etc.).
- **TE (Trusted Environment)** — a trusted execution/build environment.
- **QEMU** — an architecture emulator used for testing.
- **ELF** — Executable and Linkable Format.
- **HEX0/...** — minimalist formats/tools for early stages.

---

## 2. Stakeholders
- **Student developers:** implement and maintain the pipeline, reproduce results, and improve it.  
- **Supervisors/Instructors:** validate requirements and perform acceptance checks.

---

## 3. System Description

### 3.1 Context
The system builds a trusted chain of tools and artifacts, allowing to:
1) Build early stages with minimal means;  
2) Build higher-level toolsets;  
3) Build a target image and run it (QEMU/hardware).

### 3.2 Constraints and Assumptions
- Target: **RISC-V 64-bit (rv64)**.
- Only an agreed set of external tools may be used in early stages (e.g., **`riscv64-unknown-elf-gcc vZ`**).
- **Build reproducibility is mandatory** (fixed versions and hashes).

---

## 4. Use Cases

### UC-01: Fast Local Build and Run in QEMU

**Actor:** Developer  
**Goal:** Obtain an image and ensure early stages are properly initialized.

**Preconditions:**  
- Dependencies are installed (make, RISC-V compiler, QEMU)
- Project sources are available locally

**Main Flow:**
1. Run `make qemu` in the project root directory.
2. The system sequentially builds all stages (stage1 → stage2), links and produces ELF/BIN artifacts.
3. QEMU is automatically started in 'virt' machine mode with UART console; boot messages appear in the terminal.
4. The console displays signal/status lines of initial system startup (e.g., Stage1 OK, ENTER MAIN) for quick verification.
5. The process completes without errors, and the developer can confirm that minimal boot has succeeded.

**Acceptance Criteria:**  
- The command completes without errors  
- QEMU starts successfully  
- A message confirming successful boot appears

---

### UC-02: Build Reproducibility Check

**Actor:** Instructor/CI  
**Goal:** Two consecutive builds produce identical artifact hashes

**Main Flow:**
1. Run `make clean`, then `make all`, and save SHA256 checksums of all key artifacts.
2. Run `make clean` again, repeat `make all`, and save SHA256 checksums.
3. Compare and ensure that hashes match for every artifact.
4. Record the result: "reproducible" if there are no differences; otherwise, "not reproducible" with a list of differing files.

**Acceptance Criteria:**  
- SHA256 hashes of all key artifacts are identical between two independent builds

---

## 5. Functional Requirements (FR)

**Numbering rules:**  
`BLD-REQ-###` — build/pipeline;  
`IMG-REQ-###` — images/formats;  
`RUN-REQ-###` — execution/platforms;  
`VER-REQ-###` — verification/tests;  
`DOC-REQ-###` — documentation/UX.

### 5.1 Build/Pipeline
- **BLD-REQ-001:** The system must provide a `make all` target that performs the full cycle: stage1 → stage2 → toolchain subset → image.

### 5.2 Images and Formats
- **IMG-REQ-001:** The system must be able to convert ELF to BIN with a fixed entry point at `0x08048000`.
- **IMG-REQ-002:** The memory map (segments, addresses, alignment) must be documented.

### 5.3 Execution
- **RUN-REQ-001:** The `make qemu` command must run the image using `qemu-system-riscv64 -machine virt -bios` with UART0 console.
- **RUN-REQ-002:** (Optional) Payload generation for Lichee Pi 4A must be supported.

### 5.4 Documentation and UX
- **DOC-REQ-001:** The README must provide a “5-minute quick start”: dependencies, `make all`, `make qemu`.
- **DOC-REQ-002:** Each stage must have a brief page describing: purpose, inputs/outputs, and readiness criteria.

---

## 6. Non-Functional Requirements (NFR)

### 6.1 Performance
- **NFR-PERF-001:** Full build for QEMU must take no more than 1 minute on a machine with 4 CPU cores and 8 GB RAM.

### 6.2 Reliability/Reproducibility
- **NFR-REP-001:** Two consecutive builds in a clean environment must produce identical SHA256 hashes for key artifacts.
- **NFR-LOG-001:** All build errors must include a code and a reference to the stage.

### 6.3 Portability
- **NFR-PORT-001:** Linux x86_64 and WSL2 must be supported.

### 6.4 Security/Trust
- **NFR-SEC-001:** The list of external binary dependencies must be minimal and version/hash-locked.

---

## 7. Interfaces

### 7.1 CLI
- `make all | clean | qemu | verify | hashes`  
- Environment variables: `CROSS_COMPILE`, `RISCV_PREFIX`, `PLATFORM=qemu|lpi4a`, etc.

### 7.2 File Formats
- ELF (input), BIN (output), MAP (memory map), LOG (logs).  
- Mapping table: segment → address → size (see Appendix A).

### 7.3 Hardware/Emulator
- QEMU virt: UART0 @115200 8N1; memory — 128 MB.

---

## 8. Acceptance Criteria

- All FR/NFR are satisfied; UC-01 and UC-02 are passed.  
- README is validated on a “clean” machine (acting as reviewer).  
- Artifact hashes are stable across two independent hosts.

---

## 9. Risks and Assumptions
- Risk: differences in QEMU/linker versions may cause hash mismatches.  
- Mitigation: version lock files/containerization.  
- Assumption: a minimal cross-compiler is available (assumes `riscv64-unknown-elf-gcc`). Stage0 is not implemented within this project.

---

## 10. Release Plan and Readiness Metrics
- **M1:** Basic builder + `make qemu`.  
- **M2:** Documented memory map + hash verification.  
- **M3:** Launch on Lichee Pi 4A hardware after QEMU stabilization.  
- **Metrics:** % of FR covered, hash stability, build time.

---

## Appendix A. Memory Map (based on the target project architecture)

| Address Range                | Purpose                                           | Approx. Size     | Notes |
|-----------------------------|--------------------------------------------------|------------------|--------|
| `0x54000000 - 0xBBFFFFFF`   | Files (files)                                    | ~1744 MB         | File system contents |
| `0x30000000 - 0x53FFFFFF`   | Saved processes                                  | ~604 MB          | Memory of terminated processes |
| `0x08048000 - 0x2FFFFFFF`   | Current running process                          | ~670 MB          | Code/data of the executing process; entry point `.text` = `0x08048000` |
| `0x01080000 - 0x08000000`   | 32-bit stack                                     | ~117 MB          | Used by early process |
| `0x01000010 - 0x0107FFFF`   | File descriptor table (16 bytes × 32K)          | ~512 KB          | `{ unused, address, length, unused }` |
| `0x01000000 - 0x0100000F`   | stdin descriptor (disk locator)                 | 16 bytes         | `{ sector (4B), offset (2B), unused }` |
| `0x201800 - 0xFFFFFF`       | File names (file names 6..14335)                | Up to ~16K names | Global file descriptors |
| `0x201400 - 0x2017FF`       | File name for descriptor #5                     | 1 name           | |
| `0x201000 - 0x2013FF`       | File name for descriptor #4                     | 1 name           | |
| `0x200C00 - 0x200FFF`       | File name for descriptor #3 (`"/e820"`)         | 1 name           | Contains part of BIOS information |
| `0x100000 - 0x200BF0`       | Unused                                           | -                | Reserved |
| `0x080000 - 0x0FFFFF`       | BIOS                                             | ~512 KB          | BIOS code |
| `0x050000 - 0x07FFFF`       | Scratch buffer                                   | ~192 KB          | Stores absolute file path after resolution |
| `0x040000 - 0x04FFFF`       | stdin device buffer                              | ~64 KB           | |
| `0x020000 - 0x03FFFF`       | Process descriptors (16 * 4096 bytes each)       | ~128 KB          | Structures: process address, brk, stack, file descriptors, etc. |
| `0x010800 - 0x01FFFF`       | BIOS memory map                                  | ~56 KB           | |
| `0x010000 - 0x0107FF`       | Interrupt vector table                           | 2 KB             | |
| `0x008E00 - 0x00FFFF`       | Unused                                           | -                | |
| `0x007C00 - 0x008DFF`       | Code (bootloader/code)                           | ~5 KB            | Initial bootloader code |
| `0x007B00 - 0x007BFF`       | Saved 32-bit registers (in 16-bit mode)          | 256 bytes        | |
| `< 0x007B00`                | Real mode stack                                  | -                | Used before switching to protected mode |

## Appendix B. Log Signatures
- Stage1 OK\n
- ENTER MAIN\n

---

### SRS Maintenance Guidelines
- All requirements must be **atomic**, **verifiable**, and have an **ID** with acceptance criteria.
- Changes must be introduced via PR with reference to a corresponding test or verification script.