// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRewardToken as RT} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";

contract MigrationPermitAndRetirementTest is TestBase_UniswapV4DetfMigration {
    uint256 internal principal;
    uint256 internal id;
    function setUp() public override {
        super.setUp();
        _fundAndCapture();
        _buyOwnerFirstBond();
        principal = _configure(address(this), 1 ether, bytes32("permit"));
        id = _issue(address(this));
        vm.warp(block.timestamp + 90 days);
        bonds.claimPrincipal(id, address(this));
    }

    function _permit(address token_, uint256 key_, address spender_, uint256 amount_) private {
        IERC20Permit permit_ = IERC20Permit(token_);
        address signer_ = vm.addr(key_);
        uint256 nonce_ = permit_.nonces(signer_);
        bytes32 structHash_ = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            signer_, spender_, amount_, nonce_, block.timestamp
        ));
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", permit_.DOMAIN_SEPARATOR(), structHash_));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(key_, digest_);
        permit_.permit(signer_, spender_, amount_, block.timestamp, v_, r_, s_);
        assertEq(permit_.nonces(signer_), nonce_ + 1);
        assertEq(IERC20(token_).allowance(signer_, spender_), amount_);
        (bool replay_,) = token_.call(abi.encodeCall(
            IERC20Permit.permit, (signer_, spender_, amount_, block.timestamp, v_, r_, s_)
        ));
        assertFalse(replay_);
    }

    function test_receiptPermitAuthorizesPrincipalButNotRetainedRights() public {
        uint256 key_ = 0xA11CE;
        address signer_ = vm.addr(key_);
        receipt.transfer(signer_, principal);
        _permit(address(receipt), key_, address(this), principal);
        receipt.transferFrom(signer_, address(this), principal);
        assertEq(receipt.allowance(signer_, address(this)), 0);
        assertEq(receipt.balanceOf(signer_), 0);
        assertEq(receipt.balanceOf(address(this)), principal);
    }

    function test_syPermitAndMaxAllowanceUseCanonicalNativeUnits() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        uint256 key_ = 0xB0B;
        address signer_ = vm.addr(key_);
        stakingSy.transfer(signer_, principal);
        _permit(address(stakingSy), key_, address(this), type(uint256).max);
        stakingSy.transferFrom(signer_, address(stakingSy), principal);
        assertEq(stakingSy.allowance(signer_, address(this)), type(uint256).max - principal);
        assertEq(stakingSy.redeem(address(this), principal, detf, principal, true), principal);
        assertEq(stakingSy.totalSupply(), 0);
    }

    function test_activeFullWalletExitRetiresOnlyOwnFraction() public {
        receipt.approve(address(stakingSy), principal / 2);
        stakingSy.deposit(address(this), address(receipt), principal / 2, principal / 2);
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairA);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 50 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        vm.warp(block.timestamp + 8 hours);
        migration.synchronizeRewards();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        uint256 held_ = receipt.gonsOf(address(this));
        uint256 amount_ = receipt.balanceOf(address(this));
        IStakedDETF.StakingState memory before_ = receipt.stakingState();
        uint256 syGons_ = receipt.gonsOf(address(stakingSy));
        receipt.exchangeIn(IERC20(address(receipt)), amount_, IERC20(detf), amount_, address(this), false, block.timestamp);
        IStakedDETF.StakingState memory after_ = receipt.stakingState();
        assertEq(receipt.gonsOf(address(this)), 0);
        assertEq(before_.totalGons - after_.totalGons, held_);
        assertEq(before_.accountedBacking - after_.accountedBacking, amount_);
        assertEq(after_.stakingDust - before_.stakingDust,
            before_.totalGons / before_.gonsPerUnit - after_.totalGons / after_.gonsPerUnit - amount_);
        assertEq(receipt.gonsOf(address(stakingSy)), syGons_);
    }

    function test_oneNativeRewardTokenRetainsAllUnpayableGonsForOwner() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairA);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 50 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        vm.warp(block.timestamp + 8 hours);
        migration.synchronizeRewards();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        uint256 minted_ = stakingSy.claimRewards(address(this))[0];
        assertGt(minted_, 1);
        RT rt_ = RT(migration.migrationSyRewardToken());
        uint256 before_ = receipt.deferredRewardGons(0, address(this));
        (uint256 paid_, uint256 remainder_) = rt_.redeem(1, address(0xBEEF), 0);
        assertEq(paid_, 0);
        assertEq(remainder_, 1e18);
        assertEq(receipt.deferredRewardGons(0, address(this)), before_ + 1e18);
        assertEq(receipt.deferredRewardGons(0, address(0xBEEF)), 0);
        assertEq(receipt.tokenizedSyRewardGons(), rt_.totalSupply() * 1e18);
    }
}
