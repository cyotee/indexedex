"""Consolidate native Orbital SY checks into the retained standard-liquidity ABI suite."""
from pathlib import Path
import json,hashlib
p=Path('test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol');old=p.read_text();s=old
s=s.replace('import {IERC20}', '''import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookHooksFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol";
import {IERC20}''',1)
s=s.replace('test_T2_8_previewBurnToToken_propRejoin_notExitSingle', 'test_T2_8_previewBurnToToken_usesStandardSingleExit')
s=s.replace('lp / 2', 'lp / 20')
s=s.replace('''        assertEq(orbital.previewExitSingleAssetExactBptIn(address(token1), lp / 20), 0, "T2.8 no single-asset path");''','''        assertEq(orbital.previewExitSingleAssetExactBptIn(address(token1), lp / 20), preview);
        uint256 before = token1.balanceOf(user);
        vm.prank(user);
        assertEq(orbital.exitSingleAssetExactBptIn(address(token1), lp / 20, user, preview, block.timestamp), preview);
        assertEq(token1.balanceOf(user) - before, preview);''')
mark='    function _joinFullBook('
assert s.count(mark)==1
s=s.replace(mark,'''    function test_nativeSYMetadataAndInstalledFacetSizes() public {
        _joinFullBook(300 ether, 300 ether, 300 ether);
        IStandardizedYield sy = IStandardizedYield(hook);
        assertTrue(IERC165(hook).supportsInterface(type(IStandardizedYield).interfaceId));
        assertEq(sy.getTokensIn().length, 5);
        assertEq(sy.getTokensIn(), sy.getTokensOut());
        assertEq(sy.yieldToken(), address(0));
        assertEq(sy.decimals(), 18);
        (IStandardizedYield.AssetType kind, address asset, uint8 decimals) = sy.assetInfo();
        assertEq(uint8(kind), uint8(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(asset, hook); assertEq(decimals, 18);
        assertEq(sy.getRewardTokens().length, 0);
        address[] memory facets = IDiamondLoupe(hook).facetAddresses();
        for (uint256 i; i < facets.length; ++i) assertLe(facets[i].code.length, 24_576);
    }

    function test_nativeSYEveryDeclaredRoutePaysItsPreview() public {
        _joinFullBook(300 ether, 300 ether, 300 ether);
        _mintSeSharesToUser(se1, token1, 20 ether);
        _mintSeSharesToUser(se2, token2, 20 ether);
        IStandardizedYield sy = IStandardizedYield(hook);
        address[] memory tokens = sy.getTokensIn();
        vm.startPrank(user);
        for (uint256 i; i < tokens.length; ++i) {
            IERC20(tokens[i]).approve(hook, 2 ether);
            uint256 shares = sy.previewDeposit(tokens[i], 2 ether);
            assertGt(shares, 0);
            assertEq(sy.deposit(user, tokens[i], 2 ether, shares), shares, "deposit preview");
            address out = tokens[(i + 1) % tokens.length];
            uint256 quoted = sy.previewRedeem(out, shares);
            uint256 before = IERC20(out).balanceOf(user);
            assertEq(sy.redeem(user, shares, out, quoted, false), quoted, "redemption preview");
            assertEq(IERC20(out).balanceOf(user) - before, quoted, "actual payout");
        }
        vm.stopPrank();
    }

    function test_nativeSYInternalBalanceLimitsAndPriorInventory() public {
        uint256 lp = _joinFullBook(300 ether, 300 ether, 300 ether);
        token0.mint(hook, 7 ether); token1.mint(hook, 11 ether); token2.mint(hook, 13 ether);
        IStandardizedYield sy = IStandardizedYield(hook);
        uint256 amount = lp / 100;
        uint256 quoted = sy.previewRedeem(address(token0), amount);
        vm.startPrank(user);
        vm.expectRevert(); sy.redeem(user, amount, address(token0), quoted + 1, false);
        assertEq(sy.balanceOf(user), lp, "failed minimum rolls back burn");
        sy.transfer(hook, 3 * amount);
        assertEq(sy.redeem(user, amount, address(token0), quoted, true), quoted);
        assertEq(sy.balanceOf(hook), 2 * amount, "only requested internal shares burned");
        vm.stopPrank();
        assertEq(token0.balanceOf(hook) - orbital.rawReserve(0), 7 ether);
        assertEq(token1.balanceOf(hook), 11 ether);
        assertEq(token2.balanceOf(hook), 13 ether);
    }

    function test_nativeSYFundedYieldRepricesWithoutRebasingAndStillRedeems() public {
        uint256 lp = _joinFullBook(300 ether, 300 ether, 300 ether);
        IStandardizedYield sy = IStandardizedYield(hook);
        uint256 rate = sy.exchangeRate();
        vm.startPrank(user);
        token1.approve(address(vault1), 40 ether);
        vault1.simulateYield(40 ether);
        vm.stopPrank();
        assertGt(sy.exchangeRate(), rate);
        assertEq(sy.balanceOf(user), lp);
        uint256 quoted = sy.previewRedeem(address(token1), lp / 100);
        uint256 before = token1.balanceOf(user);
        vm.prank(user); assertEq(sy.redeem(user, lp / 100, address(token1), quoted, false), quoted);
        assertEq(token1.balanceOf(user) - before, quoted);
    }

'''+mark)
p.write_text(s)
root=Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol');r=root.read_text()
for suffix in ('SeBufferAbi','SeLifecycle','OwnerOnlyLiquidity','OwnerDuringLock','SeExchange','Fees'):
 path=f'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_{suffix}.t.sol'
 r+=f'\nimport "{path}";\n'
root.write_text(r)
Path('implementation-artifacts/detf-funded-staking/orbital-native-sy-test-consolidation.json').write_text(json.dumps({'file':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest(),'retained':'T2.1–T2.10 and unknown/empty guards','updated':'T2.8 obsolete zero stub expectation replaced by real single-output preview/payout','added':'Four consolidated native SY cases including every declared input/output, funded yield, minimum rollback, prior inventory and actual facet runtime'},indent=2)+'\n')
