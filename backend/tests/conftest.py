import importlib
import os
import sys

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)


def _build_app(monkeypatch, tmp_path, extra_env=None):
    monkeypatch.setenv("APP_UPLOADS_DIR", str(tmp_path / "uploads"))
    monkeypatch.setenv("APP_OUTPUT_DIR", str(tmp_path / "outputs"))
    monkeypatch.setenv("APP_ENABLE_CONFIG_DEBUG", "true")

    if extra_env:
        for key, value in extra_env.items():
            monkeypatch.setenv(key, value)

    import config as config_module
    import main as main_module

    importlib.reload(config_module)
    importlib.reload(main_module)

    return main_module.app


@pytest.fixture
def app_factory(monkeypatch, tmp_path):
    def _factory(extra_env=None):
        return _build_app(monkeypatch, tmp_path, extra_env=extra_env)

    return _factory
