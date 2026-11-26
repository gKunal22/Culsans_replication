# Builds bare-metal programs for the 2-core Culsans SoC into build/sw/.
#   make -C sw integration              all of the authors' integration tests
#   make -C sw integration T=amo_mutex  one test
# Each program ends up as build/sw/<suite>/<name>.hex for sim/tb/tb_culsans.sv.

ROOT      := $(abspath ..)
CULSANS   := $(ROOT)/culsans
OUT       := $(ROOT)/build/sw
PREFIX    ?= riscv64-unknown-elf-
CC        := $(PREFIX)gcc
AR        := $(PREFIX)ar
ARCH      := -march=rv64gc_zifencei -mabi=lp64d -mcmodel=medany
# picolibc only provides the C headers; programs link with -nostdlib like the authors' flow
CFLAGS    := $(ARCH) --specs=picolibc.specs -static -std=gnu99 -O3 -ffast-math -fno-common \
             -fno-builtin-printf -falign-functions=32 -falign-jumps=32 -DPREALLOCATE=1
LDFLAGS   := -nostdlib -nostartfiles -T $(ROOT)/sw/common/linker.ld
ELF2HEX   := python3 $(ROOT)/scripts/elf2hex.py --objcopy $(PREFIX)objcopy

# --- authors' integration tests (culsans/tests/integration) --------------------
# The tests include "../../sw/include/nb_cores.h" relative to themselves, so the
# suite is copied into build/ and the 2-core nb_cores.h and crt.S are dropped in.
IT_SRC := $(CULSANS)/tests/integration
IT_OUT := $(OUT)/integration
IT_ALL := $(notdir $(patsubst %/,%,$(dir $(wildcard $(IT_SRC)/testlist/*/main.c))))
T      ?= $(IT_ALL)

integration: $(addprefix $(IT_OUT)/,$(addsuffix .hex,$(T)))

$(IT_OUT)/.copied:
	mkdir -p $(IT_OUT)/tree
	cp -r $(IT_SRC)/sw $(IT_SRC)/testlist $(IT_OUT)/tree/
	cp $(ROOT)/sw/common/nb_cores.h $(IT_OUT)/tree/sw/include/nb_cores.h
	cp $(ROOT)/sw/common/crt.S      $(IT_OUT)/tree/sw/sys/crt.S
	# amo_mutex's inline asm writes t0/t1/a0 without declaring them; GCC 13 then keeps
	# cid in a0 and the delay loop runs ~10^9 times. Declare the clobbers (ASSUMPTIONS A15).
	sed -i -E 's/asm volatile \(("[^"]*")\);/asm volatile (\1 ::: "t0", "t1", "a0", "memory");/' \
	  $(IT_OUT)/tree/testlist/amo_mutex/amo_mutex.c $(IT_OUT)/tree/testlist/amo_mutex/main.c
	touch $@

$(IT_OUT)/libintegr.a: $(IT_OUT)/.copied
	mkdir -p $(IT_OUT)/objs
	for f in $(IT_OUT)/tree/sw/src/*.c; do \
	  $(CC) $(ARCH) --specs=picolibc.specs -O2 -I$(IT_OUT)/tree/sw/include -c $$f -o $(IT_OUT)/objs/$$(basename $$f .c).o || exit 1; \
	done
	$(AR) rcs $@ $(IT_OUT)/objs/*.o

$(IT_OUT)/%.elf: $(IT_OUT)/libintegr.a
	cd $(IT_OUT)/tree/testlist/$* && $(CC) $(CFLAGS) -I../../sw/include -I../../sw/sys \
	  ../../sw/sys/syscalls.c ../../sw/sys/crt.S *.c $(LDFLAGS) -L$(IT_OUT) -lintegr -lgcc -o $@

%.hex: %.elf
	$(ELF2HEX) $< $@

clean:
	rm -rf $(OUT)

.PHONY: integration clean
.SECONDARY:
