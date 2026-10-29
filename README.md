# CachyOS Dotfiles

个人 CachyOS 系统配置文件备份，包含桌面环境、输入法、开发工具等配置。

## 包含内容

- `.config/` - 用户配置文件（niri、fcitx5、alacritty 等）
- `.local/` - 启动脚本、应用入口和选定配置
- `etc/` - 系统配置（SDDM、GRUB）
- `pictures/` - 壁纸等图片资源
- `pkglist.txt` - 官方仓库软件包列表
- `aurlist.txt` - AUR 软件包列表

## 主要软件

| 类别 | 软件 |
|------|------|
| 窗口管理器 | Niri (Wayland) |
| 桌面 Shell | Noctalia 独立补丁版 |
| 终端 | Alacritty |
| 输入法 | Fcitx5 + Rime (雾凇拼音) |
| 编辑器 | VS Code, Zed |
| 浏览器 | Google Chrome |
| 文件管理器 | Tern |
| 登录管理器 | SDDM (Catppuccin 主题) |

## 使用方法

```bash
git clone <repo-url>
cd cachyos-dotfiles
chmod +x init.sh
./init.sh
```

脚本会自动：

1. 创建英文用户目录
2. 安装所有软件包
3. 恢复配置文件
4. 配置系统设置

## 同步配置

```bash
./sync.sh pull  # 本机配置 → 仓库
./sync.sh push  # 仓库配置 → 本机
```

Noctalia 补丁的构建和维护见 [补丁文档](packages/noctalia-local-patches/README.txt)。

## 常用命令

```fish
sudo snapper create -d "备份快照"
```

## 许可证

[MIT](LICENSE)
