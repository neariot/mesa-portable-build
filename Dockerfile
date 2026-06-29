FROM quay.io/pypa/manylinux2014_x86_64

RUN yum install -y epel-release && \
    yum install -y cmake3 ninja-build python3-pip \
        pkgconfig expat-devel zlib-devel libdrm-devel \
        wget xz patchelf && \
    yum clean all

# Install newer cmake (manylinux has old 3.17)
RUN wget -q https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz && \
    tar xzf cmake-3.31.6-linux-x86_64.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake-3.31.6-linux-x86_64.tar.gz && \
    pip3 install meson && \
    ln -sf /usr/bin/ninja-build /usr/local/bin/ninja

ENV CC=/opt/rh/devtoolset-9/root/usr/bin/gcc
ENV CXX=/opt/rh/devtoolset-9/root/usr/bin/g++
ENV PATH=/opt/rh/devtoolset-9/root/usr/bin:/usr/local/bin:$PATH

WORKDIR /build

# Build LLVM 18.1.8 statically (X86 only)
RUN wget -q https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/llvm-18.1.8.src.tar.xz && \
    tar xf llvm-18.1.8.src.tar.xz && \
    mkdir llvm-build && cd llvm-build && \
    cmake ../llvm-18.1.8.src -G Ninja \
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
        -DLLVM_BUILD_STATIC=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLVM_ENABLE_PIC=ON \
        -DLLVM_ENABLE_EH=ON \
        -DLLVM_ENABLE_RTTI=ON && \
    ninja -j$(nproc) install

# Build Mesa 24.3.4 with llvmpipe, OSMesa, surfaceless EGL
RUN wget -q https://archive.mesa3d.org/mesa-24.3.4.tar.xz && \
    tar xf mesa-24.3.4.tar.xz && \
    mkdir mesa-build && cd mesa-build && \
    export PKG_CONFIG_PATH=/usr/local/llvm/lib/pkgconfig && \
    meson setup ../mesa-24.3.4 \
        --prefix=/usr/local/mesa --libdir=lib --buildtype=release \
        -Dgallium-drivers=swrast \
        -Dvulkan-drivers=[] \
        -Dglx=disabled \
        -Degl=enabled \
        -Dgbm=disabled \
        -Dosmesa=true \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=true \
        -Dllvm=enabled \
        -Dshared-llvm=false \
        -Dlmsensors=disabled \
        -Dvalgrind=disabled \
        -Dlibunwind=disabled \
        -Dplatforms=surfaceless \
        -Ddri3=disabled \
        -Dshader-cache=disabled \
        -Dbuild-tests=false \
        -Dtools=[] && \
    ninja -j$(nproc) install

# Package portable libs with RPATH=$ORIGIN
RUN mkdir -p /output && \
    cp -av /usr/local/mesa/lib/libEGL*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libOSMesa*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libgallium*.so* /output/ 2>/dev/null; \
    cp -av /usr/local/mesa/lib/libglapi*.so* /output/ 2>/dev/null; \
    for f in /output/*.so*; do \
        patchelf --set-rpath '$ORIGIN' $f 2>/dev/null || true; \
    done; \
    echo "=== Files ===" && ls -la /output/ && \
    echo "=== Missing deps ===" && \
    for f in /output/*.so*; do \
        miss=$(ldd $f 2>/dev/null | grep "not found"); \
        [ -n "$miss" ] && echo "--- $(basename $f) ---" && echo "$miss"; \
    done; \
    echo "=== GLIBC ===" && \
    for f in /output/*.so*; do \
        echo "$(basename $f): $(strings $f 2>/dev/null | grep -oP 'GLIBC_[0-9]+\.[0-9]+' | sort -V | tail -1)"; \
    done
