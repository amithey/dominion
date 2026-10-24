"""Rebuild the evidence ledger without treating an asset's existence as proof of service.

Only this tools directory receives output. Never alters national game data.
Run from the repository root with the project's Python runtime.
"""
from pathlib import Path
import collections,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).parent
sys.path.insert(0,str(HERE.parent))
from vehicle_parts import read_glb
ART=ROOT/'native/godot/assets/art'

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    roster_path=ROOT/'native/CODEX-UNIT-ROSTER.json';roster=read(roster_path)
    manifest=read(ART/'MANIFEST.json');by={e['file']:e for e in manifest}
    evidence=read(HERE/'evidence.json') if (HERE/'evidence.json').exists() else {'sources':{},'findings':[],'additional_inventory':[]}
    sources=evidence['sources'];findings=evidence['findings'];overrides={}
    for f in findings:
        assert f['nation'] and f['key'] and f['roster_slug'] and f['source_ids'] and f['assessment']
        assert all(s in sources for s in f['source_ids']),f
        index=(f['nation'],f['key'],f['roster_slug']);assert index not in overrides,index
        overrides[index]=f
    nations=collections.defaultdict(list);resolved={};missing=[]
    for item in evidence['additional_inventory']:
        slug=item.get('proposed_slug');paths=[f'{folder}/{slug}.glb' for folder in ('vehicles','aircraft','ships')] if slug else []
        item['existing_exact_asset']=next((name for name in paths if (ART/name).exists()),None)
        item['asset_state']='available_exact_file' if item['existing_exact_asset'] else 'not_yet_created_or_unresolved'
    for row in roster:
        folder='ships' if row['priority']=='P7' else 'aircraft' if row['priority'] in ('P5','P6') else 'vehicles'
        slug=row['slug'];candidate=slug;entry=None
        while True:
            name=f'{folder}/{candidate}.glb'
            if (ART/name).exists():entry=by.get(name);break
            tail=candidate.split('__',1)[1]
            if '_' not in tail:break
            candidate=candidate.rsplit('_',1)[0]
        if entry:
            if name not in resolved:
                doc,_=read_glb(ART/name);extra=doc.get('extras',{});spec=extra.get('spec',{})
                resolved[name]={'file':name,'sha256':hashlib.sha256((ART/name).read_bytes()).hexdigest(),
                    'exact_slug':candidate==slug,'declared_vehicle':extra.get('vehicle'),
                    'declared_name':spec.get('name',entry.get('name')),
                    'approximate':spec.get('approximate',entry.get('approximate')),
                    'representative':spec.get('representative',entry.get('representative_vehicle',entry.get('representative',''))),
                    'features':spec.get('features',entry.get('recognition_features',entry.get('features',[]))),
                    'materials':entry.get('materials',[]),'triangles':entry.get('triangles')}
            asset={**resolved[name],'exact_slug':candidate==slug}
        else:
            asset={'file':None,'exact_slug':False};missing.append(slug)
        for nation in row['nations']:
            f=overrides.pop((nation,row['key'],slug),None)
            nations[nation].append({'key':row['key'],'roster_model':row['model'],'roster_slug':slug,
                'asset':asset,'evidence_status':'reviewed' if f else 'pending',
                'evidence_source_ids':f['source_ids'] if f else [],
                'assessment':f['assessment'] if f else {'status':'unverified','reason':'No newly checked model-specific operator evidence yet.'}})
    assert not overrides,('finding does not match roster',list(overrides))
    (HERE/'countries').mkdir(exist_ok=True)
    for nation,rows in sorted(nations.items()):
        additional=[x for x in evidence['additional_inventory'] if x['nation']==nation]
        write(HERE/'countries'/f'{nation}.json',{'nation':nation,'scope':'current and confirmed-order platforms in existing Tier 7 categories',
            'all_roster_rows_assessed':all(r['evidence_status']=='reviewed' for r in rows),
            'complete':False,'completion_note':'Operator evidence, exact visual fit and additional inventory still being audited.',
            'rows':rows,'additional_inventory':additional})
    summary={'scope':'National operator and model-identity audit; current equipment and confirmed orders in existing Tier 7 categories',
        'as_of':'2026-10-24','roster_sha256':hashlib.sha256(roster_path.read_bytes()).hexdigest(),
        'nations':len(nations),'roster_rows':len(roster),'nation_model_assignments':sum(map(len,nations.values())),
        'reviewed_assignments':len(findings),'pending_assignments':sum(map(len,nations.values()))-len(findings),
        'all_roster_rows_assessed':all(r['evidence_status']=='reviewed' for rows in nations.values() for r in rows),
        'complete':False,
        'completion_note':'Row assessment coverage does not certify current service, resolve open variant questions, or complete additional-platform geometry review.',
        'unresolved_asset_slugs':sorted(set(missing)),'checked_sources':len(sources),
        'country_progress':{n:{'reviewed':sum(r['evidence_status']=='reviewed' for r in rows),'total':len(rows)} for n,rows in sorted(nations.items())}}
    write(HERE/'progress.json',summary)
    md=['# National inventory audit — evidence ledger\n',
        'Work in progress. Current equipment **and confirmed orders** are in scope. A reviewed row may still contain an unresolved question; it is not a blanket certification of current service or model accuracy.\n',
        f"Coverage: {len(findings)} of {summary['nation_model_assignments']} nation–model assignments assessed; {len(sources)} source records. No absent-source claim establishes non-possession.\n"]
    for nation,rows in sorted(nations.items()):
        reviewed=[r for r in rows if r['evidence_status']=='reviewed']
        md += [f'\n## {nation}\n',f'Assessed {len(reviewed)}/{len(rows)} roster assignments. Full asset metadata: [country ledger](countries/{nation}.json).\n']
        if reviewed:
            md += ['| Role / roster model | Assessment and next action | Sources |\n','|---|---|---|\n']
            for r in reviewed:
                a=r['assessment'];links=', '.join(f"[{sid}]({sources[sid]['url']})" for sid in r['evidence_source_ids'])
                md += [f"| `{r['key']}` — {r['roster_model']} | **{a['status']}**. {a['reason']} Next: `{a['recommended_action']}`. | {links} |\n"]
        for a in [x for x in evidence['additional_inventory'] if x['nation']==nation]:
            links=', '.join(f"[{sid}]({sources[sid]['url']})" for sid in a['source_ids'])
            md += [f"\nAdditional: **{a['model']}** (`{a['status']}`), `{a['asset_action']}`. {a['reason']} Sources: {links}.\n"]
    (HERE/'FINDINGS.md').write_text(''.join(md),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=True),flush=True)

if __name__=='__main__':main()
