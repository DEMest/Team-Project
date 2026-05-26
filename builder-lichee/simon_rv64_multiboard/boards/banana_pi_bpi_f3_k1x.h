#ifndef BOARD_CONFIG_LOADED
#define BOARD_CONFIG_LOADED 1
#endif

#define BOARD_TRAP_M 1
#define BOARD_TRAP_S 2

/* Banana Pi BPI-F3 / SpacemiT K1-X.
 * Payload is started by OpenSBI + U-Boot go, so Simon runs in S-mode.
 */
#define BOARD_TRAP_MODE BOARD_TRAP_S
#define BOARD_WDT_ENABLE 1

#define UART0_BASE      0xD4017000
#define UART_LSR        0x14
#define LSR_RX_READY    0x01
#define LSR_TX_IDLE     0x20

#define SOC_WDT_BASE    0xD4080000
#define WDT_WMER        0x00b8
#define WDT_WMR         0x00bc
#define WDT_WSR         0x00c0
#define WDT_WCR         0x00c8
#define WDT_WFAR        0x00b0
#define WDT_WSAR        0x00b4

#define MCAUSE_ECALL_U      8
#define MCAUSE_ECALL_M      9
#define MCAUSE_TIMER_M      0x8000000000000005

#define SRAM_SIZE       0x17FFFF
#define STACK_OFFSET    SRAM_SIZE
#define PAYLOAD_OFFSET  0x80000

#define IMAGE_SCAN_BASE     0x10000000
#define IMAGE_SCAN_END      0x10900000

#define PROC_BASE           0x12050000
#define PROC_FIRST_RUNNABLE 0x12051000
#define PROC_END            0x1206ffff
#define FILE_NAME_BASE      0x12070000
#define FILE_NAME_END       0x1207ffff
#define STAGE2_BASE         0x12080000
#define KERNEL_STACK_TOP    0x12090000
#define OPEN_FILES_BASE     0x12090100
#define OPEN_FILES_END      0x12090300
#define ARGS_BLOCK_BASE     0x12098000
#define FD_BASE             0x12100000
#define FILE_DATA_BASE      0x12100400
#define HEAP_BASE           0x16000000
#define HEAP_END            0x1A000000

#define EARLY_WARMUP_START  0x12050000
#define EARLY_WARMUP_END    0x12200000
#define WARMUP1_START       0x12050000
#define WARMUP1_END         0x12200000
#define WARMUP2_ENABLE      0
#define WARMUP2_START       0
#define WARMUP2_END         0
