# ==========================================
# Stage 1: Fetch Rust CLI tools (prebuilt via cargo-binstall)
# ==========================================
FROM rust:slim-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TIME_STYLE=long-iso

# Install curl (to bootstrap cargo-binstall) plus build dependencies that are
# only needed if binstall has to fall back to compiling a crate from source.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    make \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-binstall (itself a prebuilt binary) so we can fetch prebuilt
# releases of the CLI tools instead of compiling them from source.
RUN curl -L --proto '=https' --tlsv1.2 -sSf \
    https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

# Download prebuilt binaries for the pinned versions into /tools.
# binstall automatically falls back to compiling from source (via the build
# deps installed above) for any crate that has no prebuilt release available.
RUN cargo binstall -y --install-path /tools \
    lsd@1.2.0 \
    ripgrep@15.2.0 \
    fd-find@10.4.2 \
    bat@0.26.1 \
    zoxide@0.10.0


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

# Copy the prebuilt Rust CLI binaries directly from the builder stage
COPY --from=builder /tools/* /usr/local/bin/

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
