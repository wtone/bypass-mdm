#!/bin/bash
# bypass-mdm-v3.sh
# Copyright (c) 2026 assafdori. MIT License; see LICENSE in the repository.
# Safety-focused v3 derivative of wtone/bypass-mdm bypass-mdm-v2.sh.
# Upstream commit: 60583be37d41f314cb04a99e260071fc31a2eaf4
# Upstream SHA256: 1aa477aad2ee4b2dbf2e59214dee05b73c81b392d74f89ac341db77597a98256
# Offline macOS volumes only. NOT verified on a real Mac; no guarantee of MDM removal.
# No arguments: automatic volumes, grouped credentials, one final action menu.
# Parameter mode remains read-only unless --apply or an interactive apply choice is used.
set +x
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C
umask 077

language=zh
changes_started=0

# Fixed format strings only; pass variable text as separate arguments.
message() {
    local format="$1"
    shift
    if [ "$language" = zh ]; then
        case "$format" in
            ERROR) format='错误' ;;
            'Use an absolute mount path directly below /Volumes.') format='请使用 /Volumes 下的卷挂载点绝对路径。' ;;
            'Volume is not mounted: %s') format='卷尚未挂载：%s' ;;
            'Cannot resolve mount path.') format='无法解析挂载路径。' ;;
            'Expected a volume mount point, not a subdirectory.') format='请选择卷挂载点，不能选择其子目录。' ;;
            'Mount path resolves outside /Volumes.') format='挂载路径解析后位于 /Volumes 之外。' ;;
            'Interactive input requires a terminal. Download the file and run it directly; do not pipe it into bash.') format='交互输入需要终端。请先下载脚本文件再直接运行，不要通过管道传入 bash。' ;;
            'Cannot inspect the selected volume.') format='无法读取所选卷的信息。' ;;
            'Selected volume has no APFS volume-group UUID.') format='所选卷没有 APFS 卷组 UUID。' ;;
            'Invalid selected APFS group UUID.') format='所选 APFS 卷组 UUID 无效。' ;;
            'Cannot read APFS volume inventory.') format='无法读取 APFS 卷列表。' ;;
            'Cannot inspect the boot volume.') format='无法读取当前启动卷的信息。' ;;
            'No mounted offline %s volume is available. Mount/unlock the correct volumes in Disk Utility, then rerun.') format='没有可用的已挂载离线 %s 卷。请先在磁盘工具中挂载或解锁正确的卷，再重新运行。' ;;
            'Automatically selected %s volume: %s [%s]') format='自动选择 %s 卷：%s [%s]' ;;
            'Multiple %s candidates found; using the first. Use --system/--data to specify another target.') format='发现多个 %s 候选卷，使用第一个；需要其他目标时可通过 --system/--data 指定。' ;;
            'Cancelled. No changes made.') format='已取消，未进行任何修改。' ;;
            '\nAccount setup (written only if you choose to apply):') format='\n账户设置（仅在确认执行后写入）：' ;;
            'New username [apple] (Ctrl+C to cancel): ') format='请输入新用户名 [apple]（Ctrl+C 取消）：' ;;
            'Username input interrupted.') format='用户名输入已中断。' ;;
            'Use 1-31 ASCII letters/digits/_/-, beginning with a letter.') format='请使用 1–31 个英文字母、数字、_ 或 -，且以英文字母开头。' ;;
            'Choose another NEW username; no existing account will be reused.') format='请换一个全新用户名；不会复用已有账户。' ;;
            '\n1) Check only (default)\n2) Confirm the targets above and apply changes\nq) Cancel\n') format='\n1) 仅检查（默认）\n2) 确认以上目标并执行修改\nq) 取消\n' ;;
            'Action [1]: ') format='请选择操作 [1]：' ;;
            'Action selection interrupted.') format='操作选择已中断。' ;;
            'Enter 1, 2, or q.') format='请输入 1、2 或 q。' ;;
            'Confirm target volumes [APPLY %s %s] (Return accepts; Ctrl+C cancels): ') format='确认目标卷 [APPLY %s %s]（回车接受；Ctrl+C 取消）：' ;;
            'Target confirmation interrupted. No changes made.') format='磁盘确认已中断，未进行任何修改。' ;;
            'Target confirmation did not match. No changes made.') format='磁盘确认文字不匹配，未进行任何修改。' ;;
            'Cannot inspect System volume.') format='无法读取 System 系统卷的信息。' ;;
            'Cannot inspect Data volume.') format='无法读取 Data 数据卷的信息。' ;;
            'System mount point unavailable.') format='无法获取系统卷挂载点。' ;;
            'Data mount point unavailable.') format='无法获取数据卷挂载点。' ;;
            'Paths are not the exact reported mount points.') format='所选路径与系统报告的挂载点不完全一致。' ;;
            'System device ID unavailable.') format='无法获取系统卷设备编号。' ;;
            'Data device ID unavailable.') format='无法获取数据卷设备编号。' ;;
            'Expected base APFS volumes, not snapshots.') format='请选择 APFS 基础卷，不能选择快照。' ;;
            'System and Data must be different volumes.') format='系统卷和数据卷必须是不同的卷。' ;;
            'System APFS volume-group UUID unavailable; stop rather than guess.') format='无法获取系统卷的 APFS 卷组 UUID；已停止，不会猜测。' ;;
            'Data APFS volume-group UUID unavailable; stop rather than guess.') format='无法获取数据卷的 APFS 卷组 UUID；已停止，不会猜测。' ;;
            'Invalid APFS group UUID.') format='APFS 卷组 UUID 无效。' ;;
            'System and Data do NOT belong to the same APFS volume group.') format='系统卷与数据卷不属于同一个 APFS 卷组。' ;;
            'Cannot read APFS volume roles.') format='无法读取 APFS 卷角色。' ;;
            'System volume missing from APFS inventory.') format='APFS 卷列表中找不到所选系统卷。' ;;
            'Data volume missing from APFS inventory.') format='APFS 卷列表中找不到所选数据卷。' ;;
            'Selected volumes do not have System and Data roles respectively.') format='所选卷未分别具有 System 和 Data 角色。' ;;
            'Cannot inspect boot volume.') format='无法读取当前启动卷的信息。' ;;
            'Refusing to modify the currently booted macOS volume group.') format='不能修改当前正在启动运行的 macOS 卷组。' ;;
            'Selected volume identity changed after preflight.') format='检查后所选卷的身份信息发生变化，已停止。' ;;
            'SystemVersion.plist missing.') format='缺少 SystemVersion.plist 文件。' ;;
            'Required directory is absent: %s') format='缺少必要目录：%s' ;;
            'Cannot resolve target directory.') format='无法解析目标目录。' ;;
            'Directory escapes selected Data volume: %s') format='目录解析后位于所选数据卷之外：%s' ;;
            'hosts must be an existing regular file, not a symlink.') format='hosts 必须是已有的普通文件，不能是符号链接。' ;;
            'Unexpected marker type: %s') format='标记文件类型异常：%s' ;;
            'Unexpected .AppleSetupDone type.') format='.AppleSetupDone 文件类型异常。' ;;
            'Cannot read account database; no assumption of an unused name or UID.') format='无法读取账户数据库；不会假定用户名或 UID 可用。' ;;
            'Unexpected account inventory format or non-numeric UID.') format='账户列表格式异常，或 UID 不是整数；已停止。' ;;
            'Account inventory has no root record with UID 0.') format='账户列表中没有 UID 为 0 的 root 记录；已停止，不会假定账户数据库为空。' ;;
            'Username already exists (case-insensitive check). Existing accounts will not be reused or reset.') format='用户名已存在（不区分大小写）。不会复用或重置已有账户。' ;;
            'A home directory or account plist already uses this name.') format='已有用户目录或账户 plist 文件使用了该名称。' ;;
            'Selected UID is now occupied. Stop; do not fall back to 501.') format='所选 UID 已被占用；已停止，不会退回使用 501。' ;;
            'New password [1234] (Return uses default; input hidden): ') format='请输入新密码 [1234]（回车使用默认值；输入隐藏）：' ;;
            'Password input interrupted.') format='密码输入已中断。' ;;
            'Repeat password (Return accepts the chosen password; input hidden): ') format='请再次输入密码（回车确认所选密码；输入隐藏）：' ;;
            'WARNING: the default password 1234 is weak. Change it after signing in.') format='提示：默认密码 1234 很弱，请在登录后修改。' ;;
            'Password confirmation interrupted.') format='密码确认已中断。' ;;
            'Passwords did not match.') format='两次密码不一致，请重新输入。' ;;
            'Unknown domain profile.') format='未知域名选项。' ;;
            'Existing non-loopback hosts mapping conflicts with: %s') format='hosts 中已有的非回环地址映射与该域名冲突：%s' ;;
            'Cannot create hosts staging file.') format='无法创建 hosts 临时文件。' ;;
            'Cannot create backup directory.') format='无法创建备份目录。' ;;
            'Backup (contains device-management configuration; keep private): %s') format='备份位置（包含设备管理配置，请妥善保管）：%s' ;;
            'Creating a NEW administrator. If interrupted, partial changes may remain; inspect the backup manifest before retrying.') format='正在创建全新管理员账户。若中断，可能留下部分修改；重试前请先检查备份清单。' ;;
            '  ✓ MDM bypass setup completed!\n') format='  ✓ MDM 绕过配置已完成！\n' ;;
            '  Login username: %s') format='  登录用户名：%s' ;;
            '  Password: the password you just entered') format='  登录密码：刚才设置的密码' ;;
            '  Configuration backup: %s') format='  配置备份：%s' ;;
            'Next steps:') format='下一步：' ;;
            '  1. Close this terminal window.') format='  1. 关闭当前终端窗口。' ;;
            '  2. Restart your Mac from the Apple menu.') format='  2. 通过苹果菜单重新启动 Mac。' ;;
            '  3. Sign in as %s with the password you just entered.') format='  3. 使用 %s 和刚才设置的密码登录。' ;;
            'Missing value for %s') format='参数 %s 缺少值。' ;;
            'Unknown option: %s') format='未知参数：%s' ;;
            '--check and --apply cannot be combined.') format='--check 与 --apply 不能同时使用。' ;;
            'Run only on macOS; this script has not been validated on your Mac.') format='请仅在 macOS 中运行；此脚本尚未在你的 Mac 上验证。' ;;
            'Cannot resolve selected Data volume group.') format='无法解析所选数据卷的卷组。' ;;
            'Cannot resolve selected System volume group.') format='无法解析所选系统卷的卷组。' ;;
            'System and Data paths must differ.') format='系统卷与数据卷路径不能相同。' ;;
            'Provide a NEW username: 1-31 ASCII letters/digits/_/-, beginning with a letter.') format='请提供全新用户名：1–31 个英文字母、数字、_ 或 -，且以英文字母开头。' ;;
            'No free UID found; refusing fallback.') format='找不到可用 UID；已停止，不会使用备用默认值。' ;;
            '\nSystem: %s (%s)\nData:   %s (%s)\nAPFS group: %s\nNew admin: %s; UID: %s\nHosts: %s\nProfile: %s\n') format='\n系统卷：%s (%s)\n数据卷：%s (%s)\nAPFS 卷组：%s\n新管理员：%s；UID：%s\nhosts 文件：%s\n域名选项：%s\n' ;;
            'Selected domain: %s\n') format='所选域名：%s\n' ;;
            'Existing hosts entries are preserved; selecting fewer domains does not remove earlier blocks.') format='已有 hosts 条目会保留；选择较少域名不会删除之前添加的屏蔽。' ;;
            'READ-ONLY PREFLIGHT COMPLETE. No files, accounts or volumes were changed.') format='只读检查完成，未修改任何文件、账户或卷。' ;;
            'Apply requires root in Recovery. No changes made.') format='执行修改需要恢复模式中的 root 权限，未进行任何修改。' ;;
            'WARNING: six-domain profile blocks activation-related Apple services; acmdm.apple.com was not verified in current official documentation.') format='警告：六域名选项会屏蔽 Apple 激活相关服务；acmdm.apple.com 尚未通过当前官方文档核实。' ;;
            'Target directory is not writable: %s') format='目标目录不可写：%s' ;;
            'Selected hosts file is not writable.') format='所选 hosts 文件不可写。' ;;
            'Preflight stopped (exit status %s). No target files or accounts were changed.') format='检查阶段已停止（退出码 %s），未修改目标文件或账户。' ;;
            'Apply stopped (exit status %s). Partial changes may remain; no automatic rollback was attempted.') format='执行阶段已停止（退出码 %s），可能保留部分修改，未进行自动回滚。' ;;
            'Unknown language: %s. Use zh or en.') format='未知语言：%s。请使用 zh 或 en。' ;;
        esac
    fi
    printf -- "$format" "$@"
}

fail() { printf '%s: %s\n' "$(message 'ERROR')" "$(message "$@")" >&2; exit 1; }
info() { printf '%s\n' "$(message "$@")"; }

# EXIT is not an error hook for every unsuccessful lookup. Bash 3.2 can invoke
# inherited ERR traps inside command substitutions used by conditional probes.
# Report once, from the main shell, and only when the script actually exits.
report_exit() {
    local status="$1"
    unset passw
    [ "$status" -ne 0 ] || return 0
    [ "$BASH_SUBSHELL" -eq 0 ] || return 0
    if [ "$changes_started" -eq 1 ]; then
        info 'Apply stopped (exit status %s). Partial changes may remain; no automatic rollback was attempted.' "$status" >&2
    else
        info 'Preflight stopped (exit status %s). No target files or accounts were changed.' "$status" >&2
    fi
}

install_traps() {
    trap 'report_exit "$?"' EXIT
    trap 'unset passw; exit 130' INT TERM
}

usage() {
    if [ "$language" = zh ]; then
        cat <<'EOF'
用法（在 macOS 恢复模式中运行，离线系统卷及数据卷须已挂载、解锁）：
  bash bypass-mdm-v3.sh
  bash bypass-mdm-v3.sh --lang en
  bash bypass-mdm-v3.sh --check
  bash bypass-mdm-v3.sh --system '/Volumes/系统卷' \
    --data '/Volumes/数据卷' --username NEWNAME [--domains conservative|xiaohu-six] [--check|--apply]

默认中文，不再显示语言选择；--lang en 使用英文。
省略卷路径时自动使用第一个已挂载离线系统卷，以及同组数据卷，不需选卷或回车。
需要其他卷时通过 --system 和 --data 指定完整挂载路径。
用户名默认 apple；密码默认 1234，允许任意自定义密码，不校验强度。
用户名和密码连续输入，再核对目标摘要。输入 2 确认执行，回车仅检查，q 取消。
密码确认时回车接受所选密码；检查或取消时丢弃密码。
--check：仅检查且不询问密码；--apply：进入执行流程，最后确认一次目标磁盘。
--check 与 --apply 不能同时使用。
完整提供目标参数且未指定 --apply 时，仅进行检查。
执行修改需要 root 权限、目标设备编号确认、密码确认及写入前复查。
脚本备份相关文件，创建一个全新管理员，再修改 hosts 和设置标记。
不会重命名、挂载或解锁卷，不会修改安全策略或自动重启。

conservative（默认）：三个注册服务域名。
xiaohu-six：额外添加三个域名，涉及激活服务，并非通用 MDM 屏蔽清单。
EOF
        return 0
    fi
    cat <<'EOF'
Usage (macOS Recovery, mounted/unlocked offline System and Data volumes):
  bash bypass-mdm-v3.sh
  bash bypass-mdm-v3.sh --check
  bash bypass-mdm-v3.sh --system '/Volumes/Your System' \
    --data '/Volumes/Your Data' --username NEWNAME [--domains conservative|xiaohu-six] [--check|--apply]

Chinese is the default; there is no language menu. Use --lang en for English.
Missing paths: automatically select the first mounted offline System and matching Data volumes.
No volume input is needed. Use --system/--data to specify different mount paths.
Username defaults to apple. Username and password are entered together, before the target summary.
Password defaults to 1234; any custom password is accepted without strength checks.
Return confirms the chosen password. Passwords are discarded on check-only or cancel.
The final menu offers check only (default), confirm targets and apply (2), or cancel (q).
--check: preflight only, without asking for a password. --apply: apply flow with one final disk confirmation.
With all target arguments and neither action flag: preflight only, as before.
Apply requires root, rechecks, confirmation of target IDs, and password confirmation.
Apply backs up affected files, creates ONE NEW administrator, and then applies
the upstream hosts/setup-marker changes.
No volume rename, mounting, unlocking, security-policy changes or automatic reboot.

conservative (default): the three enrollment hosts from upstream.
xiaohu-six: explicitly add the other three hosts from the previously reviewed script.
The latter includes activation-related services; it is NOT a universal MDM blocklist.
EOF
}

plist_value() {
    printf '%s\n' "$1" | plutil -extract "$2" raw - 2>/dev/null
}

canonical_mount() {
    local requested="$1" resolved
    case "$requested" in /Volumes/*) ;; *) fail 'Use an absolute mount path directly below /Volumes.' ;; esac
    [ -d "$requested" ] || fail 'Volume is not mounted: %s' "$requested"
    resolved=$(cd "$requested" && pwd -P) || fail 'Cannot resolve mount path.'
    case "${resolved#/Volumes/}" in ''|*/*) fail 'Expected a volume mount point, not a subdirectory.' ;; esac
    case "$resolved" in /Volumes/*) ;; *) fail 'Mount path resolves outside /Volumes.' ;; esac
    printf '%s\n' "$resolved"
}

role_for_device() {
    local xml="$1" wanted="$2" ci=0 vi device role ri
    while plist_value "$xml" "Containers.$ci.ContainerReference" >/dev/null; do
        vi=0
        while device=$(plist_value "$xml" "Containers.$ci.Volumes.$vi.DeviceIdentifier"); do
            if [ "$device" = "$wanted" ]; then
                ri=0
                while role=$(plist_value "$xml" "Containers.$ci.Volumes.$vi.Roles.$ri"); do
                    printf '%s\n' "$role"
                    ri=$((ri + 1))
                done
                return 0
            fi
            vi=$((vi + 1))
        done
        ci=$((ci + 1))
    done
    return 1
}

require_terminal() {
    [ -t 0 ] && [ -t 1 ] || fail 'Interactive input requires a terminal. Download the file and run it directly; do not pipe it into bash.'
}

volume_group_for_path() {
    local xml group
    xml=$(diskutil info -plist "$1") || fail 'Cannot inspect the selected volume.'
    group=$(plist_value "$xml" APFSVolumeGroupID) || fail 'Selected volume has no APFS volume-group UUID.'
    [[ "$group" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]] || fail 'Invalid selected APFS group UUID.'
    printf '%s\n' "$group"
}

list_volume_candidates() {
    local wanted_role="$1" required_group="$2" inventory boot boot_group ci=0 vi device role xml mount group
    candidate_paths=(); candidate_devices=(); candidate_groups=()
    candidate_count=0
    inventory=$(diskutil apfs list -plist) || fail 'Cannot read APFS volume inventory.'
    boot=$(diskutil info -plist /) || fail 'Cannot inspect the boot volume.'
    boot_group=$(plist_value "$boot" APFSVolumeGroupID || true)
    while plist_value "$inventory" "Containers.$ci.ContainerReference" >/dev/null; do
        vi=0
        while device=$(plist_value "$inventory" "Containers.$ci.Volumes.$vi.DeviceIdentifier"); do
            vi=$((vi + 1))
            [[ "$device" =~ ^disk[0-9]+s[0-9]+$ ]] || continue
            role=$(role_for_device "$inventory" "$device") || continue
            [ "$role" = "$wanted_role" ] || continue
            xml=$(diskutil info -plist "$device") || continue
            mount=$(plist_value "$xml" MountPoint) || continue
            case "$mount" in /Volumes/*) ;; *) continue ;; esac
            case "${mount#/Volumes/}" in ''|*/*) continue ;; esac
            [ -d "$mount" ] || continue
            group=$(plist_value "$xml" APFSVolumeGroupID) || continue
            [[ "$group" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]] || continue
            [ -z "$required_group" ] || [ "$group" = "$required_group" ] || continue
            [ -z "$boot_group" ] || [ "$group" != "$boot_group" ] || continue
            candidate_paths+=("$mount")
            candidate_devices+=("$device")
            candidate_groups+=("$group")
            candidate_count=$((candidate_count + 1))
        done
        ci=$((ci + 1))
    done
}

select_default_volume() {
    local wanted_role="$1" required_group="$2"
    list_volume_candidates "$wanted_role" "$required_group"
    [ "$candidate_count" -gt 0 ] || fail 'No mounted offline %s volume is available. Mount/unlock the correct volumes in Disk Utility, then rerun.' "$wanted_role"
    selected_volume_path="${candidate_paths[0]}"
    info 'Automatically selected %s volume: %s [%s]' "$wanted_role" "$selected_volume_path" "${candidate_devices[0]}"
    if [ "$candidate_count" -gt 1 ]; then
        info 'Multiple %s candidates found; using the first. Use --system/--data to specify another target.' "$wanted_role"
    fi
}

prompt_username() {
    require_terminal
    while true; do
        IFS= read -r -p "$(message 'New username [apple] (Ctrl+C to cancel): ')" username || fail 'Username input interrupted.'
        username=${username:-apple}
        if ! validate_username "$username"; then
            info 'Use 1-31 ASCII letters/digits/_/-, beginning with a letter.'
            continue
        fi
        # Run the existing hard-stop conflict checks in a subshell so a typing
        # conflict can be corrected without weakening the final checks.
        if (assert_new_account); then
            return 0
        fi
        info 'Choose another NEW username; no existing account will be reused.'
    done
}

choose_action() {
    local choice
    require_terminal
    message '\n1) Check only (default)\n2) Confirm the targets above and apply changes\nq) Cancel\n'
    while true; do
        IFS= read -r -p "$(message 'Action [1]: ')" choice || fail 'Action selection interrupted.'
        case "$choice" in
            ''|1) selected_action=check; return 0 ;;
            2) selected_action=apply; return 0 ;;
            q|Q) selected_action=cancel; return 0 ;;
            *) info 'Enter 1, 2, or q.' ;;
        esac
    done
}

confirm_targets() {
    local answer
    require_terminal
    IFS= read -r -p "$(message 'Confirm target volumes [APPLY %s %s] (Return accepts; Ctrl+C cancels): ' "$expected_system" "$expected_data")" answer || fail 'Target confirmation interrupted. No changes made.'
    answer=${answer:-"APPLY $expected_system $expected_data"}
    [ "$answer" = "APPLY $expected_system $expected_data" ] || fail 'Target confirmation did not match. No changes made.'
}

validate_volumes() {
    local sx dx sm dm sg dg sid did apfs sr dr boot bg
    sx=$(diskutil info -plist "$system_path") || fail 'Cannot inspect System volume.'
    dx=$(diskutil info -plist "$data_path") || fail 'Cannot inspect Data volume.'
    sm=$(plist_value "$sx" MountPoint) || fail 'System mount point unavailable.'
    dm=$(plist_value "$dx" MountPoint) || fail 'Data mount point unavailable.'
    [ "$sm" = "$system_path" ] && [ "$dm" = "$data_path" ] || fail 'Paths are not the exact reported mount points.'
    sid=$(plist_value "$sx" DeviceIdentifier) || fail 'System device ID unavailable.'
    did=$(plist_value "$dx" DeviceIdentifier) || fail 'Data device ID unavailable.'
    [[ "$sid" =~ ^disk[0-9]+s[0-9]+$ ]] && [[ "$did" =~ ^disk[0-9]+s[0-9]+$ ]] || fail 'Expected base APFS volumes, not snapshots.'
    [ "$sid" != "$did" ] || fail 'System and Data must be different volumes.'
    sg=$(plist_value "$sx" APFSVolumeGroupID) || fail 'System APFS volume-group UUID unavailable; stop rather than guess.'
    dg=$(plist_value "$dx" APFSVolumeGroupID) || fail 'Data APFS volume-group UUID unavailable; stop rather than guess.'
    [[ "$sg" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]] || fail 'Invalid APFS group UUID.'
    [ "$sg" = "$dg" ] || fail 'System and Data do NOT belong to the same APFS volume group.'
    apfs=$(diskutil apfs list -plist) || fail 'Cannot read APFS volume roles.'
    sr=$(role_for_device "$apfs" "$sid") || fail 'System volume missing from APFS inventory.'
    dr=$(role_for_device "$apfs" "$did") || fail 'Data volume missing from APFS inventory.'
    [ "$sr" = System ] && [ "$dr" = Data ] || fail 'Selected volumes do not have System and Data roles respectively.'
    boot=$(diskutil info -plist /) || fail 'Cannot inspect boot volume.'
    bg=$(plist_value "$boot" APFSVolumeGroupID || true)
    [ -z "$bg" ] || [ "$bg" != "$sg" ] || fail 'Refusing to modify the currently booted macOS volume group.'
    if [ -n "${expected_group:-}" ]; then
        [ "$expected_group" = "$sg" ] && [ "$expected_system" = "$sid" ] && [ "$expected_data" = "$did" ] || fail 'Selected volume identity changed after preflight.'
    fi
    expected_group="$sg"; expected_system="$sid"; expected_data="$did"
    [ -f "$system_path/System/Library/CoreServices/SystemVersion.plist" ] || fail 'SystemVersion.plist missing.'
}

physical_directory() {
    local requested="$1" resolved
    [ -d "$requested" ] || fail 'Required directory is absent: %s' "$requested"
    resolved=$(cd "$requested" && pwd -P) || fail 'Cannot resolve target directory.'
    case "$resolved" in "$data_path"/*) ;; *) fail 'Directory escapes selected Data volume: %s' "$requested" ;; esac
    printf '%s\n' "$resolved"
}

validate_paths() {
    db_parent=$(physical_directory "$data_path/private/var/db")
    dscl_path=$(physical_directory "$db_parent/dslocal/nodes/Default")
    users_dir=$(physical_directory "$dscl_path/users")
    homes_dir=$(physical_directory "$data_path/Users")
    etc_dir=$(physical_directory "$data_path/private/etc")
    config_path=$(physical_directory "$db_parent/ConfigurationProfiles/Settings")
    hosts_file="$etc_dir/hosts"
    [ -f "$hosts_file" ] && [ ! -L "$hosts_file" ] || fail 'hosts must be an existing regular file, not a symlink.'
    local marker
    for marker in .cloudConfigHasActivationRecord .cloudConfigRecordFound .cloudConfigProfileInstalled .cloudConfigRecordNotFound; do
        if [ -e "$config_path/$marker" ] || [ -L "$config_path/$marker" ]; then
            [ -f "$config_path/$marker" ] && [ ! -L "$config_path/$marker" ] || fail 'Unexpected marker type: %s' "$marker"
        fi
    done
    if [ -e "$db_parent/.AppleSetupDone" ] || [ -L "$db_parent/.AppleSetupDone" ]; then
        [ -f "$db_parent/.AppleSetupDone" ] && [ ! -L "$db_parent/.AppleSetupDone" ] || fail 'Unexpected .AppleSetupDone type.'
    fi
}

validate_username() {
    [[ "$1" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,30}$ ]]
}

read_users() {
    user_inventory=$(dscl -f "$dscl_path" localhost -list /Local/Default/Users UniqueID) || fail 'Cannot read account database; no assumption of an unused name or UID.'
    # macOS system accounts can have signed UIDs (notably nobody = -2).
    # Keep every record for collision checks; do not filter malformed rows out.
    printf '%s\n' "$user_inventory" | awk 'NF != 2 || $2 !~ /^-?[0-9]+$/ {bad=1} END {exit bad}' || fail 'Unexpected account inventory format or non-numeric UID.'
    printf '%s\n' "$user_inventory" | awk '$1=="root" && $2==0 {root=1} END {exit !root}' || fail 'Account inventory has no root record with UID 0.'
}

assert_new_account() {
    local path
    if printf '%s\n' "$user_inventory" | awk -v u="$username" 'tolower($1)==tolower(u) {found=1} END {exit !found}'; then
        fail 'Username already exists (case-insensitive check). Existing accounts will not be reused or reset.'
    fi
    shopt -s nocasematch
    for path in "$homes_dir"/* "$homes_dir"/.[!.]* "$homes_dir"/..?* "$users_dir"/*.plist; do
        [ -e "$path" ] || [ -L "$path" ] || continue
        if [[ "${path##*/}" == "$username" ]] || [[ "${path##*/}" == "$username.plist" ]]; then
            fail 'A home directory or account plist already uses this name.'
        fi
    done
    shopt -u nocasematch
}

find_available_uid() {
    printf '%s\n' "$user_inventory" | awk '{used[$2]=1} END {for (u=501; u<60000; u++) if (!(u in used)) {print u; exit} exit 1}'
}

assert_uid_free() {
    if printf '%s\n' "$user_inventory" | awk -v u="$available_uid" '$2==u {found=1} END {exit !found}'; then
        fail 'Selected UID is now occupied. Stop; do not fall back to 501.'
    fi
}

get_password() {
    local confirm=''
    while true; do
        IFS= read -r -s -p "$(message 'New password [1234] (Return uses default; input hidden): ')" passw || fail 'Password input interrupted.'
        printf '\n'
        passw=${passw:-1234}
        if [ "$passw" = 1234 ]; then
            info 'WARNING: the default password 1234 is weak. Change it after signing in.'
        fi
        IFS= read -r -s -p "$(message 'Repeat password (Return accepts the chosen password; input hidden): ')" confirm || fail 'Password confirmation interrupted.'
        printf '\n'
        confirm=${confirm:-"$passw"}
        [ "$passw" = "$confirm" ] && break
        info 'Passwords did not match.'
        unset passw
    done
    unset confirm
}

select_domains() {
    domains=(deviceenrollment.apple.com mdmenrollment.apple.com iprofiles.apple.com)
    case "$domain_profile" in
        conservative) ;;
        xiaohu-six) domains+=(acmdm.apple.com albert.apple.com deviceservices-external.apple.com) ;;
        *) fail 'Unknown domain profile.' ;;
    esac
}

check_hosts() {
    local domain
    for domain in "${domains[@]}"; do
        awk -v d="$domain" '{sub(/#.*/, ""); for(i=2;i<=NF;i++) if(tolower($i)==d && $1!="0.0.0.0" && $1!="127.0.0.1" && $1!="::1" && $1!="::") bad=1} END {exit bad}' "$hosts_file" || fail 'Existing non-loopback hosts mapping conflicts with: %s' "$domain"
    done
}

write_hosts() {
    local domain temp
    temp=$(mktemp "$etc_dir/.hosts-mdm.XXXXXX") || fail 'Cannot create hosts staging file.'
    cp -p "$hosts_file" "$temp"
    printf '\n# Enrollment hosts added by reviewed wtone derivative\n' >> "$temp"
    for domain in "${domains[@]}"; do
        if ! awk -v d="$domain" '{sub(/#.*/, ""); for(i=2;i<=NF;i++) if(tolower($i)==d) found=1} END {exit !found}' "$hosts_file"; then
            printf '0.0.0.0 %s\n' "$domain" >> "$temp"
        fi
    done
    mv -f "$temp" "$hosts_file"
}

make_backup() {
    backup_dir=$(mktemp -d "$db_parent/mdm-reviewed-backup.XXXXXX") || fail 'Cannot create backup directory.'
    cp -p "$hosts_file" "$backup_dir/hosts.before"
    cp -Rp "$config_path" "$backup_dir/Settings.before"
    if [ -f "$db_parent/.AppleSetupDone" ]; then
        cp -p "$db_parent/.AppleSetupDone" "$backup_dir/AppleSetupDone.before"
    else
        : > "$backup_dir/AppleSetupDone.was-absent"
    fi
    printf 'system=%s\ndata=%s\nvolume_group=%s\nnew_username=%s\nnew_uid=%s\n' "$system_path" "$data_path" "$expected_group" "$username" "$available_uid" > "$backup_dir/manifest.txt"
    info 'Backup (contains device-management configuration; keep private): %s' "$backup_dir"
}

apply_changes() {
    local user_record="/Local/Default/Users/$username"
    changes_started=1
    make_backup
    info 'Creating a NEW administrator. If interrupted, partial changes may remain; inspect the backup manifest before retrying.'
    dscl -f "$dscl_path" localhost -create "$user_record"
    dscl -f "$dscl_path" localhost -create "$user_record" UserShell /bin/zsh
    dscl -f "$dscl_path" localhost -create "$user_record" RealName "$username"
    dscl -f "$dscl_path" localhost -create "$user_record" UniqueID "$available_uid"
    dscl -f "$dscl_path" localhost -create "$user_record" PrimaryGroupID 20
    dscl -f "$dscl_path" localhost -create "$user_record" NFSHomeDirectory "/Users/$username"
    mkdir "$homes_dir/$username"
    chown "$available_uid:20" "$homes_dir/$username"
    chmod 700 "$homes_dir/$username"
    # Retains upstream dscl password-setting interface: transient process-argument
    # exposure remains possible. Never run under a debugger or shell tracing.
    dscl -f "$dscl_path" localhost -passwd "$user_record" "$passw"
    unset passw
    dscl -f "$dscl_path" localhost -merge /Local/Default/Groups/admin GroupMembership "$username"
    write_hosts
    # Modern macOS mutable files are addressed on Data directly, not through
    # absolute symlinks inside the offline System mount.
    touch "$db_parent/.AppleSetupDone"
    rm -f "$config_path/.cloudConfigHasActivationRecord" "$config_path/.cloudConfigRecordFound"
    touch "$config_path/.cloudConfigProfileInstalled" "$config_path/.cloudConfigRecordNotFound"
    print_success
}

print_success() {
    local green='' cyan='' reset='' rule='────────────────────────────────────────────'
    if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
        green=$'\033[1;32m'; cyan=$'\033[1;36m'; reset=$'\033[0m'
    fi
    printf '\n%s%s\n' "$green" "$rule"
    message '  ✓ MDM bypass setup completed!\n'
    printf '%s%s\n\n' "$rule" "$reset"
    info '  Login username: %s' "$username"
    info '  Password: the password you just entered'
    info '  Configuration backup: %s' "$backup_dir"
    printf '\n%s' "$cyan"
    info 'Next steps:'
    printf '%s' "$reset"
    info '  1. Close this terminal window.'
    info '  2. Restart your Mac from the Apple menu.'
    info '  3. Sign in as %s with the password you just entered.' "$username"
    printf '\n'
}

main() {
    local apply=0 check_only=0 interactive=0 targets_confirmed=0 help_requested=0 target_dir required_group
    language=zh
    unset passw
    system_path=''; data_path=''; username=''; domain_profile=conservative
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --lang)
                [ "$#" -ge 2 ] && [ -n "$2" ] || fail 'Missing value for %s' "$1"
                case "$2" in zh|en) language="$2" ;; *) fail 'Unknown language: %s. Use zh or en.' "$2" ;; esac
                shift 2 ;;
            --system|--data|--username|--domains)
                [ "$#" -ge 2 ] && [ -n "$2" ] || fail 'Missing value for %s' "$1"
                case "$1" in --system) system_path="$2" ;; --data) data_path="$2" ;; --username) username="$2" ;; --domains) domain_profile="$2" ;; esac
                shift 2 ;;
            --apply) apply=1; shift ;;
            --check) check_only=1; shift ;;
            --help|-h) help_requested=1; shift ;;
            *) fail 'Unknown option: %s' "$1" ;;
        esac
    done
    if [ "$help_requested" -eq 1 ]; then usage; return 0; fi
    [ "$apply" -eq 0 ] || [ "$check_only" -eq 0 ] || fail '--check and --apply cannot be combined.'
    [ "$(uname -s)" = Darwin ] || fail 'Run only on macOS; this script has not been validated on your Mac.'
    select_domains
    if [ -z "$system_path" ] || [ -z "$data_path" ] || [ -z "$username" ]; then
        interactive=1
    fi
    if [ -z "$system_path" ]; then
        required_group=''
        if [ -n "$data_path" ]; then
            data_path=$(canonical_mount "$data_path")
            required_group=$(volume_group_for_path "$data_path") || fail 'Cannot resolve selected Data volume group.'
        fi
        select_default_volume System "$required_group"
        system_path="$selected_volume_path"
    fi
    system_path=$(canonical_mount "$system_path")
    if [ -z "$data_path" ]; then
        required_group=$(volume_group_for_path "$system_path") || fail 'Cannot resolve selected System volume group.'
        select_default_volume Data "$required_group"
        data_path="$selected_volume_path"
    fi
    data_path=$(canonical_mount "$data_path")
    [ "$system_path" != "$data_path" ] || fail 'System and Data paths must differ.'
    validate_volumes
    validate_paths
    read_users
    if [ -z "$username" ] || [ "$apply" -eq 1 ] || { [ "$interactive" -eq 1 ] && [ "$check_only" -eq 0 ]; }; then
        info '\nAccount setup (written only if you choose to apply):'
    fi
    if [ -z "$username" ]; then
        prompt_username
    fi
    validate_username "$username" || fail 'Provide a NEW username: 1-31 ASCII letters/digits/_/-, beginning with a letter.'
    assert_new_account
    available_uid=$(find_available_uid) || fail 'No free UID found; refusing fallback.'
    assert_uid_free
    check_hosts
    # Keep account inputs together, before the summary and sole final decision.
    # Explicit --check and fully specified read-only calls never request a password.
    if [ "$apply" -eq 1 ] || { [ "$interactive" -eq 1 ] && [ "$check_only" -eq 0 ]; }; then
        require_terminal
        get_password
    fi
    message '\nSystem: %s (%s)\nData:   %s (%s)\nAPFS group: %s\nNew admin: %s; UID: %s\nHosts: %s\nProfile: %s\n' "$system_path" "$expected_system" "$data_path" "$expected_data" "$expected_group" "$username" "$available_uid" "$hosts_file" "$domain_profile"
    message 'Selected domain: %s\n' "${domains[@]}"
    info 'Existing hosts entries are preserved; selecting fewer domains does not remove earlier blocks.'
    if [ "$interactive" -eq 1 ] && [ "$apply" -eq 0 ] && [ "$check_only" -eq 0 ]; then
        choose_action
        case "$selected_action" in
            apply) apply=1; targets_confirmed=1 ;;
            cancel) unset passw; info 'Cancelled. No changes made.'; return 0 ;;
        esac
    fi
    if [ "$apply" -eq 0 ]; then
        unset passw
        info 'READ-ONLY PREFLIGHT COMPLETE. No files, accounts or volumes were changed.'
        return 0
    fi
    [ "$EUID" -eq 0 ] || fail 'Apply requires root in Recovery. No changes made.'
    if [ "$domain_profile" = xiaohu-six ]; then
        info 'WARNING: six-domain profile blocks activation-related Apple services; acmdm.apple.com was not verified in current official documentation.'
    fi
    if [ "$targets_confirmed" -eq 0 ]; then confirm_targets; fi
    # No sleeping or user input between this recheck and the writes.
    validate_volumes
    validate_paths
    read_users
    assert_new_account
    assert_uid_free
    check_hosts
    for target_dir in "$db_parent" "$dscl_path" "$users_dir" "$homes_dir" "$etc_dir" "$config_path"; do
        [ -w "$target_dir" ] || fail 'Target directory is not writable: %s' "$target_dir"
    done
    [ -w "$hosts_file" ] || fail 'Selected hosts file is not writable.'
    apply_changes
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_traps
    main "$@"
fi
