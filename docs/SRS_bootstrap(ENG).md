# SRS: Trusted Environment Bootstrap (RISC-V)
**Version:** 0.2
**Date:** 2026-05-22
**Author:** Daniil Smolin (team: Yuri Pivkin, Viktor Tumilevich, Maxim Tokarev)

---

## 1. Introduction

### 1.1 Purpose of the Document

This document captures the requirements for the **bootstrap** project — a reproducible, hand-auditable boot and trust chain for RISC-V (rv64gc), running on QEMU `virt` and LicheePi 4A. The chain follows the [live-bootstrap `parts.rst`](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst) roadmap (`hex0 → hex1 → hex2 → M0 → …`) and the project is presently working on **bringing up M0** on top of hex2.

### 1.2 Scope

The SRS covers functional and non-functional requirements for:

- The boot chain: stage 1 (`boot`), stage 2 (`simon`), stage 3 (FS payloads `*.hex0`, `*.hex1`, `*.hex2`, `*.M0`).
- The shell (`sish`) embedded in `simon` and the in-kernel hex compilers.
- Image generation (concatenation of `boot.bin + simon.hex0 + FS files`).
- Run targets: QEMU `virt`, LicheePi 4A.
- Verification: `pytest + pexpect` integration tests against QEMU.
- Documentation and UX (`make` CLI, UART logs, FS layout).

### 1.3 Definitions and Abbreviations

- **Bootstrap** — building a minimal trusted toolchain "from nothing", each stage built only with the tools of previous stages.
- **hex0 / hex1 / hex2** — auditable hex/macro languages from `live-bootstrap`. `hex0` accepts raw hex pairs and comments. `hex1` adds labels. `hex2` adds simple expressions and directives.
- **M0** — minimal macro assembler that consumes hex2 output and is the first stage to introduce instruction mnemonics.
- **boot** — stage 1, the hex0 decoder; jumps to stage 2 after decoding.
- **simon** — stage 2, the kernel: UART, FS, shell (`sish`), hex compilers, `do` execution.
- **sish** — the shell loop inside `simon`.
- **FS file** — a payload packaged in the image, beginning with `src <name>` and terminated by `\0`.
- **Builder** — a directory (`builder-mvp`, `builder-hex1`, `builder-hex2`, `builder-lichee`, `builder-syscall`) packaging a particular snapshot of the chain.

---

## 2. Stakeholders

- **Student developers** — implement, document, and audit the chain.
- **Supervisors / instructors** — validate requirements, perform acceptance against milestones.
- **External readers** — reproduce the build from sources and audit each stage by hand.

---

## 3. System Description

### 3.1 Context

The system produces a single flat image that is loaded by QEMU (`-bios`) or burned onto LicheePi 4A. Stage 1 decodes stage 2 from hex0, stage 2 brings up an interactive shell capable of compiling and executing further stages of the live-bootstrap chain.

### 3.2 Constraints and Assumptions

- **Target ISA:** RISC-V rv64gc, ABI `lp64d`.
- **Trusted root:** the only opaque binary in the trust chain is the cross-compiler used once to assemble `boot.bin` and `simon.bin`. All later artefacts are produced by the chain itself.
- **Source language:** RISC-V assembly (`.S`), processed by `gcc -ffreestanding -nostdlib`.
- **No libc**, no dynamic linking, no standard runtime.
- **Reproducibility:** identical sources + identical toolchain version ⇒ identical `image_qemu.bin`.

---

## 4. Use Cases

### UC-01 — Build and run the MVP image in QEMU

**Actor:** developer
**Goal:** obtain `image_qemu.bin` and confirm boot through UART.

**Preconditions:** `riscv64-unknown-elf-gcc`, `qemu-system-riscv64`, `xxd`, `make` available; on Windows — WSL2.

**Main flow:**
1. From `builder-mvp/`, run `make build-and-run` (or `wsl make build-and-run`).
2. The Makefile produces `boot.bin`, `simon.bin`, `simon.hex0`, then concatenates `boot.bin + simon.hex0 + payload.hex0` into `image_qemu.bin`.
3. QEMU starts with `-M virt -bios image_qemu.bin -nographic`.
4. UART shows the stage 1 greeting (`[BOOTED]: Stage 1 (boot) …`) and the stage 2 transition (`[BUILDED]: Jump to stage 2.`).
5. The `sish` prompt appears; `ls` lists `payload.hex0`.
6. Running `do payload` outputs `Hello, World!`.

**Acceptance:** stage 1, stage 2, and `Hello, World!` from the payload all reach UART without errors.

---

### UC-02 — Compile a hex1 file inside the running kernel

**Actor:** developer
**Goal:** verify that the chain is self-extending from inside `simon`.

**Builder:** `builder-hex1`.

**Main flow:**
1. Run the image in QEMU.
2. At the `sish` prompt: `ls` shows the bundled `*.hex1` payload.
3. Run `hex1 <name>` — `simon` compiles it into a new FS entry.
4. Run `do <name>` — the compiled payload executes.

**Acceptance:** the freshly compiled entry appears in `ls`, executes, and produces the expected UART output.

---

### UC-03 — Bring up M0 on top of hex2 (active milestone)

**Actor:** developer
**Goal:** demonstrate that an M0 source, compiled by an in-kernel hex2 pipeline, runs on QEMU.

**Builder:** `builder-hex2`.

**Main flow:**
1. From `builder-hex2/`, run `make build-and-run`.
2. At the `sish` prompt, locate the bundled `M0.hex2` (the M0 assembler itself, written in hex2) plus a small `*.M0` test source.
3. Compile `M0.hex2` via `hex2`, then use the resulting binary to assemble the `*.M0` source, then `do` it.
4. UART shows the expected output of the test program.

**Acceptance:** the M0-produced binary runs to completion in QEMU; the same flow reproduces from a clean checkout.

---

### UC-04 — Run the integration test suite

**Actor:** developer / CI
**Goal:** automatically check shell commands and compiler outputs.

**Main flow:**
1. From `builder-hex1/` (or `builder-hex2/` once tests are filled in): `wsl make test`.
2. The Makefile installs Python deps and runs `pytest`.
3. `tests/qemu_wrapper.py` starts QEMU under `pexpect`; `tests/test_commands.py` drives `sish` and asserts responses.

**Acceptance:** all tests pass; QEMU is cleanly terminated.

---

### UC-05 — Run on LicheePi 4A hardware

**Actor:** developer (Viktor)
**Goal:** the same chain boots on real RISC-V silicon.

**Builder:** `builder-lichee`.

**Main flow:**
1. Build the image with the LicheePi SRAM base (`0xFFE0000000`).
2. Flash / load the image on the board.
3. Observe stage 1 greeting and stage 2 prompt on the board's UART.

**Acceptance:** UART transcript on hardware matches the QEMU transcript up to the boot banner.

---

## 5. Functional Requirements (FR)

**Numbering rules:**
`BLD-REQ-###` — build/pipeline; `IMG-REQ-###` — image/formats; `RUN-REQ-###` — execution/platforms; `KER-REQ-###` — kernel (`simon`); `VER-REQ-###` — verification/tests; `DOC-REQ-###` — documentation/UX.

### 5.1 Build / Pipeline

- **BLD-REQ-001:** Each builder must expose `make`, `make run`, `make build-and-run`, `make clean` targets.
- **BLD-REQ-002:** The default `make` target must rebuild `boot.bin`, `simon.bin`, `simon.hex0` from sources and concatenate `boot.bin + simon.hex0 + $(FS_FILES)` into `$(OUTPUT_IMAGE)`.
- **BLD-REQ-003:** `FS_FILES` and `OUTPUT_IMAGE` must be overridable on the `make` command line.
- **BLD-REQ-004:** Compile flags must remain `-march=rv64gc -mabi=lp64d -nostdlib -ffreestanding -Ttext=0x80000000`.

### 5.2 Image and Formats

- **IMG-REQ-001:** Each FS file must start with the marker line `src <filename>` and end with a single `\0` byte.
- **IMG-REQ-002:** hex0 must accept ASCII hex pairs and treat `#` and `;` as line comments, ignoring all other non-hex characters.
- **IMG-REQ-003:** The image must be a flat binary, loadable by QEMU `-bios` without any wrapper.
- **IMG-REQ-004:** The memory map of `simon` must remain stable and documented (see Appendix A).

### 5.3 Kernel (`simon` / `sish`)

- **KER-REQ-001:** `simon` must initialize UART0 at `0x10000000` and print a startup banner.
- **KER-REQ-002:** `simon` must walk the concatenated FS data and register each entry in the file descriptor table at `0x80100000`.
- **KER-REQ-003:** `sish` must implement at least: `ls`, `echo`, `do`, `hex0`, `shutdown`, `reboot`, `debug`.
- **KER-REQ-004 (builder-hex1):** `sish` must additionally implement `hex1`.
- **KER-REQ-005 (builder-hex2):** `sish` must additionally implement `hex2` and a route (`m0` or shared dispatcher) to compile and run `*.M0` files.
- **KER-REQ-006:** `do <file>` must transfer control to the file's load address inside the file data area (`0x80100400`+).
- **KER-REQ-007:** Input must support canonical-line editing including Backspace.

### 5.4 Execution

- **RUN-REQ-001:** `make run` must invoke `qemu-system-riscv64 -M virt -bios $(OUTPUT_IMAGE) -nographic`.
- **RUN-REQ-002:** The image must boot identically when the LicheePi 4A SRAM base is selected (`builder-lichee`).
- **RUN-REQ-003:** UART must run at 115200 8N1 in both targets.

### 5.5 Verification

- **VER-REQ-001:** Each builder that ships tests must provide a `make test` target wiring `pytest` against a QEMU instance.
- **VER-REQ-002:** Tests must drive `sish` through `pexpect` and assert exact UART substrings for each command under test.
- **VER-REQ-003:** A "smoke" test must boot the image and assert the stage 1 and stage 2 banners reach UART.

### 5.6 Documentation and UX

- **DOC-REQ-001:** Each builder must ship a `README.md` covering dependencies, build, run, and the WSL note for Windows hosts.
- **DOC-REQ-002:** The repository must keep a current `SAD.md`, `SRS_bootstrap(*)`, and `Vision(*)` in `docs/`.
- **DOC-REQ-003:** Each builder must keep an up-to-date `parts.rst` describing the stages it owns, cross-referenced with live-bootstrap.

---

## 6. Non-Functional Requirements (NFR)

### 6.1 Performance

- **NFR-PERF-001:** A clean build (`make clean && make`) of `builder-mvp` must complete in under 30 s on a 4-core/8 GB host.
- **NFR-PERF-002:** Boot to `sish` prompt in QEMU must take under 5 s.

### 6.2 Reproducibility

- **NFR-REP-001:** Two `make clean && make` runs in the same checkout, with the same toolchain version, must produce byte-identical `image_qemu.bin`.
- **NFR-REP-002:** Toolchain versions (compiler, binutils, QEMU) must be documented in the top-level `README.md` or per-builder `README.md`.

### 6.3 Portability

- **NFR-PORT-001:** All builders must build under Linux x86_64 and Windows + WSL2.
- **NFR-PORT-002:** `builder-lichee` must additionally build on a host with `riscv64-unknown-elf-gcc` only (no QEMU dependency for the build itself).

### 6.4 Trust

- **NFR-SEC-001:** No stage beyond the toolchain may introduce a new opaque binary into the trust chain. New stages must be expressible as sources of previous stages.
- **NFR-SEC-002:** `simon.hex0` must remain human-readable hex with comments; obfuscated encodings are not allowed.

---

## 7. Interfaces

### 7.1 CLI

```
make [all]            # build the image
make run              # boot the existing image in QEMU
make build-and-run    # build + boot
make clean            # remove build artefacts
make test             # run pytest+pexpect suite (where present)
```

Override variables: `CROSS_COMPILE`, `FS_FILES`, `OUTPUT_IMAGE`, `BOOT_SRC`, `SIMON_SRC`.

### 7.2 File Formats

- `.S` — RISC-V assembly source.
- `.bin` — flat binary, output of `objcopy -O binary`.
- `.hex0` / `.hex1` / `.hex2` / `.M0` — auditable FS payloads.
- `image_qemu.bin` — concatenated boot image.

### 7.3 Hardware / Emulator

- QEMU `virt`: UART0 at `0x10000000`, 115200 8N1, console on stdio.
- LicheePi 4A: SRAM base `0xFFE0000000`, UART base differs per board (`builder-lichee`).

### 7.4 In-kernel Shell

Commands listed in §5.3 reach the user over UART0. The shell is line-based; Backspace edits the current line; Enter submits it.

---

## 8. Acceptance Criteria

- All FR/NFR are satisfied for the active builder.
- UC-01 passes on a clean checkout (QEMU).
- UC-02 passes on `builder-hex1`.
- UC-03 passes on `builder-hex2` for the current M0 milestone.
- UC-04 passes (where tests are present).
- UC-05 passes on the LicheePi 4A board (`builder-lichee`).
- `README.md` for each builder is validated by an outside reader against a clean machine.

---

## 9. Risks and Assumptions

| Risk | Mitigation |
|---|---|
| Toolchain version drift breaks reproducibility | Pin the toolchain in per-builder `README.md`; document the exact versions used during acceptance. |
| QEMU `virt` behaviour changes between QEMU releases | Pin a known-good QEMU version; cover with `make test`. |
| LicheePi UART base differs from in-tree assumption | Keep a `builder-lichee`-local `boot.S` variant. |
| M0 design is under-specified | Track M0 directly against live-bootstrap's M0 source; treat the upstream M0 as the spec. |
| Process model from `builder-syscall` diverges from `builder-mvp` | Reintegrate only after M0 is running; do not branch the kernel before that. |

**Assumption:** the cross-compiler (`riscv64-unknown-elf-gcc` or `riscv-none-elf-gcc` on Windows) is available on the host. The project does not implement stage 0.

---

## 10. Release Plan and Readiness Metrics

| Milestone | Content | Status |
|---|---|---|
| **M-MVP** | `builder-mvp`: stage 1 + stage 2 + hex0 payload + QEMU run | done |
| **M-Hex1** | `builder-hex1`: in-kernel hex1 compiler + pytest suite | done |
| **M-Lichee** | `builder-lichee`: same chain on LicheePi 4A | done (Hello-World level) |
| **M-Hex2** | `builder-hex2`: in-kernel hex2 compiler | in progress |
| **M-M0** | M0 (live-bootstrap) compiled by hex2 and running in QEMU | **active** |
| **M-Reintegrate** | Merge `builder-syscall` process model into the post-M0 kernel | planned |
| **M-Reproduce** | Bit-identical image across two independent hosts | planned |

Readiness metrics: % of FR covered, presence of integration tests for each new stage, stability of the UART transcript across rebuilds.

---

## Appendix A. Memory Map (QEMU `virt`, `SRAM_BASE = 0x80000000`)

Reflects `simon.S` as currently shipped in `builder-mvp` / `builder-hex1`.

| Address range | Purpose | Size | Notes |
|---|---|---|---|
| `0x80000000 – 0x8000FFFF` | `boot` (stage 1) + embedded `simon.hex0` source | 64 KB | Decoded in place by `boot.S` |
| `0x80010000 – 0x8004FFFF` | `simon` (stage 2) code/data | 256 KB | Jump target of stage 1 |
| `0x80050000 – 0x8006FFFF` | Process descriptors (max 16 × 4 KB) | 128 KB | PID, state, sp, registers, stack |
| `0x80070000 – 0x8007FFFF` | File-name table (max 64 × 1 KB) | 64 KB | Names of registered FS entries |
| `0x80080000 – 0x8008FFFF` | stdin device buffer | 64 KB | UART input buffer |
| `0x80090000 – 0x8009000F` | stdin disk locator | 16 B | `{ sector (4B), offset (2B) }` |
| `0x80100000 – 0x801003FF` | File descriptor table | 1 KB | `{ address, length }` per file |
| `0x80100400 – …` | File data and execution area | — | Where `do <file>` lands |

For LicheePi 4A the same layout is shifted to `SRAM_BASE = 0xFFE0000000`.

## Appendix B. UART Log Signatures

- `[BOOTED]: Stage 1 (boot) - coded by ylab-nsu.`
- `[BUILDED]: Jump to stage 2.`
- `sish>` (the shell prompt)
- `Hello, World!` (default payload)

---

### SRS Maintenance Guidelines

- All requirements must be **atomic**, **verifiable**, and carry an **ID** plus acceptance criteria.
- Changes are introduced via PR and must reference an integration test or, where infeasible, a manual UART transcript.
- The active milestone (currently **M-M0**) drives the priority of new requirements.
