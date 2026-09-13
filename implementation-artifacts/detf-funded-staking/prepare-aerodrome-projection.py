"""Prepare, without applying, exact Aerodrome provider projections and proxy checks."""
from pathlib import Path
import difflib, hashlib, json, runpy

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = runpy.run_path(str(art / 'prepare-cp-lp-accounting.py'))['changes']

def change(path, text):
    file = root / path
    before = file.read_text() if file.exists() else ''
    changes[path] = (before, text)

base = 'contracts/protocols/dexes/aerodrome/v1/'
change(base + 'AerodromeStandardExchangeQuoteTarget.sol', (art / 'pending-aerodrome-transition-target.sol.txt').read_text())
path = base + 'AerodromeStandardExchangeOutQueryFacet.sol'
text = (root / path).read_text()
text = text.replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {AerodromeStandardExchangeQuoteTarget} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeQuoteTarget.sol";''')
text = text.replace('is AerodromeStandardExchangeOutQueryTarget,', 'is AerodromeStandardExchangeOutQueryTarget, AerodromeStandardExchangeQuoteTarget,')
text = text.replace('interfaces = new bytes4[](1);', 'interfaces = new bytes4[](3);')
text = text.replace('interfaces[0] = type(IStandardizedYield).interfaceId;', '''interfaces[0] = type(IStandardizedYield).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;''')
text = text.replace('funcs = new bytes4[](1);', 'funcs = new bytes4[](8);')
text = text.replace('funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;', '''funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[6] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;''')
change(path, text)

path = base + 'AerodromeStandardExchangeDFPkg.sol'
text = (root / path).read_text().replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";''')
text = text.replace('interfaces = new bytes4[](12);', 'interfaces = new bytes4[](14);')
text = text.replace('interfaces[11] = type(IStandardizedYield).interfaceId;', '''interfaces[11] = type(IStandardizedYield).interfaceId;
        interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[13] = type(IStandardExchangeExternalQuote).interfaceId;''')
change(path, text)

path = base + 'Aerodrome_Component_FactoryService.sol'
text = (root / path).read_text()
for name in ['AerodromeStandardExchangeInFacet', 'AerodromeStandardExchangeOutFacet', 'AerodromeStandardExchangeOutQueryFacet']:
    old = f'''        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("{name}.sol:{name}"),
            abi.encode("{name}")._hash()
        );'''
    new = f'''        bytes memory code = ArtifactCreationCode.creationCode("{name}.sol:{name}");
        bytes32 releaseSalt = keccak256(abi.encode("{name}", keccak256(code)));
        instance = create3Factory.deployFacet(code, releaseSalt);'''
    assert text.count(old) == 1, name
    text = text.replace(old, new)
start = text.index('        instance = IAerodromeStandardExchangeDFPkg(')
end = text.index('        vm.label(address(instance), "AerodromeStandardExchangeDFPkg");', start)
text = text[:start] + '''        bytes memory code = ArtifactCreationCode.creationCode("AerodromeStandardExchangeDFPkg.sol:AerodromeStandardExchangeDFPkg");
        bytes memory arguments = abi.encode(pkgInit);
        bytes32 releaseSalt = keccak256(abi.encode("AerodromeStandardExchangeDFPkg", keccak256(code), keccak256(arguments)));
        instance = IAerodromeStandardExchangeDFPkg(address(vaultRegistry.deployPkg(code, arguments, releaseSalt)));
''' + text[end:]
change(path, text)

path = 'test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol'
text = changes[path][1]
old = 'contract AerodromeNativeSYTest is TestBase_AerodromeStandardExchange, ConstantProductNativeSYBehavior {'
assert text.count(old) == 1
text = text.replace(old, old + '\n' + (art / 'pending-aerodrome-projection-tests.txt').read_text())
change(path, text)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                         fromfile='a/' + path if before else '/dev/null', tofile='b/' + path))
                for path, (before, after) in changes.items())
(art / 'aerodrome-projection.patch').write_text(patch)
record = {
    'status': 'PREPARED_NOT_APPLIED',
    'reason': 'Preserve accepted V4 buffer compositions for the existing volatile Aerodrome SE without a capability allowlist.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest() if before else None,
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'scope': 'Aerodrome existing query facet, package declarations, code-bound factory salts; retained LP accounting routes for V2/Camelot/Aerodrome with consolidated existing production-proxy fixtures. No PkgArgs/PkgInit or execution economics change.',
    'validation': 'Pending compilation, EIP-170 measurement, exact full-state proxy sequences and existing native SY regression cases. If the existing query facet exceeds EIP-170, split the quote selectors through the existing package/registry architecture.',
    'source_freeze': 'Do not apply until release validation session 52340 and every child Forge process have exited.',
}
(art / 'aerodrome-projection-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
print('Prepared', len(changes), 'sources; no Solidity changed.')
