// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";

contract RebasingAwareHandler is Test {
    IERC4626 public vault;
    IERC4626 public vault2;
    IERC20 public asset;
    address[] public actors;
    uint256 public depositAttempts;
    uint256 public depositSuccess;
    uint256 public redeemSuccess;
    uint256 public expectedReverts;

    constructor(IERC4626 vault_, IERC4626 vault2_, IERC20 asset_, address[] memory actors_) {
        vault = vault_;
        vault2 = vault2_;
        asset = asset_;
        actors = actors_;
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1, 50e18);
        depositAttempts++;
        if (asset.balanceOf(actor) < amount) {
            expectedReverts++;
            return;
        }
        if (vault.previewDeposit(amount) == 0 || vault.maxDeposit(actor) < amount) {
            expectedReverts++;
            return;
        }
        vm.startPrank(actor);
        vault.deposit(amount, actor);
        vm.stopPrank();
        depositSuccess++;
    }

    function redeem(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 bal = IERC20(address(vault)).balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        if (vault.previewRedeem(amount) == 0) return;
        vm.prank(actor);
        vault.redeem(amount, actor, actor);
        redeemSuccess++;
    }

    function transferShares(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 bal = IERC20(address(vault)).balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(from);
        IERC20(address(vault)).transfer(to, amount);
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 1, 10e18);
        ERC20PermitMintableStub(address(asset)).mint(address(vault), amount);
    }

    function assetPretransferReject(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        vm.prank(actor);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(asset)), 1e18, IERC20(address(vault)), 0, actor, true, block.timestamp
        );
        expectedReverts++;
    }

    function syInternalRedeem(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 bal = IERC20(address(vault)).balanceOf(actor);
        if (bal < 2) return;
        amount = bound(amount, 1, bal / 2);
        uint256 preview = IStandardizedYield(address(vault)).previewRedeem(address(asset), amount);
        if (preview == 0) return;
        vm.prank(actor);
        IERC20(address(vault)).transfer(address(vault), amount);
        uint256 publicBal = IERC20(address(vault)).balanceOf(address(vault));
        if (publicBal < amount) return;
        vm.prank(actor);
        IStandardizedYield(address(vault)).redeem(actor, amount, address(asset), 0, true);
        redeemSuccess++;
    }

    function depositVault2(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1, 20e18);
        if (asset.balanceOf(actor) < amount) return;
        vm.startPrank(actor);
        asset.approve(address(vault2), type(uint256).max);
        vault2.deposit(amount, actor);
        vm.stopPrank();
    }

    function zeroDepositRevert(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        vm.prank(actor);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vault.deposit(0, actor);
        expectedReverts++;
    }
}

contract RebasingAwareERC4626_Invariant is TestBase_RebasingAwareERC4626 {
    RebasingAwareHandler internal handler;
    IERC4626 internal vaultB;

    function setUp() public override {
        super.setUp();
        vaultB = pkg.deployVault(IERC20Metadata(address(asset)), 10, bytes32(uint256(7)));
        address[] memory actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = attacker;
        handler = new RebasingAwareHandler(vault, vaultB, IERC20(address(asset)), actors);
        targetContract(address(handler));
    }

    function invariant_INV01_supplyEqualsSumBalances() public view {
        uint256 sum = IERC20(address(vault)).balanceOf(alice) + IERC20(address(vault)).balanceOf(bob)
            + IERC20(address(vault)).balanceOf(attacker)
            + IERC20(address(vault)).balanceOf(address(vault))
            + IERC20(address(vault)).balanceOf(receiver);
        assertEq(sum, IERC20(address(vault)).totalSupply());
    }

    function invariant_INV02_backingIsLiveBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
        assertEq(vaultB.totalAssets(), asset.balanceOf(address(vaultB)));
    }

    function invariant_INV03_claimsDoNotExceedBacking() public view {
        uint256 supply = IERC20(address(vault)).totalSupply();
        if (supply == 0) return;
        uint256 claim = vault.convertToAssets(supply);
        assertLe(claim, vault.totalAssets() + 1);
    }

    function invariant_INV10_vaultsIsolated() public view {
        assertEq(vault.asset(), address(asset));
        assertEq(vaultB.asset(), address(asset));
        assertTrue(address(vault) != address(vaultB));
    }

    function invariant_INV12_zeroFeeType() public view {
        assertEq(pkg.vaultFeeTypeIds(), bytes32(0));
    }
}
