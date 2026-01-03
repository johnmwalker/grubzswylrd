# GTK Version Setup Guide

## Why GTK is Better for WSL2

GTK works **natively in WSL2** without requiring an X server! This is a huge advantage over the GLFW/OpenGL version:

✅ **No VcXsrv or X410 needed**
✅ **Better performance** - direct rendering
✅ **Easier setup** - fewer dependencies
✅ **Native look and feel** 
✅ **Works out of the box** in WSL2

---

## Installation

### WSL2 (Ubuntu/Debian)

```bash
# Update package lists
sudo apt update

# Install GTK4 development libraries
sudo apt install -y libgtk-4-dev

# Install CUDA if you haven't already (see SETUP_GUIDE.md)
# Install build tools
sudo apt install -y build-essential
```

That's it! No X server configuration needed.

### Native Linux

#### Ubuntu/Debian
```bash
sudo apt install -y libgtk-4-dev
```

#### Fedora
```bash
sudo dnf install -y gtk4-devel
```

#### Arch Linux
```bash
sudo pacman -S gtk4
```

---

## Compiling

```bash
# Build GTK version
make falling_sand_gtk

# Or build all versions
make
```

---

## Running

```bash
./falling_sand_gtk
```

Or with make:
```bash
make run_gui
```

The window should appear immediately without any X server configuration!

---

## Controls

### Keyboard
- **1** - Sand
- **2** - Water  
- **3** - Stone
- **4** - Fire
- **5** - Wood
- **6** - Steam
- **7** - Lava
- **C** - Clear grid
- **ESC** - Exit

### Mouse
- **Left Click + Drag** - Draw particles

---

## Features

### GTK-Specific Features
- **Native window resizing** - the simulation scales automatically
- **Better integration** with your desktop environment
- **Hardware acceleration** via Cairo
- **Cross-platform** - works on Linux, WSL2, macOS (with some setup)

### Performance
- Runs at ~30 FPS (configurable in code)
- Lower CPU overhead than GLFW version
- Better for laptops/lower-end systems
- Can increase frame rate by changing timeout value

---

## Troubleshooting

### "Package gtk4 was not found"

GTK4 isn't installed. Install it:
```bash
sudo apt install -y libgtk-4-dev
```

### "undefined reference to 'gtk_...'"

The compiler can't find GTK libraries. Make sure you're using the Makefile target:
```bash
make clean
make falling_sand_gtk
```

### Window doesn't appear in WSL2

Make sure you're using WSL2 (not WSL1):
```bash
wsl --list --verbose
```

If it shows VERSION 1, upgrade:
```bash
wsl --set-version Ubuntu 2
```

### Can't draw particles

Click and hold the left mouse button, then drag. Make sure you've selected a particle type with keys 1-7.

### Performance is slow

Try reducing the update frequency. Edit the code and change:
```c
state->timeout_id = g_timeout_add(33, update_simulation, state);
```

Change `33` to a lower number for faster updates (e.g., `16` for ~60 FPS).

---

## Customization

### Change Window Size

Edit in `falling_sand_gtk.cu`:
```c
#define WIDTH 1200
#define HEIGHT 800
```

### Change Update Rate

In the `activate` function, change the timeout value:
```c
// 33ms = ~30 FPS
// 16ms = ~60 FPS  
// 8ms = ~120 FPS
state->timeout_id = g_timeout_add(16, update_simulation, state);
```

### Change Brush Size

```c
#define BRUSH_SIZE 8  // Change this value
```

### Add Keyboard Shortcuts

In the `key_pressed` function, add new cases:
```c
case GDK_KEY_p:
case GDK_KEY_P:
    // Pause simulation
    // Your code here
    break;
```

---

## Advantages Over GLFW Version

| Feature | GTK Version | GLFW Version |
|---------|------------|--------------|
| WSL2 Support | ✅ Native | ⚠️ Needs X server |
| Setup Complexity | ✅ Simple | ⚠️ Complex |
| Dependencies | 1 (GTK4) | 3 (GLFW, GLEW, OpenGL) |
| Window Resizing | ✅ Native | ❌ Fixed size |
| Desktop Integration | ✅ Yes | ⚠️ Basic |
| Cross-platform | ✅ Linux, WSL2 | ✅ Linux, Windows, macOS |

---

## Comparison Table: All Versions

| Feature | CLI | GTK | GLFW |
|---------|-----|-----|------|
| Real-time | ❌ | ✅ | ✅ |
| Interactive | ❌ | ✅ | ✅ |
| WSL2 Ready | ✅ | ✅ | ⚠️ |
| Setup Difficulty | Easy | Easy | Hard |
| Max FPS | N/A | 30-120 | 60-500+ |
| Output | Images | Window | Window |
| Best For | Batch | WSL2/Linux | Performance |

---

## Advanced: Rendering Details

The GTK version uses **Cairo** for rendering, which is GPU-accelerated on most systems. The data flow is:

1. CUDA updates particles on GPU
2. CUDA renders to RGBA buffer
3. Data copied to CPU (this is the bottleneck)
4. Cairo displays the buffer
5. GTK handles the window

### Optimization Tips

**Reduce memory copies:**
The current version copies from GPU to CPU every frame. For better performance, you could:
- Update less frequently (every 2-3 frames)
- Use smaller resolution
- Implement dirty rectangle tracking

**Increase FPS:**
```c
// In activate() function
state->timeout_id = g_timeout_add(8, update_simulation, state);  // ~120 FPS
```

**Multi-threading:**
Run simulation in separate thread to prevent UI blocking:
```c
// Use g_thread_new() to run simulation in background
// Update UI with g_idle_add()
```

---

## Building on Other Platforms

### macOS (with Homebrew)

```bash
brew install gtk4
make falling_sand_gtk
./falling_sand_gtk
```

### Windows Native (MSYS2)

```bash
pacman -S mingw-w64-x86_64-gtk4
# Then compile with nvcc using appropriate flags
```

---

## Next Steps

Try these enhancements:

1. **Add UI Controls**
   - Add GTK buttons for particle selection
   - Add sliders for brush size
   - Add FPS counter display

2. **Save/Load**
   - Add menu bar with File > Save/Load
   - Save grid state to file
   - Load pre-made scenes

3. **Multiple Particle Types**
   - Add ice, oil, acid
   - Create custom particles
   - Import from configuration file

4. **Better Visuals**
   - Add glow effects to fire/lava
   - Particle trails
   - Screen shake effects

5. **Sound**
   - Add sound effects for fire, water
   - Background ambiance
   - Use GStreamer integration

---

## Example: Adding a Menu Bar

```c
// In activate() function, before gtk_window_set_child()

GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

// Create menu bar
GtkWidget* menu_bar = gtk_menu_bar_new();
// ... add menus ...

gtk_box_append(GTK_BOX(box), menu_bar);
gtk_box_append(GTK_BOX(box), state->drawing_area);

gtk_window_set_child(GTK_WINDOW(window), box);
```

---

## Resources

- **GTK4 Documentation**: https://docs.gtk.org/gtk4/
- **Cairo Graphics**: https://www.cairographics.org/
- **CUDA Documentation**: https://docs.nvidia.com/cuda/
- **Example Projects**: https://gitlab.gnome.org/GNOME/gtk/-/tree/main/demos

---

## FAQ

**Q: Can I use GTK3 instead of GTK4?**  
A: Yes, but you'll need to adjust the code. GTK4 has simpler APIs for drawing.

**Q: Does this work on Wayland?**  
A: Yes! GTK4 works great on both X11 and Wayland.

**Q: Can I package this as a .deb or .rpm?**  
A: Yes, create a package with dependencies: `libgtk-4-1`, `nvidia-cuda-toolkit`

**Q: How do I make this fullscreen?**  
A: Add to the window setup:
```c
gtk_window_fullscreen(GTK_WINDOW(window));
```

**Q: Can I add touch support for tablets?**  
A: Yes! GTK4 has built-in touch gesture support. Use `gtk_gesture_stylus_new()`.

---

Enjoy your falling sand simulator! 🎨
