#!/bin/bash

# 删除中文目录
rm -rf ~/下载 ~/公共 ~/图片 ~/文档 ~/桌面 ~/模板 ~/视频 ~/音乐

# 创建英文目录
mkdir -p ~/downloads ~/public ~/pictures ~/documents ~/desktop ~/templates ~/videos ~/music

# 更新软件包数据库
sudo pacman -Syy

# 安装官方仓库软件包（从 pkglist.txt 读取）
while read -r pkg <&3; do
    [[ -n "$pkg" ]] && sudo pacman -S --needed "$pkg"
done 3< pkglist.txt

# 安装 AUR 软件包（从 aurlist.txt 读取）
while read -r pkg <&3; do
    [[ -n "$pkg" ]] && paru -S --needed "$pkg"
done 3< aurlist.txt

# 删除默认的 Firefox 浏览器（如果已安装）
pacman -Qi firefox &>/dev/null && sudo pacman -Rns firefox

# 恢复用户配置文件
cp -rf ./.config/* ~/.config/

# 恢复用户数据文件
cp -rf ./.local/share/* ~/.local/share/

# 恢复应用程序快捷方式
sudo cp -rf ./usr/share/applications/* /usr/share/applications/

# 配置 SDDM 登录管理器主题
sudo mkdir -p /etc/sddm.conf.d && sudo cp ./etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf

# 恢复 GRUB 引导配置
sudo cp ./etc/default/grub /etc/default/grub

# 恢复图片资源
cp -rf ./pictures/* ~/pictures/

# 刷新字体缓存
fc-cache -fv

# 重新生成 GRUB 引导菜单
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 安装 Rust 工具链（如果未安装）
command -v rustup &>/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 重启 Fcitx5 输入法
pkill fcitx5 || true; fcitx5 -rd &>/dev/null &

# 设置图标主题为 Papirus
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'

# 设置默认终端为 Alacritty
gsettings set org.cinnamon.desktop.default-applications.terminal exec alacritty

# 更新系统图标缓存
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
sudo gtk-update-icon-cache -f /usr/share/icons/Papirus

# 为飞书自动启动脚本添加执行权限
chmod +x ~/.config/niri/feishu-startup.sh

read -p "初始化完成，是否立即重启？[y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] && reboot