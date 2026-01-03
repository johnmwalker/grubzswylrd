NVCC = nvcc
CFLAGS = -O3 -arch=sm_75
GLFW_LIBS = -lGL -lGLEW -lglfw
GTK_CFLAGS = $(shell pkg-config --cflags gtk4 | sed 's/ -m[^ ]*//g; s/ -pthread//g')
GTK_LIBS = $(shell pkg-config --libs gtk4)

# Targets
TARGET_CLI = falling_sand
TARGET_GUI_GLFW = falling_sand_gui
TARGET_GUI_GTK = falling_sand_gtk
SOURCE_CLI = falling_sand.cu
SOURCE_GUI_GLFW = falling_sand_gui.cu
SOURCE_GUI_GTK = falling_sand_gtk.cu

all: $(TARGET_CLI) $(TARGET_GUI_GTK)

# CLI version (original)
$(TARGET_CLI): $(SOURCE_CLI)
	$(NVCC) $(CFLAGS) -o $(TARGET_CLI) $(SOURCE_CLI)

# GUI version (GLFW/OpenGL)
$(TARGET_GUI_GLFW): $(SOURCE_GUI_GLFW)
	$(NVCC) $(CFLAGS) -o $(TARGET_GUI_GLFW) $(SOURCE_GUI_GLFW) $(GLFW_LIBS)

# GUI version (GTK4)
$(TARGET_GUI_GTK): $(SOURCE_GUI_GTK)
	$(NVCC) $(CFLAGS) $(GTK_CFLAGS) -o $(TARGET_GUI_GTK) $(SOURCE_GUI_GTK) $(GTK_LIBS)

clean:
	rm -f $(TARGET_CLI) $(TARGET_GUI_GLFW) $(TARGET_GUI_GTK) frame_*.ppm animation.gif

run_cli: $(TARGET_CLI)
	./$(TARGET_CLI)

run_gui: $(TARGET_GUI_GTK)
	./$(TARGET_GUI_GTK)

run_gui_glfw: $(TARGET_GUI_GLFW)
	./$(TARGET_GUI_GLFW)

.PHONY: all clean run_cli run_gui run_gui_glfw
