// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
// FactoryServices load these implementation artifacts at runtime.
import {StandardExchangeRateProviderFacet} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {WrappedStandardExchangeRateProviderFacet} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderFacet.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/IERC4626PermitDFPkg.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IWrappedStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/IWrappedStandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

contract WrappedStandardExchangeRateProvider_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant LP_SEED_AMOUNT = 1_000e18;

    uint256 internal wrapperADeposit;
    uint256 internal wrapperBDeposit;

    IERC4626PermitDFPkg internal erc4626PermitPkg;
    IWrappedStandardExchangeRateProviderDFPkg internal wrappedRateProviderPkg;

    IERC4626 internal wrappedForTokenA;
    IERC4626 internal wrappedForTokenB;

    function setUp() public virtual override(TestBase_UniswapV2StandardExchange_MultiPool) {
        super.setUp();

        _deployWrapperAndRateProviderPackages();
        _mintReserveVaultShares();

        wrappedForTokenA = _deployWrappedVaultWithRateTargetSalt(IERC20(address(uniswapBalancedTokenA)));
        wrappedForTokenB = _deployWrappedVaultWithRateTargetSalt(IERC20(address(uniswapBalancedTokenB)));

        uint256 reserveVaultShareBalance = IERC20(address(balancedVault)).balanceOf(address(this));
        assertGt(reserveVaultShareBalance, 2, "insufficient reserve vault shares for wrapper tests");

        wrapperADeposit = reserveVaultShareBalance / 3;
        wrapperBDeposit = reserveVaultShareBalance - wrapperADeposit;

        IERC20(address(balancedVault)).approve(address(wrappedForTokenA), type(uint256).max);
        IERC20(address(balancedVault)).approve(address(wrappedForTokenB), type(uint256).max);

        wrappedForTokenA.deposit(wrapperADeposit, address(this));
        wrappedForTokenB.deposit(wrapperBDeposit, address(this));
    }

    function test_wrappedVaults_useSameUnderlying_withDifferentSaltedAddresses() public view {
        assertEq(address(wrappedForTokenA.asset()), address(balancedVault), "wrappedForTokenA asset mismatch");
        assertEq(address(wrappedForTokenB.asset()), address(balancedVault), "wrappedForTokenB asset mismatch");
        assertNotEq(address(wrappedForTokenA), address(wrappedForTokenB), "salted wrappers should differ");
    }

    function test_wrappedRateProvider_matchesManualQuote_forEachWrapper() public {
        IRateProvider rpTokenA = wrappedRateProviderPkg.deployRateProvider(
            wrappedForTokenA, IStandardExchangeIn(address(balancedVault)), IERC20(address(uniswapBalancedTokenA))
        );
        IRateProvider rpTokenB = wrappedRateProviderPkg.deployRateProvider(
            wrappedForTokenB, IStandardExchangeIn(address(balancedVault)), IERC20(address(uniswapBalancedTokenB))
        );

        uint256 expectedTokenA = _expectedRate(wrappedForTokenA, IERC20(address(uniswapBalancedTokenA)));
        uint256 expectedTokenB = _expectedRate(wrappedForTokenB, IERC20(address(uniswapBalancedTokenB)));

        uint256 observedTokenA = rpTokenA.getRate();
        uint256 observedTokenB = rpTokenB.getRate();

        assertEq(observedTokenA, expectedTokenA, "wrapped tokenA rate mismatch");
        assertEq(observedTokenB, expectedTokenB, "wrapped tokenB rate mismatch");
        assertGt(observedTokenA, 0, "wrapped tokenA rate should be > 0");
        assertGt(observedTokenB, 0, "wrapped tokenB rate should be > 0");
    }

    function test_projectedRatesFollowExternalSwapAndFundedDeposit() public {
        IRateProvider standard = create3Factory.deployStandardExchangeRateProviderDFPkg(
            create3Factory.deployStandardExchangeRateProviderFacet(), diamondPackageFactory
        ).deployRateProvider(IStandardExchange(address(balancedVault)), IERC20(address(uniswapBalancedTokenA)));
        IRateProvider wrapped = wrappedRateProviderPkg.deployRateProvider(
            wrappedForTokenA, IStandardExchangeIn(address(balancedVault)), IERC20(address(uniswapBalancedTokenA))
        );
        assertTrue(IERC165(address(standard)).supportsInterface(type(IStandardExchangeRateQuote).interfaceId));
        assertTrue(IERC165(address(wrapped)).supportsInterface(type(IStandardExchangeRateQuote).interfaceId));
        _assertProjectedRates(standard, wrapped, true);
        _assertProjectedRates(standard, wrapped, false);
    }

    struct RateComparison {
        uint256 standard;
        uint256 wrapped;
        uint256 previous;
        bytes state;
    }

    function _assertProjectedRates(IRateProvider standard, IRateProvider wrapped, bool swap) private {
        address se = address(balancedVault);
        address asset = address(uniswapBalancedTokenA);
        uint256 amount = 13 ether;
        IStandardExchangeTransitionQuote transition = IStandardExchangeTransitionQuote(se);
        RateComparison memory expected;
        (expected.state,) = transition.quoteState(asset, address(this));
        if (swap) {
            (expected.state,,) = IStandardExchangeExternalQuote(se).quoteExternalExchange(
                expected.state, address(uniswapBalancedTokenB), amount
            );
        } else {
            (expected.state,,,) = transition.quoteTransition(expected.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amount);
        }
        expected.standard = IStandardExchangeRateQuote(address(standard)).quoteRate(se, asset, expected.state);
        expected.wrapped = IStandardExchangeRateQuote(address(wrapped)).quoteRate(se, asset, expected.state);
        expected.previous = standard.getRate();
        if (swap) {
            uniswapBalancedTokenB.mint(address(this), amount);
            uniswapBalancedTokenB.approve(se, amount);
        } else {
            uniswapBalancedTokenA.mint(address(this), amount);
            uniswapBalancedTokenA.approve(se, amount);
        }
        IStandardExchangeIn(se).exchangeIn(
            IERC20(swap ? address(uniswapBalancedTokenB) : asset), amount,
            IERC20(swap ? asset : se), 0, address(this), false, block.timestamp
        );
        assertEq(expected.standard, standard.getRate(), "SE rate uses projected state and issued supply");
        assertEq(expected.wrapped, wrapped.getRate(), "wrapped rate uses projected underlying SE state");
        assertEq(transition.quoteTotalSupply(expected.state), IERC20(se).totalSupply());
        if (swap) assertNotEq(expected.standard, expected.previous, "external swap changes the buffered SE rate");
    }

    function _deployWrapperAndRateProviderPackages() internal {
        erc4626PermitPkg = create3Factory.deployERC4626PermitDFPkg(erc20Facet, erc5267Facet, erc2612Facet, erc4626Facet);

        IFacet wrappedRateProviderFacet = create3Factory.deployWrappedStandardExchangeRateProviderFacet();
        wrappedRateProviderPkg =
            create3Factory.deployWrappedStandardExchangeRateProviderDFPkg(wrappedRateProviderFacet, diamondPackageFactory);
    }

    function _mintReserveVaultShares() internal {
        uniswapBalancedTokenA.mint(address(this), LP_SEED_AMOUNT);
        uniswapBalancedTokenB.mint(address(this), LP_SEED_AMOUNT);

        uniswapBalancedTokenA.approve(address(uniswapV2Router), LP_SEED_AMOUNT);
        uniswapBalancedTokenB.approve(address(uniswapV2Router), LP_SEED_AMOUNT);

        (, , uint256 lpOut) = uniswapV2Router.addLiquidity(
            address(uniswapBalancedTokenA),
            address(uniswapBalancedTokenB),
            LP_SEED_AMOUNT,
            LP_SEED_AMOUNT,
            1,
            1,
            address(this),
            block.timestamp
        );

        IERC20(address(uniswapBalancedPair)).approve(address(balancedVault), lpOut);
        IStandardExchangeIn(address(balancedVault)).exchangeIn(
            IERC20(address(uniswapBalancedPair)),
            lpOut,
            IERC20(address(balancedVault)),
            0,
            address(this),
            false,
            block.timestamp + 1
        );
    }

    function _deployWrappedVaultWithRateTargetSalt(IERC20 rateTarget_) internal returns (IERC4626 wrapped_) {
        IERC4626PermitDFPkg.PkgArgs memory args = IERC4626PermitDFPkg.PkgArgs({
            reserveAsset: IERC20Metadata(address(balancedVault)),
            optionalDecimalOffset: 10,
            optionalSalt: keccak256(abi.encode(rateTarget_)),
            optionalInitialDeposit: 0,
            depositor: address(0),
            recipient: address(0)
        });

        bytes memory encodedArgs = abi.encode(args);
        address expected = diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(erc4626PermitPkg)), encodedArgs);
        // Deploy instance using factory (the IERC4626PermitDFPkg interface does not expose deploy; concrete does in this case).
        address deployed = diamondPackageFactory.deploy(IDiamondFactoryPackage(address(erc4626PermitPkg)), encodedArgs);

        assertEq(deployed, expected, "wrapper deployment address mismatch");

        wrapped_ = IERC4626(deployed);
    }

    function _expectedRate(IERC4626 wrapper_, IERC20 rateTarget_) internal view returns (uint256 expected_) {
        uint256 totalShares = wrapper_.totalSupply();
        if (totalShares == 0) {
            return 0;
        }

        uint256 subjectUnit = 10 ** IERC20Metadata(address(wrapper_)).decimals();
        uint256 quoteShares = totalShares < subjectUnit ? totalShares : subjectUnit;
        uint256 reserveShareAmount = wrapper_.previewRedeem(quoteShares);
        uint256 out;
        if (reserveShareAmount > 0) {
            out = IStandardExchangeIn(address(balancedVault)).previewExchangeIn(
                IERC20(address(balancedVault)), reserveShareAmount, rateTarget_
            );
        }

        for (uint256 i = 0; out == 0 && quoteShares < totalShares && i < 18; ++i) {
            uint256 nextQuote = quoteShares * 10;
            if (nextQuote > totalShares) nextQuote = totalShares;
            if (nextQuote == quoteShares) break;
            quoteShares = nextQuote;
            reserveShareAmount = wrapper_.previewRedeem(quoteShares);
            if (reserveShareAmount == 0) continue;
            out = IStandardExchangeIn(address(balancedVault)).previewExchangeIn(
                IERC20(address(balancedVault)), reserveShareAmount, rateTarget_
            );
        }

        if (out == 0 || quoteShares == 0) {
            return 0;
        }

        if (quoteShares != subjectUnit) {
            out = (out * subjectUnit + quoteShares - 1) / quoteShares;
        }

        uint8 targetDecimals = IERC20Metadata(address(rateTarget_)).decimals();

        if (targetDecimals == 18) {
            return out;
        }

        if (targetDecimals < 18) {
            return out * (10 ** (18 - targetDecimals));
        }

        return out / (10 ** (targetDecimals - 18));
    }
}
