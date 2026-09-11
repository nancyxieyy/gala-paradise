#!/usr/bin/env python3
"""Evaluate the pre-registered guardrails from retained experiment outputs."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=ROOT/'Docs/readable-emergence-v1.7.1-evidence.json';report=json.loads(p.read_text());rows=report['rows']
guards={}
for name in ['F-two-hours','C-chemical']:
 r=[r for r in rows if r['scenario']==name];t=[r for r in r if r['mode']=='treatment'];c=[r for r in r if r['mode']=='control']
 guards[name]=dict(diversitySeeds=sum(x['uniqueHabitats']>=2 for x in t),nestSeeds=sum(x['nests']>0 for x in t),populationRatio=sum(x['population'] for x in t)/sum(x['population'] for x in c))
 guards[name]['pass']=guards[name]['diversitySeeds']>=4 and guards[name]['nestSeeds']>=4 and guards[name]['populationRatio']>=.5
h=[r for r in rows if r['scenario']=='H-oscillation' and r['mode']=='treatment'];guards['HShock']=all(r['shockDepartures']>0 for r in h)
chains=[]
for seed in report['config']['seeds']:
 o=json.loads((ROOT/f'build/simulation/C-chemical-{seed}-treatment-swift.json').read_text());es=o['eventLog']
 # Require actual child lineage at hatch, a subsequent return, then a nest at the original source.
 stages={};parents={};matched=[]
 for e in es:
  if e['trigger']=='incubation':parents[e['location']]=(e['entity'],e['timestamp'])
  if e['trigger']=='created' and e['new']=='baby':
   parent=parents.get(e['location'])
   if parent and parent[1]==e['timestamp']:stages[e['entity']]=e
 for e in es:
  if e['trigger']=='migration' and e['previous']=='Archive' and e['new']=='Downloads' and e['entity'] in stages:
   hatch=stages[e['entity']]
   prior_nest=next((x for x in es if x['trigger']=='formation' and x['location']=='Archive' and 10<x['timestamp']<hatch['timestamp']),None)
   prior_move=next((x for x in es if x['trigger']=='migration' and x['previous']=='Downloads' and x['new']=='Archive' and 10<x['timestamp']<(prior_nest or {}).get('timestamp',0)),None)
   later_nest=next((x for x in es if x['trigger']=='formation' and x['location']=='Downloads' and x['timestamp']>e['timestamp']),None)
   if prior_move and prior_nest and later_nest:matched=[prior_move,prior_nest,hatch,e,later_nest];break

 chains.append(dict(seed=seed,complete=bool(matched),events=matched))
guards['CCompleteChainSeeds']=sum(x['complete'] for x in chains)
guards['pass']=guards['F-two-hours']['pass'] and guards['C-chemical']['pass'] and guards['HShock'] and guards['CCompleteChainSeeds']>=1
report['guardrails']=guards;report['chains']=chains
report['HDiscriminatesOscillation']=any(r['reversals']>0 for r in rows if r['scenario']=='H-oscillation' and r['mode']=='control')
report['stability']='PASS' if report['primary']=='PASS' and guards['pass'] and report['HDiscriminatesOscillation'] else 'PARTIAL' if guards['pass'] else 'FAIL'
p.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['primary','guardrails','HDiscriminatesOscillation','stability']},indent=2))
