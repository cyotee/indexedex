// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition, IStandardExchangeRateQuote as RateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote as Context} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeRateProviderDFPkg as RatePackage} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService as Factory} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {FullSpreadRateContextReader} from "contracts/test/stubs/FullSpreadRateContextReader.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {StandardExchangeConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";

abstract contract TestBase_UniswapV4FullSpreadRateContext is Test {
    IStandardExchangeProxy internal rateVault;
    IPoolManager internal rateManager;
    RatePackage internal ratePackage;
    IRateProvider[2] internal rateProviders;
    IERC20[2] internal rateTokens;
    uint256[2] internal rateUnits;
    FullSpreadRateContextReader internal rateReader;

    function _rateBootstrap() internal virtual;
    function _rateZeroSleeve() internal virtual;
    function _rateBlocked(bytes memory data_) internal virtual returns (bytes memory);

    function _startRateChecks(IStandardExchangeProxy vault_, IPoolManager manager_, ICreate3FactoryProxy factory_,
        IDiamondPackageCallBackFactory diamondFactory_, uint256[2] memory units_) internal
    {
        rateVault = vault_; rateManager = manager_; rateUnits = units_;
        address[] memory tokens = vault_.vaultTokens(); rateTokens = [IERC20(tokens[0]), IERC20(tokens[1])];
        ratePackage = Factory.deployStandardExchangeRateProviderDFPkg(factory_, Factory.deployStandardExchangeRateProviderFacet(factory_), diamondFactory_);
        for (uint256 i; i < 2; ++i) {
            rateProviders[i] = ratePackage.deployRateProvider(IStandardExchange(address(vault_)), rateTokens[i]);
            rateTokens[i].approve(address(vault_), type(uint256).max);
        }
        rateReader = new FullSpreadRateContextReader(manager_);
    }

    function test_liveRateMatchesOpaqueSnapshotInIdleAndActualBlockedContexts() public {
        _rateBootstrap();
        for (uint256 i; i < 2; ++i) {
            (bytes memory state,) = Transition(address(rateVault)).quoteState(address(rateTokens[i]), address(0));
            uint256 live = rateProviders[i].getRate(); assertGt(live, 0);
            assertEq(live, RateQuote(address(rateProviders[i])).quoteRate(address(rateVault), address(rateTokens[i]), state));
            bytes memory blocked = Context(address(rateVault)).quoteStateWithUnavailableUnlock(state, address(rateManager));
            uint256 projected = RateQuote(address(rateProviders[i])).quoteRate(address(rateVault), address(rateTokens[i]), blocked);
            assertGt(projected, 0); assertEq(_blockedLiveRate(i), projected);
            (bytes memory actual,) = abi.decode(rateReader.readWhileUnlocked(address(rateVault),
                abi.encodeCall(Transition.quoteState, (address(rateTokens[i]), address(0)))), (bytes, uint256));
            assertEq(actual, blocked);
            (bytes memory unchanged,) = Transition(address(rateVault)).quoteState(address(rateTokens[i]), address(0));
            assertEq(unchanged, state);
        }
    }

    function test_liveAndProjectedRatesAfterDepositUseSameContext() public {
        _rateBootstrap();
        for (uint256 i; i < 2; ++i) for (uint256 mode; mode < 2; ++mode) {
            uint256 saved = vm.snapshotState();
            _postDepositRate(i, mode == 1);
            assertTrue(vm.revertToStateAndDelete(saved));
        }
    }

    function _postDepositRate(uint256 leg_, bool blocked_) private {
        (bytes memory state,) = Transition(address(rateVault)).quoteState(address(rateTokens[leg_]), address(this));
        if (blocked_) state = Context(address(rateVault)).quoteStateWithUnavailableUnlock(state, address(rateManager));
        (bytes memory next,, uint256 shares,) = Transition(address(rateVault)).quoteTransition(state, Transition.Operation.DepositExactIn, rateUnits[leg_]);
        uint256 projected = RateQuote(address(rateProviders[leg_])).quoteRate(address(rateVault), address(rateTokens[leg_]), next);
        bytes memory callData = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (rateTokens[leg_], rateUnits[leg_], IERC20(address(rateVault)), shares, address(this), false, block.timestamp));
        uint256 minted;
        if (blocked_) minted = abi.decode(_rateBlocked(callData), (uint256));
        else minted = rateVault.exchangeIn(rateTokens[leg_], rateUnits[leg_], IERC20(address(rateVault)), shares, address(this), false, block.timestamp);
        assertEq(minted, shares); assertGt(minted, 0);
        assertEq(blocked_ ? _blockedLiveRate(leg_) : rateProviders[leg_].getRate(), projected);
        assertEq(Transition(address(rateVault)).quoteTotalSupply(next), rateVault.totalSupply());
    }

    function test_shortLocalCoverCannotShrinkOnlyLiveRateProbe() public {
        _rateZeroSleeve(); _rateBootstrap();
        bool shortageExercised;
        uint256 initialProbe = Math.min(rateVault.totalSupply(), 10 ** uint256(rateVault.decimals()));
        for (uint256 i; i < 2; ++i) {
            (bytes memory state,) = Transition(address(rateVault)).quoteState(address(rateTokens[i]), address(0));
            state = Context(address(rateVault)).quoteStateWithUnavailableUnlock(state, address(rateManager));
            uint256 probe = initialProbe;
            // Small-decimal supplies cap the first probe to the entire supply.
            // F2 forbids that while opposite backing remains, independently of
            // funding. Preserve and explicitly verify that legitimate fallback.
            if (probe == rateVault.totalSupply()) {
                vm.expectRevert(StandardExchangeConstantProduct.InsufficientBacking.selector);
                Transition(address(rateVault)).quoteAssets(state, probe);
                probe /= 2;
            }
            uint256 quantity = Transition(address(rateVault)).quoteAssets(state, probe);
            uint256 available = rateTokens[i].balanceOf(address(rateVault));
            if (quantity <= available) continue;
            shortageExercised = true;
            bytes memory callData = abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
                (IERC20(address(rateVault)), probe, rateTokens[i]));
            vm.expectRevert(abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)", address(rateTokens[i]), quantity, available));
            rateReader.readWhileUnlocked(address(rateVault), callData);
            uint256 expected = _normalise(quantity, probe, address(rateVault), i);
            assertGt(expected, 0);
            assertEq(_blockedLiveRate(i), expected, "live must use unfunded quantity probe");
            assertEq(RateQuote(address(rateProviders[i])).quoteRate(address(rateVault), address(rateTokens[i]), state), expected);
        }
        assertTrue(shortageExercised, "real local-cover shortage required");
    }

    function test_independentSubjectKeepsLegacyLivePreviewPolicy() public {
        _rateBootstrap();
        IRateProvider independent = ratePackage.deployRateProvider(IStandardExchange(address(rateVault)), rateTokens[0], rateTokens[1]);
        uint256 subjectUnit = 10 ** uint256(IERC20Metadata(address(rateTokens[0])).decimals());
        uint256 probe = Math.min(subjectUnit, rateTokens[0].totalSupply());
        uint256 expected = _normalise(rateVault.previewExchangeIn(rateTokens[0], probe, rateTokens[1]), probe, address(rateTokens[0]), 1);
        assertGt(expected, 0); assertEq(independent.getRate(), expected);
        assertEq(RateQuote(address(independent)).quoteRate(address(rateVault), address(rateTokens[1]), hex"012345"), expected);
    }

    function test_emptyFullSpreadRetainsItsExistingInitialMintFailurePolicy() public {
        assertEq(rateVault.totalSupply(), 0);
        for (uint256 i; i < 2; ++i) {
            (bytes memory state,) = Transition(address(rateVault)).quoteState(address(rateTokens[i]), address(0));
            assertEq(rateProviders[i].getRate(), 0, "single-token bootstrap is unsupported");
            assertEq(RateQuote(address(rateProviders[i])).quoteRate(address(rateVault), address(rateTokens[i]), state), 0);
            assertEq(_blockedLiveRate(i), 0);
        }
    }

    function _blockedLiveRate(uint256 leg_) private returns (uint256) {
        return abi.decode(rateReader.readWhileUnlocked(address(rateProviders[leg_]), abi.encodeCall(IRateProvider.getRate, ())), (uint256));
    }

    function _normalise(uint256 out_, uint256 probe_, address subject_, uint256 targetLeg_) private view returns (uint256) {
        uint256 unit = 10 ** uint256(IERC20Metadata(subject_).decimals());
        if (probe_ != unit) out_ = Math.mulDiv(out_, unit, probe_, Math.Rounding.Ceil);
        uint8 decimals = IERC20Metadata(address(rateTokens[targetLeg_])).decimals();
        if (decimals < 18) return out_ * 10 ** uint256(18 - decimals);
        if (decimals > 18) return out_ / 10 ** uint256(decimals - 18);
        return out_;
    }
}
