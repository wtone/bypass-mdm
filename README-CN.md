# wtone v2 加固副本：中文使用说明

对应脚本：`wtone-bypass-mdm-v2.sh`
文档日期：2026 年 11 月 11 日

[English](README.md) | **简体中文**

本副本基于 wtone 的 `bypass-mdm-v2.sh`，增加密码、账户冲突和目标磁盘校验，保留创建管理员、修改 hosts 和本地设置标记的核心行为。

**默认只做只读预览。显式添加 `--apply` 后才会进入写入流程。** 本副本尚未在真实 Mac 或 macOS 恢复环境中验证，不能保证适用于某个 macOS 版本，也不能保证解除 MDM、激活锁或组织端的设备归属。

## 1. 文件与来源

| 文件 | 用途 |
|---|---|
| `wtone-bypass-mdm-v2.sh` | 加固后的脚本 |
| `README-CN.md` | 本使用说明 |
| `修改说明与域名清单.md` | 修改内容、域名选项和剩余限制 |

上游固定版本：[wtone/bypass-mdm，提交 60583be](https://github.com/wtone/bypass-mdm/blob/60583be37d41f314cb04a99e260071fc31a2eaf4/bypass-mdm-v2.sh)。本副本独立保存，没有覆盖原始下载文件。

本次生成的加固脚本 SHA-256：

```text
c195c142b7828fbedf457ceb7e3865191d4ade1d2274a5b862218330780c4404
```

在 Mac 上可用以下命令核对文件是否与这一版本一致：

```bash
shasum -a 256 ./wtone-bypass-mdm-v2.sh
```

指纹只能核对文件内容是否一致，不是安全认证。自行修改脚本后，指纹会变化。

## 2. 使用前准备

- 使用场景为 macOS 恢复环境中的离线 macOS 安装；系统卷和数据卷需要已经挂载，且相关数据可访问。
- 先备份重要数据。脚本内置的备份仅覆盖部分配置文件，不是整机备份。
- 将脚本保存在能从恢复环境访问的位置，例如外置存储设备。进入脚本所在目录后，再运行下文命令。
- 准备一个没有使用过的新用户名，以及密码管理器生成的唯一强密码。
- 操作期间不要并行修改账户、卸载目标卷或重新挂载磁盘。

M3 Pro 属于 Apple 芯片机型。进入恢复环境的方法是关机后按住电源键，出现启动选项后选择“选项”，再点“继续”。参见 [Apple：在搭载 Apple 芯片的 Mac 上使用 macOS 恢复](https://support.apple.com/guide/mac-help/macos-recovery-a-mac-apple-silicon-mchl82829c17/mac)。在恢复环境中打开终端后继续。

脚本不会自动挂载、解锁或重命名磁盘，也不会关闭系统保护。遇到卷未解锁或信息不完整，应先确认实际情况，不要删除脚本中的校验来强行继续。

## 3. 核对实际磁盘

先查看 APFS 卷和卷组：

```bash
diskutil apfs list
diskutil apfs listVolumeGroups
ls /Volumes
```

需要确认两个不同的目标：

| 参数 | 应当填写什么 |
|---|---|
| `--system` | 角色为 System 的系统卷，填写其完整挂载路径 |
| `--data` | 与该系统卷属于同一 APFS 卷组、角色为 Data 的数据卷，填写其完整挂载路径 |

路径必须是 `/Volumes` 下的卷挂载点，不能填写其中的子目录。名称中包含空格时，保留引号。

**以下命令中的“你的系统卷”“你的数据卷”都是占位文字，必须替换成实际挂载路径。** 不要假定系统卷一定叫 `Macintosh HD`，也不要根据名字相近就认为两个卷属于同一个安装。设备编号也可能在重启后变化。

脚本会检查挂载点、设备编号、System/Data 角色及卷组 UUID，并拒绝以当前启动系统的卷组作为目标。但两个卷通过校验，只能说明它们属于同一个安装，仍需你确认该安装就是原本想操作的目标。

## 4. 先做只读预览

查看帮助：

```bash
bash ./wtone-bypass-mdm-v2.sh --help
```

预览默认三域名模式：

```bash
bash ./wtone-bypass-mdm-v2.sh \
  --system '/Volumes/你的系统卷' \
  --data '/Volumes/你的数据卷' \
  --username NewAdmin
```

`NewAdmin` 也是示例用户名，请换成你准备创建的新用户名。多行命令中，反斜杠 `\` 后不要加空格。

通过检查后，终端会列出目标卷路径及设备编号、APFS 卷组 UUID、新账户及 UID、hosts 路径、域名模式和选定的域名。最后显示：

```text
READ-ONLY PREFLIGHT COMPLETE. No files, accounts or volumes were changed.
```

这表示只读预检查完成。预览不会索取新账户密码，不会创建账户、备份或修改配置；它也不能证明后续写入或登录一定成功。

## 5. 参数说明

| 参数 | 必填 | 含义 |
|---|---|---|
| `--system PATH` | 是，帮助模式除外 | 已挂载的离线系统卷完整路径 |
| `--data PATH` | 是，帮助模式除外 | 与系统卷同组的数据卷完整路径 |
| `--username NAME` | 是，帮助模式除外 | 要创建的新账户名，无默认值 |
| `--domains conservative` | 否 | 三域名模式，默认值 |
| `--domains xiaohu-six` | 否 | 六域名模式，包含额外服务风险，见下一节 |
| `--apply` | 否 | 启用实际写入流程；不提供时仅预览 |
| `--help` 或 `-h` | 否 | 显示帮助 |

用户名须以英文字母开头，共 1–31 个字符，只允许英文字母、数字、下划线 `_` 和连字符 `-`。脚本不区分大小写检查已有账户，并检查同名用户目录和账户 plist；发现冲突就停止，不会复用账户或重置已有账户的密码。

## 6. 域名选项

默认 `conservative` 保留上游原版的三个域名：

```text
deviceenrollment.apple.com
mdmenrollment.apple.com
iprofiles.apple.com
```

`xiaohu-six` 在这三项之外增加：

```text
acmdm.apple.com
albert.apple.com
deviceservices-external.apple.com
```

| 额外域名 | 本次核对结果 |
|---|---|
| `acmdm.apple.com` | 本次未能从当前 Apple 官方文档核实其必要性 |
| `albert.apple.com` | 用于设备激活，屏蔽可能影响正常激活流程 |
| `deviceservices-external.apple.com` | 用于管理服务解除受管设备的激活锁，屏蔽可能影响该流程 |

域名用途参考 [Apple：在企业网络上使用 Apple 产品](https://support.apple.com/en-euro/101555)。六项模式只是与此前小胡版的清单对齐，不代表“完整且必要”；默认三项也不代表保证有效。不同组织可能使用自己的管理服务器。

如果只是查看六项模式的预览：

```bash
bash ./wtone-bypass-mdm-v2.sh \
  --system '/Volumes/你的系统卷' \
  --data '/Volumes/你的数据卷' \
  --username NewAdmin \
  --domains xiaohu-six
```

hosts 写入按完整域名字段检查并忽略注释，保留其他现有内容。已有冲突的非回环地址映射会导致停止。**从六项模式切回三项模式，不会自动移除之前添加的额外屏蔽。**

## 7. 实际执行

先完成预览并核对输出。需要实际写入时，在同一条命令中明确增加 `--apply`：

```bash
bash ./wtone-bypass-mdm-v2.sh \
  --system '/Volumes/你的系统卷' \
  --data '/Volumes/你的数据卷' \
  --username NewAdmin \
  --domains conservative \
  --apply
```

写入需要 root 权限。可用 `id -u` 查看当前用户 ID，root 的结果为 `0`。脚本不会自行提权；不要为绕过权限或当前启动卷的检查，改到正常系统中强行执行。

执行流程如下：

1. 重做预检查，并显示目标信息。
2. 要求输入包含实际设备编号的确认文字。假设终端要求 `APPLY disk3s1 disk3s5`，就输入该完整文字；编号必须以本次输出为准。
3. 隐藏输入新密码，再输入一次确认。输入时不显示字符属于正常行为。
4. 再次核对卷身份、账户、UID、hosts 和目录写入权限。
5. 备份相关配置，然后开始创建新管理员及修改本地配置。

密码没有默认值，要求 16–128 个字符，同时包含大写字母、小写字母、数字和符号，并通过脚本对用户名子串的检查。复杂度规则不能识别所有可猜密码，请使用唯一随机密码。

脚本完成后只报告本地命令没有报错，不会自动重启。它创建的是持久管理员，不会自动过期；也不会自动授予 Secure Token、FileVault 解锁能力或 Apple 芯片的卷所有权。

## 8. 实际修改范围

写入模式会：

- 创建新本地账户、设置密码、创建用户目录并加入管理员组。
- 向选定数据卷的 `private/etc/hosts` 添加缺失的选定域名映射。
- 在该数据卷的 `private/var/db` 下创建 `.AppleSetupDone` 标记。
- 在 `ConfigurationProfiles/Settings` 下删除两个原版指定的激活/记录标记，并创建两个原版指定的配置标记。
- 在该数据卷保存本节以下说明的配置备份。

可写配置直接定位到所选 Data 卷，避免通过离线系统卷中的绝对符号链接误指向恢复环境。原始下载脚本没有被修改。

这些本地操作不会自动解除组织管理平台上的设备归属，也不能据此确认设备已经不再受管理。

## 9. 备份位置及恢复原则

开始修改账户前，脚本会在所选数据卷下创建随机后缀的目录：

```text
/Volumes/实际数据卷/private/var/db/mdm-reviewed-backup.XXXXXX/
```

`XXXXXX` 代表实际生成的随机后缀；以终端打印的位置为准。备份目录权限为 `700`，只允许目录所有者访问，内容可能包含设备管理配置，应妥善保存。

| 备份内容 | 含义 |
|---|---|
| `hosts.before` | 修改前的 hosts 文件 |
| `Settings.before/` | 修改前的配置 Settings 目录 |
| `AppleSetupDone.before` | 首次设置标记原本存在时的副本 |
| `AppleSetupDone.was-absent` | 首次设置标记原本不存在时的记录；与上一项二选一 |
| `manifest.txt` | 目标卷路径、卷组 UUID、拟创建的账户名和 UID；不含密码 |

**备份不是事务，也不包含完整账户数据库或整个用户目录。** 操作清单记录的是计划使用的账户和 UID，不代表每一步都已经执行成功。

如需恢复，先停止操作，核对备份中的卷组和目标安装，逐项比较当前文件与备份，再只恢复需要撤销的改动。如果脚本执行后又有其他配置变化，不应直接整目录覆盖。首次设置标记原本不存在和原本存在的恢复方式不同，应按备份记录处理。

新增账户及其用户目录需要单独核查。不要仅凭账户名或 UID 批量删除，也不要认为还原 hosts 就等于撤销了全部操作。本副本不提供自动回滚命令。

## 10. 常见停止原因

| 提示或现象 | 应检查什么 |
|---|---|
| `Run only on macOS` | 当前环境不是 macOS；Windows 中不能用于真实操作 |
| `Volume is not mounted` | 路径是否正确，目标卷是否已挂载、可访问 |
| `Paths are not the exact reported mount points` | 是否填写了子目录、旧挂载路径或其他非目标路径 |
| `APFS volume-group UUID unavailable` | 当前环境是否提供所需信息；不要仅凭同容器或卷名相似就跳过校验 |
| `do NOT belong to the same APFS volume group` | 两个卷不属于同一安装，重新核对目标 |
| `do not have System and Data roles` | 是否选反、选了快照或其他角色的卷 |
| `currently booted macOS volume group` | 选中了当前运行的系统，改到恢复环境操作离线目标 |
| `Username already exists` / `home directory or account plist` | 使用另一个全新用户名，不要删除既有账户文件来绕过检查 |
| `Cannot read account database` / `Unexpected account inventory` | 数据卷访问权限、解锁状态或账户库格式不符合预期 |
| `Selected UID is now occupied` | 复查发现账户状态变化，停止并排查并行操作 |
| `hosts mapping conflicts` | 已有同域名的非回环映射，需要人工核对其用途 |
| `Required directory is absent` | 当前安装布局不符合脚本预期，不要自行创建目录冒充原有结构 |
| `Target directory is not writable` | 权限或卷状态不满足要求；不要为继续操作关闭系统保护 |
| 密码输入时没有字符 | 正常的隐藏输入；仍需完成两次输入 |
| 中断后再次执行提示用户名冲突 | 可能已经部分创建账户，先核查备份清单和实际账户，不要换名后连续重复执行 |

如果已经开始写入，报错或按 `Ctrl+C` 不会撤销此前成功的操作。记录终端信息和备份位置，先核查现状再决定下一步。

## 11. 已验证内容与限制

目前通过的是 Windows Git Bash 中的 Bash 语法检查及 22 项模拟检查，覆盖密码策略、隐藏输入、账户冲突、UID 耗尽与复查、hosts 匹配、卷角色与卷组校验、当前启动卷保护和默认不写入。

这些检查没有调用真实 macOS 的 `diskutil`、`dscl`，也没有验证 macOS 自带 Bash 3.2、M3 Pro 的具体恢复环境、实际账户登录或 MDM 状态变化。

仍需了解以下限制：

- 密码输入不回显，但设置密码仍沿用上游 `dscl -passwd` 的参数接口，存在短暂的进程参数暴露可能。不要开启 shell 跟踪或调试器。
- 检查与写入不是事务，不能排除并行账户操作或挂载变化造成的竞态。
- 中途失败可能留下部分改动，脚本不会自动删除账户或回滚配置。
- 六域名模式可能影响正常激活相关服务；仅修改 hosts 也不能覆盖所有管理通信。
- 本地修改和预览通过，都不能证明组织端归属已解除。正式释放设备应由原组织管理员通过相应管理平台处理，参考 [Apple：释放设备](https://support.apple.com/en-gb/guide/business/axmec4d28461/web)。

## 12. 旧版说明与许可证

仓库原有的 `bypass-mdm-v2.sh` 和 `bypass-mdm.sh` 保留不变。它们的参数、账户默认值和交互流程与本副本不同；旧版流程参见 [旧版英文 README](docs/README-legacy.md)。不要混用旧版命令与本说明的参数。

本项目遵循 [MIT License](LICENSE)，保留原作者 assafdori 的版权与许可声明。
