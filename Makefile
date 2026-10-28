# ============================================================================
# Makefile — Bare-metal RP2040 blink for Vicharak Shrike Lite
#
# No SDK. No libraries. Just arm-none-eabi-gcc + our 6 files.
#
# Build:   make
# Flash:   make flash  (copies .uf2 to mounted RPI-RP2 drive)
# Clean:   make clean
# Size:    make size   (show binary size breakdown)
# ============================================================================

PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
SIZE    = $(PREFIX)size

# Cortex-M0+ flags: Thumb-only, no standard libs, optimize for size
CFLAGS  = -mcpu=cortex-m0plus -mthumb -nostdlib -nostartfiles \
          -ffreestanding -Os -Wall -Wextra -std=c11
ASFLAGS = -mcpu=cortex-m0plus -mthumb
LDFLAGS = -T memmap.ld -nostdlib -nostartfiles

TARGET  = blink

# ── Build targets ──────────────────────────────────────────────────────────

all: $(TARGET).uf2
	@echo ""
	@echo "========================================"
	@echo "  BUILD COMPLETE: $(TARGET).uf2"
	@echo "  Flash: hold BOOT + plug USB, then:"
	@echo "    cp $(TARGET).uf2 /media/$$USER/RPI-RP2/"
	@echo "========================================"
	@echo ""

# Step 1: Assemble boot2 → raw binary → pad + CRC32 → object file
boot2_raw.o: boot2.S
	$(CC) $(ASFLAGS) -c -o $@ $<

boot2_raw.bin: boot2_raw.o
	$(OBJCOPY) -O binary $< $@

boot2_padded.bin: boot2_raw.bin pad_checksum.py
	python3 pad_checksum.py $< $@

# Convert the padded+CRC'd boot2 binary back into a linkable object file
# The .boot2 section name must match what memmap.ld expects
boot2.o: boot2_padded.bin
	$(OBJCOPY) -I binary -O elf32-littlearm -B arm \
		--rename-section .data=.boot2 \
		$< $@

# Step 2: Assemble startup code
crt0.o: crt0.S
	$(CC) $(ASFLAGS) -c -o $@ $<

# Step 3: Compile main program
main.o: main.c rp2040.h
	$(CC) $(CFLAGS) -c -o $@ $<

# Step 4: Link everything together
$(TARGET).elf: boot2.o crt0.o main.o memmap.ld
	$(CC) $(LDFLAGS) -o $@ boot2.o crt0.o main.o
	@echo "--- Section sizes ---"
	@$(SIZE) $@

# Step 5: Extract raw binary from ELF
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Step 6: Convert to UF2 for drag-and-drop flashing
$(TARGET).uf2: $(TARGET).bin elf2uf2.py
	python3 elf2uf2.py $< $@

# ── Utility targets ────────────────────────────────────────────────────────

# Show section sizes
size: $(TARGET).elf
	$(SIZE) $<

# Generate disassembly listing (great for learning / debugging)
disasm: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $(TARGET).lst
	@echo "Disassembly written to $(TARGET).lst"

# Flash: copy UF2 to the RP2040 mass-storage bootloader
# The board must be in BOOTSEL mode (hold BOOT button while plugging USB)
flash: $(TARGET).uf2
	@echo "Copying $(TARGET).uf2 to RPI-RP2 drive..."
	@if [ -d "/media/$$USER/RPI-RP2" ]; then \
		cp $(TARGET).uf2 /media/$$USER/RPI-RP2/ && \
		echo "Done! Board should reboot and LED should blink."; \
	elif [ -d "/run/media/$$USER/RPI-RP2" ]; then \
		cp $(TARGET).uf2 /run/media/$$USER/RPI-RP2/ && \
		echo "Done! Board should reboot and LED should blink."; \
	else \
		echo "ERROR: RPI-RP2 drive not found."; \
		echo "Hold BOOT button on Shrike Lite, plug USB-C, try again."; \
		exit 1; \
	fi

clean:
	rm -f *.o *.elf *.bin *.uf2 *.lst boot2_raw.* boot2_padded.*

.PHONY: all flash clean size disasm
