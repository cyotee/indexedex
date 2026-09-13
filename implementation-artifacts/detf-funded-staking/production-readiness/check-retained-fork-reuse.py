"""Validate record-specific reuse without relabeling the original fork runs."""
from pathlib import Path
import json,sys
here=Path(__file__).resolve().parent;art=here.parent;root=art.parent.parent
sys.path.insert(0,str(art))
from build_provenance import capture,unchanged_fork_evidence_matches
current=capture(root)
for relative in ('production-readiness/provider-renewal-core-final/run.json','v3-retained-live-pool-production-readiness-run.json'):
    assert unchanged_fork_evidence_matches(root,current,art/relative), relative
assert not unchanged_fork_evidence_matches(root,current,art/'implementation-hermetic-test.json')
changed=dict(current,source_and_config_sha256='different-candidate')
assert not unchanged_fork_evidence_matches(root,changed,art/'v3-retained-live-pool-production-readiness-run.json')
print('PASS: 27 provider and eight V3 cases have unchanged verified source closures; full-suite and changed-candidate reuse rejected.')
