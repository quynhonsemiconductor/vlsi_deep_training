# QSOC boot ROM (QNSC_BOOT_SPEC V3.0 section 8, QNSC_ROM_MAS V3.1 7.2):
#   C/asm -> boot.elf -> boot.bin -> rom_image.hex -> m_qnsc_rom_image.sv
#
#   make                       build + size check
#   make rtl                   copy the hex to util/gen/rom/ and regenerate m_qnsc_rom_image.sv
#   make CROSS=riscv-none-elf- (xPack toolchain on Windows)
#   make test                  protocol test on the Python ROM model (no HW)
#   make clean

CROSS   ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size
PYTHON  ?= python3

# Code budget after the 128-byte trap table (Day005: program <= 1 KiB).
BUDGET  ?= 1024
ROM_WORDS := 512

CFLAGS  := -march=rv32imc_zicsr_zifencei -mabi=ilp32 -Os -ffreestanding -fno-builtin \
           -nostdlib -msmall-data-limit=0 -ffunction-sections \
           -Wall -Wextra -Werror
LDFLAGS := -T link.ld -nostartfiles -nostdlib -Wl,--gc-sections -Wl,-Map,boot.map

SRCS := crt0.S boot.c

.PHONY: all size test rtl clean
REPO    := ../../..
ROM_GEN := $(REPO)/util/gen/rom
all: rom_image.hex boot.dis size

boot.elf: $(SRCS) boot.h link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)

boot.bin: boot.elf
	$(OBJCOPY) -O binary $< $@

rom_image.hex: boot.bin tools/bin2hex.py
	$(PYTHON) tools/bin2hex.py $< $@ --words $(ROM_WORDS)

boot.dis: boot.elf
	$(OBJDUMP) -d $< > $@

size: boot.bin
	@$(SIZE) boot.elf
	@$(PYTHON) tools/bin2hex.py boot.bin - --words $(ROM_WORDS) --budget $(BUDGET) --report

# the committed hex is the single input CI regenerates the module from (ROM_006)
rtl: rom_image.hex
	cp $< $(ROM_GEN)/rom_image.hex
	$(PYTHON) $(REPO)/util/gen_rom.py $(ROM_GEN)/rom_image.hex $(ROM_GEN)/m_qnsc_rom_image.sv

test:
	$(PYTHON) tools/test_protocol.py

clean:
	rm -f boot.elf boot.bin boot.map boot.dis rom_image.hex
