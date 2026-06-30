# Portable Mesa llvmpipe for HPC

Build Mesa with llvmpipe (CPU-based OpenGL) on CentOS 7 for maximum
compatibility with older HPC systems.

## What's included

- **libGL.so** — GLX support for X11/VNC environments
- **libEGL.so** — EGL support
- **libOSMesa.so** — Off-screen Mesa rendering
- **libgallium-*.so** — Gallium driver with llvmpipe + softpipe
- **libglapi.so** — GL API dispatch
- **dri/swrast_dri.so** — Software rasterizer DRI driver (needed for GLX/EGL loading)
- RPATH set to `$ORIGIN` (and `$ORIGIN/..` for DRI drivers) — all libs find each other in same directory structure
- Bundled system deps: expat, zlib, libstdc++, libX11, libXext, libxcb, etc. — no host system dependencies needed

## Usage on HPC

### Option A: Running under VNC / X11 (requires `DISPLAY` with GLX support)
```bash
# Extract the zip
unzip mesa-portable-libs.zip -d /path/to/mesa

# Set environment to use portable Mesa's GLX and software drivers
export LD_LIBRARY_PATH=/path/to/mesa:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/path/to/mesa/dri
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

# Run your OpenGL application (will use llvmpipe for software rendering over VNC)
/path/to/your/app
```

### Option B: Off-screen rendering with OSMesa (no X server needed)
```bash
# Extract the zip
unzip mesa-portable-libs.zip -d /path/to/mesa

# Set environment
export LD_LIBRARY_PATH=/path/to/mesa:$LD_LIBRARY_PATH
export GALLIUM_DRIVER=llvmpipe

# Run your OSMesa-based application
/path/to/your/app
```

## How to trigger a build

Push to main branch or use GitHub Actions "Run workflow".
