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

Pull the published image with:

```bash
docker pull ghcr.io/<owner>/<repo>:latest
```

---

## Installed Tools & Features

| Tool | Description | Usage Note |
| :--- | :--- | :--- |
| **`uv`** | Fast Python package & version manager | Runs via `uv venv` and `uv pip` |
| **`lsd`** | Next-gen `ls` replacement | Aliased to `ls`, `l`, `la`, `lla`, `lt` |
| **`bat`** | Syntax-highlighted `cat` replacement | Aliased to `cat` |
| **`zoxide`** | Smart directory navigation | Integrated into shell (`z <folder>`) |
| **`ripgrep` / `fd`** | Fast file search (`rg`, `fd`) | Multi-stage built from Rust source |
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
