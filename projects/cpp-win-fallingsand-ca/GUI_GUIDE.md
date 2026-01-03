# Real-Time GUI Version Setup Guide

## Additional Prerequisites for GUI

The GUI version requires OpenGL libraries in addition to CUDA:

### WSL2 (Recommended)

```bash
# Install OpenGL libraries
sudo apt update
sudo apt install -y libglfw3-dev libglew-dev libgl1-mesa-dev

# For X11 support in WSL2
sudo apt install -y x11-apps

# Install VcXsrv or X410 on Windows to display GUI
# Download VcXsrv: https://sourceforge.net/projects/vcxsrv/
# Or X410 from Microsoft Store (paid)
```

**Setting up X11 forwarding in WSL2:**

1. Install VcXsrv on Windows
2. Launch XLaunch with these settings:
   - Display: Multiple windows
   - Client startup: Start no client
   - Extra settings: ✓ Disable access control
3. In WSL, set the DISPLAY variable:
```bash
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
# Add to ~/.bashrc to make permanent
echo 'export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '"'"'{print $2}'"'"'):0' >> ~/.bashrc
```

### Native Linux

```bash
# Ubuntu/Debian
sudo apt install -y libglfw3-dev libglew-dev libgl1-mesa-dev

# Fedora
sudo dnf install -y glfw-devel glew-devel mesa-libGL-devel

# Arch
sudo pacman -S glfw-x11 glew mesa
```

### Windows Native (Visual Studio)

Download and install:
1. **GLFW**: https://www.glfw.org/download.html
2. **GLEW**: http://glew.sourceforge.net/

Or use vcpkg:
```cmd
vcpkg install glfw3:x64-windows glew:x64-windows
```

---

## Compiling

### Both Versions (CLI + GUI)
```bash
make
```

### GUI Only
```bash
make falling_sand_gui
```

### CLI Only
```bash
make falling_sand
```

---

## Running the GUI Version

```bash
./falling_sand_gui
```

Or with make:
```bash
make run_gui
```

---

## Controls

### Keyboard
- **1** - Select Sand
- **2** - Select Water
- **3** - Select Stone
- **4** - Select Fire
- **5** - Select Wood
- **6** - Select Steam
- **7** - Select Lava
- **ESC** - Exit

### Mouse
- **Left Click + Drag** - Draw particles
- Brush size is 8 pixels (defined in code as `BRUSH_SIZE`)

---

## Usage Tips

### Creating Structures
1. Press **3** to select Stone
2. Click and drag to create platforms
3. Press **5** to select Wood
4. Draw wood structures on top

### Making Fire
1. Press **4** to select Fire
2. Click near wood to ignite it
3. Watch it spread!

### Water and Lava Interaction
1. Press **2** for Water
2. Draw a pool of water
3. Press **7** for Lava
4. Pour lava into water
5. Watch it turn to stone with steam!

### Sand Piles
1. Press **1** for Sand
2. Hold mouse button and move slowly
3. Watch realistic sand physics

---

## Performance

The GUI version runs at your monitor's refresh rate (typically 60 FPS with VSync enabled).

If you want uncapped FPS:
1. Change `glfwSwapInterval(1)` to `glfwSwapInterval(0)` in the code
2. Recompile

Expected performance:
- **WSL2 with X11**: 60 FPS (limited by X11 forwarding)
- **Native Linux**: 200-500+ FPS (GPU-limited)
- **Windows Native**: 200-500+ FPS (GPU-limited)

---

## Customization

### Change Window Size

Edit these lines in `falling_sand_gui.cu`:
```c
#define WIDTH 1200
#define HEIGHT 800
```

### Change Brush Size

Edit this line:
```c
#define BRUSH_SIZE 8  // Radius in pixels
```

### Add More Particle Types

1. Define new constant:
```c
#define OIL 8
```

2. Add color in `get_color()`:
```c
case OIL:
    c.r = 139; c.g = 90; c.b = 0;
    break;
```

3. Add physics in `update_particles()`:
```c
else if (cell == OIL) {
    // Oil floats on water, falls through air
    // Add your physics logic here
}
```

4. Add keyboard shortcut in `key_callback()`:
```c
case GLFW_KEY_8: 
    current_particle = OIL; 
    printf("Selected: OIL\n"); 
    break;
```

---

## Troubleshooting

### "cannot open display"
Your X server isn't running or DISPLAY isn't set correctly.

**WSL2:**
```bash
# Check DISPLAY
echo $DISPLAY

# Should output something like: 172.x.x.x:0
# If empty, set it:
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0

# Test with:
xclock
```

### "Failed to initialize GLFW"
OpenGL libraries not installed:
```bash
sudo apt install -y libglfw3-dev libglew-dev libgl1-mesa-dev
```

### "undefined reference to 'glfw...'"
Linking issue. Make sure you're using the GUI Makefile target:
```bash
make clean
make falling_sand_gui
```

### Black screen / No particles visible
Try clicking and dragging - the simulation starts empty. Press number keys to select particles.

### Low FPS in WSL2
This is normal - X11 forwarding has overhead. For best performance:
- Use native Linux
- Or use Windows native compilation
- WSL2 is great for development, but X11 forwarding limits rendering

### VcXsrv connection issues (WSL2)
Make sure:
1. VcXsrv is running on Windows
2. "Disable access control" is checked
3. Windows Firewall allows VcXsrv
4. DISPLAY variable is set correctly

---

## Advanced: CUDA-OpenGL Interop

The current implementation copies data from GPU to CPU to texture. For even better performance, you can use CUDA-OpenGL interop to render directly from GPU memory:

```c
// Register OpenGL texture with CUDA
cudaGraphicsResource* cuda_resource;
cudaGraphicsGLRegisterImage(&cuda_resource, texture, GL_TEXTURE_2D, 
                            cudaGraphicsRegisterFlagsWriteDiscard);

// Map for CUDA access
cudaGraphicsMapResources(1, &cuda_resource);
cudaArray* cuda_array;
cudaGraphicsSubResourceGetMappedArray(&cuda_array, cuda_resource, 0, 0);

// Render directly to texture
cudaMemcpy2DToArray(cuda_array, 0, 0, d_rgba, 
                    WIDTH * 4, WIDTH * 4, HEIGHT, 
                    cudaMemcpyDeviceToDevice);

// Unmap
cudaGraphicsUnmapResources(1, &cuda_resource);
```

This eliminates the CPU copy and can boost FPS significantly!

---

## Comparison: CLI vs GUI

| Feature | CLI Version | GUI Version |
|---------|-------------|-------------|
| Real-time | ❌ | ✅ |
| Interactive | ❌ | ✅ |
| Output | PPM images | Live display |
| Performance | ~300 FPS | 60-500+ FPS |
| Mouse drawing | ❌ | ✅ |
| Dependencies | CUDA only | CUDA + OpenGL |
| Use case | Batch rendering | Interactive play |

---

## Next Steps

1. **Add more particles**: Try implementing oil, ice, or acid
2. **Add keyboard shortcuts**: Clear screen with 'C', pause with 'P'
3. **Add temperature**: Make particles have heat that transfers
4. **Make it 3D**: Extend to a 3D voxel simulation
5. **Add shaders**: Use GLSL for post-processing effects

Have fun experimenting with the simulation!
