# 冬狮郎 · 冰轮丸（Don't Starve Together）

当前基线：**1.3.3**，对应 [Steam 创意工坊条目 3831773235](https://steamcommunity.com/sharedfiles/filedetails/?id=3831773235)。

本仓库从已发布、下载回读并核对的 Mod 包建立，用于继续开发。它不是原开发仓库的完整恢复：原提交历史、原 UT、资源生成脚本和可编辑美术源文件尚未取得。运行文件的原有署名和说明保留在 [CREDITS.txt](CREDITS.txt)，没有另行声明新的授权协议。

## 当前操作

- F：游戏原生攻击键；实际目标选择遵循原版规则。
- X：默认开启或解除卍解；旧存档的 Z 变身配置会自动按 X 处理，其他自定义键保留。
- Z：范围冰冻，与变身分离。
- 卍解需要至少 60 理智才能开启；冰冻有理智消耗和冷却。
- **目前没有范围灭火功能**，冰冻技能不能用来扑灭树木或建筑火灾。

## 目录与开发

根目录的 `modinfo.lua`、`modmain.lua`、`scripts/`、`anim/`、`bigportraits/`、`images/`、`modicon.*`、`CREDITS.txt` 是原样导入的发布文件。其他目录用于开发规则、记录及测试。

- [发布文件清单及 SHA-256](docs/release-1.3.3-manifest.json)：记录此次导入的 60 个文件。
- [验证范围与已知限制](docs/validation.md)。
- [开发规则](rules/rules.md)。

请在此仓库修改并保留版本记录，不要将 Steam 自动管理的订阅目录当作唯一源码。后续发布只打包运行文件，排除 `.git/`、开发文档、测试环境和日志。内容变更后递增 `modinfo.lua` 的版本，并通过官方 ModUploader 更新原条目；本次 GitHub 导入没有再次发布创意工坊。

## 重跑现有隔离检查

需要 Python 3 和 Lua 5.1 后端的 `lupa`：

```powershell
py -3 -m pip install -r tests/requirements.txt
py -3 tests/check_keybindings.py
```

该检查编译 25 个 Lua 文件，执行 4 种语言的受限元数据加载和 20 项配置迁移/按键分发检查。断言失败时退出码非零。这是新增的有限回归检查，不是原开发仓库的 UT，也不代表完整覆盖率或游戏内验收。

后续拿到原仓库后，按文件差异合并这里的提交，不覆盖原历史。
