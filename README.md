# Claude Desktop 简体中文汉化补丁

一键将 Claude Desktop Windows 版界面汉化为简体中文。

## 支持版本

| 版本 | 状态 |
|------|------|
| **1.6259.1.0** | 已验证通过 ✅ |
| 其他版本 | 脚本会自动检测安装路径，但侧边栏补丁可能因文件名哈希不一致需要手动更新 `sidebar_patches.json` |

## 使用方法

1. 下载并解压到任意目录
2. **完全退出 Claude Desktop**（右键系统托盘图标 → 退出）
3. 右键 `汉化应用.bat` → **以管理员身份运行**
4. 等待脚本执行完毕
5. 重新打开 Claude Desktop

### 回滚

右键 `汉化回滚.bat` → 以管理员身份运行，可恢复英文界面。

## 汉化原理

汉化分三层进行：

1. **语言文件**：复制 `zh-CN.json` 翻译文件到 Claude 的 `ion-dist/i18n/` 目录
2. **JS 运行时**：将 `zh-CN` 加入支持语言列表，使 Claude 识别并加载中文配置
3. **硬编码字符串**：通过 `sidebar_patches.json` 配置的查找替换规则，修复侧边栏导航项等不走翻译系统的英文文本

## 项目结构

```
├── 汉化应用.bat              # 一键汉化入口（全自动）
├── 汉化回滚.bat              # 一键回滚入口
├── config.json               # 配置文件
├── README.md / .gitignore
├── docs/
│   └── USAGE.md
├── locales/                  # 中文语言资源文件
│   ├── root-zh-CN.json       # 根级翻译
│   ├── ion-zh-CN.json        # UI 界面翻译
│   ├── ion-zh-CN.json.zst
│   ├── ion-zh-CN.overrides.json
│   ├── ion-zh-CN.overrides.json.zst
│   └── statsig/              # 特性开关配置翻译
│       ├── zh-CN.json
│       └── zh-CN.json.zst
└── scripts/
    ├── apply_all.ps1         # 主脚本（自动检测版本、复制文件、JS 补丁、侧边栏补丁）
    ├── simple_rollback.ps1   # 回滚脚本
    ├── sidebar_patches.json  # 硬编码字符串翻译映射表
    └── search_lang.ps1       # 适配新版本时搜索语言列表用
```

## 常见问题

**汉化后界面空白？**
运行 `汉化回滚.bat` 恢复，然后确保 Claude 已完全退出再试一次。

**侧边栏仍是英文？**
确保运行的是最新版脚本，`sidebar_patches.json` 中的文件名哈希需与你的 Claude 版本匹配。

**提示找不到安装目录？**
脚本会自动扫描 `WindowsApps` 下的 Claude 安装。如果未找到，请确认已从官网安装。
