// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {TestBase_UniswapV4Detf_Orbital} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_CurveQuad} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_CurveQuad.sol";
import {DETFFundedStakingArtifacts} from "contracts/test/bases/DETFFundedStakingArtifacts.sol";

/// @dev Integration assertions shared without inheriting another executable suite.
abstract contract V4FundedBindingBehavior is Test {
    function _subject() internal view virtual returns (IUniswapV4Detf);
    function _buyer() internal view virtual returns (address);
    function _hookPackage() internal view virtual returns (address);
    function _purchase(uint256 amount_) internal virtual returns (uint256 id_, uint256 lp_);
    function _leadPayment() internal view virtual returns (address);

    function test_bindingFirstBondPaymentPreviewMatchesEveryWalletDebit() public {
        address[] memory accepted_ = _subject().acceptedBondTokens();
        assertGt(accepted_.length, 1);
        for (uint256 i_; i_ < accepted_.length; ++i_) assertNotEq(accepted_[i_], address(_subject()), "DETF is minted separately, not paid by the first bonder");
        // Each fixture's first payment is its unsorted lead token, not necessarily accepted_[0].
        address lead_ = _leadPayment();
        (address[] memory tokens_, uint256[] memory amounts_) = _subject().previewFirstBondPayments(IERC20(lead_), 1_000 ether);
        assertEq(tokens_.length, accepted_.length);
        uint256[] memory before_ = new uint256[](tokens_.length);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            before_[i_] = IERC20(tokens_[i_]).balanceOf(_buyer());
            assertGt(amounts_[i_], 0);
        }
        _purchase(1_000 ether);
        for (uint256 i_; i_ < tokens_.length; ++i_) assertEq(before_[i_] - IERC20(tokens_[i_]).balanceOf(_buyer()), amounts_[i_]);
        vm.expectRevert(); _subject().previewFirstBondPayments(IERC20(lead_), 1_000 ether);
    }


    function _stake() internal view returns (IStakedDETF) {
        return IStakedDETF(_subject().rebasingClaimToken());
    }

    function _positions() internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(_subject().bondNftVault());
    }

    function test_bindingHookComponentsFitAndSelectorsAreInstalled() public view {
        address pkg_ = _hookPackage();
        assertLe(pkg_.code.length, 24_576, "hook package runtime");
        address[] memory facets_ = IDiamondFactoryPackage(pkg_).facetAddresses();
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertGt(facets_[i_].code.length, 0, "missing facet bytecode");
            assertLe(facets_[i_].code.length, 24_576, IFacet(facets_[i_]).facetName());
            if (i_ < 4) continue; // Initialization facets are removed during finalization.
            bytes4[] memory selectors_ = IFacet(facets_[i_]).facetFuncs();
            for (uint256 j_; j_ < selectors_.length; ++j_) {
                assertEq(IDiamondLoupe(_subject().hook()).facetAddress(selectors_[j_]), facets_[i_]);
            }
        }
    }

    function test_bindingRetiredLpClaimProjectionSelectorsAreAbsent() public view {
        IDiamondLoupe hook_ = IDiamondLoupe(_subject().hook());
        assertEq(hook_.facetAddress(bytes4(keccak256("previewClaimAfterJoin(uint256,uint256)"))), address(0));
        assertEq(hook_.facetAddress(bytes4(keccak256("previewClaimExit(uint256)"))), address(0));
    }

    function test_bindingHasNativeNineDecimalChildren() public view {
        address detf_ = address(_subject());
        assertEq(IERC20Metadata(detf_).decimals(), 9);
        assertEq(_stake().decimals(), 9);
        assertEq(_stake().detf(), detf_);
        IDETFStandardizedYield children_ = IDETFStandardizedYield(detf_);
        IStandardizedYield raw_ = IStandardizedYield(children_.rawSY());
        IStandardizedYield staked_ = IStandardizedYield(children_.stakingSY());
        assertEq(raw_.decimals(), 9);
        assertEq(staked_.decimals(), 9);
        assertEq(raw_.yieldToken(), detf_);
        assertEq(staked_.yieldToken(), address(_stake()));
        assertEq(raw_.exchangeRate(), 1e18);
    }

    function test_bindingFirstBondFundsPrincipalSeparatelyFromOwnedLP() public {
        (uint256 id_, uint256 lp_) = _purchase(1_000 ether);
        Math.BondPosition memory position_ = _positions().positionOf(id_);
        assertGt(position_.principal, 0);
        assertEq(position_.claimedPrincipal, 0);
        assertEq(position_.startTimestamp, block.timestamp);
        assertGt(lp_, 0);
        assertGe(IERC20(_subject().hook()).balanceOf(address(_positions())), lp_);
        assertGe(_stake().balanceOf(address(_positions())), position_.principal);
        uint256 held_ = IERC20(address(_subject())).balanceOf(address(_stake()));
        assertEq(held_, _stake().stakingState().accountedBacking);
        assertGe(held_, _stake().totalSupply());
        assertEq(IERC20(address(_subject())).balanceOf(_buyer()), 0);
    }

    function test_bindingHalfwayPrincipalUnstakesWithoutLPWithdrawal() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory p_ = _positions().positionOf(id_);
        vm.warp(p_.startTimestamp + p_.vestingDuration / 2);
        vm.startPrank(_buyer());
        uint256 claimed_ = _positions().claimPrincipal(id_, _buyer());
        vm.stopPrank();
        assertEq(claimed_, p_.principal / 2);
        uint256 lp_ = IERC20(_subject().hook()).balanceOf(address(_positions()));
        IStakedDETF staking_ = _stake();
        vm.startPrank(_buyer());
        uint256 raw_ = staking_.exchangeIn(
            IERC20(address(staking_)), claimed_, IERC20(address(_subject())),
            claimed_, _buyer(), false, block.timestamp
        );
        vm.stopPrank();
        assertEq(raw_, claimed_);
        assertEq(IERC20(address(_subject())).balanceOf(_buyer()), claimed_);
        assertEq(IERC20(_subject().hook()).balanceOf(address(_positions())), lp_);
        assertEq(_positions().positionOf(id_).claimedPrincipal, claimed_);
    }

    function test_bindingRewardsClaimWhilePrincipalRemainsLocked() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory before_ = _positions().positionOf(id_);
        vm.startPrank(_buyer());
        uint256 reward_ = _positions().claimRewards(id_, _buyer());
        vm.stopPrank();
        assertGt(reward_, 0, "funded immediate seigniorage");
        assertEq(_stake().balanceOf(_buyer()), reward_);
        Math.BondPosition memory after_ = _positions().positionOf(id_);
        assertEq(after_.principal, before_.principal);
        assertEq(after_.claimedPrincipal, 0);
        assertEq(after_.startTimestamp, before_.startTimestamp);
        assertEq(_positions().previewClaim(id_).principalDue, 0);
    }

    function test_bindingStaticSYReceivesLaterFundedBondRewards() public {
        (uint256 id_,) = _purchase(1_000 ether);
        Math.BondPosition memory position_ = _positions().positionOf(id_);
        vm.warp(position_.startTimestamp + position_.vestingDuration);
        vm.startPrank(_buyer());
        (uint256 principal_, uint256 rewards_) = _positions().claimBond(id_, _buyer());
        vm.stopPrank();
        IStandardizedYield sy_ = IStandardizedYield(
            IDETFStandardizedYield(address(_subject())).stakingSY()
        );
        IStakedDETF staking_ = _stake();
        vm.startPrank(_buyer());
        staking_.approve(address(sy_), principal_ + rewards_);
        uint256 shares_ = sy_.deposit(_buyer(), address(staking_), principal_ + rewards_, 0);
        vm.stopPrank();
        uint256 rate_ = sy_.exchangeRate();
        _purchase(10 ether);
        assertEq(sy_.balanceOf(_buyer()), shares_);
        assertGt(sy_.exchangeRate(), rate_);
        uint256 quoted_ = sy_.previewRedeem(address(_subject()), shares_);
        vm.prank(_buyer());
        uint256 raw_ = sy_.redeem(_buyer(), shares_, address(_subject()), quoted_, false);
        assertEq(raw_, quoted_);
        assertGt(raw_, principal_ + rewards_);
        assertGe(IERC20(address(_subject())).balanceOf(address(staking_)), staking_.totalSupply());
    }
}

contract WeightedFundedBindingTest is TestBase_UniswapV4Detf_Weighted, V4FundedBindingBehavior, DETFFundedStakingArtifacts {
    function _hookPackage() internal view override returns (address) { return address(weightedHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}

contract OrbitalFundedBindingTest is TestBase_UniswapV4Detf_Orbital, V4FundedBindingBehavior, DETFFundedStakingArtifacts {
    function _hookPackage() internal view override returns (address) { return address(orbitalHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}

contract CurveQuadFundedBindingTest is TestBase_UniswapV4Detf_CurveQuad, V4FundedBindingBehavior, DETFFundedStakingArtifacts {
    function _hookPackage() internal view override returns (address) { return address(curveHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return address(pairToken); }
}


import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";
import {IStandardExchangeTransitionQuote as ITransition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_Univ4Se} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol";

/// @notice The same funded bond/SY behavior backed by two actual V4 full-range position vaults.
contract OrbitalV4PositionFundedBindingTest is TestBase_UniswapV4Detf_Orbital_Univ4Se, V4FundedBindingBehavior, DETFFundedStakingArtifacts {
    function setUp() public override {
        super.setUp();
        _activatePositionVault(se0, sePoolKey0);
        _activatePositionVault(se1, sePoolKey1);
    }

    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args_) {
        args_ = super._defaultDetfArgs();
        args_.ownerOnlyLiquidity = false;
    }

    function _activatePositionVault(address vault_, PoolKey memory key_) private {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = Currency.unwrap(key_.currency0);
        tokens_[1] = Currency.unwrap(key_.currency1);
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            amounts_[i_] = 1_000 ether;
            SimpleMintableERC20(tokens_[i_]).mint(address(this), amounts_[i_]);
            IERC20(tokens_[i_]).approve(vault_, amounts_[i_]);
        }
        uint256 shares_ = IStandardExchangeInMulti(vault_).exchangeInManyToOne(
            tokens_, amounts_, IERC20(vault_), 1, address(this), false, block.timestamp
        );
        assertGt(shares_, 0, "both funded tokens activate the position vault");
    }

    function _hookPackage() internal view override returns (address) { return address(orbitalHookPkg); }
    function _subject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _buyer() internal view override returns (address) { return detfUser; }
    function _purchase(uint256 amount_) internal override returns (uint256, uint256) { return _firstBond(amount_); }
    function _leadPayment() internal view override returns (address) { return mintToken; }

    function test_bindingPositionShareInputsRedeemThroughEveryNativeSyOutput() public {
        _purchase(1_000 ether);
        _measurePositionWithdrawalQuotes(se0, pairAddr0);
        _measurePositionWithdrawalQuotes(se1, pairAddr1);
        IStandardizedYield sy_ = IStandardizedYield(detfInfo.hook());
        address[] memory outputs_ = sy_.getTokensOut();
        for (uint256 i_; i_ < 2; ++i_) {
            IERC20 input_ = IERC20(i_ == 0 ? se0 : se1);
            uint256 amount_ = input_.balanceOf(address(this)) / 1_000;
            assertGt(amount_, 0);
            for (uint256 j_; j_ < outputs_.length; ++j_) {
                uint256 snapshot_ = vm.snapshotState();
                input_.transfer(detfUser, amount_);
                _positionShareSyRoundTrip(sy_, input_, amount_, IERC20(outputs_[j_]));
                assertTrue(vm.revertToStateAndDelete(snapshot_));
            }
        }
    }

    function testFuzz_bindingPositionShareDepositWithinChainGasLimit(bool second_, uint96 amountSeed_) public {
        _purchase(1_000 ether);
        IERC20 input_ = IERC20(second_ ? se1 : se0);
        uint256 available_ = input_.balanceOf(address(this));
        uint256 amount_ = bound(uint256(amountSeed_), available_ / 100_000, available_ / 100);
        input_.transfer(detfUser, amount_);
        _positionShareSyRoundTrip(IStandardizedYield(detfInfo.hook()), input_, amount_, IERC20(detf));
    }

    function test_bindingPositionShareGasCounterexample() public {
        testFuzz_bindingPositionShareDepositWithinChainGasLimit(false, 16222);
    }

    function test_bindingV4LpPaymentKeepsBufferAssetsAndFitsChainGasBudget() public {
        _purchase(1_000 ether);
        IStandardizedYield sy_ = IStandardizedYield(detfInfo.hook());
        IERC20 input_ = IERC20(se0);
        uint256 amount_ = input_.balanceOf(address(this)) / 1_000;
        input_.transfer(detfUser, amount_);
        uint256 minimum_ = sy_.previewDeposit(address(input_), amount_);
        vm.startPrank(detfUser);
        input_.approve(address(sy_), amount_);
        uint256 lp_ = _measuredPositionSyDeposit(sy_, input_, amount_, minimum_);
        vm.stopPrank();
        _assertV4PositionLpBond(sy_, lp_);
    }

    function _quoteV4PositionLpBond(IStandardizedYield lp_, uint256 amount_)
        private view returns (uint256 principal_, uint256 rewards_)
    {
        IUniswapV4SeBufferHook reserve_ = IUniswapV4SeBufferHook(address(lp_));
        address[] memory tokens_ = reserve_.tokens();
        uint256[] memory assets_ = reserve_.previewExitProportional(amount_);
        uint256 expected_;
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] != detf && assets_[i_] != 0) {
                expected_ += reserve_.previewSwapExactIn(tokens_[i_], detf, assets_[i_] * 3 / 2);
            }
        }
        uint256 gross_;
        uint256 join_;
        (gross_, principal_, rewards_, join_) =
            detfInfo.previewBond(IERC20(address(lp_)), amount_, 180 days);
        assertEq(gross_, expected_, "V4 buffers valued once, self-leg excluded, bonus once");
        assertEq(join_, 0);
    }

    function _assertV4PositionLpBond(IStandardizedYield lp_, uint256 amount_) private {
        (uint256 principal_, uint256 rewards_) = _quoteV4PositionLpBond(lp_, amount_);
        uint256[4] memory before_ = [
            IERC20(detf).totalSupply(), lp_.totalSupply(),
            IERC20(detf).balanceOf(address(lp_)), lp_.balanceOf(detfInfo.bondNftVault())
        ];
        vm.startPrank(detfUser);
        lp_.approve(detf, amount_);
        (uint256 id_, uint256 acquired_) = detfInfo.bond{gas: 31_000_000}(
            IERC20(address(lp_)), amount_, 180 days, detfUser, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(acquired_, amount_);
        assertEq(lp_.balanceOf(detfUser), 0);
        assertEq(lp_.balanceOf(detfInfo.bondNftVault()), before_[3] + amount_);
        assertEq(lp_.totalSupply(), before_[1], "received LP retained without another join or unwind");
        assertEq(IERC20(detf).balanceOf(address(lp_)), before_[2], "existing DETF inventory retained");
        assertEq(IERC20(detf).totalSupply(), before_[0] + principal_ + rewards_);
        assertEq(_positions().positionOf(id_).principal, principal_);
        assertEq(_positions().previewClaim(id_).principalDue, 0);
        assertGt(_positions().previewClaim(id_).rewardsDue, 0);
        assertGe(IERC20(detf).balanceOf(address(_stake())), _stake().totalSupply());
    }

    function _positionShareSyRoundTrip(IStandardizedYield sy_, IERC20 in_, uint256 amount_, IERC20 out_) private {
        _assertCachedBufferClaim(address(in_), address(sy_), amount_);
        emit log_named_address("SY input", address(in_));
        emit log_named_address("SY output", address(out_));
        uint256 detfSupply_ = IERC20(detf).totalSupply();
        uint256 stakingFunding_ = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());
        uint256 quote_ = sy_.previewDeposit(address(in_), amount_);
        assertGt(quote_, 0);
        uint256 payment_ = in_.balanceOf(detfUser);
        vm.startPrank(detfUser);
        in_.approve(address(sy_), amount_);
        uint256 shares_ = _measuredPositionSyDeposit(sy_, in_, amount_, quote_);
        vm.stopPrank();
        assertEq(shares_, quote_, "V4 position-share deposit preview matches execution");
        assertEq(in_.balanceOf(detfUser), payment_ - amount_);
        quote_ = sy_.previewRedeem(address(out_), shares_);
        assertGt(quote_, 0);
        uint256 balance_ = out_.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = _measuredPositionSyRedeem(sy_, out_, shares_, quote_);
        assertEq(paid_, quote_, "V4 position-backed exit preview matches execution");
        assertEq(out_.balanceOf(detfUser), balance_ + paid_);
        assertEq(sy_.balanceOf(detfUser), 0);
        assertEq(IERC20(detf).totalSupply(), detfSupply_);
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()), stakingFunding_);
    }

    function _assertCachedBufferClaim(address se_, address hook_, uint256 amount_) private view {
        address token_ = se_ == se0 ? pairAddr0 : pairAddr1;
        ClaimLib.BufferClaimQuote memory quote_ = ClaimLib.bufferClaimQuote(se_, address(0), token_, hook_);
        assertEq(
            ClaimLib.previewBufferClaimIn(quote_, amount_),
            ClaimLib.previewBufferClaimIn(se_, address(0), token_, amount_, hook_),
            "cached balance and claim preserve the existing forward quote"
        );
    }

    function _measurePositionWithdrawalQuotes(address se_, address token_) private {
        uint256 start_ = gasleft();
        uint256 shares_ = IStandardExchangeOut(se_).previewExchangeOut(IERC20(se_), IERC20(token_), 1 ether);
        emit log_named_uint("Standard exact-output quote gas", start_ - gasleft());
        start_ = gasleft();
        (bytes memory state_,) = ITransition(se_).quoteState(token_, detfInfo.hook());
        (, uint256 projected_,,) = ITransition(se_).quoteTransition(state_, ITransition.Operation.WithdrawExactOut, 1 ether);
        emit log_named_uint("State-based exact-output quote gas", start_ - gasleft());
        assertEq(projected_, shares_, "state-based and standard withdrawal shares agree");
    }

    function _measuredPositionSyDeposit(IStandardizedYield sy_, IERC20 in_, uint256 amount_, uint256 minimum_)
        private returns (uint256 shares_)
    {
        uint256 start_ = gasleft();
        // Robinhood mainnet reports a 32M transaction limit. Leave execution
        // headroom and exercise the actual assembled proxy within that budget.
        shares_ = sy_.deposit{gas: 31_000_000}(detfUser, address(in_), amount_, minimum_);
        emit log_named_uint("SY deposit execution gas", start_ - gasleft());
    }

    function _measuredPositionSyRedeem(IStandardizedYield sy_, IERC20 out_, uint256 shares_, uint256 minimum_)
        private returns (uint256 amount_)
    {
        uint256 start_ = gasleft();
        amount_ = sy_.redeem{gas: 31_000_000}(detfUser, shares_, address(out_), minimum_, false);
        emit log_named_uint("SY redeem execution gas", start_ - gasleft());
    }

}
