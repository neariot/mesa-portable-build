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

## Usage on HPC

### Option A: Running under VNC / X11 (Virtual Desktop)
```bash
# Extract the tarball
tar xzf mesa-portable-libs.tar.gz -C /path/to/mesa

# Set environment to use portable Mesa's GLX and software drivers
export LD_LIBRARY_PATH=/path/to/mesa:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/path/to/mesa/dri
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

# Run your OpenGL application (it will use llvmpipe for software rendering over VNC)
/path/to/your/app
```

### Option B: Headless / Surfaceless EGL (Off-screen rendering without VNC/X11)
```bash
# Extract the tarball
tar xzf mesa-portable-libs.tar.gz -C /path/to/mesa

# Set environment
export LD_LIBRARY_PATH=/path/to/mesa:$LD_LIBRARY_PATH
export LIBGL_DRIVERS_PATH=/path/to/mesa/dri
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export EGL_PLATFORM=surfaceless

# Run your off-screen EGL application
/path/to/your/app
```

## How to trigger a build

Push to main branch or use GitHub Actions "Run workflow".
