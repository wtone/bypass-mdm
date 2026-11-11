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

Common mount points are `/Volumes/Macintosh HD` and `/Volumes/Macintosh HD - Data`, but names can differ. **Replace both paths in the following commands with the actual mount points if they differ. Keep the quotes.**

## 4. Download and run in one line

After verifying the paths, paste this complete line into Terminal in Recovery. `NewAdmin` is the new username; replace it with another unused name if desired.

```bash
cd /tmp && curl -fsSL https://raw.githubusercontent.com/wtone/bypass-mdm/main/bypass-mdm-v3.sh -o bypass-mdm-v3.sh && chmod +x ./bypass-mdm-v3.sh && ./bypass-mdm-v3.sh --system '/Volumes/Macintosh HD' --data '/Volumes/Macintosh HD - Data' --username NewAdmin --apply
```

This downloads the script and starts the apply flow. **You still need to confirm the target volumes and enter a new password at the prompts.**

To check first without changing accounts or configuration, remove the final `--apply`. Review the output, then run the command with `--apply` when the targets are correct.

If already downloaded, run it separately:

```bash
bash /tmp/bypass-mdm-v3.sh --system '/Volumes/Macintosh HD' --data '/Volumes/Macintosh HD - Data' --username NewAdmin --apply
```

Files in `/tmp` may disappear after a restart. Download again if needed.

## 5. Complete the prompts

1. Check the displayed System/Data volumes, device identifiers, and new username.
2. Enter the exact requested confirmation, such as `APPLY disk3s1 disk3s5`. Use the identifiers displayed during this run.
3. Enter the password twice. Input is hidden and there is no default password.
4. Wait for completion. Investigate any error instead of treating it as success.
5. Quit Terminal, restart using the Apple menu, and try signing in with the new credentials.

Username: 1–31 characters, starting with an ASCII letter, using only letters, digits, `_`, or `-`. It must not conflict with an existing account or home directory.

Password: 16–128 characters, including uppercase and lowercase letters, a digit, and a symbol. Avoid including the username. Save it securely; it is not displayed at completion.

## 6. Optional arguments

| Argument | Usage |
|---|---|
| `--system 'path'` | Required: complete target System-volume mount point |
| `--data 'path'` | Required: complete mount point of the matching Data volume |
| `--username name` | Required: new account name |
| `--apply` | Apply changes; omit for checks only |
| `--domains conservative` | Default three-host selection; normally leave the default |
| `--domains xiaohu-six` | Six-host selection including activation-related services; may affect normal activation. Switching back does not remove earlier blocks |
| `--help` | Display help, e.g. `bash /tmp/bypass-mdm-v3.sh --help` |

To select six hosts, append `--domains xiaohu-six` to the execution command.

## 7. Troubleshooting

| Problem | Action |
|---|---|
| Download fails | Check Recovery networking and access to `raw.githubusercontent.com`; later steps do not run if download fails |
| Volume unmounted or path incorrect | Mount/unlock in Disk Utility, then check actual paths with `ls /Volumes` |
| Group, role, or device mismatch | Recheck the System/Data pair; do not remove validation to force execution |
| Currently booted target rejected | Return to Recovery and operate on the offline installation |
| Username, UID, or home conflict | Use an unused name; after an interrupted run, inspect any partially created account first |
| Insufficient permission or unwritable target | Check `id -u`: apply requires `0`; also review unlock state and volume status |
| Password typing looks blank | Expected: finish typing, press Return, and confirm it |
| Retrying after interruption or failure | Record the error and backup path, then inspect the state before retrying with another name |

The script prints its configuration-backup location under the target Data volume's `private/var/db/mdm-reviewed-backup.XXXXXX/`. This is not a full backup and there is no automatic rollback; a failure can leave partial changes.

This script has not been verified in real Mac Recovery. Completion does not establish organization-side release or guarantee FileVault unlock access for the new account. Investigate any remaining login or activation issue separately.
