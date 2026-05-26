src hex1.hex0
# :_start ; (0x0600078)

    03 36 01 01     # rd_a2 rs1_sp !16 ld               ; Input file name

    ; Initialize globals
    13 0A F0 FF     # rd_s4 !-1 addi                    ; Toggle
    93 0A 00 00     # rd_s5 addi                        ; Hold
    13 0B 00 00     # rd_s6 addi                        ; Instruction Pointer

    ; Open input file and store FD in s2
    93 08 80 03     # rd_a7 !56 addi                    ; sys_openat
    13 05 C0 F9     # rd_a0 !-100 addi                  ; AT_FDCWD
    93 05 06 00     # rd_a1 rs1_a2 mv                   ; file name
    13 06 00 00     # rd_a2 addi                        ; read only
    73 00 00 00     # ecall                             ; syscall
    63 4C 05 40     # rs1_a0 @Fail bltz                 ; Error opening file
                    # +1048
    13 09 05 00     # rd_s2 rs1_a0 mv                   ; Save fd in for later

    ; Set default FD for output file to stdout
    93 09 10 00     # rd_s3 !1 addi

    ; If we only have 2 arguments, don't use the third (it's not set)
    93 02 20 00     # rd_t0 !2 addi
    03 35 01 00     # rd_a0 rs1_sp ld                   ; Get number of the args
    63 42 55 40     # rs1_a0 rs2_t0 @Fail blt           ; No input file provided
                    # +1028B
    63 00 55 02     # rs1_a0 rs2_t0 @after_open beq     ; No output file provided. Use stdout
                    # +32B

    ; Open output file and store the FD in s3
    93 08 80 03     # rd_a7 !56 addi                    ; sys_openat
    13 05 C0 F9     # rd_a0 !-100 addi                  ; AT_FDCWD
    83 35 81 01     # rd_a1 rs1_sp !24 ld               ; Output file (argument 3)
    13 06 10 24     # rd_a2 !00001101 addi              ; decimal 577
    ; O_TRUNC   00001000
    ; O_CREAT   00000100
    ; O_WRONLY  00000001
    ; OCTAL!
    93 06 00 1C     # rd_a3 !00700 addi                 ; Set read, write, execute permission on user
    ; S_IRWXU  00700
    ; OCTAL!
    73 00 00 00     # ecall                             ; syscall
    93 09 05 00     # rd_s3 rs1_a0 mv                   ; Save fd in for later

# :after_open ; (0x06000D4)
    EF 00 40 03     # rd_ra $First_pass jal             ; First pass
                    # +52B

    ; Rewind input file
    93 08 E0 03     # rd_a7 !62 addi                    ; sys_lseek
    13 05 09 00     # rd_a0 rs1_s2 mv                   ; Input file descriptor
    93 05 00 00     # rd_a1 mv                          ; Set offset to zero
    13 06 00 00     # rd_a2 mv                          ; Set whence to zero
    73 00 00 00     # ecall                             ; syscall

    ; Initialize globals
    13 0A F0 FF     # rd_s4 !-1 addi                    ; Toggle
    93 0A 00 00     # rd_s5 addi                        ; Hold
    13 0B 00 00     # rd_s6 addi                        ; Instruction Pointer
    93 0B 00 00     # rd_s7 addi                        ; tempword
    13 0C 00 00     # rd_s8 addi                        ; Shift register

    EF 00 00 07     # rd_ra $Second_pass jal            ; Now do the second pass
                    # +112B

    6F 00 40 3A     # $Done jal                         ; We are done
                    # +392B

; First pass loop to determine addresses of labels
# :First_pass ; (0x0600108)
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

# :First_pass_loop ; (0x0600110)
    EF 00 C0 2D     # rd_ra $Read_byte jal              ; Get another byte
                    # +732B

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    63 06 65 04     # rs1_a0 rs2_t1 @First_pass_done beq
                    # +76B

    ; Check for :
    13 03 A0 03     # rd_t1 !0x3a addi
    63 14 65 00     # rs1_a0 rs2_t1 @First_pass_0 bne
                    # +8B
    EF 00 C0 32     # rd_ra $StoreLabel jal             ; Store this label
                    # +812B

# :First_pass_0 ; (0x0600128)
    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    63 08 65 02     # rs1_a0 rs2_t1 @Throwaway_token beq
                    # +48B

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    63 04 65 02     # rs1_a0 rs2_t1 @Throwaway_token beq
                    # +40B

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    63 00 65 02     # rs1_a0 rs2_t1 @Throwaway_token beq
                    # +32B

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    63 0C 65 00     # rs1_a0 rs2_t1 @Throwaway_token beq
                    # +24B

    93 05 F0 FF     # rd_a1 !-1 addi                    ; write = false
    EF 00 C0 19     # rd_ra $DoByte jal                 ; Deal with everything else
                    # +412B

    13 03 C0 FF     # rd_t1 !-4 addi                    ; Deal with EOF
    63 08 65 00     # rs1_a0 rs2_t1 @First_pass_done beq
                    # +16B

    6F F0 9F FB     # $First_pass_loop jal              ; Keep looping
                    # -72B

# :Throwaway_token ; (0x060015C)
    ; Deal with Pointer to label
    EF 00 00 29     # rd_ra $Read_byte jal              ; Drop the char
                    # +656B
    6F F0 1F FB     # $First_pass_loop jal              ; Loop again
                    # -80B

# :First_pass_done ; (0x0600164)
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

# :Second_pass ; (0x0600170)
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

# :Second_pass_loop ; (0x0600178)
    EF 00 40 27     # rd_ra $Read_byte jal              ; Read another byte
                    # +628B

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi                    ; Deal with EOF
    63 0E 65 14     # rs1_a0 rs2_t1 @Second_pass_done beq
                    # +348B

    ; Drop the label
    13 03 A0 03     # rd_t1 !0x3a addi
    63 16 65 00     # rs1_a0 rs2_t1 @Second_pass_0 bne
                    # +12B

    EF 00 00 26     # rd_ra $Read_byte jal              ; Read the label
                    # +608B
    6F F0 9F FE     # $Second_pass_loop jal             ; Continue looping
                    # -24B

# :Second_pass_0 ; (0x0600194)
    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    63 08 65 02     # rs1_a0 rs2_t1 @UpdateShiftRegister beq
                    # +48B

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    63 04 65 02     # rs1_a0 rs2_t1 @UpdateShiftRegister beq
                    # +40B

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    63 00 65 02     # rs1_a0 rs2_t1 @UpdateShiftRegister beq
                    # +32B

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    63 0C 65 00     # rs1_a0 rs2_t1 @UpdateShiftRegister beq
                    # +24B

    ; Deal with everything else
    93 05 00 00     # rd_a1 mv                          ; write = true
    EF 00 00 13     # rd_ra $DoByte jal                 ; Process our char
                    # +304B

    # Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    63 0E 65 10     # rs1_a0 rs2_t1 @Second_pass_done beq ; We are done
                    # +284B

    6F F0 5F FB     # $Second_pass_loop jal             ; continue looping
                    # -76B

# :UpdateShiftRegister ; (0x06001C8)
    93 05 05 00     # rd_a1 rs1_a0 mv                   ; Store label prefix
    EF 00 C0 25     # rd_ra $Get_table_target jal       ; Get target
                    # +604B
    03 35 05 00     # rd_a0 rs1_a0 ld                   ; Dereference pointer
    33 05 65 41     # rd_a0 rs1_a0 rs2_s6 sub           ; target - ip

    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    63 80 65 02     # rs1_a1 rs2_t1 @UpdateShiftRegister_I beq
                    # +32B

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    63 8A 65 02     # rs1_a1 rs2_t1 @UpdateShiftRegister_B beq
                    # +52B

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    63 8A 65 06     # rs1_a1 rs2_t1 @UpdateShiftRegister_J beq
                    # +116B

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    63 88 65 0A     # rs1_a1 rs2_t1 @UpdateShiftRegister_U beq
                    # +176B

    6F F0 1F F8     # $Second_pass_loop jal             ; continue looping
                    # -128B

# :UpdateShiftRegister_I ; (0x06001FC)
    ; Corresponds to RISC-V I format
    13 05 45 00     # rd_a0 rs1_a0 !4 addi              ; add 4 due to this being 2nd part of auipc combo

    37 13 00 00     # rd_t1 ~0xfff lui                  ; load higher bits
    1B 03 F3 FF     # rd_t1 rs1_t1 !0xfff addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; (value & 0xfff)
    93 1B 43 01     # rd_s7 rs1_t1 rs2_x20 slli         ; tempword = (value & 0xfff) << 20
    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    6F F0 5F F6     # $Second_pass_loop jal             ; continue looping
                    # -156B

# :UpdateShiftRegister_B ; (0x0600218)
    ; Corresponds to RISC-V B format

    ; tempword = ((value & 0x1e) << 7)            ; imm[4:1]
    ;          | ((value & 0x7e0) << (31 - 11))   ; imm[10:5]
    ;          | ((value & 0x800) >> 4)           ; imm[11]
    ;          | ((value & 0x1000) << (31 - 12))  ; imm[12]

    13 03 E0 01     # rd_t1 !0x1e addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x1e
    93 12 73 00     # rd_t0 rs1_t1 rs2_x7 slli          ; tempword = (value & 0x1e) << 7

    13 03 00 7E     # rd_t1 !0x7e0 addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x7e0
    13 13 43 01     # rd_t1 rs1_t1 rs2_x20 slli         ; (value & 0x7e0) << (31 - 11)
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 13 00 00     # rd_t1 ~0x800 lui                  ; load higher bits
    1B 03 03 80     # rd_t1 rs1_t1 !0x800 addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x800
    13 53 43 00     # rd_t1 rs1_t1 rs2_x4 srli          ; (value & 0x800) >> 4
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 13 00 00     # rd_t1 ~0x1000 lui                 ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x1000
    13 13 33 01     # rd_t1 rs1_t1 rs2_x19 slli         ; (value & 0x1000) << (31 - 12)
    B3 EB 62 00     # rd_s7 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    6F F0 DF F1     # $Second_pass_loop jal             ; continue looping
                    # -228B

# :UpdateShiftRegister_J ; (0x0600260)
    ; Corresponds to RISC-V J format

    ; tempword = ((value & 0x7fe) << (30 - 10))    ; imm[10:1]
    ;          | ((value & 0x800) << (20 - 11))    ; imm[11]
    ;          | ((value & 0xff000))               ; imm[19:12]
    ;          | ((value & 0x100000) << (31 - 20)) ; imm[20]

    13 03 E0 7F     # rd_t1 !0x7fe addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x7fe
    93 12 43 01     # rd_t0 rs1_t1 rs2_x20 slli         ; tempword = (value & 0x7fe) << 20

    37 13 00 00     # rd_t1 ~0x800 lui                  ; load higher bits
    1B 03 03 80     # rd_t1 rs1_t1 !0x800 addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x800
    13 13 93 00     # rd_t1 rs1_t1 rs2_x9 slli          ; (value & 0x800) << (20 - 11)
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 F3 0F 00     # rd_t1 ~0xff000 lui                ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0xff000
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 03 10 00     # rd_t1 ~0x100000 lui               ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x100000
    13 13 B3 00     # rd_t1 rs1_t1 rs2_x11 slli         ; (value & 0x100000) << (31 - 20)
    B3 EB 62 00     # rd_s7 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    6F F0 9F ED     # $Second_pass_loop jal             ; continue looping
                    # -296B

# :UpdateShiftRegister_U ; (0x06002A4)
    ; Corresponds to RISC-V U format
    ; if value is 0x800 or more we have to add 11-th bit (0x1000) to compensate for signed extension

    B7 12 00 00     # rd_t0 ~0x800 lui                  ; load higher bits
    9B 82 02 80     # rd_t0 rs1_t0 !0x800 addiw
    37 13 00 00     # rd_t1 ~0xfff lui                  ; load higher bits
    1B 03 F3 FF     # rd_t1 rs1_t1 !0xfff addiw

    ; We are outside 31-bit that ~ can normally load
    B7 03 10 00     # rd_t2 ~0x100000 lui               ; load 0xfffff000
    9B 83 F3 FF     # rd_t2 rs1_t2 !-1 addiw            ; load 0xfffff000
    93 93 C3 00     # rd_t2 rs1_t2 rs2_x12 slli         ; load 0xfffff000
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0xfff
    B3 7B 75 00     # rd_s7 rs1_a0 rs2_t2 and           ; value & 0xfffff000
    63 46 53 00     # rs1_t1 rs2_t0 @UpdateShiftRegister_U_small blt
                    # +12B

    # Deal with sign extension: add 0x1000
    B7 12 00 00     # rd_t0 ~0x1000 lui                 ; load higher bits
    BB 8B 72 01     # rd_s7 rs1_t0 rs2_s7 addw          ; (value & 0xfffff000) + 0x1000

# :UpdateShiftRegister_U_small ; (0x06002D4)
    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    6F F0 1F EA     # $Second_pass_loop jal             ; continue looping
                    # -352B

# :Second_pass_done ; (0x06002DC)
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return


; DoByte function
; Receives:
;   character in a0
;   bool write in a1
; Does not return anything
# :DoByte ; (0x06002E8)
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

    EF 00 00 05     # rd_ra $hex jal                    ; Process hex, store it in a6
                    # +80B

    63 40 08 04     # rs1_a6 @DoByte_Done bltz          ; Deal with EOF and unrecognized characters
                    # +64B

    63 1A 0A 02     # rs1_s4 @DoByte_NotToggle bnez     ; Check if toggle is set
                    # +56B

    ; toggle = true
    63 92 05 02     # rs1_a1 @DoByte_1 bnez             ; check if we have to write
                    # +36B

    ; write = true
    ; We calculate (hold * 16) + hex(c) ^ sr_nextb()
    ; First, calculate new shiftregister
    93 02 F0 0F     # rd_t0 !0xff addi
    B3 72 5C 00     # rd_t0 rs1_s8 rs2_t0 and           ; sr_nextb = shiftregister & 0xff
    13 5C 8C 00     # rd_s8 rs1_s8 rs2_x8 srli          ; shiftregister >> 8

    B3 C2 02 01     # rd_t0 rs1_t0 rs2_a6 xor           ; hex(c) ^ sr_nextb
    13 93 4A 00     # rd_t1 rs1_s5 rs2_x4 slli          ; hold << 4
    33 85 62 00     # rd_a0 rs1_t0 rs2_t1 add           ; (hold << 4) + hex(c) ^ sr_nextb()
    EF 00 40 15     # rd_ra $fputc jal                  ; print it
                    # +340B
    63 0C 05 18     # rs1_a0 @Fail beqz                 ; Fail if nothing was written
                    # +408B

# :DoByte_1 ; (0x0600320)
    13 0B 1B 00     # rd_s6 rs1_s6 !1 addi              ; Increment IP
    93 0A 00 00     # rd_s5 mv                          ; hold = 0
    6F 00 80 00     # $DoByte_FlipToggle jal            ; return
                    # +8B

# :DoByte_NotToggle ; (0x060032C)
    93 0A 08 00     # rd_s5 rs1_a6 mv                   ; hold = hex(c)

# :DoByte_FlipToggle ; (0x0600330)
    13 4A FA FF     # rd_s4 rs1_s4 not                  ; Flip the toggle

# :DoByte_Done ; (0x0600334)
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Convert ASCII hex characters into binary representation, e.g. 'a' -> 0xA
; Receives:
;   character in a0
; Returns:
;   a6 with character's hex value.
# :hex ; (0x0600340)
    13 01 01 FF     # rd_sp rs1_sp !-16 addi            ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra
    23 34 B1 00     # rs1_sp rs2_a1 @8 sd               ; protect a1

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    63 06 65 08     # rs1_a0 rs2_t1 @hex_return beq
                    # +140B

    ; deal with line comments starting with #
    13 03 30 02     # rd_t1 !0x23 addi
    63 06 65 06     # rs1_a0 rs2_t1 @ascii_comment beq ; a0 eq to '#'
                    # +108B

    ; deal with line comments starting with ;
    13 03 B0 03     # rd_t1 !0x3b addi
    63 02 65 06     # rs1_a0 rs2_t1 @ascii_comment beq  ; a0 eq to ';'
                    # +100B

    ; deal all ascii less than 0
    13 03 00 03     # rd_t1 !0x30 addi
    63 4A 65 04     # rs1_a0 rs2_t1 @ascii_other blt
                    # +84B

    ; deal with 0-9
    13 03 A0 03     # rd_t1 !0x3a addi
    63 44 65 02     # rs1_a0 rs2_t1 @ascii_num blt
                    # +40B

    ; deal with all ascii less than A
    13 03 10 04     # rd_t1 !0x41 addi
    63 42 65 04     # rs1_a0 rs2_t1 @ascii_other blt
                    # +68B

    ; deal with A-F
    13 03 70 04     # rd_t1 !0x47 addi
    63 48 65 02     # rs1_a0 rs2_t1 @ascii_high blt
                    # +48B

    ; deal with all ascii less than a
    13 03 10 06     # rd_t1 !0x61 addi
    63 4A 65 02     # rs1_a0 rs2_t1 @ascii_other blt
                    # +52B

    ; deal with a-f
    13 03 70 06     # rd_t1 !0x67 addi
    63 4A 65 00     # rs1_a0 rs2_t1 @ascii_low blt
                    # +20B

    ; The rest that remains needs to be ignored
    6F 00 80 02     # $ascii_other jal
                    # +40B

# :ascii_num ; (0x0600398)
    13 03 00 03     # rd_t1 !0x30 addi                  ; '0' -> 0
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    6F 00 C0 03     # $hex_return jal                   ; return
                    # +60B
# :ascii_low ; (0x06003A4)
    13 03 70 05     # rd_t1 !0x57 addi                  ; 'a' -> 0xA
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    6F 00 00 03     # $hex_return jal                   ; return
                    # +48B
# :ascii_high ; (0x06003B0)
    13 03 70 03     # rd_t1 !0x37 addi                  ; 'A' -> 0xA
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    6F 00 40 02 # $hex_return jal                       ; return
                    # +36B
# :ascii_other ; (0x06003BC)
    13 08 F0 FF     # rd_a6 !-1 addi                    ; Return -1
    6F 00 C0 01     # $hex_return jal                   ; return
                    # +28B
# :ascii_comment ; (0x06003C4)                          ; Read the comment until newline
    EF 00 80 02     # rd_ra $Read_byte jal
                    # +40B
    13 03 D0 00     # rd_t1 !0xd addi                   ; CR
    63 06 65 00     # rs1_a0 rs2_t1 @ascii_comment_cr beq
                    # +12B
    13 03 A0 00     # rd_t1 !0xa addi                   ; LF
    E3 18 65 FE     # rs1_a0 rs2_t1 @ascii_comment bne  ; Keep reading comment
                    # -16B
# :ascii_comment_cr ; (0x06003D8)
    13 08 F0 FF     # rd_a6 !-1 addi                    ; Return -1
# :hex_return ; (0x06003DC)
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    83 35 81 00     # rd_a1 rs1_sp !8 ld                ; restore a1
    13 01 01 01     # rd_sp rs1_sp !16 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Read byte into a0
# :Read_byte ; (0x06003EC)
    13 01 01 FF     # rd_sp rs1_sp !-16 addi            ; Allocate stack
    23 34 B1 00     # rs1_sp rs2_a1 @8 sd               ; protect a1

    93 08 F0 03     # rd_a7 !63 addi                    ; sys_read
    13 05 09 00     # rd_a0 rs1_s2 mv                   ; File descriptor
    93 05 01 00     # rd_a1 rs1_sp mv                   ; Get stack address for buffer
    13 00 00 00     # nop                               ; no-op
    13 06 10 00     # rd_a2 !1 addi                     ; Size of what we want to read
    73 00 00 00     # ecall                             ; syscall

    63 06 05 00     # rs1_a0 @Read_byte_1 beqz          ; Deal with EOF
                    # +12B
    03 85 05 00     # rd_a0 rs1_a1 lb                   ; Dereference pointer

    6F 00 80 00     # $Read_byte_done jal               ; return
                    # +8B

# :Read_byte_1 ; (0x0600418)
    13 05 C0 FF     # rd_a0 !-4 addi                    ; Put EOF in a0
# :Read_byte_done ; (0x060041C)
    83 35 81 00     # rd_a1 rs1_sp !8 ld                ; restore a1
    13 01 01 01     # rd_sp rs1_sp !16 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Reads a byte and calculates table address
; Returns a pointer in a0
# :Get_table_target ; (0x0600428)
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

    EF F0 DF FB     # rd_ra $Read_byte jal              ; Get single char label
                    # -68B
    13 15 35 00     # rd_a0 rs1_a0 rs2_x3 slli          ; Each label in table takes 8 bytes to store
    97 02 00 00     # rd_t0 ~table auipc                ; Load address of table
    93 82 82 08     # rd_t0 rs1_t0 !table addi          ; into register t0
                    # +136B
    33 05 55 00     # rd_a0 rs1_a0 rs2_t0 add           ; Calculate offset

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

# :StoreLabel ; (0x0600450)
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

    EF F0 1F FD     # rd_ra $Get_table_target jal
                    # -48B
    23 30 65 01     # rs1_a0 rs2_s6 sd                  ; Store ip into table target

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; fputc function
; Receives CHAR in a0
; Writes and returns number of bytes written in a0
# :fputc ; (0x060046C)
    13 01 01 FE     # rd_sp rs1_sp !-32 addi            ; allocate stack
    23 30 A1 00     # rs1_sp rs2_a0 sd                  ; protect a0
    23 34 11 00     # rs1_sp rs2_ra @8 sd               ; protect ra
    23 38 B1 00     # rs1_sp rs2_a1 @16 sd              ; protect a1
    23 3C C1 00     # rs1_sp rs2_a2 @24 sd              ; protect a2

    93 08 00 04     # rd_a7 !64 addi                    ; sys_write
    13 85 09 00     # rd_a0 rs1_s3 mv                   ; write to output
    93 05 01 00     # rd_a1 rs1_sp mv                   ; Get stack address
    13 06 10 00     # rd_a2 !1 addi                     ; write 1 character
    73 00 00 00     # ecall                             ; syscall

    83 30 81 00     # rd_ra rs1_sp !8 ld                ; restore ra
    83 35 01 01     # rd_a1 rs1_sp !16 ld               ; restore a1
    03 36 81 01     # rd_a2 rs1_sp !24 ld               ; restore a2
    13 01 01 02     # rd_sp rs1_sp !32 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

# :Done ; (0x06004A8)
    ; Terminate program with 0 return code
    93 08 D0 05     # rd_a7 !93 addi                    ; sys_exit
    13 05 00 00     # rd_a0 mv                          ; Return code 0
    73 00 00 00     # ecall                             ; exit(0)
# :Fail ; (0x06004B4)
    ; Terminate program with 1 return code
    93 08 D0 05     # rd_a7 !93 addi                    ; sys_exit
    13 05 10 00     # rd_a0 !1 addi                     ; Return code 1
    73 00 00 00     # ecall                             ; exit(1)
# PROGRAM END

# :table; (0x06004C0)
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
 src hex2.hex1
#:_start

    03 36 01 01     # rd_a2 rs1_sp !16 ld               ; Input file name

    ; Initialize globals
    13 0A F0 FF     # rd_s4 !-1 addi                    ; Toggle
    93 0A 00 00     # rd_s5 addi                        ; Hold
    37 0B 60 00     # rd_s6 ~0x600000 lui               ; Instruction Pointer

    ; Open input file and store FD in s2
    93 08 80 03     # rd_a7 !56 addi                    ; sys_openat
    13 05 C0 F9     # rd_a0 !-100 addi                  ; AT_FDCWD
    93 05 06 00     # rd_a1 rs1_a2 mv                   ; file name
    13 06 00 00     # rd_a2 addi                        ; read only
    73 00 00 00     # ecall                             ; syscall
    @F 63 40 05 00  # rs1_a0 @Fail bltz                 ; Error opening file
    13 09 05 00     # rd_s2 rs1_a0 mv                   ; Save fd in for later

    ; Set default FD for output file to stdout
    93 09 10 00     # rd_s3 !1 addi

    ; If we only have 2 arguments, don't use the third (it's not set)
    93 02 20 00     # rd_t0 !2 addi
    03 35 01 00     # rd_a0 rs1_sp ld                   ; Get number of the args
    @F 63 40 55 00  # rs1_a0 rs2_t0 @Fail blt           ; No input file provided
    @a 63 00 55 00  # rs1_a0 rs2_t0 @after_open beq     ; No output file provided. Use stdout

    ; Open output file and store the FD in s3
    93 08 80 03     # rd_a7 !56 addi                    ; sys_openat
    13 05 C0 F9     # rd_a0 !-100 addi                  ; AT_FDCWD
    83 35 81 01     # rd_a1 rs1_sp !24 ld               ; Output file (argument 3)
    13 06 10 24     # rd_a2 !00001101 addi              ; decimal 577
    ; O_TRUNC   00001000
    ; O_CREAT   00000100
    ; O_WRONLY  00000001
    ; OCTAL!
    93 06 00 1C     # rd_a3 !00700 addi                 ; Set read, write, execute permission on user
    ; S_IRWXU  00700
    ; OCTAL!
    73 00 00 00     # ecall                             ; syscall
    93 09 05 00     # rd_s3 rs1_a0 mv                   ; Save fd in for later

:a ;after_open
    ; Prepare heap memory
    93 08 60 0D     # rd_a7 !214 addi                   ; sys_brk
    13 05 00 00     # rd_a0 addi                        ; Get current brk
    73 00 00 00     # ecall                             ; syscall
    93 0C 05 00     # rd_s9 rs1_a0 addi                 ; Set our malloc pointer

    B7 05 10 00     # rd_a1 ~0x100000 lui
    33 05 B5 00     # rd_a0 rs1_a0 rs2_a1 add           ; Request the 1 MiB
    93 08 60 0D     # rd_a7 !214 addi                   ; sys_brk
    73 00 00 00     # ecall                             ; syscall

    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Zero scratch
    $f EF 00 00 00  # rd_ra $First_pass jal             ; First pass

    ; Rewind input file
    93 08 E0 03     # rd_a7 !62 addi                    ; sys_lseek
    13 05 09 00     # rd_a0 rs1_s2 mv                   ; Input file descriptor
    93 05 00 00     # rd_a1 mv                          ; Set offset to zero
    13 06 00 00     # rd_a2 mv                          ; Set whence to zero
    73 00 00 00     # ecall                             ; syscall

    ; Initialize globals
    13 0A F0 FF     # rd_s4 !-1 addi                    ; Toggle
    93 0A 00 00     # rd_s5 addi                        ; Hold
    37 0B 60 00     # rd_s6 ~0x600000 lui               ; Instruction Pointer
    93 0B 00 00     # rd_s7 addi                        ; tempword
    13 0C 00 00     # rd_s8 addi                        ; Shift register

    $X EF 00 00 00  # rd_ra $Second_pass jal            ; Now do the second pass

    ; Terminate program with 0 return code
    93 08 D0 05     # rd_a7 !93 addi                    ; sys_exit
    13 05 00 00     # rd_a0 mv                          ; Return code 0
    73 00 00 00     # ecall                             ; exit(0)

; First pass loop to determine addresses of labels
:f ;First_pass
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

:1 ;First_pass_loop
    $R EF 00 00 00  # rd_ra $Read_byte jal              ; Get another byte

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    @3 63 00 65 00  # rs1_a0 rs2_t1 @First_pass_done beq

    ; Check for :
    13 03 A0 03     # rd_t1 !0x3a addi
    @L 63 00 65 00  # rs1_a0 rs2_t1 @StoreLabel beq ; Store this label

    ; Check for .
    13 03 E0 02     # rd_t1 !0x2e addi
    @w 63 00 65 00  # rs1_a0 rs2_t1 @First_pass_UpdateWord beq

    ; Check for %
    13 03 50 02     # rd_t1 !0x25 addi
    @p 63 00 65 00  # rs1_a0 rs2_t1 @First_pass_pointer beq

    ; Check for &
    13 03 60 02     # rd_t1 !0x26 addi
    @p 63 00 65 00  # rs1_a0 rs2_t1 @First_pass_pointer beq

    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    @T 63 00 65 00  # rs1_a0 rs2_t1 @Throwaway_token beq

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    @T 63 00 65 00  # rs1_a0 rs2_t1 @Throwaway_token beq

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    @T 63 00 65 00  # rs1_a0 rs2_t1 @Throwaway_token beq

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    @T 63 00 65 00  # rs1_a0 rs2_t1 @Throwaway_token beq

    ; Check for <
    13 03 C0 03     # rd_t1 !0x3c addi
    93 05 F0 FF     # rd_a1 !-1 addi                    ; write = false
    @A 63 00 65 00  # rs1_a0 rs2_t1 @PadToAlign beq

    93 05 F0 FF     # rd_a1 !-1 addi                    ; write = false
    13 06 F0 FF     # rd_a2 !-1 addi                    ; update = false
    $D EF 00 00 00  # rd_ra $DoByte jal                 ; Deal with everything else

    13 03 C0 FF     # rd_t1 !-4 addi                    ; Deal with EOF
    @3 63 00 65 00  # rs1_a0 rs2_t1 @First_pass_done beq

    $1 6F 00 00 00  # $First_pass_loop jal              ; Keep looping

:T ;Throwaway_token
    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; get scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read token
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Throw away token
    $1 6F 00 00 00  # $First_pass_loop jal              ; Loop again

:p ;First_pass_pointer
    13 0B 4B 00     # rd_s6 rs1_s6 !4 addi              ; Update ip
    ; Deal with Pointer to label
    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Using scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read token
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Throw away token
    13 03 E0 03     # rd_t1 !0x3e addi                  ; Check for '>'
    @1 63 10 65 00  # rs1_a0 rs2_t1 @First_pass_loop bne ; Loop again

    ; Deal with %label>label case
    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Using scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read token
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Throw away token
    $1 6F 00 00 00  # $First_pass_loop jal ; Loop again

:w ;First_pass_UpdateWord
    13 0D 00 00     # rd_s10 addi                       ; updates = 0
    93 0B 00 00     # rd_s7 addi                        ; tempword = 0
    93 07 40 00     # rd_a5 !4 addi                     ; a5 = 4
:4 ;First_pass_UpdateWord_loop
    $R EF 00 00 00  # rd_ra $Read_byte jal              ; Read another byte into a0

    93 05 F0 FF     # rd_a1 !-1 addi                    ; write = false
    13 06 00 00     # rd_a2 addi                        ; update = true
    $D EF 00 00 00  # rd_ra $DoByte jal                 ; Process byte
    @4 63 40 FD 00  # rs1_s10 rs2_a5 @First_pass_UpdateWord_loop blt ; loop 4 times

    13 0B CB FF     # rd_s6 rs1_s6 !-4 addi             ; ip = ip - 4

    $1 6F 00 00 00  # $First_pass_loop jal              ; Loop again

:3 ;First_pass_done
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

:X ;Second_pass
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

:5 ;Second_pass_loop
    $R EF 00 00 00  # rd_ra $Read_byte jal              ; Read another byte

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi                    ; Deal with EOF
    @6 63 00 65 00  # rs1_a0 rs2_t1 @Second_pass_done beq

    ; Drop the label
    13 03 A0 03     # rd_t1 !0x3a addi
    @7 63 10 65 00  # rs1_a0 rs2_t1 @Second_pass_0 bne

    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Using scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read the label
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Throw away token

    $5 6F 00 00 00  # $Second_pass_loop jal             ; Continue looping

:7 ;Second_pass_0
    ; Check for .
    13 03 E0 02     # rd_t1 !0x2e addi
    @8 63 00 65 00  # rs1_a0 rs2_t1 @Second_pass_UpdateWord beq

    ; Check for %
    13 03 50 02     # rd_t1 !0x25 addi
    @S 63 00 65 00  # rs1_a0 rs2_t1 @StorePointer beq

    ; Check for &
    13 03 60 02     # rd_t1 !0x26 addi
    @S 63 00 65 00  # rs1_a0 rs2_t1 @StorePointer beq

    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    @Y 63 00 65 00  # rs1_a0 rs2_t1 @UpdateShiftRegister beq

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    @Y 63 00 65 00  # rs1_a0 rs2_t1 @UpdateShiftRegister beq

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    @Y 63 00 65 00  # rs1_a0 rs2_t1 @UpdateShiftRegister beq

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    @Y 63 00 65 00  # rs1_a0 rs2_t1 @UpdateShiftRegister beq

    ; Check for <
    13 03 C0 03     # rd_t1 !0x3c addi
    93 05 00 00     # rd_a1 addi                        ; write = true
    @A 63 00 65 00  # rs1_a0 rs2_t1 @PadToAlign beq

    ; Deal with everything else
    93 05 00 00     # rd_a1 addi                        ; write = true
    13 06 F0 FF     # rd_a2 !-1 addi                    ; update = false
    $D EF 00 00 00  # rd_ra $DoByte jal                 ; Process our char

    # Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    @6 63 00 65 00  # rs1_a0 rs2_t1 @Second_pass_done beq ; We are done

    $5 6F 00 00 00  # $Second_pass_loop jal ; continue looping

:8 ;Second_pass_UpdateWord
    13 0D 00 00     # rd_s10 addi                       ; updates = 0
    93 0B 00 00     # rd_s7 addi                        ; tempword = 0
    93 07 40 00     # rd_a5 !4 addi                     ; a5 = 4

:9 ;Second_pass_UpdateWord_loop
    $R EF 00 00 00  # rd_ra $Read_byte jal       ; Read another byte into a0

    93 05 F0 FF     # rd_a1 !-1 addi                    ; write = false
    13 06 00 00     # rd_a2 addi                        ; update = true
    $D EF 00 00 00  # rd_ra $DoByte jal             ; Process our char
    @9 63 40 FD 00  # rs1_s10 rs2_a5 @Second_pass_UpdateWord_loop blt ; loop 4 times

    13 85 0B 00     # rd_a0 rs1_s7 mv                   ; tempword
    $d 6F 00 00 00  # $UpdateShiftRegister_DOT jal ; UpdateShiftRegister('.', tempword)

:Y ;UpdateShiftRegister
    13 06 05 00     # rd_a2 rs1_a0 mv                   ; Store label prefix
    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Get scratch
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; Clear scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read token
    $G EF 00 00 00  # rd_ra $GetTarget jal              ; Get target
    03 35 05 00     # rd_a0 rs1_a0 ld                   ; Dereference pointer
    33 05 65 41     # rd_a0 rs1_a0 rs2_s6 sub           ; target - ip

    ; Check for !
    13 03 10 02     # rd_t1 !0x21 addi
    @I 63 00 66 00  # rs1_a2 rs2_t1 @UpdateShiftRegister_I beq

    ; Check for @
    13 03 00 04     # rd_t1 !0x40 addi
    @B 63 00 66 00  # rs1_a2 rs2_t1 @UpdateShiftRegister_B beq

    ; Check for $
    13 03 40 02     # rd_t1 !0x24 addi
    @J 63 00 66 00  # rs1_a2 rs2_t1 @UpdateShiftRegister_J beq

    ; Check for ~
    13 03 E0 07     # rd_t1 !0x7e addi
    @U 63 00 66 00  # rs1_a2 rs2_t1 @UpdateShiftRegister_U beq

    $5 6F 00 00 00  # $Second_pass_loop jal ; continue looping

:d ;UpdateShiftRegister_DOT
    ; . before instruction means it has to be added to the final word

    ; swap = (((value >> 24) & 0xff) |
    ;        ((value << 8) & 0xff0000) |
    ;        ((value >> 8) & 0xff00) |
    ;        ((value << 24) & 0xff000000))

    9B 53 85 01     # rd_t2 rs1_a0 rs2_x24 srliw        ; value >> 24
    13 03 F0 0F     # rd_t1 !0xff addi                  ; t1 = 0xff
    B3 72 73 00     # rd_t0 rs1_t1 rs2_t2 and           ; (value >> 24) & 0xff

    9B 13 85 00     # rd_t2 rs1_a0 rs2_x8 slliw         ; value << 8
    37 03 FF 00     # rd_t1 ~0xff0000 lui               ; t1 = 0xff0000
    B3 73 73 00     # rd_t2 rs1_t1 rs2_t2 and           ; (value << 8) & 0xff0000
    B3 E2 72 00     # rd_t0 rs1_t0 rs2_t2 or            ; logical or with the previous expression

    9B 53 85 00     # rd_t2 rs1_a0 rs2_x8 srliw         ; value >> 8
    37 03 01 00     # rd_t1 ~0xff00 lui                 ; t1 = 0xff00
    1B 03 03 F0     # rd_t1 rs1_t1 !0xff00 addiw        ; t1 = 0xff00
    B3 73 73 00     # rd_t2 rs1_t1 rs2_t2 and           ; (value << 8) & 0xff00
    B3 E2 72 00     # rd_t0 rs1_t0 rs2_t2 or            ; logical or with the previous expression

    9B 13 85 01     # rd_t2 rs1_a0 rs2_x24 slliw        ; value << 24
    13 03 F0 0F     # rd_t1 !0xff addi
    13 13 83 01     # rd_t1 rs1_t1 rs2_x24 slli         ; t1 = 0xff000000
    B3 73 73 00     # rd_t2 rs1_t1 rs2_t2 and           ; (value << 24) & 0xff000000
    B3 E2 72 00     # rd_t0 rs1_t0 rs2_t2 or            ; swap

    33 4C 5C 00     # rd_s8 rs1_s8 rs2_t0 xor           ; shiftregister = shiftregister ^ swap

    13 0B CB FF     # rd_s6 rs1_s6 !-4 addi             ; ip = ip - 4
    $5 6F 00 00 00  # $Second_pass_loop jal             ; continue looping

:I ;UpdateShiftRegister_I
    ; Corresponds to RISC-V I format
    1B 05 45 00     # rd_a0 rs1_a0 !4 addiw             ; add 4 due to this being 2nd part of auipc combo

    37 13 00 00     # rd_t1 ~0xfff lui                  ; load higher bits
    1B 03 F3 FF     # rd_t1 rs1_t1 !0xfff addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; (value & 0xfff)
    9B 1B 43 01     # rd_s7 rs1_t1 rs2_x20 slliw        ; tempword = (value & 0xfff) << 20
    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    $5 6F 00 00 00  # $Second_pass_loop jal             ; continue looping

:B ;UpdateShiftRegister_B
    ; Corresponds to RISC-V B format

    ; tempword = ((value & 0x1e) << 7)            ; imm[4:1]
    ;          | ((value & 0x7e0) << (31 - 11))   ; imm[10:5]
    ;          | ((value & 0x800) >> 4)           ; imm[11]
    ;          | ((value & 0x1000) << (31 - 12))  ; imm[12]

    13 03 E0 01     # rd_t1 !0x1e addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x1e
    9B 12 73 00     # rd_t0 rs1_t1 rs2_x7 slliw         ; tempword = (value & 0x1e) << 7

    13 03 00 7E     # rd_t1 !0x7e0 addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x7e0
    1B 13 43 01     # rd_t1 rs1_t1 rs2_x20 slliw        ; (value & 0x7e0) << (31 - 11)
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 13 00 00     # rd_t1 ~0x800 lui                  ; load higher bits
    1B 03 03 80     # rd_t1 rs1_t1 !0x800 addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x800
    1B 53 43 00     # rd_t1 rs1_t1 rs2_x4 srliw         ; (value & 0x800) >> 4
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 13 00 00     # rd_t1 ~0x1000 lui                 ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x1000
    1B 13 33 01     # rd_t1 rs1_t1 rs2_x19 slliw        ; (value & 0x1000) << (31 - 12)
    B3 EB 62 00     # rd_s7 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    $5 6F 00 00 00  # $Second_pass_loop jal             ; continue looping

:J ;UpdateShiftRegister_J
    ; Corresponds to RISC-V J format

    ; tempword = ((value & 0x7fe) << (30 - 10))    ; imm[10:1]
    ;          | ((value & 0x800) << (20 - 11))    ; imm[11]
    ;          | ((value & 0xff000))               ; imm[19:12]
    ;          | ((value & 0x100000) << (31 - 20)) ; imm[20]

    13 03 E0 7F     # rd_t1 !0x7fe addi
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x7fe
    9B 12 43 01     # rd_t0 rs1_t1 rs2_x20 slliw        ; tempword = (value & 0x7fe) << 20

    37 13 00 00     # rd_t1 ~0x800 lui                  ; load higher bits
    1B 03 03 80     # rd_t1 rs1_t1 !0x800 addiw
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x800
    1B 13 93 00     # rd_t1 rs1_t1 rs2_x9 slliw         ; (value & 0x800) << (20 - 11)
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 F3 0F 00     # rd_t1 ~0xff000 lui                ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0xff000
    B3 E2 62 00     # rd_t0 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    37 03 10 00     # rd_t1 ~0x100000 lui               ; load higher bits
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0x100000
    1B 13 B3 00     # rd_t1 rs1_t1 rs2_x11 slliw        ; (value & 0x100000) << (31 - 20)
    B3 EB 62 00     # rd_s7 rs1_t0 rs2_t1 or            ; logical or with the previous expression

    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    $5 6F 00 00 00  # $Second_pass_loop jal             ; continue looping

:U ;UpdateShiftRegister_U
    ; Corresponds to RISC-V U format
    ; if value is 0x800 or more we have to add 11-th bit (0x1000) to compensate for signed extension

    B7 12 00 00     # rd_t0 ~0x800 lui                  ; load higher bits
    9B 82 02 80     # rd_t0 rs1_t0 !0x800 addiw
    37 13 00 00     # rd_t1 ~0xfff lui                  ; load higher bits
    1B 03 F3 FF     # rd_t1 rs1_t1 !0xfff addiw

    ; We are outside 31-bit that ~ can normally load
    B7 03 10 00     # rd_t2 ~0x100000 lui               ; load 0xfffff000
    9B 83 F3 FF     # rd_t2 rs1_t2 !-1 addiw            ; load 0xfffff000
    93 93 C3 00     # rd_t2 rs1_t2 rs2_x12 slli         ; load 0xfffff000
    33 73 65 00     # rd_t1 rs1_a0 rs2_t1 and           ; value & 0xfff
    B3 7B 75 00     # rd_s7 rs1_a0 rs2_t2 and           ; value & 0xfffff000
    @u 63 40 53 00  # rs1_t1 rs2_t0 @UpdateShiftRegister_U_small blt

    # Deal with sign extension: add 0x1000
    B7 12 00 00     # rd_t0 ~0x1000 lui                 ; load higher bits
    BB 8B 72 01     # rd_s7 rs1_t0 rs2_s7 addw          ; (value & 0xfffff000) + 0x1000

:u ;UpdateShiftRegister_U_small
    33 4C 7C 01     # rd_s8 rs1_s8 rs2_s7 xor           ; shiftregister = shiftregister ^ tempword

    $5 6F 00 00 00  # $Second_pass_loop jal             ; continue looping

:S ;StorePointer
    13 0B 4B 00     # rd_s6 rs1_s6 !4 addi              ; update ip
    13 06 05 00     # rd_a2 rs1_a0 mv                   ; Store label prefix

    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Get scratch
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; clear scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Read token
    93 07 05 00     # rd_a5 rs1_a0 mv                   ; save char
    $G EF 00 00 00  # rd_ra $GetTarget jal              ; Get target
    83 35 05 00     # rd_a1 rs1_a0 ld                   ; Dereference pointer

    ; If char is > then change relative base address to ip
    13 03 E0 03     # rd_t1 !0x3e addi                  ; t1 = 0x3e
    @P 63 00 F3 00  # rs1_t1 rs2_a5 @StorePointer_1 beq

    ; Check for &
    13 03 60 02     # rd_t1 !0x26 addi
    @0 63 00 66 00  # rs1_a2 rs2_t1 @StorePointer_0 beq

    ; Check for %
    13 03 50 02     # rd_t1 !0x25 addi
    @F 63 10 66 00  # rs1_a2 rs2_t1 @Fail bne
    B3 85 65 41     # rd_a1 rs1_a1 rs2_s6 sub           ; displacement = target - ip

:0 ;StorePointer_0
    ; Output pointer
    93 07 40 00     # rd_a5 !4 addi                     ; number of bytes
:l ;StorePointer_loop
    13 D3 85 00     # rd_t1 rs1_a1 rs2_x8 srli          ; value / 256
    13 15 83 00     # rd_a0 rs1_t1 rs2_x8 slli
    33 85 A5 40     # rd_a0 rs1_a1 rs2_a0 sub           ; byte = value % 256

    93 05 03 00     # rd_a1 rs1_t1 mv                   ; value = value / 256
    $t EF 00 00 00  # rd_ra $fputc jal                  ; write value
    93 87 F7 FF     # rd_a5 rs1_a5 !-1 addi             ; decrease number of bytes to write
    @l 63 90 07 00  # rs1_a5 @StorePointer_loop bnez    ; continue looping

    $5 6F 00 00 00  # $Second_pass_loop jal             ; Continue looping

:P ;StorePointer_1
    13 86 05 00     # rd_a2 rs1_a1 mv                   ; save target
    ~s 97 05 00 00  # rd_a1 ~scratch auipc
    !s 93 85 05 00  # rd_a1 rs1_a1 !scratch addi        ; Get scratch
    $C EF 00 00 00  # rd_ra $ClearScratch jal           ; clear scratch
    $c EF 00 00 00  # rd_ra $consume_token jal          ; consume token
    $G EF 00 00 00  # rd_ra $GetTarget jal              ; Get target
    83 35 05 00     # rd_a1 rs1_a0 ld                   ; Dereference pointer
    B3 05 B6 40     # rd_a1 rs1_a2 rs2_a1 sub           ; displacement = target - ip

    $0 6F 00 00 00  # $StorePointer_0 jal               ; Continue looping

:6 ;Second_pass_done
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Pad with zeros to align to word size
;   bool write in a1
:A ;PadToAlign
    13 03 10 00     # rd_t1 !1 addi                     ; t1 = 1
    33 75 6B 00     # rd_a0 rs1_s6 rs2_t1 and           ; ip & 0x1
    @b 63 10 65 00  # rs1_a0 rs2_t1 @PadToAlign_1 bne   ; check if ip & 0x1 == 1
    33 0B 6B 00     # rd_s6 rs1_s6 rs2_t1 add           ; ip = ip + 1

    @b 63 90 05 00  # rs1_a1 @PadToAlign_1 bnez         ; check if we have to write
    13 05 00 00     # rd_a0 mv                          ; a0 = 0
    $t EF 00 00 00  # rd_ra $fputc jal                  ; write 0

:b ;PadToAlign_1
    13 03 20 00     # rd_t1 !2 addi                     ; t1 = 2
    33 75 6B 00     # rd_a0 rs1_s6 rs2_t1 and           ; ip & 0x1
    @e 63 10 65 00  # rs1_a0 rs2_t1 @PadToAlign_2 bne   ; check if ip & 0x2 == 2
    33 0B 6B 00     # rd_s6 rs1_s6 rs2_t1 add           ; ip = ip + 2

    @e 63 90 05 00  # rs1_a1 @PadToAlign_2 bnez         ; check if we have to write
    13 05 00 00     # rd_a0 mv                          ; a0 = 0
    $t EF 00 00 00  # rd_ra $fputc jal                  ; write 0
    13 05 00 00     # rd_a0 mv                          ; a0 = 0
    $t EF 00 00 00  # rd_ra $fputc jal                  ; write 0

:e ;PadToAlign_2
    @5 63 80 05 00  # rs1_a1 @Second_pass_loop beqz     ; return to Second_pass
    $1 6F 00 00 00  # $First_pass_loop jal              ; return to First_pass

; Zero scratch area
:C ;ClearScratch
    13 01 81 FE     # rd_sp rs1_sp !-24 addi            ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra
    23 34 A1 00     # rs1_sp rs2_a0 @8 sd               ; protect a0
    23 38 B1 00     # rs1_sp rs2_a1 @16 sd              ; protect a1

    ~s 17 05 00 00  # rd_a0 ~scratch auipc
    !s 13 05 05 00  # rd_a0 rs1_a0 !scratch addi        ; Find where our scratch area is

:g ;ClearScratch_loop
    83 05 05 00     # rd_a1 rs1_a0 lb                   ; Read current byte: s[i]
    23 00 05 00     # rs1_a0 sb                         ; Write zero: s[i] = 0
    13 05 15 00     # rd_a0 rs1_a0 !1 addi              ; Increment: i = i + 1
    @g 63 90 05 00  # rs1_a1 @ClearScratch_loop bnez    ; Keep looping

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    03 35 81 00     # rd_a0 rs1_sp !8 ld                ; restore a0
    83 35 01 01     # rd_a1 rs1_sp !16 ld               ; restore a1
    13 01 81 01     # rd_sp rs1_sp !24 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Receives pointer in a1
; Writes our token and updates pointer in a1
:c ;consume_token
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

:h ;consume_token_0
    $R EF 00 00 00  # rd_ra $Read_byte jal              ; Read byte into a0

    ; Check for \t
    13 03 90 00     # rd_t1 !0x09 addi
    @j 63 00 65 00  # rs1_a0 rs2_t1 @consume_token_done beq

    ; Check for \n
    13 03 A0 00     # rd_t1 !0x0a addi
    @j 63 00 65 00  # rs1_a0 rs2_t1 @consume_token_done beq

    ; Check for ' '
    13 03 00 02     # rd_t1 !0x20 addi
    @j 63 00 65 00  # rs1_a0 rs2_t1 @consume_token_done beq

    ; Check for >
    13 03 E0 03     # rd_t1 !0x3e addi
    @j 63 00 65 00  # rs1_a0 rs2_t1 @consume_token_done beq

    23 80 A5 00     # rs1_a1 rs2_a0 sb                  ; Store char
    93 85 15 00     # rd_a1 rs1_a1 !1 addi              ; Point to next spot
    $h 6F 00 00 00  # $consume_token_0 jal ; Continue looping

:j ;consume_token_done
    23 B0 05 00     # rs1_a1 sd                         ; Pad with nulls
    93 85 85 00     # rd_a1 rs1_a1 !8 addi              ; Update the pointer

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; DoByte function
; Receives:
;   character in a0
;   bool write in a1
;   bool update in a2
; Does not return anything
:D ;DoByte
    13 01 01 FF     # rd_sp rs1_sp !-16 addi            ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra
    23 34 01 01     # rs1_sp rs2_a6 @8 sd               ; protect a6

    $H EF 00 00 00  # rd_ra $hex jal                    ; Process hex, store it in a6

    @k 63 40 08 00  # rs1_a6 @DoByte_Done bltz          ; Deal with EOF and unrecognized characters

    @2 63 10 0A 00  # rs1_s4 @DoByte_NotToggle bnez     ; Check if toggle is set

    ; toggle = true
    @m 63 90 05 00  # rs1_a1 @DoByte_1 bnez             ; check if we have to write

    ; write = true
    ; We calculate (hold * 16) + hex(c) ^ sr_nextb()
    ; First, calculate new shiftregister
    93 02 F0 0F     # rd_t0 !0xff addi
    B3 72 5C 00     # rd_t0 rs1_s8 rs2_t0 and           ; sr_nextb = shiftregister & 0xff
    1B 5C 8C 00     # rd_s8 rs1_s8 rs2_x8 srliw         ; shiftregister >> 8

    B3 C2 02 01     # rd_t0 rs1_t0 rs2_a6 xor           ; hex(c) ^ sr_nextb
    13 93 4A 00     # rd_t1 rs1_s5 rs2_x4 slli          ; hold << 4
    33 85 62 00     # rd_a0 rs1_t0 rs2_t1 add           ; (hold << 4) + hex(c) ^ sr_nextb()
    $t EF 00 00 00  # rd_ra $fputc jal                  ; print it
    @F 63 00 05 00  # rs1_a0 @Fail beqz                 ; Fail if nothing was written

:m ;DoByte_1
    13 0B 1B 00     # rd_s6 rs1_s6 !1 addi              ; Increment IP
    @o 63 00 06 00  # rs1_a2 @DoByte_2 beqz             ; check if we have to update
:n ;DoByte_2b
    93 0A 00 00     # rd_s5 mv                          ; hold = 0
    $q 6F 00 00 00  # $DoByte_FlipToggle jal            ; return

:2 ;DoByte_NotToggle
    93 0A 08 00     # rd_s5 rs1_a6 mv                   ; hold = hex(c)

:q ;DoByte_FlipToggle
    13 4A FA FF     # rd_s4 rs1_s4 not                  ; Flip the toggle

:k ;DoByte_Done
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    03 38 81 00     # rd_a6 rs1_sp !8 ld                ; restore a6
    13 01 01 01     # rd_sp rs1_sp !16 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

:o ;DoByte_2
    13 93 4A 00     # rd_t1 rs1_s5 rs2_x4 slli          ; hold * 16
    B3 0A 03 01     # rd_s5 rs1_t1 rs2_a6 add           ; hold = hold * 16 + hex(c)
    13 93 8B 00     # rd_t1 rs1_s7 rs2_x8 slli          ; tempword << 8
    B3 4B 53 01     # rd_s7 rs1_t1 rs2_s5 xor           ; tempword = (tempword << 8) ^ hold
    13 0D 1D 00     # rd_s10 rs1_s10 !1 addi            ; updates = updates + 1
    $n 6F 00 00 00  # $DoByte_2b jal

; Convert ASCII hex characters into binary representation, e.g. 'a' -> 0xA
; Receives:
;   character in a0
; Returns:
;   a6 with character's hex value.
:H ;hex
    13 01 01 FF     # rd_sp rs1_sp !-16 addi            ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra
    23 34 B1 00     # rs1_sp rs2_a1 @8 sd               ; protect a1

    ; Deal with EOF
    13 03 C0 FF     # rd_t1 !-4 addi
    @r 63 00 65 00  # rs1_a0 rs2_t1 @hex_return beq

    ; deal with line comments starting with #
    13 03 30 02     # rd_t1 !0x23 addi
    @x 63 00 65 00  # rs1_a0 rs2_t1 @ascii_comment beq  ; a0 eq to '#'

    ; deal with line comments starting with ;
    13 03 B0 03     # rd_t1 !0x3b addi
    @x 63 00 65 00  # rs1_a0 rs2_t1 @ascii_comment beq  ; a0 eq to ';'

    ; deal all ascii less than 0
    13 03 00 03     # rd_t1 !0x30 addi
    @y 63 40 65 00  # rs1_a0 rs2_t1 @ascii_other blt

    ; deal with 0-9
    13 03 A0 03     # rd_t1 !0x3a addi
    @N 63 40 65 00  # rs1_a0 rs2_t1 @ascii_num blt

    ; deal with all ascii less than A
    13 03 10 04     # rd_t1 !0x41 addi
    @y 63 40 65 00  # rs1_a0 rs2_t1 @ascii_other blt

    ; deal with A-F
    13 03 70 04     # rd_t1 !0x47 addi
    @z 63 40 65 00  # rs1_a0 rs2_t1 @ascii_high blt

    ; deal with all ascii less than a
    13 03 10 06     # rd_t1 !0x61 addi
    @y 63 40 65 00  # rs1_a0 rs2_t1 @ascii_other blt

    ; deal with a-f
    13 03 70 06     # rd_t1 !0x67 addi
    @Z 63 40 65 00  # rs1_a0 rs2_t1 @ascii_low blt

    ; The rest that remains needs to be ignored
    $y 6F 00 00 00  # $ascii_other jal

:N ;ascii_num
    13 03 00 03     # rd_t1 !0x30 addi                  ; '0' -> 0
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    $r 6F 00 00 00  # $hex_return jal                   ; return
:Z ;ascii_low
    13 03 70 05     # rd_t1 !0x57 addi                  ; 'a' -> 0xA
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    $r 6F 00 00 00  # $hex_return jal                   ; return
:z ;ascii_high
    13 03 70 03     # rd_t1 !0x37 addi                  ; 'A' -> 0xA
    33 08 65 40     # rd_a6 rs1_a0 rs2_t1 sub
    $r 6F 00 00 00 # $hex_return jal                    ; return
:y ;ascii_other
    13 08 F0 FF     # rd_a6 !-1 addi                    ; Return -1
    $r 6F 00 00 00  # $hex_return jal                   ; return
:x ;ascii_comment                        ; Read the comment until newline
    $R EF 00 00 00  # rd_ra $Read_byte jal
    13 03 D0 00     # rd_t1 !0xd addi                   ; CR
    @E 63 00 65 00  # rs1_a0 rs2_t1 @ascii_comment_cr beq
    13 03 A0 00     # rd_t1 !0xa addi                   ; LF
    @x 63 10 65 00  # rs1_a0 rs2_t1 @ascii_comment bne  ; Keep reading comment
:E ;ascii_comment_cr
    13 08 F0 FF     # rd_a6 !-1 addi                    ; Return -1
:r ;hex_return
    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    83 35 81 00     # rd_a1 rs1_sp !8 ld                ; restore a1
    13 01 01 01     # rd_sp rs1_sp !16 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Read byte into a0
:R ;Read_byte
    13 01 81 FE     # rd_sp rs1_sp !-24 addi            ; Allocate stack
    23 34 B1 00     # rs1_sp rs2_a1 @8 sd               ; protect a1
    23 38 C1 00     # rs1_sp rs2_a2 @16 sd              ; protect a2

    93 08 F0 03     # rd_a7 !63 addi                    ; sys_read
    13 05 09 00     # rd_a0 rs1_s2 mv                   ; File descriptor
    93 05 01 00     # rd_a1 rs1_sp mv                   ; Get stack address for buffer
    13 06 10 00     # rd_a2 !1 addi                     ; Size of what we want to read
    73 00 00 00     # ecall                             ; syscall

    @K 63 00 05 00  # rs1_a0 @Read_byte_1 beqz          ; Deal with EOF
    03 C5 05 00     # rd_a0 rs1_a1 lbu                  ; return char in a0

    $M 6F 00 00 00  # $Read_byte_done jal               ; return

:K ;Read_byte_1
    13 05 C0 FF     # rd_a0 !-4 addi                    ; Put EOF in a0
:M ;Read_byte_done
    83 35 81 00     # rd_a1 rs1_sp !8 ld                ; restore a1
    03 36 01 01     # rd_a2 rs1_sp !16 ld               ; restore a2
    13 01 81 01     # rd_sp rs1_sp !24 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

; Find a label matching pointer in scratch
; Returns a pointer in a0
:G ;GetTarget
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

    93 82 04 00     # rd_t0 rs1_s1 mv                   ; grab jump_table

:O ;GetTarget_loop_0
    ; Compare the strings
    ~s 17 03 00 00  # rd_t1 ~scratch auipc
    !s 13 03 03 00  # rd_t1 rs1_t1 !scratch addi        ; reset scratch
    83 B3 02 01     # rd_t2 rs1_t0 !16 ld               ; I->name
:Q ;GetTarget_loop
    83 CE 03 00     # rd_t4 rs1_t2 lbu                  ; I->name[i]
    03 4E 03 00     # rd_t3 rs1_t1 lbu                  ; scratch[i]
    @v 63 10 DE 01  # rs1_t3 rs2_t4 @GetTarget_miss bne ; strings don't match

    ; Look at the next char
    13 03 13 00     # rd_t1 rs1_t1 !1 addi
    93 83 13 00     # rd_t2 rs1_t2 !1 addi
    @Q 63 90 0E 00  # rs1_t4 @GetTarget_loop bnez       ; Loop until zero (end of string)
    $V 6F 00 00 00  # $GetTarget_done jal   ; We have a match

:v ;GetTarget_miss
    83 B2 02 00     # rd_t0 rs1_t0 ld                   ; I = I->next
    @F 63 80 02 00  # rs1_t0 @Fail beqz                 ; Abort, no match found

    $O 6F 00 00 00  # $GetTarget_loop_0 jal             ; Try another label

:V ;GetTarget_done
    13 85 82 00     # rd_a0 rs1_t0 !8 addi              ; Get target address

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

:L ;StoreLabel
    13 01 81 FF     # rd_sp rs1_sp !-8 addi             ; Allocate stack
    23 30 11 00     # rs1_sp rs2_ra sd                  ; protect ra

    13 85 0C 00     # rd_a0 rs1_s9 mv                   ; struct entry
    93 8C 8C 01     # rd_s9 rs1_s9 !24 addi             ; calloc
    23 34 65 01     # rs1_a0 rs2_s6 @8 sd               ; entry->target = ip
    23 30 95 00     # rs1_a0 rs2_s1 sd                  ; entry->next = jump_table
    93 04 05 00     # rd_s1 rs1_a0 mv                   ; jump_table = entry
    23 38 95 01     # rs1_a0 rs2_s9 @16 sd              ; entry->name = token
    93 85 0C 00     # rd_a1 rs1_s9 mv                   ; Write after struct
    $c EF 00 00 00  # rd_ra $consume_token jal          ; Collect string
    93 8C 05 00     # rd_s9 rs1_a1 mv                   ; update HEAP

    83 30 01 00     # rd_ra rs1_sp ld                   ; restore ra
    13 01 81 00     # rd_sp rs1_sp !8 addi              ; deallocate stack
    $1 6F 00 00 00  # $First_pass_loop jal              ; return

; fputc function
; Receives CHAR in a0
; Writes and returns number of bytes written in a0
:t ;fputc
    13 01 01 FE     # rd_sp rs1_sp !-32 addi            ; allocate stack
    23 30 A1 00     # rs1_sp rs2_a0 sd                  ; protect a0
    23 34 11 00     # rs1_sp rs2_ra @8 sd               ; protect ra
    23 38 B1 00     # rs1_sp rs2_a1 @16 sd              ; protect a1
    23 3C C1 00     # rs1_sp rs2_a2 @24 sd              ; protect a2

    93 08 00 04     # rd_a7 !64 addi                    ; sys_write
    13 85 09 00     # rd_a0 rs1_s3 mv                   ; write to output
    93 05 01 00     # rd_a1 rs1_sp mv                   ; Get stack address
    13 06 10 00     # rd_a2 !1 addi                     ; write 1 character
    73 00 00 00     # ecall                             ; syscall

    83 30 81 00     # rd_ra rs1_sp !8 ld                ; restore ra
    83 35 01 01     # rd_a1 rs1_sp !16 ld               ; restore a1
    03 36 81 01     # rd_a2 rs1_sp !24 ld               ; restore a2
    13 01 01 02     # rd_sp rs1_sp !32 addi             ; Deallocate stack
    67 80 00 00     # rs1_ra jalr                       ; return

:F ;Fail
    ; Terminate program with 1 return code
    93 08 D0 05     # rd_a7 !93 addi                    ; sys_exit
    13 05 10 00     # rd_a0 !1 addi                     ; Return code 1
    73 00 00 00     # ecall                             ; exit(1)
# PROGRAM END

:s ;scratch
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

#:ELF_end
 src M0.hex2
## Copyright (C) 2017 Jeremiah Orians
## Copyright (C) 2021 Andrius Štikonas
## Copyright (C) 2021 Gabriel Wicki
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function

; Register use:
; s1: malloc pointer
; s2: input fd
; s3: output fd
; s4: struct HEAD
; s5: protected char
; s6: scratch

; Struct format: (size 32)
; NEXT => 0                           ; Next element in linked list
; TYPE => 8                           ; Token type
; TEXT => 16
; EXPRESSION => 24

; Types
; None => 0
; MACRO => 1
; STRING => 2

:_start
    # rd_s4 addi
    .000A0000 13000000

    # rd_a2 rs1_sp !16 ld               ; Input file name
    .00060000 .00000100 .00000001 03300000

    ; Open input file and store FD in s2
    # rd_a7 !56 addi                    ; sys_openat
    .80080000 .00008003 13000000
    # rd_a0 !-100 addi                  ; AT_FDCWD
    .00050000 .0000C0F9 13000000
    # rd_a1 rs1_a2 mv                   ; file name
    .80050000 .00000600 13000000
    # rd_a2 addi                        ; read only
    .00060000 13000000
    # ecall                             ; syscall
    73000000
    # rs1_a0 @Fail bltz                 ; Error opening file
    .00000500 @Fail 63400000
    # rd_s2 rs1_a0 mv                   ; Save fd in for later
    .00090000 .00000500 13000000

    ; Set default FD for output file to stdout
    # rd_s3 !1 addi
    .80090000 .00001000 13000000

    ; If we only have 2 arguments, don't use the third (it's not set)
    # rd_t0 !2 addi
    .80020000 .00002000 13000000
    # rd_a0 rs1_sp ld                   ; Get number of the args
    .00050000 .00000100 03300000
    # rs1_a0 rs2_t0 @Fail blt           ; No input file provided
    .00000500 .00005000 @Fail 63400000
    # rs1_a0 rs2_t0 @after_open beq     ; No output file provided. Use stdout
    .00000500 .00005000 @after_open 63000000

    ; Open output file and store the FD in s3
    # rd_a7 !56 addi                    ; sys_openat
    .80080000 .00008003 13000000
    # rd_a0 !-100 addi                  ; AT_FDCWD
    .00050000 .0000C0F9 13000000
    # rd_a1 rs1_sp !24 ld               ; Output file (argument 3)
    .80050000 .00000100 .00008001 03300000
    # rd_a2 !577 addi                   ; octal 00001101
    .00060000 .00001024 13000000
    ; O_TRUNC   00001000
    ; O_CREAT   00000100
    ; O_WRONLY  00000001
    ; OCTAL!
    # rd_a3 !384 addi                   ; Set read and write permission on user
    .80060000 .00000018 13000000
    # ecall                             ; syscall
    73000000
    # rd_s3 rs1_a0 mv                   ; Save fd in for later
    .80090000 .00000500 13000000

:after_open
    ; Prepare heap memory
    # rd_a7 !214 addi                   ; sys_brk
    .80080000 .0000600D 13000000
    # rd_a0 addi                        ; Get current brk
    .00050000 13000000
    # ecall                             ; syscall
    73000000
    # rd_s1 rs1_a0 mv                   ; Set our malloc pointer
    .80040000 .00000500 13000000

    # rd_a0 !512 addi                   ; Allocate scratch
    .00050000 .00000020 13000000
    # rd_ra $malloc jal                 ; Get S pointer
    .80000000 $malloc 6F000000
    # rd_s6 rs1_a0 mv                   ; Save scratch pointer
    .000B0000 .00000500 13000000

    # rd_ra $Tokenize_Line jal          ; Get all lines
    .80000000 $Tokenize_Line 6F000000
    # rd_a0 rs1_s4 mv                   ; Prepare for Reverse_List
    .00050000 .00000A00 13000000
    # rd_ra $Reverse_List jal           ; Correct order
    .80000000 $Reverse_List 6F000000
    # rd_s4 rs1_a0 mv                   ; Update HEAD
    .000A0000 .00000500 13000000
    # rd_ra $Identify_Macros jal        ; Find the DEFINEs
    .80000000 $Identify_Macros 6F000000
    # rd_ra $Line_Macro jal             ; Apply the DEFINEs
    .80000000 $Line_Macro 6F000000
    # rd_ra $Process_String jal         ; Handle strings
    .80000000 $Process_String 6F000000
    # rd_ra $Eval_Immediates jal        ; Handle numbers
    .80000000 $Eval_Immediates 6F000000
    # rd_ra $Preserve_Other jal         ; Collect the remaining
    .80000000 $Preserve_Other 6F000000
    # rd_ra $Print_Hex jal              ; Output our results
    .80000000 $Print_Hex 6F000000

    ; Terminate program with 0 return code
    # rd_a7 !93 addi                    ; sys_exit
    .80080000 .0000D005 13000000
    # rd_a0 mv                          ; Return code 0
    .00050000 13000000
    # ecall                             ; exit(0)
    73000000


; Tokenize_Line Function
; Using input file s2 and Head s4
; Creates a linked list of structs
; Uses a1 for in_set strings, a2 for Int C and a3 for Struct Token* p
:Tokenize_Line
    # rd_sp rs1_sp !-8 addi             ; allocate stack
    .00010000 .00000100 .000080FF 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000

:restart
    # rd_ra $fgetc jal                  ; Read a char
    .80000000 $fgetc 6F000000
    # rd_t0 !-4 addi                    ; EOF
    .80020000 .0000C0FF 13000000
    # rs1_a0 rs2_t0 @done beq           ; File is collected
    .00000500 .00005000 @done 63000000

    # rd_a2 rs1_a0 mv                   ; Protect C
    .00060000 .00000500 13000000

    # rd_a1 ~comments auipc             ; Get pointer to "#;"
    .80050000 ~comments 17000000
    # rd_a1 rs1_a1 !comments addi       ; Get pointer to "#;"
    .80050000 .00800500 !comments 13000000
    # rd_ra $In_Set jal                 ; Check for comments
    .80000000 $In_Set 6F000000
    # rd_t0 !1 addi                     ; If comment
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @Purge_LineComment beq ; try again
    .00000500 .00005000 @Purge_LineComment 63000000

    # rd_a0 rs1_a2 mv                   ; Put C in place for check
    .00050000 .00000600 13000000
    # rd_a1 ~terminators auipc          ; Get pointer to "\n\t "
    .80050000 ~terminators 17000000
    # rd_a1 rs1_a1 !terminators addi    ; Get pointer to "\n\t "
    .80050000 .00800500 !terminators 13000000
    # rd_ra $In_Set jal                 ; Check for terminators
    .80000000 $In_Set 6F000000
    # rd_t0 !1 addi                     ; If terminator
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @restart beq        ; try again
    .00000500 .00005000 @restart 63000000

    # rd_a0 !32 addi                    ; malloc struct P
    .00050000 .00000002 13000000
    # rd_ra $malloc jal                 ; Get pointer to P
    .80000000 $malloc 6F000000
    # rd_a3 rs1_a0 mv                   ; Protect P
    .80060000 .00000500 13000000
    # rs1_a3 rs2_s4 sd                  ; P->NEXT = HEAD
    .00800600 .00004001 23300000
    # rd_s4 rs1_a3 mv                   ; HEAD = P
    .000A0000 .00800600 13000000

    # rd_a0 rs1_a2 mv                   ; Put C in place for check
    .00050000 .00000600 13000000
    # rd_a1 ~string_char auipc          ; Get pointer to "\"'"
    .80050000 ~string_char 17000000
    # rd_a1 rs1_a1 !string_char addi    ; Get pointer to "\"'"
    .80050000 .00800500 !string_char 13000000
    # rd_ra $In_Set jal                 ; Check for string char
    .80000000 $In_Set 6F000000
    # rd_t0 !1 addi                     ; If string char
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @Store_String beq   ; Get string
    .00000500 .00005000 @Store_String 63000000

    # rd_ra $Store_Atom jal             ; Get whole token
    .80000000 $Store_Atom 6F000000
    # $restart jal
    $restart 6F000000

:done
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_sp rs1_sp !8 addi              ; deallocate stack
    .00010000 .00000100 .00008000 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; In_Set function
; Receives char C in a0 and Char* in a1
; Returns 1 if true, zero if false in a0
:In_Set
    # rd_sp rs1_sp !-8 addi             ; allocate stack
    .00010000 .00000100 .000080FF 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000

:In_Set_loop
    # rd_t0 rs1_a1 lbu                  ; Read char
    .80020000 .00800500 03400000
    # rs1_a0 rs2_t0 @In_Set_True beq    ; Return true
    .00000500 .00005000 @In_Set_True 63000000
    # rs1_t0 @In_Set_False beqz         ; Return False if NULL
    .00800200 @In_Set_False 63000000
    # rd_a1 rs1_a1 !1 addi              ; s = s + 1
    .80050000 .00800500 .00001000 13000000
    # $In_Set_loop jal                  ; Continue looping
    $In_Set_loop 6F000000

:In_Set_True
    # rd_a0 !1 addi                     ; Set True
    .00050000 .00001000 13000000
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_sp rs1_sp !8 addi              ; deallocate stack
    .00010000 .00000100 .00008000 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000

:In_Set_False
    # rd_a0 mv                          ; Set False
    .00050000 13000000
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_sp rs1_sp !8 addi              ; deallocate stack
    .00010000 .00000100 .00008000 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Purge_LineComment function
; Reads chars until LF and jumps to restart
:Purge_LineComment
    # rd_ra $fgetc jal                  ; Get a char
    .80000000 $fgetc 6F000000
    # rd_t0 !10 addi                    ; While not LF
    .80020000 .0000A000 13000000
    # rs1_a0 rs2_t0 @Purge_LineComment bne ; Keep reading
    .00000500 .00005000 @Purge_LineComment 63100000
    # $restart jal
    $restart 6F000000


; Store_String Function
; Receives C in a2, HEAD in a3 and Input file in s2
; Uses a1 for terminator, a2 for C and a3 for string
:Store_String
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000
    # rs1_sp rs2_a3 @16 sd              ; protect a3
    .00000100 .0000D000 .00080000 23300000

    # rd_a0 !2 addi                     ; Using TYPE STRING
    .00050000 .00002000 13000000
    # rs1_a3 rs2_a0 @8 sd               ; HEAD->TYPE = STRING
    .00800600 .0000A000 .00040000 23300000
    # rd_a1 rs1_a2 mv                   ; Protect terminator
    .80050000 .00000600 13000000
    # rd_a3 rs1_s6 mv                   ; Protect string pointer
    .80060000 .00000B00 13000000
:Store_String_Loop
    # rs1_a3 rs2_a2 sb                  ; write byte
    .00800600 .0000C000 23000000
    # rd_ra $fgetc jal                  ; read next char
    .80000000 $fgetc 6F000000
    # rd_a2 rs1_a0 mv                   ; Update C
    .00060000 .00000500 13000000
    # rd_a3 rs1_a3 !1 addi              ; STRING = STRING + 1
    .80060000 .00800600 .00001000 13000000
    # rs1_a1 rs2_a2 @Store_String_Loop bne ; Keep looping unless we hit terminator
    .00800500 .0000C000 @Store_String_Loop 63100000

    # rd_a0 rs1_s6 mv                   ; Prepare the string in scratch
    .00050000 .00000B00 13000000
    # rd_ra $string_length jal          ; Calculate length
    .80000000 $string_length 6F000000
    # rd_a0 rs1_a0 !1 addi              ; Add 1 for 0 terminator
    .00050000 .00000500 .00001000 13000000
    # rd_ra $malloc jal                 ; Allocate memory
    .80000000 $malloc 6F000000
    # rd_a3 rs1_sp !16 ld               ; restore a3 (HEAD)
    .80060000 .00000100 .00000001 03300000
    # rs1_a3 rs2_a0 @16 sd              ; HEAD->TEXT = STRING
    .00800600 .0000A000 .00080000 23300000
    # rd_ra $copy_string jal            ; Copy the string
    .80000000 $copy_string 6F000000

    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # $restart jal
    $restart 6F000000

; copy_string function
; Receives target in a0, and scratch s6 for source
; Uses a0, for target string T, a1 for C, a2 for source string S
; Returns nothing
:copy_string
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000
    # rs1_sp rs2_a2 @16 sd              ; protect a2
    .00000100 .0000C000 .00080000 23300000

    # rd_a2 rs1_s6 mv                   ; Get S
    .00060000 .00000B00 13000000

:copy_string_loop
    # rd_a1 rs1_a2 lbu                  ; S[0]
    .80050000 .00000600 03400000
    # rs1_a1 @copy_string_done beqz     ; Check if we are done
    .00800500 @copy_string_done 63000000

    # rs1_a0 rs2_a1 sb                  ; Copy char
    .00000500 .0000B000 23000000
    # rd_a2 rs1_a2 !1 addi              ; S = S + 1
    .00060000 .00000600 .00001000 13000000
    # rd_a0 rs1_a0 !1 addi              ; T = T + 1
    .00050000 .00000500 .00001000 13000000
    # $copy_string_loop jal             ; Keep going
    $copy_string_loop 6F000000

:copy_string_done
    # rd_ra $ClearScratch jal           ; Clear scratch
    .80000000 $ClearScratch 6F000000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_a2 rs1_sp !16 ld               ; restore a2
    .00060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # ret
    67800000


; Zero scratch area
:ClearScratch
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000

    # rd_a0 rs1_s6 mv                   ; Prepare scratch
    .00050000 .00000B00 13000000

:ClearScratch_loop
    # rd_a1 rs1_a0 lb                   ; Read current byte: s[i]
    .80050000 .00000500 03000000
    # rs1_a0 sb                         ; Write zero: s[i] = 0
    .00000500 23000000
    # rd_a0 rs1_a0 !1 addi              ; Increment: i = i + 1
    .00050000 .00000500 .00001000 13000000
    # rs1_a1 @ClearScratch_loop bnez    ; Keep looping
    .00800500 @ClearScratch_loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # ret
    67800000


; Store_Atom Function
; Receives C in a2, HEAD in a3 and Input file in s2
; Uses a1 for in_set strings, a2 for C and a3 for string
:Store_Atom
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000
    # rs1_sp rs2_a2 @16 sd              ; protect a2
    .00000100 .0000C000 .00080000 23300000
    # rs1_sp rs2_a3 @24 sd              ; protect a3
    .00000100 .0000D000 .000C0000 23300000

    # rd_a1 ~terminators auipc          ; Get pointer to "\n\t "
    .80050000 ~terminators 17000000
    # rd_a1 rs1_a1 !terminators addi    ; Get pointer to "\n\t "
    .80050000 .00800500 !terminators 13000000
    # rd_a3 rs1_s6 mv                   ; Protect string pointer
    .80060000 .00000B00 13000000

:Store_Atom_loop
    # rs1_a3 rs2_a2 sb                  ; write byte
    .00800600 .0000C000 23000000
    # rd_ra $fgetc jal                  ; read next char
    .80000000 $fgetc 6F000000
    # rd_a2 rs1_a0 mv                   ; Update C
    .00060000 .00000500 13000000
    # rd_a3 rs1_a3 !1 addi              ; STRING = STRING + 1
    .80060000 .00800600 .00001000 13000000
    # rd_ra $In_Set jal                 ; Check for terminators
    .80000000 $In_Set 6F000000
    # rs1_a0 @Store_Atom_loop beqz      ; Loop if not "\n\t "
    .00000500 @Store_Atom_loop 63000000

    # rd_a0 rs1_s6 mv                   ; Prepare the string in scratch
    .00050000 .00000B00 13000000
    # rd_ra $string_length jal          ; Calculate length
    .80000000 $string_length 6F000000
    # rd_a0 rs1_a0 !1 addi              ; Add 1 for 0 terminator
    .00050000 .00000500 .00001000 13000000
    # rd_ra $malloc jal                 ; Allocate memory
    .80000000 $malloc 6F000000
    # rd_a3 rs1_sp !24 ld               ; restore a3
    .80060000 .00000100 .00008001 03300000
    # rs1_a3 rs2_a0 @16 sd              ; HEAD->TEXT = STRING
    .00800600 .0000A000 .00080000 23300000
    # rd_ra $copy_string jal            ; Copy the string
    .80000000 $copy_string 6F000000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_a2 rs1_sp !16 ld               ; restore a2
    .00060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Reverse_List function
; Receives list in a0
; Returns the list reversed in a0
:Reverse_List
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000
    # rd_a1 rs1_a0 mv                   ; Set HEAD
    .80050000 .00000500 13000000
    # rd_a0 mv                          ; ROOT = NULL
    .00050000 13000000
:Reverse_List_Loop
    # rs1_a1 @Reverse_List_Done beqz    ; Stop if HEAD == NULL
    .00800500 @Reverse_List_Done 63000000

    # rd_a2 rs1_a1 ld                   ; NEXT = HEAD->NEXT
    .00060000 .00800500 03300000
    # rs1_a1 rs2_a0 sd                  ; HEAD->NEXT = ROOT
    .00800500 .0000A000 23300000
    # rd_a0 rs1_a1 mv                   ; ROOT = HEAD
    .00050000 .00800500 13000000
    # rd_a1 rs1_a2 mv                   ; HEAD = NEXT
    .80050000 .00000600 13000000
    # $Reverse_List_Loop jal            ; Continue looping
    $Reverse_List_Loop 6F000000

:Reverse_List_Done
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Identify_Macros function
; Receives List in a0
; Updates the list in place; does not modify registers
; Uses a1 for DEFINE, a2 for I
:Identify_Macros
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000

    # rd_a1 ~DEFINE_str auipc           ; Setup DEFINE string
    .80050000 ~DEFINE_str 17000000
    # rd_a1 rs1_a1 !DEFINE_str addi     ; Setup DEFINE string
    .80050000 .00800500 !DEFINE_str 13000000
    # rd_a2 rs1_a0 mv                   ; I = HEAD
    .00060000 .00000500 13000000

:Identify_Macros_Loop
    # rd_a0 rs1_a2 !16 ld               ; I->TEXT
    .00050000 .00000600 .00000001 03300000
    # rd_ra $match jal                  ; IF "DEFINE" == I->TEXT
    .80000000 $match 6F000000
    # rs1_a0 @Identify_Macros_Next bnez ; Check if we got macro
    .00000500 @Identify_Macros_Next 63100000

    ; Deal with MACRO
    # rd_a0 !1 addi                     ; a0 = MACRO
    .00050000 .00001000 13000000
    # rs1_a2 rs2_a0 @8 sd               ; I->TYPE = MACRO
    .00000600 .0000A000 .00040000 23300000

    # rd_a0 rs1_a2 ld                   ; I->NEXT
    .00050000 .00000600 03300000
    # rd_a0 rs1_a0 !16 ld               ; I->NEXT->TEXT
    .00050000 .00000500 .00000001 03300000
    # rs1_a2 rs2_a0 @16 sd              ; I->TEXT = I->NEXT->TEXT
    .00000600 .0000A000 .00080000 23300000

    # rd_a0 rs1_a2 ld                   ; I->NEXT
    .00050000 .00000600 03300000
    # rd_a0 rs1_a0 ld                   ; I->NEXT->NEXT
    .00050000 .00000500 03300000
    # rd_a0 rs1_a0 !16 ld               ; I->NEXT->NEXT->TEXT
    .00050000 .00000500 .00000001 03300000
    # rs1_a2 rs2_a0 @24 sd              ; I->EXPRESSION = I->NEXT->NEXT->TEXT
    .00000600 .0000A000 .000C0000 23300000

    # rd_a0 rs1_a2 ld                   ; I->NEXT
    .00050000 .00000600 03300000
    # rd_a0 rs1_a0 ld                   ; I->NEXT->NEXT
    .00050000 .00000500 03300000
    # rd_a0 rs1_a0 ld                   ; I->NEXT->NEXT->NEXT
    .00050000 .00000500 03300000
    # rs1_a2 rs2_a0 sd                  ; I->NEXT = I->NEXT->NEXT->NEXT
    .00000600 .0000A000 23300000

:Identify_Macros_Next
    # rd_a2 rs1_a2 ld                   ; I = I->NEXT
    .00060000 .00000600 03300000
    # rs1_a2 @Identify_Macros_Loop bnez ; Check if we are done
    .00000600 @Identify_Macros_Loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; match function
; Receives CHAR* in a0 and CHAR* in a1
; Returns 0 (TRUE) or 1 (FALSE) in a0
:match
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000
    # rs1_sp rs2_a3 @16 sd              ; protect a3
    .00000100 .0000D000 .00080000 23300000

    # rd_a2 rs1_a0 mv                   ; S1 in place
    .00060000 .00000500 13000000
    # rd_a3 rs1_a1 mv                   ; S2 in place
    .80060000 .00800500 13000000

:match_Loop
    # rd_a0 rs1_a2 lbu                  ; S1[i]
    .00050000 .00000600 03400000
    # rd_a1 rs1_a3 lbu                  ; S2[i]
    .80050000 .00800600 03400000
    # rs1_a0 rs2_a1 @match_False bne    ; Check if they match
    .00000500 .0000B000 @match_False 63100000

    # rd_a2 rs1_a2 !1 addi              ; S1 = S1 + 1
    .00060000 .00000600 .00001000 13000000
    # rd_a3 rs1_a3 !1 addi              ; S2 = S2 + 1
    .80060000 .00800600 .00001000 13000000
    # rs1_a0 @match_Done beqz           ; Match if we reached end of string
    .00000500 @match_Done 63000000
    # $match_Loop jal                   ; Otherwise keep looping
    $match_Loop 6F000000

:match_False
    # rd_a0 !1 addi                     ; Return false
    .00050000 .00001000 13000000
:match_Done
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_a3 rs1_sp !16 ld               ; restore a3
    .80060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Line_Macro function
; Receives List in a0
; Updates the list in place; does not modify registers
; Uses a0 for I, a1 for I->TEXT, a2 for I->EXPRESSION
:Line_Macro
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000

:Line_Macro_Loop
    # rd_a1 rs1_a0 !8 ld                ; I->TYPE
    .80050000 .00000500 .00008000 03300000
    # rd_t0 !1 addi                     ; t0 = MACRO
    .80020000 .00001000 13000000
    # rs1_a1 rs2_t0 @Line_Macro_Next bne ; Move on unless I->TYPE == MACRO
    .00800500 .00005000 @Line_Macro_Next 63100000

    ; Apply macro
    # rd_a1 rs1_a0 !16 ld               ; I->TEXT
    .80050000 .00000500 .00000001 03300000
    # rd_a2 rs1_a0 !24 ld               ; I->EXPRESSION
    .00060000 .00000500 .00008001 03300000
    # rd_a0 rs1_a0 ld                   ; I->NEXT
    .00050000 .00000500 03300000
    # rd_ra $Set_Expression jal         ; Apply it
    .80000000 $Set_Expression 6F000000
    # $Line_Macro_Loop jal              ; Move on to next
    $Line_Macro_Loop 6F000000

:Line_Macro_Next
    # rd_a0 rs1_a0 ld                   ; I->NEXT
    .00050000 .00000500 03300000
    # rs1_a0 @Line_Macro_Loop bnez      ; Check if we are done
    .00000500 @Line_Macro_Loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Set_Expression function
; Receives List in a0, CHAR* in a1 and CHAR* in a2
; Updates the list in place; does not modify registers
; Uses a1 for C, a2 for EXP and a3 for I
:Set_Expression
    # rd_sp rs1_sp !-40 addi            ; allocate stack
    .00010000 .00000100 .000080FD 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000
    # rs1_sp rs2_a3 @32 sd              ; protect a3
    .00000100 .0000D000 .00000002 23300000

    # rd_a3 rs1_a0 mv                   ; Set I
    .80060000 .00000500 13000000
:Set_Expression_Loop
    # rd_a0 rs1_a3 !8 ld                ; I->TYPE
    .00050000 .00800600 .00008000 03300000
    # rd_t0 !1 addi                     ; t0 = MACRO
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @Set_Expression_Next beq ; If MACRO == I->Type then ignore and move on
    .00000500 .00005000 @Set_Expression_Next 63000000

    # rd_a0 rs1_a3 !16 ld               ; I->TEXT
    .00050000 .00800600 .00000001 03300000
    # rd_ra $match jal                  ; Check for match
    .80000000 $match 6F000000
    # rs1_a0 @Set_Expression_Next bnez  ; Check next if does not match
    .00000500 @Set_Expression_Next 63100000

    ; Non-macro match
    # rs1_a3 rs2_a2 @24 sd              ; I->EXPRESSION = EXP
    .00800600 .0000C000 .000C0000 23300000

:Set_Expression_Next
    # rd_a3 rs1_a3 ld                   ; I = I->NEXT
    .80060000 .00800600 03300000
    # rs1_a3 @Set_Expression_Loop bnez  ; Check if we are done
    .00800600 @Set_Expression_Loop 63100000
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_a3 rs1_sp !32 ld               ; restore a3
    .80060000 .00000100 .00000002 03300000
    # rd_sp rs1_sp !40 addi             ; deallocate stack
    .00010000 .00000100 .00008002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Process_String function
; Receives List in a0
; Update the list in place; does not modify registers
; Uses a1 for I->TEXT, a2 for I and RDX for S
:Process_String
    # rd_sp rs1_sp !-40 addi            ; allocate stack
    .00010000 .00000100 .000080FD 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000
    # rs1_sp rs2_a3 @32 sd              ; protect a3
    .00000100 .0000D000 .00000002 23300000

    # rd_a2 rs1_a0 mv                   ; I = HEAD
    .00060000 .00000500 13000000

:Process_String_loop
    # rd_a0 rs1_a2 !8 ld                ; I->TYPE
    .00050000 .00000600 .00008000 03300000
    # rd_t0 !2 addi                     ; t0 = STRING
    .80020000 .00002000 13000000
    # rs1_a0 rs2_t0 @Process_String_Next bne ; Skip to next
    .00000500 .00005000 @Process_String_Next 63100000

    # rd_a1 rs1_a2 !16 ld               ; I->TEXT
    .80050000 .00000600 .00000001 03300000
    # rd_a0 rs1_a1 lbu                  ; I->TEXT[0]
    .00050000 .00800500 03400000
    # rd_t0 !39 addi                    ; t0 = \'
    .80020000 .00007002 13000000
    # rs1_a0 rs2_t0 @Process_String_Raw bne ; Deal with '"'
    .00000500 .00005000 @Process_String_Raw 63100000

    ; Deal with \'
    # rd_a1 rs1_a1 !1 addi              ; I->TEXT + 1
    .80050000 .00800500 .00001000 13000000
    # rs1_a2 rs2_a1 @24 sd              ; I->EXPRESSION = I->TEXT + 1
    .00000600 .0000B000 .000C0000 23300000
    # $Process_String_Next jal          ; Move on to next
    $Process_String_Next 6F000000

:Process_String_Raw
    # rd_a0 rs1_a1 mv                   ; I->TEXT
    .00050000 .00800500 13000000
    # rd_ra $string_length jal          ; Get length of I->TEXT
    .80000000 $string_length 6F000000
    # rd_a0 rs1_a0 rs2_x2 srli          ; LENGTH = LENGTH >> 2
    .00050000 .00000500 .00002000 13500000
    # rd_a0 rs1_a0 !1 addi              ; LENGTH = LENGTH + 1
    .00050000 .00000500 .00001000 13000000
    # rd_a0 rs1_a0 rs2_x3 slli          ; LENGTH = LENGTH << 3
    .00050000 .00000500 .00003000 13100000
    # rd_ra $malloc jal                 ; Get string
    .80000000 $malloc 6F000000
    # rd_a3 rs1_a1 mv                   ; S = I->TEXT
    .80060000 .00800500 13000000
    # rd_a3 rs1_a3 !1 addi              ; S = S + 1
    .80060000 .00800600 .00001000 13000000
    # rs1_a2 rs2_a0 @24 sd              ; I->EXPRESSION = hexify
    .00000600 .0000A000 .000C0000 23300000
    # rd_a1 rs1_a0 mv                   ; Put hexify buffer in a1
    .80050000 .00000500 13000000

:Process_String_Raw_Loop
    # rd_a0 rs1_a3 lbu                  ; Read 1 character
    .00050000 .00800600 03400000
    # rd_a3 rs1_a3 !1 addi              ; S = S + 1
    .80060000 .00800600 .00001000 13000000
    # rd_s5 rs1_a0 mv                   ; Protect character
    .800A0000 .00000500 13000000
    # rd_ra $hex8 jal                   ; write them all
    .80000000 $hex8 6F000000
    # rd_a0 rs1_s5 mv                   ; Restore character
    .00050000 .00800A00 13000000
    # rs1_a0 @Process_String_Raw_Loop bnez ; Keep looping
    .00000500 @Process_String_Raw_Loop 63100000

:Process_String_Next
    # rd_a2 rs1_a2 ld                   ; I = I->NEXT
    .00060000 .00000600 03300000
    # rs1_a2 @Process_String_loop bnez  ; Check if we are done
    .00000600 @Process_String_loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_a3 rs1_sp !32 ld               ; restore a3
    .80060000 .00000100 .00000002 03300000
    # rd_sp rs1_sp !40 addi             ; deallocate stack
    .00010000 .00000100 .00008002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; string_length function
; Receives CHAR* in a0
; Returns INT in a0
; Uses a0 for CH, a1 for S and a2 for INDEX
:string_length
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000

    # rd_a1 rs1_a0 mv                   ; Set S
    .80050000 .00000500 13000000
    # rd_a2 mv                          ; INDEX = 0
    .00060000 13000000

:string_length_loop
    # rd_t0 rs1_a1 rs2_a2 add           ; S + INDEX
    .80020000 .00800500 .0000C000 33000000
    # rd_a0 rs1_t0 lbu                  ; S[INDEX]
    .00050000 .00800200 03400000
    # rs1_a0 @string_length_done beqz   ; Check if we are done
    .00000500 @string_length_done 63000000

    # rd_a2 rs1_a2 !1 addi              ; INDEX = INDEX + 1
    .00060000 .00000600 .00001000 13000000
    # $string_length_loop jal           ; Keep going
    $string_length_loop 6F000000

:string_length_done
    # rd_a0 rs1_a2 mv                   ; return INDEX
    .00050000 .00000600 13000000
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Eval_Immediates function
; Receives List in a0
; Updates the list in place; does not modify registers
; Uses a1 for I->TEXT[0], a2 for I->TEXT[1] and a3 for I
:Eval_Immediates
    # rd_sp rs1_sp !-40 addi            ; allocate stack
    .00010000 .00000100 .000080FD 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; protect a0
    .00000100 .0000A000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000
    # rs1_sp rs2_a3 @32 sd              ; protect a3
    .00000100 .0000D000 .00000002 23300000

    # rd_a3 rs1_a0 mv                   ; I = HEAD
    .80060000 .00000500 13000000

:Eval_Immediates_Loop
    ; Check for MACRO
    # rd_a0 rs1_a3 !8 ld                ; I->TYPE
    .00050000 .00800600 .00008000 03300000
    # rd_t0 !1 addi                     ; t0 = MACRO
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @Eval_Immediates_Next beq ; Skip to next if I->TYPE == MACRO
    .00000500 .00005000 @Eval_Immediates_Next 63000000

    ; Check for NULL EXPRESSION
    # rd_a0 rs1_a3 !24 ld               ; I->EXPRESSION
    .00050000 .00800600 .00008001 03300000
    # rs1_a0 @Eval_Immediates_Next bnez ; Skip to next if NULL == I->EXPRESSION
    .00000500 @Eval_Immediates_Next 63100000

    ; Check if number
    # rd_a0 rs1_a3 !16 ld               ; I->TEXT
    .00050000 .00800600 .00000001 03300000
    # rd_a1 rs1_a0 lbu                  ; I->TEXT[0]
    .80050000 .00000500 03400000
    # rd_a0 rs1_a0 !1 addi              ; I->TEXT + 1
    .00050000 .00000500 .00001000 13000000
    # rd_a2 rs1_a0 lbu                  ; I->TEXT[1]
    .00060000 .00000500 03400000
    # rd_ra $numerate_string jal        ; Convert string to INT
    .80000000 $numerate_string 6F000000
    # rs1_a0 @Eval_Immediates_value bnez ; Has a value IF 0 != numerate_string(I->TEXT + 1)
    .00000500 @Eval_Immediates_value 63100000

    ; Last chance for Immediate
    # rd_t0 !48 addi                    ; If '0' = I->TEXT[1]
    .80020000 .00000003 13000000
    # rs1_a2 rs2_t0 @Eval_Immediates_Next bne ; Skip to next
    .00000600 .00005000 @Eval_Immediates_Next 63100000

:Eval_Immediates_value
    # rd_ra $express_number jal         ; Convert value to hex string
    .80000000 $express_number 6F000000
    # rs1_a3 rs2_a0 @24 sd              ; I->EXPRESSION = express_number(value, I-TEXT[0])
    .00800600 .0000A000 .000C0000 23300000

:Eval_Immediates_Next
    # rd_a3 rs1_a3 ld                   ; I = I->NEXT
    .80060000 .00800600 03300000
    # rs1_a3 @Eval_Immediates_Loop bnez ; Check if we are done
    .00800600 @Eval_Immediates_Loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a0 rs1_sp !8 ld                ; restore a0
    .00050000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_a3 rs1_sp !32 ld               ; restore a3
    .80060000 .00000100 .00000002 03300000
    # rd_sp rs1_sp !40 addi             ; deallocate stack
    .00010000 .00000100 .00008002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; numerate_string function
; Receives CHAR* in a0
; Returns value of CHAR* in a0
; Uses a0 for VALUE, a1 for S, a2 for CH and a3 for NEGATIVE?
:numerate_string
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000
    # rs1_sp rs2_a3 @16 sd              ; protect a3
    .00000100 .0000D000 .00080000 23300000

    # rd_a1 rs1_a0 mv                   ; put S in correct place
    .80050000 .00000500 13000000
    # rd_a0 mv                          ; Initialize to Zero
    .00050000 13000000
:numerate_string_loop
    # rd_t0 rs1_a1 !1 addi              ; S + 1
    .80020000 .00800500 .00001000 13000000
    # rd_a2 rs1_t0 lbu                  ; S[1]
    .00060000 .00800200 03400000
    # rd_t0 !120 addi                   ; 'x'
    .80020000 .00008007 13000000
    # rs1_a2 rs2_t0 @numerate_hex beq   ; Deal with hex_input
    .00000600 .00005000 @numerate_hex 63000000

    ; Assume decimal input
    # rd_a3 mv                          ; Assume no negation
    .80060000 13000000
    # rd_a2 rs1_a1 lbu                  ; S[0]
    .00060000 .00800500 03400000
    # rd_t0 !45 addi                    ; '-'
    .80020000 .0000D002 13000000
    # rs1_a2 rs2_t0 @numerate_decimal bne ; Skip negation
    .00000600 .00005000 @numerate_decimal 63100000

    # rd_a3 !1 addi                     ; Set FLAG
    .80060000 .00001000 13000000
    # rd_a1 rs1_a1 !1 addi              ; S = S + 1
    .80050000 .00800500 .00001000 13000000

:numerate_decimal
    # rd_a2 rs1_a1 lbu                  ; S[i]
    .00060000 .00800500 03400000
    # rs1_a2 @numerate_decimal_done beqz ; We are done if NULL == S[i]
    .00000600 @numerate_decimal_done 63000000

    ; a0 = a0 * 10 = (a0 << 3) + (a0 << 1)
    # rd_t0 rs1_a0 rs2_x3 slli          ; a0 * 8
    .80020000 .00000500 .00003000 13100000
    # rd_t1 rs1_a0 rs2_x1 slli          ; a0 * 2
    .00030000 .00000500 .00001000 13100000
    # rd_a0 rs1_t0 rs2_t1 add           ; VALUE = VALUE * 10
    .00050000 .00800200 .00006000 33000000
    # rd_a2 rs1_a2 !-48 addi            ; CH = CH - '0'
    .00060000 .00000600 .000000FD 13000000
    # rd_t0 !9 addi                     ; t0 = 9
    .80020000 .00009000 13000000
    # rs1_t0 rs2_a2 @numerate_string_fail blt ; Check for illegal CH > 9
    .00800200 .0000C000 @numerate_string_fail 63400000
    # rs1_a2 @numerate_string_fail bltz ; Check for illegal CH < 0
    .00000600 @numerate_string_fail 63400000
    # rd_a0 rs1_a0 rs2_a2 add           ; VALUE = VALUE + CH
    .00050000 .00000500 .0000C000 33000000
    # rd_a1 rs1_a1 !1 addi              ; S = S + 1
    .80050000 .00800500 .00001000 13000000
    # $numerate_decimal jal
    $numerate_decimal 6F000000

:numerate_decimal_done
    # rd_t0 !1 addi                     ; Check for negative FLAG
    .80020000 .00001000 13000000
    # rs1_a3 rs2_t0 @numerate_string_done bne ; Nope
    .00800600 .00005000 @numerate_string_done 63100000

    # rd_a0 rs2_a0 sub                  ; VALUE = -VALUE
    .00050000 .0000A000 33000040
    # $numerate_string_done jal         ; Done
    $numerate_string_done 6F000000

:numerate_hex
    # rd_a1 rs1_a1 !2 addi              ; S = S + 2
    .80050000 .00800500 .00002000 13000000
:numerate_hex_loop
    # rd_a2 rs1_a1 lbu                  ; S[i]
    .00060000 .00800500 03400000
    # rs1_a2 @numerate_string_done beqz ; We are done if NULL == S[i]
    .00000600 @numerate_string_done 63000000

    # rd_a0 rs1_a0 rs2_x4 slli          ; VALUE = VALUE << 4
    .00050000 .00000500 .00004000 13100000
    # rd_a2 rs1_a2 !-48 addi            ; CH = CH - '0'
    .00060000 .00000600 .000000FD 13000000
    # rd_t0 !10 addi                    ; t0 = 10
    .80020000 .0000A000 13000000
    # rs1_a2 rs2_t0 @numerate_hex_digit blt ; Check if we are dealing with number or letter
    .00000600 .00005000 @numerate_hex_digit 63400000
    # rd_a2 rs1_a2 !-7 addi             ; Push A-F into range
    .00060000 .00000600 .000090FF 13000000

:numerate_hex_digit
    # rd_t0 !15 addi                    ; t0 = 15
    .80020000 .0000F000 13000000
    # rs1_t0 rs2_a2 @numerate_string_fail blt ; Check for CH > 'F'
    .00800200 .0000C000 @numerate_string_fail 63400000
    # rs1_a2 @numerate_string_fail bltz ; Check for CH < 0
    .00000600 @numerate_string_fail 63400000
    # rd_a0 rs1_a0 rs2_a2 add           ; VALUE = VALUE + CH
    .00050000 .00000500 .0000C000 33000000
    # rd_a1 rs1_a1 !1 addi              ; S = S + 1
    .80050000 .00800500 .00001000 13000000
    # $numerate_hex_loop jal            ; Keep looping
    $numerate_hex_loop 6F000000

:numerate_string_fail
    # rd_a0 mv                          ; return ZERO
    .00050000 13000000

:numerate_string_done
    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_a3 rs1_sp !16 ld               ; restore a3
    .80060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; express_number function
; Receives INT in a0 and CHAR in a1
; Allocates a string and expresses the value in appropriate RISC-V encoding
; Returns string in a0
; Uses a0 for VALUE, a1 for S and a2 for CH
:express_number
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000
    # rs1_sp rs2_a2 @16 sd              ; protect a2
    .00000100 .0000C000 .00080000 23300000
    # rs1_sp rs2_a3 @24 sd              ; protect a3
    .00000100 .0000D000 .000C0000 23300000

    # rd_a2 rs1_a1 mv                   ; Put CH in right place
    .00060000 .00800500 13000000
    # rd_s5 rs1_a0 mv                   ; Protect VALUE
    .800A0000 .00000500 13000000

    # rd_a0 !10 addi                    ; We need 10 bytes
    .00050000 .0000A000 13000000
    # rd_ra $malloc jal                 ; Get S pointer
    .80000000 $malloc 6F000000
    # rd_a1 rs1_a0 mv                   ; Put S in place
    .80050000 .00000500 13000000
    # rd_a0 rs1_s5 mv                   ; Restore VALUE
    .00050000 .00800A00 13000000

    ; Check for %
    # rd_t0 !0x25 addi
    .80020000 .00005002 13000000
    # rs1_a2 rs2_t0 @express_number_const beq
    .00000600 .00005000 @express_number_const 63000000

    # rd_s5 rs1_a1 mv                   ; Protect S
    .800A0000 .00800500 13000000
    # rd_t0 !0x2E addi                  ; t0 = '.'
    .80020000 .0000E002 13000000
    # rs1_a1 rs2_t0 sd                  ; S[0] = '.'
    .00800500 .00005000 23300000
    # rd_a1 rs1_a1 !1 addi              ; Next byte
    .80050000 .00800500 .00001000 13000000

    ; Check for !
    # rd_t0 !0x21 addi
    .80020000 .00001002 13000000
    # rs1_a2 rs2_t0 @express_number_I beq
    .00000600 .00005000 @express_number_I 63000000

    ; Check for @
    # rd_t0 !0x40 addi
    .80020000 .00000004 13000000
    # rs1_a2 rs2_t0 @express_number_S beq
    .00000600 .00005000 @express_number_S 63000000

    ; Check for ~
    # rd_t0 !0x7E addi
    .80020000 .0000E007 13000000
    # rs1_a2 rs2_t0 @express_number_U beq
    .00000600 .00005000 @express_number_U 63000000

    # $Fail jal                         ; Error
    $Fail 6F000000

:express_number_const
    ; provides an option for 32-bit immediate constants

    # rd_t0 !2 addi
    .80020000 .00002000 13000000
    # rd_t0 rs1_t0 rs2_x31 slli
    .80020000 .00800200 .0000F001 13100000
    # rd_t0 rs1_t0 !-1 addi             ; t0 = 0xffffffff
    .80020000 .00800200 .0000F0FF 13000000
    # rd_a0 rs1_a0 rs2_t0 and           ; immediate = value & 0xffffffff
    .00050000 .00000500 .00005000 33700000

    # rd_s5 rs1_a1 mv                   ; Protect S
    .800A0000 .00800500 13000000
    # rd_ra $hex32l jal                 ; Store 32-bits
    .80000000 $hex32l 6F000000
    # $express_number_done jal          ; done
    $express_number_done 6F000000

:express_number_I
    ; Corresponds to RISC-V S format
    ; (value & 0xfff) << 20
    # rd_t0 !0xFFF addi
    .80020000 .0000F0FF 13000000
    # rd_a0 rs1_a0 rs2_t0 and           ; value & 0xfff
    .00050000 .00000500 .00005000 33700000
    # rd_a0 rs1_a0 rs2_x20 slli         ; (value & 0xfff) << 20
    .00050000 .00000500 .00004001 13100000
    # rd_ra $hex32l jal                 ; Store 32-bits
    .80000000 $hex32l 6F000000
    # $express_number_done jal          ; done
    $express_number_done 6F000000

:express_number_S
    ; Corresponds to RISC-V S format
    ; ((value & 0x1f) << 7) | ((value & 0xfe0) << (31 - 11))
    # rd_t0 !0x1F addi
    .80020000 .0000F001 13000000
    # rd_t1 rs1_a0 rs2_t0 and           ; value & 0x1f
    .00030000 .00000500 .00005000 33700000
    # rd_t1 rs1_t1 rs2_x7 slli          ; (value & 0x1f) << 7
    .00030000 .00000300 .00007000 13100000
    # rd_t0 !0xFE0 addi
    .80020000 .000000FE 13000000
    # rd_t0 rs1_a0 rs2_t0 and           ; value & 0xfe0
    .80020000 .00000500 .00005000 33700000
    # rd_t0 rs1_t0 rs2_x20 slli         ; (value & 0xfe0) << (31 - 11)
    .80020000 .00800200 .00004001 13100000
    # rd_a0 rs1_t0 rs2_t1 or            ; Combine two parts
    .00050000 .00800200 .00006000 33600000
    # rd_ra $hex32l jal                 ; Store 32-bits
    .80000000 $hex32l 6F000000
    # $express_number_done jal          ; done
    $express_number_done 6F000000

:express_number_U
    ; Corresponds to RISC-V U format
    ; if value is 0x800 or more we have to add 11-th bit (0x1000) to compensate for signed extension

    # rd_t0 ~0x800 lui                  ; load higher bits
    .80020000 .00100000 37000000
    # rd_t0 rs1_t0 !0x800 addiw
    .80020000 .00800200 .00000080 1B000000
    # rd_t1 ~0xFFF lui                  ; load higher bits
    .00030000 .00100000 37000000
    # rd_t1 rs1_t1 !0xFFF addiw
    .00030000 .00000300 .0000F0FF 1B000000
    ; We are outside 31-bit that ~ can normally load
    # rd_t2 ~0x100000 lui               ; load 0xfffff000
    .80030000 .00001000 37000000
    # rd_t2 rs1_t2 !-1 addiw            ; load 0xfffff000
    .80030000 .00800300 .0000F0FF 1B000000
    # rd_t2 rs1_t2 rs2_x12 slli         ; load 0xfffff000
    .80030000 .00800300 .0000C000 13100000
    # rd_t1 rs1_a0 rs2_t1 and           ; value & 0xfff
    .00030000 .00000500 .00006000 33700000
    # rd_a0 rs1_a0 rs2_t2 and           ; value & 0xfffff000
    .00050000 .00000500 .00007000 33700000
    # rs1_t1 rs2_t0 @express_number_U_small blt
    .00000300 .00005000 @express_number_U_small 63400000

    ; Deal with sign extension: add 0x1000
    # rd_t0 ~0x1000 lui
    .80020000 .00100000 37000000
    # rd_a0 rs1_t0 rs2_a0 addw          ; (value & 0xfffff000) + 0x1000
    .00050000 .00800200 .0000A000 3B000000
:express_number_U_small
    # rd_ra $hex32l jal                 ; Store 32-bits
    .80000000 $hex32l 6F000000
    # $express_number_done jal          ; done
    $express_number_done 6F000000

:express_number_done
    # rd_a0 rs1_s5 mv                   ; Restore S
    .00050000 .00800A00 13000000
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_a2 rs1_sp !16 ld               ; restore a2
    .00060000 .00000100 .00000001 03300000
    # rd_a3 rs1_sp !24 ld               ; restore a3
    .80060000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; HEX to ascii routine
; Receives INT in a0 and CHAR* in a1
; Stores ascii of INT in CHAR*
; Returns only modifying a0
:hex32l
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_ra sd                  ; Protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; Protect top 16 bits
    .00000100 .0000A000 .00040000 23300000
    # rd_ra $hex16l jal                 ; Store it
    .80000000 $hex16l 6F000000
    # rd_a0 rs1_sp !8 ld                ; do high 16-bits
    .00050000 .00000100 .00008000 03300000
    # rd_a0 rs1_a0 rs2_x16 srli         ; do bottom 16 bits
    .00050000 .00000500 .00000001 13500000
    # rd_ra $hex16l jal                 ; Store it
    .80000000 $hex16l 6F000000
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000

:hex16l
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_ra sd                  ; Protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; Protect top byte
    .00000100 .0000A000 .00040000 23300000
    # rd_ra $hex8 jal                   ; Store it
    .80000000 $hex8 6F000000
    # rd_a0 rs1_sp !8 ld                ; do high byte
    .00050000 .00000100 .00008000 03300000
    # rd_a0 rs1_a0 rs2_x8 srli          ; do bottom byte
    .00050000 .00000500 .00008000 13500000
    # rd_ra $hex8 jal                   ; Store it
    .80000000 $hex8 6F000000
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000

:hex8
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_ra sd                  ; Protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a0 @8 sd               ; Protect bottom nibble
    .00000100 .0000A000 .00040000 23300000
    # rd_a0 rs1_a0 rs2_x4 srli          ; do high nibble first
    .00050000 .00000500 .00004000 13500000
    # rd_ra $hex4 jal                   ; Store it
    .80000000 $hex4 6F000000
    # rd_a0 rs1_sp !8 ld                ; do low nibble
    .00050000 .00000100 .00008000 03300000
    # rd_ra $hex4 jal                   ; Store it
    .80000000 $hex4 6F000000
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000

:hex4
    # rd_t0 !0xF addi
    .80020000 .0000F000 13000000
    # rd_a0 rs1_a0 rs2_t0 and           ; isolate nibble
    .00050000 .00000500 .00005000 33700000
    # rd_a0 rs1_a0 !0x30 addi           ; convert to ascii
    .00050000 .00000500 .00000003 13000000
    # rd_t0 !0x39 addi                  ; t0 = '9'
    .80020000 .00009003 13000000
    # rs1_t0 rs2_a0 @hex1 bge           ; check if valid digit
    .00800200 .0000A000 @hex1 63500000
    # rd_a0 rs1_a0 !7 addi              ; use alpha range
    .00050000 .00000500 .00007000 13000000
:hex1
    # rs1_a1 rs2_a0 sb                  ; store result
    .00800500 .0000A000 23000000
    # rd_a1 rs1_a1 !1 addi              ; next position
    .80050000 .00800500 .00001000 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Preserve_Other function
; Receives list in a0
; Update the list in place; does not modify registers
; Uses a0 for I, a1 for I->TEXT
:Preserve_Other
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_a1 sd                  ; protect a1
    .00000100 .0000B000 23300000
    # rs1_sp rs2_a2 @8 sd               ; protect a2
    .00000100 .0000C000 .00040000 23300000
    # rs1_sp rs2_a3 @16 sd              ; protect a3
    .00000100 .0000D000 .00080000 23300000
    # rs1_sp rs2_a4 @24 sd              ; protect a4
    .00000100 .0000E000 .000C0000 23300000
:Preserve_Other_Loop
    # rd_a1 rs1_a0 !24 ld               ; I->EXPRESSION
    .80050000 .00000500 .00008001 03300000
    # rs1_a1 @Preserve_Other_Next bnez  ; IF NULL == I->EXPRESSION then preserve
    .00800500 @Preserve_Other_Next 63100000

    # rd_a1 rs1_a0 !16 ld               ; I->TEXT
    .80050000 .00000500 .00000001 03300000
    # rs1_a0 rs2_a1 @24 sd              ; I->EXPRESSION = I->TEXT
    .00000500 .0000B000 .000C0000 23300000

:Preserve_Other_Next
    # rd_a0 rs1_a0 ld                   ; I = I->NEXT
    .00050000 .00000500 03300000
    # rs1_a0 @Preserve_Other_Loop bnez  ; Keep looping until I == NULL
    .00000500 @Preserve_Other_Loop 63100000

    # rd_a1 rs1_sp ld                   ; restore a1
    .80050000 .00000100 03300000
    # rd_a2 rs1_sp !8 ld                ; restore a2
    .00060000 .00000100 .00008000 03300000
    # rd_a3 rs1_sp !16 ld               ; restore a3
    .80060000 .00000100 .00000001 03300000
    # rd_a4 rs1_sp !24 ld               ; restore a4
    .00070000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Print_Hex function
; Receives list in a0
; walks the list and prints the I->EXPRESSION for all nodes followed by newline
; Uses a1 for I
:Print_Hex
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000
    # rs1_sp rs2_a2 @16 sd              ; protect a2
    .00000100 .0000C000 .00080000 23300000

    # rd_a1 rs1_s4 mv                   ; I = HEAD
    .80050000 .00000A00 13000000

:Print_Hex_Loop
    # rd_a0 rs1_a1 !8 ld                ; I->TYPE
    .00050000 .00800500 .00008000 03300000
    # rd_t0 !1 addi                     ; t0 = MACRO
    .80020000 .00001000 13000000
    # rs1_a0 rs2_t0 @Print_Hex_Next beq ; Skip if MACRO = I->TYPE
    .00000500 .00005000 @Print_Hex_Next 63000000

    # rd_a0 rs1_a1 !24 ld               ; Using EXPRESSION
    .00050000 .00800500 .00008001 03300000
    # rd_ra $File_Print jal             ; Print it
    .80000000 $File_Print 6F000000
    # rd_a0 !10 addi                    ; \n
    .00050000 .0000A000 13000000
    # rd_ra $fputc jal                  ; Print newline
    .80000000 $fputc 6F000000

:Print_Hex_Next
    # rd_a1 rs1_a1 ld                   ; Iterate to next Token
    .80050000 .00800500 03300000
    # rs1_a1 @Print_Hex_Loop bnez       ; Stop if NULL, otherwise keep looping
    .00800500 @Print_Hex_Loop 63100000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_a2 rs1_sp !16 ld               ; restore a2
    .00060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; File_Print function
; Receives CHAR* in a0
; calls fputc for every non-null char
:File_Print
    # rd_sp rs1_sp !-24 addi            ; allocate stack
    .00010000 .00000100 .000080FE 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000
    # rs1_sp rs2_a2 @16 sd              ; protect a2
    .00000100 .0000C000 .00080000 23300000
    # rd_a1 rs1_a0 mv                   ; protect a0
    .80050000 .00000500 13000000

    # rs1_a0 @File_Print_Done beqz      ; Protect against nulls
    .00000500 @File_Print_Done 63000000

:File_Print_Loop
    # rd_a0 rs1_a1 lbu                  ; Read byte
    .00050000 .00800500 03400000
    # rs1_a0 @File_Print_Done beqz      ; Stop at NULL
    .00000500 @File_Print_Done 63000000

    # rd_ra $fputc jal                  ; print it
    .80000000 $fputc 6F000000
    # rd_a1 rs1_a1 !1 addi              ; S = S + 1
    .80050000 .00800500 .00001000 13000000
    # $File_Print_Loop jal              ; Keep printing
    $File_Print_Loop 6F000000

:File_Print_Done
    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_a2 rs1_sp !16 ld               ; restore a2
    .00060000 .00000100 .00000001 03300000
    # rd_sp rs1_sp !24 addi             ; deallocate stack
    .00010000 .00000100 .00008001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; fgetc function
; Loads FILE* from s2
; Returns -4 (EOF) or char in a0
:fgetc
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_ra @8 sd               ; protect ra
    .00000100 .00001000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000

    # rd_a7 !63 addi                    ; sys_read
    .80080000 .0000F003 13000000
    # rd_a1 rs1_sp mv                   ; Get stack address for buffer
    .80050000 .00000100 13000000
    # rd_a0 rs1_s2 mv                   ; read from input file
    .00050000 .00000900 13000000
    # rd_a2 !1 addi                     ; read 1 character
    .00060000 .00001000 13000000
    # ecall                             ; syscall
    73000000

    # rs1_a0 @fgetc_done bnez           ; Check if nothing was read
    .00000500 @fgetc_done 63100000
    # rd_a2 !-4 addi                    ; Use -4 as EOF
    .00060000 .0000C0FF 13000000
    # rs1_a1 rs2_a2 sb                  ; Store EOF in *a1
    .00800500 .0000C000 23000000

:fgetc_done
    # rd_a0 rs1_a1 lb                   ; return char in a0
    .00050000 .00800500 03000000
    # rd_ra rs1_sp !8 ld                ; restore ra
    .80000000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; Malloc isn't actually required if the program being built fits in the initial memory
; However, it doesn't take much to add it.
; Requires MALLOC pointer to be initialized and a0 to have the number of desired bytes
:malloc
    # rd_sp rs1_sp !-16 addi            ; allocate stack
    .00010000 .00000100 .000000FF 13000000
    # rs1_sp rs2_ra sd                  ; protect ra
    .00000100 .00001000 23300000
    # rs1_sp rs2_a1 @8 sd               ; protect a1
    .00000100 .0000B000 .00040000 23300000

    # rd_a1 rs1_s1 mv                   ; Store the current pointer
    .80050000 .00800400 13000000
    # rd_a0 rs1_a0 rs2_s1 add           ; Request the number of desired bytes
    .00050000 .00000500 .00009000 33000000
    # rd_a7 !214 addi                   ; sys_brk
    .80080000 .0000600D 13000000
    # ecall                             ; syscall
    73000000
    # rd_s1 rs1_a0 mv                   ; Set our malloc pointer
    .80040000 .00000500 13000000
    # rd_a0 rs1_a1 mv                   ; Return the pointer
    .00050000 .00800500 13000000

    # rd_ra rs1_sp ld                   ; restore ra
    .80000000 .00000100 03300000
    # rd_a1 rs1_sp !8 ld                ; restore a1
    .80050000 .00000100 .00008000 03300000
    # rd_sp rs1_sp !16 addi             ; deallocate stack
    .00010000 .00000100 .00000001 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


; fputc function
; receives CHAR in a0 and load FILE* from s3
; writes char and returns
:fputc
    # rd_sp rs1_sp !-32 addi            ; allocate stack
    .00010000 .00000100 .000000FE 13000000
    # rs1_sp rs2_a0 sd                  ; protect a0
    .00000100 .0000A000 23300000
    # rs1_sp rs2_ra @8 sd               ; protect ra
    .00000100 .00001000 .00040000 23300000
    # rs1_sp rs2_a1 @16 sd              ; protect a1
    .00000100 .0000B000 .00080000 23300000
    # rs1_sp rs2_a2 @24 sd              ; protect a2
    .00000100 .0000C000 .000C0000 23300000

    # rd_a7 !64 addi                    ; sys_write
    .80080000 .00000004 13000000
    # rd_a0 rs1_s3 mv                   ; write to output
    .00050000 .00800900 13000000
    # rd_a1 rs1_sp mv                   ; Get stack address
    .80050000 .00000100 13000000
    # rd_a2 !1 addi                     ; write 1 character
    .00060000 .00001000 13000000
    # ecall                             ; syscall
    73000000

    # rd_a0 rs1_sp ld                   ; restore a0
    .00050000 .00000100 03300000
    # rd_ra rs1_sp !8 ld                ; restore ra
    .80000000 .00000100 .00008000 03300000
    # rd_a1 rs1_sp !16 ld               ; restore a1
    .80050000 .00000100 .00000001 03300000
    # rd_a2 rs1_sp !24 ld               ; restore a2
    .00060000 .00000100 .00008001 03300000
    # rd_sp rs1_sp !32 addi             ; deallocate stack
    .00010000 .00000100 .00000002 13000000
    # rs1_ra jalr                       ; return
    .00800000 67000000


:Fail
    ; Terminate program with 1 return code
    # rd_a7 !93 addi                    ; sys_exit
    .80080000 .0000D005 13000000
    # rd_a0 !1 addi                     ; Return code 1
    .00050000 .00001000 13000000
    # ecall                             ; exit(1)
    73000000

; PROGRAM END

:terminators
#	"
#	 "
0A 09 20 00

:comments
#	"#;"
23 3B 00

:string_char
#	'22 27 00'
22 27 00

:DEFINE_str
#	"DEFINE"
44 45 46 49 4E 45 00

:ELF_end
 src testA.hex0
93 08 00 04    # li_a7_64
13 05 10 00    # li_a0_1
97 05 00 00    # auipc_a1
93 85 c5 01    # addi_a1
13 06 00 01    # li_a2_len
73 00 00 00    # ecall
93 08 d0 05    # li_a7_93
13 05 00 00    # li_a0_0
73 00 00 00    # ecall
68 65 6c 6c 6f 20 66 72 6f 6d 20 68 65 78 30 0a    # "hello from hex0
"
 src testB.hex1
93 08 00 04    # li_a7_64
13 05 10 00    # li_a0_1
97 05 00 00    # auipc_a1
93 85 c5 01    # addi_a1
13 06 00 01    # li_a2_len
73 00 00 00    # ecall
93 08 d0 05    # li_a7_93
13 05 00 00    # li_a0_0
73 00 00 00    # ecall
68 65 6c 6c 6f 20 66 72 6f 6d 20 68 65 78 31 0a    # "hello from hex1
"
 src testC.hex2
93 08 00 04    # li_a7_64
13 05 10 00    # li_a0_1
97 05 00 00    # auipc_a1
93 85 c5 01    # addi_a1
13 06 00 01    # li_a2_len
73 00 00 00    # ecall
93 08 d0 05    # li_a7_93
13 05 00 00    # li_a0_0
73 00 00 00    # ecall
68 65 6c 6c 6f 20 66 72 6f 6d 20 68 65 78 32 0a    # "hello from hex2
"
 src testD.M0
DEFINE li_a7_64 93080004
DEFINE li_a0_1 13051000
DEFINE auipc_a1 97050000
DEFINE addi_a1 9385c501
DEFINE li_a2_len 1306e000
DEFINE ecall 73000000
DEFINE li_a7_93 9308d005
DEFINE li_a0_0 13050000
DEFINE msg_str 68656c6c6f2066726f6d204d300a

li_a7_64
li_a0_1
auipc_a1
addi_a1
li_a2_len
ecall
li_a7_93
li_a0_0
ecall
msg_str
 