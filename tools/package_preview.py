"""Build an unpublished B42 preview outside the checkout, excluding lab tools."""
import argparse
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out", type=Path, required=True, help="New external output directory")
parser.add_argument("--release", action="store_true", help="Label installation notes as a release")
args = parser.parse_args()
output = args.out.resolve()
if output == ROOT or ROOT in output.parents:
    parser.error("Keep preview outputs outside the source checkout")
if output.exists():
    parser.error("Output directory already exists; choose a fresh preview name")
package = output / "HydrocraftReinvented"
shutil.copytree(ROOT / "common", package / "common")
(package / "42").mkdir()
metadata = (ROOT / "common/mod.info").read_text(encoding="utf-8-sig")
version_match = re.search(r'^modversion=([0-9A-Za-z.+_-]+)\s*$', metadata, re.M)
if not version_match:
    parser.error('mod.info must declare a safe modversion')
version = version_match.group(1)
(package / "42/mod.info").write_text(metadata, encoding="utf-8")
for name in ["README.md", "CHANGELOG.md", "ROADMAP.md", "CONTRIBUTING.md"]:
    shutil.copy2(ROOT / name, package / name)
for name in ["ASSET_PROVENANCE.json", "SPIKE_TRAP_PIPELINE.json",
             "WORLD_MODEL_FALLBACKS.json", "PLAYABILITY_VERIFICATION.md"]:
    (package / "docs").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "docs" / name, package / "docs" / name)
for name in ["banner.jpg", "LICENSE", "LICENSE.md", "LICENSE.txt"]:
    if (ROOT / name).is_file():
        shutil.copy2(ROOT / name, package / name)

# Copy the documentation reached by actual Markdown links, rather than shipping
# development tools or private lab data. CONTRIBUTING's tool index is a document,
# included under docs/TOOLS.md; executable tools remain outside the preview.
contributing = package / "CONTRIBUTING.md"
contributing.write_text(contributing.read_text(encoding="utf-8").replace(
    "(tools/README.md)", "(docs/TOOLS.md)"), encoding="utf-8")
shutil.copy2(ROOT / "tools/README.md", package / "docs/TOOLS.md")
link_pattern = re.compile(r"!?\[[^\]\n]*\]\((<[^>]+>|[^)\n]+)\)")

def local_links(markdown):
    for match in link_pattern.finditer(markdown.read_text(encoding="utf-8-sig")):
        href = match[1].strip().strip("<>")
        parsed = urlsplit(href)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        yield unquote(parsed.path)

pending = list(package.rglob("*.md"))
visited = set()
while pending:
    markdown = pending.pop()
    if markdown in visited:
        continue
    visited.add(markdown)
    for href in local_links(markdown):
        destination = (markdown.parent / href).resolve()
        if package.resolve() not in destination.parents:
            raise RuntimeError(f"Documentation link escapes package: {markdown.name}: {href}")
        if not destination.exists():
            relative = destination.relative_to(package.resolve())
            source = ROOT / relative
            if (not relative.parts or relative.parts[0] != "docs"
                    or source.suffix.lower() not in {".md", ".json", ".xlsx", ".png", ".jpg"}
                    or not source.is_file()):
                raise RuntimeError(f"Missing distributable documentation: {markdown.name}: {href}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        if destination.suffix.lower() == ".md":
            pending.append(destination)
(output / "INSTALL.txt").write_text(
    ("RELEASE / РЕЛИЗ\n" if args.release else "UNPUBLISHED PREVIEW / НЕОПУБЛИКОВАННАЯ ТЕСТОВАЯ СБОРКА\n") +
    "Project Zomboid 42.21.0. Use a separate test profile first.\n"
    "Copy HydrocraftReinvented into your profile's mods folder.\n"
    "Keep both common and 42 folders. Disable the Workshop copy in this profile.\n"
    "Do not enable two copies of the same mod ID.\n"
    "Скопируйте HydrocraftReinvented в mods отдельного тестового профиля;\n"
    "сохраните common и 42. Отключите Workshop-копию в этом профиле.\n",
    encoding="utf-8")
archive = output / f"HydrocraftReinvented-{version}.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(package.rglob("*")):
        if path.is_file(): z.write(path, path.relative_to(output).as_posix())
    z.write(output / "INSTALL.txt", "INSTALL.txt")
manifest = {"archive": archive.name, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "files": sum(p.is_file() for p in package.rglob("*")), "published": False}
(output / "PREVIEW.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
print(json.dumps(manifest, indent=2))
