# -*- coding: utf-8 -*-
"""Общие пути и хелперы для инструментов аудита HCR.

Корень репозитория определяется от расположения этого файла — настраивать
нечего. Каталог установки Project Zomboid (нужен для ванильных предметов
и переводов) ищется в таком порядке:

  1. аргумент командной строки  --game "путь"  /  --game=путь
  2. переменная окружения       PZ_GAME_DIR
  3. типовые места установки Steam (Windows / Linux / macOS)

Пример:
    PZ_GAME_DIR="~/.steam/steam/steamapps/common/ProjectZomboid" python3 tools/parse_hcr.py
    python3 tools/variant_b.py --game "D:\\Steam\\steamapps\\common\\ProjectZomboid"
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent

SCRIPTS = REPO / "common/media/scripts"
LUA = REPO / "common/media/lua"
TR_RU = LUA / "shared/Translate/RU"
DOCS = REPO / "docs"
MODEL = HERE / "model.json"
MOD_INFO = REPO / "common/mod.info"

GAME_ENV = "PZ_GAME_DIR"
GAME_CANDIDATES = (
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
    r"C:\Program Files\Steam\steamapps\common\ProjectZomboid",
    "~/.steam/steam/steamapps/common/ProjectZomboid",
    "~/.local/share/Steam/steamapps/common/ProjectZomboid",
    "~/Library/Application Support/Steam/steamapps/common/ProjectZomboid",
)

_HINT = (
    "Каталог Project Zomboid не найден. Укажите его через --game <путь> "
    f"или переменную окружения {GAME_ENV} "
    "(внутри должна лежать папка media/scripts)."
)


def read_text(path: Path) -> str:
    """Чтение файла с перебором кодировок, встречающихся в скриптах мода."""
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace")


def _is_game_dir(path: Path) -> bool:
    return (path / "media/scripts").is_dir()


def _from_argv():
    argv = sys.argv[1:]
    for i, arg in enumerate(argv):
        if arg.startswith("--game="):
            return arg.split("=", 1)[1]
        if arg == "--game" and i + 1 < len(argv):
            return argv[i + 1]
    return None


def find_game(required: bool = True):
    """Каталог установки Project Zomboid или None (если required=False)."""
    for explicit in (_from_argv(), os.environ.get(GAME_ENV)):
        if explicit:
            path = Path(explicit).expanduser()
            if _is_game_dir(path):
                return path
            sys.exit(f"{path} — не похоже на установку Project Zomboid "
                     "(нет подкаталога media/scripts).")
    for candidate in GAME_CANDIDATES:
        path = Path(candidate).expanduser()
        if _is_game_dir(path):
            return path
    if required:
        sys.exit(_HINT)
    return None


def mod_version(default: str = "?") -> str:
    """modversion из common/mod.info — чтобы отчёты не врали о версии."""
    if MOD_INFO.exists():
        for line in read_text(MOD_INFO).splitlines():
            if line.strip().startswith("modversion="):
                return line.split("=", 1)[1].strip()
    return default


def load_model():
    """Модель, собранная parse_hcr.py."""
    if not MODEL.exists():
        sys.exit(f"Нет {MODEL} — сначала запустите tools/parse_hcr.py.")
    return __import__("json").loads(MODEL.read_text(encoding="utf-8"))


def require_vanilla_names(model):
    """Генераторы документации требуют ванильных переводов.

    Без них ванильные предметы подписываются идентификаторами (Stone2 вместо
    «Камень»), и перегенерация молча ухудшает docs/. Пропустить проверку —
    флагом --allow-missing-vanilla.
    """
    if model.get("van_ru"):
        return
    if "--allow-missing-vanilla" in sys.argv[1:]:
        print("! ванильные переводы отсутствуют: часть подписей будет "
              "идентификаторами", file=sys.stderr)
        return
    sys.exit("В model.json нет ванильных переводов — пересоберите её при "
             f"установленной игре (--game <путь> или {GAME_ENV}), иначе "
             "ванильные предметы попадут в docs/ идентификаторами. "
             "Осознанно — повторите с --allow-missing-vanilla.")
