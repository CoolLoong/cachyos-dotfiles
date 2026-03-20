#!/bin/bash

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "正在从系统同步配置到项目..."

# 基于 git 已跟踪的文件列表，逐文件同步（避免复制用户数据）
sync_tracked_files() {
    local prefix="$1"  # 如 .config 或 .local/share
    local src_base="$2" # 如 $HOME/.config 或 $HOME/.local/share

    while IFS= read -r file; do
        src="$src_base/${file#"$prefix"/}"
        if [[ -f "$src" ]]; then
            echo "同步 $file"
            mkdir -p "$(dirname "$DOTFILES_DIR/$file")"
            cp -f "$src" "$DOTFILES_DIR/$file"
        else
            echo "跳过 $file（系统中不存在）"
        fi
    done < <(cd "$DOTFILES_DIR" && git ls-files -- "$prefix/")
}

sync_tracked_files ".config" "$HOME/.config"
sync_tracked_files ".local/share" "$HOME/.local/share"

# 同步 /etc 配置
if [[ -f /etc/default/grub ]]; then
    echo "同步 etc/default/grub"
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

# 同步 /usr/share/applications 自定义桌面文件
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

# 同步图片资源
if [[ -d "$HOME/pictures/wallpapers" ]]; then
    echo "同步 pictures/wallpapers/"
    rm -rf "$DOTFILES_DIR/pictures/wallpapers"
    cp -rf "$HOME/pictures/wallpapers" "$DOTFILES_DIR/pictures/wallpapers"
fi

if [[ -f "$HOME/pictures/icon.jpeg" ]]; then
    echo "同步 pictures/icon.jpeg"
    cp -f "$HOME/pictures/icon.jpeg" "$DOTFILES_DIR/pictures/icon.jpeg"
fi

# 更新软件包列表
echo "更新 pkglist.txt..."
pacman -Qqen > "$DOTFILES_DIR/pkglist.txt"

echo "更新 aurlist.txt..."
pacman -Qqem > "$DOTFILES_DIR/aurlist.txt"

echo "同步完成！"
