"""Integrity and aggregate regression checks; uses only the Python standard library."""
from pathlib import Path
import ast
import csv
import hashlib
import json
import math

ROOT=Path(__file__).resolve().parents[1]
def rows(name):
    with (ROOT/'public_data'/name).open(encoding='utf8',newline='') as f:return list(csv.DictReader(f))

def main():
    manifest=json.loads((ROOT/'public_data/manifest.json').read_text('utf8'))
    forbidden={'seqn','hhidpn','id','hhid','mergeid','participant_id','email','address','name'}
    assert {p.name for p in (ROOT/'public_data').glob('*.csv')}=={r['file'] for r in manifest}
    for entry in manifest:
        p=ROOT/'public_data'/entry['file'];data=rows(entry['file'])
        assert hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256']
        assert len(data)==entry['rows']
        assert not forbidden.intersection(c.lower() for c in entry['columns'])
        assert all(list(r)==entry['columns'] for r in data)
    perf=rows('component_cv_performance.csv')
    assert len(perf)==80 and all(math.isfinite(float(r['value'])) for r in perf)
    for r in perf:
        assert int(r['folds'])==10
        if r['metric']=='CV AUC':assert 0<=float(r['value'])<=1
    for r in rows('bridge_pooled.csv'):
        assert int(r['n'])==11731 and int(r['imputations'])==5
        assert float(r['conf_low'])<float(r['r'])<float(r['conf_high'])
    for r in rows('spline_tests.csv'):
        if r['dataset']=='NHANES':assert float(r['p_nonlinear'])>.05
    for r in rows('weight_coverage_audit.csv'):
        assert int(r['harmonized_weight_positive'])==int(r['body_composition'])
    for r in rows('threshold_performance.csv'):
        for col in ('auc','sensitivity','specificity','ppv','npv'):assert 0<=float(r[col])<=1
        if r['strategy']=='Sensitivity >=90%':assert float(r['sensitivity'])>=.9
    context=rows('context_clustered_associations.csv')
    assert len(context)==48 and {r['dataset'] for r in context}=={'HRS','CHARLS','SHARE'}
    for r in context:
        assert 0<int(r['participants'])<=int(r['n']) and 0<int(r['events'])<int(r['n'])
        assert float(r['conf_low'])<float(r['estimate'])<float(r['conf_high'])
    counts=rows('study_design_sample_counts.csv')
    assert len(counts)==38 and all(int(r['n'])>0 for r in counts)
    def count(dataset,sample,measure):
        found=[int(r['n']) for r in counts if (r['dataset'],r['sample'],r['measure'])==(dataset,sample,measure)]
        assert len(found)==1
        return found[0]
    assert count('Chinese BIA','Discovery','records')==152449
    assert count('NHANES','Paired components','paired_participants')==11731
    for r in rows('sample_flow.csv'):
        assert count(r['dataset'],'DXA bone health','eligible_participants')==int(r['eligible'])
        assert count(r['dataset'],r['outcome'],'complete_case_participants')==int(r['complete_cases'])
    checked=0
    for r in context:
        if r['weighted']=='FALSE' and r['contrast']=='Per 10-year age increase' and not (r['dataset']=='CHARLS' and r['scope']!='2011-2020'):
            assert count(r['dataset'],r['outcome'],'complete_case_person_waves')==int(r['n'])
            assert count(r['dataset'],r['outcome'],'complete_case_unique_participants')==int(r['participants'])
            assert int(r['n'])<=count(r['dataset'],'Clinical context','eligible_person_waves')
            assert int(r['participants'])<=count(r['dataset'],'Clinical context','eligible_unique_participants')
            checked+=1
    assert checked==9
    for p in (ROOT/'code').rglob('*.py'):ast.parse(p.read_text('utf8'))
    for line in (ROOT/'SHA256SUMS').read_text('utf8').splitlines():
        digest,name=line.split('  ',1);p=(ROOT/name).resolve()
        assert p.is_relative_to(ROOT.resolve()) and hashlib.sha256(p.read_bytes()).hexdigest()==digest
    print(f'PASS: {len(manifest)} aggregate tables; hashes, schemas, sample counts and numerical regression checks.')
if __name__=='__main__':main()
