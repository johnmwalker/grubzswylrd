#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <GL/glew.h>
#include <GLFW/glfw3.h>

// Window dimensions
#define WIDTH 1200
#define HEIGHT 800
#define BRUSH_SIZE 8

// Particle types
#define EMPTY 0
#define SAND 1
#define WATER 2
#define STONE 3
#define FIRE 4
#define WOOD 5
#define STEAM 6
#define LAVA 7

// Global state
unsigned char current_particle = SAND;
bool mouse_down = false;
double mouse_x = 0, mouse_y = 0;

// Colors (RGBA)
typedef struct {
    unsigned char r, g, b, a;
} Color;

__device__ Color get_color(unsigned char type, unsigned int rand_val) {
    Color c;
    c.a = 255;
    
    // Add slight color variation for visual interest
    int variation = (rand_val % 20) - 10;
    
    switch(type) {
        case SAND:
            c.r = 194 + variation; 
            c.g = 178 + variation; 
            c.b = 128 + variation;
            break;
        case WATER:
            c.r = 64; 
            c.g = 164 + variation; 
            c.b = 223 + variation;
            break;
        case STONE:
            c.r = 128 + variation; 
            c.g = 128 + variation; 
            c.b = 128 + variation;
            break;
        case FIRE:
            c.r = 255; 
            c.g = 100 + (rand_val % 100); 
            c.b = 0;
            break;
        case WOOD:
            c.r = 139 + variation; 
            c.g = 90 + variation; 
            c.b = 43;
            break;
        case STEAM:
            c.r = 200 + variation; 
            c.g = 200 + variation; 
            c.b = 200 + variation;
            break;
        case LAVA:
            c.r = 255; 
            c.g = 69 + (rand_val % 50); 
            c.b = 0;
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
    
    unsigned int rand_val = (rand_state[0] + idx * 1103515245 + 12345) & 0x7FFFFFFF;
    int rand_dir = (rand_val % 3) - 1;
    
    new_grid[idx] = cell;
    
    if (cell == EMPTY) return;
    
    #define VALID(nx, ny) ((nx) >= 0 && (nx) < width && (ny) >= 0 && (ny) < height)
    #define GET(nx, ny) (VALID(nx, ny) ? grid[(ny) * width + (nx)] : STONE)
    #define SET(nx, ny, val) if (VALID(nx, ny)) new_grid[(ny) * width + (nx)] = val
    
    // Sand physics
    if (cell == SAND) {
        if (y < height - 1) {
            int below = GET(x, y + 1);
            if (below == EMPTY || below == WATER) {
                SET(x, y, below);
                SET(x, y + 1, SAND);
            }
            else {
                int diag_x = x + rand_dir;
                if (VALID(diag_x, y + 1) && (GET(diag_x, y + 1) == EMPTY || GET(diag_x, y + 1) == WATER)) {
                    SET(x, y, GET(diag_x, y + 1));
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
            int diag_x = x + rand_dir;
            if (VALID(diag_x, y + 1) && GET(diag_x, y + 1) == EMPTY) {
                SET(x, y, EMPTY);
                SET(diag_x, y + 1, WATER);
            }
            else {
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
        if (rand_val % 10 < 2) {
            SET(x, y, EMPTY);
        }
        else if (y > 0 && GET(x, y - 1) == EMPTY && rand_val % 3 == 0) {
            SET(x, y, EMPTY);
            SET(x, y - 1, FIRE);
        }
        
        // Spread fire to adjacent wood
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WOOD && rand_val % 30 == 0) {
                    SET(x + dx, y + dy, FIRE);
                }
            }
        }
        
        // Turn water to steam
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WATER && rand_val % 8 == 0) {
                    SET(x + dx, y + dy, STEAM);
                    if (rand_val % 2 == 0) SET(x, y, EMPTY);
                }
            }
        }
    }
    
    // Steam physics
    else if (cell == STEAM) {
        if (rand_val % 200 < 1) {
            SET(x, y, WATER);
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
    
    // Lava physics
    else if (cell == LAVA) {
        if (y < height - 1 && GET(x, y + 1) == EMPTY) {
            SET(x, y, EMPTY);
            SET(x, y + 1, LAVA);
        }
        else if (y < height - 1 && GET(x, y + 1) == WATER) {
            SET(x, y, STONE);
            SET(x, y + 1, STEAM);
        }
        else {
            int diag_x = x + rand_dir;
            if (VALID(diag_x, y + 1) && GET(diag_x, y + 1) == EMPTY) {
                SET(x, y, EMPTY);
                SET(diag_x, y + 1, LAVA);
            }
            else if (rand_val % 4 == 0) {
                int side_x = x + rand_dir;
                if (VALID(side_x, y) && GET(side_x, y) == EMPTY) {
                    SET(x, y, EMPTY);
                    SET(side_x, y, LAVA);
                }
            }
        }
        
        // Lava ignites wood
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WOOD && rand_val % 20 == 0) {
                    SET(x + dx, y + dy, FIRE);
                }
            }
        }
    }
    
    #undef VALID
    #undef GET
    #undef SET
}

// CUDA kernel for rendering to RGBA buffer
__global__ void render_to_rgba(unsigned char* grid, unsigned char* rgba_buffer, 
                               int width, int height, unsigned int* rand_state) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (x >= width || y >= height) return;
    
    int idx = y * width + x;
    unsigned char cell = grid[idx];
    
    unsigned int rand_val = (rand_state[0] + idx * 7919) & 0x7FFFFFFF;
    Color c = get_color(cell, rand_val);
    
    // Flip Y for OpenGL
    int flipped_y = height - 1 - y;
    int rgba_idx = (flipped_y * width + x) * 4;
    
    rgba_buffer[rgba_idx] = c.r;
    rgba_buffer[rgba_idx + 1] = c.g;
    rgba_buffer[rgba_idx + 2] = c.b;
    rgba_buffer[rgba_idx + 3] = c.a;
}

// Mouse button callback
void mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
    if (button == GLFW_MOUSE_BUTTON_LEFT) {
        mouse_down = (action == GLFW_PRESS);
    }
}

// Mouse position callback
void cursor_position_callback(GLFWwindow* window, double xpos, double ypos) {
    mouse_x = xpos;
    mouse_y = ypos;
}

// Key callback for selecting particle types
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (action == GLFW_PRESS) {
        switch(key) {
            case GLFW_KEY_1: current_particle = SAND; printf("Selected: SAND\n"); break;
            case GLFW_KEY_2: current_particle = WATER; printf("Selected: WATER\n"); break;
            case GLFW_KEY_3: current_particle = STONE; printf("Selected: STONE\n"); break;
            case GLFW_KEY_4: current_particle = FIRE; printf("Selected: FIRE\n"); break;
            case GLFW_KEY_5: current_particle = WOOD; printf("Selected: WOOD\n"); break;
            case GLFW_KEY_6: current_particle = STEAM; printf("Selected: STEAM\n"); break;
            case GLFW_KEY_7: current_particle = LAVA; printf("Selected: LAVA\n"); break;
            case GLFW_KEY_ESCAPE: glfwSetWindowShouldClose(window, GLFW_TRUE); break;
        }
    }
}

void add_particles(unsigned char* grid, int mx, int my, unsigned char particle_type, int brush_size) {
    for (int dy = -brush_size; dy <= brush_size; dy++) {
        for (int dx = -brush_size; dx <= brush_size; dx++) {
            if (dx*dx + dy*dy <= brush_size*brush_size) {
                int x = mx + dx;
                int y = my + dy;
                if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
                    grid[y * WIDTH + x] = particle_type;
                }
            }
        }
    }
}

int main() {
    printf("GPU-Accelerated Falling Sand Simulation (Real-Time GUI)\n");
    printf("========================================================\n");
    printf("Controls:\n");
    printf("  1 - Sand\n");
    printf("  2 - Water\n");
    printf("  3 - Stone\n");
    printf("  4 - Fire\n");
    printf("  5 - Wood\n");
    printf("  6 - Steam\n");
    printf("  7 - Lava\n");
    printf("  Left Mouse - Draw particles\n");
    printf("  ESC - Exit\n\n");
    
    // Initialize GLFW
    if (!glfwInit()) {
        fprintf(stderr, "Failed to initialize GLFW\n");
        return -1;
    }
    
    // Create window
    GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Falling Sand Simulator", NULL, NULL);
    if (!window) {
        fprintf(stderr, "Failed to create GLFW window\n");
        glfwTerminate();
        return -1;
    }
    
    glfwMakeContextCurrent(window);
    glfwSetMouseButtonCallback(window, mouse_button_callback);
    glfwSetCursorPosCallback(window, cursor_position_callback);
    glfwSetKeyCallback(window, key_callback);
    glfwSwapInterval(1); // VSync
    
    // Initialize GLEW
    glewExperimental = GL_TRUE;
    if (glewInit() != GLEW_OK) {
        fprintf(stderr, "Failed to initialize GLEW\n");
        return -1;
    }
    
    // Create OpenGL texture
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    // Allocate memory
    size_t grid_size = WIDTH * HEIGHT * sizeof(unsigned char);
    size_t rgba_size = WIDTH * HEIGHT * 4 * sizeof(unsigned char);
    
    unsigned char* h_grid = (unsigned char*)malloc(grid_size);
    memset(h_grid, EMPTY, grid_size);
    
    unsigned char *d_grid, *d_new_grid, *d_rgba;
    unsigned int *d_rand_state;
    
    cudaMalloc(&d_grid, grid_size);
    cudaMalloc(&d_new_grid, grid_size);
    cudaMalloc(&d_rgba, rgba_size);
    cudaMalloc(&d_rand_state, sizeof(unsigned int));
    
    unsigned int h_rand = (unsigned int)time(NULL);
    cudaMemcpy(d_rand_state, &h_rand, sizeof(unsigned int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_grid, h_grid, grid_size, cudaMemcpyHostToDevice);
    
    // CUDA grid dimensions
    dim3 block_size(16, 16);
    dim3 grid_dim((WIDTH + block_size.x - 1) / block_size.x,
                  (HEIGHT + block_size.y - 1) / block_size.y);
    
    unsigned char* h_rgba = (unsigned char*)malloc(rgba_size);
    
    int frame = 0;
    double last_fps_time = glfwGetTime();
    int fps_counter = 0;
    
    printf("Starting simulation...\n");
    
    // Main loop
    while (!glfwWindowShouldClose(window)) {
        // Handle mouse input
        if (mouse_down) {
            // Convert screen coordinates to grid coordinates
            int grid_x = (int)(mouse_x);
            int grid_y = (int)(mouse_y);
            
            cudaMemcpy(h_grid, d_grid, grid_size, cudaMemcpyDeviceToHost);
            add_particles(h_grid, grid_x, grid_y, current_particle, BRUSH_SIZE);
            cudaMemcpy(d_grid, h_grid, grid_size, cudaMemcpyHostToDevice);
        }
        
        // Update simulation
        h_rand = h_rand * 1103515245 + 12345;
        cudaMemcpy(d_rand_state, &h_rand, sizeof(unsigned int), cudaMemcpyHostToDevice);
        
        update_particles<<<grid_dim, block_size>>>(d_grid, d_new_grid, WIDTH, HEIGHT, d_rand_state);
        cudaDeviceSynchronize();
        
        // Swap buffers
        unsigned char* temp = d_grid;
        d_grid = d_new_grid;
        d_new_grid = temp;
        
        // Render to texture
        render_to_rgba<<<grid_dim, block_size>>>(d_grid, d_rgba, WIDTH, HEIGHT, d_rand_state);
        cudaDeviceSynchronize();
        
        cudaMemcpy(h_rgba, d_rgba, rgba_size, cudaMemcpyDeviceToHost);
        
        // Update OpenGL texture
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, h_rgba);
        
        // Draw textured quad
        glClear(GL_COLOR_BUFFER_BIT);
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, texture);
        
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(-1, -1);
        glTexCoord2f(1, 0); glVertex2f(1, -1);
        glTexCoord2f(1, 1); glVertex2f(1, 1);
        glTexCoord2f(0, 1); glVertex2f(-1, 1);
        glEnd();
        
        glfwSwapBuffers(window);
        glfwPollEvents();
        
        // FPS counter
        fps_counter++;
        double current_time = glfwGetTime();
        if (current_time - last_fps_time >= 1.0) {
            printf("FPS: %d\n", fps_counter);
            fps_counter = 0;
            last_fps_time = current_time;
        }
        
        frame++;
    }
    
    printf("\nSimulation ended after %d frames\n", frame);
    
    // Cleanup
    cudaFree(d_grid);
    cudaFree(d_new_grid);
    cudaFree(d_rgba);
    cudaFree(d_rand_state);
    free(h_grid);
    free(h_rgba);
    
    glDeleteTextures(1, &texture);
    glfwDestroyWindow(window);
    glfwTerminate();
    
    return 0;
}
