import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
STATE = Path('.local/state/noctalia-local-patches/noctalia')
LAUNCHER = Path('.config/noctalia-local-patches/noctalia/zz-launcher.toml')


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo = base / 'repo'
        self.user = base / 'user'
        self.bin = base / 'bin'
        for path in (self.repo, self.user, self.bin):
            path.mkdir()
        for name in ('sync.sh', 'update.sh', '.gitignore', 'localpkglist.txt'):
            shutil.copy2(SOURCE / name, self.repo / name)
        self.log = base / 'calls.log'
        self.env = dict(os.environ, HOME=str(self.user), PATH=f'{self.bin}:/usr/bin:/bin',
                        CALL_LOG=str(self.log), GIT_CONFIG_GLOBAL='/dev/null')
        self.command(['git', 'init', '-q'])
        self.fake('pacman', '''case "$1" in
  -Qqen) printf 'meson\\nnoctalia\\n' ;;
  -Qqem) printf 'example-bin\\nnoctalia-local-patches\\n' ;;
  *) exit 17 ;;
esac
''')
        for name in ('sudo', 'paru', 'makepkg', 'fcitx5-remote', 'noctalia-patched'):
            self.fake(name, f'printf \'%s\\n\' "{name} $PWD $*" >> "$CALL_LOG"\n')

    def command(self, args, check=True):
        return subprocess.run(args, cwd=self.repo, env=self.env, text=True,
                              capture_output=True, check=check)

    def fake(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    @staticmethod
    def put(root, relative, text):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_pull_captures_selected_preferences_and_new_files(self):
        self.put(self.repo, '.config/niri/config.kdl', 'old')
        self.put(self.repo, STATE / 'settings.toml', 'old')
        self.command(['git', 'add', '.config/niri/config.kdl', str(STATE / 'settings.toml')])
        # A selected new config does not need staging before the first pull.
        self.put(self.repo, LAUNCHER, 'old')
        self.put(self.user, '.config/niri/config.kdl', 'new binding')
        self.put(self.user, LAUNCHER, 'categories = false\n')
        self.put(self.user, STATE / 'settings.toml', 'config_version = 15\n')
        self.put(self.user, STATE / 'notification_history.json', 'private history')
        self.command(['bash', 'sync.sh', 'pull'])
        self.assertEqual((self.repo / LAUNCHER).read_text(), 'categories = false\n')
        self.assertEqual((self.repo / STATE / 'settings.toml').read_text(), 'config_version = 15\n')
        self.assertEqual((self.repo / 'pkglist.txt').read_text(), 'meson\nnoctalia\n')
        self.assertEqual((self.repo / 'aurlist.txt').read_text(), 'example-bin\n')
        self.assertFalse((self.repo / STATE / 'notification_history.json').exists())

    def test_push_restores_preferences_without_overwriting_history(self):
        self.put(self.repo, LAUNCHER, 'categories = false\n')
        self.put(self.repo, STATE / 'settings.toml', 'config_version = 15\n')
        history = self.put(self.user, STATE / 'notification_history.json', 'keep this history')
        self.command(['bash', 'sync.sh', 'push'])
        self.assertEqual((self.user / LAUNCHER).read_text(), 'categories = false\n')
        self.assertEqual((self.user / STATE / 'settings.toml').read_text(), 'config_version = 15\n')
        self.assertEqual(history.read_text(), 'keep this history')
        self.assertIn('msg config-reload', self.log.read_text())

    def test_local_mode_builds_the_package_from_this_repository(self):
        package = self.put(self.repo, 'packages/noctalia-local-patches/PKGBUILD', 'pkgname=noctalia-local-patches\n')
        self.command(['bash', 'update.sh', 'local'])
        self.assertIn(f'makepkg {package.parent} --syncdeps --install --needed', self.log.read_text())

    def test_aur_mode_does_not_send_local_packages_to_paru(self):
        self.put(self.repo, 'aurlist.txt', 'example-bin\nnoctalia-local-patches\n')
        self.command(['bash', 'update.sh', 'aur'])
        calls = self.log.read_text()
        self.assertIn('example-bin', calls)
        self.assertNotIn('noctalia-local-patches', calls)

    def test_failed_local_build_does_not_report_success(self):
        self.put(self.repo, 'packages/noctalia-local-patches/PKGBUILD', 'pkgname=noctalia-local-patches\n')
        self.fake('makepkg', 'exit 42\n')
        result = self.command(['bash', 'update.sh', 'local'], check=False)
        self.assertEqual(result.returncode, 42)
        self.assertNotIn('本地软件包安装完成', result.stdout)

    def test_history_and_build_artifacts_are_ignored(self):
        package = self.repo / 'packages/noctalia-local-patches'
        package.mkdir(parents=True)
        shutil.copy2(SOURCE / 'packages/noctalia-local-patches/.gitignore', package / '.gitignore')
        paths = [STATE / 'notification_history.json', STATE / 'storage.key',
                 Path('packages/noctalia-local-patches/src/build/cache'),
                 Path('packages/noctalia-local-patches/noctalia-build.pkg.tar.zst')]
        for path in paths:
            self.put(self.repo, path, 'ignored')
            self.assertEqual(self.command(['git', 'check-ignore', str(path)], check=False).returncode, 0)
        self.put(self.repo, STATE / 'settings.toml', 'config_version = 15\n')
        self.assertEqual(self.command(['git', 'check-ignore', str(STATE / 'settings.toml')], check=False).returncode, 1)


if __name__ == '__main__':
    unittest.main()
