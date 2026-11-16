// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as Receipt} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {MigrationHostileContribution} from "./MigrationHostileContribution.t.sol";

/// @notice Genuine external contract owner; calls real parent/children during an external payment callback.
contract PaidOwnerWallet {
    Migration immutable parent;
    IERC20 immutable payment;
    uint256 public probes;
    constructor(Migration parent_, IERC20 payment_) { parent = parent_; payment = payment_; }
    function accept() external { parent.acceptOwnershipTransfer(); }
    function buy(bool pretransferred_) external returns (uint256 id_) {
        payment.approve(address(parent), 1 ether);
        (id_,) = parent.bond(payment, 1 ether, 90 days, address(this), pretransferred_, block.timestamp);
    }
    function probe() external {
        require(msg.sender == address(payment), "payment callback only");
        ++probes;
        require(parent.migrationOwnerFirstBondTokenId() == 0 && !parent.migrationActivated(), "premature completion");
        (bool active_,) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        require(!active_, "callback activation");
        (bool bond_,) = address(parent).call(abi.encodeWithSignature(
            "bond(address,uint256,uint256,address,bool,uint256)", payment, 1 ether, 90 days, address(this), false, block.timestamp
        ));
        require(!bond_, "callback second bond");
        (bool mint_,) = address(parent).call(abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            payment, 1 ether, IERC20(address(parent)), 0, address(this), false, block.timestamp
        )));
        require(!mint_, "callback acquisition");
        (bool rewards_,) = parent.rebasingClaimToken().call(
            abi.encodeCall(Receipt.claimDeferredRoleRewards, (address(this)))
        );
        require(!rewards_, "callback rewards");
    }
}

contract MigrationOwnerBondCallbacksTest is TestBase_UniswapV4DetfMigration {
    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationHostileContribution.t.sol:MigrationHostileContribution"),
            "", keccak256("owner.first.paid.external")
        );
    }

    function test_contractOwnerPaymentCallbacksCannotPublishOrBypassAndShortReceiptRollsBack() public {
        _fundAndCapture();
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        PaidOwnerWallet wallet_ = new PaidOwnerWallet(migration, IERC20(pairB));
        token_.transfer(address(wallet_), 1 ether);
        vm.prank(migrationOwner);
        migration.initiateOwnershipTransfer(address(wallet_));
        wallet_.accept();
        bytes memory initial_ = abi.encode(receipt.stakingState());
        uint256 supply_ = IERC20(detf).totalSupply();
        token_.arm(true, detf, address(wallet_), abi.encodeCall(PaidOwnerWallet.probe, ()));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 1 ether - 1));
        wallet_.buy(false);
        assertEq(token_.balanceOf(address(wallet_)), 1 ether);
        assertEq(token_.allowance(address(wallet_), detf), 0);
        assertEq(wallet_.probes(), 0);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(abi.encode(receipt.stakingState()), initial_);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        (bool pretransferred_,) = address(wallet_).call(abi.encodeCall(PaidOwnerWallet.buy, (true)));
        assertFalse(pretransferred_);
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        token_.arm(false, detf, address(wallet_), abi.encodeCall(PaidOwnerWallet.probe, ()));
        uint256 id_ = wallet_.buy(false);
        assertTrue(token_.callbackSucceeded());
        assertEq(wallet_.probes(), 1);
        assertEq(token_.balanceOf(address(wallet_)), 0);
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
        assertGt(bonds.positionOf(id_).principal, 0);
        assertFalse(bonds.isMigrationPosition(id_));
        assertFalse(migration.migrationActivated());
    }
}
