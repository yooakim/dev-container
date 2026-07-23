# ==========================================
# Stage 1: Build Rust CLI tools from source
# ==========================================
FROM rust:slim-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TIME_STYLE=long-iso

# Install build dependencies including GNU make and C compilers for jemalloc
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    make \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Compile preferred CLI tools from source.
# Versions are pinned and '--locked' is used so builds are reproducible.
RUN cargo install lsd@1.2.0 --locked \
    && cargo install ripgrep@15.2.0 --locked \
    && cargo install fd-find@10.4.2 --locked \
    && cargo install bat@0.26.1 --locked \
    && cargo install zoxide@0.10.0 --locked


# ==========================================
# Stage 2: Final Development Container
# ==========================================
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    UV_LINK_MODE=copy \
    TIME_STYLE=long-iso

# Install essential runtime tools + .NET runtime dependencies for sqlpackage
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    sudo \
    procps \
    gnupg \
    unzip \
    libicu-dev \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 1. Install Azure CLI via official Microsoft script
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# 2. Install azcopy
RUN curl -sSL "https://aka.ms/downloadazcopy-v10-linux" | tar -xz --strip-components=1 -C /tmp \
    && mv /tmp/azcopy /usr/local/bin/ \
    && chmod +x /usr/local/bin/azcopy \
    && rm -rf /tmp/*

# 3. Install sqlpackage
RUN curl -sSL -o /tmp/sqlpackage.zip "https://aka.ms/sqlpackage-linux" \
    && mkdir -p /opt/sqlpackage \
    && unzip -q /tmp/sqlpackage.zip -d /opt/sqlpackage \
    && chmod +x /opt/sqlpackage/sqlpackage \
    && ln -s /opt/sqlpackage/sqlpackage /usr/local/bin/sqlpackage \
    && rm /tmp/sqlpackage.zip

# Create non-root developer user
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Copy compiled Rust binaries directly from the builder stage
COPY --from=builder /usr/local/cargo/bin/* /usr/local/bin/

USER $USERNAME
WORKDIR /home/$USERNAME

# Install Astral 'uv' and Starship
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && curl -sS https://starship.rs/install.sh | sh -s -- -y

# Configure environment & aliases
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc \
    && echo 'eval "$(starship init bash)"' >> ~/.bashrc \
    && echo 'eval "$(zoxide init bash)"' >> ~/.bashrc \
    && echo 'alias ls="lsd"' >> ~/.bashrc \
    && echo 'alias l="lsd"' >> ~/.bashrc \
    && echo 'alias la="lsd -a"' >> ~/.bashrc \
    && echo 'alias lla="lsd -la"' >> ~/.bashrc \
    && echo 'alias lt="lsd --tree"' >> ~/.bashrc \
    && echo 'alias cat="bat"' >> ~/.bashrc

CMD ["/bin/bash"]
