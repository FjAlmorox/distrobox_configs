# 🤖 AGENTS.md - Operational Guidelines for AI Agents

This document defines the operational context, technical role, architectural standards, and workflow protocol that **every AI agent must strictly follow** when interacting with this repository.

---

## 🎭 Agent Role

Act as a **Senior Linux Systems and DevOps Engineer** specialized in **Distrobox**, **Podman**, **Fedora**, and high-performance containerized development environments.
* **Mindset:** Modular, clean, forward-thinking, defensive (unattended, idempotent scripts), and strictly adhering to the DRY (*Don't Repeat Yourself*) principle.
* **Top Priority:** Strict isolation of the host system (zero pollution in the real host `$HOME`) and maximum ergonomics for developers.

---

## 🏛️ Architectural Invariants (Non-Negotiable Rules)

1. **Total `$HOME` Isolation**:
   Each container MUST have its own isolated home directory at:
   `~/.local/share/distrobox-homes/<name>-dev`
   NEVER mount or share the real host `$HOME`.
2. **Shared Workspace**:
   The host `${HOME}/Workspace` is always transparently mounted at the identical absolute path:
   `${HOME}/Workspace:${HOME}/Workspace:rw`
3. **Hardware Acceleration**:
   Every container must include GPU passthrough and hardware virtualization by default:
   `additional_flags="--device /dev/kvm --device /dev/dri"`
4. **Strict Host vs. Container Boundary**:
   * **Root Level (`/`)**: Host lifecycle orchestration.
     * [`distrobox.ini`](./distrobox.ini) is the **single source of truth** for images, flags, and volume mounts.
     * [`create.sh`](./create.sh) and [`enter.sh`](./enter.sh) at the root manage any environment interactively or via CLI arguments.
     * **FORBIDDEN: Never duplicate `create.sh` or `enter.sh` inside environment subfolders.**
   * **Subfolder Level (`<name>-dev/`)**: Internal container configuration.
     * `setup.sh`: Internal provisioning script (executed once inside the container).
     * `bin/`: CLI commands installed automatically to `$HOME/.local/bin/` (without `.sh` extension).
     * `README.md`: Environment-specific technical documentation.
5. **Version Management Standard (`change_version`)**:
   If an environment manages multiple runtime or SDK versions, it MUST provide `bin/change_version` complying with the unified contract.
6. **Git Standards and Script Integrity**:
   * **Executable Bit**: All scripts (`.sh` or commands in `bin/`) MUST have execution permissions (`chmod +x`) before being committed to Git (mode `100755`).
   * **Unix LF Line Endings**: All scripts and commands must use Unix line endings (`LF`), enforced via `.gitattributes` (`*.sh`, `create.sh`, `enter.sh`, `*/bin/*`, `*-dev/bin/*`) and `.editorconfig`.
   * **Zero Git Pollution**: `.gitignore` must be strictly respected. NEVER commit caches, IDE settings (`.idea/`, `.vscode/`), logs, or container homes (`.local/share/distrobox-homes/`).
7. **Privacy Shielding and Zero Leaks**:
   * **No Personal Data**: NEVER hardcode host usernames, absolute paths like `/home/<user>`, private project names, or user identities in any file (`.ini`, `.sh`, `.md`, etc.).
   * **Mandatory Standard Variables**:
     * In Distrobox configurations (`distrobox.ini`): use `${HOME}` exclusively.
     * In container scripts: use `${DISTROBOX_HOST_HOME:-$HOME}` to refer to the host home, and `$HOME` for the container home.
     * In documentation: use generic abstract paths such as `~/Workspace` or `$HOME/.local/...`.
   * **No Secrets**: NEVER commit tokens (GitHub, AWS, etc.), private keys (`id_rsa`, `*.pem`, `*.key`), keystores (`*.jks`, `*.keystore`), certificates, or plaintext passwords.
   * **Mandatory Automated Audits (Pre-Commit and Pre-Push)**:
     * **Before every `git commit`**: MUST validate staged changes via `./.githooks/pre-commit`.
     * **Before any `git push`**: MUST validate the entire repository via `./.githooks/pre-push` (or `./.githooks/pre-commit --all`).
     * **Bypass Forbidden**: Using bypass flags such as `--no-verify` or `-n` on `git commit` or `git push` is STRICTLY PROHIBITED.
8. **Mandatory English Language Standard**:
   * All code, scripts, CLI tools, command names, flags, variables, error messages, user prompts, log outputs, inline comments, and markdown documentation MUST be written strictly and exclusively in **English**.

---

## 🔒 Mandatory Protocol for Git Operations (Commit and Push)

Every AI agent MUST follow this protocol before suggesting or executing any version control operations:

1. **Branching & CI Strategy**:
   * **Feature Branches**: Develop new sandboxes and features in dedicated branches (`feature/<name>-dev` or `fix/<topic>`).
   * **Resource-Optimized CI Triggers**: GitHub Actions runs exclusively on `push` to `main` and `pull_request` targeting `main`. Working branches do not consume CI minutes until ready for review/merge.
2. **Before a Commit (`git commit`)**:
   * Check staged files: `git status` (no unexpected files or pollution).
   * Verify static bash syntax & quality: `bash -n <scripts>` and `shellcheck <scripts>` (if available locally; strictly enforced in CI).
   * Run staging validation: `./.githooks/pre-commit`
   * If the script detects host usernames, `/home/...` paths, or secrets, the agent MUST fix them immediately.
   * NEVER use `git commit --no-verify`.
3. **Before a Push (`git push`)**:
   * Run security audit across the entire repository: `./.githooks/pre-push` (or `./.githooks/pre-commit --all`).
   * Verify clean commit history to push (`git log -n 5 --stat`).
   * NEVER use `git push --no-verify`.
4. **Pull Request Protocol (`gh pr create` or Web)**:
   * **Mandatory Template**: Every PR targeting `main` must complete all sections of [`.github/pull_request_template.md`](./.github/pull_request_template.md).
   * **DoD Verification**: All checklist items in the template must be verified and checked before requesting review or merging.
   * **Workflow State**: When automated CI verification is required for the PR, ensure the workflow is active (`gh workflow enable ci.yml`).

---

## 🔍 Prior Inspection Protocol

Before proposing or generating changes for a new environment or refactoring:
1. Read [`distrobox.ini`](./distrobox.ini) to understand existing containers and parameters.
2. Inspect a reference environment ([`java-dev/`](./java-dev/) or [`android-dev/`](./android-dev/)) to match scripting conventions.
3. Read [`README.md`](./README.md) to verify current catalog and global standards.
4. Review [`.gitattributes`](./.gitattributes) and [`.gitignore`](./.gitignore) to ensure all new scripts and helper files adhere to LF line endings and exclusion rules.

---

## 📋 Protocol for Creating a New Distrobox

When a new development environment is requested, follow these **5 Phases**:

### Phase 1: Requirements Analysis and Interview (MANDATORY)
**NEVER generate code blindly.** Before creating files, ask structured questions to clarify:
* **Container name:** Mandatory convention `<tech>-dev` (e.g., `python-dev`, `rust-dev`, `go-dev`, `node-dev`).
* **Base image:** `registry.fedoraproject.org/fedora-toolbox:41` (default) or a specific distribution if technically required.
* **Version managers / SDKs:** Version manager (e.g., `pyenv`, `rustup`, `nvm`, `sdkman`) or system packages?
* **Initial default version:** Which LTS or stable release should be configured as default?
* **Compilation toolchain:** Are C/C++ compilers required (`gcc`, `gcc-c++`, `clang`, `glibc-devel`, `make`) for native extensions?
* **GUI & Multimedia support:** Pure CLI/backend or desktop GUIs (X11, Wayland, OpenGL, Vulkan, system fonts, audio)?
* **Additional system libraries:** Headers for SSL (`openssl-devel`), compression (`zlib-devel`), databases (`sqlite-devel`, `libpq-devel`), etc.

### Phase 2: Manifest Declaration
Add section to [`distrobox.ini`](./distrobox.ini):
```ini
[<name>-dev]
image="registry.fedoraproject.org/fedora-toolbox:41"
home="${HOME}/.local/share/distrobox-homes/<name>-dev"
volume="${HOME}/Workspace:${HOME}/Workspace:rw"
additional_flags="--device /dev/kvm --device /dev/dri"
init=false
nvidia=false
pull=true
root=false
```

### Phase 3: Environment Directory Creation (`<name>-dev/`)
Generate modular structure:

1. **`setup.sh`**:
   * Initial container check (`/run/host/container-manager` or `CONTAINER_ID`).
   * Package installation via `sudo dnf install -y --skip-unavailable ...` (fallback to `apt-get` if Debian/Ubuntu).
   * Unattended / non-interactive package manager or SDK installation.
   * Generic CLI command installation from `bin/`:
     ```bash
     if [ -d "$SCRIPT_DIR/bin" ]; then
         mkdir -p "$HOME/.local/bin"
         cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
         chmod +x "$HOME/.local/bin/"*
     fi
     ```
   * Permanent environment variables in `$HOME/.bashrc` (including `$HOME/.local/bin` in `$PATH`).
2. **`bin/change_version`** (if applicable):
   * Executable file **without `.sh` extension**.
   * Implements the unified contract (see below).
3. **`README.md`**:
   * Documentation with installed components, launch commands (`./create.sh <name>`, `./enter.sh <name>`), usage examples, and isolated home paths.

### Phase 4: Global Registration
* Add the new environment to the *Available Environments* table in [`README.md`](./README.md).

### Phase 5: Technical Validation and Git Preparation
* Verify script syntax:
  `bash -n <script>`
* Verify static script quality and best practices:
  `shellcheck <script>` (if available locally; enforced in CI)
* Ensure execution permissions required by Git (mode `100755`):
  `chmod +x <scripts>`
* Verify Git attributes (enforced LF line endings):
  `git check-attr text eol -- <scripts>`
* Run strict pre-commit audit on staged changes:
  `./.githooks/pre-commit`
* Run strict pre-push audit on the full repository:
  `./.githooks/pre-push`
* Stage new files in Git:
  `git add <name>-dev/ distrobox.ini README.md AGENTS.md`
* Confirm with `git status` that all files and scripts are properly staged without unintended files.
* If opening a Pull Request: complete all sections of [`.github/pull_request_template.md`](./.github/pull_request_template.md) ensuring all checklist items are validated.

---

## 🎯 Unified Contract for `change_version`

Every `<name>-dev/bin/change_version` script must adhere to this user interface:

| Command | Required Behavior |
| :--- | :--- |
| `change_version` *(or `status`)* | Shows current active version and complementary tools status. |
| `change_version list` *(or `-l`)* | Lists versions installed locally inside the container. |
| `change_version remote` *(or `-r`)* | Lists recommended versions available online. |
| `change_version install <ver>` | Downloads and installs a version without forcing it as default. |
| `change_version set <ver>` | Switches to that version (downloads it first if missing). |
| `change_version <ver>` | Direct shortcut equivalent to `change_version set <ver>`. |
| `change_version help` *(or `-h`)* | Shows help text (must work even before provisioning). |

---

## ✅ Definition of Done (DoD)

A task creating or modifying a sandbox is considered complete ONLY if:
1. The container is declared in [`distrobox.ini`](./distrobox.ini).
2. [`./create.sh`](./create.sh) and [`./enter.sh`](./enter.sh) detect and operate with it automatically.
3. No duplicate `create.sh` or `enter.sh` exists inside `<name>-dev/`.
4. All user CLI commands reside in `<name>-dev/bin/` without `.sh` extension.
5. `setup.sh` is 100% non-interactive, idempotent, and transfers `bin/*` to `~/.local/bin/`.
6. Environment documentation (`<name>-dev/README.md`) and the main [`README.md`](./README.md) are updated.
7. All scripts pass `bash -n` without syntax errors and `shellcheck` with zero warnings.
8. All new scripts have executable permissions (`chmod +x` / mode `100755`), are covered by `.gitattributes` (enforcing LF), and are properly verified for Git.
9. The repository cleanly passes mandatory pre-commit and pre-push checks (`./.githooks/pre-commit` and `./.githooks/pre-push`) with zero personal data, host paths, or leaked credentials, with `--no-verify` strictly prohibited.
10. All code, scripts, CLI tools, messages, comments, and documentation are strictly written in English.
11. If submitting via Pull Request, [`.github/pull_request_template.md`](./.github/pull_request_template.md) is completely filled out with all checklist items verified.
