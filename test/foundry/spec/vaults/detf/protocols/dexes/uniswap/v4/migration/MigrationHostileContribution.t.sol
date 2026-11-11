// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";

/// @notice Controllable external ERC20 only. The parent, children, pools and SEs are real.
contract MigrationHostileContribution is SimpleMintableERC20 {
    bool public shortReceipt;
    address public watchedParent;
    address public callback;
    bytes public payload;
    bool public callbackSucceeded;
    constructor() SimpleMintableERC20("External hostile contribution fixture", "HOSTILE") {}
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    function arm(bool short_, address parent_, address callback_, bytes calldata payload_) external {
        shortReceipt = short_; watchedParent = parent_; callback = callback_; payload = payload_;
    }
    function transferFrom(address from_, address to_, uint256 amount_) external override returns (bool) {
        uint256 allowed_ = allowance[from_][msg.sender];
        require(allowed_ >= amount_, "allowance");
        if (allowed_ != type(uint256).max) allowance[from_][msg.sender] = allowed_ - amount_;
        bool trigger_ = msg.sender == watchedParent;
        _transfer(from_, to_, trigger_ && shortReceipt ? amount_ - 1 : amount_);
        if (trigger_ && callback != address(0)) (callbackSucceeded,) = callback.call(payload);
        return true;
    }
    function claim(IDetfBondNFT bond_, uint256 id_, address recipient_) external returns (uint256) {
        return bond_.claimPrincipal(id_, recipient_);
    }
}

contract MigrationHostileContributionTest is TestBase_UniswapV4DetfMigration {
    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationHostileContribution.t.sol:MigrationHostileContribution"),
            "", keccak256("migration.hostile.external")
        );
    }

    function test_shortExternalReceiptRevertsAllDonationAccounting() public {
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        token_.arm(true, detf, address(0), "");
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        uint256 payerBefore_ = token_.balanceOf(address(this));
        uint256 parentBefore_ = token_.balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 1 ether - 1));
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        assertEq(token_.balanceOf(address(this)), payerBefore_);
        assertEq(token_.balanceOf(detf), parentBefore_);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 0);
        assertEq(IERC20(detf).totalSupply(), 0);
    }

    function test_tokenCallbackCannotBorrowLockedParentChildSynchronization() public {
        _fundAndCapture();
        uint256 principal_ = _configure(pairB, 1 ether, bytes32("external-owner"));
        uint256 id_ = _issue(pairB);
        vm.warp(block.timestamp + 90 days);
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        token_.arm(false, detf, address(bonds), abi.encodeCall(IDetfBondNFT.claimPrincipal, (id_, address(this))));
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        uint256 gons_ = receipt.gonsOf(address(bonds));
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        assertFalse(token_.callbackSucceeded());
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(receipt.gonsOf(address(bonds)), gons_);
        // The same genuine contract holder succeeds after the outer transaction is finished.
        assertEq(token_.claim(IDetfBondNFT(address(bonds)), id_, address(this)), principal_);
        assertEq(receipt.balanceOf(address(this)), principal_);
    }
}
