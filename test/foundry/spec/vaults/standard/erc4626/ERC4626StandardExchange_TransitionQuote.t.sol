// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {ERC4626TargetStub} from "@crane/contracts/tokens/ERC4626/ERC4626TargetStub.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";

contract ERC4626StandardExchange_TransitionQuote is TestBase_ERC4626StandardExchange, TransitionQuoteAssertions {
    function test_transitionCapability_projectsCanonicalVirtualUnderlying() public {
        MintableERC20Decimals asset_ = new MintableERC20Decimals("Asset", "ASSET", 18);
        ERC4626TargetStub vault_ = new ERC4626TargetStub(IERC20Metadata(address(asset_)), 0, permit2);
        address se_ = _deployERC4626SE(address(vault_));
        assertTrue(IERC165(se_).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId));
        assertTrue(ClaimLib.supportsTransitionQuote(se_, address(asset_), address(this)));
        asset_.mint(address(this), 100 ether);
        asset_.approve(se_, 100 ether);
        uint256 quoted_ = IStandardExchangeIn(se_).previewExchangeIn(IERC20(address(asset_)), 100 ether, IERC20(se_));
        uint256 minted_ = IStandardExchangeIn(se_).exchangeIn(
            IERC20(address(asset_)), 100 ether, IERC20(se_), quoted_, address(this), false, block.timestamp
        );
        assertEq(minted_, quoted_, "ordinary ERC4626 routes retain compatibility");
        assertTrue(ClaimLib.supportsTransitionQuote(se_, address(asset_), address(this)));
        assertGt(ClaimLib.previewBufferClaimIn(se_, address(asset_), 1 ether, indexedexManager, address(this)), 0);
        asset_.mint(address(this), 100 ether);
        _assertQuoteSequence(se_, IERC20(address(asset_)), address(this), 1 ether);
    }

    function test_externalProtocolVaultRedemptionTransition() public {
        MintableERC20Decimals asset_ = new MintableERC20Decimals("Asset", "ASSET", 18);
        SimpleYieldERC4626 vault_ = new SimpleYieldERC4626(asset_);
        address se_ = _deployERC4626SE(address(vault_));
        asset_.mint(address(this), 10_000 ether);
        asset_.approve(se_, 1_000 ether);
        IStandardExchangeIn(se_).exchangeIn(IERC20(address(asset_)), 1_000 ether, IERC20(se_), 1, address(this), false, block.timestamp);
        asset_.approve(address(vault_), 200 ether);
        uint256 payment_ = vault_.deposit(100 ether, address(this));
        vault_.simulateYield(100 ether);
        _assertExternalExchangeQuote(se_, IERC20(address(vault_)), IERC20(address(asset_)), payment_);
    }

    function test_prepaidProtocolReceiptMintUsesPrepaymentBacking() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        uint256 payment = 10 ether;
        uint256 quoted = IStandardExchangeIn(se).previewExchangeIn(IERC20(address(vault)), payment, IERC20(se));
        uint256 backing = vault.balanceOf(se);
        uint256 balance = IERC20(se).balanceOf(address(this));
        vault.transfer(se, payment);
        uint256 minted = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(vault)), payment, IERC20(se), quoted, address(this), true, block.timestamp
        );
        assertEq(minted, quoted, "prepaid protocol shares quote against prepayment backing");
        assertEq(IERC20(se).balanceOf(address(this)) - balance, quoted);
        assertEq(vault.balanceOf(se), backing + payment, "new reserve is retained once");
        assertEq(asset.balanceOf(se), 0);
    }

    function test_prepaidProtocolReceiptExactOutputRefundsOnlyUnusedPayment() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        uint256 wanted = 5 ether;
        uint256 quoted = IStandardExchangeOut(se).previewExchangeOut(IERC20(address(vault)), IERC20(se), wanted);
        uint256 maximum = quoted + 3 ether;
        uint256 backing = vault.balanceOf(se);
        uint256 wallet = vault.balanceOf(address(this));
        uint256 balance = IERC20(se).balanceOf(address(this));
        vault.transfer(se, maximum);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(address(vault)), maximum, IERC20(se), wanted, address(this), true, block.timestamp
        );
        assertEq(spent, quoted, "prepaid exact-output cost retains prepayment quote");
        assertEq(IERC20(se).balanceOf(address(this)) - balance, wanted);
        assertEq(vault.balanceOf(se), backing + spent, "existing backing and required payment retained");
        assertEq(vault.balanceOf(address(this)), wallet - spent, "only unused user payment refunded");
    }

    function _fundPrepaidReceiptCase() private returns (address se, SimpleYieldERC4626 vault, IERC20 asset) {
        MintableERC20Decimals token = new MintableERC20Decimals("Asset", "ASSET", 18);
        vault = new SimpleYieldERC4626(token);
        se = _deployERC4626SE(address(vault));
        asset = IERC20(address(token));
        token.mint(address(this), 1_000 ether);
        token.approve(se, 100 ether);
        IStandardExchangeIn(se).exchangeIn(asset, 100 ether, IERC20(se), 1, address(this), false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, address(this));
    }

    function test_externalDepositTransition_underlyingAndReceiptWithFundedFees() public {
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", 18);
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(asset);
        address se = _deployERC4626SE(address(vault));
        address holder = address(indexedexManager.feeTo());
        asset.mint(address(this), 10_000 ether);
        asset.approve(se, 1_000 ether);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(asset)), 1_000 ether, IERC20(se), 1, holder, false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        asset.approve(address(vault), 200 ether);
        uint256 payment = vault.deposit(100 ether, address(this));
        vault.simulateYield(100 ether);
        _assertExternalDepositQuote(se, IERC20(address(vault)), IERC20(address(asset)), payment, holder);
        _assertExternalDepositQuote(se, IERC20(address(asset)), IERC20(address(asset)), 10 ether, holder);
    }

    function testFuzz_transitionSequence(uint8 decimals_, uint64 yield_, bool feeOn_, bool feeHolder_) public {
        uint8 dec_ = uint8(bound(decimals_, 6, 18));
        uint256 unit_ = 10 ** uint256(dec_);
        MintableERC20Decimals asset_ = new MintableERC20Decimals("Asset", "ASSET", dec_);
        SimpleYieldERC4626 vault_ = new SimpleYieldERC4626(asset_);
        address se_ = _deployERC4626SE(address(vault_));
        address holder_ = feeHolder_ ? address(indexedexManager.feeTo()) : makeAddr("quote holder");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se_, feeOn_ ? 2e15 : 0);
        asset_.mint(holder_, 10_000 * unit_);
        vm.startPrank(holder_);
        asset_.approve(se_, type(uint256).max);
        IStandardExchangeIn(se_).exchangeIn(IERC20(address(asset_)), 1000 * unit_ + 13, IERC20(se_), 1, holder_, false, block.timestamp);
        vm.stopPrank();
        uint256 accrued_ = bound(yield_, 1, 100 * unit_);
        asset_.mint(address(this), accrued_);
        asset_.approve(address(vault_), accrued_);
        vault_.simulateYield(accrued_);
        _assertQuoteSequence(se_, IERC20(address(asset_)), holder_, unit_);
    }

    function test_receiptAccounting_nestedErc4626DepositDoesNotChargeNestedSeUsageFee() public {
        _nestedErc4626FeeSemantics(6);
        _nestedErc4626FeeSemantics(9);
        _nestedErc4626FeeSemantics(18);
    }

    function _nestedErc4626FeeSemantics(uint8 decimals) private {
        uint256 unit = 10 ** decimals;
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", decimals);
        ERC4626TargetStub receipt = new ERC4626TargetStub(IERC20Metadata(address(asset)), 0, permit2);
        address inner = _deployERC4626SE(address(receipt));
        address outer = _deployERC4626SE(inner);
        asset.mint(address(this), 10_000 * unit);
        asset.approve(address(receipt), type(uint256).max);
        receipt.deposit(9_000 * unit, address(this));
        IERC20(address(receipt)).approve(inner, type(uint256).max);
        IERC4626(inner).deposit(1_000 * unit, address(this));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(inner, 7e16);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(outer, 11e16);
        vm.stopPrank();
        IERC20(address(receipt)).approve(outer, type(uint256).max);
        IStandardExchangeIn(outer).exchangeIn(IERC20(address(receipt)), 1_000 * unit, IERC20(outer), 1, address(this), false, block.timestamp);
        address fee = address(indexedexManager.feeTo());
        uint256 beforeFee = IERC20(inner).balanceOf(fee);
        _assertQuoteSequence(outer, IERC20(address(receipt)), address(this), unit);
        assertEq(IERC20(inner).balanceOf(fee), beforeFee, "nested IERC4626 deposit has no SE usage fee");
    }

    function test_receiptAccounting_canonicalVirtualVaultSequence() public {
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", 18);
        ERC4626TargetStub vault = new ERC4626TargetStub(IERC20Metadata(address(asset)), 0, permit2);
        address se = _deployERC4626SE(address(vault));
        asset.mint(address(this), 3_000 ether);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(2_000 ether, address(this));
        IERC20(address(vault)).approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(vault)), 1_000 ether, IERC20(se), 1, address(this), false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        _assertQuoteSequence(se, IERC20(address(vault)), address(this), 1 ether);
        _assertExternalExchangeQuote(se, IERC20(address(asset)), IERC20(address(vault)), 20 ether);
    }

    function test_receiptAccounting_sequentialDepositWithdrawalAndRedemption() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        _assertQuoteSequence(se, IERC20(address(vault)), address(this), 1 ether);
    }

    function test_receiptAccounting_exactOutputRetainsRoundingSurplus() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        vault.transfer(se, 90 ether);
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(se);
        (bytes memory state,) = quote.quoteState(address(vault), address(this));
        Step memory step;
        (step.state, step.input, step.output, step.claim) = quote.quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, 2
        );
        assertEq(step.output, 2, "receipt exact-output pays only the requested amount");
        uint256 before = vault.balanceOf(address(this));
        assertEq(IStandardExchangeOut(se).exchangeOut(
            IERC20(se), step.input, IERC20(address(vault)), 2, address(this), false, block.timestamp
        ), step.input);
        assertEq(vault.balanceOf(address(this)) - before, 2);
        (bytes memory actual, uint256 claim) = quote.quoteState(address(vault), address(this));
        _assertProjectedState(actual, step.state);
        assertEq(claim, step.claim, "unpaid conversion surplus remains backing");
    }

    function test_receiptAccounting_externalUnderlyingAndReceiptDeposits() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        address holder = address(indexedexManager.feeTo());
        IERC20(se).transfer(holder, IERC20(se).balanceOf(address(this)) / 2);
        _assertExternalDepositQuote(se, IERC20(address(vault)), IERC20(address(vault)), 10 ether, holder);
        _assertExternalDepositQuote(se, asset, IERC20(address(vault)), 20 ether, holder);
    }

    function test_receiptAccounting_externalUnderlyingConversionPreservesReserve() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        uint256 reserve = vault.balanceOf(se);
        uint256 issued = IERC20(se).totalSupply();
        _assertExternalExchangeQuote(se, asset, IERC20(address(vault)), 20 ether);
        assertEq(vault.balanceOf(se), reserve, "passthrough receipt belongs to paying user");
        assertEq(IERC20(se).totalSupply(), issued, "passthrough does not issue wrapper shares");
    }

    function testFuzz_receiptAccounting_sequenceWithYieldAndFeeRecipient(
        uint8 decimals_, uint64 yield_, bool feeHolder_
    ) public {
        uint256 unit = 10 ** bound(decimals_, 6, 18);
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", uint8(bound(decimals_, 6, 18)));
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(asset);
        address se = _deployERC4626SE(address(vault));
        address holder = feeHolder_ ? address(indexedexManager.feeTo()) : makeAddr("receipt quote holder");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        asset.mint(holder, 10_000 * unit);
        vm.startPrank(holder);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(9_000 * unit, holder);
        vault.approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(vault)), 1_000 * unit + 13, IERC20(se), 1, holder, false, block.timestamp);
        vm.stopPrank();
        uint256 accrued = bound(yield_, 1, 100 * unit);
        asset.mint(address(this), accrued);
        asset.approve(address(vault), accrued);
        vault.simulateYield(accrued);
        _assertQuoteSequence(se, IERC20(address(vault)), holder, unit);
    }
}
