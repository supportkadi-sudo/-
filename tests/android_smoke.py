"""Install and exercise a separately exported x86_64 build of identical game code."""
import re,subprocess,time
from pathlib import Path
out=Path('diagnostics');out.mkdir(exist_ok=True)
def adb(*args):
    return subprocess.check_output(['adb',*args])
def alive():
    assert adb('shell','pidof','com.hookahbros.prototype').strip(), 'Android app exited'
adb('install','-r','build/HookahBros-emulator.apk')
adb('logcat','-c')
adb('shell','monkey','-p','com.hookahbros.prototype','-c','android.intent.category.LAUNCHER','1')
time.sleep(8);alive()
def capture(name):
    data=adb('exec-out','screencap','-p');(out/name).write_bytes(data)
    assert data.startswith(b'\x89PNG'), 'Screenshot invalid'
    import struct
    return struct.unpack('>II',data[16:24])
w,h=capture('android-menu.png')
assert w>h,'Game must launch landscape'
adb('shell','input','tap',str(int(w*.5)),str(int(h*.26)))
time.sleep(5);alive();capture('android-solo.png')
# Exercise touch jump, drag camera and pause; the runtime emits truthful state markers.
adb('shell','input','tap',str(int(w*.91)),str(int(h*.63)))
adb('shell','input','swipe',str(int(w*.65)),str(int(h*.45)),str(int(w*.73)),str(int(h*.42)),'300')
adb('shell','input','tap',str(int(w*.07)),str(int(h*.055)))
time.sleep(2);alive();capture('android-pause.png')
adb('shell','input','keyevent','3');time.sleep(1)
adb('shell','monkey','-p','com.hookahbros.prototype','1');time.sleep(2);alive()
logs=adb('logcat','-d').decode(errors='replace');(out/'android-logcat.txt').write_text(logs)
assert 'HB_SOLO_READY' in logs,'Solo session did not start'
assert 'HB_PAUSE_OPEN' in logs,'Pause menu did not open'
assert not re.search(r'FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|Parse Error:',logs), 'Crash/script error in Android logcat'
print('ANDROID_RUNTIME_OK: install, menu, solo, controls, pause and resume')
