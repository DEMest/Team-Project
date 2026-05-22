# Software Architecture Document (SAD)
## Trusted Environment Bootstrap (RISC-V)

**Version:** 0.2
**Date:** 2026-05-22
**Authors:** Daniil Smolin, Yuri Pivkin, Viktor Tumilevich, Maxim Tokarev

---

## 0. Authors and Roles

- **Daniil Smolin** (DEMest) — documentation, kernel implementation, project management.
- **Yuri Pivkin** (alwenwhy) — kernel implementation, hex0/hex1/hex2 design, general decisions.
- **Viktor Tumilevich** (ViktorTum) — LicheePi 4A hardware bring-up.
- **Maxim Tokarev** (Rakdat) — documentation, development.

---

## 1. Goals and Limitations

### 1.1 Reference Roadmap

The project follows the [live-bootstrap parts.rst](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst) roadmap, adapted for RISC-V rv64gc. The chain is:

```
hex0 → hex1 → hex2 → M0 → M1 → M2 → cc_riscv64 → …
```

Each next stage is built *only* with tools provided by previous stages. The current focus of the project is **bringing up M0** — a minimal macro assembler that consumes the hex2 output stream and is the first stage to introduce labels and named references.

### 1.2 Key Functional Requirements (architecturally significant)

- Provide a flat boot image consisting of: `boot` (stage 1) + `simon` (stage 2, encoded as hex0) + filesystem payload (hex0/hex1/hex2/M0 files).
- Run on `qemu-system-riscv64 -M virt -bios <image>` and confirm successful boot through UART0.
- Provide an in-image shell (`sish` inside `simon`) with file-system commands: `ls`, `echo`, `do`, `hex0`, `hex1`, `shutdown`, `reboot`, `debug`.
- Compile hex0 payloads (`builder-mvp`), then hex1 payloads (`builder-hex1`), then hex2 / M0 (`builder-hex2`, in progress).
- Keep LicheePi 4A as an explicit target (covered by `builder-lichee`).

### 1.3 Non-Functional Requirements

- **Auditability:** every stage must be readable by hand (hex0 → comments, hex1 → labels, hex2 → directives, M0 → mnemonics).
- **Minimal trusted base:** the only external binary in the trust chain is the cross-compiler (`riscv64-unknown-elf-gcc`), used solely to produce `boot.bin` and the hex0 form of `simon`. All later stages are produced by the chain itself.
- **Portability (host):** Linux x86_64 / WSL2 on Windows.
- **Portability (target):** QEMU `virt` (`0x80000000`) and LicheePi 4A (`0xFFE0000000`).
- **Reproducibility:** identical inputs and toolchain version must yield identical `image_qemu.bin`.

### 1.4 Architectural Goals

- Strict separation between **stages** (boot / simon / payload) and **builders** (mvp / hex1 / hex2 / lichee / syscall).
- Clear and fixed memory map for QEMU virt and LicheePi.
- Single CLI workflow: **build → image → run → (test)**, driven from `make`.

### 1.5 Constraints and Preferences

- Source language: RISC-V assembly (`.S`), processed by `gcc -ffreestanding -nostdlib`.
- No dynamic linking, no libc, no standard runtime.
- Tests via `pytest + pexpect` against a real QEMU instance.

---

## 2. Goals Analysis

### 2.1 Security and Trust

The threat model is **the trust chain**, not multi-user isolation:

- **Assets:** sources (`.S`), `boot.bin`, hex0 form of `simon`, intermediate hex1/hex2/M0 artefacts, the final image.
- **Trust assumption:** the cross-compiler is the only opaque binary; everything later in the chain must be expressible (and verifiable) in a previous-stage language.
- **Mitigations:** stage-by-stage rebuild from sources packaged in the image itself; the `do` command in `simon` allows executing freshly compiled payloads without leaving the trusted runtime.

### 2.2 Multi-Platform

A single source tree, but **multiple parallel builders** rather than a single configurable one:

| Builder | hex1 | Processes | LicheePi | pytest |
|---|---|---|---|---|
| `builder-mvp` | no | no | no | no |
| `builder-hex1` | yes | no | no | yes |
| `builder-hex2` | yes (planned: hex2, M0) | no | no | scaffolded |
| `builder-syscall` | no | yes | no | yes |
| `builder-lichee` | no | no | yes | no |

This is intentional: each builder is a snapshot of the trust chain at a particular stage and can be audited independently.

---

## 3. Solution Description

### 3.1 Three-Stage Boot Image

The binary image is a flat concatenation:

```
image_qemu.bin = boot.bin  +  simon.hex0  +  <FS files>
```

- **Stage 1 — `boot.S`** (~140 lines): Decodes the hex0-encoded stage 2 in place from its embedded source (`payload_src` label), then jumps to it. Inherited from [ws25-bootstrap](https://github.com/ylab-nsu/ws25-bootstrap), lightly modified.
- **Stage 2 — `simon.S`** (~500 lines in `builder-mvp`, ~1281 lines in `builder-hex1`): the kernel. Initializes UART, builds an in-memory file table from the concatenated FS files, provides the `sish` shell, and can compile/execute hex0 (and hex1 in `builder-hex1`).
- **Stage 3 — payload** (`.hex0` / `.hex1` / `.hex2` / `.M0`): test program embedded in the image as filesystem data. Each FS file starts with `src <filename>` and ends with a NUL byte.

### 3.2 Modules and Subsystems

- **Build:** `Makefile` per builder. Produces `boot.elf` → `boot.bin`, `simon.elf` → `simon.bin` → `simon.hex0`, then concatenates with FS payloads.
- **Image:** flat binary, loaded by QEMU `-bios` directly at the platform's reset vector.
- **Run:** `make run` → `qemu-system-riscv64 -M virt -bios image_qemu.bin -nographic`.
- **Verify:** `make test` runs pytest fixtures (`tests/qemu_wrapper.py`, `conftest.py`, `test_commands.py`) that drive QEMU with pexpect and assert shell behaviour and compiler output.

Minimal flow:

```
Sources (.S, .hex0)
   │
   ▼
boot.bin + simon.hex0 + FS
   │
   ▼
image_qemu.bin
   │
   ▼
QEMU virt UART0  ──►  sish shell  ──►  hex0/hex1/hex2/M0 compile + do
```

### 3.3 Deployment

- **Emulator target:** QEMU `virt`, UART0 @ `0x10000000`, 115200 8N1, console on stdio (`-nographic`).
- **Hardware target:** LicheePi 4A, UART base differs, reset vector at `0xFFE0000000` (`builder-lichee`).

---

## 4. Key Architectural Elements

### 4.1 Memory Map — QEMU virt (`SRAM_BASE = 0x80000000`)

The map below reflects what `simon.S` actually uses today (`builder-mvp` / `builder-hex1`):

| Address range | Purpose | Size | Notes |
|---|---|---|---|
| `0x80000000 – 0x8000FFFF` | `boot` (stage 1) and its embedded `simon.hex0` source | 64 KB | Decoded in place by `boot.S` |
| `0x80010000 – 0x8004FFFF` | `simon` (stage 2) code/data | 256 KB | Decoded target of stage 1 |
| `0x80050000 – 0x8006FFFF` | Process descriptors (max 16 × 4 KB) | 128 KB | PID, state, sp, regs, stack |
| `0x80070000 – 0x8007FFFF` | File-name table (max 64 × 1 KB) | 64 KB | Per-file names |
| `0x80080000 – 0x8008FFFF` | stdin device buffer | 64 KB | UART input buffer |
| `0x80090000 – 0x8009000F` | stdin disk locator | 16 B | `{ sector (4B), offset (2B) }` |
| `0x80100000 – 0x801003FF` | File descriptor table | 1 KB | `{ address, length }` per file |
| `0x80100400 – …` | File data and execution area | — | Where `do <file>` lands |

The process-descriptor area is reserved across builders; it is *populated* only in `builder-syscall`.

### 4.2 Memory Map — LicheePi 4A (`SRAM_BASE = 0xFFE0000000`)

Same logical layout, shifted to the on-chip SRAM base. Used by `builder-lichee`.

### 4.3 hex0 Encoding (boot input)

`boot.S` parses a permissive hex0 stream:

- ASCII hex digits (`0-9`, `a-f`, `A-F`) accumulate into a byte every two nibbles.
- `#` and `;` start a line comment, terminated by `\n`.
- All other characters are skipped.
- A NUL byte terminates the stream.

This is the property that lets `simon.hex0` ship as commented hex inside the image without losing auditability.

### 4.4 FS File Format

Each file packaged into the image starts with the marker line `src <filename>` and ends with a single NUL byte (`\0`). `simon` walks this stream at boot, registers each file in the descriptor table, and exposes it through `ls`, `do`, `hex0`, `hex1`.

### 4.5 Shell Commands (`sish` in `simon`)

| Command | Effect |
|---|---|
| `ls` | List files registered in the FS table |
| `echo <…>` | Echo text to UART |
| `hex0 <file>` | Compile a hex0 file into a new FS entry |
| `hex1 <file>` | (builder-hex1) Compile a hex1 file |
| `do <file>` | Execute a compiled file at its load address |
| `shutdown` | Issue QEMU shutdown signal at `0x100000` |
| `reboot` | Issue QEMU reboot signal at `0x100000` |
| `debug` | Force a kernel panic (for testing the panic path) |

---

## 5. Platform

- **Target ISA:** RISC-V `rv64gc`, ABI `lp64d`.
- **Toolchain:** `riscv64-unknown-elf-gcc` (Linux / WSL) or `riscv-none-elf-gcc` (Windows native), with `binutils` (`objcopy`).
- **Compile flags:** `-march=rv64gc -mabi=lp64d -nostdlib -ffreestanding -Ttext=0x80000000`.
- **Emulator:** `qemu-system-riscv64 -M virt`.
- **Host OS:** Linux x86_64 or Windows 10/11 with WSL2.

---

## 6. Current State (snapshot at v0.2)

| Component | Builder | Status |
|---|---|---|
| boot stage 1 (hex0 decoder) | mvp / hex1 / hex2 / lichee / syscall | done |
| simon stage 2 (shell, FS, hex0) | mvp | done |
| hex1 compiler in simon | hex1 | done |
| hex2 compiler in simon | hex2 | **in progress** |
| **M0 launch on top of hex2** | hex2 | **active milestone** |
| Process scheduling (`create_process`, `switch_context`) | syscall | done, isolated |
| LicheePi 4A boot | lichee | done up to "Hello, World!" |
| pytest+pexpect integration suite | hex1 / hex2 / syscall | partial (hex1 full, hex2 scaffold) |

---

## 7. Open Questions / Next Steps

- Define the on-image format for M0 source files (mnemonics, labels, directives accepted).
- Decide whether M0 is a *new* command in `sish` (`m0 <file>`) or layered on top of `hex2` via a single `compile` dispatcher.
- Reintegrate the `builder-syscall` process model into the post-M0 kernel without breaking the trust chain.
- Pin a toolchain version (compiler + binutils + QEMU) to make the image bit-for-bit reproducible across hosts.
