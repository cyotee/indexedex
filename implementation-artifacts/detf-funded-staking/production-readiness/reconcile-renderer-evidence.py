"""Reuse visual review only when the current Solidity exports are byte-identical."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET

here = Path(__file__).resolve().parent
art = here.parent
root = art.parent.parent
sys.path.insert(0, str(art))
from build_provenance import capture, readiness_provenance_matches

current = capture(root)
run = json.loads((art / 'implementation-hermetic-test.json').read_text())
build = json.loads((art / 'implementation-full-build.json').read_text())
keys = ('source_and_config_sha256', 'crane_head', 'crane_tracked_contract_and_config_diff_sha256',
        'crane_source_and_config_sha256', 'forge_version')
assert run['exit_code'] == build['exit_code'] == 0
assert readiness_provenance_matches(root, current, run['provenance'])
assert all(current[key] == build['provenance'][key] for key in keys)
log = (art / 'implementation-hermetic-test.log').read_text()
assert '[PASS] test_exportRepresentativeRendererArtifacts()' in log
directory = art / 'bond-artwork/rendered'
review = json.loads((directory / 'visual-check.json').read_text())
assert len(review) == 8
rows = []
for reviewed in review:
    name = reviewed['name']
    svg = (directory / (name + '.svg')).read_bytes()
    data = (directory / (name + '.json')).read_bytes()
    svg_hash = hashlib.sha256(svg).hexdigest()
    json_hash = hashlib.sha256(data).hexdigest()
    matching = svg_hash == reviewed['svg_sha256'] and json_hash == reviewed['json_sha256']
    document = ET.fromstring(svg)
    for node in document.iter():
        assert node.tag.split('}')[-1] != 'script', name
        for key, value in node.attrib.items():
            if key.split('}')[-1] == 'href':
                assert value.startswith(('#', 'data:')), 'External image/link dependency: ' + name
    assert not re.search(rb'@import|url\(\s*["\x27]?(?:https?:|//)', svg), name
    rows.append({'fixture': name, 'svg_sha256': svg_hash, 'json_sha256': json_hash,
                 'matches_reviewed_output': matching, 'prior_browser_loaded': reviewed['loaded'],
                 'self_contained_svg': True, 'traits': json.loads(data)['attributes']})
report = {
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(), 'provenance': current,
    'status': 'PASS_REUSED_IDENTICAL_VISUAL_EVIDENCE' if all(r['matches_reviewed_output'] and r['prior_browser_loaded'] for r in rows) else 'CHANGED_OUTPUT_REQUIRES_NEW_VISUAL_REVIEW',
    'renderer_test': 'DETFFundedBondMetadataTest.test_exportRepresentativeRendererArtifacts',
    'current_runtime_log': 'implementation-hermetic-test.log',
    'prior_visual_review': 'bond-artwork/rendered/visual-check.json',
    'method': __doc__, 'fixtures': rows,
}
(here / 'renderer-evidence-reuse.json').write_text(json.dumps(report, indent=2) + '\n')
print(report['status'])
assert report['status'] == 'PASS_REUSED_IDENTICAL_VISUAL_EVIDENCE'
