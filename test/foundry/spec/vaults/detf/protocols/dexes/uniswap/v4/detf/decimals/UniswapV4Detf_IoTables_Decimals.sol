// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {UniswapV4Detf_IoTablesGoldBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTablesGoldBase_Decimals.sol";
import {UniswapV4Detf_IoTablesOpenBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTablesOpenBase_Decimals.sol";

/// @notice CP gold IoTables concrete: gold-only §7.1 IDs plus Open-layer T7.2/T7.10/T7.14/T7.19.
/// @dev T7.11 retains funded claim/LP conservation; Quad T8.3 covers its distinct multi-leg funded claim.
abstract contract UniswapV4Detf_IoTables_Decimals is
    TestBase_UniswapV4Detf_Decimals,
    UniswapV4Detf_IoTablesGoldBase_Decimals,
    UniswapV4Detf_IoTablesOpenBase_Decimals
{
    /// @notice T7.11: Funded sDETF claims retain protocol LP without a separate close configuration.
    function test_T7_11_fundedClaim_retainsProtocolLp() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "FundedClaimInstance";
        args.symbol = "FC1";
        address custom_ = _deployHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(custom_);
        _approveUserForDetf(custom_);

        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = info.bond(
            IERC20(address(pairToken)),
            _uPair(80),
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        IStandardExchangeIn(address(info)).exchangeIn(IERC20(address(pairToken)), _uPair(20), IERC20(address(info)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(info.isReserveLive(), "live");

        _assertFundedMatureClaim(custom_, tokenId, detfUser);
    }

    // T7.15 is a token-policy declaration, not an executable regression.
    // FoT remains forbidden by product law; no deployment allowlist is introduced.
    // Actual short-payment rejection remains covered by the SecurePull suites.
}
