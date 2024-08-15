FROM ubuntu:noble

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        pkg-config \
        python3-venv \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Download crossbuild toolchain
RUN mkdir -p /opt \
    && wget -q https://github.com/jcar87/conan-crossbuild-with-sysroot/releases/download/v0.0.1-alpha/gcc-10.5.0-toolchain-aarch64-linux-gnu_linux_x86_64.tar.gz \
    && tar -xzf gcc-10.5.0-toolchain-aarch64-linux-gnu_linux_x86_64.tar.gz -C /opt \
    && rm gcc-10.5.0-toolchain-aarch64-linux-gnu_linux_x86_64.tar.gz

# Download reference sysroot
RUN wget -q https://github.com/jcar87/conan-crossbuild-with-sysroot/releases/download/v0.0.1-alpha/rassperry_pi_debian_bullseye_sysroot.tar.gz \
    && tar -xzf rassperry_pi_debian_bullseye_sysroot.tar.gz -C /opt \
    && rm rassperry_pi_debian_bullseye_sysroot.tar.gz

# Add helper files
COPY support_files/user_toolchain.cmake /opt/user_toolchain.cmake
COPY support_files/pkg-config /opt/pkg-config

# Build simdjson and install into /usr/local
RUN wget -q https://github.com/simdjson/simdjson/archive/v3.10.0.tar.gz \
    && tar xzf v3.10.0.tar.gz \
    && mkdir -p /root/simdjson-3.10.0/build \
    && cmake -S /root/simdjson-3.10.0 -B /root/simdjson-3.10.0/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build /root/simdjson-3.10.0/build && cmake --build /root/simdjson-3.10.0/build --target install \
    && rm -rf /root/simdjson-3.10.0 v3.10.0.tar.gz

# Install Conan
RUN python3 -m venv /opt/conan-venv \
    && /opt/conan-venv/bin/pip install --upgrade pip \
    && /opt/conan-venv/bin/pip install conan==2.6.0 \
    && ln -s /opt/conan-venv/bin/conan /usr/bin/conan

# Add a user
RUN useradd -ms /bin/bash conan
USER conan
WORKDIR /home/conan

# Setup Conan profiles
RUN conan profile detect
COPY support_files/rpi-crossbuild /home/conan/.conan2/profiles/rpi-crossbuild
COPY support_files/rpi-crossbuild-full /home/conan/.conan2/profiles/rpi-crossbuild-full

# COPY examples
COPY --chown=conan:conan examples/ /home/conan/examples
