"""Verify real Assimp import using PZ's loadX flags, geometry and external UV.

Requires assimp_py in the private lab dependency path. No engine code copied.
"""
from pathlib import Path
import numpy as np
import assimp_py as ai
from native_static_x import read_x

REPO = Path(__file__).resolve().parents[1]
FLAGS = (ai.Process_FindInstances | ai.Process_MakeLeftHanded
         | ai.Process_LimitBoneWeights | ai.Process_Triangulate
         | ai.Process_OptimizeMeshes | ai.Process_RemoveRedundantMaterials
         | ai.Process_JoinIdenticalVertices)


def verify(path):
    positions, normals, uv, faces = read_x(path)
    scene = ai.import_file(str(path), FLAGS)
    assert len(scene.meshes) == 1
    mesh = scene.meshes[0]
    vertices = np.asarray(mesh.vertices).reshape(-1, 3)
    imported_normals = np.asarray(mesh.normals).reshape(-1, 3)
    imported_uv = np.asarray(mesh.texcoords[0]).reshape(-1, mesh.num_uv_components[0])[:, :2]
    imported_faces = np.asarray(mesh.indices).reshape(-1, 3)
    assert mesh.num_bones == 0 and mesh.num_faces == len(faces)
    # Assimp X may reorder vertices/winding. Check the actual attribute tuples
    # for every triangle corner, including UV, independently of this ordering.
    expected = np.column_stack([positions, normals, uv])[faces].reshape(-1, 8)
    actual = np.column_stack([vertices, imported_normals, imported_uv])[imported_faces].reshape(-1, 8)
    def ordered(values):
        values = np.round(values, 5)
        return values[np.lexsort(values.T[::-1])]
    np.testing.assert_allclose(ordered(actual), ordered(expected), rtol=0, atol=2e-5)
    if path.name == 'weapons_chainsaw.x':
        from PIL import Image
        image = np.asarray(Image.open(REPO/'common/media/textures/Objects_chainsaw.png'))
        centers = vertices[imported_faces].mean(axis=1)
        sample = imported_uv[imported_faces].mean(axis=1)
        px = np.clip((sample[:, 0]*(image.shape[1]-1)).astype(int), 0, image.shape[1]-1)
        # Native PNG/OpenGL V origin, independently evidenced by client capture.
        py = np.clip(((1-sample[:, 1])*(image.shape[0]-1)).astype(int), 0, image.shape[0]-1)
        blade = image[py[centers[:, 1] > .35], px[centers[:, 1] > .35]].mean(axis=0)
        housing_mask = (centers[:, 1] > .02) & (centers[:, 1] < .1)
        housing = image[py[housing_mask], px[housing_mask]].mean(axis=0)
        assert np.max(blade) - np.min(blade) < 1, ("blade must be grey metal", blade)
        assert housing[0] > housing[1]*2, ("housing must be red", housing)
        print(f'Chainsaw native atlas sampling PASS: blade={blade}, housing={housing}')
    print(f'Assimp native flags PASS {path.name}: {mesh.num_vertices} vertices, {mesh.num_faces} triangles, no bones, positions/normals/UV conserved')


if __name__ == '__main__':
    verify(REPO/'common/media/models_X/WorldItems/HCRSpikeTrap.x')
    verify(REPO/'common/media/models_X/weapons_chainsaw.x')
