import importlib.util
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    environment = {'HOME': str(root), 'XDG_CONFIG_HOME': str(root/'config'), 'XDG_STATE_HOME': str(root/'state'), 'XDG_DATA_HOME': str(root/'data')}
    with patch.dict(os.environ, environment):
        spec = importlib.util.spec_from_file_location('patch_control', Path(__file__).resolve().parents[1] / 'control.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original = root/'config/noctalia'
        original.mkdir(parents=True)
        (original/'config.toml').write_text('[theme]\nmode = "dark"\n')
        official_state = root/'state/noctalia'
        official_state.mkdir(parents=True)
        (official_state/'settings.toml').write_text('config_version = 15\n')
        module.initialize()
        copied = module.CONFIG_ROOT/'noctalia/config.toml'
        assert copied.read_text() == (original/'config.toml').read_text()
        copied.write_text('[theme]\nmode = "light"\n')
        module.initialize()
        assert 'light' in copied.read_text()
        assert 'dark' in (original/'config.toml').read_text()
        niri = root/'config/niri/config.kdl'
        niri.parent.mkdir()
        before = 'input { keyboard { numlock; }; }\n\n    spawn-at-startup "noctalia"\n'
        niri.write_text(before)
        with patch.object(module, 'run'):
            module.change_autostart(True)
            assert module.AUTOSTART in niri.read_text()
            module.change_autostart(True)
            module.change_autostart(False)
        assert niri.read_text() == before
        print('独立配置复制、再次初始化保留修改、自启动切换/回退测试通过')
