// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

/**
 * @title Adversarial_TrustFlags
 * @notice I1/I2/I3 on mint, later bond, donate, plus K1 donation-not-mint-credit.
 * @dev Happy-path pretransfer is not I1. E6 N/A no residual-return.
 */
contract Adversarial_TrustFlags is TestBase_UniswapV4Detf_Adversarial {
    function test_I1_mint_pretransferred_inventoryNoInCallTransfer_reverts() public {
        _assertI1_mint();
    }

    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        _assertI1_bond();
    }

    function test_I1_donate_pretransferred_inventoryNoTransfer_reverts() public {
        _assertI1_donate();
    }

    function test_I2_mint_pretransferred_claimedGtDelta_reverts() public {
        _assertI2_mint();
    }

    function test_I2_bond_pretransferred_claimedGtDelta_reverts() public {
        _assertI2_bond();
    }

    function test_I2_donate_pretransferred_claimedGtDelta_reverts() public {
        _assertI2_donate();
    }

    function test_I3_mint_residualInventory_cannotFundSecondFreePretransfer() public {
        _assertI3_mint();
    }

    function test_I3_bond_residualInventory_cannotFundSecondFreePretransfer() public {
        _assertI3_bond();
    }

    function test_I3_donate_residualInventory_cannotFundSecondFreePretransfer() public {
        _assertI3_donate();
    }

    function test_K1_donationNotMintCredit() public {
        _assertK1_donationNotMintCredit();
    }

    /// @notice D37: a registry that cannot answer isDisabled reverts prepaid-capable donate/bond.
    function test_APEX005_D37_registryWithoutIsDisabled_revertsDonate() public {
        _goLive(500 ether);
        vm.mockCallRevert(
            address(indexedexManager),
            abi.encodeWithSelector(IVaultRegistryDisableQuery.isDisabled.selector, detf),
            "missing isDisabled"
        );
        vm.prank(address(apexCaller));
        vm.expectRevert(bytes("missing isDisabled"));
        detfInfo.donate(IERC20(address(pairToken)), 1 ether, true);
    }
}
