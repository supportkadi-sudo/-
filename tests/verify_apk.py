import sys,zipfile
from pathlib import Path
p=Path(sys.argv[1])
assert p.stat().st_size>1_000_000,'APK unexpectedly small'
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None,'APK CRC failure'
    names=z.namelist()
    assert 'AndroidManifest.xml' in names
    assert any(n.startswith('lib/arm64-v8a/') and n.endswith('.so') for n in names)
    assert any(n.startswith('assets/') and 'project.binary' in n for n in names)
    for script in ['main','player','world','ui']:
        assert any(n.startswith('assets/') and f'{script}.gd' in n for n in names),f'Missing {script}'
print('ARM64_APK_CONTENTS_OK',p.stat().st_size)
