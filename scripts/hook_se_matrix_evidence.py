#!/usr/bin/env python3
"""Generate docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json from a forge -vv matrix log (M12).

Usage:
  forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*_SeMatrix_*.t.sol' -vv > <log>
  python3 scripts/hook_se_matrix_evidence.py <log> docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json \
      docs/audits/apex-2026-09-17-evidence/hook-se-matrix-findings.json \
      docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json

States: DEPRECATED (test_DEPRECATED_*, an SE the owner retired: D57 Slipstream), DEFERRED (test_DEFERRED_*), INCOMPATIBLE (test_INCOMPATIBLE_*), BLOCKED (row listed in the findings map with
blockedTests), COMPATIBLE (all ten test_row_* pass), FAILING (a row test failed). Findings without blockedTests keep the
row COMPATIBLE and add `findings`.
"""
import re, json, sys, collections, glob, os

REQUIRED_ROW_TESTS = {
    'test_row_ammCallerFundSeparation',
    'test_row_bind_deploysThroughPackage',
    'test_row_bufferFirst_restingFace_notPaidToJoiner',
    'test_row_hookSwap_exactIn_eoaPretransferRejected',
    'test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly',
    'test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed',
    'test_row_partialConsumption_bookedNotRefunded',
    'test_row_poolManagerSwap_bothDirections_noFaceResidual',
    'test_row_previewMatchesExecution',
    'test_row_seFailure_rollsBack',
}
log_path = sys.argv[1]; out_path = sys.argv[2]; log_name = os.path.basename(log_path)
lines = open(log_path).read().split('\n')
suite=None; path=None; res=collections.OrderedDict()
for line in lines:
    m=re.match(r'Ran \d+ tests? for (\S+):(\S+)',line)
    if m: path, suite = m.group(1), m.group(2); res[suite]={'path':path,'pass':[],'fail':[]}; continue
    m=re.match(r'\[(PASS|FAIL)(?:: (.*?))?\] (\w+)\(\)',line)
    if m and suite:
        (res[suite]['pass'] if m.group(1)=='PASS' else res[suite]['fail']).append((m.group(3), m.group(2) or ''))
    # A9 / A10: behaviors emit `matrix.se<i>` and `matrix.faceDecimals<i>` in setUp (log_named_*).
    m=re.match(r'\s*matrix\.(se|faceDecimals)(\d+): (\S+)',line)
    if m and suite:
        legs=res[suite].setdefault('legs',{}); leg=legs.setdefault(int(m.group(2)),{})
        leg['se' if m.group(1)=='se' else 'faceDecimals']=(m.group(3) if m.group(1)=='se' else int(m.group(3)))
    if line.startswith('Suite result'): suite=None
hooks = {'orbital':'orbital','weighted':'weighted','stable/quad/curve':'curve-quad','stable/quad/balancer':'balancer-quad','constantProduct/single':'single-cp','dual':'dual','single':'single-noncp'}
findings = json.load(open(sys.argv[3])) if len(sys.argv)>3 else {}
descriptions = json.load(open(sys.argv[4])) if len(sys.argv)>4 else {}
rows=[]
for suite,r in res.items():
    if '_SeMatrix_' not in suite: continue
    prefix, family = suite.split('_SeMatrix_',1)
    combo=None
    mm=re.match(r'(.+)_F(\d+)$', family)   # M14 decimal row: <SeFamily>_F<faceDecimals>
    if mm: family, combo = mm.group(1), 'F'+mm.group(2)
    p=r['path']; hookdir = None
    for k in sorted(hooks, key=len, reverse=True):
        if '/standardExchange/'+k+'/' in p: hookdir=k; break
    tests=[t for t,_ in r['pass']]+[t for t,_ in r['fail']]
    state='COMPATIBLE'; error=None
    if any(t.startswith('test_DEPRECATED_') for t in tests):
        state='DEPRECATED'; t=[t for t in tests if t.startswith('test_DEPRECATED_')][0]; error=t.split('_')[-1]
    elif any(t.startswith('test_DEFERRED_') for t in tests): state='DEFERRED'
    elif any(t.startswith('test_INCOMPATIBLE_') for t in tests):
        state='INCOMPATIBLE'; t=[t for t in tests if t.startswith('test_INCOMPATIBLE_')][0]; error=t.split('_')[-1]
    elif any(t.startswith('test_BLOCKED_') for t in tests): state='BLOCKED'; error=[t for t in tests if t.startswith('test_BLOCKED_')][0].split('_')[-1]
    rowtests=[t for t in tests if t.startswith('test_row_')]
    row={'hook':hooks.get(hookdir,hookdir),'seFamily':family,'suite':suite,'file':p,'state':state,
         'tests':sorted(tests),'passed':len(r['pass']),'failed':len(r['fail']),
         'failures':[{'test':t,'error':e} for t,e in r['fail']],'log':log_name}
    if combo: row['combo']=combo; row['faceDecimals']=int(combo[1:])
    if r.get('legs'): row['legs']=[r['legs'][k] for k in sorted(r['legs'])]
    if error: row['error']=error
    # A failed named rejection or retirement control is not evidence of incompatibility.
    if r['fail']: row['state']='FAILING'
    elif state=='COMPATIBLE' and not REQUIRED_ROW_TESTS.issubset(rowtests):
        row['state']='INCOMPLETE'
        row['missingTests']=sorted(REQUIRED_ROW_TESTS.difference(rowtests))
    key=f"{row['hook']}:{family}"
    if key in findings:
        f=findings[key]
        if f.get('blockedTests') and row['state']=='COMPATIBLE':
            row['state']='BLOCKED'; row['blockedTests']=f['blockedTests']
        row['findings']=f['findings']
    rows.append(row)
rows.sort(key=lambda x:(x['hook'],x['seFamily']))
summary=collections.Counter(r['state'] for r in rows)
out={'generatedFrom':log_name,'rowCount':len(rows),'summary':dict(summary),'rows':rows}
expected = set()
for source in glob.glob('test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*_SeMatrix_*.t.sol', recursive=True):
    with open(source) as contract_file:
        expected.update(re.findall(r'\bcontract\s+(\w+_SeMatrix_\w+)', contract_file.read()))
executed = {row['suite'] for row in rows}
out['expectedRowCount'] = len(expected)
out['missingSuites'] = sorted(expected - executed)
out['unexpectedSuites'] = sorted(executed - expected)
if descriptions: out['findings']=descriptions
out['note']=("D69: all planned hook/SE combinations require executed evidence. COMPATIBLE requires all ten named controls; "
 "INCOMPATIBLE requires a passing named production rejection; DEPRECATED records an owner-retired SE (D57 Slipstream). "
 "Any failed control is FAILING regardless of its name. INCOMPLETE, DEFERRED, BLOCKED and FAILING prevent closure.")
json.dump(out,open(out_path,'w'),indent=1); open(out_path,'a').write('\n')
print(json.dumps(dict(summary)), len(rows))
if (not rows or not expected or out['missingSuites'] or out['unexpectedSuites']
        or any(r['state'] not in ('COMPATIBLE', 'INCOMPATIBLE', 'DEPRECATED') for r in rows)):
    sys.exit(1)
