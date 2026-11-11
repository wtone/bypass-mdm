# Bypass MDM v3 Usage

[简体中文](README.md) | **English**

Web page: [https://cdn.h5ds.com/bypass-mdm](https://cdn.h5ds.com/bypass-mdm). Switch between the China CDN and GitHub download sources, copy commands with one click, and read usage instructions in your browser. The page source is [index.html](index.html) in the project root.

Reference video: [Watch the tutorial on Bilibili](https://www.bilibili.com/video/BV1zG8M6wEu5).

Follow this sequence: erase the target installation, reinstall macOS, return to Recovery, run the script, then restart and sign in. These instructions cover Apple silicon Macs, including M3 Pro.

**Erasing deletes files and accounts in the target installation. Back up your data, connect power, and prepare an internet connection first.** Run the script after macOS is installed; it does not erase or install macOS, remove Activation Lock, or release organization-side ownership.

## 1. Start macOS Recovery

1. Shut down the Mac.
2. Hold the power button until startup options appear, then release it.
3. Select Options, then Continue. Select the requested disk and authenticate if prompted.

See [Apple's Recovery instructions](https://support.apple.com/en-us/102518).

## 2. Erase and reinstall macOS

1. Open Disk Utility and select the intended startup volume under Internal, usually `Macintosh HD`. Verify the target to avoid erasing a backup or another installation.
2. Choose Erase, use `Macintosh HD` as the name, and select `APFS`.
3. Choose Erase Volume Group if offered; otherwise use Erase. Provide Apple Account details and confirm when requested.
4. Follow the network activation prompts, return to Recovery utilities, and select Reinstall macOS. Install on the intended System volume and keep power connected until installation finishes.

Follow the current screens described in [Apple's erase guide](https://support.apple.com/en-ie/102506) and [reinstallation guide](https://support.apple.com/en-ie/102655). Resolve activation, disk detection, or installation errors before running the script.

## 3. Return to Recovery after installation

When installation reaches Setup Assistant, shut down and use section 1 to return to Recovery if you intend to run the script. Do not run it against the normally booted target installation.

Open Utilities > Terminal from the menu bar and make sure networking works. Run:

```bash
diskutil apfs list
diskutil apfs listVolumeGroups
ls /Volumes
```

Identify the **System volume** and matching **Data volume** in the same APFS volume group. Both must be mounted. Use Disk Utility to mount or unlock them first if needed.

The script automatically uses the first eligible mounted offline System volume and the first eligible Data volume in the same APFS group. There are no volume menus or Return prompts. The selected paths and device IDs are displayed; no eligible candidate means the script stops. Specify different targets with `--system 'path' --data 'path'` before running; add `--check` to review them without changes.

## 4. Download and run in one line

A mainland China download address is available for networks that cannot reach GitHub or `raw.githubusercontent.com`. Choose either method below and paste its complete command into Terminal in Recovery. No volume-path or username arguments need to be edited.

### Method 1: [Recommended] Mainland China address

Download: [Mainland China CDN script](https://cdn.h5ds.com/bypass-mdm/bypass-mdm-v3.sh).

```bash
cd /tmp && curl -fsSL https://cdn.h5ds.com/bypass-mdm/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh
```

### Method 2: GitHub address

If your network can access GitHub downloads, use the project source directly:

```bash
cd /tmp && curl -fsSL https://raw.githubusercontent.com/wtone/bypass-mdm/main/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh
```

Both addresses use automatic execution with no interactive input. The script defaults to Chinese, matches offline volumes in the same group, creates temporary administrator `apple` with fixed password `1234`, and applies the configuration after validation. **No username, password, Return, or secondary confirmation is requested; the default command writes changes directly.**

Append `--check` for a read-only preflight without account or configuration changes. `--apply` remains a compatibility alias for the default automatic mode and cannot be combined with `--check`.

| Setting | Automatic value | Optional command argument |
|---|---|---|
| Language | Chinese | `--lang en` for English |
| System volume | First eligible mounted offline System volume | `--system 'path'` |
| Data volume | First eligible Data volume in the same APFS group | `--data 'path'` |
| Temporary username | `apple` | `--username UnusedName` for another temporary name |
| Temporary password | Fixed `1234` | No password input is requested or accepted |
| Run mode | Apply automatically, without another confirmation | `--check` for check-only |

Volume-group, role, path, existing-account, and UID checks remain, including rechecks before writing. No eligible volume, an existing account name, or a failed check stops execution; existing accounts are never reused, overwritten, or reset. Specify different target disks with arguments before running.

If already downloaded, run it separately:

```bash
bash /tmp/bypass-mdm-v3.sh
```

Chinese is used directly with no startup language menu. Set English or explicitly choose Chinese with:

```bash
bash /tmp/bypass-mdm-v3.sh --lang en
bash /tmp/bypass-mdm-v3.sh --lang zh
```

Append `--lang en` to the end of the one-line download command to start directly in English. The script's menus, prompts, help, and error explanations follow the selected language; output from macOS commands follows the system settings.

Files in `/tmp` may disappear after a restart. Download again if needed.

## 5. Automatic execution and first sign-in

1. Run the one-line command in Recovery Terminal. Volume selection and validation are automatic, with no input or secondary confirmation. Mount or unlock the volumes and retry if none is available.
2. Wait for “MDM bypass setup completed!” and “Next steps:”. Investigate errors before treating the run as successful.
3. Close Terminal, restart, and sign in with temporary username `apple` and password `1234`. The completion summary also shows the backup location.
4. Follow section 6.1 to create and verify your own administrator, then remove the temporary account before proceeding to SIP changes.

The temporary account is for initial access, with fixed password `1234`. Choose your personal administrator name and password in Users & Groups after signing in. If `--username` selected another temporary name, substitute it for `apple` below.

## 6. Follow-up after signing in

Sign in with the temporary account, create and verify your own administrator, then remove the temporary account. For any manual repair, disable SIP afterward, repair markers and hosts, then re-enable SIP. The script already handles the four configuration markers on the offline Data volume and adds three enrollment hosts. A successful run does not require repeating those operations. Use the commands below for manual inspection or repair when needed.

### 6.1 Before changing SIP: replace the temporary administrator

**Create and verify your own administrator before removing temporary account `apple`. Do not delete your only usable account first.**

1. Sign in with `apple / 1234` and back up any files stored in that account.
2. Open System Settings → Users & Groups → Add User, authenticate as requested, choose Administrator, and create a new personal account and password. Do not merely rename `apple`.
3. Log out from the Apple menu and sign in with the new account. Verify its password and Administrator role, then check the token and volume-owner authorization described below before removing the temporary account.
4. While signed in as the new administrator, select temporary account `apple` in Users & Groups and choose Delete User. Keep or delete its home folder as appropriate after backing up needed files. Do not delete the account while signed in to it or force-remove your only administrator with `rm` or `dscl`.
5. Use the new administrator for Recovery authentication, then proceed to SIP changes in section 6.2.

If `csrutil disable` reports `no admin user`, deleting and recreating accounts is not a guaranteed fix. Administrator membership, Secure Token, and Apple silicon volume ownership are distinct; startup security changes involve administrator and owner authorization. Run these read-only checks in the new account's system Terminal:

```bash
sysadminctl -secureTokenStatus "$(id -un)"
dscl . -read "/Users/$(id -un)" GeneratedUID
sudo diskutil apfs listUsers /
```

Check the current account's token state and the ownership associated with its GUID. Resolve missing authorization through Apple's documented procedures before further SIP changes; retain usable accounts instead of repeatedly deleting and recreating them. See Apple's guides for [adding users](https://support.apple.com/guide/mac-help/mh15191/mac), [deleting users](https://support.apple.com/guide/mac-help/mchlp1557/mac), and [tokens and volume ownership](https://support.apple.com/guide/deployment/dep24dbdcf9e/web).

### 6.2 Before manual repair: disable SIP

If you intend to perform the manual repair below in the booted system, disable SIP first using these steps. Skip the disabling step if it already reports `disabled`. A successful script run does not require repeating repairs or disabling SIP just to repeat them.

1. Shut down, hold the power button for startup options, and choose Options → Continue.
2. In Recovery, open Utilities → Terminal and run:

```bash
csrutil disable
```

3. Complete the requested confirmation or authentication, then restart from the Apple menu and sign in to macOS.
4. In the normal system Terminal, run the following and confirm that it reports `disabled` before continuing:

```bash
csrutil status
```

Run `csrutil disable` in Recovery; `csrutil status` can check the state in the normal system. The script does not switch SIP for you. Re-enable it in section 6.5 after completing the work. See [Apple's SIP configuration guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html).

### 6.3 Inspect or repair configuration markers

Disable SIP and sign in as described in section 6.2, perform the needed manual repair, then restore SIP in section 6.5. Stop and check permissions if a command reports `Operation not permitted`.

For manual repair, back up the existing configuration and paste the following into the normal system Terminal. `sudo` asks for your current administrator password; typed characters remain hidden:

```bash
sudo cp -Rp /var/db/ConfigurationProfiles/Settings "/var/db/ConfigurationProfiles/Settings.before-manual-$(date +%Y%m%d-%H%M%S)" &&
sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord &&
sudo rm -f /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound &&
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled &&
sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
```

The four marker operations remove the first two files and ensure the other two exist. **`touch` neither empties existing files nor makes them read-only.** If you specifically need empty markers with ordinary read-only permissions, run the following after backing up; it overwrites the existing contents of those two markers:

```bash
sudo sh -c ': > /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled &&
: > /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound &&
chmod 444 /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound'
```

Mode `444` is an ordinary file permission, not protection against deletion or recreation. It does not guarantee that enrollment prompts cannot return after OTA updates. Keep configuration backups private.

### 6.4 Optional: extend the hosts blocklist

The default script already adds `iprofiles.apple.com`, `mdmenrollment.apple.com`, and `deviceenrollment.apple.com`. The extended list includes Apple services with other purposes. See [Apple's network requirements](https://support.apple.com/en-us/101555):

| Host | Purpose and effect |
|---|---|
| `iprofiles.apple.com`, `mdmenrollment.apple.com`, `deviceenrollment.apple.com` | Enrollment services, already included by default |
| `gdmf.apple.com` | Update catalogs and managed-update queries; blocking may affect update checks |
| `albert.apple.com` | Device activation; blocking may affect activation |
| `acmdm.apple.com` | Additional host; its specific purpose was not confirmed in the official list reviewed |

If you choose to use the following six-host list, back up hosts and open the editor with administrator privileges:

```bash
sudo cp -p /etc/hosts "/etc/hosts.before-mdm-$(date +%Y%m%d-%H%M%S)" &&
sudo vi /etc/hosts
```

Use an English input method. Press `Esc`, then `G` to reach the last line, then lowercase `o` to open a new line at the end in insert mode. Preserve existing content and add only entries that are not already present:

```text
0.0.0.0 iprofiles.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 acmdm.apple.com
0.0.0.0 albert.apple.com
```

Press `Esc`, type `:wq`, and press Return to save and exit. Use `:q!` to exit without saving. To refresh DNS caches if needed:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

This list differs from `--domains xiaohu-six`, which includes `deviceservices-external.apple.com` and excludes `gdmf.apple.com`. These are manual instructions; the script's default host selection stays the same. If added blocks cause update-check or activation issues, remove the relevant new entries or restore your backup before retrying. Keep backups and review the actual state after OTA updates; these settings do not guarantee that prompts will never return.

### 6.5 Re-enable SIP

If you previously disabled SIP, restore it after completing the necessary work. If `csrutil status` already reports `enabled`, leave it enabled.

1. Shut down, hold the power button for startup options, and choose Options → Continue.
2. In Recovery, open Utilities → Terminal and run:

```bash
csrutil enable
```

3. Complete the requested authentication and restart from the Apple menu.
4. After signing in, run `csrutil status` again and confirm that it reports `enabled`.

If an iPhone/iPad app from the App Store reports an incompatible startup security policy, restore SIP and follow the app or system guidance for startup security settings. An app failing to open is not, by itself, proof of a SIP issue. See [Apple's SIP configuration guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html) for the commands and restart requirement.

## 7. Optional arguments

| Argument | Usage |
|---|---|
| `--lang zh` / `--lang en` | Set Chinese or English; Chinese is the default and there is no language menu |
| `--system 'path'` | Optional; omit to automatically select the first eligible System volume |
| `--data 'path'` | Optional; omit to automatically select the first eligible matching Data volume |
| `--username name` | Optional temporary name; defaults to `apple`, always with password `1234`; conflicts stop execution |
| `--check` | Explicitly read-only; no account or configuration changes; cannot be combined with `--apply` |
| `--apply` | Compatibility alias for the default noninteractive apply mode |
| `--domains conservative` | Default three-host selection; normally leave the default |
| `--domains xiaohu-six` | Six-host selection including activation-related services; may affect normal activation. Switching back does not remove earlier blocks |
| `--help` | Display help, e.g. `bash /tmp/bypass-mdm-v3.sh --help` |

To select six hosts, append `--domains xiaohu-six` to the execution command.

You can still specify all targets with `--system`, `--data`, and `--username`. Execution is automatic whether or not all target arguments are provided; only explicit `--check` is read-only. Download the script as a file and run it.

## 8. Troubleshooting

| Problem | Action |
|---|---|
| Download fails | Check Recovery networking and access to the chosen host, `cdn.h5ds.com` or `raw.githubusercontent.com`; try the other download address. Later steps do not run if download fails |
| No available candidate, unmounted volume, or incorrect path | Mount/unlock in Disk Utility, then check actual paths with `ls /Volumes` |
| Group, role, or device mismatch | Recheck the System/Data pair; do not remove validation to force execution |
| Currently booted target rejected | Return to Recovery and operate on the offline installation |
| Username, UID, or home conflict | Use an unused name; after an interrupted run, inspect any partially created account first |
| Repeated “Stopped at line …” notices or account-inventory validation failure | Download the current script instead of reusing an old copy. If the China address still serves old content, synchronize the CDN file and refresh its cache. Record any remaining error; do not bypass account validation |
| Insufficient permission or unwritable target | Check `id -u`: apply requires `0`; also review unlock state and volume status |
| Account `apple` already exists | The script stops rather than resetting an existing account. Do not rerun completed setup unnecessarily; use `--username` for another unused temporary name only when needed |
| Retrying after interruption or failure | Record the error and backup path, then inspect the state before retrying with another name |

The script prints its configuration-backup location under the target Data volume's `private/var/db/mdm-reviewed-backup.XXXXXX/`. This is not a full backup and there is no automatic rollback; a failure can leave partial changes.

This script has not been verified in real Mac Recovery. Completion does not establish organization-side release or guarantee FileVault unlock access for the new account. Investigate any remaining login or activation issue separately.
