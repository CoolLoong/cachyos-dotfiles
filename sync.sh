#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-}"

usage() {
    echo "用法: $0 {pull|push}"
    echo "  pull  从系统同步配置到项目"
    echo "  push  从项目同步配置到系统"
    exit 1
}

sync_tracked_files() {
    local prefix="$1"
    local src_base="$2"
    local file
    local src

    while IFS= read -r -d '' file; do
        src="$src_base/${file#"$prefix/"}"
        if [[ -f "$src" ]]; then
            echo "同步 $file"
            mkdir -p "$(dirname "$DOTFILES_DIR/$file")"
            cp -f "$src" "$DOTFILES_DIR/$file"
        else
            echo "跳过 $file（系统中不存在）"
        fi
    done < <(cd "$DOTFILES_DIR" && git ls-files -z --cached --others --exclude-standard -- "$prefix/")
}

sync_system_to_project() {
    echo "正在从系统同步配置到项目..."

    sync_tracked_files ".config" "$HOME/.config"
    sync_tracked_files ".local/bin" "$HOME/.local/bin"
    sync_tracked_files ".local/share" "$HOME/.local/share"
    sync_tracked_files ".local/state" "$HOME/.local/state"

    if [[ -f /etc/default/grub ]]; then
        echo "同步 etc/default/grub"
        mkdir -p "$DOTFILES_DIR/etc/default"
        cp -f /etc/default/grub "$DOTFILES_DIR/etc/default/grub"
    fi

    if [[ -d /etc/sddm.conf.d ]]; then
        echo "同步 etc/sddm.conf.d/"
        rm -rf "$DOTFILES_DIR/etc/sddm.conf.d"
        cp -rf /etc/sddm.conf.d "$DOTFILES_DIR/etc/sddm.conf.d"
    fi

    if [[ -f /etc/systemd/logind.conf ]]; then
        echo "同步 etc/systemd/logind.conf"
        mkdir -p "$DOTFILES_DIR/etc/systemd"
        cp -f /etc/systemd/logind.conf "$DOTFILES_DIR/etc/systemd/logind.conf"
    fi

    if [[ -d "$DOTFILES_DIR/usr/share/applications" ]]; then
        for file in "$DOTFILES_DIR"/usr/share/applications/*.desktop; do
            name="$(basename "$file")"
            src="/usr/share/applications/$name"
            if [[ -f "$src" ]]; then
                echo "同步 usr/share/applications/$name"
                cp -f "$src" "$file"
            else
                echo "跳过 usr/share/applications/$name（系统中不存在）"
            fi
        done
    fi

    if [[ -d "$HOME/pictures/wallpapers" ]]; then
        echo "同步 pictures/wallpapers/"
        rm -rf "$DOTFILES_DIR/pictures/wallpapers"
        cp -rf "$HOME/pictures/wallpapers" "$DOTFILES_DIR/pictures/wallpapers"
    fi

    if [[ -f "$HOME/pictures/icon.jpeg" ]]; then
        echo "同步 pictures/icon.jpeg"
        mkdir -p "$DOTFILES_DIR/pictures"
        cp -f "$HOME/pictures/icon.jpeg" "$DOTFILES_DIR/pictures/icon.jpeg"
    fi

    echo "更新 pkglist.txt..."
    pacman -Qqen > "$DOTFILES_DIR/pkglist.txt"

    echo "更新 aurlist.txt..."
    local exclude_lists=()
    local exclude_list
    for exclude_list in localpkglist.txt aurignore.txt; do
        [[ ! -f "$DOTFILES_DIR/$exclude_list" ]] || exclude_lists+=("$DOTFILES_DIR/$exclude_list")
    done
    if (( ${#exclude_lists[@]} > 0 )); then
        pacman -Qqem | awk 'FILENAME != "-" { skip[$0] = 1; next } !($0 in skip)' \
            "${exclude_lists[@]}" - > "$DOTFILES_DIR/aurlist.txt"
    else
        pacman -Qqem > "$DOTFILES_DIR/aurlist.txt"
    fi

    echo "同步完成！"
}

sync_project_to_system() {
    echo "正在从项目同步配置到系统..."

    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        echo "同步 .config/"
        mkdir -p "$HOME/.config"
        cp -rf "$DOTFILES_DIR/.config/." "$HOME/.config/"
    fi

    if [[ -d "$DOTFILES_DIR/.local/bin" ]]; then
        echo "同步 .local/bin/"
        mkdir -p "$HOME/.local/bin"
        cp -rf --remove-destination "$DOTFILES_DIR/.local/bin/." "$HOME/.local/bin/"
    fi

    if [[ -d "$DOTFILES_DIR/.local/share" ]]; then
        echo "同步 .local/share/"
        mkdir -p "$HOME/.local/share"
        cp -rf "$DOTFILES_DIR/.local/share/." "$HOME/.local/share/"
    fi

    # Only selected preference files are kept here; histories and keys are ignored.
    if [[ -d "$DOTFILES_DIR/.local/state" ]]; then
        echo "同步 .local/state/ 配置覆盖"
        mkdir -p "$HOME/.local/state"
        cp -rf "$DOTFILES_DIR/.local/state/." "$HOME/.local/state/"
    fi

    if [[ -f "$DOTFILES_DIR/etc/default/grub" ]]; then
        echo "同步 etc/default/grub"
        sudo install -Dm644 "$DOTFILES_DIR/etc/default/grub" /etc/default/grub
    fi

    if [[ -d "$DOTFILES_DIR/etc/sddm.conf.d" ]]; then
        echo "同步 etc/sddm.conf.d/"
        sudo mkdir -p /etc/sddm.conf.d
        sudo cp -rf "$DOTFILES_DIR/etc/sddm.conf.d/." /etc/sddm.conf.d/
    fi

    if [[ -f "$DOTFILES_DIR/etc/systemd/logind.conf" ]]; then
        echo "同步 etc/systemd/logind.conf"
        sudo install -Dm644 "$DOTFILES_DIR/etc/systemd/logind.conf" /etc/systemd/logind.conf
    fi

    if [[ -d "$DOTFILES_DIR/usr/share/applications" ]]; then
        echo "同步 usr/share/applications/"
        sudo mkdir -p /usr/share/applications
        sudo cp -rf "$DOTFILES_DIR/usr/share/applications/." /usr/share/applications/
    fi

    if [[ -d "$DOTFILES_DIR/pictures" ]]; then
        echo "同步 pictures/"
        mkdir -p "$HOME/pictures"
        cp -rf "$DOTFILES_DIR/pictures/." "$HOME/pictures/"
    fi

    if command -v fcitx5-remote &>/dev/null; then
        if fcitx5-remote -r &>/dev/null; then
            echo "已请求 Fcitx5 重新加载配置"
        else
            echo "提示：当前会话无法重新加载 Fcitx5，请在图形会话中执行 fcitx5-remote -r"
        fi
    fi

    if command -v noctalia-patched &>/dev/null; then
        if noctalia-patched msg config-reload &>/dev/null; then
            echo "已请求 Noctalia 补丁版重新加载配置"
        else
            echo "提示：请在图形会话中执行 noctalia-patched msg config-reload"
        fi
    fi

    echo "同步完成！"
}

case "$MODE" in
    pull)
        sync_system_to_project
        ;;
    push)
        sync_project_to_system
        ;;
    *)
        usage
        ;;
esac
