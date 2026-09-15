#!/bin/bash

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

    while IFS= read -r file; do
        src="$src_base/${file#"$prefix/"}"
        if [[ -f "$src" ]]; then
            echo "同步 $file"
            mkdir -p "$(dirname "$DOTFILES_DIR/$file")"
            cp -f "$src" "$DOTFILES_DIR/$file"
        else
            echo "跳过 $file（系统中不存在）"
        fi
    done < <(cd "$DOTFILES_DIR" && git ls-files -- "$prefix/")
}

sync_system_to_project() {
    echo "正在从系统同步配置到项目..."

    sync_tracked_files ".config" "$HOME/.config"
    sync_tracked_files ".local/share" "$HOME/.local/share"

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
    pacman -Qqem > "$DOTFILES_DIR/aurlist.txt"

    echo "同步完成！"
}

sync_project_to_system() {
    echo "正在从项目同步配置到系统..."

    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        echo "同步 .config/"
        mkdir -p "$HOME/.config"
        cp -rf "$DOTFILES_DIR/.config/." "$HOME/.config/"
    fi

    if [[ -d "$DOTFILES_DIR/.local/share" ]]; then
        echo "同步 .local/share/"
        mkdir -p "$HOME/.local/share"
        cp -rf "$DOTFILES_DIR/.local/share/." "$HOME/.local/share/"
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
