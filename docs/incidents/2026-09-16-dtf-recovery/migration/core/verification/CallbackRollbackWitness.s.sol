// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

contract RejectingMigrationOwner is IERC721Receiver {
    Migration private immutable parent;
    address private immutable oldHolder;

    constructor(Migration parent_, address holder_) {
        parent = parent_;
        oldHolder = holder_;
    }

    function accept() external { parent.acceptOwnershipTransfer(); }

    function onERC721Received(address, address, uint256 id, bytes calldata) external returns (bytes4) {
        (bool activated,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        (bool reentered,) = parent.rebasingClaimToken().call(
            abi.encodeCall(IERC20.transfer, (address(this), 0))
        );
        // A broken gate deliberately makes the outer transfer succeed, failing the
        // witness. Only the correctly guarded pre-mutation callback rejects receipt.
        if (activated || reentered || IERC721(msg.sender).ownerOf(id) != oldHolder) {
            return IERC721Receiver.onERC721Received.selector;
        }
        return bytes4(0);
    }
}

contract CallbackRollbackWitness is TestBase_UniswapV4DetfMigration {
    function run() external {
        _fundAndCapture();
        uint256 principal = _configure(address(this), 1 ether, bytes32("rollback"));
        uint256 id = _issue(address(this));
        uint256 start = bonds.positionOf(id).startTimestamp;
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(pairA);
        tokens[1] = IERC20(pairB);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        migration.donateMigrationCapital(tokens, amounts, 0, 1, block.timestamp);
        RejectingMigrationOwner receiver = new RejectingMigrationOwner(migration, address(this));
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(receiver));
        receiver.accept();
        vm.warp(start + 8 hours);
        require(migration.pendingExpansionDetf() > 0, "rollback must include genuine due funding");
        bytes32 stateBefore = keccak256(abi.encode(receipt.stakingState(), bonds.positionOf(id)));
        uint256 supplyBefore = IERC20(detf).totalSupply();
        (bool accepted, bytes memory reason) = address(bonds).call(
            abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(this), address(receiver), id)
        );
        require(!accepted && bytes4(reason) == IERC721Errors.ERC721InvalidReceiver.selector, "rejecting callback");
        require(IERC721(address(bonds)).ownerOf(id) == address(this), "ownership rollback");
        require(!migration.migrationActivated(), "activation rollback");
        require(keccak256(abi.encode(receipt.stakingState(), bonds.positionOf(id))) == stateBefore, "gon rollback");
        require(IERC20(detf).totalSupply() == supplyBefore, "funding rollback");
        console2.log("CALLBACK_FULL_ROLLBACK", true);

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        vm.warp(start + 90 days);
        require(bonds.claimPrincipal(id, address(this)) == principal, "disabled mature principal");
        uint256 before = IERC20(detf).balanceOf(address(this));
        receipt.exchangeIn(IERC20(address(receipt)), principal, IERC20(detf), principal, address(this), false, block.timestamp);
        require(IERC20(detf).balanceOf(address(this)) - before == principal, "disabled held backing payout");
        console2.log("DISABLED_MATURE_PRINCIPAL", principal);
    }
}

contract CallbackRollbackWitnessRunner is Script {
    function run() external {
        CallbackRollbackWitness witness = new CallbackRollbackWitness();
        vm.allowCheatcodes(address(witness));
        witness.setUp();
        witness.run();
    }
}
