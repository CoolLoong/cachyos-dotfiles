# CachyOS Dotfiles

个人 CachyOS 系统配置文件备份，包含桌面环境、输入法、开发工具等配置。

## 包含内容

- `.config/` - 用户配置文件（niri、fcitx5、alacritty 等）
- `.local/bin/` - 应用启动脚本
- `.local/share/` - 用户数据文件
- `.local/state/` - 选定的 Noctalia GUI 设置覆盖，仅跟踪 `settings.toml`
- `etc/` - 系统配置（SDDM、GRUB）
- `pictures/` - 壁纸等图片资源
- `pkglist.txt` - 官方仓库软件包列表
- `aurlist.txt` - AUR 软件包列表
- `aurignore.txt` - 自行管理的本地包，AUR 安装和列表同步时排除（如 `claudebox`）
- `localpkglist.txt` - 本仓库维护的本地软件包列表
- `packages/` - 本地补丁包的源码补丁、PKGBUILD、校验值和版本记录

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

## 同步当前配置

```bash
./sync.sh pull  # 本机配置 → 仓库
./sync.sh push  # 仓库配置 → 本机
```

`pull` 只同步仓库里已选定的配置文件，包括刚放入仓库、尚未提交的文件。
新增配置时，先按用户目录的相同路径放进仓库，再执行 `pull`。
本地软件包会从 `aurlist.txt` 中排除，交给 `localpkglist.txt` 和 `packages/` 管理。

当前生效的 Noctalia 补丁版配置是：

- `.config/noctalia-local-patches/noctalia/migrated-v4.toml`：桌面基础配置。
- `.config/noctalia-local-patches/noctalia/zz-launcher.toml`：启动器配置，隐藏分类和 Recent，All 列表中 Alacritty、Tern 置顶。
- `.local/state/noctalia-local-patches/noctalia/settings.toml`：GUI 保存的配置覆盖，加载优先级高于 `.config` 中的 TOML。
- `.local/share/noctalia-local-patches/noctalia/plugins/system-monitor/`：本地系统监控插件。

官方版的 `.config/noctalia/` 备份与补丁版配置分别保留。历史记录、通知、密钥及插件下载缓存不纳入 Git。
远程歌词插件仍由 Noctalia 插件管理器从配置中保存的 Git 来源恢复；尚未下载该插件的离线目录在校验时会提示插件未加载。
在图形会话中执行 `push` 后，脚本会请求补丁版重新加载配置。

微信使用 `.local/bin/wechat` 启动脚本显式设置 Fcitx 输入法环境，桌面入口也调用这个脚本。
AppImage 需位于 `~/.local/share/wechat/WeChat.AppImage`；仓库保存启动脚本和桌面入口。
恢复脚本会替换旧的 `wechat` 符号链接，保留其指向的 AppImage 文件。

## Noctalia 补丁版本管理

补丁的维护入口为 [packages/noctalia-local-patches](packages/noctalia-local-patches/README.txt)，
当前版本为 `5.3.0.p2-1`，上游固定在 `v5.3.0` 的提交 `a33122c4208a385e19c9a252e65e2751b2c44fbb`。
版本变化见 [CHANGELOG](packages/noctalia-local-patches/CHANGELOG.md)。

```bash
./update.sh local  # 从仓库构建并安装本地补丁包
```

修改补丁后，更新 `PKGBUILD` 中的版本，同时更新补丁中的 `VERSION`、README 及 CHANGELOG，再更新校验值和包元数据：

```bash
cd packages/noctalia-local-patches
updpkgsums  # pacman-contrib 提供
makepkg --printsrcinfo > .SRCINFO
makepkg --verifysource -f
NOCTALIA_BUILD_JOBS=4 makepkg -si --needed
```

每个补丁发布版本使用 `noctalia-local-patches-v<版本>-<pkgrel>` Git 标签。
Git 维护补丁和构建入口；上游源码归档、展开源码、安装包及编译缓存由目录内的 `.gitignore` 排除。
系统及 AUR 更新仍使用 `./update.sh system`，本地补丁由 `./update.sh local` 明确触发构建。

## 检查

```bash
bash -n sync.sh update.sh init.sh
python3 -m unittest discover -s tests -v
python3 packages/noctalia-local-patches/tests/test_control.py
```

工作流测试使用临时用户目录和模拟包管理命令，不修改当前系统。

## 常用命令
```fish
sudo snapper create -d "备份快照"
```

## 许可证

[MIT](LICENSE)
