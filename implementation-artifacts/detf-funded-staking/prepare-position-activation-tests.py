"""Prepare remaining position-vault launch/rounding fixtures for two-token activation."""
from pathlib import Path
import datetime, hashlib, json, re, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
changes = {}
p = root / 'test/foundry/spec/scripts/anvil_robinhood_main/StandardExchangeStages.t.sol'
b = p.read_text()
s = b.replace('import {IERC20}', 'import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";\nimport {IERC20}')
needle = '        a.mint(address(this), 10 ether);\n        _assertDeposit(vault, IERC20(address(a)), 10 ether);'
replacement = '''        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0(); tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether; amounts[1] = 100 ether;
        a.mint(address(this), 110 ether); b.mint(address(this), 100 ether);
        a.approve(vault, 100 ether); b.approve(vault, 100 ether);
        IStandardExchangeInMulti(vault).exchangeInManyToOne(tokens, amounts, IERC20(vault), 1, address(this), false, block.timestamp);
        _assertDeposit(vault, IERC20(address(a)), 10 ether);'''
assert needle in s
s = s.replace(needle, replacement)
s = s.replace('        uint256 received = IStandardExchangeIn(vault).exchangeIn(',
              '        uint256 heldBefore = IERC20(vault).balanceOf(address(this));\n        uint256 received = IStandardExchangeIn(vault).exchangeIn(')
s = s.replace('assertEq(IERC20(vault).balanceOf(address(this)), received);',
              'assertEq(IERC20(vault).balanceOf(address(this)) - heldBefore, received);')
changes[p] = (b, s)

p = root / 'test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_FullRangeBook.t.sol'
b = p.read_text()
s = b.replace('import {TransitionQuoteAssertions}', 'import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";\nimport {TransitionQuoteAssertions}')
start = s.index('    function testFuzz_oneAssetSleeveWithdrawal(')
end = s.index('    function testFuzz_freeInventoryExit_matchesQuote(', start)
replacement = '''    function testFuzz_fundedSleeveWithdrawalRounding(uint128 deposit_, uint128 wanted_) public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 1e18);
        uint256 deposit = bound(deposit_, 1_000_000, 1_000_000 ether);
        uint256 issued = _dualJoin(deposit, deposit);
        IERC20 asset = IERC20(_token0());
        uint256 donation = deposit / 3 + 1;
        ERC20PermitMintableStub(address(asset)).mint(address(vault), donation);
        uint256 reserve = deposit + donation;
        uint256 wanted = bound(wanted_, 1, reserve);
        uint256 expected = (wanted * issued + reserve - 1) / reserve;
        IERC20(address(vault)).transfer(address(lockCaller), issued);
        vm.prank(address(lockCaller)); IERC20(address(vault)).approve(address(vault), issued);
        uint256 beforeAssets = asset.balanceOf(address(this));
        uint256 charged = lockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), expected, asset, wanted, address(this), false, _deadline()
        );
        assertEq(charged, expected, "independent ceiling over a funded two-token book");
        assertEq(asset.balanceOf(address(this)) - beforeAssets, wanted);
        assertEq(IERC20(address(vault)).totalSupply(), issued - charged);
    }

'''
changes[p] = (b, s[:start] + replacement + s[end:])

p = root / 'test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol'
b = p.read_text()
s = b.replace('import {TransitionQuoteAssertions}', 'import {PoolSeedLib} from "scripts/foundry/anvil_robinhood_testnet/PoolSeedLib.sol";\nimport {TransitionQuoteAssertions}')
needle = '    function testFuzz_transitionSequence_fundedPool('
test = '''    function test_launchHelperActivatesBothTokensAndDoesNotReseed() public {
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        tokenA.mint(address(this), 100 ether);
        tokenB.mint(address(this), 100 ether);
        address receiver = makeAddr("SE activation receiver");
        PoolSeedLib.activateStandardExchange(address(vault), poolKey, 100 ether, receiver);
        uint256 issued = IERC20(address(vault)).balanceOf(receiver);
        assertGt(issued, 0, "actual SE shares fund the launch receiver");
        assertEq(tokenA.allowance(address(this), address(vault)), 0);
        assertEq(tokenB.allowance(address(this), address(vault)), 0);
        PoolSeedLib.activateStandardExchange(address(vault), poolKey, 100 ether, receiver);
        assertEq(IERC20(address(vault)).balanceOf(receiver), issued, "replay does not deposit again");
        tokenA.mint(address(this), 1 ether);
        tokenA.approve(address(vault), 1 ether);
        uint256 quote = vault.previewExchangeIn(IERC20(address(tokenA)), 1 ether, IERC20(address(vault)));
        assertGt(quote, 0, "single-token intake is live after activation");
        assertEq(vault.exchangeIn(IERC20(address(tokenA)), 1 ether, IERC20(address(vault)), quote, receiver, false, _deadline()), quote);
    }

'''
assert needle in s
changes[p] = (b, s.replace(needle, test + needle, 1))

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-activation-test-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'coverage_mapping': {
        'V3 stage single-token initial activation': 'Activate with both real tokens, then retain the separate subsequent single-token deposit assertion using its actual balance delta.',
        'V3 one-sided initial sleeve fuzz': 'Replace obsolete one-token launch with two-token funded locked-pool withdrawal; retain independent ceiling, exact recipient payout and supply/burn conservation. V4 already has this funded regression.',
        'Robinhood helper': 'Actual V4 proxy activation funds intended receiver, clears approvals, does not reseed on replay, and enables subsequent one-token intake.',
    },
    'dependencies': ['prepare-robinhood-se-activation.py'],
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'position-activation-test-migrations.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
