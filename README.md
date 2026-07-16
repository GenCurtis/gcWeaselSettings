# gcWeaselSettings

> GenCurtis 的 Weasel（小狼毫 / RIME 中州韵输入法）个人配置，**一键安装 + 跨设备同步**。
> 双击 `setup.bat`，在裸 Windows 上自动：装 Weasel → 装思源黑体 → 应用配置 → 部署。
> 平台：Windows 10/11 ｜ 当前 Weasel 0.17.4 ｜ Rime 1.13.1

## 当前特性

- **配色**：Catppuccin 双档 —— 亮色 Latte（`preset_color_schemes/latte`，accent=Mauve `#8839EF`）+ 暗色 Mocha（`preset_color_schemes/mocha`），靠 `color_scheme`/`color_scheme_dark` 跟随系统亮暗
- **排版**：横排候选（`horizontal: true`）
- **布局**：候选词间距 `16` / 序号-字间距 `2` / 选中块内边距 `3`
- **字体**：Source Han Sans VF（思源黑体 Default 区 ≈ 日式字形）—— 候选 / 序号 / 注释
- **字号**：候选+编码 `12`，序号 `11`，注释 `11`
- **候选数**：每页 `9` 个（`1`–`9` 选择）
- **方案**：`luna_pinyin`（朙月拼音，繁体输出）
- **中英切换**：左 Shift = `commit_code`（编码以西文直接上屏 + 切西文）；Shift_R/Caps_Lock 沿用默认

## 文件

| 文件 | 作用 |
|---|---|
| `setup.bat` | **入口**：双击即一键配置（提权后调用 `setup.ps1`） |
| `setup.ps1` | 主脚本：自提权、幂等（缺啥装啥）—— Weasel/字体/配置/部署 |
| `fonts/SourceHanSans-VF.otf` | 内置思源黑体（~30MB；免去下载 888MB 全量包） |
| `weasel.custom.yaml` | 外观配置（配色 / 排版 / 字体 / 字号） |
| `default.custom.yaml` | 全局配置（方案 / 候选数 / 中英切换键） |

## 一键配置（裸机 → 就绪）

**双击 `setup.bat`**，同意 UAC。脚本会：

1. **装 Weasel**（若未装）：从 GitHub 拉最新版安装包，NSIS 静默安装 `/S`；失败则回退到 GUI。
2. **装思源黑体**（若未装）：拷 `fonts/SourceHanSans-VF.otf` 到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` + 注册表 + 广播字体变更。
3. **应用配置**：拷两个 `*.custom.yaml` 到 `%APPDATA%\Rime\`。
4. **部署（静默）**：停 WeaselServer → `WeaselDeployer.exe /deploy`（headless 写 build、不弹窗）→ 重启 server。一次性应用全部配置（双配色/横排/布局/字体/字号/候选数/方案/切换键）。

幂等：已装的跳过，重复运行安全。

## 跨设备同步

**新设备：**
```bat
git clone https://github.com/GenCurtis/gcWeaselSettings.git
cd gcWeaselSettings
setup.bat
```

**把本机改动存回仓库：**
```bat
copy %APPDATA%\Rime\weasel.custom.yaml  weasel.custom.yaml
copy %APPDATA%\Rime\default.custom.yaml default.custom.yaml
git add -A && git commit -m "update settings" && git push
```
> 建议以仓库版（带注释）为基准编辑，再 `setup.bat` 应用，避免 live 标准化版本污染仓库。

## ⚠️ 三个坑（改设置必读）

1. **配色字节序是 BGR**（`0xBBGGRR`），不是 CSS 的 `#RRGGBB`，要把 R/B 两字节对调。例：Mauve `#CBA6F7` → `0xF7A6CB`。
2. **裸跑 `WeaselDeployer.exe`（无参）不部署**，只弹维护 GUI；必须用 `WeaselDeployer.exe /deploy`（源码：无参→维护窗，`/deploy`→`UpdateWorkspace` 真部署）。
3. **静默部署（不弹窗）**：`/deploy` 时若 WeaselServer 在跑，server 进 maintenance 模式会弹窗。要完全静默：**停 server → `/deploy`（headless 写 build）→ 重启 server**（`setup.ps1` 内置此流程）。`/deploy` 一次性应用全部配置，无回退、无需删 build。

> 勘误（2026-07-16）：早期版本以为有"color_scheme 被 server 打回"和"需删 build 仪式"，**均为误诊**——根因是当时裸跑 deployer 只弹维护 GUI、没真部署。真相见上。

## 相关

- 完整设置清单与键名速查：主项目 `notes/Weasel设置清单.md`
- 配色源自 [Catppuccin](https://github.com/catppuccin/catppuccin) · Latte + Mocha
- 字体 [Source Han Sans](https://github.com/adobe-fonts/source-han-sans)（思源黑体）｜ 输入法 [Weasel](https://github.com/rime/weasel)
