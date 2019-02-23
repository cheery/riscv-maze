# RISC-V maze written in assembly with ELF headers

This is a part of the blog post "RISC-V can be fun if they don't mess it up".

## How to run

 1. Ensure you're on Linux.
 2. Ensure you have the riscv cross compiling tools installed.
 3. Ensure you have SDL2 development files installed.
    For example, on Debian-based system
    you'd run: `sudo apt-get install libsdl2-dev`
 3. Run `make`
 4. Run `viewer &`, a window opens.
 5. Run `rv-jit mini-hello`
 6. The program draws the following image to the window,
    it is randomized every time it runs.

 ![Maze screenshot](screenshot.png)
