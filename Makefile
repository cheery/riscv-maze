# There was a bug in the riscv toolchain preventing use of --oformat binary.
# Use of objcopy is a workaround for it.
mini-hello: mini-hello.elf
	riscv64-unknown-elf-objcopy -O binary $^ $@ 
	chmod +x $@

mini-hello.elf: listing.s
	riscv64-unknown-elf-gcc -nostartfiles $^ -o $@
