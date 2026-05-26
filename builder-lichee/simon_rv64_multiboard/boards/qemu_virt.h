#ifndef BOARD_CONFIG_LOADED
#define BOARD_CONFIG_LOADED 1
#endif

#define BOARD_TRAP_M 1
#define BOARD_TRAP_S 2

/* Template for qemu-system-riscv64 -M virt -bios image_qemu.bin.
 * Kept mostly for local debugging; hardware configs above are the tested ones.
 */
#define BOARD_TRAP_MODE BOARD_TRAP_M
#define BOARD_WDT_ENABLE 0

#define UART0_BASE      0x10000000
#define UART_LSR        5
#define LSR_RX_READY    1
#define LSR_TX_IDLE     0x20

#define SOC_WDT_BASE    0x00000000
#define WDT_WMER        0x00b8
#define WDT_WMR         0x00bc
#define WDT_WSR         0x00c0
#define WDT_WCR         0x00c8
#define WDT_WFAR        0x00b0
#define WDT_WSAR        0x00b4

#define MCAUSE_ECALL_U      8
#define MCAUSE_ECALL_M      11
#define MCAUSE_TIMER_M      0x8000000000000005

#define SRAM_SIZE       0x17FFFF
#define STACK_OFFSET    SRAM_SIZE
#define PAYLOAD_OFFSET  0x80000

#define IMAGE_SCAN_BASE     0x80000000
#define IMAGE_SCAN_END      0x80900000

#define PROC_BASE           0x80050000
#define PROC_FIRST_RUNNABLE 0x80051000
#define PROC_END            0x8006ffff
#define FILE_NAME_BASE      0x80070000
#define FILE_NAME_END       0x8007ffff
#define STAGE2_BASE         0x80080000
#define KERNEL_STACK_TOP    0x80090000
#define OPEN_FILES_BASE     0x80090100
#define OPEN_FILES_END      0x80090300
#define ARGS_BLOCK_BASE     0x80098000
#define FD_BASE             0x80100000
#define FILE_DATA_BASE      0x80100400
#define HEAP_BASE           0x84000000
#define HEAP_END            0x88000000

#define EARLY_WARMUP_START  0x80050000
#define EARLY_WARMUP_END    0x80200000
#define WARMUP1_START       0x80050000
#define WARMUP1_END         0x80200000
#define WARMUP2_ENABLE      0
#define WARMUP2_START       0
#define WARMUP2_END         0
