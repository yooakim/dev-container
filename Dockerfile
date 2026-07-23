# syntax=docker/dockerfile:1

# Pinned base image digests (linux/amd64 — matches GitHub Actions runners).
# Refresh via Dependabot docker updates or a scheduled security rebuild.
ARG DEBIAN_DIGEST=sha256:63a496b5d3b99214b39f5ed70eb71a61e590a77979c79cbee4faf991f8c0783e
ARG RUST_DIGEST=sha256:b001fed8c602fe3126bfee18c7afa14fe58dc855ce1d0cdfb4ac3ee7d6361a1c

# Pinned third-party tool versions and verified checksums.
ARG CARGO_BINSTALL_VERSION=1.21.0
ARG CARGO_BINSTALL_SHA256=b1880b3631d1ff0fd1f286a0d20f82f373355651f9fbd7f4d0d7fbfe218bf562
ARG AZURE_CLI_VERSION=2.88.0-1~bookworm
ARG AZCOPY_VERSION=10.32.6
ARG AZCOPY_SHA256=6538f7fb9ec6e4d159e44a1612ca7eee24fe7a822065a3dcbc664ef30fe85d16
ARG SQLPACKAGE_VERSION=170.4.83.3
ARG SQLPACKAGE_URL=https://download.microsoft.com/download/18a5e51e-8332-4cbe-bb50-6d3a50c704c5/sqlpackage-linux-x64-en-170.4.83.3.zip
ARG SQLPACKAGE_SHA256=e81ede2429f3a15d9e752845c8928569c7706b3a911fad2d1717c0f03e0fc7c3
ARG UV_VERSION=0.11.31
ARG UV_SHA256=8cc1cd82d434ec565376f98bd938d4b715b5791a80ff2d3aa78821cf85091b4b
ARG STARSHIP_VERSION=1.26.0
ARG STARSHIP_SHA256=321f0dd7af8340a5f2e6a8fec6538a04f617486f9ec70d878f91c09cd8deef22

# ==========================================
# Stage 1: Fetch Rust CLI tools (prebuilt via cargo-binstall)
# ==========================================
FROM rust:slim-bookworm@${RUST_DIGEST} AS builder

ARG CARGO_BINSTALL_VERSION
ARG CARGO_BINSTALL_SHA256

ENV DEBIAN_FRONTEND=noninteractive \
    TIME_STYLE=long-iso

# Build dependencies only needed if binstall falls back to compiling from source.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    make \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-binstall from a versioned release tarball (no curl|bash).
RUN set -eu; \
    archive="/tmp/cargo-binstall.tgz"; \
    curl -fsSL -o "${archive}" \
      "https://github.com/cargo-bins/cargo-binstall/releases/download/v${CARGO_BINSTALL_VERSION}/cargo-binstall-x86_64-unknown-linux-musl.tgz"; \
    echo "${CARGO_BINSTALL_SHA256}  ${archive}" | sha256sum -c -; \
    tar -xzf "${archive}" -C /usr/local/bin; \
    rm "${archive}"

RUN cargo binstall -y --install-path /tools \
    lsd@1.2.0 \
    ripgrep@15.2.0 \
    fd-find@10.4.2 \
    bat@0.26.1 \
    zoxide@0.10.0


# ==========================================
# Stage 2: Final Development Container
# ==========================================
FROM debian:bookworm-slim@${DEBIAN_DIGEST}

ARG AZURE_CLI_VERSION
ARG AZCOPY_VERSION
ARG AZCOPY_SHA256
ARG SQLPACKAGE_URL
ARG SQLPACKAGE_SHA256
ARG UV_VERSION
ARG UV_SHA256
ARG STARSHIP_VERSION
ARG STARSHIP_SHA256

LABEL org.opencontainers.image.source="https://github.com/yooakim/dev-container" \
      org.opencontainers.image.description="Debian-based dev container with Azure tooling and modern CLI utilities" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    UV_LINK_MODE=copy \
    TIME_STYLE=long-iso

# Install runtime dependencies, apply security updates, then add Azure CLI repo.
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    unzip \
    git \
    procps \
    libicu72 \
    libssl3 \
    libunwind8 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/repos/azure-cli/ bookworm main" \
       > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "azure-cli=${AZURE_CLI_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

# azcopy — pinned GitHub release with checksum verification.
RUN set -eu; \
    archive="/tmp/azcopy.tgz"; \
    curl -fsSL -o "${archive}" \
      "https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy_linux_amd64_${AZCOPY_VERSION}.tar.gz"; \
    echo "${AZCOPY_SHA256}  ${archive}" | sha256sum -c -; \
    tar -xzf "${archive}" -C /tmp --strip-components=1; \
    mv /tmp/azcopy /usr/local/bin/azcopy; \
    chmod +x /usr/local/bin/azcopy; \
    rm -rf /tmp/*

# sqlpackage — pinned Microsoft download with checksum verification.
RUN set -eu; \
    archive="/tmp/sqlpackage.zip"; \
    curl -fsSL -o "${archive}" "${SQLPACKAGE_URL}"; \
    echo "${SQLPACKAGE_SHA256}  ${archive}" | sha256sum -c -; \
    mkdir -p /opt/sqlpackage \
    && unzip -q "${archive}" -d /opt/sqlpackage \
    && chmod +x /opt/sqlpackage/sqlpackage \
    && ln -s /opt/sqlpackage/sqlpackage /usr/local/bin/sqlpackage \
    && rm "${archive}"

# uv and starship — pinned GitHub releases with checksum verification.
RUN set -eu; \
    uv_archive="/tmp/uv.tgz"; \
    curl -fsSL -o "${uv_archive}" \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"; \
    echo "${UV_SHA256}  ${uv_archive}" | sha256sum -c -; \
    tar -xzf "${uv_archive}" -C /usr/local/bin --strip-components=1; \
    rm "${uv_archive}"; \
    starship_archive="/tmp/starship.tgz"; \
    curl -fsSL -o "${starship_archive}" \
      "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz"; \
    echo "${STARSHIP_SHA256}  ${starship_archive}" | sha256sum -c -; \
    tar -xzf "${starship_archive}" -C /usr/local/bin; \
    rm "${starship_archive}"

# Remove download tooling and repo keys from the final image.
RUN apt-get purge -y curl gnupg unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /usr/share/keyrings/microsoft-prod.gpg

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash

COPY --from=builder /tools/* /usr/local/bin/

USER $USERNAME
WORKDIR /home/$USERNAME

RUN echo 'eval "$(starship init bash)"' >> ~/.bashrc \
    && echo 'eval "$(zoxide init bash)"' >> ~/.bashrc \
    && echo 'alias ls="lsd"' >> ~/.bashrc \
    && echo 'alias l="lsd"' >> ~/.bashrc \
    && echo 'alias la="lsd -a"' >> ~/.bashrc \
    && echo 'alias lla="lsd -la"' >> ~/.bashrc \
    && echo 'alias lt="lsd --tree"' >> ~/.bashrc \
    && echo 'alias cat="bat"' >> ~/.bashrc

CMD ["/bin/bash"]
