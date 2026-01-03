NVCC = nvcc
CFLAGS = -O3 -arch=sm_50
TARGET = falling_sand
SOURCE = falling_sand.cu

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(NVCC) $(CFLAGS) -o $(TARGET) $(SOURCE)

clean:
	rm -f $(TARGET) frame_*.ppm animation.gif

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
