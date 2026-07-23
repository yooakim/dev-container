# Local Linux Development Environment

My lightweight, safe, and reproducible Debian-based container pre-configured with modern Rust CLI tools (`lsd`, `ripgrep`, `fd`, `bat`, `zoxide`), Python management (`uv`), and Microsoft Azure developer tooling (`az`, `azcopy`, `sqlpackage`).

---

## Quick Start

### 1. Build the Docker Image

Build the container image using Docker BuildKit:

```bash
docker build -t dev-container .
```

---

### 2. Run as Standalone CLI Container

Run the container with your current directory mounted as the workspace, along with your local Azure CLI credentials and Git configuration:

#### **Linux / macOS / WSL:**
```bash
docker run -it --rm \
  -v "$(pwd):/home/developer/app" \
  -v "$HOME/.azure:/home/developer/.azure" \
  -v "$HOME/.gitconfig:/home/developer/.gitconfig:ro" \
  -w /home/developer/app \
  dev-container
```

#### **Windows PowerShell:**
```powershell
docker run -it --rm `
  -v "${PWD}:/home/developer/app" `
  -v "$ENV:USERPROFILE\.azure:/home/developer/.azure" `
  -v "$ENV:USERPROFILE\.gitconfig:/home/developer/.gitconfig:ro" `
  -w /home/developer/app `
  dev-container
```

---

### 3. Open in VS Code Devcontainers

If using VS Code, install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).

This repo ships a ready-to-use [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) that builds from the `Dockerfile`, runs as the non-root `developer` user, and bind-mounts your host `~/.azure` credentials.

Press `F1` in VS Code and select **Dev Containers: Reopen in Container**.

---

## Continuous Integration

A GitHub Actions workflow ([`.github/workflows/docker-image.yml`](.github/workflows/docker-image.yml)) builds the image on every push and pull request, and publishes it to the **GitHub Container Registry** (GHCR) on pushes to `main`/`master` and on version tags (`v*`).

The pipeline also:

- Lints the `Dockerfile` with **Hadolint**
- Scans the built image with **Trivy** (fails on unfixed **Critical/High** CVEs)
- Generates **SBOM** and **SLSA provenance** attestations on publish builds
- **Signs** published images with **cosign** (keyless via GitHub OIDC)
- Rebuilds weekly (Mondays 06:00 UTC) to pick up base-image security patches
- Opens **Dependabot** PRs for GitHub Actions and base-image updates

---

## Security

This image is a **development environment**, not a minimal production runtime. Security controls focus on supply-chain integrity, vulnerability gating, and least privilege that still supports day-to-day dev work.

| Control | Implementation |
| :--- | :--- |
| Non-root runtime | Container runs as the `developer` user (UID 1000) |
| No passwordless sudo | Removed — install tooling at build time instead |
| Pinned base images | `debian:bookworm-slim` and `rust:slim-bookworm` pinned by digest |
| Verified downloads | azcopy, sqlpackage, uv, starship, and cargo-binstall use pinned versions + SHA256 checks |
| Pinned Azure CLI | Installed from the Microsoft apt repo at a fixed version |
| Reduced attack surface | `curl`, `gnupg`, and `unzip` removed from the final image after setup |
| Immutable releases | Prefer semver or `sha-*` tags; verify signatures with cosign |

### Verify a signed release

```bash
cosign verify ghcr.io/yooakim/dev-container:1.0.0 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='https://github.com/yooakim/dev-container/.github/workflows/.*'
```

### Credential handling

The devcontainer bind-mounts host `~/.azure` credentials for convenience. Treat the container as a **trusted environment** — do not run untrusted code with your Azure credentials mounted. Prefer read-only mounts where possible (`:ro` for `.gitconfig` in standalone `docker run` examples).

---

## Versioning & Image Tags

Releases are driven by **git tags** using [semantic versioning](https://semver.org/) (`vX.Y.Z`). Each publish generates the following tags on `ghcr.io/yooakim/dev-container`:

| Tag | Example | Meaning |
| :--- | :--- | :--- |
| `X.Y.Z` | `1.2.3` | Exact release, fully immutable |
| `X.Y` | `1.2` | Latest patch within a minor (gets bug fixes) |
| `X` | `1` | Latest minor within a major (gets features + fixes) |
| `latest` | `latest` | Newest **released** version (stable) |
| `main` | `main` | Newest build of the default branch (bleeding edge) |
| `sha-<short>` | `sha-9551425` | Exact commit reference |

Choose based on how much you value stability vs. staying current:

```bash
docker pull ghcr.io/yooakim/dev-container:1.2.3   # pin exactly (reproducible)
docker pull ghcr.io/yooakim/dev-container:1        # latest v1.x
docker pull ghcr.io/yooakim/dev-container:latest   # newest stable release
docker pull ghcr.io/yooakim/dev-container:main     # bleeding edge
```

### Cutting a release

Create an annotated git tag (or a GitHub Release) and push it — the workflow does the rest:

```bash
# Option A: git tag
git tag -a v1.0.0 -m "First stable release"
git push origin v1.0.0

# Option B: GitHub Release (also creates the tag + release notes)
gh release create v1.0.0 --generate-notes
```

Follow [semver](https://semver.org/): bump the **patch** for fixes, the **minor** for new tools/features (backward compatible), and the **major** for breaking changes to how the image is used.

---

## Installed Tools & Features

| Tool | Description | Usage Note |
| :--- | :--- | :--- |
| **`uv`** | Fast Python package & version manager | Runs via `uv venv` and `uv pip` |
| **`lsd`** | Next-gen `ls` replacement | Aliased to `ls`, `l`, `la`, `lla`, `lt` |
| **`bat`** | Syntax-highlighted `cat` replacement | Aliased to `cat` |
| **`zoxide`** | Smart directory navigation | Integrated into shell (`z <folder>`) |
| **`ripgrep` / `fd`** | Fast file search (`rg`, `fd`) | Prebuilt via cargo-binstall (pinned versions) |
| **`just`** | Command runner for project tasks | Run `just` / `just --list` in a repo with a `justfile` |
| **`az`** | Azure CLI | Reads host credentials if mounted |
| **`azcopy`** | High-performance Azure storage sync | Pre-configured in `/usr/local/bin` |
| **`sqlpackage`** | Azure SQL dacpac/dacfx deployment | Includes necessary .NET runtime libs |

---

## 🐍 Python Setup via `uv`

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
