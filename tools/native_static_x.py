"""Own geometry export to DirectX text .x; no game skeleton or assets needed."""
import re
import numpy as np


def write_x(path, positions, normals, uv, faces, name='HCRStaticMesh'):
    def vectors(values):
        return '\n'.join(';'.join(format(float(v), '.9g') for v in row)
                         + (';;' if i == len(values)-1 else ';,')
                         for i, row in enumerate(values))
    def triangles(values):
        return '\n'.join('3;' + ','.join(str(int(v)) for v in row)
                         + (';;' if i == len(values)-1 else ';,')
                         for i, row in enumerate(values))
    # Assimp's X importer converts texture coordinates by v -> 1-v. Pre-flip
    # V so the separate PNG is sampled exactly like the original GLB/TXT UV.
    x_uv = np.array(uv, copy=True)
    x_uv[:, 1] = 1 - x_uv[:, 1]
    text = ('xof 0303txt 0032\nMesh ' + name + ' {\n'
            + str(len(positions)) + ';\n' + vectors(positions) + '\n'
            + str(len(faces)) + ';\n' + triangles(faces) + '\n'
            + 'MeshNormals {\n' + str(len(normals)) + ';\n' + vectors(normals)
            + '\n' + str(len(faces)) + ';\n' + triangles(faces) + '\n}\n'
            + 'MeshTextureCoords {\n' + str(len(x_uv)) + ';\n' + vectors(x_uv)
            + '\n}\n}\n')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='ascii')


def read_x(path):
    text = path.read_text(encoding='ascii')
    assert text.startswith('xof 0303txt 0032\nMesh ')
    numbers = re.findall(r'[-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?', text[text.index('{')+1:])
    index = 0
    def scalar():
        nonlocal index
        value = float(numbers[index]); index += 1
        return value
    def vectors():
        return np.array([[scalar(), scalar(), scalar()] for _ in range(int(scalar()))])
    def triangles():
        faces = []
        for _ in range(int(scalar())):
            assert scalar() == 3
            faces.append([int(scalar()), int(scalar()), int(scalar())])
        return np.array(faces)
    positions = vectors(); faces = triangles(); normals = vectors()
    normal_faces = triangles()
    assert np.array_equal(faces, normal_faces)
    uv = np.array([[scalar(), scalar()] for _ in range(int(scalar()))])
    uv[:, 1] = 1 - uv[:, 1]
    assert index == len(numbers) and len(positions) == len(normals) == len(uv)
    assert faces.min() >= 0 and faces.max() < len(positions)
    return positions, normals, uv, faces


def read_legacy_static(path):
    lines = [line.strip() for line in path.read_text(encoding='ascii').splitlines()
             if line.strip() and not line.startswith('#')]
    assert lines[0] == '1.0' and lines[2] == '3', 'only original static three-element meshes'
    count = int(lines[10]); start = 11
    data = [list(map(float, line.split(','))) for line in lines[start:start + count * 3]]
    positions = np.array(data[0::3]); normals = np.array(data[1::3]); uv = np.array(data[2::3])
    start += count * 3; face_count = int(lines[start])
    faces = np.array([list(map(int, line.split(','))) for line in lines[start+1:]])
    assert faces.shape == (face_count, 3)
    return positions, normals, uv, faces
