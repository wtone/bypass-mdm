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

The script lists mounted offline volumes. The first eligible System candidate is the default, followed by the first eligible Data candidate in the same APFS volume group. Each step displays the default path and device ID. Press Return to accept, or enter another number or a full mount path from the list. No eligible candidate means the script stops. Verify the target rather than relying on its name.

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

Both download methods use the same interactive flow. At startup, choose a language: Return or `1` selects Chinese (the default), `2` selects English, and `q` cancels. Then choose the System and Data volumes and enter a new username. The action menu offers:

- `1` or Return: check only; no account or configuration changes.
- `2`: enter the apply flow, including device-ID confirmation and password setup; these prompts also accept defaults with Return.
- `q`: cancel; volume selection also accepts `q`.

Append `--check` to force check-only mode. Append `--apply` to skip the action menu and enter the apply flow; volume selection, username entry, disk confirmation, and password prompts still remain.

| Prompt | Value used on Return | Custom input |
|---|---|---|
| Language | Chinese | Enter `2` for English |
| System volume | First eligible listed volume | Enter another number or a full mount path from the list |
| Data volume | First eligible volume in the System group | Enter another number or a full mount path from the list |
| Username | `apple` | Enter an unused new username |
| Action | Check only | Enter `2` to apply |
| Disk confirmation | Displayed `APPLY SystemDeviceID DataDeviceID` | Review and press Return, or type the exact confirmation; Ctrl+C cancels |
| Password | `1234` | Enter any custom password |
| Repeat password | Password chosen in the previous step | Enter the same password again |

Pressing Return throughout completes a read-only check. Disk confirmation and password setup appear only after `--apply` or action `2`. A default volume is simply the first eligible candidate; review it before accepting.

If already downloaded, run it separately:

```bash
bash /tmp/bypass-mdm-v3.sh
```

To choose a language directly and skip the language menu:

```bash
bash /tmp/bypass-mdm-v3.sh --lang en
bash /tmp/bypass-mdm-v3.sh --lang zh
```

Append `--lang en` to the end of the one-line download command to start directly in English. The script's menus, prompts, help, and error explanations follow the selected language; output from macOS commands follows the system settings.

Files in `/tmp` may disappear after a restart. Download again if needed.

## 5. Complete the prompts

1. Choose a language (Chinese by default), then review the System and matching Data volumes. Return accepts each displayed default; another number or a listed path selects a different candidate. If none is available, mount or unlock the volumes in Disk Utility and rerun.
2. Press Return for username `apple`, or enter an unused name. Correct invalid or conflicting names when prompted; existing accounts are never reused or reset.
3. Review the displayed paths, device identifiers, and username. Choose `2` to apply or `1` to check only.
4. Review the two device IDs in the disk confirmation, then press Return to accept. You may instead type the exact text, such as `APPLY disk3s1 disk3s5`, using the identifiers displayed in this run. A mismatch stops execution; Ctrl+C cancels.
5. Press Return for password `1234`, or enter any custom password. At the repeat prompt, Return confirms the password chosen in the previous step, or you can type the same password again. A mismatch requires retrying. Input remains hidden.
6. Wait for completion. Investigate any error instead of treating it as success.
7. Quit Terminal, restart using the Apple menu, and try signing in with the new credentials.

Username: 1–31 characters, starting with an ASCII letter, using only letters, digits, `_`, or `-`. It must not conflict with an existing account or home directory.

Password: defaults to `1234`. There are no strength checks for length, character classes, or inclusion of the username; any custom password is accepted by the script. Empty input selects the default rather than an empty password. Save custom passwords securely; their contents are not displayed. `1234` is weak: change it after signing in. If the macOS password-setting command rejects a password, the script reports an error and stops.

## 6. Optional arguments

| Argument | Usage |
|---|---|
| `--lang zh` / `--lang en` | Choose Chinese or English directly and skip startup language selection; Chinese is the default |
| `--system 'path'` | Optional; omit to choose a System volume interactively |
| `--data 'path'` | Optional; omit to choose a matching Data volume |
| `--username name` | Optional; omit for a prompt with default `apple`; account-conflict checks still apply |
| `--check` | Force check-only mode; cannot be combined with `--apply` |
| `--apply` | Enter the apply flow; disk confirmation and password input remain required |
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
