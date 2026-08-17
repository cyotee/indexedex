// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/// @dev Policy mint/burn gates + NotZapEligible (split for via-IR test bytecode tag space).
contract UniswapV4StandardExchangeOrbitalDETF_PolicyNotZapTest is
    TestBase_UniswapV4StandardExchangeOrbitalDETF
{
    function setUp() public override {
        super.setUp();
        _firstBondBothPairs(500 ether, 500 ether);
        _assertLive();
    }

    /// @dev Partial/min book: pull bond LP via production custody, multipath-remove redeemable LP
    ///      (leave MINIMUM_LIQUIDITY). No DETF redeposit → supply == MIN → !isZapEligible.
    ///      Primary mint must hard-revert NotZapEligible (DETF gate before depositSingle).
    function test_mint_reverts_NotZapEligible_when_only_min_liquidity() public {
        address d = _deployDetfInstance(_openArgsUnique("notZap"));
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        (uint256 tokenId,) = _firstBondOn(d, 50 ether, 50 ether);
        address hook = info.reserveHook();
        address bond = info.bondNftVault();
        address p0 = info.pairToken0();

        // Production custody: DETF (bond owner) moves LP to user; user removes via hook.
        uint256 bondLp = IERC20(hook).balanceOf(bond);
        assertGt(bondLp, 0, "bond holds first-bond LP");
        vm.prank(d);
        IDETFNFTVault(bond).transferHeldToken(IERC20(hook), detfUser, bondLp);

        uint256 userLp = IERC20(hook).balanceOf(detfUser);
        // Leave only permanent MINIMUM_LIQUIDITY (1000) on the hook ERC-20.
        uint256 removeAmt = userLp;
        // Cannot remove more than balance; MIN is held by address(0), not user.
        vm.startPrank(detfUser);
        IERC20(hook).approve(hook, removeAmt);
        IHook(hook).removeLiquidity(removeAmt, detfUser, 0, 0, 0, block.timestamp + 1 days);
        vm.stopPrank();

        assertFalse(IHook(hook).isZapEligible(), "must not be zap-eligible at min liquidity");
        assertLe(IERC20(hook).totalSupply(), 1000, "only MINIMUM_LIQUIDITY remains");

        // Primary mint must hard-revert NotZapEligible.
        SimpleMintableERC20(p0).mint(detfUser, 10 ether);
        uint256 dl = _dl();
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        vm.expectRevert(Repo.NotZapEligible.selector);
        IStandardExchangeIn(d).exchangeIn(IERC20(p0), 1 ether, IERC20(d), 0, detfUser, false, dl);
        vm.stopPrank();

        // silence unused
        tokenId;
    }

    function test_policy_mint_blocked_in_deadband_then_allowed_after_push() public {
        address d = _deployDetfInstance(_gentleArgsUnique("polMint"));
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));
        // Unbalanced first bond so S lands in Policy deadband (address-sorted
        // 1:1 doors + new DETF CREATE2 address no longer keep 400/400 at peg).
        _firstBondOn(d, 400 ether, 560 ether);

        // Hard mint-blocked precondition (no soft-if skip of blocked path).
        _requireMintBlocked(info);

        // Unconditional: primary mint must revert MintingNotAllowed while blocked.
        address p0 = info.pairToken0();
        SimpleMintableERC20(p0).mint(detfUser, 5 ether);
        uint256 sBlocked = info.syntheticPrice();
        uint256 mintTh = info.mintThreshold();
        uint256 dl = _dl();
        vm.startPrank(detfUser);
        IERC20(p0).approve(d, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(Repo.MintingNotAllowed.selector, sBlocked, mintTh));
        IStandardExchangeIn(d).exchangeIn(IERC20(p0), 1 ether, IERC20(d), 0, detfUser, false, dl);
        vm.stopPrank();

        // Drive rich synthetic; mint must be allowed with preview == exec.
        _pushSyntheticMintAllowed(info);
        assertTrue(info.isMintingAllowed(), "mint allowed after push");
        assertGt(info.syntheticPrice(), info.mintThreshold(), "S > mintThreshold");

        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(p0), 5 ether, IERC20(d));
        uint256 out_ = _mintOn(d, p0, 5 ether);
        assertEq(out_, preview, "Policy mint preview == exec when allowed");
        assertGt(out_, 0);
    }

    function test_policy_burn_allowed_when_synthetic_below_burnThreshold() public {
        address d = _deployDetfInstance(_gentleArgsUnique("polBurn"));
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        _firstBondOn(d, 100 ether, 100 ether);

        _pushSyntheticMintAllowed(info);
        uint256 minted = _mintOn(d, info.pairToken1(), 100 ether);
        assertGt(minted, 0);
        assertGt(info.protocolLp(), 0);

        for (uint256 i; i < 25 && !info.isBurningAllowed() && info.isMintingAllowed(); ++i) {
            try this.mintExternal(d, info.pairToken1(), 80 ether) {} catch {
                break;
            }
        }
        for (uint256 j; j < 15 && !info.isBurningAllowed(); ++j) {
            try this.bondDualExternal(d, 40 ether, 40 ether) {} catch {
                break;
            }
        }

        assertTrue(info.isBurningAllowed(), "burn allowed after dilution");
        assertLt(info.syntheticPrice(), info.burnThreshold(), "S < burnThreshold");

        uint256 bal = IERC20(d).balanceOf(detfUser);
        uint256 burnAmt = bal / 10;
        if (burnAmt == 0) burnAmt = bal;
        require(burnAmt > 0, "need free DETF to burn");
        address p1 = info.pairToken1();
        uint256 preview = IStandardExchangeIn(d).previewExchangeIn(IERC20(d), burnAmt, IERC20(p1));
        uint256 out_ = _burnOn(d, p1, burnAmt);
        assertApproxEqAbs(out_, preview, 100, "Policy burn preview == exec (few-wei)");
        assertGt(out_, 0);
    }
}
