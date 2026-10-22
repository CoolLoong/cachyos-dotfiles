#!/usr/bin/env python3
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

PREFIX = Path(os.environ.get('NOCTALIA_PATCHES_PREFIX', '/usr/lib/noctalia-local-patches'))
HOME = Path.home()
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
STATE = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state'))
DATA = Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))
CONFIG_ROOT = CONFIG / 'noctalia-local-patches'
STATE_ROOT = STATE / 'noctalia-local-patches'
DATA_ROOT = DATA / 'noctalia-local-patches'
PATCHED = PREFIX / 'bin/noctalia'
OFFICIAL = Path('/usr/bin/noctalia')
AUTOSTART = 'spawn-sh-at-startup "if command -v noctalia-patched >/dev/null 2>&1; then exec noctalia-patched; else exec noctalia; fi"'


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def initialize():
    destination = CONFIG_ROOT / 'noctalia'
    if not destination.exists():
        source = CONFIG / 'noctalia'
        if source.exists():
            shutil.copytree(source, destination, symlinks=False)
        else:
            destination.mkdir(parents=True)
    target_state = STATE_ROOT / 'noctalia'
    if not target_state.exists():
        target_state.mkdir(parents=True)
        original = STATE / 'noctalia'
        for name in ['settings.toml', 'state.toml', '.setup-complete']:
            if (original / name).is_file():
                shutil.copy2(original / name, target_state / name)
        if (original / 'plugins').exists():
            shutil.copytree(original / 'plugins', target_state / 'plugins', symlinks=False)
    if not (DATA_ROOT / 'noctalia').exists():
        original = DATA / 'noctalia'
        if original.exists():
            shutil.copytree(original, DATA_ROOT / 'noctalia', symlinks=False)
        else:
            (DATA_ROOT / 'noctalia').mkdir(parents=True)


def patched_environment():
    environment = dict(os.environ)
    environment['NOCTALIA_CONFIG_HOME'] = str(CONFIG_ROOT)
    environment['NOCTALIA_STATE_HOME'] = str(STATE_ROOT)
    environment['NOCTALIA_DATA_HOME'] = str(DATA_ROOT)
    environment['NOCTALIA_ASSETS_DIR'] = str(PREFIX / 'share/noctalia/assets')
    return environment


def launch_arguments(arguments):
    initialize()
    os.execve(PATCHED, [str(PATCHED), *arguments], patched_environment())


def compositor_config():
    return (CONFIG / 'niri/config.kdl').resolve()


def change_autostart(enable):
    path = compositor_config()
    if not path.exists():
        raise RuntimeError('未找到 niri/config.kdl；配置未修改。')
    text = path.read_text()
    if enable and AUTOSTART in text:
        return
    if not enable and AUTOSTART not in text:
        return
    backups = STATE_ROOT / 'backups'
    backups.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, backups / ('config.kdl.' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')))
    record = STATE_ROOT / 'autostart.json'
    if enable:
        match = re.search(r'(?m)^([ \t]*)spawn-at-startup[ \t]+"noctalia"[ \t]*$', text)
        if match is None:
            raise RuntimeError('自启动内容与预期不符；未替换现有命令。')
        record.write_text(json.dumps({'original': match.group(0)}, ensure_ascii=False))
        updated = text[:match.start()] + match.group(1) + AUTOSTART + text[match.end():]
    else:
        original = json.loads(record.read_text()).get('original') if record.exists() else None
        updated = text.replace(AUTOSTART, original.strip() if original else 'spawn-at-startup "noctalia"', 1)
    temporary = path.with_name('.noctalia-patches-candidate.kdl')
    try:
        temporary.write_text(updated)
        run(['niri', 'validate', '--config', str(temporary)], stdout=subprocess.DEVNULL)
        shutil.copymode(path, temporary)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def shell_processes():
    programs = {str(OFFICIAL.resolve()), str(PATCHED.resolve())}
    result = []
    for entry in Path('/proc').glob('[0-9]*'):
        try:
            if entry.stat().st_uid == os.getuid() and str((entry / 'exe').resolve()) in programs:
                result.append(int(entry.name))
        except OSError:
            pass
    return result


def stop_shells():
    for unit in ['noctalia-shell.service', 'noctalia-shell-patched.service', 'noctalia-patches-preview.service']:
        subprocess.run(['systemctl', '--user', 'stop', unit], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for pid in shell_processes():
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 6
    while shell_processes() and time.monotonic() < deadline:
        time.sleep(0.1)
    if shell_processes():
        raise RuntimeError('现有 Noctalia 尚未退出，未启动第二个实例。')


def start_shell(patched):
    unit = 'noctalia-shell-patched.service' if patched else 'noctalia-shell.service'
    executable = PREFIX / 'bin/noctalia' if patched else OFFICIAL
    command = ['systemd-run', '--user', '--unit=' + unit, '--collect', '--property=PartOf=graphical-session.target']
    if patched:
        for name in ['NOCTALIA_CONFIG_HOME', 'NOCTALIA_STATE_HOME', 'NOCTALIA_DATA_HOME', 'NOCTALIA_ASSETS_DIR']:
            command.append('--setenv=' + name + '=' + patched_environment()[name])
    command.append(str(executable))
    run(command)
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        active = subprocess.run(['systemctl', '--user', 'is-active', '--quiet', unit]).returncode == 0
        if active:
            query = subprocess.run([str(executable), 'msg', 'status'], capture_output=True, text=True)
            if query.returncode == 0:
                try:
                    if 'barVisible' in json.loads(query.stdout):
                        return
                except json.JSONDecodeError:
                    pass
        time.sleep(0.25)
    raise RuntimeError('Noctalia 启动验证未通过。')


def switch(patched):
    if patched:
        initialize()
        run([str(PATCHED), 'config', 'validate'], env=patched_environment())
    change_autostart(patched)
    try:
        stop_shells()
        start_shell(patched)
    except Exception:
        if patched:
            change_autostart(False)
            stop_shells()
            start_shell(False)
        raise
    print('已切换到独立补丁版。' if patched else '已恢复官方 Noctalia。')


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == 'run':
        launch_arguments(sys.argv[2:])
        return
    parser = argparse.ArgumentParser(description='独立 Noctalia 补丁版管理；enable/disable 只重启桌面 shell。')
    parser.add_argument('command', choices=['init', 'enable', 'disable', 'status'])
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('请在桌面会话中使用普通用户执行。')
    if args.command == 'init':
        initialize()
        print('已初始化独立配置；官方配置未修改。')
    elif args.command == 'enable':
        switch(True)
    elif args.command == 'disable':
        switch(False)
    else:
        print(json.dumps({'prefix': str(PREFIX), 'config': str(CONFIG_ROOT / 'noctalia'), 'state': str(STATE_ROOT / 'noctalia'), 'running_pids': shell_processes(), 'autostart_patched': compositor_config().exists() and AUTOSTART in compositor_config().read_text()}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print('操作失败：' + str(error), file=sys.stderr)
        sys.exit(1)
