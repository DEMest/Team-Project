echo "=== SIMON INTERCEPT ==="
fatload mmc 1:1 0x40000000 simon.bin
go 0x40000000
