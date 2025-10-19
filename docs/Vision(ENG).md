# Vision Document  
## Trusted Environment Bootstrap (RISC-V) — bootstrap  

**Version:** 0.1  
**Date:** 2025-10-19  
**Author:** Daniil Smolin  

---

## 1. Purpose of the Document

The purpose of this document is to describe the concept, goals, value, and boundaries of the “bootstrap” project, which represents a trusted step-by-step build system (bootstrap pipeline) for the RISC-V architecture. The document serves as a guideline for the development team, supervisors, and reviewers, reflecting the vision of the final result and the key implementation stages.

---

## 2. Background and Motivation

Modern toolchains — compilers, linkers, assemblers — often rely on pre-existing binaries whose origin may not always be transparent. This reduces trust in the final system.

In the field of system security and open architectures (e.g., RISC-V), there is a need for a fully reproducible and verifiable system-building process starting from a minimal trusted base.

Our project serves educational, research, and engineering purposes:
- to gain a deep understanding of how to build a system “from scratch”;
- to ensure strict reproducibility;
- to establish a foundation for a trusted execution environment;
- to support further experiments with early boot/stub execution on QEMU and real hardware.

---

## 3. Overall Product Goal

The “bootstrap” system must provide:
- A reproducible build chain of initial tools (stage0 → stage1 → stage2 → …);  
- Confirmation of reproducibility through double compilation / divorce bootstrap (additional independent builds with artifact comparison); <!-- COMMENT: verify if "divorce bootstrap" or "double-compilation validation pipeline" should be finalized -->
- Development and execution of a minimal kernel and boot environment on the RISC-V architecture;
- Execution support on both QEMU virt and real hardware such as Lichee Pi 4A.

The product evolves step-by-step, where each stage includes:
- a specific input environment,
- a result in the form of the next-level artifact,
- a defined completion criterion.

---

## 4. Stakeholders and Their Benefits

| Role / Stakeholder       | Interest / Benefit                                               |
|--------------------------|------------------------------------------------------------------|
| Student developers       | Deep understanding of booting, linking, and the trust chain.     |
| Supervisors/instructors  | Ability to assess students’ understanding of system-level concepts and engineering thinking. |
| CI system                | Automation of reproducibility and stability validation.          |

---

## 5. Problem Space / Needs

| Problem                                    | How the Project Solves It                                           |
|--------------------------------------------|---------------------------------------------------------------------|
| Lack of trust in existing binaries         | Tools are built step-by-step from a minimal trusted foundation.     |
| Non-transparent system build processes     | Logs, determinism, and checksum validation are included.            |
| Difficulty understanding RISC-V boot flow  | Gradual build and execution of artifacts on QEMU and hardware.      |
| Learning architecture on abstractions only | Establishes a direct connection “instruction → binary → execution.” |

---

## 6. Project Objectives

- Organize a minimal trusted chain for building a binary image.  
- Ensure execution of the image on the QEMU emulator.  
- Achieve reproducibility of artifacts during independent rebuilds.  
- Document the pipeline, memory map, entry points, and key dependencies.  
- Demonstrate divorce double compilation principles by validating identical artifacts from independent builds. <!-- COMMENT: confirm final terminology -->
- Develop a minimal kernel (kernel stub) and boot code.  
- Confirm execution capabilities on Lichee Pi 4A (not only in QEMU).  
- Ensure extendability of the pipeline up to stage2 and beyond.  
- Prepare a basis for running a minimal software environment on RISC-V hardware.

---

## 7. Key Features and Functionality

| Feature                    | Description                                                                 |
|---------------------------|------------------------------------------------------------------------------|
| Bootstrap pipeline        | Step-by-step chain of artifact generation with fixed stages.                 |
| ELF → BIN conversion      | Transformation of input ELF into a binary image with a defined entry point. |
| QEMU execution            | Automatic execution via `make qemu` with expected UART0 output.             |
| Reproducibility control   | Calculation and comparison of SHA256 artifact hashes.                       |
| Memory Map visualization  | Documented memory layout and segment distribution.                          |
| Target platform support   | QEMU (required), Lichee Pi 4A (planned/validated).                          |
| Documentation support     | SRS, Vision, Schedule, architectural overview.                              |

---

## 8. Scope and Boundaries

Included:
- Implementation of the pipeline up to a working executable image;
- Use of a fixed compiler (external or stage0);
- Launch on QEMU virt;
- Hash verification of artifacts;
- Documentation support.

Not included (in version 0.1):
- Fully featured operating system;
- Advanced dynamic loader implementation (future stages);
- Network stack or filesystem development;
- Support for all RISC-V platforms beyond QEMU and Lichee Pi 4A (initially).


---

## 9. Success Criteria

- The image successfully runs via `make qemu`;  
- A minimal kernel stub prints a confirmation message through UART;  
- The image successfully boots on Lichee Pi 4A;  
- Documentation (SRS + Vision + Memory Map) is completed;  
- The roadmap for expansion to the next stage is defined.

---

## 10. Major Risks

| Risk                                   | Mitigation Strategy                                       |
|---------------------------------------|-----------------------------------------------------------|
| Stages inconsistency                  | Clear SRS documentation and memory map alignment          |
| Dependency on unstable external tools | Version pinning and hash validation of toolchain binaries |
| Hardware launch failure               | Focus on QEMU first, hardware testing after stabilization |
| Entry point/linking mistakes          | Memory Map and basic launch testing                       |

---

## 11. Evolution Vision (Roadmap)

| Version | Content                                                                 | Status        |
|---------|-------------------------------------------------------------------------|--------------|
| 0.1     | Stage1 pipeline, QEMU launch, SRS/Vision, initial launch on Lichee Pi 4A | In progress  |
| 0.2     | Stage2, extended tests, documentation expansion                         | Planned      |
| 1.0     | Completed bootstrap pipeline for a minimal system with kernel and boot  | Optional/future |

---

## 12. Conclusion

The “bootstrap” project is focused on creating a trusted execution and loading environment for the RISC-V architecture, based on reproducibility, transparency, and educational value. It serves as a foundation for gaining deep understanding of low-level system concepts and can be scaled into a fully featured bootstrap chain.
