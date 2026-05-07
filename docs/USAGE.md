# 使用说明

## 适用范围

- Claude Desktop **1.6259.1.0**（MSIX/AppX 安装）
- 自动检测 `WindowsApps` 下的安装路径

## 汉化流程

1. 完全退出 Claude Desktop（右键托盘图标 → 退出）
2. 右键 `汉化应用.bat` → 以管理员身份运行
3. 等待脚本输出"Done"
4. 重新打开 Claude Desktop
5. 进入 Settings → Language，确认 zh-CN 已生效

## 回滚

右键 `汉化回滚.bat` → 以管理员身份运行
- 删除所有 zh-CN 语言文件
- 恢复 .zst 缓存（从 .bak 重命名回 .zst）

## 原理说明

汉化过程分四步：

1. **获取权限**：takeown + icacls 获取 WindowsApps 写入权限
2. **复制翻译**：7 个 zh-CN JSON/ZST 文件 → `ion-dist/i18n/`
3. **JS 补丁**：将 zh-CN 加入支持语言列表（Yk 数组）
4. **硬编码补丁**：按 `sidebar_patches.json` 替换侧边栏等硬编码英文字符串

## 适配新版本

当 Claude 更新后，侧边栏补丁可能失效。可用 `search_lang.ps1` 脚本找到新版本的语言列表变量名。
