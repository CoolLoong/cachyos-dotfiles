#!/bin/bash

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "用法: $0 [模式]"
    echo "  system    更新系统和所有软件包（默认）"
    echo "  aur       从 aurlist.txt 安装 AUR 软件包"
    exit 1
}

MODE="${1:-system}"

case "$MODE" in
    system)
        echo "正在更新官方仓库软件包..."
        sudo pacman -Syu

        if command -v paru &>/dev/null; then
            echo "正在更新 AUR 软件包..."
            paru -Sua
        else
            echo "警告: 未安装 paru，跳过 AUR 更新"
        fi

        if command -v rustup &>/dev/null; then
            echo "正在更新 Rust 工具链..."
            rustup update
        fi

        echo "更新完成！"
        ;;
    aur)
        if ! command -v paru &>/dev/null; then
            echo "错误: 未安装 paru"
            exit 1
        fi
        echo "正在从 aurlist.txt 安装 AUR 软件包..."
        while read -r pkg <&3; do
            [[ -n "$pkg" ]] && paru -S --needed "$pkg"
        done 3< "$DOTFILES_DIR/aurlist.txt"
        echo "AUR 软件包安装完成！"
        ;;
    *)
        usage
        ;;
esac
