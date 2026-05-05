# Claude Desktop Windows 汉化补丁

一键将 Claude Desktop Windows 版界面汉化为简体中文。

## 支持版本

- Claude Desktop **1.5354.0.0** (MSIX/AppX 安装)
- 安装路径：`C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources`

> 其他版本或安装路径需要自行修改 `scripts\apply_all.ps1` 中的 `$base` 变量。

## 使用方法

1. 下载并解压本项目到任意目录
2. **完全退出 Claude Desktop**（右键系统托盘图标 → 退出）
3. 右键 `汉化应用.bat` → **以管理员身份运行**
4. 等待脚本执行完毕
5. 重新打开 Claude Desktop

## 回滚

如需恢复英文界面，右键 `汉化回滚.bat` → 以管理员身份运行。

## 汉化内容

- 完整的 zh-CN 语言资源文件（界面翻译）
- 运行时 JS 补丁（将 zh-CN 加入语言列表）
- 中文字体回退支持

## 常见问题

**汉化后仍然显示英文？**
1. 确认 Claude Desktop 已完全退出再重新打开
2. 清除应用缓存：在文件资源管理器输入 `%LOCALAPPDATA%\AnthropicClaude\Cache`，删除内容后重试

**提示"找不到安装目录"？**
- 你的 Claude 版本或安装路径与补丁不匹配，请检查版本号

**需要管理员权限？**
- 是的，脚本需要写入 `WindowsApps` 目录，会自动请求管理员权限

## 项目结构

```
├── 汉化应用.bat          # 一键汉化入口
├── 汉化回滚.bat          # 一键回滚入口
├── config.json           # 配置文件
├── locales/              # 中文语言资源
│   ├── root-zh-CN.json
│   ├── ion-zh-CN.json
│   ├── ion-zh-CN.json.zst
│   ├── ion-zh-CN.overrides.json
│   ├── ion-zh-CN.overrides.json.zst
│   └── statsig/
│       ├── zh-CN.json
│       └── zh-CN.json.zst
├── scripts/
│   ├── apply_all.ps1     # 核心汉化脚本
│   └── simple_rollback.ps1  # 回滚脚本
└── tests/                # 测试文件
```

## 致谢

基于 [claude-desktop-win-chinese-main](https://github.com/芹菜香/claude-desktop-win-chinese-main) 适配 1.5354.0.0 版本。
