#!/usr/bin/env python3
"""R12: compare compiled artifacts against the APEX selector/size baseline.

Usage:
  python3 scripts/r12_selector_size_compare.py [--rebaseline NAME ...] [--classify NAME=TEXT ...] [--note TEXT]

Reads docs/audits/apex-2026-09-17-evidence/initial-artifact-selectors-sizes.json, loads every listed artifact
plus new concrete deployment units beside those sources, and writes a new dated comparison with:
compared, missingArtifacts, oversizeCount (> 24576
runtime bytes), selectorDiffs (added / removed method identifiers vs the baseline), proxySelectorDiffCount
(selector diffs on facets, whose facetFuncs() define diamond proxy selector sets) and a note.
--rebaseline writes a separate revised baseline copy beside the output, preserving the original.
Every existing-artifact diff must carry a classification (carried over from the previous compare
by artifact path, or supplied with --classify). --manifest PATH --test-log LOG captures current
source/artifact/log hashes without claiming a historical log ran this current source tree.
Missing or oversized artifacts cause a nonzero exit after the comparison is written.
"""
import argparse, datetime, hashlib, json, os, re, subprocess, sys
from pathlib import Path
E = 'docs/audits/apex-2026-09-17-evidence/'
BASE = E + 'initial-artifact-selectors-sizes.json'
OUT = E + 'selector-size-compare.json'
EIP170 = 24576

def load_artifact(path):
    if not os.path.isfile(path):
        return None
    a = json.load(open(path))
    rt = a.get('deployedBytecode', {}).get('object', '') or ''
    hexbody = rt[2:] if rt.startswith('0x') else rt
    return {'runtimeBytes': len(hexbody) // 2, 'sha256': hashlib.sha256(hexbody.encode()).hexdigest(),
            'methodIdentifiers': a.get('methodIdentifiers', {}) or {},
            'artifactSha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()}

def discover_artifacts(base):
    """Discover concrete deployment units beside the in-scope baseline sources.

    The source tree, rather than out/, is authoritative: deleted source cannot be
    resurrected by stale artifacts, and a newly added facet without an artifact
    is a missing-artifact failure. Abstract targets and test fixtures are excluded.
    """
    known = {r['artifact'] for r in base}
    parents = {Path(r['source']).parent for r in base}
    candidates = []
    declaration = re.compile(r'\b(abstract\s+)?contract\s+(\w+)\b')
    for parent in sorted(parents):
        for source in sorted(parent.glob('*.sol')):
            if source.name.startswith(('Test', 'Mock', 'Handler')):
                continue
            # Strip comments so examples and disabled declarations are not units.
            body = re.sub(r'/\*.*?\*/|//[^\n]*', '', source.read_text(), flags=re.S)
            for abstract, name in declaration.findall(body):
                if abstract or not (
                    re.search(r'(Facet(?:Ext)?|DFPkg|Delegate|StandardVaultPkg)$', name)
                    or name == 'BalancerV3SinglePoolStandardExchange'
                ):
                    continue
                artifact = f'out/{source.name}/{name}.json'
                if artifact not in known:
                    candidates.append({'source': str(source), 'artifact': artifact})
                    known.add(artifact)
    return candidates

def sha256_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write_manifest(path, rows, log_paths, result_path):
    """Capture the current tree; never imply a past log proves this tree ran."""
    def git(*args):
        return subprocess.check_output(['git', *args], text=True).strip()
    # Include test/tool sources and both tracked and untracked production sources.
    sources = set()
    for root in ('contracts', 'test/foundry', 'scripts', 'lib/crane/contracts'):
        sources.update(p for p in Path(root).rglob('*') if p.is_file() and p.suffix in ('.sol', '.py', '.sh'))
    sources.add(Path('foundry.toml'))
    artifacts = {r['artifact']: sha256_file(r['artifact']) for r in rows if Path(r['artifact']).is_file()}
    manifest = {
        'capturedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'indexedexRevision': git('rev-parse', 'HEAD'),
        'craneRevision': git('-C', 'lib/crane', 'rev-parse', 'HEAD'),
        'workingTreeStatus': git('status', '--porcelain'),
        'craneWorkingTreeStatus': git('-C', 'lib/crane', 'status', '--porcelain'),
        'identityScope': 'Current on-disk source and artifact identity captured after the supplied logs. '
                         'Log hashes bind these files into one evidence bundle; they do not establish '
                         'that these sources or artifacts produced an earlier log, or that artifacts are fresh.',
        'sourceSha256': {str(p): sha256_file(p) for p in sorted(sources)},
        'artifactSha256': artifacts,
        'logSha256': {str(p): sha256_file(p) for p in log_paths},
        'comparisonSha256': {str(result_path): sha256_file(result_path)},
    }
    with open(path, 'x') as output:
        json.dump(manifest, output, indent=2)
        output.write('\n')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rebaseline', nargs='*', default=[])
    ap.add_argument('--classify', nargs='*', default=[])
    ap.add_argument('--note', default=None)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    ap.add_argument('--output', default=E + f'selector-size-compare-{stamp}.json', help='New comparison output path')
    ap.add_argument('--manifest', help='New identity-manifest path (refuses to overwrite)')
    ap.add_argument('--test-log', action='append', default=[], help='Existing local log to hash in --manifest; repeatable')
    args = ap.parse_args()
    if args.test_log and not args.manifest:
        ap.error('--test-log requires --manifest')
    for path in args.test_log:
        if not Path(path).is_file():
            ap.error(f'log does not exist: {path}')
    if args.manifest and Path(args.manifest).exists():
        ap.error(f'manifest already exists: {args.manifest}')
    if Path(args.output).exists():
        ap.error(f'comparison already exists: {args.output}')
    base = json.load(open(BASE))
    prev = json.load(open(OUT)) if os.path.isfile(OUT) else {}
    classes = {d['artifact']: d['classification'] for d in prev.get('selectorDiffs', [])}
    for c in args.classify:
        name, text = c.split('=', 1)
        classes[name] = text
    rebase = set(args.rebaseline)
    compared = 0; missing = []; oversize = []; diffs = []; proxy_diffs = 0
    new_artifacts = discover_artifacts(base)
    for r in base:
        cur = load_artifact(r['artifact'])
        name = r['artifact'].split('/')[-1][:-5]
        if cur is None:
            missing.append(r['artifact']); continue
        compared += 1
        if name in rebase:
            r['runtimeBytes'] = cur['runtimeBytes']; r['sha256'] = cur['sha256']
            r['methodIdentifiers'] = cur['methodIdentifiers']
            r['provenance'] = f'rebaseline requested at {stamp}; artifact freshness must be verified by build evidence'
        if cur['runtimeBytes'] > EIP170:
            oversize.append({'artifact': r['artifact'], 'runtimeBytes': cur['runtimeBytes']})
        b = r.get('methodIdentifiers') or {}
        added = sorted(set(cur['methodIdentifiers']) - set(b)); removed = sorted(set(b) - set(cur['methodIdentifiers']))
        if added or removed:
            cls = classes.get(name) or classes.get(r['artifact'])
            if not cls:
                sys.exit(f"unclassified selector diff on {r['artifact']}: +{added} -{removed}")
            diffs.append({'source': r['source'], 'artifact': r['artifact'], 'added': added, 'removed': removed,
                          'runtimeBytes': cur['runtimeBytes'], 'classification': cls})
            # A facet's facetFuncs() defines an installed proxy selector set. A D19 split that moves selectors to a
            # sibling facet installed alongside leaves the set unchanged and says so in its classification.
            if 'Facet' in name and 'proxy selector set unchanged' not in cls:
                proxy_diffs += 1
    discovered = []
    for row in new_artifacts:
        cur = load_artifact(row['artifact'])
        if cur is None:
            missing.append(row['artifact'])
            continue
        compared += 1
        if cur['runtimeBytes'] > EIP170:
            oversize.append({'artifact': row['artifact'], 'runtimeBytes': cur['runtimeBytes']})
        discovered.append({**row, **cur, 'status': 'NEW_ARTIFACT_NO_HISTORICAL_BASELINE'})
    if rebase:
        with open(args.output + '.baseline.json', 'x') as baseline_copy:
            json.dump(base, baseline_copy, indent=1)
            baseline_copy.write('\n')
    out = {'compared': compared, 'missingArtifacts': len(missing), 'oversizeCount': len(oversize),
           'selectorDiffCount': len(diffs), 'oversize': oversize, 'selectorDiffs': diffs, 'missing': missing,
           'note': args.note or prev.get('note', ''), 'proxySelectorDiffCount': proxy_diffs,
           'newArtifacts': discovered,
           'newArtifactCount': len(new_artifacts),
           'selectorCoverage': 'Artifact ABI comparison only. New units have no historical ABI baseline; '
                               'proxy selector sets require deployed cuts/loupe verification.'}
    with open(args.output, 'x') as comparison:
        json.dump(out, comparison, indent=1)
        comparison.write('\n')
    if args.manifest:
        write_manifest(args.manifest, base + new_artifacts, args.test_log, args.output)
    print(json.dumps({k: out[k] for k in ('compared', 'missingArtifacts', 'oversizeCount', 'selectorDiffCount', 'proxySelectorDiffCount')}))
    if missing or oversize:
        sys.exit(1)

if __name__ == '__main__':
    main()
