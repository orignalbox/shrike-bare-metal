#!/usr/bin/env python3
"""
elf2uf2.py — Convert an ELF binary to UF2 format for RP2040.

UF2 (USB Flashing Format) is what the RP2040 bootrom expects when
the board is in BOOTSEL mode (mounted as a mass storage drive).

UF2 spec: https://github.com/microsoft/uf2

Each UF2 block is 512 bytes:
  - 32 bytes header (magic numbers, flags, address, size, block info)
  - 476 bytes data (payload, padded with zeros)
  - 4 bytes final magic number

Usage: python3 elf2uf2.py input.bin output.uf2 [base_address]
       base_address defaults to 0x10000000 (start of flash)
"""
import struct
import sys

UF2_MAGIC_START0 = 0x0A324655  # "UF2\n"
UF2_MAGIC_START1 = 0x9E5D5157
UF2_MAGIC_END    = 0x0AB16F30
UF2_FLAG_FAMILY  = 0x00002000
RP2040_FAMILY_ID = 0xE48BFF56

PAYLOAD_SIZE = 256  # bytes of data per UF2 block

def convert(input_path, output_path, base_addr=0x10000000):
    with open(input_path, "rb") as f:
        data = f.read()

    num_blocks = (len(data) + PAYLOAD_SIZE - 1) // PAYLOAD_SIZE
    blocks = []

    for i in range(num_blocks):
        chunk_offset = i * PAYLOAD_SIZE
        chunk = data[chunk_offset : chunk_offset + PAYLOAD_SIZE]
        addr = base_addr + chunk_offset

        # Pad chunk to exactly 476 bytes (payload area in UF2 block)
        payload = chunk.ljust(476, b'\x00')

        header = struct.pack("<IIIIIIII",
            UF2_MAGIC_START0,
            UF2_MAGIC_START1,
            UF2_FLAG_FAMILY,       # flags
            addr,                   # target address in flash
            len(chunk),             # data size (actual, not padded)
            i,                      # block number
            num_blocks,             # total blocks
            RP2040_FAMILY_ID        # family ID
        )

        footer = struct.pack("<I", UF2_MAGIC_END)

        block = header + payload + footer
        assert len(block) == 512, f"UF2 block must be 512 bytes, got {len(block)}"
        blocks.append(block)

    with open(output_path, "wb") as f:
        for block in blocks:
            f.write(block)

    print(f"UF2: {input_path} -> {output_path} ({len(data)} bytes, {num_blocks} blocks)")

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} input.bin output.uf2 [base_addr_hex]", file=sys.stderr)
        sys.exit(1)

    base = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x10000000
    convert(sys.argv[1], sys.argv[2], base)

if __name__ == "__main__":
    main()
