"""Register existing mod clothing assets with their authored GUIDs."""
from pathlib import Path
import xml.etree.ElementTree as ET

MEDIA = Path(__file__).resolve().parents[1] / 'common/media'


def build():
    root = ET.Element('fileGuidTable')
    seen = set()
    for path in sorted((MEDIA / 'clothing/clothingItems').glob('*.xml')):
        guid = ET.parse(path).getroot().findtext('m_GUID')
        if not guid or guid in seen:
            raise ValueError(f'Missing or duplicate clothing GUID: {path}')
        seen.add(guid)
        entry = ET.SubElement(root, 'files')
        ET.SubElement(entry, 'path').text = 'media/' + path.relative_to(MEDIA).as_posix()
        ET.SubElement(entry, 'guid').text = guid
    ET.indent(root, space='    ')
    ET.ElementTree(root).write(MEDIA / 'fileGuidTable.xml', encoding='utf-8', xml_declaration=True)
    print(f'Registered {len(seen)} clothing assets')


if __name__ == '__main__':
    build()
