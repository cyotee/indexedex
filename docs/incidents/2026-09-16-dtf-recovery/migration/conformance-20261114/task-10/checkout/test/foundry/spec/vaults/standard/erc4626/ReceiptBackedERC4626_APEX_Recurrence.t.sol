// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ReceiptBackedERC4626_SharedFacet_Test} from "./ReceiptBackedERC4626_SharedFacet.t.sol";

/// @notice R14.18 distinguishes the generic proxy family from its real Stata receipt's type.
contract ReceiptBackedERC4626_APEX_Recurrence is ReceiptBackedERC4626_SharedFacet_Test {
    /// @notice A generic wrapper over Stata uses generic books and preserves the independent Stata proxy.
    function test_RECURRENCE_B05_genericOverRealStata_dispatchAndIsolation() public {
        vm.prank(owner);
        address genericOverStata = genericPkg.deployVault(IERC4626(realStata));
        uint256 receipts = _acquireStata(address(this), _u(100));
        IERC20(realStata).approve(genericOverStata, receipts);
        uint256 oldSupply = IERC20(realVault).totalSupply();
        uint256 oldAssets = IERC4626(realVault).totalAssets();
        uint256 preview = IERC4626(genericOverStata).previewDeposit(receipts);
        uint256 shares = IERC4626(genericOverStata).deposit(receipts, address(this));
        assertEq(shares, preview, "generic adapter uses its configured Stata receipt");
        assertEq(IERC4626(genericOverStata).asset(), realStata, "actual receipt identity");
        assertEq(IERC4626(genericOverStata).totalAssets(), receipts, "receipt accounting");
        address[] memory tokens = IBasicVault(genericOverStata).vaultTokens();
        assertEq(tokens.length, 2, "generic registered book excludes Stata-only aToken");
        for (uint256 i; i < tokens.length; ++i) {
            assertTrue(tokens[i] != aToken, "no Stata-family aToken slot on generic proxy");
            assertEq(IBasicVault(genericOverStata).reserveOfToken(tokens[i]), IERC20(tokens[i]).balanceOf(genericOverStata), "full generic book sync");
        }
        assertEq(IERC20(realVault).totalSupply(), oldSupply, "other proxy supply isolated");
        assertEq(IERC4626(realVault).totalAssets(), oldAssets, "other proxy backing isolated");
        uint256 payout = IERC4626(genericOverStata).previewRedeem(shares);
        uint256 before = IERC20(realStata).balanceOf(address(this));
        assertEq(IERC4626(genericOverStata).redeem(shares, address(this), address(this)), payout, "generic receipt exit");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, payout, "payout measured independently");
    }
}
