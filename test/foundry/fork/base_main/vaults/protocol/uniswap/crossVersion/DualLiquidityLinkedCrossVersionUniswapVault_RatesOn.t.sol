// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenInfo, TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Rates-on regression: opt-in `useRateProviders=true` restores WITH_RATE legs + non-zero
///         SE rate providers, and keeps deposit/redeem preview≈execution under live Balancer rates.
contract DualLiquidityLinkedCrossVersionUniswapVault_RatesOn is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal actor = makeAddr("ratesOnActor");

    function _useRateProviders() internal pure override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
    }

    function test_ratesOn_reserveLegs_withRateAndNonZeroProviders() public {
        address pool = _reservePool();
        (IERC20[] memory tokens, TokenInfo[] memory info,,) = vault.getPoolTokenInfo(pool);
        assertEq(tokens.length, 3, "three reserve legs");
        assertEq(info.length, 3, "three token infos");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(uint8(info[i].tokenType), uint8(TokenType.WITH_RATE), "leg is WITH_RATE");
            assertTrue(address(info[i].rateProvider) != address(0), "non-zero rate provider");
            // Live SE rate provider should return a positive WAD-scale rate.
            assertGt(IRateProvider(address(info[i].rateProvider)).getRate(), 0, "rate > 0");
        }
    }

    function test_ratesOn_depositAndRedeem_previewMatchesExecution() public {
        IERC20 shareToken = IERC20(linkedVault);
        address pool = _reservePool();

        uint256 amount = LEG_SEED;
        _fund(commonToken, actor, amount);
        uint256 previewMint =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, amount, shareToken);

        vm.startPrank(actor);
        commonToken.approve(linkedVault, amount);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, shareToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(minted, 0, "minted shares");
        assertApproxEqAbs(minted, previewMint, 1e6, "deposit preview ~ execution under WITH_RATE");

        uint256 sharesIn = minted / 4;
        uint256 previewBpt =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, IERC20(pool));

        vm.startPrank(actor);
        uint256 bptOut = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, IERC20(pool), 0, actor, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(bptOut, 0, "BPT payout");
        assertEq(bptOut, previewBpt, "redeem-to-BPT preview == execution under WITH_RATE");
        _assertNoIntermediateInventory();
    }

    function test_ratesOn_vsRatesOff_distinctReservePools() public {
        address ratesOnPool = _reservePool();

        // Same markets/legs, rates off → different weighted-pool CREATE salt → different pool address.
        address ratesOffVault = _deployVaultWithArgs(
            "Dual Liquidity Rates Off Twin",
            "dlROff",
            0.2e18,
            0.2e18,
            0.6e18,
            false,
            keccak256("rates-off-twin-for-salt")
        );
        address ratesOffPool = _reservePoolOf(ratesOffVault);

        assertTrue(ratesOnPool != ratesOffPool, "rate policy must change reserve pool salt/address");

        // Rates-off TokenConfig: STANDARD + zero rate providers; no forced RP deploy.
        (, TokenInfo[] memory offInfo,,) = vault.getPoolTokenInfo(ratesOffPool);
        assertEq(offInfo.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(uint8(offInfo[i].tokenType), uint8(TokenType.STANDARD), "rates-off STANDARD");
            assertEq(address(offInfo[i].rateProvider), address(0), "rates-off zero RP");
        }

        // Rates-on remains WITH_RATE + non-zero (sanity vs twin).
        (, TokenInfo[] memory onInfo,,) = vault.getPoolTokenInfo(ratesOnPool);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(uint8(onInfo[i].tokenType), uint8(TokenType.WITH_RATE));
            assertTrue(address(onInfo[i].rateProvider) != address(0));
        }
    }

    /// @dev Reserve weighted pool for an arbitrary dual-liquidity vault instance.
    function _reservePoolOf(address vault_) internal view returns (address pool_) {
        address[] memory vt = IBasicVault(vault_).vaultTokens();
        for (uint256 i = 0; i < vt.length; i++) {
            if (vt[i] == vault_) continue;
            try vault.getPoolTokens(vt[i]) returns (IERC20[] memory pt) {
                if (pt.length == 3) return vt[i];
            } catch {}
        }
        revert("reserve pool not found");
    }
}
