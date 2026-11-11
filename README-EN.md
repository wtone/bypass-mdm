# Bypass MDM v3 Usage

[简体中文](README.md) | **English**

Web page: [https://cdn.h5ds.com/bypass-mdm](https://cdn.h5ds.com/bypass-mdm). Switch between the China CDN and GitHub download sources, copy commands with one click, and read usage instructions in your browser. The page source is [index.html](index.html) in the project root.

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

The script automatically uses the first eligible mounted offline System volume and the first eligible Data volume in the same APFS group. There are no volume menus or Return prompts. The selected paths and device IDs are displayed; no eligible candidate means the script stops. Use `--system 'path' --data 'path'` for different targets, and review them before the final confirmation.

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

Both download methods use the same flow: Chinese by default, automatic System/Data matching, then username, password, and password confirmation together. A target summary and one final action menu follow:

- `1` or Return: check only; no account or configuration changes.
- `2`: confirm the displayed volumes and account, then apply changes without another disk confirmation.
- `q`: cancel; Ctrl+C also cancels input prompts.

Append `--check` for check-only mode without a password prompt. Append `--apply` to skip the action menu: enter the account details together, then confirm the target disks once at the end.

| Prompt | Value used on Return | Custom input |
|---|---|---|
| Language | Chinese automatically; no input | Append `--lang en` for English |
| System volume | First eligible volume automatically; no input | Specify `--system 'path'` |
| Data volume | First eligible volume in the System group automatically; no input | Specify `--data 'path'` |
| Username | `apple` | Enter an unused new username |
| Final decision | Check only | Enter `2` to confirm targets and apply; `q` cancels |
| Final confirmation with `--apply` | Displayed `APPLY SystemDeviceID DataDeviceID` | Review and press Return, or type the exact confirmation; Ctrl+C cancels |
| Password | `1234` | Enter any custom password |
| Repeat password | Password chosen in the previous step | Enter the same password again |

Pressing Return throughout completes a read-only check. Standard mode collects account details first and discards the password if you choose check-only or cancel; `--check` skips password input entirely. Automatic selection uses the first eligible candidate, so review the targets before the final decision.

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

## 5. Complete the prompts

1. The script uses Chinese by default and automatically matches System and Data volumes. Mount or unlock them and retry if none is available.
2. Enter the username and password together. Return uses `apple` and `1234`, or enter custom values. Return again confirms the chosen password. Conflicting usernames must be changed; existing accounts are not reused.
3. Review the paths, device IDs, and username. Enter `2` to confirm and apply, Return to check only, or `q` to cancel. With `--apply`, accept the final `APPLY …` prompt instead.
4. Wait for “MDM bypass setup completed!” and “Next steps:”. Investigate any reported error first.
5. Follow the next steps to close Terminal, restart, and sign in with the new account and chosen password. The completion summary includes the backup location and never displays a custom password.

Username: 1–31 characters, starting with an ASCII letter, using only letters, digits, `_`, or `-`. It must not conflict with an existing account or home directory.

Password: defaults to `1234`. There are no strength checks for length, character classes, or inclusion of the username; any custom password is accepted by the script. Empty input selects the default rather than an empty password. Save custom passwords securely; their contents are not displayed. `1234` is weak: change it after signing in. If the macOS password-setting command rejects a password, the script reports an error and stops.

## 6. Optional arguments

| Argument | Usage |
|---|---|
| `--lang zh` / `--lang en` | Set Chinese or English; Chinese is the default and there is no language menu |
| `--system 'path'` | Optional; omit to automatically select the first eligible System volume |
| `--data 'path'` | Optional; omit to automatically select the first eligible matching Data volume |
| `--username name` | Optional; omit for a prompt with default `apple`; account-conflict checks still apply |
| `--check` | Check only without asking for a password; cannot be combined with `--apply` |
| `--apply` | Enter account details together, then confirm the target disks once and apply |
| `--domains conservative` | Default three-host selection; normally leave the default |
| `--domains xiaohu-six` | Six-host selection including activation-related services; may affect normal activation. Switching back does not remove earlier blocks |
| `--help` | Display help, e.g. `bash /tmp/bypass-mdm-v3.sh --help` |

To select six hosts, append `--domains xiaohu-six` to the execution command.

You can still specify all targets with `--system`, `--data`, and `--username`. Providing all three without `--apply` remains check-only. Interactive selection requires a terminal: download the file and run it directly instead of using `curl ... | bash`.

## 7. Troubleshooting

| Problem | Action |
|---|---|
| Download fails | Check Recovery networking and access to the chosen host, `cdn.h5ds.com` or `raw.githubusercontent.com`; try the other download address. Later steps do not run if download fails |
| No available candidate, unmounted volume, or incorrect path | Mount/unlock in Disk Utility, then check actual paths with `ls /Volumes` |
| Group, role, or device mismatch | Recheck the System/Data pair; do not remove validation to force execution |
| Currently booted target rejected | Return to Recovery and operate on the offline installation |
| Username, UID, or home conflict | Use an unused name; after an interrupted run, inspect any partially created account first |
| Repeated “Stopped at line …” notices or account-inventory validation failure | Download the current script instead of reusing an old copy. If the China address still serves old content, synchronize the CDN file and refresh its cache. Record any remaining error; do not bypass account validation |
| Insufficient permission or unwritable target | Check `id -u`: apply requires `0`; also review unlock state and volume status |
| Password typing looks blank | Expected: Return selects `1234`, then Return confirms it; alternatively enter and confirm a custom password |
| Retrying after interruption or failure | Record the error and backup path, then inspect the state before retrying with another name |

The script prints its configuration-backup location under the target Data volume's `private/var/db/mdm-reviewed-backup.XXXXXX/`. This is not a full backup and there is no automatic rollback; a failure can leave partial changes.

This script has not been verified in real Mac Recovery. Completion does not establish organization-side release or guarantee FileVault unlock access for the new account. Investigate any remaining login or activation issue separately.
