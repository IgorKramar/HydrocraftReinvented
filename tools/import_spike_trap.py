"""Convert our fal GLB into B42.21's Assimp static DirectX .x mesh and PNG.

Usage: python tools/import_spike_trap.py SOURCE.glb --preview preview.png
The raw fal source stays private. No model generation or network request occurs.
"""
import argparse
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image
from native_static_x import write_x, read_x

REPO = Path(__file__).resolve().parents[1]


def read_glb(path):
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw)
    assert magic == 0x46546C67 and version == 2 and total == len(raw)
    position, document, binary = 12, None, None
    while position < len(raw):
        length, kind = struct.unpack_from("<II", raw, position)
        chunk = raw[position + 8:position + 8 + length]
        position += 8 + length
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = bytearray(chunk)
    assert document is not None and binary is not None
    return raw, document, binary


def accessor(document, binary, index):
    data = document["accessors"][index]
    view = document["bufferViews"][data["bufferView"]]
    assert "sparse" not in data and view.get("buffer", 0) == 0
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[data["type"]]
    dtype = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}[data["componentType"]]
    size = np.dtype(dtype).itemsize
    offset = view.get("byteOffset", 0) + data.get("byteOffset", 0)
    return np.ndarray((data["count"], components), dtype=dtype, buffer=binary,
                      offset=offset, strides=(view.get("byteStride", components * size), size))


def add_nails(document, binary, primitive, image):
    """Restore fine steel nails omitted by the image-to-3D reconstruction."""
    positions = accessor(document, binary, primitive["attributes"]["POSITION"]).copy()
    normals = accessor(document, binary, primitive["attributes"]["NORMAL"]).copy()
    uv = accessor(document, binary, primitive["attributes"]["TEXCOORD_0"]).copy()
    indices = accessor(document, binary, primitive["indices"]).reshape(-1, 3).copy()
    pixels = np.array(image, dtype=float) / 255.0
    # A real grey metal texel from the generated albedo; no second material or
    # foreign atlas is needed by PZ's single-mesh/single-texture static loader.
    difference = pixels.max(axis=2) - pixels.min(axis=2)
    score = difference * 5 + np.abs(pixels.mean(axis=2) - 0.34)
    iy, ix = np.unravel_index(np.argmin(score), score.shape)
    metal_uv = [(ix + 0.5) / image.width, (iy + 0.5) / image.height]
    extra_positions, extra_normals, extra_uv, extra_indices = [], [], [], []
    base = float(positions[:, 1].max()) - 0.006
    for x in np.linspace(-0.255, 0.255, 7):
        for z in np.linspace(-0.255, 0.255, 7):
            tip = np.array([x, base + 0.07, z])
            for side in range(8):
                a, b = side * np.pi / 4, (side + 1) * np.pi / 4
                p1 = np.array([x + 0.0035 * np.cos(a), base, z + 0.0035 * np.sin(a)])
                p2 = np.array([x + 0.0035 * np.cos(b), base, z + 0.0035 * np.sin(b)])
                normal = np.cross(tip - p1, p2 - p1)
                normal /= np.linalg.norm(normal)
                start = len(positions) + len(extra_positions)
                extra_indices.append([start, start + 1, start + 2])
                extra_positions.extend([p1, tip, p2])
                extra_normals.extend([normal] * 3)
                extra_uv.extend([metal_uv] * 3)
    positions = np.vstack([positions, extra_positions]).astype("<f4")
    normals = np.vstack([normals, extra_normals]).astype("<f4")
    uv = np.vstack([uv, extra_uv]).astype("<f4")
    indices = np.vstack([indices, extra_indices]).astype("<u4").reshape(-1, 1)
    packed = bytearray(binary)
    for index, values, component_type, value_type in [
        (primitive["attributes"]["POSITION"], positions, 5126, "VEC3"),
        (primitive["attributes"]["NORMAL"], normals, 5126, "VEC3"),
        (primitive["attributes"]["TEXCOORD_0"], uv, 5126, "VEC2"),
        (primitive["indices"], indices, 5125, "SCALAR"),
    ]:
        packed.extend(b"\0" * (-len(packed) % 4))
        offset = len(packed)
        payload = values.tobytes()
        packed.extend(payload)
        view_index = len(document["bufferViews"])
        document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(payload)})
        document["accessors"][index] = {"bufferView": view_index, "componentType": component_type,
            "count": len(values), "type": value_type,
            "min": values.min(axis=0).tolist(), "max": values.max(axis=0).tolist()}
    return packed, positions


def render_preview(path, mesh_path, texture_path):
    # Re-read delivered files, so the preview verifies the exported geometry/UV.
    from PIL import ImageDraw
    vertices, _, uv, faces = read_x(mesh_path)
    image = np.array(Image.open(texture_path).convert("RGB")) / 255.0
    center_uv = uv[faces].mean(axis=1)
    px = np.clip((center_uv[:, 0] * (image.shape[1] - 1)).astype(int), 0, image.shape[1] - 1)
    py = np.clip((center_uv[:, 1] * (image.shape[0] - 1)).astype(int), 0, image.shape[0] - 1)
    colors = image[py, px]
    preview = Image.new("RGB", (1024, 540), "#ececea")
    draw = ImageDraw.Draw(preview)
    centered = vertices - (vertices.min(axis=0) + vertices.max(axis=0)) / 2
    triangles = centered[faces]
    normals = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
    normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-8)
    light = np.array([0.3, 0.8, 0.5]); light /= np.linalg.norm(light)
    brightness = 0.45 + 0.55 * np.abs(normals @ light)
    for index, view in enumerate([np.array([1.3, 1.2, 1.3]), np.array([0.0, 1.4, 0.15])]):
        view /= np.linalg.norm(view)
        right = np.cross(np.array([0.0, 1.0, 0.0]), view); right /= np.linalg.norm(right)
        up = np.cross(view, right)
        projected = np.column_stack((centered @ right, -(centered @ up)))
        scale = min(450 / np.ptp(projected[:, 0]), 430 / np.ptp(projected[:, 1]))
        projected = projected * scale + np.array([256 + 512 * index, 285])
        depths = (triangles @ view).mean(axis=1)
        for face_index in np.argsort(depths):
            polygon = [tuple(point) for point in projected[faces[face_index]]]
            color = tuple((np.clip(colors[face_index] * brightness[face_index], 0, 1) * 255).astype(int))
            draw.polygon(polygon, fill=color)
    draw.text((20, 15), "HCR spike trap: native static DirectX / albedo, 0.60 m footprint", fill="#242424")
    draw.text((20, 520), "Technical orthographic inspection; per-triangle sampled albedo", fill="#555555")
    path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    raw, document, binary = read_glb(args.source)
    assert len(document["meshes"]) == 1 and len(document["meshes"][0]["primitives"]) == 1
    assert all(not any(key in node for key in ["matrix", "translation", "rotation", "scale"])
               for node in document["nodes"]), "Bake nonidentity node transforms first"
    primitive = document["meshes"][0]["primitives"][0]
    assert primitive.get("mode", 4) == 4 and "skin" not in document["nodes"][1]
    positions = accessor(document, binary, primitive["attributes"]["POSITION"])
    minimum, maximum = positions.min(axis=0).copy(), positions.max(axis=0).copy()
    factor = 0.6 / max(maximum[0] - minimum[0], maximum[2] - minimum[2])
    positions[:, 0] -= (minimum[0] + maximum[0]) / 2
    positions[:, 2] -= (minimum[2] + maximum[2]) / 2
    positions[:, 1] -= minimum[1]
    positions *= factor
    position_meta = document["accessors"][primitive["attributes"]["POSITION"]]
    position_meta["min"], position_meta["max"] = positions.min(axis=0).tolist(), positions.max(axis=0).tolist()
    material = document["materials"][primitive.get("material", 0)]
    texture_info = document["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    image_index = texture_info.get("source")
    if image_index is None:
        image_index = texture_info["extensions"]["EXT_texture_webp"]["source"]
    image_view = document["bufferViews"][document["images"][image_index]["bufferView"]]
    offset = image_view.get("byteOffset", 0)
    image = Image.open(io.BytesIO(binary[offset:offset + image_view["byteLength"]])).convert("RGB")
    binary, positions = add_nails(document, binary, primitive, image)
    position_meta = document["accessors"][primitive["attributes"]["POSITION"]]
    texture = REPO / "common/media/textures/WorldItems/HCRSpikeTrap.png"
    texture.parent.mkdir(parents=True, exist_ok=True)
    image.save(texture)
    # PZ uses the separate albedo texture. Strip unsupported PBR/embedded WebP
    # references; geometry and UVs remain unchanged except the baked unit/pivot.
    document["materials"] = [{"pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1]},
                              "alphaMode": "OPAQUE", "doubleSided": False}]
    for key in ["images", "textures", "samplers", "extensionsUsed", "extensionsRequired"]:
        document.pop(key, None)
    mesh = REPO / "common/media/models_X/WorldItems/HCRSpikeTrap.x"
    normals = accessor(document, binary, primitive["attributes"]["NORMAL"])
    uv = accessor(document, binary, primitive["attributes"]["TEXCOORD_0"])
    faces = accessor(document, binary, primitive["indices"]).reshape(-1, 3)
    write_x(mesh, positions, normals, uv, faces, 'HCRSpikeTrap')
    loaded = read_x(mesh)
    for expected, actual in zip([positions, normals, uv, faces], loaded):
        np.testing.assert_allclose(actual, expected, rtol=1e-7, atol=1e-9)
    # Remove only our previous generated formats. Static TXT has a native
    # applyToMesh bug when animationsMesh is supplied, even for a static model.
    for old in [REPO / 'common/media/models_X/WorldItems/HCRSpikeTrap.glb',
                REPO / 'common/media/models/WorldItems/HCRSpikeTrap.txt']:
        if old.exists():
            old.unlink()
    record = {"asset": mesh.relative_to(REPO).as_posix(), "texture": texture.relative_to(REPO).as_posix(),
              "source_sha256": hashlib.sha256(raw).hexdigest(), "output_sha256": hashlib.sha256(mesh.read_bytes()).hexdigest(),
              "processing": "B42.21 FileTask_LoadMesh.loadX StaticMesh (DirectX text mesh, normals, UV; no skeleton); V pre-flipped for Assimp X parser; 0.60 m XZ footprint, Y-up bottom pivot; separate PNG albedo; restored 49 steel nails omitted by Trellis, sampled grey from same atlas; geometry independently re-read and round-trip checked; avoids native static TXT applyToMesh skinningData bug",
              "vertices": len(positions), "triangles": document["accessors"][primitive["indices"]]["count"] // 3,
              "bounds": [position_meta["min"], position_meta["max"]]}
    (REPO / "docs/SPIKE_TRAP_PIPELINE.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if args.preview:
        render_preview(args.preview, mesh, texture)
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
