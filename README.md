# Bypass MDM v3 使用说明

**简体中文** | [English](README-EN.md)

网页入口：[https://cdn.h5ds.com/bypass-mdm](https://cdn.h5ds.com/bypass-mdm)。可在浏览器中切换国内/GitHub 下载地址、一键复制命令，并查看使用说明。网页源文件位于项目根目录的 [index.html](index.html)。

参考视频：[哔哩哔哩视频教程](https://www.bilibili.com/video/BV1zG8M6wEu5)。

下面按“抹盘 → 重装 macOS → 返回恢复模式 → 运行脚本 → 重启登录”的顺序操作，适用于 Apple 芯片 Mac，包括 M3 Pro。

**抹盘会删除目标安装中的文件和账户。先备份数据、接通电源并准备可用网络。** 脚本在 macOS 安装完成后运行，不负责抹盘或安装系统；也不能解除激活锁或组织端的设备归属。

## 1. 进入恢复模式

1. 将 Mac 关机。
2. 按住电源键，看到启动选项后松开。
3. 选择“选项”→“继续”。按提示选择磁盘并输入已有用户密码。

参考 [Apple：从 macOS 恢复启动](https://support.apple.com/en-us/102518)。

## 2. 抹盘并重装 macOS

1. 打开“磁盘工具”，在“内置”区域选中要重装的启动卷，通常为 `Macintosh HD`。核对目标，避免选中备份盘或其他系统。
2. 点击“抹掉”，名称填写 `Macintosh HD`，格式选择 `APFS`。
3. 如果出现“抹掉宗卷组”，选择该选项；否则按窗口中的“抹掉”继续。按要求输入 Apple 账户信息并完成确认。
4. 按屏幕提示联网激活，然后返回恢复工具，选择“重新安装 macOS”。安装到目标系统卷，保持供电，等待安装完成。

具体界面以 [Apple 抹盘说明](https://support.apple.com/en-ie/102506)和[重装说明](https://support.apple.com/en-ie/102655)为准。若无法激活、识别磁盘或完成安装，先处理该问题，再运行脚本。

## 3. 安装完成后，再次进入恢复模式

安装结束进入设置助理后，如果要运行脚本，先关机，再按第 1 节返回恢复模式。不要在正常启动的目标系统中运行。

打开菜单栏“实用工具”→“终端”，确保网络可用。运行：

```bash
diskutil apfs list
diskutil apfs listVolumeGroups
ls /Volumes
```

确认同一 APFS 卷组中的 **System 系统卷**和 **Data 数据卷**已经挂载。如果尚未挂载或需要解锁，先在磁盘工具中选择目标卷并完成“装载”或解锁。

脚本自动使用第一个合格的已挂载离线 System 系统卷，以及同一 APFS 卷组中的第一个 Data 数据卷，不再询问选卷或要求回车。终端会显示所用路径和设备编号；没有合格候选卷时停止。需要其他卷时，通过 `--system '路径' --data '路径'` 指定，并在最后确认前核对目标。

## 4. 一行下载并执行

提供国内下载地址，方便国内网络无法访问 GitHub 或 `raw.githubusercontent.com` 时使用。以下两种方式任选一种，在恢复模式终端粘贴对应整行命令，无需手动填写卷路径或用户名。

### 方式一：【推荐】国内地址

下载地址：[国内 CDN 脚本](https://cdn.h5ds.com/bypass-mdm/bypass-mdm-v3.sh)。

```bash
cd /tmp && curl -fsSL https://cdn.h5ds.com/bypass-mdm/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh
```

### 方式二：GitHub 地址

网络可以访问 GitHub 下载服务时，也可直接使用项目源文件：

```bash
cd /tmp && curl -fsSL https://raw.githubusercontent.com/wtone/bypass-mdm/main/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh
```

两种地址下载后使用相同流程：默认中文、自动匹配系统卷与数据卷，然后连续输入新用户名、密码和密码确认，最后显示目标摘要及一次操作确认：

- 输入 `1` 或直接回车：仅检查，不修改账户或配置。
- 输入 `2`：确认摘要中的目标卷和账户，执行修改，不再重复询问磁盘确认。
- 输入 `q`：取消；输入阶段也可按 Ctrl+C 退出。

仅检查时可在一行命令最后加 `--check`，此时不询问密码。要略过操作菜单并进入执行流程，加 `--apply`；用户名和密码输入完成后，只需最后确认一次目标磁盘。

| 提示 | 直接回车使用的值 | 如何自定义 |
|---|---|---|
| 语言 | 自动使用中文，无需输入 | 命令末尾加 `--lang en` 使用英文 |
| 系统卷 | 自动使用第一个合格卷，无需输入 | 用 `--system '路径'` 指定 |
| 数据卷 | 自动使用与系统卷同组的第一个合格卷，无需输入 | 用 `--data '路径'` 指定 |
| 用户名 | `apple` | 输入未被使用的新用户名 |
| 最后确认 | 仅检查 | 输入 `2` 确认目标并执行；`q` 取消 |
| `--apply` 的最后确认 | 当前显示的 `APPLY 系统设备编号 数据设备编号` | 核对后回车，或原样输入确认文字；Ctrl+C 取消 |
| 密码 | `1234` | 输入任意自定义密码 |
| 再次确认密码 | 上一步选定的密码 | 再次输入相同密码 |

一直回车会完成只读检查，不会执行修改。普通模式下先收集账户输入，最后选择仅检查或取消时会丢弃密码；指定 `--check` 则完全跳过密码输入。自动卷使用第一个合格候选项，最后确认前请核对目标。

已经下载脚本时，可单独执行：

```bash
bash /tmp/bypass-mdm-v3.sh
```

默认直接使用中文，不再弹出语言菜单。可通过参数使用英文或明确指定中文：

```bash
bash /tmp/bypass-mdm-v3.sh --lang zh
bash /tmp/bypass-mdm-v3.sh --lang en
```

一行下载命令的最后加 `--lang en` 即可直接使用英文。脚本自身的菜单、提示、帮助和错误说明随所选语言切换；macOS 命令自身的输出由系统决定。

`/tmp` 中的下载文件可能在重启后消失；需要再次使用时重新下载。

## 5. 按提示完成操作

1. 脚本默认使用中文，自动匹配系统卷与同组数据卷。没有候选卷时，先挂载或解锁后重试。
2. 连续输入用户名和密码：用户名回车使用 `apple`；密码回车使用 `1234`，也可自定义。再次回车确认刚才选定的密码。用户名冲突时需换名，不会复用已有账户。
3. 核对摘要中的卷路径、设备编号及用户名，输入 `2` 确认并执行；回车仅检查，`q` 取消。使用 `--apply` 时，改为在最后的 `APPLY …` 提示回车确认。
4. 等待终端出现“MDM 绕过配置已完成”和“下一步”。若报错，先按下文排查。
5. 按“下一步”关闭终端、重启 Mac，并使用新建账户和刚才设置的密码登录。完成提示包含备份位置，不会显示自定义密码。

用户名：1–31 个字符，以英文字母开头，只使用英文字母、数字、`_` 或 `-`。必须是全新名称，不能与已有账户或用户目录重复。

密码：默认 `1234`，不进行长度、字符种类或用户名包含关系的强度校验；可输入任意自定义密码。空输入表示使用默认值，不会设置空密码。请保存好自定义密码，脚本不会显示其内容。`1234` 很弱，建议登录后立即修改。若 macOS 命令拒绝设置密码，脚本会报错停止。

## 6. 进入系统后的后续操作

手动后续流程为：先在恢复模式关闭 SIP，再登录系统处理标记和 hosts，完成后重新开启 SIP。当前脚本已在离线数据卷处理四个配置标记，并添加三个默认注册域名；正常完成后无需重复执行。需要手动核对或修复时，再使用下面的命令。

### 6.1 手动修复前：先关闭 SIP

如果要按本节在已启动的系统中手动修复，先按以下步骤关闭 SIP；已经显示 `disabled` 时可跳过关闭步骤。正常完成脚本后不需要重复修复，也不需要为了重复操作而关闭 SIP。

1. 将 Mac 关机，长按电源键进入启动选项，选择“选项”→“继续”。
2. 在恢复模式打开“实用工具”→“终端”，执行：

```bash
csrutil disable
```

3. 按屏幕提示完成确认或用户验证，然后通过苹果菜单重新启动，登录 macOS。
4. 在系统终端执行以下命令，确认显示 `disabled`，再继续手动修复：

```bash
csrutil status
```

`csrutil disable` 在恢复模式中执行；`csrutil status` 可在系统终端检查。脚本不会代你切换 SIP。后续操作完成后，按第 6.4 节重新开启 SIP。操作方式参考 [Apple：配置 SIP](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html)。

### 6.2 核对或修复配置标记

先按第 6.1 节关闭 SIP 并登录系统，再执行所需的手动修复；完成后按第 6.4 节恢复。出现 `Operation not permitted` 等错误时先停止并核实权限。

需要手动修复时，先备份现有配置，再将以下命令粘贴到系统终端执行。`sudo` 会要求输入当前管理员密码，输入时不显示字符：

```bash
sudo cp -Rp /var/db/ConfigurationProfiles/Settings "/var/db/ConfigurationProfiles/Settings.before-manual-$(date +%Y%m%d-%H%M%S)" &&
sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord &&
sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound &&
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled &&
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
```

这四项操作是删除前两个标记，并确保后两个标记存在。**`touch` 不会清空已有内容，也不会把文件设成只读。** 如果明确需要把后两个标记清空并设为普通权限只读，可在备份后另执行以下命令；它会覆盖这两个标记的现有内容：

```bash
sudo sh -c ': > /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled &&
: > /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound &&
chmod 444 /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound'
```

`444` 只是文件权限上的只读，不等于不可删除或不可重建，也不能据此保证 OTA 后不会再次出现注册提示。配置备份可能包含设备管理信息，请妥善保管。

### 6.3 可选：编辑 hosts 扩展屏蔽列表

默认脚本已经添加 `iprofiles.apple.com`、`mdmenrollment.apple.com`、`deviceenrollment.apple.com`。扩展名单含有其他用途的 Apple 服务；按 [Apple 联网清单](https://support.apple.com/en-us/101555)，需要区分以下用途：

| 域名 | 用途及影响 |
|---|---|
| `iprofiles.apple.com`、`mdmenrollment.apple.com`、`deviceenrollment.apple.com` | 设备注册相关，已包含在默认脚本中 |
| `gdmf.apple.com` | 软件更新目录及受管理更新查询；屏蔽可能影响系统更新检查 |
| `albert.apple.com` | 设备激活；屏蔽可能影响正常激活 |
| `acmdm.apple.com` | 扩展项；本次所查官方清单中未确认其具体用途 |

需要使用下面这份六域名名单时，先备份 hosts，再以管理员权限打开编辑器：

```bash
sudo cp -p /etc/hosts "/etc/hosts.before-mdm-$(date +%Y%m%d-%H%M%S)" &&
sudo vi /etc/hosts
```

切换到英文输入法，先按 `Esc`，再按 `G` 到最后一行，按小写 `o` 新建末尾空行并进入编辑状态。仅添加尚未存在的条目，保留原有内容：

```text
0.0.0.0 iprofiles.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 acmdm.apple.com
0.0.0.0 albert.apple.com
```

按 `Esc`，输入 `:wq` 并回车保存退出；不保存退出可用 `:q!`。需要刷新 DNS 缓存时执行：

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

这份名单与 `--domains xiaohu-six` 不同，后者包含 `deviceservices-external.apple.com`，不包含 `gdmf.apple.com`。本节仅提供手动操作说明，不改变脚本的默认域名选项。若新增屏蔽后出现更新检查或激活异常，先删除本次新增的相关条目或使用备份恢复，再重试。保留备份并在 OTA 后核对实际状态，不将这些设置视为“以后绝不会再提示”的保证。

### 6.4 恢复开启 SIP

若之前关闭过 SIP，完成所需操作后建议恢复开启；如果 `csrutil status` 已显示 `enabled`，保持现状即可。

1. 关机，长按电源键进入启动选项，选择“选项”→“继续”。
2. 在恢复模式中打开“实用工具”→“终端”，执行：

```bash
csrutil enable
```

3. 按屏幕提示完成验证，再通过苹果菜单重新启动 Mac。
4. 登录系统后再次执行 `csrutil status`，确认显示 `enabled`。

若 App Store 下载的 iPhone/iPad 应用提示启动安全策略不满足，先恢复 SIP，并按应用或系统提示检查启动安全策略；不能仅凭应用打不开就判断是 SIP 导致。命令及重启要求可参考 [Apple：配置 SIP](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html)。

## 7. 可选参数

| 参数 | 如何使用 |
|---|---|
| `--lang zh` / `--lang en` | 指定中文或英文；默认中文，不弹出语言菜单 |
| `--system '路径'` | 可选；省略时自动选择第一个合格 System 卷 |
| `--data '路径'` | 可选；省略时自动选择同组的第一个合格 Data 卷 |
| `--username 名称` | 可选；省略时提示输入，回车使用 `apple`；仍需通过账户冲突检查 |
| `--check` | 仅检查，不询问密码；与 `--apply` 不能同时使用 |
| `--apply` | 连续输入账户信息后，最后确认一次目标磁盘并执行 |
| `--domains conservative` | 默认三域名选项，通常保持默认即可 |
| `--domains xiaohu-six` | 选择六域名选项；包含激活相关服务，可能影响正常激活。切回默认选项不会自动删除已添加的屏蔽 |
| `--help` | 查看帮助，例如 `bash /tmp/bypass-mdm-v3.sh --help` |

要使用六域名选项，在执行命令末尾加上 `--domains xiaohu-six`。

仍可用 `--system`、`--data`、`--username` 一次性指定目标；三个参数都提供且没有 `--apply` 时保持仅检查。交互选择需要可交互的终端，请下载为文件后直接运行，不要用 `curl ... | bash`。

## 8. 常见问题

| 问题 | 处理方法 |
|---|---|
| 下载失败 | 检查恢复环境中的网络，以及能否连接所选地址的 `cdn.h5ds.com` 或 `raw.githubusercontent.com`；可换用另一种下载地址。下载失败时后续步骤不会执行 |
| 没有可选卷、卷未挂载或路径不符 | 用磁盘工具挂载/解锁，再用 `ls /Volumes` 查看实际路径 |
| 卷组、角色或设备编号不匹配 | 重新核对目标 System/Data 组合，不要删除校验来强行继续 |
| 提示当前启动卷不能修改 | 返回恢复模式，操作离线目标安装 |
| 用户名、UID 或用户目录冲突 | 使用一个全新用户名；若刚才执行中断过，先检查是否已经部分创建账户 |
| 出现大量“已在第 … 行停止”，或账户列表校验失败 | 重新下载当前脚本，避免使用旧副本；国内地址仍返回旧内容时，需同步 CDN 文件并刷新缓存。若当前版本仍报错，记录完整错误，勿跳过账户校验 |
| 权限不足或目标不可写 | 用 `id -u` 检查当前权限，执行需要结果为 `0`；同时核对解锁和卷状态 |
| 输入密码没有显示 | 正常；直接回车使用 `1234`，再次回车确认；也可输入自定义密码并确认 |
| 中断或失败后想重试 | 先记录报错及备份位置，检查当前状态；不要连续换名重复执行 |

配置备份位置会打印在终端，位于目标数据卷的 `private/var/db/mdm-reviewed-backup.XXXXXX/`。备份不是整机备份，也没有自动回滚；中途失败可能保留已完成的部分操作。

本脚本尚未在真实 Mac 恢复环境验证。完成信息不代表已解除组织管理，也不保证新账户拥有 FileVault 解锁权限。登录或激活仍受阻时，先核实具体原因。
