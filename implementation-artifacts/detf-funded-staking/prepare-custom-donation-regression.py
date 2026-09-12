from pathlib import Path
import json,datetime,sys
root=Path.cwd();p=root/'test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol';s=p.read_text();needle='        args_.mintRoutes[2] = IUniswapV4Detf.IoRoute(IERC20(IStandardizedYield(se).yieldToken()), IStandardExchange(se));';assert needle in s
s=s.replace(needle,needle+'\n        args_.donateRouteMode = IUniswapV4Detf.RouteTableMode.Custom;\n        args_.donateRoutes = args_.mintRoutes;',1)
needle='    function _fundFallbackShares('
addition='''    function test_customDonationQuoteIncludesWrappingBeforeReserveJoin() public {
        IUniswapV4Detf subject = _activateFallbackInstance();
        address pair = _leadPayment();
        address se = IUniswapV4SeBufferHook(subject.hook()).standardExchangeOf(pair);
        IERC4626 protocol = IERC4626(IStandardizedYield(se).yieldToken());
        address oracle = IReserveOracleBinding(subject.hook()).feeOracle();
        vm.prank(_admin(oracle));
        IVaultFeeOracleManager(oracle).setUsageFeeOfVault(se, 0.07e18);
        vm.startPrank(_buyer());
        IERC20(pair).approve(address(protocol), 10 ether);
        uint256 shares = protocol.deposit(10 ether, _buyer());
        vm.stopPrank();
        IDetfNftReserveDonation nft = IDetfNftReserveDonation(subject.bondNftVault());
        uint256 preview = nft.previewDonate(IERC20(address(protocol)), shares);
        assertGt(preview, 0, "configured donation remains quotable");
        uint256 supply = IERC20(address(subject)).totalSupply();
        uint256 backing = IERC20(address(subject)).balanceOf(subject.rebasingClaimToken());
        uint256 owned = IERC20(subject.hook()).balanceOf(address(nft));
        vm.startPrank(_buyer());
        IERC20(address(protocol)).approve(address(nft), shares);
        uint256 minted = nft.donate(IERC20(address(protocol)), shares, 0, false, block.timestamp);
        vm.stopPrank();
        assertEq(minted, preview, "LP preview includes custom wrap and reserve join");
        assertEq(IERC20(subject.hook()).balanceOf(address(nft)), owned + minted);
        assertEq(IERC20(address(subject)).totalSupply(), supply, "donation issues no DETF");
        assertEq(IERC20(address(subject)).balanceOf(subject.rebasingClaimToken()), backing, "donation issues no staking claim");
    }

'''
assert needle in s;s=s.replace(needle,addition+needle,1);a=root/'implementation-artifacts/detf-funded-staking'
if '--apply' in sys.argv:p.write_text(s)
else:(a/'pending-custom-donation-regression.txt').write_text(s)
(a/'custom-donation-regression.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Eight real reserve/policy bindings with a custom protocol-share donation and 7% SE issuance fee; preview versus actual LP and no DETF/staking issuance.'},indent=2)+'\n');print('prepared' if '--apply' not in sys.argv else 'applied')
