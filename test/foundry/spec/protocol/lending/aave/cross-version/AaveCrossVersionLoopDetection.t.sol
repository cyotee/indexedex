// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopService} from
    "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";

/**
 * @title AaveCrossVersionLoopDetection_Test
 * @notice End-to-end profitable-loop detection on the live local cross-version market. Drives
 *         asymmetric utilization across V3.6 and V4, reads real rates via the Service libs, and
 *         asserts CrossVersionLoopService detects the profitable direction (and rejects the flip).
 *         Validates the product's core thesis (PRD decision 28) against real markets.
 */
contract AaveCrossVersionLoopDetection_Test is TestBase_AaveCrossVersionLoopV3Market {
    uint256 internal _acctNonce;

    function _freshAccount() internal returns (address a) {
        a = address(uint160(uint256(keccak256(abi.encode("acct", _acctNonce++)))));
    }

    /* --------------------------- utilization drivers ------------------------ */

    /// @dev On V3.6: a fresh LP supplies `token`; a fresh borrower posts `collTok` collateral and
    ///      borrows `borrowAmt` of `token`, raising `token` utilization. Fresh accounts per call
    ///      avoid cross-leg position contamination.
    function _v3Utilize(IERC20 token, uint256 supplyAmt, IERC20 collTok, uint256 collAmt, uint256 borrowAmt)
        internal
    {
        address lp = _freshAccount();
        _mint(token, lp, supplyAmt);
        vm.startPrank(lp);
        token.approve(address(v36Pool), supplyAmt);
        v36Pool.supply(address(token), supplyAmt, lp, 0);
        vm.stopPrank();

        if (borrowAmt == 0) return;
        address borrower = _freshAccount();
        _mint(collTok, borrower, collAmt);
        vm.startPrank(borrower);
        collTok.approve(address(v36Pool), collAmt);
        v36Pool.supply(address(collTok), collAmt, borrower, 0);
        v36Pool.borrow(address(token), borrowAmt, 2, 0, borrower);
        vm.stopPrank();
    }

    /// @dev On V4: same shape using the Spoke, fresh accounts per call.
    function _v4Utilize(
        uint256 reserveId,
        uint256 supplyAmt,
        IERC20 token,
        uint256 collReserveId,
        IERC20 collTok,
        uint256 collAmt,
        uint256 borrowAmt
    ) internal {
        address lp = _freshAccount();
        _mint(token, lp, supplyAmt);
        vm.startPrank(lp);
        token.approve(address(v4Spoke), supplyAmt);
        v4Spoke.supply(reserveId, supplyAmt, lp);
        vm.stopPrank();

        if (borrowAmt == 0) return;
        address borrower = _freshAccount();
        _mint(collTok, borrower, collAmt);
        vm.startPrank(borrower);
        collTok.approve(address(v4Spoke), collAmt);
        v4Spoke.supply(collReserveId, collAmt, borrower);
        v4Spoke.setUsingAsCollateral(collReserveId, true, borrower);
        v4Spoke.borrow(reserveId, borrowAmt, borrower);
        vm.stopPrank();
    }

    /* ------------------------------ rate readers ---------------------------- */

    function _v4SupplyRate(uint256 assetId) internal view returns (uint256) {
        return CrossVersionLoopService.deriveV4SupplyRate(
            AaveV4Service.baseDrawnRate(v4Hub, assetId),
            AaveV4Service.assetLiquidity(v4Hub, assetId),
            AaveV4Service.assetTotalOwed(v4Hub, assetId),
            AaveV4Service.assetLiquidityFee(v4Hub, assetId)
        );
    }

    /* --------------------------------- tests -------------------------------- */

    /// @notice tokenA: high utilization on V4 (expensive borrow), low on V3 (cheap borrow).
    ///         Detection: borrowing tokenA is cheaper on V3 than V4.
    function test_detects_cheaper_borrow_version_for_tokenA() public {
        // V4 tokenA high util: LP 100 A; borrower posts 1,000,000 B ($1M) collateral, borrows 90 A.
        _v4Utilize(v4ReserveIdA, 100e18, tokenA, v4ReserveIdB, tokenB, 1_000_000e6, 90e18);
        // V3 tokenA low util: LP 100 A; borrower posts 1,000,000 B collateral, borrows 5 A.
        _v3Utilize(tokenA, 100e18, tokenB, 1_000_000e6, 5e18);

        uint256 v3BorrowA = AaveV36Service.borrowRate(v36Pool, address(tokenA));
        uint256 v4BorrowA = AaveV4Service.baseDrawnRate(v4Hub, v4AssetIdA);

        assertGt(v4BorrowA, v3BorrowA, "V4 tokenA borrow rate higher => cheaper to borrow on V3");
    }

    /// @notice Clean single-token cross-version carry detection. Drive tokenA utilization HIGH on V4
    ///         (collateral = tokenB, which does not pollute tokenA liquidity) and LOW on V3. Then a
    ///         real positive carry exists: SUPPLY tokenA on V4 (high supply rate) and BORROW tokenA
    ///         on V3 (cheap), while the reverse is unprofitable.
    function test_detects_profitable_single_token_carry_tokenA() public {
        // V4 tokenA HIGH util: LP 100 A; borrower posts tokenB collateral, borrows 90 A.
        _v4Utilize(v4ReserveIdA, 100e18, tokenA, v4ReserveIdB, tokenB, 1_000_000e6, 90e18);
        // V3 tokenA LOW util: LP 100 A; borrower posts tokenB collateral, borrows 5 A.
        _v3Utilize(tokenA, 100e18, tokenB, 1_000_000e6, 5e18);

        uint256 sA_v4 = _v4SupplyRate(v4AssetIdA); // V4 supply rate (high util)
        uint256 bA_v3 = AaveV36Service.borrowRate(v36Pool, address(tokenA)); // V3 borrow rate (low util)
        uint256 sA_v3 = AaveV36Service.supplyRate(v36Pool, address(tokenA)); // V3 supply rate (low util)
        uint256 bA_v4 = AaveV4Service.baseDrawnRate(v4Hub, v4AssetIdA); // V4 borrow rate (high util)

        // Profitable direction: supply tokenA on V4, borrow tokenA on V3.
        assertGt(sA_v4, bA_v3, "supply-A-on-V4 yields more than borrow-A-on-V3 costs (profitable)");
        // Reverse direction is unprofitable: supply tokenA on V3, borrow tokenA on V4.
        assertLt(sA_v3, bA_v4, "supply-A-on-V3 yields less than borrow-A-on-V4 costs (unprofitable)");

        // Net carry of the profitable single-token round-trip is positive; the reverse is negative.
        int256 fwd = int256(sA_v4) - int256(bA_v3);
        int256 rev = int256(sA_v3) - int256(bA_v4);
        assertGt(fwd, int256(0), "forward carry positive");
        assertLt(rev, int256(0), "reverse carry negative");
        assertGt(fwd, rev, "detection selects the profitable direction");
    }
}
