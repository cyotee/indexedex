// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWeightedPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_N8HooklessFullSpreadGas
 * @notice One n=8 Weighted hook bound to eight production Hookless FullSpread vaults.
 * @dev The Curve and Balancer quad rows bind four Hookless vaults. This is the Weighted
 *      maximum (n=8), not the missing 1..7 matrix. The money call uses the same 31_000_000
 *      stipend as the Orbital position-share deposit that ran out of gas. A revert here is
 *      the measurement, not a waived failure.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_N8HooklessFullSpreadGas is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    /// @dev Robinhood reports a 32M transaction limit. The funded-binding probes leave this headroom.
    uint256 internal constant CHAIN_GAS = 31_000_000;
    uint256 internal constant LEGS = 8;
    uint256 internal constant FACE_IN = 10 ether;

    function test_n8_eightHooklessFullSpreadVaults_faceJoinFitsChainGas() public {
        SeMatrix_FullSpreadV4Fixture[8] memory fxs = _eightHooklessVaults();
        _bindEight(fxs);

        assertEq(weighted.numTokens(), LEGS, "n=8");
        assertEq(weighted.pairDoorCount(), 28, "every unordered pair");
        for (uint256 i; i < LEGS; ++i) {
            assertEq(weighted.token(i), fxs[i].faceToken(), "ascending face");
            assertEq(weighted.standardExchange(i), fxs[i].se(), "Hookless vault bound");
            assertTrue(weighted.isBuffered(i), "every leg buffered");
            assertGt(
                IStandardExchangeIn(fxs[i].se()).previewExchangeIn(
                    IERC20(fxs[i].faceToken()), FACE_IN, IERC20(fxs[i].se())
                ),
                0,
                "Hookless vault quotes the face"
            );
        }

        uint256 quoteStart = gasleft();
        IStandardExchangeIn(fxs[0].se()).previewExchangeIn(
            IERC20(fxs[0].faceToken()), FACE_IN, IERC20(fxs[0].se())
        );
        emit log_named_uint("one Hookless previewExchangeIn gas", quoteStart - gasleft());

        uint256[] memory amounts = new uint256[](LEGS);
        for (uint256 i; i < LEGS; ++i) amounts[i] = FACE_IN;

        uint256 joinStart = gasleft();
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional{gas: CHAIN_GAS}(
            amounts, user, 0, block.timestamp + 1 hours
        );
        emit log_named_uint("n=8 Hookless face join gas", joinStart - gasleft());
        assertGt(shares, 0, "eight-vault join minted LP inside the chain gas stipend");
        for (uint256 i; i < LEGS; ++i) {
            assertGt(IERC20(fxs[i].se()).balanceOf(hook), 0, "hook holds every Hookless vault's shares");
        }
    }

    function _eightHooklessVaults() internal returns (SeMatrix_FullSpreadV4Fixture[8] memory fxs) {
        SeMatrix_FullSpreadV4Fixture[8] memory raw;
        address sharedPkg;
        SeMatrixFixture.Ctx memory ctx = _fixtureCtx();
        for (uint256 i; i < LEGS; ++i) {
            raw[i] = new SeMatrix_FullSpreadV4Fixture(ctx, sharedPkg);
            sharedPkg = raw[i].pkg();
        }
        for (uint256 i; i < LEGS; ++i) {
            for (uint256 j = i + 1; j < LEGS; ++j) {
                if (raw[j].faceToken() < raw[i].faceToken()) {
                    (raw[i], raw[j]) = (raw[j], raw[i]);
                }
            }
        }
        fxs = raw;
    }

    function _bindEight(SeMatrix_FullSpreadV4Fixture[8] memory fxs) internal {
        IWeightedPkg.PkgArgs memory args;
        args.poolManager = address(pm);
        args.feeOracle = address(indexedexManager);
        args.n = uint8(LEGS);
        args.tokens = new address[](LEGS);
        args.weights = new uint256[](LEGS);
        args.standardExchanges = new address[](LEGS);
        uint256 each = WAD / LEGS;
        for (uint256 i; i < LEGS; ++i) {
            args.tokens[i] = fxs[i].faceToken();
            args.standardExchanges[i] = fxs[i].se();
            args.weights[i] = i == LEGS - 1 ? (WAD - each * (LEGS - 1)) : each;
            fxs[i].fund(user, 1_000_000 ether);
        }
        args.ownerOnlyLiquidity = _pkgOwnerOnlyLiquidity();
        args.owner = _pkgOwner();
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.rateProviders = RateProviderFixtureLib.providersFor(
            create3Factory, diamondPackageFactory, args.tokens, args.standardExchanges
        );

        _deployHookWithArgs(args);
        _setUsageFee(0);
        _setDexFee(0);
        for (uint256 i; i < LEGS; ++i) {
            vm.startPrank(user);
            IERC20(args.tokens[i]).approve(hook, type(uint256).max);
            IERC20(args.tokens[i]).approve(args.standardExchanges[i], type(uint256).max);
            vm.stopPrank();
        }
    }

    function _fixtureCtx() internal view returns (SeMatrixFixture.Ctx memory) {
        return SeMatrixFixture.Ctx({
            create3Factory: create3Factory,
            indexedexManager: IIndexedexManagerProxy(address(indexedexManager)),
            owner: owner,
            permit2: permit2,
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
        });
    }
}
