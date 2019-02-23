.section .text
.globl _start # ld nags without this.
.org 0
load_address = 0x010000 # can also use: 0x08048000
ehdr:
    .byte 0x7f, 0x45, 0x4c, 0x46, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .half 2                                 #   e_type
    .half 0xf3                              #   e_machine
    .word 1                                 #   e_version
    .quad load_address + _start - ehdr      #   e_entry
    .quad phdr - ehdr                       #   e_phoff
    .quad 0                                 #   e_shoff
    .word 0                                 #   e_flags
    .half ehdrsize                          #   e_ehsize    (64)
    .half phdrsize                          #   e_phentsize (56)
    .half 1                                 #   e_phnum
    .half 0                                 #   e_shentsize (64)
    .half 0                                 #   e_shnum
    .half 0                                 #   e_shstrndx
ehdrsize = . - ehdr

phdr:
    .word 1                                 #   p_type
    .word 5                                 #   p_flags
    .quad 0                                 #   p_offset
    .quad load_address                      #   p_vaddr
    .quad load_address                      #   p_paddr
    .quad filesize                          #   p_filesz
    .quad filesize                          #   p_memsz
    .quad 0x1000                            #   p_align
phdrsize = . - phdr

# Linux system call numbers https://rv8.io/syscalls.html
sys_write = 64
sys_exit  = 93
# Standard fileno numbers
stdin  = 0
stdout = 1
stderr = 2

_start:
    li a0, stdout
    lla a1, greeting_text
    lw a2, -4(a1)
    li a7, sys_write
    ecall
    bne a0, a2, write_failed

    li a0, 0
    li a7, sys_exit
    ecall

write_failed:
    li a0, 1
    li a7, sys_exit
    ecall

    .word greeting_end - greeting_text
greeting_text:
    .string "Hello world\n"
greeting_end:

filesize = . - ehdr
