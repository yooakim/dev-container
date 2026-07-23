# dev-cli — Local Linux Development Environments

A monorepo of lightweight, reproducible Debian-based dev container images. Each image shares a common base (Azure tooling, modern Rust CLI utilities) and adds language-specific tooling on top.

| Image | GHCR package | Status |
| :--- | :--- | :--- |
| **Python** | `ghcr.io/yooakim/dev-cli-python` | Available |
| **.NET** | `ghcr.io/yooakim/dev-cli-dotnet` | Planned — see [`images/dotnet/README.md`](images/dotnet/README.md) |

> **Migration:** The legacy single image `ghcr.io/yooakim/dev-container` is deprecated. New builds publish to `dev-cli-python`. Pull the new package name for updates; the old package will remain available until removed manually from GHCR.

---

## Repository layout

```
docker/
  Dockerfile          # multi-stage: builder → base → python (+ dotnet later)
images/
  python/
    devcontainer.json # VS Code dev container for Python workflows
  dotnet/
    README.md         # placeholder for the future .NET image
.devcontainer/
  devcontainer.json   # root entry (builds docker/Dockerfile --target python)
```

---

## Quick Start (Python image)

### 1. Build the Docker image

Build from the repository root using BuildKit:

```bash
docker build -f docker/Dockerfile --target python -t dev-cli-python .
```

---

### 2. Run as standalone CLI container

Run with your current directory mounted as the workspace, along with local Azure CLI credentials and Git configuration:

#### **Linux / macOS / WSL:**
```bash
docker run -it --rm \
  -v "$(pwd):/home/developer/app" \
  -v "$HOME/.azure:/home/developer/.azure" \
  -v "$HOME/.gitconfig:/home/developer/.gitconfig:ro" \
  -w /home/developer/app \
  dev-cli-python
```

#### **Windows PowerShell:**
```powershell
docker run -it --rm `
  -v "${PWD}:/home/developer/app" `
  -v "$ENV:USERPROFILE\.azure:/home/developer/.azure" `
  -v "$ENV:USERPROFILE\.gitconfig:/home/developer/.gitconfig:ro" `
  -w /home/developer/app `
  dev-cli-python
```

---

### 3. Open in VS Code Dev Containers

Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).

This repo ships [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) (or [`images/python/devcontainer.json`](images/python/devcontainer.json)) which builds `docker/Dockerfile` with `--target python`, runs as the non-root `developer` user, and bind-mounts host `~/.azure` credentials.

Press `F1` in VS Code and select **Dev Containers: Reopen in Container**.

---

## Continuous Integration

GitHub Actions ([`.github/workflows/publish.yml`](.github/workflows/publish.yml)) builds and publishes images on push/PR, with a matrix ready for additional images.

The pipeline:

- Lints `docker/Dockerfile` with **Hadolint**
- Scans built images with **Trivy** (fails on unfixed **Critical/High** CVEs)
- Generates **SBOM** and **SLSA provenance** attestations on publish builds
- **Signs** published images with **cosign** (keyless via GitHub OIDC)
- Rebuilds weekly (Mondays 06:00 UTC) to pick up base-image security patches
- Opens **Dependabot** PRs for GitHub Actions and base-image updates

---

## Security

These images are **development environments**, not minimal production runtimes. Security controls focus on supply-chain integrity, vulnerability gating, and least privilege that still supports day-to-day dev work.

| Control | Implementation |
| :--- | :--- |
| Non-root runtime | Container runs as the `developer` user (UID 1000) |
| No passwordless sudo | Removed — install tooling at build time instead |
| Pinned base images | `debian:bookworm-slim` and `rust:slim-bookworm` pinned by digest |
| Verified downloads | azcopy, sqlpackage, uv, starship, and cargo-binstall use pinned versions + SHA256 checks |
| Pinned Azure CLI | Installed from the Microsoft apt repo at a fixed version |
| Reduced attack surface | `curl`, `gnupg`, and `unzip` removed from runtime images after setup |
| Immutable releases | Prefer semver or `sha-*` tags; verify signatures with cosign |

### Verify a signed release

```bash
cosign verify ghcr.io/yooakim/dev-cli-python:0.1.0 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='https://github.com/yooakim/dev-container/.github/workflows/.*'
```

### Credential handling

The devcontainer bind-mounts host `~/.azure` credentials for convenience. Treat the container as a **trusted environment** — do not run untrusted code with your Azure credentials mounted. Prefer read-only mounts where possible (`:ro` for `.gitconfig` in standalone `docker run` examples).

---

## Versioning & Image Tags

Python releases use **per-image git tags** in the form `python/vX.Y.Z` ([semantic versioning](https://semver.org/)). CI maps those to Docker image tags on `ghcr.io/yooakim/dev-cli-python` (slashes are not valid in image tag names):

| Git tag | Image tag | Meaning |
| :--- | :--- | :--- |
| `python/vX.Y.Z` | `X.Y.Z` | Exact release, fully immutable |
| `python/vX.Y.Z` | `X.Y` | Latest patch within a minor |
| `python/vX.Y.Z` | `X` | Latest minor within a major |
| — | `latest` | Newest **released** version (stable) |
| — | `main` | Newest build of the default branch (bleeding edge) |
| — | `sha-<short>` | Exact commit reference |

```bash
docker pull ghcr.io/yooakim/dev-cli-python:0.1.0   # pin exactly (reproducible)
docker pull ghcr.io/yooakim/dev-cli-python:0       # latest 0.x
docker pull ghcr.io/yooakim/dev-cli-python:latest  # newest stable release
docker pull ghcr.io/yooakim/dev-cli-python:main    # bleeding edge
```

### Cutting a Python release

```bash
git tag -a python/v0.2.0 -m "Python CLI release"
git push origin python/v0.2.0
```

Follow [semver](https://semver.org/): bump **patch** for fixes, **minor** for new tools/features (backward compatible), and **major** for breaking changes to how the image is used.

---

## Installed Tools & Features (Python image)

| Tool | Description | Usage Note |
| :--- | :--- | :--- |
| **`uv`** | Fast Python package & version manager | Runs via `uv venv` and `uv pip` |
| **`just`** | Command runner / task automation | Prebuilt via cargo-binstall (`justfile` support) |
| **`lsd`** | Next-gen `ls` replacement | Aliased to `ls`, `l`, `la`, `lla`, `lt` |
| **`bat`** | Syntax-highlighted `cat` replacement | Aliased to `cat` |
| **`zoxide`** | Smart directory navigation | Integrated into shell (`z <folder>`) |
| **`ripgrep` / `fd`** | Fast file search (`rg`, `fd`) | Prebuilt via cargo-binstall (pinned versions) |
| **`az`** | Azure CLI | Reads host credentials if mounted |
| **`azcopy`** | High-performance Azure storage sync | Pre-configured in `/usr/local/bin` |
| **`sqlpackage`** | Azure SQL dacpac/dacfx deployment | Includes necessary .NET runtime libs |

---

## Python Setup via `uv`

Create and manage isolated Python environments inside the mounted workspace without `root` privileges:

```bash
# Create a venv using a specific Python version (uv downloads it automatically)
uv venv --python 3.12

# Activate environment
source .venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt
```

---

## License

Released under the [MIT License](LICENSE).
