"""Integrity and aggregate regression checks; uses only the Python standard library."""
from pathlib import Path
import ast
import csv
import hashlib
import json
import math
import statistics
from collections import defaultdict

ROOT=Path(__file__).resolve().parents[1]
def rows(name):
    with (ROOT/'public_data'/name).open(encoding='utf8',newline='') as f:return list(csv.DictReader(f))

def quantile(values, probability):
    values=sorted(values)
    index=(len(values)-1)*probability
    low=math.floor(index)
    high=math.ceil(index)
    return values[low]+(values[high]-values[low])*(index-low)

def close(a,b):
    assert math.isclose(float(a),float(b),rel_tol=1e-9,abs_tol=1e-11),(a,b)

def check_validation(performance):
    key=lambda r:(r['dataset'],r['outcome'],r['model'])
    original={key(r):float(r['value']) for r in performance}
    repeated=rows('validation_repeated_cv.csv')
    bootstrap=rows('validation_refit_bootstrap.csv')
    summary=rows('validation_performance_summary.csv')
    differences=rows('validation_paired_differences.csv')
    assert (len(repeated),len(bootstrap),len(summary),len(differences))==(8000,80000,80,70)
    rep,boot=defaultdict(dict),defaultdict(dict)
    for r in repeated:
        i=int(r['repeat_id'])
        assert int(r['seed'])==20261010+i and i not in rep[key(r)]
        rep[key(r)][i]=float(r['value'])
    for r in bootstrap:
        i=int(r['bootstrap_id'])
        assert i not in boot[key(r)]
        boot[key(r)][i]=float(r['value'])
    assert set(rep)==set(boot)==set(original)
    for r in summary:
        k=key(r)
        assert set(rep[k])==set(range(1,101)) and set(boot[k])==set(range(1,1001))
        rv,bv=list(rep[k].values()),list(boot[k].values())
        close(r['original'],original[k])
        close(r['repeated_mean'],statistics.mean(rv))
        close(r['repeated_sd'],statistics.stdev(rv))
        close(r['split_p025'],quantile(rv,.025))
        close(r['split_p975'],quantile(rv,.975))
        close(r['refit_basic_low'],2*original[k]-quantile(bv,.975))
        close(r['refit_basic_high'],2*original[k]-quantile(bv,.025))
        close(r['refit_percentile_low'],quantile(bv,.025))
        close(r['refit_percentile_high'],quantile(bv,.975))
    for r in differences:
        k=(r['dataset'],r['outcome'],r['comparator'])
        ref=(r['dataset'],r['outcome'],'mbr')
        assert r['reference']=='mbr' and int(r['repetitions'])==100 and int(r['bootstrap_replicates'])==1000
        delta=original[k]-original[ref]
        rv=[rep[k][i]-rep[ref][i] for i in range(1,101)]
        bv=[boot[k][i]-boot[ref][i] for i in range(1,1001)]
        close(r['delta'],delta)
        close(r['repeated_mean_delta'],statistics.mean(rv))
        close(r['repeated_sd_delta'],statistics.stdev(rv))
        close(r['split_delta_p025'],quantile(rv,.025))
        close(r['split_delta_p975'],quantile(rv,.975))
        close(r['refit_basic_low'],2*delta-quantile(bv,.975))
        close(r['refit_basic_high'],2*delta-quantile(bv,.025))
        close(r['refit_percentile_low'],quantile(bv,.025))
        close(r['refit_percentile_high'],quantile(bv,.975))
        assert int(r['positive_repeats'])==sum(x>0 for x in rv)
        assert int(r['negative_repeats'])==sum(x<0 for x in rv)
        assert int(r['tied_repeats'])==sum(x==0 for x in rv)

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
    check_validation(perf)
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
