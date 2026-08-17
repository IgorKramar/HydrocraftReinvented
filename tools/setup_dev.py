# -*- coding: utf-8 -*-
"""Подготовка машины к работе над модом: доставить недостающее, показать пробелы.

Скрипт идемпотентен — гоняйте сколько угодно. Что он делает:

  1. проверяет версию Python;
  2. находит установку Project Zomboid (см. hcr_paths.find_game);
  3. заводит tools/pz-lua — ссылку на media/lua игры, из неё lua-language-server
     берёт ванильный Lua API (см. .luarc.json);
  4. ставит openpyxl и Pillow в tools/.venv, если их нет в системном Python;
  5. проверяет lua-language-server и подсказывает команду установки.

Права root нужны только для пятого пункта, и его скрипт не выполняет сам —
печатает команду. Всё остальное делается без sudo.

    python3 tools/setup_dev.py            # доставить недостающее
    python3 tools/setup_dev.py --check    # только диагностика, ничего не менять
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hcr_paths as hp  # noqa: E402

MIN_PYTHON = (3, 8)
VENV = hp.HERE / ".venv"
PZ_LUA_LINK = hp.HERE / "pz-lua"
PYTHON_DEPS = (("openpyxl", "openpyxl"), ("PIL", "Pillow"))

OK, WARN, FAIL = "  ok  ", " нет  ", " ошибка "

_problems = []


def say(status: str, title: str, detail: str = "") -> None:
    print(f"[{status}] {title}" + (f"\n         {detail}" if detail else ""))


def note_problem(title: str, hint: str) -> None:
    _problems.append((title, hint))


def check_python() -> None:
    v = sys.version_info
    current = f"{v.major}.{v.minor}.{v.micro}"
    if v[:2] >= MIN_PYTHON:
        say(OK, f"Python {current}")
    else:
        need = ".".join(map(str, MIN_PYTHON))
        say(FAIL, f"Python {current}", f"инструментам нужен {need} или новее")
        note_problem("Python слишком старый", f"обновитесь до {need}+")


def check_game() -> Path | None:
    game = hp.find_game(required=False)
    if game:
        say(OK, "Project Zomboid", str(game))
        return game
    say(WARN, "Project Zomboid не найден")
    note_problem(
        "не найдена установка игры",
        "укажите её через PZ_GAME_DIR=<путь> — без неё не работают "
        "variant_b.py, analyze_gaps.py и генераторы docs/",
    )
    return None


def link_pz_lua(game: Path | None, apply: bool) -> None:
    """tools/pz-lua → media/lua игры: из неё lua-language-server берёт API."""
    if game is None:
        say(WARN, "tools/pz-lua", "нечего связывать — игра не найдена")
        return

    target = game / "media/lua"
    if PZ_LUA_LINK.is_symlink() and PZ_LUA_LINK.resolve() == target.resolve():
        say(OK, "tools/pz-lua", f"→ {target}")
        return

    if not apply:
        say(WARN, "tools/pz-lua", f"нужно связать с {target}")
        note_problem("нет ссылки tools/pz-lua", "python3 tools/setup_dev.py")
        return

    try:
        if PZ_LUA_LINK.is_symlink() or PZ_LUA_LINK.exists():
            PZ_LUA_LINK.unlink()
        PZ_LUA_LINK.symlink_to(target, target_is_directory=True)
        say(OK, "tools/pz-lua", f"→ {target}")
    except OSError as exc:
        # На Windows симлинк требует режима разработчика или прав администратора.
        say(FAIL, "tools/pz-lua", str(exc))
        note_problem(
            "не удалось создать tools/pz-lua",
            f'mklink /D "{PZ_LUA_LINK}" "{target}"  (Windows, от администратора)',
        )


def _venv_python() -> Path:
    bindir = "Scripts" if os.name == "nt" else "bin"
    exe = "python.exe" if os.name == "nt" else "python"
    return VENV / bindir / exe


def _importable(python: Path | None, module: str) -> bool:
    if python is None:
        try:
            __import__(module)
            return True
        except ImportError:
            return False
    return subprocess.run(
        [str(python), "-c", f"import {module}"],
        capture_output=True,
    ).returncode == 0


def check_python_deps(apply: bool) -> None:
    """openpyxl и Pillow: в системном Python или в tools/.venv."""
    missing = [pkg for mod, pkg in PYTHON_DEPS if not _importable(None, mod)]
    if not missing:
        say(OK, "openpyxl, Pillow", "в системном Python")
        return

    venv_python = _venv_python()
    if venv_python.exists():
        left = [pkg for mod, pkg in PYTHON_DEPS
                if not _importable(venv_python, mod)]
        if not left:
            say(OK, "openpyxl, Pillow", f"в {VENV.relative_to(hp.REPO)}")
            _venv_reminder()
            return
        missing = left

    if not apply:
        say(WARN, ", ".join(missing), "нет ни в системе, ни в tools/.venv")
        note_problem(f"нет {', '.join(missing)}", "python3 tools/setup_dev.py")
        return

    if not venv_python.exists():
        print(f"    создаю {VENV.relative_to(hp.REPO)} …")
        rc = subprocess.run([sys.executable, "-m", "venv", str(VENV)]).returncode
        if rc != 0 or not venv_python.exists():
            say(FAIL, "tools/.venv", "не удалось создать виртуальное окружение")
            note_problem(
                "нет openpyxl и Pillow",
                "поставьте их пакетами дистрибутива: "
                "python-openpyxl python-pillow",
            )
            return

    print(f"    ставлю {', '.join(missing)} …")
    rc = subprocess.run(
        [str(venv_python), "-m", "pip", "install", "--quiet", *missing]
    ).returncode
    if rc == 0:
        say(OK, ", ".join(missing), f"в {VENV.relative_to(hp.REPO)}")
        _venv_reminder()
    else:
        say(FAIL, ", ".join(missing), "pip вернул ошибку")
        note_problem("не установились openpyxl/Pillow",
                     f"{venv_python} -m pip install {' '.join(missing)}")


def _venv_reminder() -> None:
    rel = _venv_python().relative_to(hp.REPO)
    print(f"         build_xlsx.py и make_icon.py запускать через {rel}")


_LSP_INSTALL = (
    ("pacman", "sudo pacman -S lua-language-server"),
    ("dnf", "sudo dnf install lua-language-server"),
    ("brew", "brew install lua-language-server"),
    ("snap", "sudo snap install lua-language-server --classic"),
)


def check_lua_lsp() -> None:
    exe = shutil.which("lua-language-server")
    if exe:
        out = subprocess.run([exe, "--version"], capture_output=True, text=True)
        version = (out.stdout or out.stderr).strip().splitlines()[:1]
        say(OK, "lua-language-server", f"{version[0] if version else ''} · {exe}")
        return

    say(WARN, "lua-language-server не найден")
    for manager, command in _LSP_INSTALL:
        if shutil.which(manager):
            note_problem("нет lua-language-server", command)
            return
    note_problem(
        "нет lua-language-server",
        "соберите с https://github.com/LuaLS/lua-language-server/releases",
    )


def check_luarc() -> None:
    luarc = hp.REPO / ".luarc.json"
    if luarc.exists():
        say(OK, ".luarc.json")
    else:
        say(FAIL, ".luarc.json отсутствует")
        note_problem("нет .luarc.json",
                     "файл версионируется — восстановите его из git")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Подготовка окружения для работы над Hydrocraft Reinvented."
    )
    parser.add_argument("--check", action="store_true",
                        help="только диагностика, ничего не устанавливать")
    parser.add_argument("--game", metavar="ПУТЬ",
                        help="каталог установки Project Zomboid")
    args = parser.parse_args()
    apply = not args.check

    print("Окружение Hydrocraft Reinvented\n")
    check_python()
    game = check_game()
    check_luarc()
    link_pz_lua(game, apply)
    check_python_deps(apply)
    check_lua_lsp()

    if not _problems:
        print("\nВсё на месте.")
        return 0

    print("\nОсталось сделать вручную:")
    for title, hint in _problems:
        print(f"  · {title}\n      {hint}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
