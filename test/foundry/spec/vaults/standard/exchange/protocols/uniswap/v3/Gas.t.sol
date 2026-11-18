// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as IImport} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {TestBase_UniswapV3FullSpreadColdGas} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadColdGas.sol";

/// @notice Step 10: cold body, standalone transaction envelope, and preview ceilings.
/// @dev No warming preview precedes a money measurement. Each fixture mutation is outside its body.
contract UniswapV3FullSpreadGas is TestBase_UniswapV3FullSpreadColdGas {
    function test_gasGenesisToken0Pull() public { _mintGas(true, true, false); }
    function test_gasGenesisToken1Pull() public { _mintGas(true, false, false); }
    function test_gasGenesisToken0Pretransfer() public { _mintGas(true, true, true); }
    function test_gasGenesisToken1Pretransfer() public { _mintGas(true, false, true); }
    function test_gasLaterToken0Pull() public { _mintGas(false, true, false); }
    function test_gasLaterToken1Pull() public { _mintGas(false, false, false); }
    function test_gasLaterToken0Pretransfer() public { _mintGas(false, true, true); }
    function test_gasLaterToken1Pretransfer() public { _mintGas(false, false, true); }
    function test_gasExitToken0() public { _exitGas(true, false); }
    function test_gasExitToken1() public { _exitGas(false, false); }
    function test_gasFeeAndBookedHeavyExitToken0() public { _exitGas(true, true); }
    function test_gasFeeAndBookedHeavyExitToken1() public { _exitGas(false, true); }

    function _mintGas(bool genesis_, bool zero_, bool prepaid_) private {
        if (!genesis_) _seedVault(SEED);
        IERC20 input_ = IERC20(zero_ ? address(token0) : address(token1));
        uint256 amount_ = 1e8;
        if (prepaid_) input_.transfer(address(vault), amount_);
        bytes memory result_ = _moneyGas(
            string.concat(genesis_ ? "genesis/" : "later/", zero_ ? "token0/" : "token1/", prepaid_ ? "pretransfer" : "pull"),
            prepaid_ ? address(this) : bob,
            abi.encodeCall(IStandardExchangeIn.exchangeIn, (
                input_, amount_, IERC20(address(vault)), 1, recipient, prepaid_, block.timestamp
            ))
        );
        (uint256 minted_,) = abi.decode(result_, (uint256, uint256));
        assertGt(minted_, 0, "measurement must execute a successful mint");
    }

    function _exitGas(bool want0_, bool heavy_) private {
        _seedVault(SEED);
        if (heavy_) {
            _poolFees(1e20, 1e20);
            _bundleIn(bob, 1e9, 1e9);
            _poolFees(1e20, 1e20);
        }
        bytes memory result_ = _moneyGas(
            string.concat(heavy_ ? "fees+booked/" : "principal/", want0_ ? "exit-token0" : "exit-token1"),
            alice,
            abi.encodeCall(IStandardExchangeIn.exchangeIn, (
                IERC20(address(vault)), vault.balanceOf(alice) / 3,
                IERC20(want0_ ? address(token0) : address(token1)), 1, recipient, false, block.timestamp
            ))
        );
        (uint256 paid_,) = abi.decode(result_, (uint256, uint256));
        assertGt(paid_, 0);
    }

    function test_gasPassThroughBothDirections() public {
        for (uint256 i_; i_ < 2; ++i_) {
            bytes memory result_ = _moneyGas(
                i_ == 0 ? "pass-token0-to-token1/pull" : "pass-token1-to-token0/pull", bob,
                abi.encodeCall(IStandardExchangeIn.exchangeIn, (
                    IERC20(i_ == 0 ? address(token0) : address(token1)), 1e8,
                    IERC20(i_ == 0 ? address(token1) : address(token0)), 1, recipient, false, block.timestamp
                ))
            );
            (uint256 paid_,) = abi.decode(result_, (uint256, uint256));
            assertGt(paid_, 0);
        }
    }

    function test_gasBundleInWithProportionalRefund() public {
        _seedVault(SEED);
        bytes memory result_ = _moneyGas("bundle-in/unequal-budgets/pull", bob, abi.encodeCall(
            IStandardExchangeBundleIn.exchangeBundleInForSingleOut,
            (_amountArray(1e8, 2e8), address(vault), 1, bob, false, block.timestamp)
        ));
        (uint256 minted_, uint256[] memory refunds_) = abi.decode(result_, (uint256, uint256[]));
        assertGt(minted_, 0);
        assertEq(refunds_[1], 1e8);
    }

    function test_gasBundleOut() public {
        _seedVault(SEED);
        bytes memory result_ = _moneyGas("bundle-out/exact-caller-shares", alice, abi.encodeCall(
            IStandardExchangeBundleOut.exchangeBundleOut,
            (address(vault), vault.balanceOf(alice) / 2, _tokensOut(), _amountArray(1, 1), recipient, false, block.timestamp)
        ));
        (uint256[] memory paid_, uint256 refund_) = abi.decode(result_, (uint256[], uint256));
        assertGt(paid_[0], 0);
        assertGt(paid_[1], 0);
        assertEq(refund_, 0);
    }

    function test_gasOneTokenDonate() public {
        _seedVault(SEED);
        uint128 before_ = _positionLiquidity();
        _moneyGas("donate/token0-only/pull", address(this), abi.encodeCall(IVault.donate, (address(token0), 1e8, false)));
        assertGt(_positionLiquidity(), before_);
    }

    function test_gasBothTokenDonate() public {
        _seedVault(SEED);
        _poolFees(0, 1e20);
        _bundleIn(bob, 1e9, 1e9);
        uint128 before_ = _positionLiquidity();
        _moneyGas("donate/token0-plus-booked-token1/pull", address(this), abi.encodeCall(IVault.donate, (address(token0), 1e8, false)));
        assertGt(_positionLiquidity(), before_);
    }

    function test_gasShareDonate() public {
        _seedVault(SEED);
        vm.prank(alice);
        vault.transfer(address(this), 1e8);
        uint256 before_ = vault.totalSupply();
        _moneyGas("donate/caller-shares", address(this), abi.encodeCall(IVault.donate, (address(vault), 1e8, false)));
        assertEq(vault.totalSupply(), before_ - 1e8);
    }

    function test_gasOneTokenCompound() public {
        _seedVault(SEED);
        _poolFees(1e20, 0);
        uint128 before_ = _positionLiquidity();
        _moneyGas("compound/token0-fees", address(this), abi.encodeCall(IVault.compound, ()));
        assertGt(_positionLiquidity(), before_);
    }

    function test_gasBothTokenCompound() public {
        _seedVault(SEED);
        _poolFees(1e20, 1e20);
        uint128 before_ = _positionLiquidity();
        _moneyGas("compound/both-token-fees", address(this), abi.encodeCall(IVault.compound, ()));
        assertGt(_positionLiquidity(), before_);
    }

    function test_gasEmptyCompoundIgnoresStrayCustody() public {
        _seedVault(SEED);
        token0.transfer(address(vault), 1e8);
        _moneyGas("compound/empty-eligible-with-stray", address(this), abi.encodeCall(IVault.compound, ()));
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_ + booked1_, 0);
    }

    function test_gasGenesisImport() public { _importGas(false, false); }
    function test_gasLaterImport() public { _importGas(true, false); }
    function test_gasPreviewGenesisImport() public { _importGas(false, true); }
    function test_gasPreviewLaterImport() public { _importGas(true, true); }

    function _importGas(bool later_, bool preview_) private {
        if (later_) _seedVault(SEED);
        (uint256 id_,) = _mintPosition(alice, 1e9, 1e9, -600, 600);
        vm.prank(alice);
        npm.approve(address(vault), id_);
        if (preview_) {
            bytes memory result_ = _previewGas(later_ ? "later-import" : "genesis-import",
                abi.encodeCall(IImport.previewImportPosition, (npm, id_)));
            (uint256 shares_,,) = abi.decode(result_, (uint256, uint256, uint256));
            assertGt(shares_, 0);
        } else {
            bytes memory result_ = _moneyGas(later_ ? "later-import/NFT-transfer-decrease-collect-burn" : "genesis-import/NFT-transfer-decrease-collect-burn",
                alice, abi.encodeCall(IImport.importPosition, (npm, id_, 1, alice, recipient, block.timestamp)));
            assertGt(abi.decode(result_, (uint256)), 0);
            vm.expectRevert();
            npm.ownerOf(id_);
        }
    }

    function test_gasColdSinglePreviews() public {
        _seedVault(SEED);
        bytes memory mint_ = _previewGas("later/token0-mint", abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(token0)), uint256(1e8), IERC20(address(vault)))));
        bytes memory exit_ = _previewGas("partial/token1-exit", abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(vault)), vault.balanceOf(alice) / 3, IERC20(address(token1)))));
        bytes memory pass_ = _previewGas("token0-to-token1-pass", abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(token0)), uint256(1e8), IERC20(address(token1)))));
        (uint256 minted_,) = abi.decode(mint_, (uint256, uint256));
        (uint256 paid_,) = abi.decode(exit_, (uint256, uint256));
        (uint256 swapped_,) = abi.decode(pass_, (uint256, uint256));
        assertGt(minted_, 0);
        assertGt(paid_, 0);
        assertGt(swapped_, 0);
    }

    function test_gasColdBundlePreviewsAndFailClosedExactOut() public {
        _seedVault(SEED);
        bytes memory mint_ = _previewGas("bundle-in/proportional-refund", abi.encodeCall(
            IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut, (_amountArray(1e8, 2e8), address(vault))));
        bytes memory exit_ = _previewGas("bundle-out/exact-shares", abi.encodeCall(
            IStandardExchangeBundleOut.previewExchangeBundleOut, (address(vault), vault.balanceOf(alice) / 3, _tokensOut())));
        bytes memory unavailable_ = _previewGas("exact-out/unavailable", abi.encodeCall(
            IStandardExchangeOut.previewExchangeOut, (IERC20(address(token0)), IERC20(address(vault)), uint256(1e8))));
        (uint256 shares_,) = abi.decode(mint_, (uint256, uint256[]));
        (uint256[] memory paid_,) = abi.decode(exit_, (uint256[], uint256));
        assertGt(shares_, 0);
        assertGt(paid_[0], 0);
        assertEq(abi.decode(unavailable_, (uint256)), 0);
    }

    function test_gasAdjacentDustTicksAndSubstantialCrossing() public {
        _dustTicks();
        bytes memory result_ = _moneyGas("40-adjacent-dust-ticks/token0-pass/pull", bob, abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(token0)), uint256(1e17), IERC20(address(token1)), uint256(1), recipient, false, block.timestamp)));
        (uint256 received_,) = abi.decode(result_, (uint256, uint256));
        (, int24 tick_,,,,,) = pool.slot0();
        assertGt(received_, 0);
        assertLt(tick_, -1_000, "measurement crosses many initialized ticks");
    }

    function test_gasColdAdjacentDustTickPreview() public {
        _dustTicks();
        bytes memory result_ = _previewGas("40-adjacent-dust-ticks/token0-pass", abi.encodeCall(
            IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(token0)), uint256(1e17), IERC20(address(token1)))));
        (uint256 received_, uint256 refund_) = abi.decode(result_, (uint256, uint256));
        assertGt(received_, 0);
        assertEq(refund_, 0, "fixed exact input is fully spent across dust ticks");
    }

    function _dustTicks() private {
        _seedVault(SEED);
        for (int24 i_ = 1; i_ <= 40; ++i_) {
            pool.mint(address(this), -i_ * 60, (-i_ + 1) * 60, 1e6, abi.encode(address(this)));
        }
    }
}
