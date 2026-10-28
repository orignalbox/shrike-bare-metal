#!/usr/bin/env python3
"""
pad_checksum.py — Pad boot2 binary to 252 bytes and append CRC32.

The RP2040 ROM bootloader requires:
  - Bytes 0-251: boot2 code (padded with 0x00)
  - Bytes 252-255: CRC32 of bytes 0-251 (little-endian)
  - Total: exactly 256 bytes

Usage: python3 pad_checksum.py input.bin output.bin
"""
import struct
import sys
import binascii

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.bin output.bin", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "rb") as f:
        data = f.read()

    if len(data) > 252:
        print(f"ERROR: boot2 binary is {len(data)} bytes, max is 252!", file=sys.stderr)
        sys.exit(1)

    # Pad to 252 bytes
    data = data.ljust(252, b'\x00')

    # Compute CRC32 (standard IEEE 802.3)
    crc = binascii.crc32(data) & 0xFFFFFFFF

    # Append as little-endian uint32
    data += struct.pack("<I", crc)

    assert len(data) == 256, f"Final size must be 256, got {len(data)}"

    with open(sys.argv[2], "wb") as f:
        f.write(data)

    print(f"boot2: {sys.argv[1]} -> {sys.argv[2]} ({len(data)} bytes, CRC32=0x{crc:08X})")

if __name__ == "__main__":
    main()
