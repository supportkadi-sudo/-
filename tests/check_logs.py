"""Godot can report script errors while still exiting zero: fail CI on those logs."""
import sys
from pathlib import Path
files=list(Path(sys.argv[1]).glob('*.log'))
bad=[]
for p in files:
    for line in p.read_text(errors='replace').splitlines():
        if 'ERROR:' in line or 'Parse Error:' in line:
            bad.append(f'{p.name}: {line}')
if bad: raise SystemExit('\n'.join(bad))
print('Runtime logs contain no engine/script errors')
