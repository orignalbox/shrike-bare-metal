PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
SIZE    = $(PREFIX)size

CFLAGS  = -mcpu=cortex-m0plus -mthumb -nostdlib -nostartfiles -ffreestanding -Os -Wall -Wextra -std=c11
ASFLAGS = -mcpu=cortex-m0plus -mthumb
LDFLAGS = -T memmap.ld -nostdlib -nostartfiles

TARGET  = blink

all: $(TARGET).uf2
	@echo "build finished: $(TARGET).uf2"

# assemble second-stage bootloader (pre-padded 256 bytes with CRC)
boot2.o: boot2.S
	$(CC) $(ASFLAGS) -c -o $@ $<

# assemble startup code
crt0.o: crt0.S
	$(CC) $(ASFLAGS) -c -o $@ $<

# compile main program
main.o: main.c rp2040.h
	$(CC) $(CFLAGS) -c -o $@ $<

# link everything
$(TARGET).elf: boot2.o crt0.o main.o memmap.ld
	$(CC) $(LDFLAGS) -o $@ boot2.o crt0.o main.o
	@$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).uf2: $(TARGET).bin elf2uf2.py
	python3 elf2uf2.py $< $@

size: $(TARGET).elf
	$(SIZE) $<

disasm: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $(TARGET).lst

flash: $(TARGET).uf2
	@if [ -d "/media/$$USER/RPI-RP2" ]; then \
		cp $(TARGET).uf2 /media/$$USER/RPI-RP2/ && sync && echo "flashed successfully"; \
	elif [ -d "/run/media/$$USER/RPI-RP2" ]; then \
		cp $(TARGET).uf2 /run/media/$$USER/RPI-RP2/ && sync && echo "flashed successfully"; \
	else \
		echo "error: RPI-RP2 drive not mounted"; \
		exit 1; \
	fi

clean:
	rm -f *.o *.elf *.bin *.uf2 *.lst

.PHONY: all flash clean size disasm
