# Portable Mesa llvmpipe for HPC

Build Mesa with llvmpipe (CPU-based OpenGL) on CentOS 7 for maximum
compatibility with older HPC systems.

## What's included

- **libEGL.so** — EGL with surfaceless platform (no X11 needed)
- **libOSMesa.so** — Off-screen Mesa (if available)
- **libgallium-*.so** — Gallium driver with llvmpipe + softpipe
- **libglapi.so** — GL API dispatch
- RPATH set to `$ORIGIN` — all libs find each other in same directory

## Usage on HPC

```bash
# Extract the tarball
tar xzf mesa-portable-libs.tar.gz -C /path/to/mesa

# Set environment
export LD_LIBRARY_PATH=/path/to/mesa:$LD_LIBRARY_PATH
export EGL_PLATFORM=surfaceless

# Run your OpenGL application (will use llvmpipe)
/path/to/your/app
```

## How to trigger a build

Push to main branch or use GitHub Actions "Run workflow".
