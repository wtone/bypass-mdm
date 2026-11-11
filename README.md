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

脚本自动使用第一个合格的已挂载离线 System 系统卷，以及同一 APFS 卷组中的第一个 Data 数据卷，不再询问选卷或要求回车。终端会显示所用路径和设备编号；没有合格候选卷时停止。需要其他卷时，运行前通过 `--system '路径' --data '路径'` 指定；想先核对目标时加 `--check`。

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

两种地址均使用无交互自动执行：默认中文，自动匹配同组卷，检查通过后创建临时管理员 `apple`，密码固定为 `1234`，并完成配置。**无需输入用户名、密码或回车确认；默认命令会直接写入修改。**

只想检查时，在命令末尾加 `--check`，此模式不创建账户或写入配置。`--apply` 保留为兼容参数，与默认自动执行相同，不能和 `--check` 同时使用。

| 项目 | 自动使用的值 | 可选命令参数 |
|---|---|---|
| 语言 | 中文 | `--lang en` 使用英文 |
| 系统卷 | 第一个合格的已挂载离线系统卷 | `--system '路径'` |
| 数据卷 | 同一 APFS 卷组中的第一个合格数据卷 | `--data '路径'` |
| 临时用户名 | `apple` | `--username 全新名称` 可指定其他临时名 |
| 临时密码 | 固定 `1234` | 不再询问或接收密码输入 |
| 运行方式 | 自动执行，无二次确认 | `--check` 仅检查 |

仍会检查卷组、角色、路径、已有账户和 UID，并在写入前复查。没有合格卷、同名账户已存在或检查失败时会停止，不会复用、覆盖或重置已有账户。需要其他磁盘时，请在运行前通过参数明确指定。

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

## 5. 自动执行与首次登录

1. 在恢复模式终端执行上方一键命令。脚本自动选卷并完成检查，无需输入或二次确认；没有候选卷时，先挂载或解锁后重试。
2. 等待出现“MDM 绕过配置已完成”和“下一步”。若报错，先按后文排查，不要将报错当作成功。
3. 关闭终端，重启 Mac，使用临时用户名 `apple`、密码 `1234` 登录。完成提示同时显示备份位置。
4. 按第 6.1 节先创建并验证自己的管理员账号，再删除临时账号，之后才进行关闭 SIP 等后续操作。

临时账号仅用于首次登录。密码固定为 `1234`；个人管理员账号的名称和密码在进入系统后通过“用户与群组”自行设置。若使用 `--username` 指定其他临时名称，后文的 `apple` 应替换为该名称。

## 6. 进入系统后的后续操作

先登录临时账户，创建并验证自己的管理员，再删除临时账户。接着关闭 SIP、按下文处理配置标记和注册服务、补齐 hosts 扩展屏蔽列表，完成后恢复 SIP。当前脚本已在离线数据卷处理四个配置标记，并添加三个默认注册域名；下文还包括禁用注册服务和补齐六域名名单的步骤。

### 6.1 关闭 SIP 前：先替换临时管理员账号

**先创建并验证自己的管理员，再删除临时 `apple`；不要先删除唯一可用账号。**

1. 用 `apple / 1234` 登录；如临时账户中已有文件，先备份。
2. 打开“系统设置”→“用户与群组”→“添加用户”，按提示验证，账户类型选择“管理员”，创建自己的全新账号和密码，不要仅重命名 `apple`。
3. 从苹果菜单退出登录，使用新账号登录，确认密码可用且显示为管理员；准备修改 SIP 时，先按下方只读命令核对新账号的 Token 和卷所有权授权，再删除临时账号。
4. 使用新管理员进入“用户与群组”，选择临时 `apple`，点击“删除用户”。按需要保留或删除其个人文件夹；先确认所需文件已备份。不要在仍登录 `apple` 时删除它，也不要用 `rm` 或 `dscl` 强制删除唯一管理员。
5. 后续恢复模式的身份验证使用新管理员账号。完成账号替换后，再按第 6.2 节关闭 SIP。

如果 `csrutil disable` 提示 `no admin user`，不要把“删掉再新建账号”当作必然修复。管理员身份、Secure Token 和 Apple 芯片 Mac 的卷所有权是不同条件；修改启动安全策略涉及管理员及卷所有权。可在新账号的系统终端做以下只读检查：

```bash
sysadminctl -secureTokenStatus "$(id -un)"
dscl . -read "/Users/$(id -un)" GeneratedUID
sudo diskutil apfs listUsers /
```

核对当前账号的 Token 状态，以及其 GUID 对应的卷所有权。如果授权不满足，先按 Apple 流程处理，保留可用账号，不要反复删建或继续关闭 SIP。参考 [Apple：添加用户](https://support.apple.com/guide/mac-help/mh15191/mac)、[删除用户](https://support.apple.com/guide/mac-help/mchlp1557/mac)及 [Secure Token 与卷所有权](https://support.apple.com/guide/deployment/dep24dbdcf9e/web)。

### 6.2 手动修复前：先关闭 SIP

按本节在已启动的系统中进行后续配置前，先按以下步骤关闭 SIP；已经显示 `disabled` 时可跳过关闭步骤。

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

`csrutil disable` 在恢复模式中执行；`csrutil status` 可在系统终端检查。脚本不会代你切换 SIP。后续操作完成后，按第 6.5 节重新开启 SIP。操作方式参考 [Apple：配置 SIP](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html)。

### 6.3 核对或修复配置标记

先按第 6.2 节关闭 SIP 并登录系统，在系统终端依次执行下面 5 条命令。`sudo` 会要求输入当前管理员密码，输入时不显示字符：

```text
sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
sudo launchctl disable system/com.apple.ManagedClient.enroll
```

执行命令检查结果：

```text
sudo profiles show -type enrollment
```

可能出现类似错误：

```text
Error fetching Device Enrollment configuration: (34000) Error Domain=MCCloudConfigurationErrorDomain Code=34000 "The device failed to request configuration from the cloud." UserInfo={NSLocalizedDescription=The device failed to request configuration from the cloud., CloudConfigurationErrorType=CloudConfigurationFatalError}
```

该提示表示本次未能从云端获取设备注册配置。网络屏蔽等情况也可能导致请求失败，不能仅凭错误码 `34000` 判断已解除监管或组织端设备归属；组织端释放需由有权限的管理员操作，参见 [Apple：释放设备](https://support.apple.com/en-gb/guide/business/axmec4d28461/web)。完成后继续第 6.4 节，最后按第 6.5 节恢复 SIP。

### 6.4 编辑 hosts 扩展屏蔽列表

默认脚本已经添加 `iprofiles.apple.com`、`mdmenrollment.apple.com`、`deviceenrollment.apple.com`。扩展名单含有其他用途的 Apple 服务；按 [Apple 联网清单](https://support.apple.com/en-us/101555)，需要区分以下用途：

| 域名 | 用途及影响 |
|---|---|
| `iprofiles.apple.com`、`mdmenrollment.apple.com`、`deviceenrollment.apple.com` | 设备注册相关，已包含在默认脚本中 |
| `gdmf.apple.com` | 软件更新目录及受管理更新查询；屏蔽可能影响系统更新检查 |
| `albert.apple.com` | 设备激活；屏蔽可能影响正常激活 |
| `acmdm.apple.com` | 扩展项；本次所查官方清单中未确认其具体用途 |

接着补齐下面的六域名名单。先备份 hosts，再以管理员权限打开编辑器：

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

### 6.5 恢复开启 SIP

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
| `--username 名称` | 可选临时账户名；默认 `apple`，密码始终为 `1234`；同名时停止 |
| `--check` | 显式只读检查；不创建账户或修改配置，与 `--apply` 不能同时使用 |
| `--apply` | 兼容参数，与默认无交互自动执行相同 |
| `--domains conservative` | 默认三域名选项，通常保持默认即可 |
| `--domains xiaohu-six` | 选择六域名选项；包含激活相关服务，可能影响正常激活。切回默认选项不会自动删除已添加的屏蔽 |
| `--help` | 查看帮助，例如 `bash /tmp/bypass-mdm-v3.sh --help` |

要使用六域名选项，在执行命令末尾加上 `--domains xiaohu-six`。

仍可用 `--system`、`--data`、`--username` 一次性指定目标；无论是否提供完整参数，默认都会执行；需要只读检查必须加 `--check`。脚本应下载为文件后运行。

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
| 同名 `apple` 已存在 | 脚本会停止；不会重置已有账户。已完成设置时无需重跑，必要时用 `--username` 指定其他全新临时名 |
| 中断或失败后想重试 | 先记录报错及备份位置，检查当前状态；不要连续换名重复执行 |

配置备份位置会打印在终端，位于目标数据卷的 `private/var/db/mdm-reviewed-backup.XXXXXX/`。备份不是整机备份，也没有自动回滚；中途失败可能保留已完成的部分操作。

本脚本尚未在真实 Mac 恢复环境验证。完成信息不代表已解除组织管理，也不保证新账户拥有 FileVault 解锁权限。登录或激活仍受阻时，先核实具体原因。
