# Native static geometry, Project Zomboid 42.21

The new spike trap and the mod's original chainsaw use actual DirectX text `.x`
meshes under `common/media/models_X`. Model names and separate texture references
stay unchanged. Neither exported file contains bones, weights or animations.

The first GLB export could load through Assimp but was absent from native
`ModelScript.checkMesh` validation. A later static TXT export passed validation
but failed in the real client: `ModelLoader.applyToMesh` creates skinning data
only for nonstatic meshes, then unconditionally accesses that data when
`skinnedTo != null`. Adding skeleton records cannot fix the static branch.
Neither of these rejected formats remains as a generated spike-trap asset.

Native `FileTask_AbstractLoadModel.checkExtensionType` checks `.fbx`, `.glb`,
`.x`, then `media/models/*.txt`. `FileTask_LoadMesh.loadX` uses Assimp and
`ProcessedAiScene` with `LoadMode.StaticMesh` when the model declares
`static = true`; it avoids `ModelLoader.applyToMesh`. Native `checkMesh` also
recognises `.x`. The original chainsaw TXT remains as the converter's source,
but its matching `.x` has loader precedence.

Reproduce the owned geometry:

```text
python tools/import_spike_trap.py PRIVATE/HCRSpikeTrap.glb --preview PRIVATE/preview.png
python tools/convert_static_chainsaw.py
python tools/verify_static_x.py
```

The last command requires `assimp_py`, installed only in the private lab
dependency directory. It actually imports both files with the native loadX
flags: FindInstances, MakeLeftHanded, LimitBoneWeights, Triangulate,
OptimizeMeshes, RemoveRedundantMaterials and JoinIdenticalVertices. It checks
every imported triangle corner's position, normal and UV against the exported
source, independently of Assimp's vertex reordering. Both checks passed:

| Asset | Vertices | Triangles | Bones |
| --- | ---: | ---: | ---: |
| Spike trap | 5771 | 5121 | 0 |
| Chainsaw | 743 | 1343 | 0 |

Assimp's X parser flips the V texture coordinate; the shared exporter preflips
V to compensate. The legacy chainsaw converter additionally converts its
top-left atlas UV to the native bottom-origin PNG sampler. Positions and normals
retain their source scale and axes. The spike-trap technical preview was
regenerated from the final `.x`, then visually inspected. Provenance and output
hashes live in `SPIKE_TRAP_PIPELINE.json`, `CHAINSAW_PIPELINE.json` and
`ASSET_PROVENANCE.json`. The fal source and request metadata remain private;
no new generation request or charge was made for this format repair.

Actual client mesh display after this change still requires the main agent's
cold restart. Successful Assimp import is not presented as native display proof.

Follow-up: the main agent verified the spike-trap ground model in a real native
42.21 client, without the TXT NPE. The chainsaw's initial hand display used
`chainsaw uvs.png`, a UV wireframe template with 51% fully transparent pixels.
Its model now references the corresponding original opaque RGB
`Objects_chainsaw.png`, whose UV islands match that template. This texture was
already tracked in the mod's first commit (`3defd36`, 2026-08-06), and its SHA256
differs from installed vanilla `media/textures/chainsaw.png`. No game texture
was imported. Original chainsaw geometry and its 0.49672555 m longest dimension
remain unchanged. Native hand display after correcting the albedo is pending.

The corrected opaque albedo subsequently appeared in the native client, with
the long blade red. Inspection isolated a V convention mismatch: 200 blade-tip
triangles sample grey RGB(96.8,96.8,96.8) at the original atlas's top-left UV,
but red RGB(244.64,23.38,23.38) at inverted V, matching the capture. Only the
legacy chainsaw UV is now converted to native bottom-origin coordinates; this
is separate from Assimp's X parser conversion. `verify_static_x.py` imports the
final mesh and checks actual native-coordinate PNG samples: blade grey,
housing red. Positions, normals, triangles and physical scale are unchanged.
Final native colour display passed after a cold restart: the red housing and grey
blade are visible in the equipped hand model. The proof capture remains in the
private lab; no game screenshot or game file is included in the mod package.
