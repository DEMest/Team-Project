#ifdef QEMU
#define SRAM_BASE      0x80000000
#define UART0_BASE     0x10000000
#define DDR_BASE       0x80000000 // For QEMU, DDR can be the same as SRAM_BASE for simplicity
#define PAYLOAD_DDR_DEST_ADDR (DDR_BASE + 0x10000) // Payload destination in DDR
#define PAYLOAD_DDR_STACK_ADDR (DDR_BASE + 0x200000) // Stack for payload in DDR (arbitrary offset)
#else // LICHEE_PI_4A
#define SRAM_BASE      0xFFE0000000
#define UART0_BASE     0xFFE7014000
#define DDR_BASE       0x40000000 // Lichee Pi 4A DDR base address
#define PAYLOAD_DDR_DEST_ADDR (DDR_BASE + 0x10000) // Payload destination in DDR
#define PAYLOAD_DDR_STACK_ADDR (DDR_BASE + 0x20000000) // Stack for payload in DDR (arbitrary offset, far from payload)
#endif

#define NEWLINE        0xA
#define HASH           0x23
#define SEMICOLON      0x3B
#define F_LOWERCASE    0x66
#define F_UPPERCASE    0x46
#define A_LOWERCASE    0x61
#define A_UPPERCASE    0x41
#define DIGIT_9        0x39
#define DIGIT_0        0x30

.global _start
.section .text

#------------------------------------------------------------
# 
# Memory Layout:
#   SRAM_BASE - (SRAM_BASE + 0x40000)  stage1 (bootloader) + payload_src (hex-encoded payload)
#   PAYLOAD_DDR_DEST_ADDR              decoded payload (copied from SRAM to DDR)
#   PAYLOAD_DDR_STACK_ADDR             m-mode stack (located in DDR)
# 
#------------------------------------------------------------

_start:
        la a0, greetings
        call puts

        # Set up stack pointer to a location in DDR for the payload
        li sp, PAYLOAD_DDR_STACK_ADDR

        # s11 will hold the entry point of the payload in DDR
        li s11, PAYLOAD_DDR_DEST_ADDR

        # s1 -- source address (points to hex-encoded payload_src in SRAM)
        # s2 -- read byte
        # s3 -- digit read flag
        # s4 -- digit buffer
        # s5 -- write address (points to the DDR destination for the decoded payload)

        la s1, payload_src # Source of hex-encoded payload in SRAM
        li s3, 0           # Digit read flag (0 for first nibble, 1 for second)
        mv s5, s11         # Destination in DDR (PAYLOAD_DDR_DEST_ADDR)
                
        # Loop to read hex characters from SRAM, decode them, and write the binary to DDR
        read_loop:
                lb s2, (s1)        # Load byte from source (SRAM)
                addi s1, s1, 1     # Increment source pointer
                beqz s2, read_loop_exit # Exit loop if null terminator is found

                # Skip comments starting with # or ;
                li s6, HASH
                beq s2, s6, skip_comment
                li s6, SEMICOLON
                beq s2, s6, skip_comment
                
                # Handle hex characters (0-9, A-F, a-f)
                li s6, (F_LOWERCASE + 1)
                bge s2, s6, read_loop_cont

                li s6, A_LOWERCASE
                bge s2, s6, handle_lower

                li s6, (F_UPPERCASE + 1)
                bge s2, s6, read_loop_cont

                li s6, A_UPPERCASE
                bge s2, s6, handle_upper

                li s6, (DIGIT_9 + 1)
                bge s2, s6, read_loop_cont

                li s6, DIGIT_0
                bge s2, s6, handle_digit

                j read_loop_cont

                skip_comment:                
                        li s6, NEWLINE
                skip_comment_loop:
                        lb s2, (s1)
                        addi s1, s1, 1
                        beq s2, s6, skip_comment_loop_end
                        j skip_comment_loop
                skip_comment_loop_end:
                        j read_loop_cont                         
                
                handle_digit:
                        addi s2, s2, -(DIGIT_0)
                        j general_handle                        
                handle_lower:
                        addi s2, s2, -(A_LOWERCASE - 10)
                        j general_handle
                handle_upper:
                        addi s2, s2, -(A_UPPERCASE - 10)

                general_handle:
                        slli s4, s4, 4     # Shift previous nibble left by 4
                        andi s4, s4, 0xFF  # Keep only the lower 8 bits (for safety)
                        add s4, s4, s2     # Add current nibble
                        beqz s3, set_flag  # If first nibble, just store it in s4
                        sb s4, (s5)        # If second nibble, store the full byte in DDR
                        addi s5, s5, 1     # Increment DDR destination pointer

                        set_flag:
                        not s3, s3         # Toggle flag for next nibble

                read_loop_cont:
                j read_loop
        read_loop_exit:
                beqz s3, read_loop_end # If an odd number of nibbles, write the last one
                andi s4, s4, 0xF
                sb s4, (s5)                
        read_loop_end:

        la a0, builded
        call puts

        # Jump to the decoded payload in DDR
        jalr zero, (s11) 

puts:
    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
wait_tx_puts_func:
    lb t5, 0x14(t2) 
    andi t5, t5, 0x20 
    beqz t5, wait_tx_puts_func
    sb a0, 0(t2)
    addi t1, t1, 1
    j puts_loop
puts_done:
    ret

greetings: .string "[BOOTED]: Stage 1 (boot) - parsing payload.\n\r"
builded: .string "[BUILDED]: Jump to stage 2.   \n\n\r"

payload_src:
