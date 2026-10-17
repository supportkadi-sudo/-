"""Install and exercise a separately exported x86_64 build of identical game code."""
import json,re,subprocess,time
from pathlib import Path
out=Path('diagnostics');out.mkdir(exist_ok=True)
def adb(*args):
    return subprocess.check_output(['adb',*args])
def alive():
    assert adb('shell','pidof','com.hookahbros.prototype').strip(), 'Android app exited'
adb('install','-r','build/HookahBros-emulator.apk')
adb('shell','settings','put','secure','immersive_mode_confirmations','confirmed')
# Reproduce a modern wide-screen phone while keeping the same Android emulator.
adb('shell','wm','size','2340x1080')
adb('logcat','-c')
adb('shell','monkey','-p','com.hookahbros.prototype','-c','android.intent.category.LAUNCHER','1')
for attempt in range(60):
    time.sleep(1)
    text=adb('logcat','-d').decode(errors='replace')
    if 'HB_MENU_READY' in text: break
else:
    (out/'android-logcat.txt').write_text(text)
    raise AssertionError('Android menu did not initialize within 60 seconds')
alive();time.sleep(2)
def capture(name):
    data=adb('exec-out','screencap','-p');(out/name).write_bytes(data)
    assert data.startswith(b'\x89PNG'), 'Screenshot invalid'
    import struct
    return struct.unpack('>II',data[16:24])
def tap_control(name):
    logs=adb('logcat','-d').decode(errors='replace')
    lines=[line.split('HB_UI_LAYOUT:',1)[1] for line in logs.splitlines() if 'HB_UI_LAYOUT:' in line]
    assert lines,'Game did not report its actual debug UI layout'
    point=json.loads(lines[-1])[name]
    adb('shell','input','tap',str(round(point[0])),str(round(point[1])))
w,h=capture('android-menu.png')
assert w/h>=2.0,'Wide-screen Android test profile was not applied'
tap_control('solo')
time.sleep(5);alive();capture('android-solo.png')
# Exercise touch jump, drag camera and pause; the runtime emits truthful state markers.
tap_control('jump')
adb('shell','input','swipe',str(int(w*.65)),str(int(h*.45)),str(int(w*.73)),str(int(h*.42)),'300')
tap_control('pause')
time.sleep(2);alive();capture('android-pause.png')
adb('shell','input','keyevent','3');time.sleep(1)
adb('shell','monkey','-p','com.hookahbros.prototype','1');time.sleep(2);alive()
logs=adb('logcat','-d').decode(errors='replace');(out/'android-logcat.txt').write_text(logs)
assert 'HB_SOLO_READY' in logs,'Solo session did not start'
assert 'HB_JUMP_REQUEST' in logs,'Jump control did not fire'
assert 'HB_PAUSE_OPEN' in logs,'Pause menu did not open'
layouts=[json.loads(line.split('HB_UI_LAYOUT:',1)[1]) for line in logs.splitlines() if 'HB_UI_LAYOUT:' in line]
assert layouts,'No UI layout diagnostics on wide screen'
for name in ('jump','pause'):
    x,y=layouts[-1][name]
    assert 0<=x<w and 0<=y<h, f'{name} button outside wide-screen bounds: {(x,y)} vs {(w,h)}'
assert not re.search(r'FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|Parse Error:',logs)
assert not any('godot' in line and 'ERROR:' in line for line in logs.splitlines()), 'Crash/script error in Android logcat'
print('ANDROID_RUNTIME_OK: install, menu, solo, controls, pause and resume')
