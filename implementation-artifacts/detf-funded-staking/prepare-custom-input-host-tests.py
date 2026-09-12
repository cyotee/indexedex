from pathlib import Path
import sys,json,datetime
root=Path.cwd();p=root/'test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol';b=p.read_text();s=b.replace('import {IERC20}', 'import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";\nimport {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";\nimport {IERC20}',1)
s=s.replace('internal pure returns (IUniswapV4Detf.PkgArgs memory)\n    {','internal view returns (IUniswapV4Detf.PkgArgs memory)\n    {',1)
needle='        args_.expansionClosureRatePerYearWad = 1e18;'
s=s.replace(needle,needle+'''
        address pair = _leadPayment();
        address se = _hook().standardExchangeOf(pair);
        args_.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args_.mintRoutes = new IUniswapV4Detf.IoRoute[](3);
        args_.mintRoutes[0] = IUniswapV4Detf.IoRoute(IERC20(pair), IStandardExchange(se));
        args_.mintRoutes[1] = IUniswapV4Detf.IoRoute(IERC20(se), IStandardExchange(se));
        args_.mintRoutes[2] = IUniswapV4Detf.IoRoute(IERC20(IStandardizedYield(se).yieldToken()), IStandardExchange(se));''',1)
s=s.replace('_actualPostRedeemSwapQuote(subject_, se_, shares_)','_actualPostExchangeSwapQuote(subject_, address(se_), se_, shares_)')
s=s.replace('function _actualPostRedeemSwapQuote(IUniswapV4Detf subject_, IERC20 se_, uint256 shares_)', 'function _actualPostExchangeSwapQuote(IUniswapV4Detf subject_, address se_, IERC20 input_, uint256 shares_)')
s=s.replace('IStandardExchangeIn(address(se_)).exchangeIn(se_, shares_, IERC20(pair_), 0, _buyer(), false, block.timestamp);', 'IStandardExchangeIn(se_).exchangeIn(input_, shares_, IERC20(pair_), 0, _buyer(), false, block.timestamp);')
# External protocol shares require approval to the SE when computing the independent post-state reference.
s=s.replace('        vm.prank(_buyer());\n        uint256 pairOut_ = IStandardExchangeIn(se_).exchangeIn(', '        vm.startPrank(_buyer());\n        input_.approve(se_, shares_);\n        uint256 pairOut_ = IStandardExchangeIn(se_).exchangeIn(')
s=s.replace('        expected_ = IUniswapV4SeBufferHook(subject_.hook()).previewSwapExactIn(', '        vm.stopPrank();\n        expected_ = IUniswapV4SeBufferHook(subject_.hook()).previewSwapExactIn(',1)
needle='    function _fundFallbackShares('
addition='''    function test_customProtocolShareFallbackComposesActualConversionAndSwap() public {
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
        IERC20 input = IERC20(address(protocol));
        assertFalse(subject.isMintingAllowed(input));
        uint256 preview = IStandardExchangeIn(address(subject)).previewExchangeIn(input, shares, IERC20(address(subject)));
        assertGt(preview, 0, "configured protocol-share route has an executable quote");
        assertEq(preview, _actualPostExchangeSwapQuote(subject, se, input, shares));
        _assertShareSwapSettlement(subject, input, shares, preview);
    }

'''
assert needle in s;s=s.replace(needle,addition+needle,1)
art=root/'implementation-artifacts/detf-funded-staking'
if '--apply' in sys.argv:p.write_text(s)
else:(art/'pending-custom-input-host-tests.txt').write_text(s)
(art/'custom-input-host-tests.json').write_text(json.dumps({'status':'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Eight actual family/policy bindings exercise custom protocol-share inputs, conversion before reserve swap, strict preview/minimum and supply/backing/LP conservation.'},indent=2)+'\n')
print('prepared' if '--apply' not in sys.argv else 'applied')
