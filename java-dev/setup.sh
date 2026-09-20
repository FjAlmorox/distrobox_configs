#!/usr/bin/env bash
set -e

# ==============================================================================
# Java / JVM Tools Provisioning Script (java-dev)
# MUST BE EXECUTED INSIDE THE SANDBOX (DISTROBOX) ONLY
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${DISTROBOX_HOST_HOME:-/home/$(id -un)}/Workspace}"

echo "======================================================="
echo "  🛠️  Provisioning Java/JVM Sandbox Environment       "
echo "======================================================="

# 1. Verify execution inside container
if [ ! -f /run/host/container-manager ] && [ -z "$CONTAINER_ID" ] && [ ! -f /.dockerenv ]; then
    echo "⚠️  WARNING: It appears you are not inside a Distrobox container."
    echo "   Enter first from the host using:"
    echo "     ./enter.sh java-dev"
    echo ""
    read -rp "Are you sure you want to continue here? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 2. Install system packages (utilities, GraalVM toolchain, GUI libraries, and fonts)
echo ""
echo "📦 [1/6] Installing system dependencies (C/C++, GUI, fonts, audio)..."
if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y --skip-unavailable \
        curl wget zip unzip tar sed git which file jq findutils pciutils procps-ng \
        gcc gcc-c++ glibc-devel zlib-devel libstdc++-devel \
        libglvnd-glx mesa-dri-drivers vulkan-loader xrandr \
        gtk3 glib2 libX11 libXext libXdamage libXfixes libXcursor libXrandr libxkbcommon libXi libXrender libXtst libXinerama libXcomposite \
        fontconfig freetype dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts google-noto-sans-fonts google-noto-color-emoji-fonts \
        pulseaudio-libs alsa-lib
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y \
        curl wget zip unzip tar sed git file jq \
        build-essential zlib1g-dev \
        libgl1-mesa-glx libgl1-mesa-dri \
        libgtk-3-0 libx11-6 libxtst6 libxrender1 libxcursor1 libxrandr2 libxi6 \
        fontconfig fonts-dejavu fonts-noto-color-emoji \
        libpulse0 libasound2t64 libvulkan1 pciutils
fi

# 3. Install SDKMAN! if not present
echo ""
echo "📦 [2/6] Setting up SDKMAN!..."
export SDKMAN_DIR="$HOME/.sdkman"
if [ ! -d "$SDKMAN_DIR" ]; then
    echo "📥 Downloading and installing SDKMAN!..."
    curl -s "https://get.sdkman.io" | bash
fi

# Configure non-interactive auto-answer in SDKMAN
mkdir -p "$SDKMAN_DIR/etc"
if [ -f "$SDKMAN_DIR/etc/config" ]; then
    sed -i -e 's/sdkman_auto_answer=false/sdkman_auto_answer=true/' "$SDKMAN_DIR/etc/config"
else
    echo "sdkman_auto_answer=true" > "$SDKMAN_DIR/etc/config"
fi

# Source SDKMAN in current session
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"

# 4. Install Java 21 LTS (Temurin)
echo ""
echo "☕ [3/6] Installing Java 21 LTS (Eclipse Temurin)..."
JAVA_21_VERSION=$(sdk list java 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '\|\s*21\.[0-9].*tem' | awk -F'|' '{print $NF}' | tr -d ' ' | head -n 1)
if [ -z "$JAVA_21_VERSION" ]; then
    JAVA_21_VERSION="21.0.12+1.1-tem"
fi
echo "Detected version: $JAVA_21_VERSION"
sdk install java "$JAVA_21_VERSION" || true
sdk default java "$JAVA_21_VERSION" || true

# 5. Install Build Tools (Gradle & Maven)
echo ""
echo "🐘 [4/6] Installing Gradle and Apache Maven..."
sdk install gradle || true
sdk install maven || true

# 6. Install Kotlin
echo ""
echo "💜 [5/6] Installing Kotlin CLI..."
sdk install kotlin || true

# 7. Configure environment variables in .bashrc
echo ""
echo "⚙️  [6/6] Configuring environment variables in ~/.bashrc..."
if ! grep -q "SDKMAN_DIR" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# SDKMAN Configuration (Distrobox Sandbox java-dev)"
        echo "export SDKMAN_DIR=\"\$HOME/.sdkman\""
        echo "[[ -s \"\$HOME/.sdkman/bin/sdkman-init.sh\" ]] && source \"\$HOME/.sdkman/bin/sdkman-init.sh\""
    } >> "$HOME/.bashrc"
fi

if ! grep -q "JAVA_HOME" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo "export JAVA_HOME=\"\$HOME/.sdkman/candidates/java/current\""
        echo "export PATH=\"\$JAVA_HOME/bin:\$HOME/.local/bin:\$PATH\""
    } >> "$HOME/.bashrc"
fi


# 8. Install CLI tools from bin/ into ~/.local/bin
if [ -d "$SCRIPT_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
fi

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo ""
echo "======================================================="
echo "  🎉 Sandbox java-dev provisioning completed!          "
echo "======================================================="
echo "Installed tools ready in sandbox:"
echo "  • Java:    $(java -version 2>&1 | head -n 1)"
echo "  • Gradle:  $(gradle --version 2>&1 | grep '^Gradle ' || echo 'Gradle installed')"
echo "  • Maven:   $(mvn -version 2>&1 | head -n 1 || echo 'Maven installed')"
echo "  • Kotlin:  $(kotlinc -version 2>&1 || echo 'Kotlin installed')"
echo ""
echo "Available commands in this sandbox:"
echo "  • Version manager: change_version [list|remote|<version>]"
echo "  • Direct SDKMAN:   sdk list java, sdk use java <version>"
echo "======================================================="
