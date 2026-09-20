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
   `${DISTROBOX_HOMES_DIR:-~/.local/share/distrobox-homes}/<name>-dev`
   NEVER mount or share the real host `$HOME`.
2. **Shared Workspace**:
   The host `${WORKSPACE_DIR:-${HOME}/Workspace}` is always transparently mounted at the identical absolute path:
   `${WORKSPACE_DIR:-${HOME}/Workspace}:${WORKSPACE_DIR:-${HOME}/Workspace}:rw`
3. **Hardware Acceleration**:
   Every container must include GPU passthrough and hardware virtualization by default:
   `additional_flags="${DISTROBOX_ADDITIONAL_FLAGS:---device /dev/kvm --device /dev/dri}"`
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
   If an environment manages multiple runtime or SDK versions, it MUST provide `bin/change_version` complying with the unified contract (see [`.agents/skills/version-manager/SKILL.md`](./.agents/skills/version-manager/SKILL.md)).
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
   * Run full repository audit & sandbox validation: `./.githooks/pre-push` (which runs privacy/secrets audit and `./tests/validate-sandboxes.sh`).
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

## 📚 Specialized Skills and Runbooks (`.agents/skills/`)

To prevent context bloat and maintain consistency, procedural workflows and implementation contracts are maintained as modular skills under `.agents/skills/`.

AI agents MUST consult and adhere to these specialized runbooks when performing related tasks:
* **Creating a New Sandbox**: Follow the 5-phase protocol in [`.agents/skills/create-sandbox/SKILL.md`](./.agents/skills/create-sandbox/SKILL.md) for requirements analysis, manifest declaration, non-interactive `setup.sh` patterns (including the Conditional GUI / Emulator Pattern), and catalog updates.
* **Version Manager Implementation**: Follow the contract and technical rules in [`.agents/skills/version-manager/SKILL.md`](./.agents/skills/version-manager/SKILL.md) for standard `change_version` CLI commands.

---

## ✅ Definition of Done (DoD)

A task creating or modifying a sandbox is considered complete ONLY if:
1. The container is declared in [`distrobox.ini`](./distrobox.ini).
2. [`./create.sh`](./create.sh) and [`./enter.sh`](./enter.sh) detect and operate with it automatically.
3. No duplicate `create.sh` or `enter.sh` exists inside `<name>-dev/`.
4. All user CLI commands reside in `<name>-dev/bin/` without `.sh` extension.
5. `setup.sh` is 100% non-interactive, idempotent, transfers `bin/*` to `~/.local/bin/`, and complies with the Conditional GUI / Emulator Pattern when applicable.
6. Environment documentation (`<name>-dev/README.md`) and the main [`README.md`](./README.md) are updated.
7. The repository cleanly passes `./tests/validate-sandboxes.sh` (validating directory structure, manifest declaration, executable permissions `100755`, LF line endings, and syntax `bash -n`).
8. The repository cleanly passes mandatory pre-commit and pre-push checks (`./.githooks/pre-commit` and `./.githooks/pre-push`) with zero personal data, host paths, or leaked credentials, with `--no-verify` strictly prohibited.
9. All code, scripts, CLI tools, messages, comments, and documentation are strictly written in English.
10. If submitting via Pull Request, [`.github/pull_request_template.md`](./.github/pull_request_template.md) is completely filled out with all checklist items verified.
