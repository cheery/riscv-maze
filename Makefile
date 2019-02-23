SDL2_CFLAGS = $(shell pkg-config sdl2 --cflags)
SDL2_LIBS = $(shell pkg-config sdl2 --libs)

CFLAGS = $(SDL2_CFLAGS)
LIBS = $(SDL2_LIBS)

.PHONY: all
all: viewer maze

viewer: viewer.c
	gcc $(CFLAGS) -O2 $^ -o $@ $(LIBS)

# There was a bug in the riscv toolchain preventing use of --oformat binary.
# Use of objcopy is a workaround for it.
maze: maze.elf
	riscv64-unknown-elf-objcopy -O binary $^ $@ 
	chmod +x $@

maze.elf: listing.s slant_a.bmp slant_b.bmp
	riscv64-unknown-elf-gcc -nostartfiles listing.s -o $@
