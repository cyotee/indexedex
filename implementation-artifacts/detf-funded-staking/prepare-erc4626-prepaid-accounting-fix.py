"""Prepare the confirmed prepaid receipt backing fix, preserving issuance formulas."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
changes = []

def stage(relative, transform):
    path = root / relative
    before = path.read_text()
    after = transform(before)
    assert before != after, relative
    changes.append((path, before, after))

def exact_in(source):
    old = '''            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            // totalBefore is vault inventory *before* this user's deposit credit
'''
    assert old in source
    return source.replace(old, '''            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            // A prepaid receipt is already in the token balance. Exclude only
            // this credited payment, retaining all other existing reserve.
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this)) - actualIn;
''', 1)

stage('contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol', exact_in)

def common(source):
    old = '''    function _previewVaultInForSeOut(uint256 seOut) internal view returns (uint256 vaultIn) {
        uint256 supply = ERC20Repo._totalSupply();
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
'''
    assert old in source
    source = source.replace(old, '''    function _previewVaultInForSeOut(uint256 seOut) internal view returns (uint256 vaultIn) {
        return _vaultInForSeOut(seOut, IERC20(address(protocolVault())).balanceOf(address(this)));
    }

    function _vaultInForSeOut(uint256 seOut, uint256 vaultBal) internal view returns (uint256 vaultIn) {
        uint256 supply = ERC20Repo._totalSupply();
''', 1)
    anchor = '    /// @dev Underlying out for exact SE in (unwrap exact-in).'
    assert anchor in source
    return source.replace(anchor, '''    /// @dev Credit at most the caller's maximum from unbooked payment. Booked
    /// reserve and unclaimed surplus remain backing throughout exact-output minting.
    function _prepaidCredit(IERC20 token, uint256 maximum) internal view returns (uint256) {
        uint256 available = token.balanceOf(address(this)) - MultiAssetBasicVaultRepo._reserveOfToken(address(token));
        return available < maximum ? available : maximum;
    }

''' + anchor, 1)

stage('contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol', common)

def exact_out(source):
    old = '''            amountIn = _previewVaultInForSeOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();

            // Snapshot reserve *before* user deposit credit (free-mint safe).
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            _securePull(tokenIn, amountIn, pretransferred);

            uint256 sharesFromDelta = _convertVaultDeltaToShares(amountIn, totalBefore);
            if (sharesFromDelta < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // Pull overshoot already refunded in _securePull; never refund absolute reserve.
'''
    assert old in source
    return source.replace(old, '''            uint256 prepaid = pretransferred ? _prepaidCredit(tokenIn, maxAmountIn) : 0;
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this)) - prepaid;
            amountIn = _vaultInForSeOut(amountOut, totalBefore);
            if (amountIn > maxAmountIn) revert Slippage();
            uint256 received = _securePull(tokenIn, amountIn, pretransferred);
            if (received != amountIn) revert InsufficientDeposit(amountIn, received);
            uint256 sharesFromDelta = _convertVaultDeltaToShares(amountIn, totalBefore);
            if (sharesFromDelta < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            if (prepaid > amountIn) tokenIn.safeTransfer(msg.sender, prepaid - amountIn);
            // Only the caller's unused credited payment is refundable.
''', 1)

stage('contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol', exact_out)

if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    for path, before, after in changes:
        assert path.read_text() == before
        path.write_text(after)
record = {'status': 'applied; validation pending' if args.apply else 'prepared; Solidity unchanged', 'reason': 'Observed prepaid protocol-share donation minted against reserve including its own payment. Preserve existing issuance algebra, exclude credited payment, and refund only unused credited exact-output maximum.', 'files': [{'path': str(path.relative_to(root)), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path,before,after in changes]}
(artifacts / 'erc4626-prepaid-accounting-fix.patch').write_text(''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))) for path,before,after in changes))
(artifacts / 'erc4626-prepaid-accounting-fix.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status':record['status'],'files':len(changes)}))
