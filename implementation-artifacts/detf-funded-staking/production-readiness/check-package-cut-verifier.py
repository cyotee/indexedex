"""Exercise the actual package-cut inspection loop without RPC or Forge."""
import ast
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile

here = Path(__file__).resolve().parent
checker = here / 'inspect-rehearsal-core.py'
module = ast.parse(checker.read_text())
loops = [node for node in ast.walk(module) if isinstance(node, ast.For)
         and ast.unparse(node.target) == '(target, action, selectors)']
assert len(loops) == 1
code = compile(ast.Module(body=loops, type_ignores=[]), str(checker), 'exec')
erc721, bond, package = ('0x' + value * 40 for value in ('1', '2', '3'))
transfers = [bytes.fromhex(value) for value in ('23b872dd', '42842e0e', 'b88d4fde')]
claim = bytes.fromhex('12345678')
checks = []
with tempfile.TemporaryDirectory(prefix='release-package-cuts-') as directory:
    root = Path(directory)
    artifact = root / 'Facet.json'
    methods = dict(zip(('transferFrom', 'safeTransferFrom', 'safeTransferFromData'),
                       (value.hex() for value in transfers)))
    artifact.write_text(json.dumps({'methodIdentifiers': methods}))

    def verify(cuts, package_name='DETFNFTVaultDFPkg', bond_name='DETFNFTVaultFacet'):
        def call(target, signature, *_):
            if signature == 'facetName()':
                return ['ERC721Facet' if target == erc721 else bond_name]
            assert signature == 'facetFuncs()'
            return [transfers if target == erc721 else [claim]]

        row = {'cuts': []}
        env = dict(root=root, json=json, call=call, cuts=cuts, name=package_name,
                   address=package, package=row, seen={}, duplicates=[],
                   compare=lambda target, name: {'artifact': 'Facet.json'})
        exec(code, env)
        return not env['duplicates'] and all(
            cut['installed_selectors_declared'] for cut in row['cuts'])

    normal = [(erc721, 0, transfers), (bond, 0, [claim]), (bond, 1, transfers)]
    cases = [
        ('accepts the declared funded ERC721 replacements', normal, {}, True),
        ('rejects duplicate selectors within one Add cut', [(erc721, 0, transfers * 2)], {}, False),
        ('rejects duplicate Add across cuts', normal[:2] + [(bond, 0, transfers)], {}, False),
        ('rejects replacement without previous installed selectors', normal[1:], {}, False),
        ('rejects same-target replacement', [(bond, 0, transfers), (bond, 1, transfers)], {}, False),
        ('rejects replacement in an unrelated package', normal, {'package_name': 'OtherPackage'}, False),
        ('rejects replacement by an unrelated facet', normal, {'bond_name': 'OtherFacet'}, False),
        ('rejects duplicate selectors within Replace', normal[:2] + [(bond, 1, transfers * 2)], {}, False),
    ]
    for name, cuts, kwargs, expected in cases:
        assert verify(cuts, **kwargs) == expected, name
        checks.append({'name': name, 'passed': True})
    artifact.write_text(json.dumps({'methodIdentifiers': {}}))
    assert not verify(normal), 'Replacements must exist in the compiled ABI'
    checks.append({'name': 'rejects replacement selectors missing from compiled ABI', 'passed': True})

record = {'status': 'PASS_NINE_PACKAGE_CUT_VERIFIER_CHECKS',
          'checked_at_utc': datetime.now(timezone.utc).isoformat(),
          'checker_sha256': hashlib.sha256(checker.read_bytes()).hexdigest(),
          'checks': checks, 'scope': 'Actual inspector loop; synthetic verifier inputs, not Solidity test counts.'}
output = here / 'package-cut-verifier-checks.json'
assert not output.exists(), 'Preserve prior evidence.'
output.write_text(json.dumps(record, indent=2) + '\n')
print(record['status'])
