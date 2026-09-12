"""Consolidate custom protocol-share funding and exercise the configured bond route."""
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
path = root / 'test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol'
before = path.read_text()
assert 'function test_customBondQuoteIncludesWrappingBeforeIssuance' not in before
after = before.replace('        args_.donateRoutes = args_.mintRoutes;\n',
    '        args_.donateRoutes = args_.mintRoutes;\n        args_.bondRouteMode = IUniswapV4Detf.RouteTableMode.Custom;\n        args_.bondRoutes = args_.mintRoutes;\n', 1)
setup = '''        address pair = _leadPayment();
        address se = IUniswapV4SeBufferHook(subject.hook()).standardExchangeOf(pair);
        IERC4626 protocol = IERC4626(IStandardizedYield(se).yieldToken());
        address oracle = IReserveOracleBinding(subject.hook()).feeOracle();
        vm.prank(_admin(oracle));
        IVaultFeeOracleManager(oracle).setUsageFeeOfVault(se, 0.07e18);
        vm.startPrank(_buyer());
        IERC20(pair).approve(address(protocol), 10 ether);
        uint256 shares = protocol.deposit(10 ether, _buyer());
        vm.stopPrank();
'''
assert after.count(setup) == 2
start = after.index('    function test_customProtocolShareFallbackComposesActualConversionAndSwap()')
end = after.index('    function _fundFallbackShares(', start)
section = after[start:end]
section = section.replace(setup,
    '        (IERC20 input, uint256 shares) = _fundCustomProtocolPayment(subject);\n')
section = section.replace('        IERC20 input = IERC20(address(protocol));\n',
    '        address se = IUniswapV4SeBufferHook(subject.hook()).standardExchangeOf(_leadPayment());\n')
section = section.replace('IERC20(address(protocol))', 'input')
addition = '''    struct CustomBondQuote {
        uint256 principal;
        uint256 rewards;
        uint256 liquidity;
    }

    function test_customBondQuoteIncludesWrappingBeforeIssuance() public {
        IUniswapV4Detf subject = _activateFallbackInstance();
        (IERC20 input, uint256 shares) = _fundCustomProtocolPayment(subject);
        CustomBondQuote memory quoted;
        (, quoted.principal, quoted.rewards, quoted.liquidity) = subject.previewBond(input, shares, 30 days);
        assertGt(quoted.principal, 0);
        uint256 supply = IERC20(address(subject)).totalSupply();
        uint256 backing = IERC20(address(subject)).balanceOf(subject.rebasingClaimToken());
        uint256 owned = IERC20(subject.hook()).balanceOf(subject.bondNftVault());
        vm.startPrank(_buyer());
        input.approve(address(subject), shares);
        (uint256 id, uint256 lpAdded) = subject.bond(input, shares, 30 days, _buyer(), false, block.timestamp);
        vm.stopPrank();
        IDetfBondNFT nft = IDetfBondNFT(subject.bondNftVault());
        assertEq(nft.positionOf(id).principal, quoted.principal, "custom bond preview includes prior SE wrapping");
        assertEq(nft.positionOf(id).vestingDuration, 30 days);
        assertEq(nft.previewClaim(id).principalDue, 0);
        assertEq(IERC20(address(subject)).totalSupply(), supply + quoted.principal + quoted.rewards + quoted.liquidity);
        assertEq(IERC20(address(subject)).balanceOf(subject.rebasingClaimToken()), backing + quoted.principal + quoted.rewards);
        assertEq(IERC20(subject.hook()).balanceOf(address(nft)), owned + lpAdded);
        assertGt(lpAdded, 0, "ordinary payment adds a matching liquidity leg");
        assertGt(nft.previewClaim(id).rewardsDue, 0, "new funded bond earns its immediate staking reward");
    }

    function _fundCustomProtocolPayment(IUniswapV4Detf subject) private returns (IERC20 input, uint256 shares) {
'''
addition += setup.replace('        uint256 shares =', '        shares =')
addition += '''        input = IERC20(address(protocol));
    }

'''
after = after[:start] + section + addition + after[end:]
record = {
    'status': 'applied; validation pending' if args.apply else 'prepared, not applied while Solidity compiles',
    'path': str(path.relative_to(root)),
    'reason': 'Compare received-capital bond execution with preview after a real custom protocol-share wrap that charges the configured SE usage fee.',
    'consolidation': 'The mint-fallback, donation and bond regressions share one actual protocol-share funding helper; no mocked accounting or new fixture.',
    'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
    'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
}
(artifacts / 'custom-bond-quote-regression.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))))
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    path.write_text(after)
(artifacts / 'custom-bond-quote-regression.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
