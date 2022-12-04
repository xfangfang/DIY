
本仓库仅供个人测试github各项功能使用

<details>
<summary id="local-switch"> 点击展开 </summary>

#### Docker

```shell
docker run --rm -v $(pwd):/data devkitpro/devkita64:20221113 \
  sh -c "/data/scripts/build_switch.sh"
```

#### 本地编译

```shell
# 1. 安装devkitpro环境: https://github.com/devkitPro/pacman/releases

# 2. 安装预编译的依赖
sudo dkp-pacman -S switch-glfw switch-cmake devkita64-cmake switch-pkg-config

# 3. 安装ffmpeg与mpv（使用自编译的库，官方的库无法播放网络视频）
# 手动编译方法请看：scripts/README.md
sudo dkp-pacman -U \
  https://github.com/xfangfang/wiliwili/releases/download/v0.1.0/switch-ffmpeg-4.4.3-1-any.pkg.tar.xz \
  https://github.com/xfangfang/wiliwili/releases/download/v0.1.0/switch-libmpv-0.34.1-1-any.pkg.tar.xz

# 4. 可选：安装依赖库 nspmini：https://github.com/StarDustCFW/nspmini
# (1). 在resources 目录下放置：nsp_forwarder.nsp
# (2). cmake 构建参数添加 -DBUILTIN_NSP=ON
# 按上述配置后，从相册打开wiliwili时会增加一个安装NSP Forwarder的按钮

# 5. build
cmake -B cmake-build-switch
make -C cmake-build-switch wiliwili.nro -j$(nproc)
```

</details>
