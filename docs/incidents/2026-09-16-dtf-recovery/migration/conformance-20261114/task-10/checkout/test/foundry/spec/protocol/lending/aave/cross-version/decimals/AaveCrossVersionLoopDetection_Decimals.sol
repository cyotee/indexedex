// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopService} from
    "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice Profitable-loop detection on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopDetection_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
    uint256 internal _acctNonce;

    function _freshAccount() internal returns (address a) {
        a = address(uint160(uint256(keccak256(abi.encode("acct", _acctNonce++)))));
    }

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

    function _v4SupplyRate(uint256 assetId) internal view returns (uint256) {
        return CrossVersionLoopService.deriveV4SupplyRate(
            AaveV4Service.baseDrawnRate(v4Hub, assetId),
            AaveV4Service.assetLiquidity(v4Hub, assetId),
            AaveV4Service.assetTotalOwed(v4Hub, assetId),
            AaveV4Service.assetLiquidityFee(v4Hub, assetId)
        );
    }

    function test_detects_cheaper_borrow_version_for_tokenA() public {
        _v4Utilize(v4ReserveIdA, _uA(100), tokenA, v4ReserveIdB, tokenB, _uB(1_000_000), _uA(90));
        _v3Utilize(tokenA, _uA(100), tokenB, _uB(1_000_000), _uA(5));

        uint256 v3BorrowA = AaveV36Service.borrowRate(v36Pool, address(tokenA));
        uint256 v4BorrowA = AaveV4Service.baseDrawnRate(v4Hub, v4AssetIdA);

        assertGt(v4BorrowA, v3BorrowA, "V4 tokenA borrow rate higher => cheaper to borrow on V3");
    }

    function test_detects_profitable_single_token_carry_tokenA() public {
        _v4Utilize(v4ReserveIdA, _uA(100), tokenA, v4ReserveIdB, tokenB, _uB(1_000_000), _uA(90));
        _v3Utilize(tokenA, _uA(100), tokenB, _uB(1_000_000), _uA(5));

        uint256 sA_v4 = _v4SupplyRate(v4AssetIdA);
        uint256 bA_v3 = AaveV36Service.borrowRate(v36Pool, address(tokenA));
        uint256 sA_v3 = AaveV36Service.supplyRate(v36Pool, address(tokenA));
        uint256 bA_v4 = AaveV4Service.baseDrawnRate(v4Hub, v4AssetIdA);

        assertGt(sA_v4, bA_v3, "supply-A-on-V4 yields more than borrow-A-on-V3 costs (profitable)");
        assertLt(sA_v3, bA_v4, "supply-A-on-V3 yields less than borrow-A-on-V4 costs (unprofitable)");

        int256 fwd = int256(sA_v4) - int256(bA_v3);
        int256 rev = int256(sA_v3) - int256(bA_v4);
        assertGt(fwd, int256(0), "forward carry positive");
        assertLt(rev, int256(0), "reverse carry negative");
        assertGt(fwd, rev, "detection selects the profitable direction");
    }
}
