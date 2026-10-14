"""Audit model references against installed B42 scripts and native mesh paths.

Optional --fix-case only repairs uniquely identifiable existing model names.
Texture-file absence is a review hint: vanilla textures can live in .pack files.
"""
import argparse
import json
import re
from pathlib import Path

from hcr_paths import REPO, SCRIPTS, find_game, read_text

HEADER = re.compile(r"^\s*(module|item|model|craftRecipe|fixing)\s+([^\s{]+)")
FIELD = re.compile(r"^(\s*)(WorldStaticModel|StaticModel|WeaponSprite|mesh|texture)(\s*=\s*)([^,\r\n]+)", re.I)


def scan(folder):
    models, references = {}, []
    for path in sorted(folder.rglob("*.txt")):
        module, kind, name = "Base", None, None
        for line_number, line in enumerate(read_text(path).splitlines(), 1):
            header = HEADER.match(line)
            if header:
                kind, name = header.groups()
                if kind == "module":
                    module = name
                elif kind == "model":
                    models[f"{module}.{name}"] = {"file": str(path), "line": line_number}
            field = FIELD.match(line)
            if not field:
                continue
            key, value = field.group(2), field.group(4).strip()
            if kind == "model" and key.lower() in {"mesh", "texture"}:
                models[f"{module}.{name}"][key.lower()] = value
            elif kind == "item" and key.lower() in {"worldstaticmodel", "staticmodel", "weaponsprite"}:
                references.append({"item": f"{module}.{name}", "field": key, "value": value,
                                   "file": str(path), "line": line_number})
    return models, references


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--fix-case", action="store_true")
    args = parser.parse_args()
    game = Path(args.game) if args.game else find_game()
    vanilla, _ = scan(game / "media/scripts")
    custom, refs = scan(SCRIPTS)
    models = {**vanilla, **custom}
    folded = {}
    for name in models:
        folded.setdefault(name.casefold(), []).append(name)
    unknown, repairs = [], []
    for ref in refs:
        value = ref["value"]
        resolved = value if "." in value else f"Base.{value}"
        if "." not in value and ref["field"].lower() != "weaponsprite":
            # Item.resolveModelScripts searches the item's module, then other
            # loaded modules, before references are validated by ModelScript.
            local = f"{ref['item'].split('.')[0]}.{value}"
            exact = [name for name in models if name.endswith("." + value)]
            if local in models or exact:
                continue
        if resolved in models:
            continue
        candidates = folded.get(resolved.casefold(), [])
        if not candidates and "." not in value:
            candidates = folded.get(f"Hydrocraft.{value}".casefold(), [])
        if len(candidates) == 1:
            repairs.append({**ref, "replacement": candidates[0]})
        else:
            unknown.append(ref)
    if args.fix_case:
        by_file = {}
        for repair in repairs:
            by_file.setdefault(Path(repair["file"]), {})[repair["line"]] = repair
        for path, changes in by_file.items():
            original = path.read_bytes()
            bom = original.startswith(b"\xef\xbb\xbf")
            lines = original.decode("utf-8-sig").splitlines(keepends=True)
            for number, repair in changes.items():
                line = lines[number - 1]
                match = FIELD.match(line)
                lines[number - 1] = line[:match.start(4)] + repair["replacement"] + line[match.end(4):]
            path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + "".join(lines).encode("utf-8"))
    asset_paths = {}
    for root in [REPO / "common/media", game / "media"]:
        for path in root.rglob("*"):
            if path.is_file():
                asset_paths.setdefault(path.relative_to(root).as_posix().casefold(), []).append(str(path))
    missing_meshes, texture_review = [], []
    for name, model in custom.items():
        mesh = model.get("mesh")
        if mesh:
            mesh = mesh.replace("\\", "/")
            if mesh.startswith("media/"):
                candidates = [mesh[6:]]
            else:
                # Match ModelScript.checkMesh, not Assimp's broader parsers.
                # GLB can be parsed but is absent from native script validation.
                candidates = [f"models_X/{mesh}{ext}" for ext in [".fbx", ".x"]]
                candidates.append(f"models/{mesh}.txt")
            if not any(candidate.casefold() in asset_paths for candidate in candidates):
                missing_meshes.append({"model": name, **model})
        texture = model.get("texture")
        if texture:
            texture = texture.replace("\\", "/")
            candidate = texture[6:] if texture.startswith("media/") else f"textures/{texture}.png"
            if candidate.casefold() not in asset_paths:
                texture_review.append({"model": name, **model})
    report = {"reference_count": len(refs), "custom_model_count": len(custom),
              "unknown_models": unknown, "exact_case_or_namespace_repairs": repairs,
              "missing_meshes": missing_meshes, "texture_file_review": texture_review,
              "fixes_applied": args.fix_case}
    if args.output:
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    print(f"References {len(refs)}; unknown {len(unknown)}; exact repairs {len(repairs)}; "
          f"missing meshes {len(missing_meshes)}; texture reviews {len(texture_review)}")


if __name__ == "__main__":
    main()
