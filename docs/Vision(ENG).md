# Vision Document
## Trusted Environment Bootstrap (RISC-V) — bootstrap

**Version:** 0.2
**Date:** 2026-05-22
**Authors:** Daniil Smolin, Yuri Pivkin, Viktor Tumilevich, Maxim Tokarev

---

## 1. Purpose of the Document

This document captures the concept, goals, value, and scope of the **bootstrap** project — a trusted, step-by-step build environment for RISC-V (rv64gc) that follows the [live-bootstrap `parts.rst`](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst) roadmap and ships a tiny self-hosting kernel (`simon`) able to compile and execute each next stage from inside itself. It is the orientation document for the team, supervisors, and external reviewers.

---

## 2. Background and Motivation

Modern toolchains rely on layers of pre-existing binaries whose origin is rarely auditable. For a system aiming to be *trusted*, this is the weakest link: a binary you cannot read by hand cannot be reasoned about.

`live-bootstrap` proposes a ladder of progressively richer languages (`hex0 → hex1 → hex2 → M0 → M1 → M2 → cc_*`) where each stage is small enough to verify by eye and powerful enough to express the next one. This project applies that idea to RISC-V (rv64gc), and additionally embeds the ladder *inside a running kernel* so that "compile the next stage" is a shell command, not a build-system step.

The project is educational, research-oriented, and engineering-grade:

- understand boot, linking, and the trust chain by writing each layer ourselves;
- enforce reproducibility and minimal external dependencies;
- experiment with early boot on both QEMU `virt` and LicheePi 4A;
- track the live-bootstrap chain as our reference roadmap.

---

## 3. Overall Product Goal

The `bootstrap` project must deliver:

- A reproducible RISC-V boot image built from three stages: `boot` (hex0 decoder) → `simon` (kernel) → FS payloads (hex0/hex1/hex2/M0).
- A minimal kernel (`simon`) that hosts a shell (`sish`), an in-memory filesystem, and successive in-kernel compilers (`hex0`, `hex1`, `hex2`, then `M0`).
- A working chain up to and including **M0**, the first stage to introduce real assembly mnemonics, faithfully ported from live-bootstrap.
- Execution on QEMU `virt` (primary development target) and on LicheePi 4A (hardware validation).

Each milestone yields:

- a defined input environment,
- an auditable artefact in the next-stage language,
- a UART-observable acceptance criterion.

---

## 4. Stakeholders and Their Benefits

| Role / stakeholder | Interest / benefit |
|---|---|
| Student developers | Deep, hands-on understanding of boot, linking, and the trust chain. |
| Supervisors / instructors | A concrete artefact against which to assess system-level understanding and engineering thinking. |
| External reviewers | A repository they can rebuild from source, audit stage by stage, and reproduce. |
| `live-bootstrap` community (indirect) | A RISC-V port of the early chain, exercised on real silicon (LicheePi 4A) as well as in emulation. |

---

## 5. Problem Space and Needs

| Problem | How the project addresses it |
|---|---|
| Modern toolchains contain opaque binaries that cannot be audited. | Limit the trust root to a single use of the cross-compiler and grow every later stage *from* the chain. |
| Build systems hide the actual sequence of compilations. | Make the build sequence an explicit, user-visible shell session inside `simon`. |
| RISC-V boot is hard to learn from docs alone. | Each stage is small, self-contained, and visible at runtime over UART. |
| Hardware vs. emulator divergence. | Parallel builders (`builder-mvp`, `builder-lichee`, `builder-syscall`, …) snapshot the chain for each target. |

---

## 6. Project Objectives

- Maintain a trusted, three-stage boot chain on RISC-V (`boot` + `simon` + FS payloads).
- Keep `simon` capable of compiling each next live-bootstrap stage *from inside the running kernel*.
- Deliver hex0 (done), hex1 (done), hex2 (in progress), and **M0 (current milestone)**.
- Boot the same chain on LicheePi 4A.
- Cover every shipped builder with `pytest + pexpect` integration tests against QEMU.
- Document architecture (SAD), requirements (SRS), and roadmap (Vision, Project-Schedule) in `docs/`.
- Pin a toolchain version and demonstrate bit-identical image reproducibility across two hosts.

---

## 7. Key Features and Functionality

| Feature | Description |
|---|---|
| Three-stage boot image | Flat concatenation `boot.bin + simon.hex0 + FS files`, loaded via QEMU `-bios`. |
| In-kernel filesystem | `simon` parses the FS payload at boot and exposes files via `ls`. |
| `sish` shell | UART-driven shell with `ls`, `echo`, `do`, `hex0`, `hex1`, `shutdown`, `reboot`, `debug`. |
| In-kernel hex compilers | `hex0` (done), `hex1` (done), `hex2` (in progress) implemented in `simon.S`. |
| M0 (live-bootstrap port) | Goal of the current milestone: M0 source compiled by in-kernel hex2 and executed via `do`. |
| Multi-target support | Same chain runs on QEMU `virt` and LicheePi 4A (`builder-lichee`). |
| Integration tests | `pytest + pexpect` drive a real QEMU and assert UART responses. |
| Documentation | `SAD.md`, `SRS_bootstrap(ENG/RU).md`, `Vision(ENG/RU).md`, per-builder `README.md` and `parts.rst`. |

---

## 8. Scope and Boundaries

**In scope (v0.2):**

- The full chain hex0 → hex1 → hex2 → M0 on RISC-V rv64gc.
- QEMU `virt` as the primary development and CI target.
- LicheePi 4A as the validation target for the boot chain.
- Integration tests via `pytest + pexpect`.
- Documentation per stage and per builder.

**Out of scope (v0.2):**

- A general-purpose operating system.
- Networking, storage drivers beyond the UART/in-image FS.
- Stages beyond M0 (M1, M2, `cc_riscv64` are explicitly future work).
- Stage 0 — the cross-compiler is taken as a trusted root.
- Process scheduling in the main kernel (lives in `builder-syscall` until M0 is up).

---

## 9. Success Criteria

- A clean checkout produces a working `image_qemu.bin` for `builder-mvp` via `make build-and-run`.
- `builder-hex1` compiles and runs an in-kernel hex1 payload (covered by tests).
- **`builder-hex2` compiles M0 from hex2 and successfully runs an M0-built payload in QEMU.**
- The same boot chain reaches "Hello, World!" on LicheePi 4A.
- `SAD.md`, `SRS_*`, and `Vision_*` are aligned with the active code state.
- Two `make clean && make` runs (same toolchain) produce identical `image_qemu.bin`.

---

## 10. Major Risks

| Risk | Mitigation |
|---|---|
| M0 design drifts from live-bootstrap upstream | Treat upstream M0 as the spec; port, do not reinvent. |
| Toolchain or QEMU updates break reproducibility | Pin versions per builder; document in `README.md`. |
| Hardware quirks on LicheePi 4A invalidate the QEMU-tuned image | Keep `builder-lichee` as an isolated snapshot until both targets converge. |
| Process model from `builder-syscall` collides with the post-M0 kernel | Defer reintegration until M0 is fully running. |
| Documentation rots faster than code | Make a "docs reflect current state" check part of each milestone's acceptance. |

---

## 11. Evolution Vision (Roadmap)

| Version | Content | Status |
|---|---|---|
| 0.1 | MVP pipeline: `boot` + `simon` + hex0 payload on QEMU; first LicheePi 4A boot. | done |
| 0.2 | hex1 in-kernel; integration tests; **M0 on top of hex2** in `builder-hex2`. | **in progress** |
| 0.3 | M0 + reintegrated process model + bit-reproducible image across hosts. | planned |
| 1.0 | Up to `cc_riscv64` ported from live-bootstrap; minimal self-hosting RISC-V environment. | aspirational |

---

## 12. Conclusion

The `bootstrap` project is a hands-on, RISC-V-native reading of the live-bootstrap idea: a trusted chain that explains itself, kept small enough to audit at every step. By embedding the chain inside a running kernel, the build sequence becomes a transparent shell session rather than a black-box build pipeline. The current milestone — bringing up M0 — is the first point at which the chain produces real assembly from inside the system it is bootstrapping, and is the gateway to the rest of the live-bootstrap ladder.
