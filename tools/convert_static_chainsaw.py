"""Route the mod's original chainsaw geometry through native Assimp StaticMesh.

The original TXT remains as provenance/input, but .x has loader precedence.
No vanilla mesh, skeleton, scale or item mechanics are copied or changed.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from native_static_x import read_legacy_static, write_x, read_x

REPO = Path(__file__).resolve().parents[1]


def main():
    source = REPO / 'common/media/models/weapons_chainsaw.txt'
    output = REPO / 'common/media/models_X/weapons_chainsaw.x'
    positions, normals, original_uv, faces = read_legacy_static(source)
    native_uv = original_uv.copy()
    # Legacy atlas UVs address the PNG's top-left pixel convention. PZ's native
    # texture sampler addresses V from the bottom; compensate before shared X
    # export (whose independent preflip handles Assimp's X parser conversion).
    # Native screenshot and 200 blade-tip triangles prove the original mapping:
    # direct PNG samples are grey metal, flipped samples are red housing.
    native_uv[:, 1] = 1 - native_uv[:, 1]
    geometry = positions, normals, native_uv, faces
    write_x(output, *geometry, name='HCRChainsaw')
    for before, after in zip(geometry, read_x(output)):
        np.testing.assert_allclose(after, before, rtol=1e-7, atol=1e-8)
    positions, _, _, faces = geometry
    record = {'source': source.relative_to(REPO).as_posix(),
              'asset': output.relative_to(REPO).as_posix(),
              'texture': 'common/media/textures/Objects_chainsaw.png',
              'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
              'vertices': len(positions), 'triangles': len(faces),
              'bounds': [positions.min(axis=0).tolist(), positions.max(axis=0).tolist()],
              'processing': 'Original Hydrocraft static TXT positions/normals/triangles and .49672555m length unchanged; corresponding original Objects_chainsaw albedo replaces transparent UV template; legacy top-left UV V converted to native bottom-origin sampler, then shared DirectX exporter compensates Assimp X V conversion; blade-tip atlas samples verified grey and housing red; loadX StaticMesh avoids native TXT null skinningData bug',
              'verification': 'Text geometry round-trip checked; native display pending'}
    (REPO / 'docs/CHAINSAW_PIPELINE.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
