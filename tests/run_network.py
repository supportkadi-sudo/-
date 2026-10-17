"""Launch real ENet processes; retain logs and propagate every failure."""
import os, subprocess, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT','godot')
logs=root/'diagnostics'; logs.mkdir(exist_ok=True)
processes=[]
def launch(role,name,script='network'):
    file=(logs/f'network-{name}.log').open('w')
    p=subprocess.Popen([godot,'--headless','--path',str(root),'--script',f'res://tests/{script}.gd','--',role],stdout=file,stderr=subprocess.STDOUT)
    processes.append((p,file,name))
try:
    launch('host','host');time.sleep(0.8)
    launch('client','one');launch('client','two');launch('reconnect','three')
    time.sleep(4)
    launch('overflow','overflow')
    failed=[]
    for p,f,name in processes:
        code=p.wait(timeout=35);f.close()
        text=(logs/f'network-{name}.log').read_text()
        print(name,code,text)
        if code or 'ERROR:' in text: failed.append(name)
    launch('host','objects-host','net_objects');time.sleep(0.7)
    launch('client','objects-client','net_objects')
    for p,f,name in processes[-2:]:
        code=p.wait(timeout=20);f.close()
        text=(logs/f'network-{name}.log').read_text()
        print(name,code,text)
        if code or 'ERROR:' in text: failed.append(name)
    if failed: raise SystemExit('Network failures: '+', '.join(failed))
finally:
    for p,f,_ in processes:
        if p.poll() is None: p.kill();p.wait()
        f.close()
