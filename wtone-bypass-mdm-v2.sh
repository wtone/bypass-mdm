#!/bin/bash
# wtone-bypass-mdm-v2.sh
# Copyright (c) 2026 assafdori. MIT License; see LICENSE in the repository.
# Safety-focused derivative of wtone/bypass-mdm bypass-mdm-v2.sh.
# Upstream commit: 60583be37d41f314cb04a99e260071fc31a2eaf4
# Upstream SHA256: 1aa477aad2ee4b2dbf2e59214dee05b73c81b392d74f89ac341db77597a98256
# Offline macOS volumes only. NOT verified on a real Mac; no guarantee of MDM removal.
# Default: read-only preflight. --apply explicitly enables the upstream local changes.
set +x
set -Eeuo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C
umask 077

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage (macOS Recovery, mounted/unlocked offline System and Data volumes):
  bash wtone-bypass-mdm-v2.sh --system '/Volumes/Your System' \
    --data '/Volumes/Your Data' --username NEWNAME [--domains conservative|xiaohu-six] [--apply]

Without --apply: inspect volumes, account conflicts, UID and hosts; make no changes.
With --apply: require root, recheck, confirm target IDs, back up affected files,
create ONE NEW administrator, then apply the upstream hosts/setup-marker changes.
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
    [ -d "$requested" ] || fail "Volume is not mounted: $requested"
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
    [ -d "$requested" ] || fail "Required directory is absent: $requested"
    resolved=$(cd "$requested" && pwd -P) || fail 'Cannot resolve target directory.'
    case "$resolved" in "$data_path"/*) ;; *) fail "Directory escapes selected Data volume: $requested" ;; esac
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
            [ -f "$config_path/$marker" ] && [ ! -L "$config_path/$marker" ] || fail "Unexpected marker type: $marker"
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
    printf '%s\n' "$user_inventory" | awk 'NF != 2 || $2 !~ /^[0-9]+$/ {bad=1} $1=="root" && $2==0 {root=1} END {exit (bad || !root)}' || fail 'Unexpected account inventory or missing root record.'
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

validate_password() {
    local value="$1"
    [ "${#value}" -ge 16 ] && [ "${#value}" -le 128 ] || return 1
    [[ "$value" =~ [A-Z] ]] && [[ "$value" =~ [a-z] ]] && [[ "$value" =~ [0-9] ]] && [[ "$value" =~ [^a-zA-Z0-9] ]] || return 1
    [[ "$value" != *"$username"* ]] || return 1
}

get_password() {
    local confirm=''
    while true; do
        IFS= read -r -s -p 'New password (16-128 chars; upper/lower/digit/symbol; no default): ' passw || fail 'Password input interrupted.'
        printf '\n'
        if ! validate_password "$passw"; then
            info 'Password does not meet the policy. Use a unique password from a password manager.'
            unset passw
            continue
        fi
        IFS= read -r -s -p 'Repeat password: ' confirm || fail 'Password confirmation interrupted.'
        printf '\n'
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
        awk -v d="$domain" '{sub(/#.*/, ""); for(i=2;i<=NF;i++) if(tolower($i)==d && $1!="0.0.0.0" && $1!="127.0.0.1" && $1!="::1" && $1!="::") bad=1} END {exit bad}' "$hosts_file" || fail "Existing non-loopback hosts mapping conflicts with: $domain"
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
    info "Backup (contains device-management configuration; keep private): $backup_dir"
}

apply_changes() {
    local user_record="/Local/Default/Users/$username"
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
    info "Local changes completed without a command error. New administrator: $username"
    info 'This does not verify successful MDM removal, Secure Token/FileVault access, or release from the organization.'
}

main() {
    local apply=0 answer target_dir
    system_path=''; data_path=''; username=''; domain_profile=conservative
    [ "$#" -gt 0 ] || { usage; return 0; }
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --system|--data|--username|--domains)
                [ "$#" -ge 2 ] && [ -n "$2" ] || fail "Missing value for $1"
                case "$1" in --system) system_path="$2" ;; --data) data_path="$2" ;; --username) username="$2" ;; --domains) domain_profile="$2" ;; esac
                shift 2 ;;
            --apply) apply=1; shift ;;
            --help|-h) usage; return 0 ;;
            *) fail "Unknown option: $1" ;;
        esac
    done
    [ "$(uname -s)" = Darwin ] || fail 'Run only on macOS; this script has not been validated on your Mac.'
    validate_username "$username" || fail 'Provide a NEW username: 1-31 ASCII letters/digits/_/-, beginning with a letter.'
    system_path=$(canonical_mount "$system_path")
    data_path=$(canonical_mount "$data_path")
    [ "$system_path" != "$data_path" ] || fail 'System and Data paths must differ.'
    validate_volumes
    validate_paths
    read_users
    assert_new_account
    available_uid=$(find_available_uid) || fail 'No free UID found; refusing fallback.'
    assert_uid_free
    select_domains
    check_hosts
    printf '\nSystem: %s (%s)\nData:   %s (%s)\nAPFS group: %s\nNew admin: %s; UID: %s\nHosts: %s\nProfile: %s\n' "$system_path" "$expected_system" "$data_path" "$expected_data" "$expected_group" "$username" "$available_uid" "$hosts_file" "$domain_profile"
    printf 'Selected domain: %s\n' "${domains[@]}"
    info 'Existing hosts entries are preserved; selecting fewer domains does not remove earlier blocks.'
    if [ "$apply" -eq 0 ]; then
        info 'READ-ONLY PREFLIGHT COMPLETE. No files, accounts or volumes were changed.'
        return 0
    fi
    [ "$EUID" -eq 0 ] || fail 'Apply requires root in Recovery. No changes made.'
    if [ "$domain_profile" = xiaohu-six ]; then
        info 'WARNING: six-domain profile blocks activation-related Apple services; acmdm.apple.com was not verified in current official documentation.'
    fi
    info 'This creates a persistent administrator and edits offline system state. It does not grant Secure Token or volume ownership.'
    IFS= read -r -p "Type APPLY $expected_system $expected_data to confirm these exact target volumes: " answer
    [ "$answer" = "APPLY $expected_system $expected_data" ] || fail 'Target confirmation did not match. No changes made.'
    get_password
    # No sleeping or user input between this recheck and the writes.
    validate_volumes
    validate_paths
    read_users
    assert_new_account
    assert_uid_free
    check_hosts
    for target_dir in "$db_parent" "$dscl_path" "$users_dir" "$homes_dir" "$etc_dir" "$config_path"; do
        [ -w "$target_dir" ] || fail "Target directory is not writable: $target_dir"
    done
    [ -w "$hosts_file" ] || fail 'Selected hosts file is not writable.'
    apply_changes
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    trap 'unset passw; printf "Stopped at line %s. Partial changes may remain if applying; no automatic rollback was attempted.\n" "$LINENO" >&2' ERR
    trap 'unset passw; exit 130' INT TERM
    main "$@"
fi
