#!/usr/bin/env python3
from pathlib import Path
import os
import struct
import time
import zlib

payload = Path(os.environ.get('PAYLOAD', 'image_simon_lichee.bin'))
wrapped = Path(os.environ.get('WRAPPED', 'simon_wrapped.img'))
flash = Path(os.environ.get('FLASH', 'flash_me.bin'))
spl = Path(os.environ.get('SPL', 'u-boot-with-spl.bin'))
load = int(os.environ.get('LOAD_ADDR', '0x40000000'), 0)
name = os.environ.get('IMAGE_NAME', 'SimonOS').encode('ascii', errors='ignore')

if not payload.exists():
    raise SystemExit(f'No payload: {payload}')
if not spl.exists():
    raise SystemExit(f'No SPL/U-Boot image: {spl}')

data = payload.read_bytes()
magic = 0x27051956
hcrc = 0
ts = int(time.time())
size = len(data)
ep = load
dcrc = zlib.crc32(data) & 0xffffffff
header = struct.pack('>7I4B32s', magic, hcrc, ts, size, load, ep, dcrc, 0x11, 0x1a, 0x01, 0x00, name[:32].ljust(32, b'\0'))
hcrc = zlib.crc32(header) & 0xffffffff
header = struct.pack('>7I4B32s', magic, hcrc, ts, size, load, ep, dcrc, 0x11, 0x1a, 0x01, 0x00, name[:32].ljust(32, b'\0'))
wrapped.write_bytes(header + data)

img = bytearray(b'\0' * (4 * 1024 * 1024))
splb = spl.read_bytes()
if len(splb) > 1024 * 1024:
    raise SystemExit(f'SPL/U-Boot image is too large for offset layout: {len(splb)} bytes')
img[:len(splb)] = splb
wr = wrapped.read_bytes()
if len(wr) > len(img) - 1024 * 1024:
    raise SystemExit(f'Wrapped payload is too large for 4 MiB flash image: {len(wr)} bytes')
img[1024 * 1024:1024 * 1024 + len(wr)] = wr
flash.write_bytes(img)
print(f'Built {flash} size {flash.stat().st_size}')
