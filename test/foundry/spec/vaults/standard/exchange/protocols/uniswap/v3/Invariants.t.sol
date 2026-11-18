// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {INonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as IImport} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {TestBase_UniswapV3FullSpreadAccountingNFT} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccountingNFT.sol";

interface IV3AccountingSequence {
    function exercise(uint256 phase, uint256 seed) external;
}

/// @notice Sequence driver only; all balances and liquidity belong to real production instances.
contract V3AccountingSequenceHandler {
    IV3AccountingSequence public immutable environment;
    uint256 public steps;

    constructor(IV3AccountingSequence environment_) {
        environment = environment_;
    }

    function step(uint256 seed_) external {
        environment.exercise(steps % 8, seed_);
        ++steps;
    }
}

/// @notice V3-ACC-20 and Step 9: multiple holders across every accounting transition.
contract UniswapV3FullSpreadInvariants is TestBase_UniswapV3FullSpreadAccountingNFT, IV3AccountingSequence {
    V3AccountingSequenceHandler internal handler;
    uint256 internal imports;

    function setUp() public override {
        super.setUp();
        _setFeeRecipient(address(this));
        handler = new V3AccountingSequenceHandler(this);
        targetContract(address(handler));
        bytes4[] memory selectors_ = new bytes4[](1);
        selectors_[0] = V3AccountingSequenceHandler.step.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors_}));
    }

    function exercise(uint256 phase_, uint256 seed_) external {
        require(msg.sender == address(handler), "sequence handler only");
        uint256 amount_ = bound(seed_, 1e6, 1e9);
        if (phase_ == 0) {
            _bundleIn(alice, SEED, SEED);
        } else if (phase_ == 1) {
            uint256[] memory before_ = vault.reserves();
            vm.startPrank(bob);
            token0.transfer(address(vault), amount_);
            token1.transfer(address(vault), amount_ / 2);
            vm.stopPrank();
            assertEq(vault.reserves(), before_, "stray custody never changes reserves");
        } else if (phase_ == 2) {
            _poolFees(amount_ * 1e6, amount_ * 2e6);
        } else if (phase_ == 3) {
            _bundleIn(bob, amount_, amount_);
        } else if (phase_ == 4) {
            (uint256 id_,) = _mintPosition(alice, amount_, amount_, -600, 600);
            vm.prank(alice);
            npm.approve(address(vault), id_);
            (uint256 quoted_, uint256 refund0_, uint256 refund1_) =
                IImport(address(vault)).previewImportPosition(npm, id_);
            uint256 before0_ = token0.balanceOf(bob);
            uint256 before1_ = token1.balanceOf(bob);
            vm.prank(alice);
            uint256 minted_ = IImport(address(vault)).importPosition(npm, id_, quoted_, alice, bob, block.timestamp);
            assertEq(minted_, quoted_);
            assertEq(token0.balanceOf(bob) - before0_, refund0_);
            assertEq(token1.balanceOf(bob) - before1_, refund1_);
            vm.expectRevert();
            npm.ownerOf(id_);
            ++imports;
        } else if (phase_ == 5) {
            IVault(address(vault)).compound();
        } else if (phase_ == 6) {
            _bundleOut(alice, vault.balanceOf(alice) / 3, alice, false);
        } else {
            uint256 aliceShares_ = vault.balanceOf(alice);
            uint256 bobShares_ = vault.balanceOf(bob);
            if (aliceShares_ != 0) _bundleOut(alice, aliceShares_, alice, false);
            if (bobShares_ != 0) _bundleOut(bob, bobShares_, bob, false);
            assertEq(vault.totalSupply(), 1_000, "ordinary holders can close without burning the floor");
        }
        _assertAccounting();
    }

    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_custodyAndSharesRemainReconciled() public view {
        _assertAccounting();
    }

    function test_fullLifecycleIncludesLaterImportAndFinalHolderExit() public {
        for (uint256 i_; i_ < 8; ++i_) handler.step(uint256(keccak256(abi.encode("V3 accounting", i_))));
        assertEq(handler.steps(), 8);
        assertEq(imports, 1);
        assertEq(vault.totalSupply(), 1_000);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 0);
        _assertAccounting();
    }

    function test_failedGenesisImportRollsBackNFTPoolCustodyAndSupply() public {
        (uint256 id_, uint128 liquidity_) = _mintPosition(alice, 500, 500, -600, 600);
        vm.prank(alice);
        npm.approve(address(vault), id_);
        bytes32 before_ = _importState(id_);
        vm.prank(alice);
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        IImport(address(vault)).importPosition(npm, id_, 0, alice, bob, block.timestamp);
        assertEq(_importState(id_), before_, "all source and destination effects roll back");
        assertEq(npm.ownerOf(id_), alice);
        (,,,,,,, uint128 afterLiquidity_,,,,) = npm.positions(id_);
        assertEq(afterLiquidity_, liquidity_);
        assertEq(vault.totalSupply(), 0);
        _assertAccounting();
    }

    function _assertAccounting() private view {
        uint256 supply_ = vault.totalSupply();
        assertEq(
            supply_,
            vault.balanceOf(address(0)) + vault.balanceOf(alice) + vault.balanceOf(bob)
                + vault.balanceOf(recipient) + vault.balanceOf(address(this)) + vault.balanceOf(address(vault))
        );
        assertEq(vault.balanceOf(address(0)), supply_ == 0 ? 0 : 1_000);
        assertGe(uint256(_positionLiquidity()), supply_, "authorized routes preserve supply <= liquidity");
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertLe(booked0_, token0.balanceOf(address(vault)));
        assertLe(booked1_, token1.balanceOf(address(vault)));
        _assertSettled();
        _assertTokenCustody(IERC20(address(token0)));
        _assertTokenCustody(IERC20(address(token1)));
    }

    function _assertTokenCustody(IERC20 token_) private view {
        uint256 held_ = token_.balanceOf(address(this)) + token_.balanceOf(alice) + token_.balanceOf(bob)
            + token_.balanceOf(recipient) + token_.balanceOf(address(handler)) + token_.balanceOf(address(vault))
            + token_.balanceOf(address(pool)) + token_.balanceOf(address(npm));
        assertEq(held_, token_.totalSupply(), "all underlying tokens remain in tracked custody");
    }

    function _importState(uint256 id_) private view returns (bytes32) {
        (bool ok_, bytes memory position_) =
            address(npm).staticcall(abi.encodeCall(INonfungiblePositionManager.positions, (id_)));
        require(ok_);
        return keccak256(abi.encode(
            position_, npm.ownerOf(id_), npm.getApproved(id_), pool.liquidity(), vault.totalSupply(),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool)),
            token0.balanceOf(alice), token1.balanceOf(alice), token0.balanceOf(bob), token1.balanceOf(bob),
            token0.balanceOf(address(npm)), token1.balanceOf(address(npm))
        ));
    }
}
