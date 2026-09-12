from pathlib import Path
import sys,json,datetime
root=Path.cwd();p=root/'test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_FullRangeBook.t.sol';s=p.read_text();a=s.index('    function test_FR5_singleTokenFirstMint_thenDualDepositMintsFullRangeL()');z=s.index('    function test_FR6_',a)
s=s[:a]+'''    function test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable() public {
        uint256 amount = 10 ether;
        IERC20 input = IERC20(_token0());
        ERC20PermitMintableStub(address(input)).mint(address(this), amount);
        input.approve(address(vault), amount);
        assertEq(vault.previewExchangeIn(input, amount, IERC20(address(vault))), 0);
        uint256 balance = input.balanceOf(address(this));
        vm.expectRevert(bytes4(keccak256("UniswapV3Exchange_ZeroAmount()")));
        vault.exchangeIn(input, amount, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(input.balanceOf(address(this)), balance, "failed activation keeps payment");
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(input.balanceOf(address(vault)), 0);
        uint256 issued = _dualJoin(amount, amount);
        assertGt(issued, 0);
        (int24 lower, int24 upper) = _fullRangeTicks();
        assertGt(_liquidityAt(lower, upper), 0, "dual activation creates full-range liquidity");
        input.approve(address(vault), amount);
        uint256 quote = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
        assertGt(quote, 0);
        assertEq(vault.exchangeIn(input, amount, IERC20(address(vault)), quote, address(this), false, _deadline()), quote);
    }

'''+s[z:]
s=s.replace('test_FR6_importedNftTicksNotRewritten','test_FR6_importedNftConvertedToFullRange').replace('assertGt(importedL, 0, "FR6: imported ticks hold L");','assertEq(importedL, 0, "FR6: imported narrow range fully removed");').replace('assertEq(fullL, 0, "FR6: not rewritten to min/max");','assertGt(fullL, 0, "FR6: conversion deploys maximum usable range");')
a=root/'implementation-artifacts/detf-funded-staking'
if '--apply' in sys.argv:p.write_text(s)
else:(a/'pending-v3-legacy-range-migration.txt').write_text(s)
(a/'v3-legacy-range-migration.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'mapping':{'test_FR5_singleTokenFirstMint_thenDualDepositMintsFullRangeL':'D59: reject one-sided activation, preserve payment, activate both tokens, retain later one-sided deposits','test_FR6_importedNftTicksNotRewritten':'D57: actual imported narrow liquidity is removed and redeployed across maximum usable ticks'},'scope':'V3 only; no deferred Slipstream changes'},indent=2)+'\n');print('prepared' if '--apply' not in sys.argv else 'applied')
