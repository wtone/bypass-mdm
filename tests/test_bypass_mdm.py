import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
import plistlib

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'bypass-mdm-v3.sh'
BASH = os.environ.get('MDM_TEST_BASH')
if not BASH and os.name == 'nt':
    git = shutil.which('git')
    candidate = Path(git).resolve().parents[1] / 'bin' / 'bash.exe' if git else None
    if candidate and candidate.is_file():
        BASH = str(candidate)
BASH = BASH or shutil.which('bash')
if not BASH:
    raise RuntimeError('Bash is required; set MDM_TEST_BASH to its path.')

def posix(path):
    text = str(path).replace('\\', '/')
    return '/' + text[0].lower() + text[2:] if len(text) > 1 and text[1] == ':' else text

class SafetyTests(unittest.TestCase):
    def run_body(self, body, language='en'):
        env = os.environ.copy()
        env['REVIEW_SCRIPT'] = posix(SCRIPT)
        env['FIXTURES'] = posix(self.fixture)
        setup = 'source "$REVIEW_SCRIPT"\n'
        if language is not None:
            setup += 'language=' + language + '\n'
        return subprocess.run([BASH, '--noprofile', '--norc', '-c', setup + body], env=env, encoding='utf-8', capture_output=True, timeout=30)

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fixture = Path(cls.tmp.name)
        (cls.fixture / 'System' / 'System' / 'Library' / 'CoreServices').mkdir(parents=True)
        (cls.fixture / 'System' / 'System' / 'Library' / 'CoreServices' / 'SystemVersion.plist').write_text('fixture')
        (cls.fixture / 'Data').mkdir()
        (cls.fixture / 'homes').mkdir()
        (cls.fixture / 'users').mkdir()
        (cls.fixture / 'apfs.plist').write_bytes(plistlib.dumps({'Containers': [{'ContainerReference': 'disk3', 'Volumes': [
            {'DeviceIdentifier': 'disk3s1', 'Roles': ['System']},
            {'DeviceIdentifier': 'disk3s5', 'Roles': ['Data']},
        ]}]}))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def ok(self, body):
        result = self.run_body(body)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def stops(self, body):
        result = self.run_body(body)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_bash_syntax(self):
        result = subprocess.run([BASH, '-n', posix(SCRIPT)], text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_default_language_and_help_are_chinese_without_terminal(self):
        result = self.run_body('[ "$language" = zh ]; main --help </dev/null', language=None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('用法（', result.stdout)
        self.assertNotIn('Usage (', result.stdout)

    def test_english_help_accepts_language_before_or_after_help(self):
        for args in ('--lang en --help', '--help --lang en'):
            with self.subTest(args=args):
                result = self.ok('main ' + args + ' </dev/null')
                self.assertIn('Usage (', result.stdout)
                self.assertNotIn('用法（', result.stdout)

    def test_invalid_or_missing_language_stops_before_volume_access(self):
        for args in ('--lang fr', '--lang', '--lang en --lang fr'):
            with self.subTest(args=args):
                result = self.stops("diskutil() { printf 'UNEXPECTED DISK ACCESS'; }; main " + args)
                self.assertNotIn('UNEXPECTED DISK ACCESS', result.stdout)

    def test_localized_messages_keep_variable_text_literal(self):
        for language in ('zh', 'en'):
            with self.subTest(language=language):
                result = self.ok('language=' + language + "; info 'Volume is not mounted: %s' '/Volumes/100% \\n literal'")
                self.assertIn('/Volumes/100% \\n literal', result.stdout)

    def test_uid_skips_occupied_numbers(self):
        result = self.ok("user_inventory=$'root 0\nAlice 501\nBob 502'; find_available_uid")
        self.assertEqual(result.stdout.strip(), '503')

    def test_uid_exhaustion_has_no_fallback(self):
        self.stops("user_inventory=$(awk 'BEGIN {print \"root 0\"; for(i=501;i<60000;i++) print \"u\" i, i}'); find_available_uid")

    def test_uid_recheck_stops_on_conflict(self):
        self.stops("available_uid=503; user_inventory=$'root 0\nSomeone 503'; assert_uid_free")

    def test_existing_user_case_variant_stops(self):
        self.stops("username=ALICE; user_inventory=$'root 0\nalice 501'; homes_dir=\"$FIXTURES/homes\"; users_dir=\"$FIXTURES/users\"; assert_new_account")

    def test_database_read_failure_stops(self):
        self.stops('dscl() { return 1; }; dscl_path=unused; read_users')

    def test_invalid_database_output_stops(self):
        self.stops('dscl() { printf "unexpected output\\n"; }; dscl_path=unused; read_users')

    def test_mac_system_accounts_with_negative_uid_are_valid(self):
        result = self.ok('''
dscl() { printf 'nobody -2\nroot 0\ndaemon 1\n_mbsetupuser 248\nExistingUser 501\n'; }
dscl_path=unused
read_users
find_available_uid
''')
        self.assertEqual(result.stdout.strip(), '502')

    def test_missing_root_and_malformed_uid_still_stop(self):
        self.stops("dscl() { printf 'nobody -2\\nAlice 501\\n'; }; dscl_path=unused; read_users")
        self.stops("dscl() { printf 'root 0\\nAlice not-a-uid\\n'; }; dscl_path=unused; read_users")

    @unittest.skipUnless(sys.platform == 'darwin', 'Requires native macOS plutil')
    def test_native_plutil_expected_missing_keys_are_silent_with_traps(self):
        result = self.ok('''
install_traps
xml=$(cat "$FIXTURES/apfs.plist")
[ "$(role_for_device "$xml" disk3s1)" = System ]
[ "$(role_for_device "$xml" disk3s5)" = Data ]
if role_for_device "$xml" disk9s1; then exit 9; fi
if value=$(plist_value "$xml" APFSVolumeGroupID); then exit 9; fi
''')
        self.assertEqual(result.stderr, '')

    @unittest.skipUnless(sys.platform == 'darwin', 'Requires native macOS dscl')
    def test_native_mac_account_inventory_is_accepted(self):
        self.ok('''
install_traps
# Read-only: use the runner's real system-account inventory, never mutate it.
dscl() { command dscl . -list /Users UniqueID; }
dscl_path=unused
read_users
''')

    def test_expected_failed_lookups_with_traps_remain_silent(self):
        result = self.ok('''
install_traps
plutil() { cat >/dev/null; return 1; }
for key in Missing.0 Missing.1 Missing.2; do
  if value=$(plist_value '<plist/>' "$key"); then exit 9; fi
done
''')
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, '')

    def test_real_failure_reports_once_and_preserves_exit_status(self):
        result = self.stops('install_traps; passw=DO_NOT_PRINT_PASSWORD; value=$(exit 7); printf SHOULD_NOT_CONTINUE')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stderr.count('Preflight stopped'), 1)
        self.assertIn('No target files or accounts were changed', result.stderr)
        self.assertNotIn('DO_NOT_PRINT_PASSWORD', result.stdout + result.stderr)
        self.assertNotIn('SHOULD_NOT_CONTINUE', result.stdout)

    def test_apply_failure_has_one_partial_change_notice(self):
        result = self.stops('install_traps; changes_started=1; false')
        self.assertEqual(result.stderr.count('Apply stopped'), 1)
        self.assertNotIn('No target files', result.stderr)

    def test_existing_home_stops(self):
        self.stops('username=StaleHome; user_inventory="root 0"; homes_dir="$FIXTURES/homes"; users_dir="$FIXTURES/users"; mkdir "$homes_dir/StaleHome"; assert_new_account')

    def test_domain_profiles_are_explicit(self):
        result = self.ok('domain_profile=conservative; select_domains; [ "${#domains[@]}" -eq 3 ]; domain_profile=xiaohu-six; select_domains; [ "${#domains[@]}" -eq 6 ]')
        self.assertEqual(result.stdout, '')

    def test_hosts_match_exact_tokens_and_preserve_unrelated_content(self):
        result = self.ok('''
etc_dir="$FIXTURES"; hosts_file="$FIXTURES/hosts"
printf '127.0.0.1 localhost\n# iprofiles.apple.com in a comment\n0.0.0.0 notiprofiles.apple.com\n0.0.0.0 deviceenrollment.apple.com # existing\n' > "$hosts_file"
domain_profile=conservative; select_domains; check_hosts; write_hosts
grep -Fx '127.0.0.1 localhost' "$hosts_file"
[ "$(awk '$1=="0.0.0.0" && $2=="deviceenrollment.apple.com" {n++} END {print n}' "$hosts_file")" -eq 1 ]
grep -Fx '0.0.0.0 iprofiles.apple.com' "$hosts_file"
''')
        self.assertIn('localhost', result.stdout)

    def test_conflicting_hosts_mapping_stops(self):
        self.stops('hosts_file="$FIXTURES/conflict-hosts"; printf "203.0.113.5 iprofiles.apple.com\\n" > "$hosts_file"; domain_profile=conservative; select_domains; check_hosts')

    def volume_fixture(self, mode):
        return '''
system_path="$FIXTURES/System"; data_path="$FIXTURES/Data"
mode=''' + mode + '''
diskutil() {
  if [ "$1" = apfs ]; then printf apfs; return; fi
  case "$3" in "$system_path") printf sys ;; "$data_path") printf dat ;; /) printf boot ;; *) return 1 ;; esac
}
plist_value() {
  local tag="$1" key="$2" group=11111111-2222-3333-4444-555555555555
  case "$tag|$key" in
    'sys|MountPoint') printf '%s' "$system_path" ;;
    'dat|MountPoint') printf '%s' "$data_path" ;;
    'sys|DeviceIdentifier') printf disk3s1 ;;
    'dat|DeviceIdentifier') if [ "$mode" = same-device ]; then printf disk3s1; else printf disk3s5; fi ;;
    'sys|APFSVolumeGroupID') printf '%s' "$group" ;;
    'dat|APFSVolumeGroupID') if [ "$mode" = mismatch ]; then printf 99999999-2222-3333-4444-555555555555; else printf '%s' "$group"; fi ;;
    'boot|APFSVolumeGroupID') if [ "$mode" = live ]; then printf '%s' "$group"; else return 1; fi ;;
    'apfs|Containers.0.ContainerReference') printf disk3 ;;
    'apfs|Containers.0.Volumes.0.DeviceIdentifier') printf disk3s1 ;;
    'apfs|Containers.0.Volumes.1.DeviceIdentifier') printf disk3s5 ;;
    'apfs|Containers.0.Volumes.0.Roles.0') if [ "$mode" = wrong-role ]; then printf Recovery; else printf System; fi ;;
    'apfs|Containers.0.Volumes.1.Roles.0') printf Data ;;
    *) return 1 ;;
  esac
}
validate_volumes
'''

    def test_matching_apfs_group_and_roles_pass(self):
        self.ok(self.volume_fixture('valid'))

    def test_mismatched_apfs_group_stops(self):
        self.stops(self.volume_fixture('mismatch'))

    def test_same_system_and_data_device_stops(self):
        self.stops(self.volume_fixture('same-device'))

    def test_wrong_apfs_role_stops(self):
        self.stops(self.volume_fixture('wrong-role'))

    def test_currently_booted_group_stops(self):
        self.stops(self.volume_fixture('live'))

    def test_volume_identity_change_stops(self):
        self.stops(self.volume_fixture('valid') + '\nexpected_group=99999999-2222-3333-4444-555555555555; validate_volumes')

    def test_main_read_only_preflight_never_calls_apply(self):
        self.ok('''
uname() { printf Darwin; }
canonical_mount() { printf '%s' "$1"; }
validate_volumes() { expected_system=disk3s1; expected_data=disk3s5; expected_group=fixture; }
validate_paths() { hosts_file=fixture; }
read_users() { user_inventory='root 0'; }
assert_new_account() { :; }
check_hosts() { :; }
apply_changes() { fail 'SHOULD NEVER APPLY'; }
main --check --system /Volumes/System --data /Volumes/Data --username NewAdmin
''')

    def candidate_fixture(self):
        group_a = '11111111-2222-3333-4444-555555555555'
        group_b = '22222222-2222-3333-4444-555555555555'
        group_live = '33333333-2222-3333-4444-555555555555'
        volumes = [
            ('disk3s1', 'System', '/Volumes/Work System', group_a),
            ('disk3s5', 'Data', '/Volumes/Work Data', group_a),
            ('disk4s5', 'Data', '/Volumes/Other Data', group_b),
            ('disk4s1', 'System', '/Volumes/Other System', group_b),
            ('disk5s1', 'System', '/Volumes/Live System', group_live),
            ('disk5s5', 'Data', '/Volumes/Live Data', group_live),
            ('disk6s1', 'System', '', group_b),
            ('disk3s1s1', 'System', '/Volumes/Snapshot', group_a),
            ('disk3s2', 'Preboot', '/Volumes/Preboot', group_a),
        ]
        rows = {'inventory|Containers.0.ContainerReference': 'disk3',
                'boot|APFSVolumeGroupID': group_live}
        for index, (device, role, mount, group) in enumerate(volumes):
            rows[f'inventory|Containers.0.Volumes.{index}.DeviceIdentifier'] = device
            rows[f'inventory|Containers.0.Volumes.{index}.Roles.0'] = role
            if mount:
                rows[f'{device}|MountPoint'] = mount
            rows[f'{device}|APFSVolumeGroupID'] = group
        import shlex
        cases = '\n'.join(f'{shlex.quote(key)}) printf %s {shlex.quote(value)} ;;' for key, value in rows.items())
        return '''
diskutil() {
  if [ "$1" = apfs ]; then printf inventory; return; fi
  if [ "$3" = / ]; then printf boot; else printf '%s' "$3"; fi
}
plist_value() {
  case "$1|$2" in
''' + cases + '''
    *) return 1 ;;
  esac
}
# Simulate mounted /Volumes entries without creating real system paths.
function [ {
  if builtin [ "$#" -eq 3 ] && builtin [ "$1" = -d ]; then
    case "$2" in /Volumes/*) return 0 ;; esac
  fi
  builtin [ "$@"
}
'''

    def test_candidate_system_list_excludes_live_unmounted_and_snapshots(self):
        self.ok(self.candidate_fixture() + '''
list_volume_candidates System ''
[ "$candidate_count" -eq 2 ]
[ "${candidate_paths[0]}" = '/Volumes/Work System' ]
[ "${candidate_paths[1]}" = '/Volumes/Other System' ]
''')

    def test_candidate_data_list_filters_to_selected_group(self):
        self.ok(self.candidate_fixture() + '''
list_volume_candidates Data 11111111-2222-3333-4444-555555555555
[ "$candidate_count" -eq 1 ]
[ "${candidate_paths[0]}" = '/Volumes/Work Data' ]
''')

    def test_no_matching_group_produces_no_candidates(self):
        self.ok(self.candidate_fixture() + '''
list_volume_candidates Data 99999999-2222-3333-4444-555555555555
[ "$candidate_count" -eq 0 ]
''')

    def volume_selection_fixture(self):
        return '''
require_terminal() { :; }
list_volume_candidates() {
  candidate_count=2
  candidate_paths=('/Volumes/First System' '/Volumes/Second System')
  candidate_devices=(disk3s1 disk4s1)
  candidate_groups=(group-a group-b)
}
'''

    def test_volume_default_is_automatic_in_both_languages_without_terminal(self):
        for language in ('zh', 'en'):
            with self.subTest(language=language):
                result = self.ok(self.volume_selection_fixture() + 'language=' + language + "; require_terminal() { fail 'Unexpected input'; }; select_default_volume System '' </dev/null; [ \"$selected_volume_path\" = '/Volumes/First System' ]")
                self.assertIn('/Volumes/First System [disk3s1]', result.stdout)

    def test_single_candidate_is_selected_without_input(self):
        self.ok(self.volume_selection_fixture() + '''
list_volume_candidates() { candidate_count=1; candidate_paths=(/Volumes/Only); candidate_devices=(disk3s1); candidate_groups=(group-a); }
select_default_volume System '' </dev/null
[ "$selected_volume_path" = /Volumes/Only ]
''')

    def test_no_candidate_stops_before_account_input(self):
        self.stops(self.volume_selection_fixture() + "list_volume_candidates() { candidate_count=0; }; select_default_volume System ''")

    def test_check_and_apply_flags_conflict(self):
        self.stops('main --check --apply')
        self.stops('main --apply --check')

    def auto_main_fixture(self, real_volume_detection=False):
        body = '''
uname() { printf Darwin; }
require_root() { :; }
read() { fail 'Unexpected interactive input'; }
canonical_mount() { printf '%s' "$1"; }
volume_group_for_path() { printf 11111111-2222-3333-4444-555555555555; }
select_default_volume() {
  case "$1" in
    System) selected_volume_path="$FIXTURES/System" ;;
    Data) [ "$2" = 11111111-2222-3333-4444-555555555555 ]; selected_volume_path="$FIXTURES/Data" ;;
  esac
}
validation_count=0; inventory_count=0
validate_volumes() {
  validation_count=$((validation_count + 1))
  expected_system=disk3s1; expected_data=disk3s5
  expected_group=11111111-2222-3333-4444-555555555555
}
validate_paths() {
  db_parent="$FIXTURES"; dscl_path="$FIXTURES"; users_dir="$FIXTURES/users"
  homes_dir="$FIXTURES/homes"; etc_dir="$FIXTURES"; config_path="$FIXTURES"
  hosts_file="$FIXTURES/main-hosts"; : > "$hosts_file"
}
read_users() { inventory_count=$((inventory_count + 1)); user_inventory=$'nobody -2\nroot 0'; }
check_hosts() { :; }
apply_changes() { fail 'Unexpected apply'; }
'''
        return body.replace('select_default_volume() {', 'unused_select_default_volume() {') if real_volume_detection else body

    def test_default_apply_with_no_input_in_both_languages(self):
        body = self.auto_main_fixture(real_volume_detection=True) + '''
list_volume_candidates() {
  candidate_count=1; candidate_groups=(11111111-2222-3333-4444-555555555555)
  case "$1" in
    System) candidate_paths=("$FIXTURES/System"); candidate_devices=(disk3s1) ;;
    Data) [ "$2" = 11111111-2222-3333-4444-555555555555 ]; candidate_paths=("$FIXTURES/Data"); candidate_devices=(disk3s5) ;;
  esac
}
apply_changes() {
  [ "$validation_count" -eq 2 ]; [ "$inventory_count" -eq 2 ]
  [ "$username" = apple ]; [ "$passw" = 1234 ]
  [ "$system_path" = "$FIXTURES/System" ]; [ "$data_path" = "$FIXTURES/Data" ]
  printf 'AUTOMATIC APPLY AFTER RECHECKS\\n'
}
'''
        for args in ('', '--lang en', '--apply', '--lang en --apply'):
            with self.subTest(args=args):
                result = self.ok(body + 'main ' + args + ' </dev/null')
                self.assertIn('AUTOMATIC APPLY AFTER RECHECKS', result.stdout)

    def test_check_is_read_only_without_root_or_input(self):
        result = self.ok(self.auto_main_fixture() + '''
require_root() { fail 'Check-only must not require root'; }
main --lang en --check </dev/null
[ "$validation_count" -eq 1 ]; [ "$inventory_count" -eq 1 ]
[ -z "${passw+x}" ]
''')
        self.assertIn('READ-ONLY PREFLIGHT COMPLETE', result.stdout)

    def test_full_target_arguments_apply_by_default(self):
        self.ok(self.auto_main_fixture() + '''
apply_changes() { [ "$username" = CustomTemp ]; [ "$passw" = 1234 ]; [ "$validation_count" -eq 2 ]; }
main --system "$FIXTURES/System" --data "$FIXTURES/Data" --username CustomTemp </dev/null
''')

    def test_automatic_apply_requires_root_before_target_access(self):
        result = self.stops(self.auto_main_fixture() + '''
require_root() { fail 'Apply requires root in Recovery. No changes made.'; }
select_default_volume() { fail 'UNEXPECTED TARGET ACCESS'; }
main --lang en </dev/null
''')
        self.assertIn('Apply requires root', result.stderr)
        self.assertNotIn('UNEXPECTED TARGET ACCESS', result.stderr)

    def test_default_account_conflict_stops_without_reuse(self):
        result = self.stops(self.auto_main_fixture() + '''
read_users() { user_inventory=$'root 0\nAPPLE 501'; }
main --lang en </dev/null
''')
        self.assertIn('Username already exists', result.stderr)
        self.assertNotIn('Unexpected apply', result.stderr)

    def test_automatic_apply_rechecks_uid_before_writes(self):
        result = self.stops(self.auto_main_fixture() + '''
read_users() {
  inventory_count=$((inventory_count + 1))
  if [ "$inventory_count" -eq 1 ]; then user_inventory='root 0'; else user_inventory=$'root 0\nOtherUser 501'; fi
}
main --lang en </dev/null
''')
        self.assertIn('Selected UID is now occupied', result.stderr)
        self.assertNotIn('Unexpected apply', result.stderr)

    def test_automatic_apply_rechecks_disk_identity_before_writes(self):
        result = self.stops(self.auto_main_fixture() + '''
validate_volumes() {
  validation_count=$((validation_count + 1))
  [ "$validation_count" -lt 2 ] || fail 'Selected volume identity changed after preflight.'
  expected_system=disk3s1; expected_data=disk3s5; expected_group=fixture
}
main --lang en </dev/null
''')
        self.assertIn('Selected volume identity changed', result.stderr)
        self.assertNotIn('Unexpected apply', result.stderr)

    def test_success_summary_is_localized_with_temporary_credentials(self):
        for language, title, steps in (
            ('zh', 'MDM 绕过配置已完成', '下一步：'),
            ('en', 'MDM bypass setup completed', 'Next steps:'),
        ):
            with self.subTest(language=language):
                result = self.ok('language=' + language + '''
username=FreshAdmin; backup_dir=/Volumes/Data/backup; passw=DO_NOT_PRINT_PASSWORD
print_success
''')
                self.assertIn(title, result.stdout)
                self.assertIn(steps, result.stdout)
                self.assertIn('FreshAdmin', result.stdout)
                self.assertIn('1234', result.stdout)
                self.assertIn('/Volumes/Data/backup', result.stdout)
                self.assertNotIn('DO_NOT_PRINT_PASSWORD', result.stdout)
                self.assertNotIn('This does not verify', result.stdout)
                self.assertNotIn('这不代表', result.stdout)
                self.assertNotIn('\x1b', result.stdout)

    def test_apply_command_failure_never_prints_success(self):
        result = self.stops('''
install_traps
username=FreshAdmin; dscl_path=unused; passw=DO_NOT_PRINT_PASSWORD
make_backup() { backup_dir="$FIXTURES"; }
dscl() { return 1; }
apply_changes
''')
        self.assertNotIn('setup completed', result.stdout)
        self.assertNotIn('Next steps:', result.stdout)
        self.assertNotIn('DO_NOT_PRINT_PASSWORD', result.stdout + result.stderr)
        self.assertIn('Apply stopped', result.stderr)

if __name__ == '__main__':
    unittest.main(verbosity=2)
