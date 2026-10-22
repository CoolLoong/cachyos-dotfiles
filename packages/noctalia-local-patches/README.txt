Noctalia 独立桌面补丁包 5.3.0.p2

基于官方 Noctalia v5.3.0，提交 a33122c4208a385e19c9a252e65e2751b2c44fbb。

包含的修改
1. 网络页独立显示物理有线网卡，包括未插网线、连接中、已连接、速率、IP 和 MAC。
2. 当前连接和有线网卡的 IP 可直接点击复制；有线信息按名称、状态/速率、IP、MAC 左对齐分行显示，复制不显示悬停提示。
3. 增加已保存 Wi-Fi 连接的自动连接总开关，修改现有无线连接配置的 autoconnect。
4. 增加“有线优先”按钮：有线连接路由 metric 100、Wi-Fi 600；下次连接生效。
5. 资源页磁盘容量固定为十进制 GB，1 GB = 1,000,000,000 字节。
6. 托盘图标四周默认留白 1 个逻辑像素；图标尺寸沿用现有配置的 20 px。
   小部件设置新增 drawer_item_margin，可调 0–8 px。

7. 启动器分类按完整名称自然宽度排列，空间不足时自动换行，避免全部显示省略号。

与官方软件分开
独立包名：noctalia-local-patches
补丁程序：/usr/lib/noctalia-local-patches/bin/noctalia
启动入口：noctalia-patched
管理入口：noctalia-patches
官方 /usr/bin/noctalia 及官方 assets 均不覆盖。

第一次初始化会复制当前设置、主题、插件代码和插件缓存；随后各自维护：
配置：~/.config/noctalia-local-patches/noctalia/
状态：~/.local/state/noctalia-local-patches/noctalia/
插件等数据：~/.local/share/noctalia-local-patches/noctalia/
原配置保留；剪贴板历史不复制。两套程序共用系统网络与系统剪贴板。
点击网络偏好按钮会修改 NetworkManager 的连接配置，切回官方版后仍保留这些系统偏好。

安装
sudo pacman -U ./noctalia-local-patches-5.3.0.p2-1-x86_64.pkg.tar.zst

切换到补丁版
noctalia-patches enable

查看当前配置位置与进程
noctalia-patches status

恢复官方版
noctalia-patches disable

切换只会重启 Noctalia 桌面 shell，不退出 niri，不关闭其他应用。
补丁版启动验证失败时会尝试恢复官方版。
开启补丁版后 niri 的自启动带有缺包回退分支；移除补丁包后下一次登录会使用官方版。

卸载
先运行 noctalia-patches disable，再运行 sudo pacman -R noctalia-local-patches。
卸载不删除两套用户配置，也不卸载官方 noctalia。

重新构建
在本目录安装 makedepends 所列构建依赖后运行 makepkg -s。
源代码固定为上述提交，补丁与源码归档均由 SHA-256 校验。
编译默认并发为 2，避免大幅增加内存压力；内存充足时可用 NOCTALIA_BUILD_JOBS 调整。
官方后续升级不会自动改写补丁包；若共享库 ABI 变化，补丁包可能需要重新构建。

本包提供软件显示和连接控制，不修改网卡驱动。
