#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "用法: $0 [模式]"
    echo "  system    更新系统和 AUR 软件包（默认）"
    echo "  pkg       仅安装/更新 pkglist.txt 中的软件包（不升级系统）"
    echo "  aur       从 aurlist.txt 安装 AUR 软件包"
    echo "  local     从 packages/ 构建并安装 localpkglist.txt 中的本地包"
    exit 1
}

MODE="${1:-system}"

install_local_packages() {
    local pkg
    local package_dir
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        [[ -n "$pkg" && "$pkg" != \#* ]] || continue
        package_dir="$DOTFILES_DIR/packages/$pkg"
        if [[ ! -f "$package_dir/PKGBUILD" ]]; then
            echo "错误：本地包 $pkg 缺少 PKGBUILD"
            return 1
        fi
        echo "从仓库构建并安装本地包 $pkg..."
        (cd "$package_dir" && makepkg --syncdeps --install --needed)
    done < "$DOTFILES_DIR/localpkglist.txt"
}

case "$MODE" in
    system)
        echo "正在更新系统并同步 pkglist.txt 中的软件包..."
        sudo pacman -Syu --needed - < "$DOTFILES_DIR/pkglist.txt"

        if command -v paru &>/dev/null; then
            echo "正在更新 AUR 软件包..."
            paru -Sua --skipreview --noconfirm
        else
            echo "警告: 未安装 paru，跳过 AUR 更新"
        fi

        if command -v rustup &>/dev/null; then
            echo "正在更新 Rust 工具链..."
            rustup update
        fi

        echo "更新完成！"
        ;;
    pkg)
        echo "正在安装/更新 pkglist.txt 中的软件包..."
        sudo pacman -S --needed - < "$DOTFILES_DIR/pkglist.txt"
        echo "软件包同步完成！"
        ;;
    aur)
        if ! command -v paru &>/dev/null; then
            echo "错误: 未安装 paru"
            exit 1
        fi
        echo "正在从 aurlist.txt 安装 AUR 软件包..."
        while IFS= read -r pkg <&3 || [[ -n "$pkg" ]]; do
            [[ -n "$pkg" && "$pkg" != \#* ]] || continue
            if [[ -f "$DOTFILES_DIR/localpkglist.txt" ]] && grep -Fxq -- "$pkg" "$DOTFILES_DIR/localpkglist.txt"; then
                echo "跳过本地包 $pkg，请使用 ./update.sh local"
                continue
            fi
            paru -S --needed --skipreview --noconfirm "$pkg"
        done 3< "$DOTFILES_DIR/aurlist.txt"
        echo "AUR 软件包安装完成！"
        ;;
    local)
        install_local_packages
        echo "本地软件包安装完成！"
        ;;
    *)
        usage
        ;;
esac
