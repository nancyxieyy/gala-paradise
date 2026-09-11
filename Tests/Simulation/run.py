#!/usr/bin/env python3
"""Build both headless engines, check deterministic ecology, and retain raw evidence."""
import json, math, pathlib, subprocess, os, shutil
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'build/simulation'; OUT.mkdir(parents=True,exist_ok=True)
DOTNET=os.environ.get('GALA_DOTNET') or shutil.which('dotnet') or str(ROOT/'build/toolchain/dotnet/dotnet')
def command(args):subprocess.run(args,cwd=ROOT,check=True)
command(['swiftc','-O','Sources/World.swift','Tests/Simulation/main.swift','-o','build/world-sim'])
command([DOTNET,'build','Tests/Simulation','-c','Release'])
def run(engine,scenario,name):
 p=OUT/(name+'-input.json');p.write_text(json.dumps(scenario))
 o=OUT/(name+'-'+engine+'.json');cmd=['build/world-sim'] if engine=='swift' else [DOTNET,'Tests/Simulation/bin/Release/net10.0/Simulation.dll']
 command(cmd+[str(p),str(o)]);return json.loads(o.read_text())
def equal(a,b,path=''):
 if isinstance(a,(int,float)) and isinstance(b,(int,float)):assert math.isclose(a,b,rel_tol=1e-10,abs_tol=1e-10),path
 elif isinstance(a,dict):
  assert a.keys()==b.keys(),(path,a.keys()^b.keys())
  for k in a:equal(a[k],b[k],path+'/'+k)
 elif isinstance(a,list):
  assert len(a)==len(b),(path,len(a),len(b))
  for i,(x,y) in enumerate(zip(a,b)):equal(x,y,path+f'/{i}')
 else:
  # Runtime number formatting in explanatory log strings is not simulation state.
  try:assert math.isclose(float(a),float(b),rel_tol=1e-10,abs_tol=1e-10),path
  except (TypeError,ValueError):assert a==b,(path,a,b)
results={}
for f in sorted((ROOT/'Tests/Simulation/scenarios').glob('*.json')):
 scenario=json.loads(f.read_text());a=run('swift',scenario,f.stem);b=run('cs',scenario,f.stem)
 equal(a['world'],b['world']);equal(a['eventLog'],b['eventLog']);equal(a['samples'],b['samples'])
 again=run('swift',scenario,f.stem+'-repeat');equal(a['world'],again['world']);equal(a['eventLog'],again['eventLog'])
 results[f.stem]=a
 print('PASS full state/event parity and replay:',f.stem)
a=results['A-frequent'];assert sum(e['trigger']=='migration' and e['previous']=='Downloads' and e['timestamp']<=120 for e in a['eventLog'])>=4
b=results['B-abandoned'];assert any(e['location']=='Archive' and e['trigger']=='formation' for e in b['eventLog'])
c=results['C-chemical'];assert c['metrics']['deaths']>0 and c['metrics']['migrations']>0 and c['metrics']['population']>0
d=results['D-eggs'];assert d['metrics']['deaths']>=6 and any(e['trigger']=='incubation' for e in d['eventLog']) and d['metrics']['population']>0
e=results['E-personality'];first=[x['new'] for x in e['eventLog'] if x['trigger']=='utility' and x['timestamp']==2];assert len(set(first))>=2,first
# Save-resume at an exact simulation tick; no offline catch-up.
s=json.loads((ROOT/'Tests/Simulation/scenarios/F-two-hours.json').read_text());half=dict(s,duration=3600)
first=run('swift',half,'resume-first');second=dict(s,initial=first['world'],duration=3600)
second['actions']=[dict(a,at=(a['at']-3600)%a['every']) for a in s['actions'] if a.get('every',0)>0]
resumed=run('cs',second,'resume-second');equal(results['F-two-hours']['world'],resumed['world'])
# Causal control: after complete adult loss, no eggs means no unexplained comeback.
control=json.loads((ROOT/'Tests/Simulation/scenarios/D-eggs.json').read_text());control['creatures']=[x for x in control['creatures'] if x.get('stage')!='egg']
zero=run('swift',control,'D-no-eggs');assert zero['metrics']['population']==0
# Fresh empty world + elapsed time cannot unlock visitors or generate a survivor.
empty=dict(control,creatures=[],actions=[],duration=7200);zero=run('swift',empty,'empty');assert zero['metrics']['population']==0 and not any(x['rule']=='visitors' for x in zero['eventLog'])
(OUT/'summary.json').write_text(json.dumps({k:v['metrics'] for k,v in results.items()},indent=2))
print('PASS A-E hypotheses, no-egg control, empty-world control, cross-language save/resume')
