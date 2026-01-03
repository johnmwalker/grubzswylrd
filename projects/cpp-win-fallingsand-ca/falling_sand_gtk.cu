#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <cuda_runtime.h>
#include <gtk/gtk.h>
#include <pango/pango.h>

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
typedef struct {
    unsigned char* d_grid;
    unsigned char* d_new_grid;
    unsigned char* d_rgba;
    unsigned int* d_rand_state;
    unsigned char* h_rgba;
    unsigned int h_rand;
    
    unsigned char current_particle;
    gboolean mouse_down;
    double mouse_x;
    double mouse_y;
    
    GtkWidget* drawing_area;
    guint timeout_id;
    int frame_count;
    
    dim3 block_size;
    dim3 grid_dim;
} SimulatorState;

// Colors (RGBA)
typedef struct {
    unsigned char r, g, b, a;
} Color;

__device__ Color get_color(unsigned char type, unsigned int rand_val) {
    Color c;
    c.a = 255;
    
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
        
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (VALID(x + dx, y + dy) && GET(x + dx, y + dy) == WOOD && rand_val % 30 == 0) {
                    SET(x + dx, y + dy, FIRE);
                }
            }
        }
        
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
    
    int rgba_idx = idx * 4;
    rgba_buffer[rgba_idx] = c.r;
    rgba_buffer[rgba_idx + 1] = c.g;
    rgba_buffer[rgba_idx + 2] = c.b;
    rgba_buffer[rgba_idx + 3] = c.a;
}

void add_particles(unsigned char* h_grid, int mx, int my, 
                  unsigned char particle_type, int brush_size) {
    for (int dy = -brush_size; dy <= brush_size; dy++) {
        for (int dx = -brush_size; dx <= brush_size; dx++) {
            if (dx*dx + dy*dy <= brush_size*brush_size) {
                int x = mx + dx;
                int y = my + dy;
                if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
                    h_grid[y * WIDTH + x] = particle_type;
                }
            }
        }
    }
}

// GTK drawing callback
static void draw_function(GtkDrawingArea* area, cairo_t* cr, 
                         int width, int height, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    
    // Create Cairo surface from RGBA data
    cairo_surface_t* surface = cairo_image_surface_create_for_data(
        state->h_rgba,
        CAIRO_FORMAT_RGB24,
        WIDTH,
        HEIGHT,
        cairo_format_stride_for_width(CAIRO_FORMAT_RGB24, WIDTH)
    );
    
    // Scale to fit window if needed
    double scale_x = (double)width / WIDTH;
    double scale_y = (double)height / HEIGHT;
    cairo_scale(cr, scale_x, scale_y);
    
    // Draw the surface
    cairo_set_source_surface(cr, surface, 0, 0);
    cairo_paint(cr);
    
    cairo_surface_destroy(surface);
}

// Simulation update callback
static gboolean update_simulation(gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    
    // Handle mouse input
    if (state->mouse_down) {
        size_t grid_size = WIDTH * HEIGHT * sizeof(unsigned char);
        unsigned char* h_grid = (unsigned char*)malloc(grid_size);
        
        cudaMemcpy(h_grid, state->d_grid, grid_size, cudaMemcpyDeviceToHost);
        add_particles(h_grid, (int)state->mouse_x, (int)state->mouse_y, 
                     state->current_particle, BRUSH_SIZE);
        cudaMemcpy(state->d_grid, h_grid, grid_size, cudaMemcpyHostToDevice);
        
        free(h_grid);
    }
    
    // Update simulation
    state->h_rand = state->h_rand * 1103515245 + 12345;
    cudaMemcpy(state->d_rand_state, &state->h_rand, sizeof(unsigned int), 
               cudaMemcpyHostToDevice);
    
    update_particles<<<state->grid_dim, state->block_size>>>(
        state->d_grid, state->d_new_grid, WIDTH, HEIGHT, state->d_rand_state);
    cudaDeviceSynchronize();
    
    // Swap buffers
    unsigned char* temp = state->d_grid;
    state->d_grid = state->d_new_grid;
    state->d_new_grid = temp;
    
    // Render
    render_to_rgba<<<state->grid_dim, state->block_size>>>(
        state->d_grid, state->d_rgba, WIDTH, HEIGHT, state->d_rand_state);
    cudaDeviceSynchronize();
    
    size_t rgba_size = WIDTH * HEIGHT * 4 * sizeof(unsigned char);
    cudaMemcpy(state->h_rgba, state->d_rgba, rgba_size, cudaMemcpyDeviceToHost);
    
    // Request redraw
    if (state->drawing_area != NULL) {
        gtk_widget_queue_draw(state->drawing_area);
    }
    
    state->frame_count++;
    
    return G_SOURCE_CONTINUE;
}

// Mouse button press callback
static void pressed(GtkGestureClick* gesture, int n_press, 
                   double x, double y, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    if (state->drawing_area == NULL) return;
    
    state->mouse_down = TRUE;
    
    // Scale mouse coordinates to grid
    int widget_width = gtk_widget_get_width(state->drawing_area);
    int widget_height = gtk_widget_get_height(state->drawing_area);
    state->mouse_x = (x / widget_width) * WIDTH;
    state->mouse_y = (y / widget_height) * HEIGHT;
}

// Mouse button release callback
static void released(GtkGestureClick* gesture, int n_press, 
                    double x, double y, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    state->mouse_down = FALSE;
}

// Mouse motion callback
static void motion(GtkEventControllerMotion* controller, 
                  double x, double y, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    if (state->drawing_area == NULL) return;
    
    // Scale mouse coordinates to grid
    int widget_width = gtk_widget_get_width(state->drawing_area);
    int widget_height = gtk_widget_get_height(state->drawing_area);
    state->mouse_x = (x / widget_width) * WIDTH;
    state->mouse_y = (y / widget_height) * HEIGHT;
}

// Key press callback
static gboolean key_pressed(GtkEventControllerKey* controller, guint keyval,
                           guint keycode, GdkModifierType state_mod, 
                           gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    
    switch(keyval) {
        case GDK_KEY_1:
            state->current_particle = SAND;
            g_print("Selected: SAND\n");
            break;
        case GDK_KEY_2:
            state->current_particle = WATER;
            g_print("Selected: WATER\n");
            break;
        case GDK_KEY_3:
            state->current_particle = STONE;
            g_print("Selected: STONE\n");
            break;
        case GDK_KEY_4:
            state->current_particle = FIRE;
            g_print("Selected: FIRE\n");
            break;
        case GDK_KEY_5:
            state->current_particle = WOOD;
            g_print("Selected: WOOD\n");
            break;
        case GDK_KEY_6:
            state->current_particle = STEAM;
            g_print("Selected: STEAM\n");
            break;
        case GDK_KEY_7:
            state->current_particle = LAVA;
            g_print("Selected: LAVA\n");
            break;
        case GDK_KEY_c:
        case GDK_KEY_C:
            // Clear grid
            {
                size_t grid_size = WIDTH * HEIGHT * sizeof(unsigned char);
                cudaMemset(state->d_grid, EMPTY, grid_size);
                g_print("Grid cleared\n");
            }
            break;
        case GDK_KEY_Escape:
            if (state->drawing_area != NULL) {
                g_application_quit(G_APPLICATION(gtk_window_get_application(
                    GTK_WINDOW(gtk_widget_get_root(state->drawing_area)))));
            }
            break;
    }
    
    return TRUE;
}

static void create_simulation_window(GtkApplication* app, SimulatorState* state);

static void start_simulation(GtkButton* button, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    
    // Hide title screen
    GtkWidget* title_window = GTK_WIDGET(gtk_widget_get_root(GTK_WIDGET(button)));
    gtk_widget_set_visible(title_window, FALSE);
    
    // Create and show simulation window
    create_simulation_window(GTK_APPLICATION(gtk_window_get_application(GTK_WINDOW(title_window))), state);
}

static void create_simulation_window(GtkApplication* app, SimulatorState* state) {
    // Create window
    GtkWidget* window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "GPU Falling Sand Simulator");
    gtk_window_set_default_size(GTK_WINDOW(window), WIDTH, HEIGHT);
    
    // Create drawing area
    state->drawing_area = gtk_drawing_area_new();
    gtk_drawing_area_set_content_width(GTK_DRAWING_AREA(state->drawing_area), WIDTH);
    gtk_drawing_area_set_content_height(GTK_DRAWING_AREA(state->drawing_area), HEIGHT);
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(state->drawing_area), 
                                   draw_function, state, NULL);
    
    // Set up mouse gestures
    GtkGesture* click = gtk_gesture_click_new();
    gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(click), GDK_BUTTON_PRIMARY);
    g_signal_connect(click, "pressed", G_CALLBACK(pressed), state);
    g_signal_connect(click, "released", G_CALLBACK(released), state);
    gtk_widget_add_controller(state->drawing_area, GTK_EVENT_CONTROLLER(click));
    
    GtkEventController* motion_controller = gtk_event_controller_motion_new();
    g_signal_connect(motion_controller, "motion", G_CALLBACK(motion), state);
    gtk_widget_add_controller(state->drawing_area, motion_controller);
    
    // Set up keyboard
    GtkEventController* key_controller = gtk_event_controller_key_new();
    g_signal_connect(key_controller, "key-pressed", G_CALLBACK(key_pressed), state);
    gtk_widget_add_controller(window, key_controller);
    
    gtk_window_set_child(GTK_WINDOW(window), state->drawing_area);
    gtk_window_present(GTK_WINDOW(window));
    
    // Start simulation timer (30 FPS)
    state->timeout_id = g_timeout_add(8, update_simulation, state);
}

static void activate(GtkApplication* app, gpointer user_data) {
    SimulatorState* state = (SimulatorState*)user_data;
    
    // Create title screen window
    GtkWidget* title_window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(title_window), "Falling Sand Simulator");
    gtk_window_set_default_size(GTK_WINDOW(title_window), 400, 300);
    
    // Create main box
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
    gtk_widget_set_margin_start(box, 20);
    gtk_widget_set_margin_end(box, 20);
    gtk_widget_set_margin_top(box, 20);
    gtk_widget_set_margin_bottom(box, 20);
    
    // Create title label
    GtkWidget* title_label = gtk_label_new("falling sand wowe");
    PangoAttrList* attrs = pango_attr_list_new();
    PangoAttribute* size_attr = pango_attr_size_new_absolute(24 * PANGO_SCALE);
    PangoAttribute* weight_attr = pango_attr_weight_new(PANGO_WEIGHT_BOLD);
    pango_attr_list_insert(attrs, size_attr);
    pango_attr_list_insert(attrs, weight_attr);
    gtk_label_set_attributes(GTK_LABEL(title_label), attrs);
    pango_attr_list_unref(attrs);
    
    // Create start button
    GtkWidget* start_button = gtk_button_new_with_label("Start");
    gtk_widget_set_size_request(start_button, 100, 40);
    g_signal_connect(start_button, "clicked", G_CALLBACK(start_simulation), state);
    
    // Pack widgets
    gtk_box_append(GTK_BOX(box), title_label);
    gtk_box_append(GTK_BOX(box), start_button);
    
    gtk_window_set_child(GTK_WINDOW(title_window), box);
    gtk_window_present(GTK_WINDOW(title_window));
}

int main(int argc, char** argv) {
    printf("GPU-Accelerated Falling Sand Simulation (GTK GUI)\n");
    printf("==================================================\n");
    printf("Controls:\n");
    printf("  1-7    - Select particle type\n");
    printf("  Mouse  - Draw particles\n");
    printf("  C      - Clear grid\n");
    printf("  ESC    - Exit\n\n");
    
    // Initialize CUDA
    SimulatorState state = {0};
    state.current_particle = SAND;
    state.mouse_down = FALSE;
    state.frame_count = 0;
    
    size_t grid_size = WIDTH * HEIGHT * sizeof(unsigned char);
    size_t rgba_size = WIDTH * HEIGHT * 4 * sizeof(unsigned char);
    
    cudaMalloc(&state.d_grid, grid_size);
    cudaMalloc(&state.d_new_grid, grid_size);
    cudaMalloc(&state.d_rgba, rgba_size);
    cudaMalloc(&state.d_rand_state, sizeof(unsigned int));
    
    state.h_rgba = (unsigned char*)malloc(rgba_size);
    state.h_rand = (unsigned int)time(NULL);
    
    cudaMemset(state.d_grid, EMPTY, grid_size);
    cudaMemcpy(state.d_rand_state, &state.h_rand, sizeof(unsigned int), 
               cudaMemcpyHostToDevice);
    
    state.block_size = dim3(16, 16);
    state.grid_dim = dim3((WIDTH + state.block_size.x - 1) / state.block_size.x,
                         (HEIGHT + state.block_size.y - 1) / state.block_size.y);
    
    printf("CUDA initialized: %dx%d grid, %dx%d blocks\n\n", 
           state.grid_dim.x, state.grid_dim.y, 
           state.block_size.x, state.block_size.y);
    
    // Create GTK application
    GtkApplication* app = gtk_application_new("com.example.fallingsand", 
                                             G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), &state);
    
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    
    // Cleanup
    g_source_remove(state.timeout_id);
    g_object_unref(app);
    
    cudaFree(state.d_grid);
    cudaFree(state.d_new_grid);
    cudaFree(state.d_rgba);
    cudaFree(state.d_rand_state);
    free(state.h_rgba);
    
    printf("\nSimulation ended after %d frames\n", state.frame_count);
    
    return status;
}
