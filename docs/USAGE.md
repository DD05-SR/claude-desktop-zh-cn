# 使用说明

## 适用范围

- 支持 Claude Desktop **1.5354.0.0** (MSIX/AppX 安装)
- 安装路径：`C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources`

> 其他版本需修改 `scripts\apply_all.ps1` 中的 `$base` 变量，并使用 `搜索语言.bat` 找到正确的 JS 变量名。

## 使用流程

1. **完全退出 Claude Desktop**（检查系统托盘）
2. 右键 `汉化应用.bat` → 以管理员身份运行
3. 等待脚本执行完成
4. 重新打开 Claude Desktop
5. 如果仍显示英文，清除缓存：删除 `%LOCALAPPDATA%\AnthropicClaude\Cache` 中的内容

## 回滚

右键 `汉化回滚.bat` → 以管理员身份运行，会删除所有 zh-CN 文件，恢复英文界面。

## 工作原理

脚本分三步：

1. **复制语言文件**：将项目中 `locales/` 下的 7 个 zh-CN 翻译文件复制到 Claude 安装目录
2. **JS 运行时补丁**：
   - 将 `zh-CN` 加入支持语言列表（`HP` 数组）
   - 添加语言菜单中的中文显示名称
   - 修复侧边栏默认文案
3. **禁用 zst 缓存**：将修改过的 JS/CSS 文件的 `.zst` 压缩版重命名为 `.bak`，确保应用加载修改后的文件

## 常见失败原因

- 版本不匹配
- Claude 未完全退出
- 未以管理员身份运行
- WindowsApps 权限被系统策略阻止
