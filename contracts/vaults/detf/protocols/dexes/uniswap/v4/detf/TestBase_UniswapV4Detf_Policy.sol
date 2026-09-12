// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Identical funded settlement and policy assertions over real reserve/provider fixtures.
abstract contract V4FundedPolicyAssertions is Test {
    function _fundedPolicyUser() internal view virtual returns (address);
    function _fundedPolicyMintToken(address d) internal view virtual returns (IERC20);
    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal virtual;
    function _fundedPolicySkewDown(address d) internal virtual;
    function _fundedPolicyPushUp(address d) internal virtual;
    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal virtual;
    function _fundedPolicyBond(address d, uint256 amount) internal virtual;
    function _fundedPolicyDonate(address d, uint256 amount) internal virtual;
    function _fundedPolicyLock() internal pure virtual returns (uint256);

    function _fundedPolicyLp(address d) private view returns (uint256) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        return IERC20(info.hook()).balanceOf(info.bondNftVault());
    }

    function _policyTokenUnits(IERC20 token_, uint256 whole_) internal view returns (uint256) {
        return whole_ * 10 ** IERC20Metadata(address(token_)).decimals();
    }

    /// @dev Move the live reserve with actual user trades in native token units.
    /// Each purchase is small relative to its current reserve and checks the
    /// same preview, payment and payout deltas as an external market participant.
    function _policyBuyFromReserve(address d) internal {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory reserves_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(IERC20(hook_).totalSupply());
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            uint256 amount_ = reserves_[i_] / 20;
            assertGt(amount_, 0, "funded public market input");
            _fundedPolicyFundToken(tokens_[i_], _fundedPolicyUser(), amount_);
            _policyPublicTrade(hook_, IERC20(tokens_[i_]), IERC20(d), amount_);
            if (IUniswapV4Detf(d).isMintingAllowed(_fundedPolicyMintToken(d))) return;
        }
    }

    function _policyPublicTrade(address hook_, IERC20 input_, IERC20 output_, uint256 amount_) internal {
        address user_ = _fundedPolicyUser();
        uint256 quote_ = IStandardExchangeIn(hook_).previewExchangeIn(input_, amount_, output_);
        uint256[2] memory before_ = [input_.balanceOf(user_), output_.balanceOf(user_)];
        vm.startPrank(user_);
        input_.approve(hook_, amount_);
        uint256 paid_ = IStandardExchangeIn(hook_)
            .exchangeIn(input_, amount_, output_, quote_, user_, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(paid_, quote_, "public reserve preview/execution");
        assertEq(before_[0] - input_.balanceOf(user_), amount_, "actual public payment");
        assertEq(output_.balanceOf(user_) - before_[1], paid_, "actual public payout");
    }

    /// @dev Keep distinct reserve-pair gates: a public trade may close one pair
    /// while another still permits primary issuance. Both standard routes execute.
    function _assertPairPolicyWithPublicTrades(address d, IERC20 pairA_, IERC20 pairB_) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        _fundedPolicyEnsureRaw(d, 1e9);
        address user_ = _fundedPolicyUser();
        for (uint256 i_; i_ < 48 && (info_.isMintingAllowed(pairB_) || !info_.isMintingAllowed(pairA_)); ++i_) {
            uint256 donation_ = _policyTokenUnits(pairA_, 50);
            _fundedPolicyFundToken(address(pairA_), user_, donation_);
            vm.startPrank(user_);
            pairA_.approve(d, donation_);
            pairA_.approve(info_.bondNftVault(), donation_);
            info_.donate(pairA_, donation_, false);
            vm.stopPrank();
            uint256 balance_ = IERC20(d).balanceOf(user_);
            if (balance_ < 1e9) {
                _assertStandardSettlementOrder(d, pairA_, _policyTokenUnits(pairA_, 10), IERC20(d));
                balance_ = IERC20(d).balanceOf(user_);
            }
            uint256 input_ = balance_ / 2;
            uint256 reserveBudget_ = IERC20(d).balanceOf(info_.hook()) / 10;
            if (input_ > reserveBudget_) input_ = reserveBudget_;
            assertGt(input_, 0, "funded DETF available for public reserve swap");
            _policyPublicTrade(info_.hook(), IERC20(d), pairB_, input_);
        }
        assertTrue(info_.isMintingAllowed(pairA_), "A primary mint gate open");
        assertFalse(info_.isMintingAllowed(pairB_), "B primary mint gate closed");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, pairB_, _policyTokenUnits(pairB_, 1), IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "B uses funded reserve swap");
        assertTrue(info_.isMintingAllowed(pairA_), "A primary route remains available");
        supply_ = IERC20(d).totalSupply();
        _assertStandardSettlementOrder(d, pairA_, _policyTokenUnits(pairA_, 10), IERC20(d));
        assertGt(IERC20(d).totalSupply(), supply_, "A executes new issuance");
    }

    function _policyBurnToken(address d) internal view returns (IERC20) {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IUniswapV4Detf.IoRoute[] memory routes_ = info_.burnRoutes();
        for (uint256 i_; i_ < routes_.length; ++i_) {
            if (info_.isBurningAllowed(routes_[i_].token)) return routes_[i_].token;
        }
        return _fundedPolicyMintToken(d);
    }

    function _policyFundedState(address d, IERC20 in_, IERC20 out_) internal view returns (bytes32) {
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        bytes32 funded_ = keccak256(
            abi.encode(
                staking_.stakingState(),
                IERC20(d).totalSupply(),
                IERC20(d).balanceOf(address(staking_)),
                _fundedPolicyLp(d)
            )
        );
        return keccak256(
            abi.encode(
                funded_,
                in_.balanceOf(_fundedPolicyUser()),
                out_.balanceOf(_fundedPolicyUser()),
                IUniswapV4Detf(d).pendingExpansionDetf()
            )
        );
    }

    /// @dev Compare projected preview and implicit settlement with explicit settlement
    /// followed by the identical standard route, including a failed-minimum rollback.
    function _assertStandardSettlementOrder(address d, IERC20 in_, uint256 amount_, IERC20 out_)
        internal
        returns (uint256 paid_)
    {
        if (address(in_) != d) _fundedPolicyFundToken(address(in_), _fundedPolicyUser(), amount_);
        vm.prank(_fundedPolicyUser());
        in_.approve(d, amount_);
        IStandardExchangeIn exchange_ = IStandardExchangeIn(d);
        uint256 quote_ = exchange_.previewExchangeIn(in_, amount_, out_);
        assertGt(quote_, 0, "executable standard route");
        bytes32 before_ = _policyFundedState(d, in_, out_);
        vm.prank(_fundedPolicyUser());
        vm.expectRevert();
        exchange_.exchangeIn(in_, amount_, out_, quote_ + 1, _fundedPolicyUser(), false, block.timestamp + 1 hours);
        assertEq(_policyFundedState(d, in_, out_), before_, "failed final minimum restores funding and payment");
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(d).synchronizeRewards();
        vm.prank(_fundedPolicyUser());
        uint256 explicit_ =
            exchange_.exchangeIn(in_, amount_, out_, quote_, _fundedPolicyUser(), false, block.timestamp + 1 hours);
        bytes32 after_ = _policyFundedState(d, in_, out_);
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        vm.prank(_fundedPolicyUser());
        paid_ = exchange_.exchangeIn(in_, amount_, out_, quote_, _fundedPolicyUser(), false, block.timestamp + 1 hours);
        assertEq(paid_, quote_, "projected preview equals actual payout");
        assertEq(paid_, explicit_, "same payout after explicit settlement");
        assertEq(_policyFundedState(d, in_, out_), after_, "same funded state and token deltas");
    }

    function _assert_T7_8_policy_isMintingAllowed_token(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(IERC20Metadata(d).decimals(), 9, "native DETF decimals");
        assertEq(info.mintThreshold(), 1.05e18);
        assertEq(info.burnThreshold(), 0.95e18);
        assertTrue(info.isReserveLive(), "live");
        IUniswapV4Detf.IoRoute[] memory routes_ = info.mintRoutes();
        assertGt(routes_.length, 0, "mintRoutes");
        bool any_;
        for (uint256 i; i < routes_.length; ++i) {
            bool expectedGate_ = _policyRouteSynthetic(d, address(routes_[i].vault)) > info.mintThreshold();
            bool tok_ = info.isMintingAllowed(routes_[i].token);
            assertEq(tok_, expectedGate_, "H8 token gate");
            if (tok_) any_ = true;
        }
        assertEq(info.isMintingAllowed(), any_, "no-arg iff some mintRoutes token");
        assertFalse(info.isMintingAllowed(IERC20(address(this))), "unknown token");
    }

    /// @dev Each route uses its own reserve pair and creation price.
    function _policyRouteSynthetic(address d, address vault_) internal view returns (uint256) {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        address hook_ = info_.hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory creation_ = info_.creationPairPerDetfWad();
        uint256 pairIndex_;
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            if (IUniswapV4SeBufferHook(hook_).standardExchangeOf(tokens_[i_]) == vault_) {
                IDetfReserveQuote.DetfQuoteCtx memory ctx_ = IDetfReserveQuote.DetfQuoteCtx({
                    detfTotalSupply: IERC20(d).totalSupply() * 1e9,
                    pendingExpansion: 0,
                    ownedLp: IERC20(hook_).balanceOf(d) + IERC20(hook_).balanceOf(info_.bondNftVault()),
                    creationPairPerDetfWad: creation_[pairIndex_]
                });
                return IDetfReserveQuote(hook_).previewSynthetic(ctx_, tokens_[i_]);
            }
            ++pairIndex_;
        }
        revert("policy route has no reserve pair");
    }

    function _assert_policy_mint_blocked_in_deadband_then_allowed_after_push(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 token_ = _fundedPolicyMintToken(d);
        assertTrue(info_.isMintingAllowed(token_), "rich launch has primary issuance");
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
        for (uint256 i_; i_ < 24 && info_.isMintingAllowed(token_); ++i_) {
            _fundedPolicySkewDown(d);
        }
        assertFalse(info_.isMintingAllowed(token_), "closed primary mint gate");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "closed mint executes supply-neutral swap");
        for (uint256 i_; i_ < 24 && !info_.isMintingAllowed(token_); ++i_) {
            _fundedPolicyPushUp(d);
        }
        assertTrue(info_.isMintingAllowed(token_), "funded reserve change reopens issuance");
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
    }

    function _assert_policy_burn_allowed_when_synthetic_below_burnThreshold(address d) internal virtual {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        _fundedPolicyEnsureRaw(d, 1e9);
        IERC20 token_ = _fundedPolicyMintToken(d);
        // Move the route we will redeem. Splitting the finite funded DETF across
        // every Quad leg can exhaust it before any individual burn gate opens.
        for (uint256 i_; i_ < 24 && !info_.isBurningAllowed(token_); ++i_) {
            uint256 input_ = IERC20(d).balanceOf(_fundedPolicyUser()) / 2;
            uint256 budget_ = IERC20(d).balanceOf(info_.hook()) / 10;
            if (input_ > budget_) input_ = budget_;
            assertGt(input_, 0, "funded DETF available to open the burn route");
            _policyPublicTrade(info_.hook(), IERC20(d), token_, input_);
        }
        assertTrue(info_.isBurningAllowed(token_), "funded reserve swaps open primary burn");
        uint256 amount_ = IERC20(d).balanceOf(_fundedPolicyUser()) / 10;
        assertGt(amount_, 0, "actual DETF to redeem");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, IERC20(d), amount_, token_);
        assertEq(IERC20(d).totalSupply(), supply_ + pending_ - amount_, "primary burn removes supplied DETF");
    }

    function _assert_open_never_expands(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        assertLe(info_.syntheticPrice(), 1e18, "no premium eligible for expansion");
        assertGt(info_.mintThreshold(), info_.burnThreshold(), "mandatory gates remain configured");
        vm.warp(block.timestamp + 8 hours * 50);
        assertEq(info_.pendingExpansionDetf(), 0, "no funded premium to expand");
        IERC20 token_ = _fundedPolicyMintToken(d);
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(info_.pendingExpansionDetf(), 0, "completed boundaries consumed");
    }

    function _assert_D31_1_policyMint_realizesThenGates(address d) internal {
        vm.warp(block.timestamp + 25 hours);
        assertGt(IUniswapV4Detf(d).pendingExpansionDetf(), 0, "funded rich-launch premium");
        IERC20 token_ = _fundedPolicyMintToken(d);
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
    }

    /// @dev Establish the trigger on the real family book. Thirty years at 5%
    /// need not close every opening premium. Each probe is rolled back before
    /// the actual preview/implicit-settlement comparison below.
    function _warpUntilSettlementClosesMint(address d, IERC20 token_) private {
        uint256 start_ = block.timestamp;
        uint256 elapsed_ = 30 * 365 days;
        for (uint256 i_; i_ < 8; ++i_) {
            vm.warp(start_ + elapsed_);
            uint256 snapshot_ = vm.snapshotState();
            IDETFFundedRewards(d).synchronizeRewards();
            bool closed_ = !IUniswapV4Detf(d).isMintingAllowed(token_);
            assertTrue(vm.revertToStateAndDelete(snapshot_));
            if (closed_) return;
            elapsed_ *= 2;
        }
        revert("fixture cannot establish post-expansion gate closure");
    }

    function _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 token_ = _fundedPolicyMintToken(d);
        assertTrue(info_.isMintingAllowed(token_), "stored price initially permits primary mint");
        _warpUntilSettlementClosesMint(d, token_);
        uint256 pending_ = info_.pendingExpansionDetf();
        assertGt(pending_, 0, "uncapped aggregate expansion due");
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(d).synchronizeRewards();
        assertFalse(info_.isMintingAllowed(token_), "settlement closes primary gate");
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        uint256 supply_ = IERC20(d).totalSupply();
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "post-expansion swap has no issuance");
    }

    function _assert_D31_3_policyBurn_realizesThenGates(address d) internal virtual {
        _fundedPolicyEnsureRaw(d, 1e9);
        vm.warp(block.timestamp + 25 hours);
        _assertStandardSettlementOrder(d, IERC20(d), IERC20(d).balanceOf(_fundedPolicyUser()) / 10, _policyBurnToken(d));
    }

    function _assert_D31_4_openMintDoesNotExpand(address d) internal {
        _assert_open_never_expands(d);
    }

    function _assert_compound_raises_protocolLp(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IDETFFundedRewards(d).synchronizeRewards();
        IERC20 token_ = _fundedPolicyMintToken(d);
        uint256 amount_ = _policyTokenUnits(token_, 10);
        (, uint256 principal_, uint256 rewards_,) = info_.previewBond(token_, amount_, _fundedPolicyLock());
        address staking_ = info_.rebasingClaimToken();
        uint256 backing_ = IERC20(d).balanceOf(staking_);
        _fundedPolicyBond(d, amount_);
        assertEq(IERC20(d).balanceOf(staking_), backing_ + principal_ + rewards_, "issuance funds staking immediately");
        uint256 lp_ = _fundedPolicyLp(d);
        assertEq(IDETFFundedRewards(d).synchronizeRewards(), 0, "same epoch has no second distribution");
        assertEq(_fundedPolicyLp(d), lp_, "reward settlement does not join LP");
    }

    function _assert_donate_doesNotRealizeExpansion(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 supply_ = IERC20(d).totalSupply();
        _fundedPolicyDonate(d, _policyTokenUnits(_fundedPolicyMintToken(d), 6));
        assertEq(IERC20(d).totalSupply(), supply_, "DN12 supply (no realize mint)");
        uint256 pendingAfter_ = info.pendingExpansionDetf();
        // Donate changes spot S so the pending *view* can move; realize would mint and consume it.
        if (pending_ > 0) {
            assertGt(pendingAfter_, 0, "DN12 pending not consumed");
        }
    }
}

/**
 * @title TestBase_UniswapV4Detf_Policy
 * @notice Policy / opening helpers for unified Uni V4 DETF. Does not edit TestBase_UniswapV4Detf.
 * @dev PRD UNIFIED_DETF_DEPRECATION_TEST_COVERAGE §5.1 / §7.2.
 *      Launch-rich opening starts at 1.1e18, +0.05e18 per step, max 24 (cap 2.25e18).
 *      Recorded mint-open WAD on gold CP: 2.20e18 (synthetic ~1.073e18).
 *      Do not prank(detf) to LP the hook before first bond.
 */
abstract contract TestBase_UniswapV4Detf_Policy is TestBase_UniswapV4Detf, V4FundedPolicyAssertions {
    uint256 internal constant POLICY_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant POLICY_BURN_THRESHOLD = 0.95e18;
    uint256 internal constant POLICY_EXPANSION_EPOCH = 8 hours;
    uint256 internal constant POLICY_EXPANSION_RATE = 0.05e18;
    uint256 internal constant POLICY_EXPANSION_CATCHUP = 4;
    uint256 internal constant FEE_P = 5e16;
    uint256 internal constant FEE_F = 12e16;
    uint256 internal constant FEE_C = 28e16;
    uint256 internal constant LAUNCH_RICH_START = 1.1e18;
    uint256 internal constant LAUNCH_RICH_STEP = 0.05e18;
    uint256 internal constant LAUNCH_RICH_MAX_STEPS = 24;
    uint256 internal constant FIRST_BOND_AMT = 100 ether;
    uint256 internal constant LIVE_MINT_AMT = 10 ether;
    uint256 internal constant ONE_WAD = 1e18;

    address internal policyCreator;
    address internal policyDetf;
    IUniswapV4Detf internal policyInfo;
    IERC20 internal policyMintToken;
    uint256 internal launchRichOpeningWad;
    uint256 internal _policyDeployNonce;
    mapping(address => uint256) internal _policyInitialBond;

    function setUp() public virtual override {
        TestBase_UniswapV4Detf.setUp();
        policyCreator = makeAddr("creator");
    }

    /// @dev n-leg gold overrides to `_nLegDetfArgs(pairCount)`.
    function _baseArgs() internal virtual returns (IUniswapV4Detf.PkgArgs memory) {
        return _defaultDetfArgs();
    }

    /// @notice Policy PkgArgs: ThresholdMode.Policy, mint 1.05e18, burn 0.95e18, expansion 0.
    function _policyArgs() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _baseArgs();
        args.name = "UniV4 DETF Policy";
        args.symbol = "uv4P";
        args.mintThreshold = POLICY_MINT_THRESHOLD;
        args.burnThreshold = POLICY_BURN_THRESHOLD;
        args.expansionClosureRatePerYearWad = 0;
        args.creator = policyCreator;
    }

    /// @notice Annual 5% closure with fixed eight-hour epochs and uncapped aggregate catch-up.
    function _policyD31Args() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _policyArgs();
        args.name = "UniV4 DETF D31";
        args.symbol = "uv4D31";
        args.expansionClosureRatePerYearWad = POLICY_EXPANSION_RATE;
    }

    /// @notice Mandatory-gated at-peg fixture; zero rate argument retains the existing default.
    function _openArgsPolicy() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _baseArgs();
        args.name = "UniV4 DETF OpenPL";
        args.symbol = "uv4Opl";
        args.expansionClosureRatePerYearWad = 0;
        args.creator = policyCreator;
    }

    function _withTag(IUniswapV4Detf.PkgArgs memory args, string memory tag)
        internal
        pure
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        args.name = string.concat(args.name, " ", tag);
        args.symbol = string.concat(args.symbol, tag);
        return args;
    }

    function _withOpening(IUniswapV4Detf.PkgArgs memory args, uint256 wad)
        internal
        pure
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        uint256 n = args.creationPairPerDetfWad.length;
        uint256[] memory opening_ = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            opening_[i] = wad;
        }
        args.openingPairPerDetfWad = opening_;
        return args;
    }

    function _nextTag() internal returns (string memory) {
        unchecked {
            ++_policyDeployNonce;
        }
        return vm.toString(_policyDeployNonce);
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _setFeeOraclePfc(address vault_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(vault_, FEE_P) {}
            catch {}
        try IVaultFeeOracleManager(address(indexedexManager)).setSeignioragePotSharesOfVault(vault_, FEE_F, FEE_C) {}
            catch {}
        vm.stopPrank();
    }

    function _setBondTermsOn(address vault_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager))
            .setVaultBondTerms(
                vault_,
                BondTerms({
                    minLockDuration: DEFAULT_MIN_LOCK,
                    maxLockDuration: DEFAULT_MAX_LOCK,
                    minBonusPercentage: 0,
                    maxBonusPercentage: 0.5e18
                })
            ) {}
            catch {}
        vm.stopPrank();
    }

    function _mintTokenOf(address d) internal view virtual returns (IERC20 tok) {
        address[] memory toks_ = IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] != d) return IERC20(toks_[i]);
        }
        revert("no mintToken");
    }

    function _fundToken(address token_, address to_, uint256 amount_) internal virtual {
        IERC20 tok_ = IERC20(token_);
        if (tok_.balanceOf(to_) >= amount_) return;
        try SimpleMintableERC20(token_).mint(to_, amount_) {
            if (tok_.balanceOf(to_) >= amount_) return;
        } catch {}
        uint256 have_ = tok_.balanceOf(to_);
        deal(token_, to_, have_ + amount_);
        if (tok_.balanceOf(to_) >= amount_) return;
        uint256 need_ = amount_ - tok_.balanceOf(to_);
        if (detfUser != to_) {
            uint256 userBal_ = tok_.balanceOf(detfUser);
            uint256 send_ = userBal_ < need_ ? userBal_ : need_;
            if (send_ > 0) {
                vm.prank(detfUser);
                tok_.transfer(to_, send_);
            }
        }
        if (tok_.balanceOf(to_) < amount_) {
            _fundTokenFallback(token_, to_, amount_);
        }
    }

    /// @dev Pons/Morpho TestBases buy or seed when mint/deal cannot fund the token.
    function _fundTokenFallback(address, address, uint256) internal virtual {}

    function _fundPair(address to_, uint256 amount_) internal virtual {
        _fundToken(address(pairToken), to_, amount_);
    }

    function _fundAndApprove(address d) internal {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            _fundToken(toks_[i], detfUser, FIRST_BOND_AMT * 4);
        }
        vm.startPrank(detfUser);
        for (uint256 j; j < toks_.length; ++j) {
            if (toks_[j] == d) continue;
            IERC20(toks_[j]).approve(d, type(uint256).max);
            IERC20(toks_[j]).approve(hook_, type(uint256).max);
            address nft_ = IUniswapV4Detf(d).bondNftVault();
            if (nft_ != address(0)) IERC20(toks_[j]).approve(nft_, type(uint256).max);
        }
        IERC20(d).approve(d, type(uint256).max);
        IERC20(se).approve(d, type(uint256).max);
        vm.stopPrank();
    }

    function _bindPolicy(address d) internal {
        policyDetf = d;
        policyInfo = IUniswapV4Detf(d);
        policyMintToken = _mintTokenOf(d);
        _setFeeOraclePfc(d);
        _setBondTermsOn(d);
        _fundAndApprove(d);
    }

    function _firstBondOn(address d, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        IERC20 token_ = _mintTokenOf(d);
        bool first_ = !IUniswapV4Detf(d).isReserveLive();
        if (first_) {
            (address[] memory tokens_, uint256[] memory amounts_) =
                IUniswapV4Detf(d).previewFirstBondPayments(token_, amt);
            for (uint256 i_; i_ < tokens_.length; ++i_) {
                _fundToken(tokens_[i_], detfUser, amounts_[i_]);
                vm.prank(detfUser);
                IERC20(tokens_[i_]).approve(d, amounts_[i_]);
            }
        } else {
            _fundToken(address(token_), detfUser, amt);
            vm.prank(detfUser);
            token_.approve(d, amt);
        }
        vm.prank(detfUser);
        (tokenId, shares) = IUniswapV4Detf(d).bond(token_, amt, DEFAULT_MIN_LOCK, detfUser, false, _deadline());
        if (first_) _policyInitialBond[d] = tokenId;
    }

    function _mintOn(address d, uint256 amt) internal returns (uint256 userDetf) {
        IERC20 tok_ = _mintTokenOf(d);
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            _fundToken(toks_[i], detfUser, amt * 4);
        }
        vm.startPrank(detfUser);
        tok_.approve(d, type(uint256).max);
        userDetf = IStandardExchangeIn(d).exchangeIn(tok_, amt, IERC20(d), 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut) internal virtual returns (uint256 amountOut) {
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        amountOut = IStandardExchangeIn(d).exchangeIn(IERC20(d), detfIn, tokenOut, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    /// @dev Hook-specific TestBases override to deploy orbital/weighted/quad instead of CP.
    function _deployInstance(IUniswapV4Detf.PkgArgs memory args) internal virtual returns (address) {
        return _deployHookThenDetf(args);
    }

    function _deployTagged(IUniswapV4Detf.PkgArgs memory args, string memory tag) internal returns (address d) {
        d = _deployInstance(_withTag(args, tag));
        _bindPolicy(d);
    }

    /// @notice Find a rich opening using each real provider's measured reserve valuation.
    /// @dev Keep the candidate bound; provider fees and full-range backing affect the needed opening.
    function _deployPolicyLaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(false);
    }

    function _deployD31LaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(true);
    }

    function _deployLaunchRichLive(bool d31_) internal returns (address d) {
        uint256 wad = d31_ ? 2.2e18 : LAUNCH_RICH_START;
        IUniswapV4Detf info;
        // Policy trading needs the first rich candidate the actual host accepts.
        // A fixed 2.2 opening overprices Orbital for the available funded traders.
        // Keep the stronger premium for expansion-specific D31 scenarios.
        for (uint256 i; i <= LAUNCH_RICH_MAX_STEPS; ++i) {
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();
            args = _withOpening(_withTag(args, string.concat("lr", vm.toString(i), _nextTag())), wad);
            d = _deployInstance(args);
            _bindPolicy(d);
            _firstBondOn(d, FIRST_BOND_AMT);
            info = IUniswapV4Detf(d);
            assertTrue(info.isReserveLive(), "first bond live");
            emit log_named_uint("launchRichOpeningWad", wad);
            emit log_named_uint("syntheticAfterFirstBond", info.syntheticPrice());
            if (info.isMintingAllowed(_mintTokenOf(d)) && info.syntheticPrice() > info.mintThreshold()) {
                launchRichOpeningWad = wad;
                return d;
            }
            uint256 price_ = info.syntheticPrice();
            wad = price_ == 0
                ? wad + LAUNCH_RICH_STEP
                : wad * (info.mintThreshold() + 0.15e18) / price_ + LAUNCH_RICH_STEP;
        }
        launchRichOpeningWad = wad;
        revert("6.1 launch-rich isMintingAllowed still false after 24 steps");
    }

    function _deployOpenLive() internal returns (address d) {
        // A configured 1:1 opening is not necessarily a no-premium reserve
        // valuation (notably for Orbital). Set an explicit below-peg launch;
        // the shared no-expansion assertion still checks the actual price.
        d = _deployTagged(_withOpening(_openArgsPolicy(), 0.5e18), _nextTag());
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "open live");
        return d;
    }

    function _deployPolicyAtPegLive() internal returns (address d) {
        d = _deployTagged(_policyArgs(), _nextTag());
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "policy peg live");
        return d;
    }

    function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal pure returns (uint256) {
        return pairAmount_ * 1e9 / opening_;
    }

    function _detfReserveInHook(address d) internal view returns (uint256) {
        address hook_ = IUniswapV4Detf(d).hook();
        uint256 supply_ = IERC20(hook_).totalSupply();
        if (supply_ == 0) return 0;
        uint256[] memory amts_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(supply_);
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 n_ = toks_.length < amts_.length ? toks_.length : amts_.length;
        for (uint256 i; i < n_; ++i) {
            if (toks_[i] == d) return amts_[i];
        }
        return 0;
    }

    function _donateMintToken(address d, uint256 amount) internal {
        IERC20 tok_ = _mintTokenOf(d);
        _fundToken(address(tok_), detfUser, amount);
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        tok_.approve(nft_, amount);
        tok_.approve(d, amount);
        IUniswapV4Detf(d).donate(tok_, amount, false);
        vm.stopPrank();
    }

    function _pushSyntheticUp(address d) internal virtual {
        _policyBuyFromReserve(d);
    }

    function donateExternal(address d, uint256 amt) external {
        _donateMintToken(d, amt);
    }

    function donateTokenExternal(address d, address token, uint256 amt) external {
        _donateToken(d, token, amt);
    }

    /// @dev Donate DETF self-leg into Bond NFT. Joins DETF reserve and lowers S on every pair.
    function _donateDetfSelf(address d, uint256 amount) internal {
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        if (amount > bal_) amount = bal_;
        if (amount == 0) return;
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        IERC20(d).approve(nft_, amount);
        IDetfNftReserveDonation(nft_).donate(IERC20(d), amount, 0, false, _deadline());
        vm.stopPrank();
    }

    function _donateToken(address d, address token, uint256 amount) internal {
        if (token != d) {
            _fundToken(token, detfUser, amount);
        }
        uint256 have_ = IERC20(token).balanceOf(detfUser);
        if (have_ == 0) return;
        if (amount > have_) amount = have_;
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        IERC20(token).approve(nft_, amount);
        IERC20(token).approve(d, amount);
        try IUniswapV4Detf(d).donate(IERC20(token), amount, false) {} catch {}
        vm.stopPrank();
    }

    /// @dev Sell actually purchased DETF through public reserve swaps; never fabricate DETF balances.
    function _skewSyntheticDown(address d) internal virtual {
        _skewSyntheticDownAmt(d, 80e9);
    }

    function _skewSyntheticDownAmt(address d, uint256 detfAmt) internal {
        // Claim the funded opening purchase once, even when an ordinary mint
        // already supplied a small raw balance. Never retry a consumed NFT.
        if (_policyInitialBond[d] >= 3) {
            _ensureFreeDetf(d, IERC20(d).balanceOf(detfUser) + 1);
        }
        uint256 available_ = IERC20(d).balanceOf(detfUser) / 2;
        uint256 amount_ = detfAmt < available_ ? detfAmt : available_;
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 chunk_ = amount_ / (tokens_.length - 1);
        vm.startPrank(detfUser);
        IERC20(d).approve(hook_, amount_);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            IStandardExchangeIn(hook_)
                .exchangeIn(IERC20(d), chunk_, IERC20(tokens_[i_]), 0, detfUser, false, _deadline());
        }
        vm.stopPrank();
    }

    function _ensureFreeDetf(address d, uint256 amt) internal {
        if (IERC20(d).balanceOf(detfUser) >= amt) return;
        uint256 id_ = _policyInitialBond[d];
        assertGe(id_, 3, "funded initial bond available");
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d).bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 unlock_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < unlock_) vm.warp(unlock_);
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, detfUser);
        delete _policyInitialBond[d];
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 amount_ = principal_ + rewards_;
        vm.prank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(d), amount_, detfUser, false, _deadline());
        assertGe(IERC20(d).balanceOf(detfUser), amt, "only actually purchased DETF can fund fixture");
    }

    function mintExternal(address d, uint256 amt) external {
        _mintOn(d, amt);
    }

    function _nftLpOf(address d) internal view returns (uint256) {
        address hook_ = IUniswapV4Detf(d).hook();
        return IERC20(hook_).balanceOf(IUniswapV4Detf(d).bondNftVault());
    }

    function _openingEq(uint256[] memory a, uint256[] memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        for (uint256 i; i < a.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    function _openingAll(uint256[] memory a, uint256 wad) internal pure returns (bool) {
        if (a.length == 0) return false;
        for (uint256 i; i < a.length; ++i) {
            if (a[i] != wad) return false;
        }
        return true;
    }

    /* ------------------------------------------------------------------ */
    /*                         Shared assert bodies                         */
    /* ------------------------------------------------------------------ */

    function _assert_T1_openingZero_storesAsCreation_firstBondGAtPeg(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        uint256[] memory creation_ = info.creationPairPerDetfWad();
        uint256[] memory opening_ = info.openingPairPerDetfWad();
        assertTrue(_openingEq(opening_, creation_), "stored opening == creation");
        assertTrue(_openingAll(creation_, DEFAULT_CREATION_PAIR_PER_DETF), "creation 1e18");
        assertFalse(info.isReserveLive(), "inert");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive(), "live");
        uint256 g_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        assertApproxEqAbs(_detfReserveInHook(d), g_, 1000, "first-bond G at peg");
    }

    function _assert_T2_openingUsesG_creationViewUnchanged(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation view");
        assertTrue(_openingAll(info.openingPairPerDetfWad(), LAUNCH_RICH_START), "stored opening");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = _expectedJoinDetf(FIRST_BOND_AMT, LAUNCH_RICH_START);
        uint256 gCreation_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        uint256 raw_ = _detfReserveInHook(d);
        assertApproxEqAbs(raw_, gOpening_, 1000, "first-bond G uses opening");
        assertTrue(raw_ != gCreation_, "G is not creation-rate join");
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation unchanged");
    }

    function _assert_T5_creationZero_revertsInvalidCreationRate() internal {
        IUniswapV4Detf.PkgArgs memory args = _policyArgs();
        args = _withTag(args, string.concat("zcr", _nextTag()));
        uint256[] memory creation_ = new uint256[](args.creationPairPerDetfWad.length);
        args.creationPairPerDetfWad = creation_;
        args = _withOpening(args, LAUNCH_RICH_START);
        _expectInvalidCreationRate(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual {
        address predicted_ = _predictDetf(args);
        _deployCpHookAt(predicted_, args.ownerOnlyLiquidity);
        args.hook = reserveHook;
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _deployCpHookAt(address predicted_, bool ownerOnlyLiquidity_) internal {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se,
                pairToken: address(pairToken),
                rawToken: predicted_,
                pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(address(pairToken)),
                rawTokenDecimals: predicted_.code.length == 0 ? uint8(9) : HookPkgArgsDecimalsLib.tokenDec(predicted_),
                ownerOnlyLiquidity: ownerOnlyLiquidity_,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, address(pairToken));
        require(init.finalizeInitialization(), "finalize");
    }

    function _fundedPolicyUser() internal view override returns (address) {
        return detfUser;
    }

    function _fundedPolicyMintToken(address d) internal view override returns (IERC20) {
        return _mintTokenOf(d);
    }

    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal override {
        _fundToken(token, user, amount);
    }

    function _fundedPolicySkewDown(address d) internal override {
        _skewSyntheticDown(d);
    }

    function _fundedPolicyPushUp(address d) internal override {
        _pushSyntheticUp(d);
    }

    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal override {
        _ensureFreeDetf(d, amount);
    }

    function _fundedPolicyBond(address d, uint256 amount) internal override {
        _firstBondOn(d, amount);
    }

    function _fundedPolicyDonate(address d, uint256 amount) internal override {
        _donateMintToken(d, amount);
    }

    function _fundedPolicyLock() internal pure override returns (uint256) {
        return DEFAULT_MIN_LOCK;
    }
}
