// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_SlipstreamFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_SlipstreamFixture.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @notice D20: orbital × SlipstreamStandardExchange — INCOMPATIBLE (M2, named production check).
/// @dev Every SE buffer hook unwraps shares through the SE's exact-in route
///      `exchangeIn(IERC20(se), shares, face, ...)`. The Slipstream SE serves only token0<->token1
///      swaps and token->share zap-ins on `exchangeIn` / `previewExchangeIn`
///      (`SlipstreamStandardExchangeInTarget.sol:80`, `SlipstreamStandardExchangeInTargetExt.sol:36`)
///      and reverts `IStandardExchangeIn.ExchangeInNotAvailable()` for a share input, so the hook's
///      first unwrap (and, on the multi-leg hooks, the first pricing of the leg) reverts with that
///      selector. Slipstream work is deferred under D66; the row records the constraint, it does not
///      patch around it. The SE is deployed through its real package on the hermetic CL book.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_SlipstreamStandardExchange is TestBase_UniswapV4StandardExchangeOrbitalBufferHook {
    function _matrixCtx() internal view returns (SeMatrixFixture.Ctx memory) {
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

    /// @dev DEPRECATED (APEX D57, owner ruling 2026-09-21): the Slipstream Standard Exchange is retired. It has no
    ///      share-to-token route and adding one would be a rewrite. The row keeps asserting the named production
    ///      check (`ExchangeInNotAvailable` at the first unwrap) so the retirement stays evidenced while the sources compile.
    function test_DEPRECATED_Slipstream_D57_ExchangeInNotAvailable() public {
        SeMatrix_SlipstreamFixture f = new SeMatrix_SlipstreamFixture(_matrixCtx(), address(0));
        address se = f.se();
        address face = f.faceToken();
        assertGt(IStandardExchangeIn(se).previewExchangeIn(IERC20(face), 1e18, IERC20(se)), 0, "face->share zap route exists");
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        IStandardExchangeIn(se).previewExchangeIn(IERC20(se), 1e18, IERC20(face));
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        IStandardExchangeIn(se).exchangeIn(IERC20(se), 1e18, IERC20(face), 0, address(this), false, block.timestamp + 1 hours);
    }
}
