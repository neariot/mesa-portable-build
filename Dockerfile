FROM quay.io/pypa/manylinux2014_x86_64

RUN yum install -y epel-release && \
    yum install -y cmake3 ninja-build python3-pip \
        pkgconfig expat-devel zlib-devel libdrm-devel \
        wget xz patchelf flex bison \
        libxshmfence-devel libX11-devel libXext-devel libXdamage-devel libXfixes-devel \
        libXrandr-devel && \
    yum clean all

# Install newer cmake (manylinux has old 3.17)
RUN wget -q https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz && \
    tar xzf cmake-3.31.6-linux-x86_64.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake-3.31.6-linux-x86_64.tar.gz && \
    ln -sf /usr/bin/ninja-build /usr/local/bin/ninja

ENV CC=/opt/rh/devtoolset-10/root/usr/bin/gcc
ENV CXX=/opt/rh/devtoolset-10/root/usr/bin/g++
ENV PATH=/opt/rh/devtoolset-10/root/usr/bin:/usr/local/bin:/usr/local/llvm/bin:$PATH

WORKDIR /build

# Build LLVM 18.1.8 statically (X86 only)
RUN wget -q https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/llvm-project-18.1.8.src.tar.xz && \
    tar xf llvm-project-18.1.8.src.tar.xz && \
    mkdir llvm-build && cd llvm-build && \
    cmake ../llvm-project-18.1.8.src/llvm -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local/llvm \
        -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_ZLIB=OFF \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_TARGETS_TO_BUILD=X86 \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLVM_ENABLE_PIC=ON \
        -DLLVM_ENABLE_EH=ON \
        -DLLVM_ENABLE_RTTI=ON && \
    ninja -j$(nproc) install && \
    cd /build && rm -rf llvm-build llvm-project-18.1.8.src llvm-project-18.1.8.src.tar.xz

# Install modern Meson (Mesa 24.3.4 requires Meson >= 1.1.0)
RUN python3 -m pip install mako pyyaml && \
    /opt/python/cp310-cp310/bin/pip install meson && \
    ln -sf /opt/python/cp310-cp310/bin/meson /usr/local/bin/meson

# Build newer libdrm (Mesa 24.3.4 requires >= 2.4.109, CentOS 7 has 2.4.97)
RUN wget -q https://dri.freedesktop.org/libdrm/libdrm-2.4.124.tar.xz && \
    tar xf libdrm-2.4.124.tar.xz && \
    mkdir libdrm-build && cd libdrm-build && \
    meson setup ../libdrm-2.4.124 \
        --prefix=/usr/local --libdir=lib --buildtype=release \
        -Dudev=false \
        -Dintel=disabled \
        -Damdgpu=disabled \
        -Dradeon=disabled \
        -Dnouveau=disabled \
        -Dvmwgfx=disabled \
        -Detnaviv=disabled \
        -Dexynos=disabled \
        -Dfreedreno=disabled \
        -Domap=disabled \
        -Dtegra=disabled \
        -Dvc4=disabled \
        -Dtests=false && \
    ninja -j$(nproc) install && \
    cd /build && rm -rf libdrm-build libdrm-2.4.124 libdrm-2.4.124.tar.xz

# Build Mesa 24.3.4 with llvmpipe, OSMesa, surfaceless EGL
RUN wget -q https://archive.mesa3d.org/mesa-24.3.4.tar.xz && \
    tar xf mesa-24.3.4.tar.xz && \
    mkdir mesa-build && cd mesa-build && \
    export PKG_CONFIG_PATH=/usr/local/llvm/lib/pkgconfig:/usr/local/lib/pkgconfig && \
    meson setup ../mesa-24.3.4 \
        --prefix=/usr/local/mesa --libdir=lib --buildtype=release \
        -Dgallium-drivers=swrast \
        -Dvulkan-drivers=[] \
        -Dglx=dri \
        -Degl=enabled \
        -Dgbm=disabled \
        -Dosmesa=true \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=true \
        -Dllvm=enabled \
        -Dshared-llvm=disabled \
        -Dlmsensors=disabled \
        -Dvalgrind=disabled \
        -Dlibunwind=disabled \
        -Dplatforms=x11 \
        -Dshader-cache=disabled \
        -Dbuild-tests=false \
        -Dtools=[] && \
    ninja -j$(nproc) install && \
    cd /build && rm -rf mesa-build mesa-24.3.4 mesa-24.3.4.tar.xz

# Package portable libs with RPATH=$ORIGIN (fully self-contained)
RUN mkdir -p /output/dri && \
    cp -av /usr/local/mesa/lib/libGL*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libEGL*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libOSMesa*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libgallium*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libglapi*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/dri/*.so /output/dri/ 2>/dev/null; \
    # Bundle libdrm (built from source, newer than system) \
    cp -av /usr/local/lib/libdrm.so* /output/ 2>/dev/null; \
    # Bundle X11/XCB libs for full portability \
    for lib in libX11 libXext libXfixes libXdamage libXrandr libXrender \
               libX11-xcb libXau libXdmcp libXxf86vm libXshmfence \
               libxcb libxcb-randr libxcb-xfixes libxcb-shm libxcb-dri3 \
               libxcb-present libxcb-sync libxcb-glx; do \
        cp -av /usr/lib64/$lib.so* /output/ 2>/dev/null; \
    done; \
    # Set RPATH to $ORIGIN for all libs \
    for f in /output/*.so*; do \
        patchelf --set-rpath '$ORIGIN' $f 2>/dev/null || true; \
    done; \
    for f in /output/dri/*.so; do \
        patchelf --set-rpath '$ORIGIN/..' $f 2>/dev/null || true; \
    done; \
    echo "=== Files ===" && ls -la /output/ && echo "=== DRI ===" && ls -la /output/dri/ && \
    echo "=== Missing deps ===" && \
    for f in /output/libEGL.so.1.0.0 /output/libGL.so.1.2.0 /output/libOSMesa.so.8.0.0 /output/libgallium-24.3.4.so; do \
        miss=$(ldd $f 2>/dev/null | grep "not found"); \
        [ -n "$miss" ] && echo "--- $(basename $f) ---" && echo "$miss"; \
    done; \
    echo "=== GLIBC ===" && \
    for f in /output/libEGL.so.1.0.0 /output/libGL.so.1.2.0 /output/libOSMesa.so.8.0.0 /output/libgallium-24.3.4.so; do \
        echo "$(basename $f): $(strings $f 2>/dev/null | grep -oP 'GLIBC_[0-9]+\.[0-9]+' | sort -V | tail -1)"; \
    done; \
    echo "=== Total size ===" && du -sh /output/
