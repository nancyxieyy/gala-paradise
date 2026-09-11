#!/usr/bin/env python3
"""Frozen 1.7.1 experiment; run.py first runs A-I and builds both engines."""
import run as sim
import json, collections, itertools
from pathlib import Path
ROOT=sim.ROOT
config=json.loads((ROOT/'Tests/Simulation/readable-experiment.json').read_text())
def metrics(output,scenario):
    world=output['world'];events=output['eventLog'];last={};reversals=0;locations=set();residents={};ever=set();empty=set();recolonizations=0
    for index,c in enumerate(scenario['creatures']):
        ident=c.get('id',f'00000000-0000-4000-8000-{index+1:012x}')
        residents[ident]=(c.get('stage','adult'),c['location']);locations.add(c['location'])
    def occupied():return {loc for stage,loc in residents.values() if stage in ('adult','baby','gold')}
    ever|=occupied();extinctions=0;was_alive=bool(occupied())
    for timestamp,group in itertools.groupby(events,key=lambda e:e['timestamp']):
        for e in group:
            ident=e['entity'];trigger=e['trigger']
            if trigger=='migration':
                previous=last.get(ident)
                if previous and e['new']==previous['previous'] and timestamp-previous['timestamp']<=config['reversalWindow']:reversals+=1
                last[ident]=e;locations.update([e['previous'],e['new']])
                if ident in residents:residents[ident]=(residents[ident][0],e['new'])
            elif trigger=='created':residents[ident]=(e['new'],e['location'])
            elif trigger=='incubation':residents.pop(ident,None)
            elif e['new']=='corpse' and ident in residents:residents[ident]=('corpse',e['location'])
            elif trigger=='maturation':residents[ident]=(e['new'],e['location'])
        current=occupied();recolonizations+=len(current&empty);empty-=current;empty|=ever-current;ever|=current
        if was_alive and not current:extinctions+=1
        was_alive=bool(current)
    migrations=world['migrations'];assert reversals==world['reversals']
    distribution=collections.Counter(c['location'] for c in world['creatures'] if c['stage'] in ('adult','baby','gold'))
    shocks=[a for a in scenario['actions'] if a['kind']=='chemical']
    shock_departures=sum(e['trigger']=='migration' and any(a['at']<e['timestamp']<=a['at']+120 and e['previous']==a['location'] for a in shocks) for e in events)
    return dict(migrations=migrations,reversals=reversals,reversalRate=reversals/migrations if migrations else 0,uniqueHabitats=len(locations),chemicalMigrations=world['chemicalMigrations'],shockDepartures=shock_departures,populationDistribution=dict(distribution),population=sum(distribution.values()),nests=sum(h['nest'] for h in world['habitats']),births=world['births'],deaths=world['deaths'],extinctions=extinctions,recolonizations=recolonizations)
rows=[]
for name in config['scenarios']:
    base=json.loads((ROOT/'Tests/Simulation/scenarios'/f'{name}.json').read_text())
    for seed in config['seeds']:
        for mode in config['modes']:
            scenario=dict(base,seed=seed,migrationMode=mode)
            tag=f'{name}-{seed}-{mode}'
            a=sim.run('swift',scenario,tag);b=sim.run('cs',scenario,tag)
            for key in ('world','eventLog','samples'):sim.equal(a[key],b[key])
            m=metrics(a,scenario);rows.append(dict(scenario=name,seed=seed,mode=mode,**m))
            if name=='F-two-hours' and seed==42 and mode=='control':assert m['migrations']==251 and m['deaths']==20
f=[r for r in rows if r['scenario']=='F-two-hours'];pooled={mode:sum(r['reversals'] for r in f if r['mode']==mode)/sum(r['migrations'] for r in f if r['mode']==mode) for mode in config['modes']}
reduction=1-pooled['treatment']/pooled['control'] if pooled['control'] else 0
directions=sum(next(r for r in f if r['seed']==seed and r['mode']=='treatment')['reversalRate']<next(r for r in f if r['seed']==seed and r['mode']=='control')['reversalRate'] for seed in config['seeds'])
report=dict(config=config,rows=rows,pooledF=pooled,reduction=reduction,improvedSeeds=directions,primary='PASS' if reduction>=.4 and directions>=3 else 'FAIL')
(ROOT/'Docs/readable-emergence-v1.7.1-evidence.json').write_text(json.dumps(report,indent=2)+'\n')
i=sim.results['I-recovery'];timeline=dict(samples=i['samples'],events=[e for e in i['eventLog'] if e['trigger'] in ('incubation','created','migration','formation','manual defeat','dose','maturation')]);(ROOT/'Docs/readable-recovery-timeline.json').write_text(json.dumps(timeline,indent=2)+'\n')
print('F PRIMARY:',report['primary'],'reduction',reduction,'directions',directions,'/5')

# Keep the frozen guardrail evaluator and published evidence in sync.
import subprocess
subprocess.run(['python3',str(ROOT/'Tests/Simulation/readable-guardrails.py')],check=True,cwd=ROOT)
