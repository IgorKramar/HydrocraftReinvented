"""Remove dangling ground-model references instead of substituting wrong shapes.

Also copy the existing quiver mesh to a distinct ground-only asset path, avoiding
native B42's path-only mesh cache collision between static and skinned models.
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

from audit_world_models import scan
from hcr_paths import REPO, SCRIPTS, find_game


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    source = REPO / "common/media/models_X/clothing/HCQuiver.fbx"
    ground = REPO / "common/media/models_X/WorldItems/HCRQuiverGround.fbx"
    assert source.is_file()
    if args.apply:
        ground.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, ground)
    vanilla, _ = scan(find_game() / "media/scripts")
    custom, refs = scan(SCRIPTS)
    all_models = {**vanilla, **custom}
    known_missing = {"Hydrocraft.WorldItem-HCCoffeeFilter"}
    removals = []
    for ref in refs:
        value = ref["value"]
        if "." in value:
            resolved = value
        else:
            local = ref["item"].split(".")[0] + "." + value
            matches = [name for name in all_models if name.endswith("." + value)]
            resolved = local if local in all_models else (matches[0] if matches else "???." + value)
        if resolved not in all_models or resolved in known_missing:
            assert ref["field"].lower() == "worldstaticmodel", \
                f"Not a safe icon fallback: {ref['field']} {ref['value']}"
            removals.append({"file": Path(ref["file"]).relative_to(REPO).as_posix(),
                             "item": ref["item"], "field": ref["field"], "old_model": value,
                             "source_line": ref["line"],
                             "fallback": "Native inventory/ground icon; no foreign-shape model substitution",
                             "reason": "Matching mesh missing" if resolved in known_missing else "Model declaration/appropriate geometry missing"})
    if args.apply:
        by_file = {}
        for removal in removals:
            by_file.setdefault(REPO / removal["file"], set()).add(removal["source_line"])
        for path, numbers in by_file.items():
            raw = path.read_bytes()
            bom = raw.startswith(b"\xef\xbb\xbf")
            lines = raw.decode("utf-8-sig").splitlines(keepends=True)
            result = "".join(line for number, line in enumerate(lines, 1) if number not in numbers)
            path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + result.encode("utf-8"))
        models_file = SCRIPTS / "HydrocraftReinvented/APhcmodels.txt"
        raw = models_file.read_bytes()
        text = raw.decode("utf-8-sig")
        text = re.sub(r"(?m)^\s*model WorldItem-HCCoffeeFilter\s*\{[^}]*\}\s*", "", text)
        models_file.write_bytes((b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8"))
        manifest_path = REPO / "docs/WORLD_MODEL_FALLBACKS.json"
        existing = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {"fallbacks": []}
        seen = {(row["file"], row["item"], row["field"], row["old_model"]) for row in existing["fallbacks"]}
        existing["fallbacks"].extend(row for row in removals
            if (row["file"], row["item"], row["field"], row["old_model"]) not in seen)
        existing["quiver_ground_copy"] = {"source": source.relative_to(REPO).as_posix(),
            "asset": ground.relative_to(REPO).as_posix(), "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "reason": "Separate static ground path for existing skinned quiver geometry"}
        manifest_path.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{'Applied' if args.apply else 'Would apply'} {len(removals)} explicit icon fallbacks")


if __name__ == "__main__":
    main()
