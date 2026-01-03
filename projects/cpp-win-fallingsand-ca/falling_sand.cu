#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cuda_runtime.h>

// Window dimensions
#define WIDTH 800
#define HEIGHT 600
#define BRUSH_SIZE 5

// Particle types
#define EMPTY 0
#define SAND 1
#define WATER 2
#define STONE 3
#define FIRE 4
#define WOOD 5
#define STEAM 6

// Colors (RGB)
typedef struct {
    unsigned char r, g, b;
} Color;

__device__ Color get_color(unsigned char type) {
    Color c;
    switch(type) {
        case SAND:
            c.r = 194; c.g = 178; c.b = 128;
            break;
        case WATER:
            c.r = 64; c.g = 164; c.b = 223;
            break;
        case STONE:
            c.r = 128; c.g = 128; c.b = 128;
            break;
        case FIRE:
            c.r = 255; c.g = 100; c.b = 0;
            break;
        case WOOD:
            c.r = 139; c.g = 90; c.b = 43;
            break;
        case STEAM:
            c.r = 220; c.g = 220; c.b = 220;
            break;
        default:
            c.r = 0; c.g = 0; c.b = 0;
    }
    return c;
}

// CUDA kernel for updating particles
__global__ void update_particles(unsigned char* grid, unsigned char* new_grid, 
                                int width, int height, unsigned int* rand_state) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (x >= width || y >= height) return;
    
    int idx = y * width + x;
    unsigned char cell = grid[idx];
    
    // Simple pseudo-random using thread index and frame
    unsigned int rand_val = (rand_state[0] + idx * 1103515245 + 12345) & 0x7FFFFFFF;
    int rand_dir = (rand_val % 3) - 1; // -1, 0, or 1
    
    // Default: copy current cell
    new_grid[idx] = cell;
    
    if (cell == EMPTY) return;
    
    // Helper macros for bounds checking
    #define VALID(nx, ny) ((nx) >= 0 && (nx) < width && (ny) >= 0 && (ny) < height)
    #define GET(nx, ny) (VALID(nx, ny) ? grid[(ny) * width + (nx)] : STONE)
    #define SET(nx, ny, val) if (VALID(nx, ny)) new_grid[(ny) * width + (nx)] = val
    
    // Sand physics
    if (cell == SAND) {
        if (y < height - 1) {
            int below = GET(x, y + 1);
            if (below == EMPTY) {
                SET(x, y, EMPTY);
                SET(x, y + 1, SAND);
            }
            else if (below == WATER) {
                SET(x, y, WATER);
                SET(x, y + 1, SAND);
            }
            else {
                // Try diagonal
                int diag_x = x + rand_dir;
                if (VALID(diag_x, y + 1) && GET(diag_x, y + 1) == EMPTY) {
                    SET(x, y, EMPTY);
                    SET(diag_x, y + 1, SAND);
                }
            }
        }
    }
    
    // Water physics
    else if (cell == WATER) {
        if (y < height - 1 && GET(x, y + 1) == EMPTY) {
            SET(x, y, EMPTY);
            SET(x, y + 1, WATER);
        }
        else if (y < height - 1) {
            // Try diagonal down
            int diag_x = x + rand_dir;
            if (VALID(diag_x, y + 1) && GET(diag_x, y + 1) == EMPTY) {
                SET(x, y, EMPTY);
                SET(diag_x, y + 1, WATER);
            }
            else {
                // Try horizontal spread
                int side_x = x + rand_dir;
                if (VALID(side_x, y) && GET(side_x, y) == EMPTY) {
                    SET(x, y, EMPTY);
                    SET(side_x, y, WATER);
                }
            }
        }
    }
    
    // Fire physics
    else if (cell == FIRE) {
        // Fire rises and dies out
        if (rand_val % 10 < 3) {
            SET(x, y, EMPTY); // Fire dies
        }
        else if (y > 0 && GET(x, y - 1) == EMPTY) {
            SET(x, y, EMPTY);
            SET(x, y - 1, FIRE);
        }
        
        // Fire ignites wood
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WOOD) {
                    if (rand_val % 20 == 0) {
                        SET(x + dx, y + dy, FIRE);
                    }
                }
            }
        }
        
        // Fire turns water to steam
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WATER) {
                    if (rand_val % 5 == 0) {
                        SET(x + dx, y + dy, STEAM);
                        SET(x, y, EMPTY);
                    }
                }
            }
        }
    }
    
    // Steam physics
    else if (cell == STEAM) {
        if (rand_val % 100 < 2) {
            SET(x, y, WATER); // Condense back to water
        }
        else if (y > 0 && GET(x, y - 1) == EMPTY) {
            SET(x, y, EMPTY);
            SET(x, y - 1, STEAM);
        }
        else {
            int side_x = x + rand_dir;
            if (VALID(side_x, y) && GET(side_x, y) == EMPTY) {
                SET(x, y, EMPTY);
                SET(side_x, y, STEAM);
            }
        }
    }
    
    #undef VALID
    #undef GET
    #undef SET
}

// CUDA kernel for rendering to RGB buffer
__global__ void render_to_rgb(unsigned char* grid, unsigned char* rgb_buffer, 
                              int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (x >= width || y >= height) return;
    
    int idx = y * width + x;
    unsigned char cell = grid[idx];
    Color c = get_color(cell);
    
    int rgb_idx = idx * 3;
    rgb_buffer[rgb_idx] = c.r;
    rgb_buffer[rgb_idx + 1] = c.g;
    rgb_buffer[rgb_idx + 2] = c.b;
}

void write_ppm(const char* filename, unsigned char* rgb_data, int width, int height) {
    FILE* fp = fopen(filename, "wb");
    if (!fp) return;
    
    fprintf(fp, "P6\n%d %d\n255\n", width, height);
    fwrite(rgb_data, 1, width * height * 3, fp);
    fclose(fp);
}

void add_particles(unsigned char* grid, int mouse_x, int mouse_y, 
                  unsigned char particle_type, int brush_size) {
    for (int dy = -brush_size; dy <= brush_size; dy++) {
        for (int dx = -brush_size; dx <= brush_size; dx++) {
            if (dx*dx + dy*dy <= brush_size*brush_size) {
                int x = mouse_x + dx;
                int y = mouse_y + dy;
                if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
                    grid[y * WIDTH + x] = particle_type;
                }
            }
        }
    }
}

int main() {
    printf("GPU-Accelerated Falling Sand Simulation\n");
    printf("========================================\n");
    printf("Simulating %dx%d grid with cellular automaton physics\n\n", WIDTH, HEIGHT);
    
    // Allocate host memory
    size_t grid_size = WIDTH * HEIGHT * sizeof(unsigned char);
    size_t rgb_size = WIDTH * HEIGHT * 3 * sizeof(unsigned char);
    
    unsigned char* h_grid = (unsigned char*)malloc(grid_size);
    unsigned char* h_rgb = (unsigned char*)malloc(rgb_size);
    memset(h_grid, EMPTY, grid_size);
    
    // Allocate device memory
    unsigned char *d_grid, *d_new_grid, *d_rgb;
    unsigned int *d_rand_state;
    
    cudaMalloc(&d_grid, grid_size);
    cudaMalloc(&d_new_grid, grid_size);
    cudaMalloc(&d_rgb, rgb_size);
    cudaMalloc(&d_rand_state, sizeof(unsigned int));
    
    // Initialize random state
    unsigned int h_rand = (unsigned int)time(NULL);
    cudaMemcpy(d_rand_state, &h_rand, sizeof(unsigned int), cudaMemcpyHostToDevice);
    
    // Set up initial scene
    printf("Setting up initial scene...\n");
    
    // Add some sand at the top
    for (int i = 0; i < 50; i++) {
        int x = WIDTH / 4 + rand() % (WIDTH / 2);
        int y = 10 + rand() % 50;
        add_particles(h_grid, x, y, SAND, 2);
    }
    
    // Add water sources
    for (int i = 0; i < 30; i++) {
        int x = WIDTH / 3 + rand() % (WIDTH / 3);
        int y = 100 + rand() % 50;
        add_particles(h_grid, x, y, WATER, 3);
    }
    
    // Add stone platforms
    for (int x = WIDTH / 4; x < 3 * WIDTH / 4; x++) {
        h_grid[(HEIGHT / 2) * WIDTH + x] = STONE;
    }
    
    for (int x = WIDTH / 6; x < 5 * WIDTH / 6; x++) {
        h_grid[(3 * HEIGHT / 4) * WIDTH + x] = STONE;
    }
    
    // Add wood blocks
    for (int y = HEIGHT / 2 - 30; y < HEIGHT / 2; y++) {
        for (int x = WIDTH / 2 - 20; x < WIDTH / 2 + 20; x++) {
            if (h_grid[y * WIDTH + x] == EMPTY) {
                h_grid[y * WIDTH + x] = WOOD;
            }
        }
    }
    
    // Add some fire
    for (int i = 0; i < 10; i++) {
        int x = WIDTH / 2 + (rand() % 20 - 10);
        int y = HEIGHT / 2 - 35;
        add_particles(h_grid, x, y, FIRE, 1);
    }
    
    cudaMemcpy(d_grid, h_grid, grid_size, cudaMemcpyHostToDevice);
    
    // Set up CUDA grid dimensions
    dim3 block_size(16, 16);
    dim3 grid_dim((WIDTH + block_size.x - 1) / block_size.x,
                  (HEIGHT + block_size.y - 1) / block_size.y);
    
    printf("Running simulation...\n");
    printf("Grid blocks: %dx%d, Threads per block: %dx%d\n\n", 
           grid_dim.x, grid_dim.y, block_size.x, block_size.y);
    
    // Simulation loop
    int num_frames = 300;
    int save_interval = 30;
    
    clock_t start = clock();
    
    for (int frame = 0; frame < num_frames; frame++) {
        // Update random state
        h_rand = h_rand * 1103515245 + 12345;
        cudaMemcpy(d_rand_state, &h_rand, sizeof(unsigned int), cudaMemcpyHostToDevice);
        
        // Update particles
        update_particles<<<grid_dim, block_size>>>(d_grid, d_new_grid, WIDTH, HEIGHT, d_rand_state);
        cudaDeviceSynchronize();
        
        // Swap buffers
        unsigned char* temp = d_grid;
        d_grid = d_new_grid;
        d_new_grid = temp;
        
        // Save frames periodically
        if (frame % save_interval == 0) {
            render_to_rgb<<<grid_dim, block_size>>>(d_grid, d_rgb, WIDTH, HEIGHT);
            cudaDeviceSynchronize();
            
            cudaMemcpy(h_rgb, d_rgb, rgb_size, cudaMemcpyDeviceToHost);
            
            char filename[64];
            sprintf(filename, "frame_%04d.ppm", frame);
            write_ppm(filename, h_rgb, WIDTH, HEIGHT);
            
            printf("Frame %d/%d saved\n", frame, num_frames);
        }
    }
    
    clock_t end = clock();
    double elapsed = (double)(end - start) / CLOCKS_PER_SEC;
    
    printf("\nSimulation complete!\n");
    printf("Total frames: %d\n", num_frames);
    printf("Time elapsed: %.2f seconds\n", elapsed);
    printf("FPS: %.2f\n", num_frames / elapsed);
    printf("\nOutput images saved as frame_*.ppm\n");
    printf("Convert to GIF with: convert -delay 3 frame_*.ppm animation.gif\n");
    
    // Cleanup
    cudaFree(d_grid);
    cudaFree(d_new_grid);
    cudaFree(d_rgb);
    cudaFree(d_rand_state);
    free(h_grid);
    free(h_rgb);
    
    return 0;
}
