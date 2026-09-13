"""Remove unread V3 NFT metadata after tracing current import custody and book use."""
from pathlib import Path
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
path = root / 'contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol'
before = path.read_text()
after = before
for declaration in ['address importedPositionManager;', 'uint256 importedPositionTokenId;', 'bool importedPositionActive;']:
    assert after.count('        ' + declaration) == 1
    after = after.replace('        ' + declaration + '\n', '')
start = after.index('    /// @notice Record import custody and the converted full-range center.')
end = after.index('    function _isPositionCreated(', start)
after = after[:start] + after[end:]
start = after.index('    function _importedPositionManager()')
after = after[:start].rstrip() + '\n}\n'
changes[str(path.relative_to(root))] = (before, after)

path = root / 'contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol'
before = path.read_text()
old = '''        UniswapV3VaultRepo._initializeImportedCenter(
            address(positionManager), positionTokenId, fullRange.centerLower, fullRange.centerUpper
        );'''
new = '''        UniswapV3VaultRepo._createPositionIfNeeded(fullRange.centerLower, fullRange.centerUpper);'''
assert before.count(old) == 1
after = before.replace(old, new)
changes[str(path.relative_to(root))] = (before, after)

for name, old, new in [
    ('IStandardExchangeInMulti.sol',
     'The array of input token addresses. Sorted in ascending order.',
     'Input token addresses in the vault\'s declared order. V4 uses PoolKey order with WETH as the ERC20 face of a native currency.'),
    ('IStandardExchangeOutMulti.sol',
     'The two pool currencies, unique, strictly ascending by address.',
     'The two unique pool currencies in the vault\'s declared order. V4 uses PoolKey order with WETH as the ERC20 face of a native currency.'),
]:
    path = root / 'contracts/interfaces' / name
    before = path.read_text()
    assert before.count(old) == 2
    changes[str(path.relative_to(root))] = (before, before.replace(old, new))

(art / 'v3-import-storage-followup.patch').write_text(''.join(''.join(difflib.unified_diff(
    before.splitlines(True), after.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
    for path, (before, after) in changes.items()))
(art / 'v3-import-storage-followup-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'finding': 'Current V3 import drains the NFT and creates a directly vault-owned full-range pool position. Three metadata fields and their private readers have no callers outside their own repository. They are not operational NFT position bindings.',
    'correction': 'Remove the three fields, unused readers and metadata initializer; reuse _createPositionIfNeeded for the same full-range center. Retain NFT custody, authorization, external positions ABI layout, actual funded import accounting, fee collection and pool position ownership.',
    'prior_record_correction': 'The V3 retention explanation in current-position-storage-disposition.json was incorrect; record the actual call graph. V4 context is separately read during import settlement and remains required.',
    'application_gate': 'Wait for the current affected-suite run PTY 10263 to exit, then apply current hashes and build before rerunning V3 import/full-range cases.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()]
}, indent=2) + '\n')
print('Prepared V3 dead import metadata cleanup and two interface ordering comments; canonical Solidity unchanged.')
