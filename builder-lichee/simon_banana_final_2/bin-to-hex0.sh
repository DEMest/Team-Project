#!/usr/bin/env python3
import sys
from pathlib import Path
if len(sys.argv) != 3:
    print(f"usage: {sys.argv[0]} input.bin output.hex0", file=sys.stderr)
    sys.exit(2)
data = Path(sys.argv[1]).read_bytes()
out = []
for i in range(0, len(data), 4):
    chunk = data[i:i+4]
    out.append(' '.join(f'{b:02X}' for b in chunk))
Path(sys.argv[2]).write_text('\n'.join(out) + ('\n' if out else ''))
