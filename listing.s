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
sys_close = 57
sys_read  = 63
sys_write = 64
sys_exit  = 93
sys_brk     = 214
sys_munmmap = 215
sys_mmap = 222
sys_open = 1024
# Standard fileno numbers
stdin  = 0
stdout = 1
stderr = 2
# Some file flags we need
O_RDWR = 0x0002
PROT_READ  = 0x1
PROT_WRITE = 0x2
PROT_EXEC = 0x4
PROT_READ_WRITE = 0x3
MAP_SHARED  = 0x1
MAP_PRIVATE = 0x2
MAP_FIXED = 0x10
MAP_ANON = 0x20

_start:
    # The gp frame.
    #  0: fileno
    #  8: screen buffer size
    # 16: screen buffer stride
    # 24: screen pixel width
    # 32: screen pixel height
    # 40: address to framebuffer
    # 48: lcg seed
    # 56: lcg multiplier
    # 64: lcg increment
    # 72: slant_a address (0)
    # 80: slant_a width   (8)
    # 88: slant_a height  (16)
    # 96: slant_b address (0)
    # 104: slant_b width   (8)
    # 112: slant_b height (16)
    # 120
    addi sp, sp, -120
    mv gp, sp

    lla a0, window_file_path
    li  a1, O_RDWR
    li  a2, 0
    li  a7, sys_open
    ecall
    blt a0, zero, program_failure
    sd a0, 0(gp)                            # fileno

    screen_buffer_size = 1280*1024*3
    lui a0,      %hi(screen_buffer_size)
    addi a0, a0, %lo(screen_buffer_size)
    sd a0, 8(gp)                            # screen buffer size

    addi a0, zero, 1280
    addi a0, a0,   1280
    addi a0, a0,   1280
    sd a0, 16(gp)                           # screen buffer stride

    addi a0, zero, 1280
    sd a0, 24(gp)                           # screen pixel width

    addi a0, zero, 1024
    sd a0, 32(gp)                           # screen pixel height

    li a0, 0
    ld a1, 8(gp)                            # screen buffer size
    li a2, PROT_READ_WRITE
    li a3, MAP_SHARED
    ld a4, 0(gp)                            # fileno
    li a5, 0                                # offset
    li a7, sys_mmap
    ecall
    blt a0, zero, program_failure
    sd a0, 40(gp)                           # address to framebuffer

    # Configuration for the random number generator.
    rdtime a0
    lcg_multiplier = 1664525
    lui a1, %hi(lcg_multiplier)
    addi a1, a1, %lo(lcg_multiplier)
    lcg_increment = 1013904223
    lui a2, %hi(lcg_increment)
    addi a2, a2, %lo(lcg_increment)
    sd a0, 48(gp)
    sd a1, 56(gp)
    sd a2, 64(gp)

    # Extract bitmaps from the images
    # The first two bytes in the bitmap images should be 42 4D
    # Otherwise this code doesn't work.
    lla a0, slant_a_bmp
    addi a1, gp, 72
    jal x1, extract_bitmap

    lla a0, slant_b_bmp
    addi a1, gp, 96
    jal x1, extract_bitmap
    j bitmaps_extracted

extract_bitmap:
    lw a2, 10(a0)
    add a2, a2, a0
    lw a3, 18(a0) # width 
    lw a4, 22(a0) # height
    sd a2,  0(a1)
    sd a3,  8(a1)
    sd a4, 16(a1)
    jr x1
bitmaps_extracted:
    # The screen clearing procedure
    ld a0, 40(gp) # framebuffer address
    ld a1,  8(gp) # framebuffer size
    add a1, a1, a0
clear_screen:
    sb x0, 0(a0)
    add a0, a0, 1
    blt a0, a1, clear_screen

    li s0, 128 # draw this many rows
    li s1, 80  # draw this many columns
    li s2, 0   # row counter
draw_a_row:
    li s3, 0   # column counter
draw_a_column:
    # Calculating screenbuffer offset to a0
    ld a0, 16(gp) # screen buffer stride
    li a1, 16*3   # tile width*3
    li a2,  8     # tile height
    mul a2, a2, a0
    mul a0, a2, s2
    mul a1, a1, s3
    add a0, a0, a1

    # LCG Random number roll
    ld a2, 48(gp) # seed
    ld a3, 56(gp) # multiplier
    ld a4, 64(gp) # increment
    mul a2, a2, a3
    add a2, a2, a4
    sd a2, 48(gp)

    srl a2, a2, 24 # Grasping a bit.
    andi a2, a2, 1

    addi a1, gp, 72
    beq a2, zero, selected_slant_a
    addi a1, gp, 96
selected_slant_a:

    # OK, everything ready for a draw.
    # gp has the framebuffer
    # a0 has the offset
    # a1 has the image
    ld t0, 16(gp) # screen buffer stride
    ld a7, 8(a1)  # image width
    sub t0, t0, a7
    sub t0, t0, a7
    sub t0, t0, a7

    # Not doing overdraw protection so this is fairly simple.
    ld a2, 40(gp)       # framebuffer address
    add a2, a2, a0
    ld a3, 0(a1)        # image address

    li a4, 0
    ld a5, 16(a1) # image height
    li a6, 0
    ld a7, 8(a1)  # image width
    bge a6, a7, blit_done
    bge a4, a5, blit_done
pixel_blit:
    # Pixel blit
    lb a0, 0(a3)
    sb a0, 2(a2)
    lb a0, 1(a3)
    sb a0, 1(a2)
    lb a0, 2(a3)
    sb a0, 0(a2)
    addi a3, a3, 3
    addi a2, a2, 3
    # Loop to the next pixel
    addi a6, a6, 1
    blt a6, a7, pixel_blit
    # Preparing for the next row
    li a6, 0
    add a2, a2, t0
    # Loop to the next row
    addi a4, a4, 1
    blt a4, a5, pixel_blit
blit_done:
    # Loop to the next column/row
    addi s3, s3, 1
    blt s3, s1, draw_a_column
    addi s2, s2, 1
    blt s2, s0, draw_a_row

    # The drawing has been finished.
    li a0, 0
    li a7, sys_exit
    ecall

program_failure:
    li a0, 1
    li a7, sys_exit
    ecall
    loop: j loop

window_file_path:
    .string "window"
    .byte 0

# 16x8x3 images, 54 byte header
slant_a_bmp: .incbin "slant_a.bmp"
slant_b_bmp: .incbin "slant_b.bmp"

filesize = . - ehdr
