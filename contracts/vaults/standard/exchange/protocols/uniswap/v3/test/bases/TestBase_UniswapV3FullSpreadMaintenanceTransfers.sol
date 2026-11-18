// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TestBase_UniswapV3FullSpreadMaintenance} from "./TestBase_UniswapV3FullSpreadMaintenance.sol";
import {UniswapV3MaintenanceTransferToken} from "../tokens/UniswapV3MaintenanceTransferToken.sol";

/// @notice Reuse the canonical fixture's deployment and funding helpers with a real hostile token.
abstract contract TestBase_UniswapV3FullSpreadMaintenanceTransfers is TestBase_UniswapV3FullSpreadMaintenance {
    UniswapV3MaintenanceTransferToken internal hostile;

    struct CustodySnapshot {
        uint256[6] balances;
        uint256 supply;
        uint256 callerShares;
        uint256 parkedShares;
        uint256 booked0;
        uint256 booked1;
        uint128 liquidity;
        uint160 price;
    }

    function setUp() public virtual override {
        super.setUp();
        hostile = new UniswapV3MaintenanceTransferToken();
        ERC20PermitMintableStub other_ = new ERC20PermitMintableStub("Other", "O", 18, address(this), 0);
        pool = _createPoolOneToOne(address(hostile), address(other_), FEE_MEDIUM);
        token0 = ERC20PermitMintableStub(pool.token0());
        token1 = ERC20PermitMintableStub(pool.token1());
        // The canonical fixture's bounds use this same factory and fee tier.
        _seedExternalLiquidity(pool, EXTERNAL_LIQUIDITY);
        vault = _deployVault(pool);
        _fundAccount(alice);
        _seedVault(SEED);
    }

    function _custodySnapshot() internal view returns (CustodySnapshot memory snapshot_) {
        snapshot_.balances = [
            token0.balanceOf(alice), token1.balanceOf(alice),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool))
        ];
        snapshot_.supply = vault.totalSupply();
        snapshot_.callerShares = vault.balanceOf(alice);
        snapshot_.parkedShares = vault.balanceOf(address(vault));
        (snapshot_.booked0, snapshot_.booked1) = _booked();
        snapshot_.liquidity = _positionLiquidity();
        (snapshot_.price,,,,,,) = pool.slot0();
    }

    function _assertCustodyUnchanged(CustodySnapshot memory before_) internal view {
        assertEq(abi.encode(_custodySnapshot()), abi.encode(before_), "complete economic rollback");
        _assertSettled();
    }
}
