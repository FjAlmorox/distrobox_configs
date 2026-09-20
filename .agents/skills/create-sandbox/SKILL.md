---
name: create-sandbox
description: Comprehensive 5-phase protocol and runbook for creating and provisioning new containerized development environments in this repository.
---

# 📦 Skill: Create Sandbox Environment

This guide defines the mandatory 5-phase process that any AI agent must strictly follow when asked to design, build, or provision a new Distrobox environment.

---

## 📋 The 5-Phase Protocol

### Phase 1: Requirements Analysis and Interview (MANDATORY)
**NEVER generate code blindly.** Before creating any files, ask structured questions to clarify:
* **Container name:** Mandatory convention `<tech>-dev` (e.g., `python-dev`, `rust-dev`, `go-dev`, `node-dev`).
* **Base image:** `${DISTROBOX_BASE_IMAGE:-registry.fedoraproject.org/fedora-toolbox:${FEDORA_VERSION:-44}}` (default) or a specific distribution if technically required.
* **Version managers / SDKs:** Version manager (e.g., `pyenv`, `rustup`, `nvm`, `sdkman`) or system packages?
* **Initial default version:** Which LTS or stable release should be configured as default?
* **Compilation toolchain:** Are C/C++ compilers required (`gcc`, `gcc-c++`, `clang`, `glibc-devel`, `make`) for native extensions?
* **GUI & Multimedia support:** Pure CLI/backend or desktop GUIs (X11, Wayland, OpenGL, Vulkan, system fonts, audio)?
* **Additional system libraries:** Headers for SSL (`openssl-devel`), compression (`zlib-devel`), databases (`sqlite-devel`, `libpq-devel`), etc.

---

### Phase 2: Manifest Declaration
Add the new container section to [`distrobox.ini`](../../distrobox.ini) complying with standard parameterized defaults:

```ini
[<name>-dev]
image="${DISTROBOX_BASE_IMAGE:-registry.fedoraproject.org/fedora-toolbox:${FEDORA_VERSION:-44}}"
home="${DISTROBOX_HOMES_DIR:-${HOME}/.local/share/distrobox-homes}/<name>-dev"
volume="${WORKSPACE_DIR:-${HOME}/Workspace}:${WORKSPACE_DIR:-${HOME}/Workspace}:rw"
additional_flags="${DISTROBOX_ADDITIONAL_FLAGS:---device /dev/kvm --device /dev/dri}"
init=false
nvidia=${DISTROBOX_NVIDIA:-0}
pull=${DISTROBOX_PULL:-1}
root=false
```

---

### Phase 3: Environment Directory Creation (`<name>-dev/`)
Generate the modular subfolder structure:

```text
<name>-dev/
├── setup.sh            # Internal container provisioning script
├── bin/
│   └── change_version  # Unified runtime version manager (if multi-version runtime)
└── README.md           # Sandbox-specific technical documentation
```

#### 1. `setup.sh` Requirements
* **Container check**: Verify execution inside container (`/run/host/container-manager` or `CONTAINER_ID`).
* **Local `.env` loading**: Check for and source `$WORKSPACE_DIR/distrobox_configs/.env` if present.
* **Package installation**: Use `sudo dnf install -y --skip-unavailable ...` (fallback to `apt-get` if Debian/Ubuntu).
* **Conditional GUI / Emulator Pattern (Unified Standard)**:
  If the environment supports desktop interfaces (JavaFX, Qt, GTK), emulators, or multimedia:
  1. Declare the unified master toggle: `INSTALL_GUI="${INSTALL_GUI:-true}"`.
  2. If the environment provides an emulator, inherit from the master toggle: `INSTALL_EMULATOR="${INSTALL_EMULATOR:-$INSTALL_GUI}"`.
  3. When `INSTALL_GUI=false`, condition **all** related layers:
     * **System packages**: Skip Mesa DRI, Vulkan loader, X11, Wayland, GTK, desktop fonts, and audio libraries.
     * **SDK / Tooling components**: Skip emulator packages, system images, or virtual device (AVD) creation.
  4. The headless/CLI fallback MUST remain minimal, fast (< 30s setup), and strictly focused on compiler/runtime tools.
* **Command installation from `bin/`**:
  ```bash
  if [ -d "$SCRIPT_DIR/bin" ]; then
      mkdir -p "$HOME/.local/bin"
      cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
      chmod +x "$HOME/.local/bin/"*
  fi
  ```
* **Persistent environment variables**: Append required paths and exports to `$HOME/.bashrc` (including `$HOME/.local/bin` in `$PATH`).
* **Non-interactive execution**: The script MUST run completely unattended with zero interactive prompts.

#### 2. `bin/change_version` Requirements
* Executable file **without `.sh` extension**.
* Implements the unified version manager specification (see [`version-manager` skill](../version-manager/SKILL.md)).

#### 3. `README.md` Requirements
* Clear overview of pre-installed components and SDKs.
* Usage commands: creation (`./create.sh <name>`), access (`./enter.sh <name>`), and provisioning (`setup.sh`).
* Practical code compilation or project run examples.
* Local customization instructions (`.env` overrides).

---

### Phase 4: Global Registration
* Register the new container in the *Available Environments* table of the root [`README.md`](../../README.md).
* If new environment variables are introduced, document them in [`.env.example`](../../.env.example).

---

### Phase 5: Technical Validation & Git Preparation
* **Syntax check**: Verify bash syntax with `bash -n <scripts>`.
* **Static quality**: Verify static analysis with `shellcheck <scripts>` (zero warnings).
* **Permissions**: Ensure mode `100755` via `chmod +x <scripts>`.
* **Line endings**: Verify Unix LF line endings via `git check-attr text eol -- <scripts>`.
* **Pre-commit audit**: Run `./.githooks/pre-commit` on staged changes.
* **Pre-push audit**: Run `./.githooks/pre-push` across the full repository.
* **Pull Request**: If submitting via PR, complete all sections of [`.github/pull_request_template.md`](../../.github/pull_request_template.md).
