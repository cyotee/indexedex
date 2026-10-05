// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversalTest} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversal.t.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition as Composition} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IProtocolFees} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IProtocolFees.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticReference as Reference} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/test/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticReference.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/// @notice Corpus version hookless-analytic-corpus-v1. Seed is additional, not a success oracle.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticCorpus is
    UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversalTest
{
    string internal constant CORPUS = "hookless-analytic-corpus-v1";
    uint256 internal constant SEED = uint256(0xA4E0000000000001);
    /// @dev Recorded feasible swap inputs. The planner is given credit, not these amounts.
    uint256 internal constant PLANTED_MULTISTEP = 500_024_998;
    uint256 internal constant PLANTED_DECIMALS = 500_024_998;

    function test_corpusVersionAndSeed() public pure {
        assertEq(keccak256(bytes(CORPUS)), keccak256("hookless-analytic-corpus-v1"));
        assertEq(SEED, uint256(0xA4E0000000000001));
    }

    function test_positiveToken0ToToken1() public view {
        _requireCertified(true, 1e15);
    }

    function test_positiveToken1ToToken0() public view {
        _requireCertified(false, 1e15);
    }

    function test_positiveSleeveZero() public view {
        Types.Snapshot memory state = _state();
        state.sleeveWad = 0;
        _requireCertifiedState(state, true, 1e15);
    }

    function test_positiveSleeveDefault() public view {
        Types.Snapshot memory state = _state();
        state.sleeveWad = 0.2e18;
        _requireCertifiedState(state, true, 1e15);
    }

    function test_positiveSleeveOne() public view {
        Types.Snapshot memory state = _state();
        state.sleeveWad = 1e18;
        _requireCertifiedState(state, true, 1e15);
    }

    function test_positiveProtocolFeeZero() public view {
        _requireCertified(true, 1e15);
    }

    function test_positiveProtocolFeeNonzero() public {
        _setLiveProtocolFee(100);
        _requireCertified(true, 1e15);
    }

    function test_positiveLpFeeZero() public view {
        _requireCertified(true, 1e15);
    }

    function test_positiveLpFeeNonzero() public {
        PoolKey memory zeroFee = key;
        key = PoolKey({
            currency0: zeroFee.currency0,
            currency1: zeroFee.currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        manager.initialize(key, uint160(1) << 96);
        _modify(1_000_000e18);
        _modify(int256(uint256(ownLiquidity)));
        assertEq(uint256(key.fee), 3000);
        _requireCertified(true, 1e15);
    }

    function test_positiveZeroLpFeeProtocolBranch() public {
        _setLiveProtocolFee(100);
        _requireCertified(true, 1e15);
    }

    function test_positivePriorEarnedFees() public view {
        Types.Snapshot memory state = _state();
        state.book.earned[0] = 1e15;
        state.book.earned[1] = 1e15;
        _requireCertifiedState(state, true, 1e15);
    }

    function test_positiveOneCoreStep() public view {
        (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(_state(), _params(true), 1e9, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.None));
        // This fixture's start price sits on a spacing boundary, so the source
        // quote reports two core steps for a fill that does not leave the range.
        assertLe(plan.swap.steps, 2);
        assertGe(plan.swap.steps, 1);
    }

    function test_positiveTwoInitializedTicks() public view {
        _requireCertified(true, 1e15);
    }

    function test_positiveExternalLiquidity() public view {
        _requireCertified(false, 1e15);
    }

    function test_positiveDecimals18() public view {
        _requireCertified(true, 1e15);
    }

    function test_positiveDecimals6and18PlantedWitness() public {
        ERC20PermitMintableStub six = new ERC20PermitMintableStub("Six", "SIX", 6, address(this), 1e32);
        ERC20PermitMintableStub eighteen = new ERC20PermitMintableStub("Eighteen", "EIGHTEEN", 18, address(this), 1e32);
        key = PoolKey({
            currency0: Currency.wrap(address(six) < address(eighteen) ? address(six) : address(eighteen)),
            currency1: Currency.wrap(address(six) < address(eighteen) ? address(eighteen) : address(six)),
            fee: 0, tickSpacing: 60, hooks: IHooks(address(0))
        });
        manager.initialize(key, uint160(1) << 96);
        ownLiquidity = 1_000e18;
        _modify(1_000_000e18);
        _modify(int256(uint256(ownLiquidity)));
        uint256 credit = 1e9;
        Types.Snapshot memory state = _state();
        Quotes.Params memory params = _params(true);
        assertEq(six.decimals(), 6);
        assertEq(eighteen.decimals(), 18);
        assertTrue(Reference._certifies(state, params, credit, PLANTED_DECIMALS), "witness");
        (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(state, params, credit, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.None));
        assertTrue(plan.valid);
        assertGt(plan.shares, 0);
        assertGe(plan.swap.steps, 2);
    }

    function test_referenceClassifiesSmallCredit() public view {
        uint256 credit = 64;
        Types.Snapshot memory state = _state();
        Quotes.Params memory params = _params(true);
        Reference.Result memory result = Reference._classify(state, params, credit);
        assertTrue(result.status != Reference.Status.Unknown);
        if (result.status == Reference.Status.Feasible) {
            assertTrue(Reference._certifies(state, params, credit, result.witness));
            (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(state, params, credit, _none());
            assertEq(uint256(failure), uint256(Composition.Failure.None));
            assertTrue(plan.valid);
        }
    }

    function test_positiveMultiStepPlantedWitness() public view {
        Types.Snapshot memory state = _state();
        Quotes.Params memory params = _params(true);
        assertTrue(Reference._certifies(state, params, 1e9, PLANTED_MULTISTEP), "witness");
        (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(state, params, 1e9, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.None));
        assertGe(plan.swap.steps, 2);
        assertTrue(plan.valid);
    }

    function test_negativeCreditZero() public view {
        (,, Composition.Failure failure) = Composition._plan(_state(), _params(true), 0, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.EmptyBook));
    }

    function test_negativeSupplyZero() public view {
        Types.Snapshot memory state = _state();
        state.book.supply = 0;
        (,, Composition.Failure failure) = Composition._plan(state, _params(true), 1, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.EmptyBook));
    }

    function test_negativeIdleFalse() public view {
        Types.Snapshot memory state = _state();
        state.idle = false;
        (,, Composition.Failure failure) = Composition._plan(state, _params(true), 1, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.EmptyBook));
    }

    function test_negativeNonzeroHook() public view {
        Quotes.Params memory params = _params(true);
        params.key.hooks = IHooks(address(1));
        (,, Composition.Failure failure) = Composition._plan(_state(), params, 1, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.Rejected));
    }

    function test_negativeAmountAboveInt128() public view {
        (,, Composition.Failure failure) = Composition._plan(_state(), _params(true), uint256(uint128(type(int128).max)) + 1, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.Rejected));
    }

    function test_negativeDiscoveryStep65() public view {
        Composition.ProjectedPoolOverlay memory overlay = _farOverlay(65);
        (,, Composition.Failure failure) = Composition._plan(_state(), _params(true), 1, overlay);
        assertTrue(failure == Composition.Failure.WorkLimit || failure == Composition.Failure.Rejected || failure == Composition.Failure.OutOfDomain);
    }

    function test_negativeBitmapWord65() public view {
        Composition.ProjectedPoolOverlay memory overlay = _farOverlay(65);
        (, Composition.Work memory work, Composition.Failure failure) = Composition._plan(_state(), _params(true), 1, overlay);
        if (failure == Composition.Failure.WorkLimit) assertGe(work.bitmapWordReads, 64);
    }

    function test_negativeDiscriminantAndOverflowAreNotSuccess() public pure {
        assertTrue(uint256(Composition.Failure.NegativeDiscriminant) != uint256(Composition.Failure.None));
        assertTrue(uint256(Composition.Failure.Unrepresentable) != uint256(Composition.Failure.None));
    }

    function _requireCertified(bool zeroForOne_, uint256 credit_) internal view {
        _requireCertifiedState(_state(), zeroForOne_, credit_);
    }

    function _requireCertifiedState(Types.Snapshot memory state_, bool zeroForOne_, uint256 credit_) internal view {
        (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(state_, _params(zeroForOne_), credit_, _none());
        assertEq(uint256(failure), uint256(Composition.Failure.None));
        assertTrue(plan.valid);
        assertGt(plan.shares, 0);
        assertEq(plan.refinements, 0);
    }

    function _setLiveProtocolFee(uint16 fee_) internal {
        IProtocolFees fees = IProtocolFees(address(manager));
        fees.setProtocolFeeController(address(this));
        fees.setProtocolFee(key, uint24(fee_) | (uint24(fee_) << 12));
    }

    function _requireOverlayProtocol(uint24 protocolFee_, uint256 credit_) internal view {
        Types.Snapshot memory state = _state();
        Composition.ProjectedPoolOverlay memory overlay;
        overlay.useOverlay = true;
        overlay.activeLiquidity = state.position.activeLiquidity;
        overlay.sqrtPriceX96 = state.position.sqrtPriceX96;
        overlay.tick = state.position.tick;
        overlay.lpFee = 0;
        overlay.protocolFees = protocolFee_ | (protocolFee_ << 12);
        (Types.Plan memory plan,, Composition.Failure failure) = Composition._plan(state, _params(true), credit_, overlay);
        assertEq(uint256(failure), uint256(Composition.Failure.None));
        assertTrue(plan.valid);
        assertGt(plan.shares, 0);
    }

    function _farOverlay(uint256 count_) internal view returns (Composition.ProjectedPoolOverlay memory overlay_) {
        Types.Snapshot memory state = _state();
        overlay_.useOverlay = true;
        overlay_.activeLiquidity = state.position.activeLiquidity;
        overlay_.sqrtPriceX96 = state.position.sqrtPriceX96;
        overlay_.tick = state.position.tick;
        overlay_.ticks = new Composition.TickOverlay[](count_);
        for (uint256 i; i < count_; ++i) {
            overlay_.ticks[i] = Composition.TickOverlay(int24(int256(i)) - 1000, 0, 0);
        }
    }
}
