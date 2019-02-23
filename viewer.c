/* Opens/Creates a shared file "window"
 * where you can draw stuff using mmap,
 * and it shows on the window that this program created. */
#include <assert.h> /* assert() */
#include <SDL.h>
#include <stdlib.h> /* exit() */
#include <math.h>
#include <unistd.h> /* truncate(), open() */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h> /* perror */
#include <sys/mman.h> /* mmap */

void check_sdl_error(int);

int main() {
    int result;
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Texture *screen;
    SDL_Event event;
    int done = 0;
    char *input_pixels;
    char *output_pixels;
    int pitch;

    int screen_width = 1280;
    int screen_height = 1024;
    int buffer_size = screen_width*screen_height*3;
    int fbfd;

    result = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
    check_sdl_error(result == 0);

    window = SDL_CreateWindow("viewer", 0, 0, screen_width, screen_height, 0);
    check_sdl_error(window != NULL);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    screen = SDL_CreateTexture(renderer,
        SDL_PIXELFORMAT_RGB888,
        SDL_TEXTUREACCESS_STREAMING,
        screen_width, screen_height);

    fbfd = open("window", O_RDWR | O_CREAT, 0660);
    if (fbfd == -1) {
        perror("cannot open 'window'");
        exit(1);
    }

    if (ftruncate(fbfd, buffer_size) == -1) {
        perror("cannot resize the file to correct size");
        exit(1);
    }

    input_pixels = mmap(NULL, buffer_size, PROT_READ|PROT_WRITE, MAP_SHARED, fbfd, 0);
    if (input_pixels == MAP_FAILED) {
        perror("mmap failed");
        exit(1);
    }

    while (!done) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                done = 1;
            }
        }

        // An alternative way to do the following,
        // though I felt the simple RGB pixel format was worth the extra effort.
        // SDL_UpdateTexture(screen, NULL, (void*)input_pixels, screen_width*4);

        SDL_LockTexture(screen, NULL, (void**)&output_pixels, &pitch);
        int i = 0;
        for (int y = 0; y < screen_height*pitch; y += pitch) {
            for (int x = 0; x < screen_width*4; x += 4) {
                output_pixels[y+x+0] = input_pixels[i+2];
                output_pixels[y+x+1] = input_pixels[i+1];
                output_pixels[y+x+2] = input_pixels[i+0];
                output_pixels[y+x+3] = 0;
                i += 3;
            }
        }
        SDL_UnlockTexture(screen);

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, screen, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    SDL_ShowWindow(window);
    SDL_DestroyTexture(screen);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}

void check_sdl_error(int success) {
    if (!success) {
        SDL_LogError(SDL_LOG_CATEGORY_ERROR,
            "%s\n", SDL_GetError());
        exit(1);
    }
}
