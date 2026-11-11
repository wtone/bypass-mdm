import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

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

    def test_language_menu_defaults_to_chinese(self):
        self.ok("require_terminal() { :; }; choose_language <<<''; [ \"$language\" = zh ]")

    def test_language_menu_retries_and_selects_english(self):
        result = self.ok("require_terminal() { :; }; choose_language <<<$'bogus\\n2'; [ \"$language\" = en ]; choose_action <<<''")
        self.assertIn('Check only (default)', result.stdout)

    def test_language_menu_cancel_and_eof_stop(self):
        self.stops("require_terminal() { :; }; choose_language <<<'q'")
        self.stops('require_terminal() { :; }; choose_language </dev/null')

    def test_localized_messages_keep_variable_text_literal(self):
        for language in ('zh', 'en'):
            with self.subTest(language=language):
                result = self.ok('language=' + language + "; info 'Volume is not mounted: %s' '/Volumes/100% \\n literal'")
                self.assertIn('/Volumes/100% \\n literal', result.stdout)

    def test_password_rejects_default_and_short(self):
        self.ok('username=NewAdmin; ! validate_password 1234; ! validate_password "Short1!"')

    def test_password_requires_all_character_classes(self):
        self.ok('username=NewAdmin; ! validate_password "alllowercase123456!"; ! validate_password "UPPERCASEONLY12345!"; ! validate_password "MixedCaseWithoutDigits!"; ! validate_password "MixedCaseWithoutSymbols123"')

    def test_password_accepts_long_complex_and_rejects_account_name(self):
        self.ok('username=NewAdmin; validate_password "Unique-Long-Secret-482!"; ! validate_password "NewAdmin-Long-Secret-482!"')

    def test_no_password_echo(self):
        result = self.ok('username=NewAdmin; get_password <<\'EOF\'\nUnique-Long-Secret-482!\nUnique-Long-Secret-482!\nEOF\nunset passw')
        self.assertNotIn('Unique-Long-Secret', result.stdout + result.stderr)

    def test_password_retries_weak_and_mismatched_input_in_both_languages(self):
        for language, weak_message, mismatch_message in (
            ('zh', '密码不符合要求', '两次密码不一致'),
            ('en', 'Password does not meet the policy', 'Passwords did not match'),
        ):
            with self.subTest(language=language):
                result = self.ok('language=' + language + '''
username=NewAdmin
get_password <<'EOF'
1234
NewAdmin-Long-Secret-482!
Unique-Long-Secret-482!
Different-Long-Secret-483!
Unique-Long-Secret-482!
Unique-Long-Secret-482!
EOF
[ "$passw" = 'Unique-Long-Secret-482!' ]; unset passw
''')
                self.assertIn(weak_message, result.stdout)
                self.assertIn(mismatch_message, result.stdout)
                self.assertNotIn('Long-Secret', result.stdout + result.stderr)

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
main --system /Volumes/System --data /Volumes/Data --username NewAdmin
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

    def menu_fixture(self):
        return '''
require_terminal() { :; }
list_volume_candidates() {
  candidate_count=2
  candidate_paths=('/Volumes/First System' '/Volumes/Second System')
  candidate_devices=(disk3s1 disk4s1)
  candidate_groups=(group-a group-b)
}
'''

    def test_volume_menu_rejects_empty_leading_zero_and_expression(self):
        self.ok(self.menu_fixture() + '''
choose_volume System '' <<'EOF'

01
1+0
2
EOF
[ "$selected_volume_path" = '/Volumes/Second System' ]
''')

    def test_single_candidate_still_requires_selection(self):
        self.stops(self.menu_fixture() + '''
list_volume_candidates() { candidate_count=1; candidate_paths=(/Volumes/Only); candidate_devices=(disk3s1); candidate_groups=(group-a); }
choose_volume System '' </dev/null
''')

    def test_volume_menu_cancel_stops(self):
        self.stops(self.menu_fixture() + "choose_volume System '' <<<'q'")

    def test_empty_volume_menu_stops(self):
        self.stops(self.menu_fixture() + "list_volume_candidates() { candidate_count=0; }; choose_volume System ''")

    def test_interactive_input_requires_terminal(self):
        self.stops('require_terminal </dev/null')

    def test_interactive_username_retries_invalid_and_existing_name(self):
        self.ok('''
require_terminal() { :; }
homes_dir="$FIXTURES/homes"; users_dir="$FIXTURES/users"
user_inventory=$'root 0\nAlice 501'
prompt_username <<'EOF'
bad name
ALICE
FreshName
EOF
[ "$username" = FreshName ]
''')

    def test_action_menu_defaults_to_check(self):
        self.ok("require_terminal() { :; }; choose_action <<<''; [ \"$selected_action\" = check ]")

    def test_action_menu_retries_invalid_choice(self):
        self.ok("require_terminal() { :; }; choose_action <<<$'bogus\\n2'; [ \"$selected_action\" = apply ]")

    def test_confirmation_requires_exact_device_ids(self):
        for language in ('zh', 'en'):
            with self.subTest(language=language):
                setup = 'language=' + language + '; require_terminal() { :; }; expected_system=disk3s1; expected_data=disk3s5; '
                for answer in ('APPLY disk4s1 disk4s5', 'apply disk3s1 disk3s5', '确认 disk3s1 disk3s5'):
                    self.stops(setup + "confirm_targets <<<'" + answer + "'")
                self.ok(setup + "confirm_targets <<<'APPLY disk3s1 disk3s5'")

    def test_check_and_apply_flags_conflict(self):
        self.stops('main --check --apply')

    def interactive_main_fixture(self):
        return '''
require_terminal() { :; }
uname() { printf Darwin; }
canonical_mount() { printf '%s' "$1"; }
volume_group_for_path() { printf 11111111-2222-3333-4444-555555555555; }
choose_volume() {
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
read_users() { inventory_count=$((inventory_count + 1)); user_inventory='root 0'; }
check_hosts() { :; }
apply_changes() { fail 'Unexpected apply'; }
'''

    def test_no_argument_flow_defaults_to_read_only(self):
        result = self.ok(self.interactive_main_fixture() + "main <<<$'\\nFreshAdmin\\n\\n'")
        self.assertIn('只读检查完成', result.stdout)
        self.assertIn('仅检查（默认）', result.stdout)

    def test_check_flag_skips_action_menu(self):
        result = self.ok(self.interactive_main_fixture() + '''
choose_action() { fail 'Action menu must not be used with --check'; }
main --lang en --check <<<'FreshAdmin'
''')
        self.assertIn('READ-ONLY PREFLIGHT COMPLETE', result.stdout)

    def test_cancel_action_makes_no_changes(self):
        result = self.ok(self.interactive_main_fixture() + "main --lang en <<<$'FreshAdmin\\nq'")
        self.assertIn('Cancelled. No changes made.', result.stdout)

    def test_interactive_apply_keeps_confirmation_password_and_rechecks(self):
        body = self.interactive_main_fixture() + '''
# Simulate root only for the mocked apply flow; no actual system writes are used.
function [ {
  if builtin [ "$#" -eq 4 ] && builtin [ "$1" = "$EUID" ] && builtin [ "$2" = -eq ] && builtin [ "$3" = 0 ]; then return 0; fi
  builtin [ "$@"
}
apply_changes() {
  [ "$validation_count" -eq 2 ]; [ "$inventory_count" -eq 2 ]
  [ "$passw" = 'Unique-Long-Secret-482!' ]
  printf 'MOCK APPLY AFTER RECHECKS\\n'
}
'''
        inputs = '''
FreshAdmin
2
APPLY disk3s1 disk3s5
Unique-Long-Secret-482!
Unique-Long-Secret-482!
'''.lstrip('\n')
        for args, prefix in (('--lang zh', ''), ('--lang en', ''), ('', '\n'), ('', '2\n')):
            with self.subTest(args=args, prefix=prefix):
                result = self.ok(body + 'main ' + args + " <<'EOF'\n" + prefix + inputs + 'EOF\n')
                self.assertIn('MOCK APPLY AFTER RECHECKS', result.stdout)
                self.assertNotIn('Unique-Long-Secret', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
