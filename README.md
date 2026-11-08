# 网易 POPO Nix 包

支持 `x86_64-linux`，使用官方 deb 和 `buildFHSEnv`。Wayland 桌面需要启用 XWayland。

```sh
nix build .#popo
./result/bin/popo
# 也可以：nix run .#popo
```

桌面入口位于 `result/share/applications/popo.desktop`。Flake 已允许此非自由软件，
`flake.lock` 固定 Nixpkgs；`source.json` 固定 POPO 版本、下载地址和 SHA-256。

## NixOS 配置

在系统 Flake 中添加 `popo` input，并将包加入 `environment.systemPackages`：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    popo.url = "github:Antares0982/nix-netease-popo";
  };

  outputs = { nixpkgs, popo, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        { environment.systemPackages = [ popo.packages.x86_64-linux.popo ]; }
      ];
    };
  };
}
```

输出为 `packages.x86_64-linux.popo` 和同一包的 `packages.x86_64-linux.default`。
仅支持 x64 Linux。包使用本仓库锁定的 Nixpkgs，不要求系统的 Nixpkgs 跟随它。
仓库更新后，在系统配置目录运行 `nix flake update popo`，再运行 `sudo nixos-rebuild switch --flake .#my-host`。

## 更新 POPO

在本目录运行：

```sh
./update.py
nix build .#popo
```

也支持通过 `passthru.updateScript` 调用：

```sh
nix run nixpkgs#nix-update -- --flake --use-update-script popo
nix build .#popo
```

已安装 nix-update 时可直接运行 `nix-update --flake --use-update-script popo`。
此方式需要在本仓库的 Git checkout 内运行。
最后的 `nix build` 也会恢复 `result`，因为 nix-update 1.16 的脚本执行流程会占用该链接。

脚本查询[官网 Linux 接口](https://popo.netease.com/api/open/jsonp/check_version?device=6&callback=popo)，
校验下载域名、deb 包名和架构，从 deb 获取完整版本号，预取 SHA-256 后原子更新 `source.json`。
官网展示版本为 `3.71.1`，deb 完整版本为 `3.71.1.13000`。
由于官方下载文件名使用时间戳，需使用 nix-update 的 `--use-update-script` 模式。

更新 Nixpkgs 则运行 `nix flake update nixpkgs`，随后重新构建。

## 每周自动更新

[Update POPO](https://github.com/Antares0982/nix-netease-popo/actions/workflows/update.yml) 每周一 UTC 03:23（北京时间 11:23）执行，也可手动触发。
它使用本仓库锁定的 Nixpkgs 运行 nix-update，更新 `source.json`，构建并检查 Flake。
全部通过且版本、下载地址或哈希发生变化时，使用 `GITHUB_TOKEN` 自动提交到默认分支；无变化时不提交。
不自动更新 `flake.lock`，也不需要额外的 PAT。

GitHub 对公开仓库有[60 天无活动后停用定时 workflow](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)的规则；停用后需在 Actions 页面重新启用。

## 验证

```sh
python3 update.py --self-test
```

构建保留上游 Qt、CEF、截图和会议组件，使用系统 C++ 运行库，并提供 JPEG 8 和 Theora 1.1 ABI。
已通过 Flake、桌面入口检查及 Xvfb 登录窗口启动验证。
已在临时仓库验证 nix-update 将旧版本和错误哈希更新后成功构建。
登录、消息发送和音视频会议需要账号，未作功能验收。

仓库中的打包代码采用 MIT 许可证；POPO 客户端仍为网易的非自由软件。
