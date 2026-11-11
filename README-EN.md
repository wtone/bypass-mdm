# Bypass MDM v3 Usage

[简体中文](README.md) | **English**

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

The script lists mounted offline volumes. Select a System volume by number, then a Data volume in the same APFS volume group. Even a single candidate requires an explicit selection; verify the intended target rather than relying on its name.

## 4. Download and run in one line

Paste this complete line into Terminal in Recovery. No volume-path or username arguments need to be edited:

```bash
cd /tmp && curl -fsSL https://raw.githubusercontent.com/wtone/bypass-mdm/main/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh
```

At startup, choose a language: Return or `1` selects Chinese (the default), `2` selects English, and `q` cancels. Then choose the System and Data volumes and enter a new username. The action menu offers:

- `1` or Return: check only; no account or configuration changes.
- `2`: enter the apply flow, including exact device-ID confirmation and a strong password entered twice.
- `q`: cancel; volume selection also accepts `q`.

Append `--check` to force check-only mode. Append `--apply` to skip the action menu and enter the apply flow; volume selection, username entry, disk confirmation, and password prompts still remain.

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

1. Choose a language (Chinese by default), then select a System volume by number and a matching Data volume. If no candidate is available, mount or unlock the volumes in Disk Utility and rerun.
2. Enter an unused username. Correct invalid or conflicting names when prompted.
3. Review the displayed paths, device identifiers, and username. Choose `2` to apply or `1` to check only.
4. Enter the exact requested confirmation, such as `APPLY disk3s1 disk3s5`. Use the identifiers displayed during this run. Both languages require uppercase `APPLY` and the exact device identifiers.
5. Enter the password twice. Input is hidden and there is no default password.
6. Wait for completion. Investigate any error instead of treating it as success.
7. Quit Terminal, restart using the Apple menu, and try signing in with the new credentials.

Username: 1–31 characters, starting with an ASCII letter, using only letters, digits, `_`, or `-`. It must not conflict with an existing account or home directory.

Password: 16–128 characters, including uppercase and lowercase letters, a digit, and a symbol. Avoid including the username. Save it securely; it is not displayed at completion.

## 6. Optional arguments

| Argument | Usage |
|---|---|
| `--lang zh` / `--lang en` | Choose Chinese or English directly and skip startup language selection; Chinese is the default |
| `--system 'path'` | Optional; omit to choose a System volume interactively |
| `--data 'path'` | Optional; omit to choose a matching Data volume |
| `--username name` | Optional; omit to enter a new username interactively |
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
| Download fails | Check Recovery networking and access to `raw.githubusercontent.com`; later steps do not run if download fails |
| No available candidate, unmounted volume, or incorrect path | Mount/unlock in Disk Utility, then check actual paths with `ls /Volumes` |
| Group, role, or device mismatch | Recheck the System/Data pair; do not remove validation to force execution |
| Currently booted target rejected | Return to Recovery and operate on the offline installation |
| Username, UID, or home conflict | Use an unused name; after an interrupted run, inspect any partially created account first |
| Insufficient permission or unwritable target | Check `id -u`: apply requires `0`; also review unlock state and volume status |
| Password typing looks blank | Expected: finish typing, press Return, and confirm it |
| Retrying after interruption or failure | Record the error and backup path, then inspect the state before retrying with another name |

The script prints its configuration-backup location under the target Data volume's `private/var/db/mdm-reviewed-backup.XXXXXX/`. This is not a full backup and there is no automatic rollback; a failure can leave partial changes.

This script has not been verified in real Mac Recovery. Completion does not establish organization-side release or guarantee FileVault unlock access for the new account. Investigate any remaining login or activation issue separately.
