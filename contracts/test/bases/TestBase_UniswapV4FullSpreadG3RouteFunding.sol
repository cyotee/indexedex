// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti as MultiIn} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti as MultiOut} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {FullSpreadQuantityReference as Reference} from "contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";

interface IFullSpreadG3Reserve {
    function rebalanceLiquidReserve() external;
    function deployedReserve() external view returns (uint256, uint256);
}

// tag::TestBase_UniswapV4FullSpreadG3Ledger[]
/// @notice G3-only observations and atomic callers around real family proxy fixtures.
abstract contract TestBase_UniswapV4FullSpreadG3Ledger is Test {
    struct G3Balances {
        uint256 supply;
        uint256 shares;
        uint256 selfShares;
        uint256 recipientShares;
        uint256[2] received;
        uint256[2] payer;
        uint256[2] payerAllowance;
        uint256[2] vaultPermitAllowance;
        uint160[2] permitAmount;
        uint48[2] permitExpiry;
        uint48[2] permitNonce;
        bytes32 fees;
    }
    struct G3Budget {
        uint256 snapshot;
        uint256 maximum;
        uint256 delivered;
        bool push;
        bytes data;
        bytes32 beforeHash;
    }
    IStandardExchangeProxy internal gVault;
    IERC20[2] internal gToken;
    address internal gManager;
    IPermit2 internal gPermit2;
    address internal constant G3_RECIPIENT = address(0x333333);

    function _gBlocked(bytes memory data_) internal virtual returns (bytes memory);
    function _gFees() internal view virtual returns (bytes32) { return bytes32(0); }

    function _gStart(IStandardExchangeProxy vault_, IERC20 a_, IERC20 b_, address manager_, IPermit2 permit2_) internal {
        gVault = vault_; gToken = [a_, b_]; gManager = manager_;
        gPermit2 = permit2_;
    }

    function _gTokens() internal view returns (address[] memory a) {
        a = new address[](2); a[0] = address(gToken[0]); a[1] = address(gToken[1]);
    }

    function _gAmounts(uint256 a_, uint256 b_) internal pure returns (uint256[] memory a) {
        a = new uint256[](2); a[0] = a_; a[1] = b_;
    }

    function _gCall(bytes memory data_, bool blocked_) internal returns (bytes memory result) {
        if (blocked_) return _gBlocked(data_);
        bool ok;
        (ok, result) = address(gVault).call(data_);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }

    /// @notice Transfers and calls occur in one revert scope, as for an integrating contract.
    function g3Atomic(address input_, uint256 delivered_, bytes calldata data_, bool blocked_)
        external returns (bytes memory)
    {
        require(msg.sender == address(this), "G3 self only");
        if (delivered_ != 0) IERC20(input_).transfer(address(gVault), delivered_);
        return _gCall(data_, blocked_);
    }

    function _gBooked() internal view {
        for (uint256 i; i < 2; ++i) {
            assertEq(gVault.reserveOfToken(address(gToken[i])), gToken[i].balanceOf(address(gVault)));
        }
        assertEq(gVault.reserveOfToken(address(gVault)), gVault.balanceOf(address(gVault)));
        assertEq(address(gVault).balance, 0);
    }

    function _gBalances() internal view returns (G3Balances memory b) {
        b.supply = gVault.totalSupply(); b.shares = gVault.balanceOf(address(this));
        b.selfShares = gVault.balanceOf(address(gVault)); b.recipientShares = gVault.balanceOf(G3_RECIPIENT);
        b.received = [gToken[0].balanceOf(G3_RECIPIENT), gToken[1].balanceOf(G3_RECIPIENT)];
        b.payer = [gToken[0].balanceOf(address(this)), gToken[1].balanceOf(address(this))];
        b.fees = _gFees();
        for (uint256 i; i < 2; ++i) {
            b.payerAllowance[i] = gToken[i].allowance(address(this), address(gVault));
            b.vaultPermitAllowance[i] = gToken[i].allowance(address(gVault), address(gPermit2));
            (b.permitAmount[i], b.permitExpiry[i], b.permitNonce[i]) =
                gPermit2.allowance(address(gVault), address(gToken[i]), gManager);
        }
    }

    /// @dev Crane ERC20 spends even max allowance. These ERC20 fixture routes settle
    /// with Currency.transfer, not Permit2.transferFrom: both Permit2 approval layers
    /// therefore have exactly zero consumption, independently of their initial value.
    function _gAssertAllowances(G3Balances memory before_, uint256 pulled0_, uint256 pulled1_) internal view {
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].allowance(address(this), address(gVault)),
                before_.payerAllowance[i] - (i == 0 ? pulled0_ : pulled1_), "exact payer allowance consumption");
            assertEq(gToken[i].allowance(address(gVault), address(gPermit2)), before_.vaultPermitAllowance[i]);
            (uint160 amount, uint48 expiry, uint48 nonce) =
                gPermit2.allowance(address(gVault), address(gToken[i]), gManager);
            assertEq(amount, before_.permitAmount[i]);
            assertEq(expiry, before_.permitExpiry[i]);
            assertEq(nonce, before_.permitNonce[i]);
            assertEq(gToken[i].allowance(address(gVault), gManager), 0);
        }
    }

    function _gAssetHash(IERC20 asset_, uint256 payerDebit_) private view returns (bytes32) {
        (uint160 allowed, uint48 expiry, uint48 nonce) = gPermit2.allowance(address(gVault), address(asset_), gManager);
        bytes32 custody = keccak256(abi.encode(
            asset_.balanceOf(address(this)), asset_.balanceOf(G3_RECIPIENT),
            asset_.balanceOf(address(gVault)), asset_.balanceOf(gManager)));
        bytes32 approvals = keccak256(abi.encode(
            asset_.allowance(address(this), address(gVault)) - payerDebit_,
            asset_.allowance(address(gVault), gManager),
            asset_.allowance(G3_RECIPIENT, address(gVault)),
            asset_.allowance(address(gVault), address(gPermit2)), allowed, expiry, nonce
        ));
        return keccak256(abi.encode(custody, approvals));
    }

    function _gDigest() internal view returns (bytes32) {
        return _gDigestWithPayerDebits(0, 0);
    }

    /// @dev Only F1 push/pull comparison normalizes the known funding-mode allowance
    /// difference. Each real allowance is checked separately; rollback/SY hashes are raw.
    function _gDigestWithPayerDebits(uint256 debit0_, uint256 debit1_) internal view returns (bytes32) {
        (bytes memory a,) = Transition(address(gVault)).quoteState(address(gToken[0]), address(this));
        (bytes memory b,) = Transition(address(gVault)).quoteState(address(gToken[1]), G3_RECIPIENT);
        bytes32 quotes = keccak256(abi.encode(a, b, gVault.totalSupply(), _gFees()));
        bytes32 assets = keccak256(abi.encode(
            _gAssetHash(gToken[0], debit0_), _gAssetHash(gToken[1], debit1_), _gAssetHash(IERC20(address(gVault)), 0)));
        bytes32 book = keccak256(abi.encode(
            gVault.reserveOfToken(address(gToken[0])), gVault.reserveOfToken(address(gToken[1])),
            gVault.reserveOfToken(address(gVault)), address(gVault).balance));
        return keccak256(abi.encode(quotes, assets, book));
    }

    function _gState(uint256 face_, bool blocked_) internal returns (bytes memory state) {
        (state,) = abi.decode(_gCall(abi.encodeCall(Transition.quoteState,
            (address(gToken[face_]), address(this))), blocked_), (bytes, uint256));
    }

    function _gReject(bytes memory data_, bytes memory error_, bool blocked_) internal {
        bytes32 beforeState = _gDigest();
        vm.expectRevert(error_);
        this.g3Atomic(address(gVault), 0, data_, blocked_);
        assertEq(_gDigest(), beforeState, "whole ledger rollback");
        _gBooked();
    }

    function _gExitData(uint256 maximum_, uint256[] memory outputs_, bool push_, bool linear_, uint256 face_)
        internal view returns (bytes memory)
    {
        if (linear_) return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(gVault)), maximum_, gToken[face_], outputs_[face_], G3_RECIPIENT, push_, block.timestamp));
        return abi.encodeCall(MultiOut.exchangeOutOneToMany,
            (IERC20(address(gVault)), maximum_, _gTokens(), outputs_, G3_RECIPIENT, push_, block.timestamp));
    }

    /// @dev Full E6 budget cells: exact/fat max, used-only/excess/over-max credit, short credit and short max.
    function _gExitMatrix(uint256 used_, uint256[] memory outputs_, bool blocked_, bool linear_, uint256 face_) internal {
        assertGt(used_, 0);
        for (uint256 mode; mode < 8; ++mode) {
            G3Budget memory c;
            c.snapshot = vm.snapshotState();
            c.push = mode >= 2;
            c.maximum = mode == 0 || mode == 2 ? used_ : used_ + 17;
            c.delivered = mode == 3 ? used_ : mode == 4 ? used_ + 9 : c.maximum;
            if (mode == 5) c.delivered = c.maximum + 11;
            if (mode == 6) c.delivered = used_ - 1;
            if (mode == 7) c.maximum = used_ - 1;
            c.data = _gExitData(c.maximum, outputs_, c.push, linear_, face_);
            c.beforeHash = _gDigest();
            if (mode >= 6) {
                bytes memory errorData = mode == 6
                    ? abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used_, c.delivered)
                    : abi.encodeWithSignature("UniswapV4ExchangeOut_InsufficientInput()");
                vm.expectRevert(errorData);
                this.g3Atomic(address(gVault), c.delivered, c.data, blocked_);
                assertEq(_gDigest(), c.beforeHash, "atomic share delivery restored");
            } else {
                _gSuccessfulExit(used_, outputs_, c.push ? c.delivered : 0, c.maximum, c.data, blocked_);
            }
            _gBooked();
            assertTrue(vm.revertToStateAndDelete(c.snapshot));
        }
        // The short-max guard must also reject the ordinary pull caller before movement.
        _gReject(_gExitData(used_ - 1, outputs_, false, linear_, face_),
            abi.encodeWithSignature("UniswapV4ExchangeOut_InsufficientInput()"), blocked_);
    }

    function _gSuccessfulExit(uint256 used_, uint256[] memory out_, uint256 delivered_, uint256 max_,
        bytes memory data_, bool blocked_) private
    {
        G3Balances memory b = _gBalances();
        Shapes.Snapshot memory beforeState = abi.decode(_gState(0, blocked_), (Shapes.Snapshot));
        assertEq(abi.decode(this.g3Atomic(address(gVault), delivered_, data_, blocked_), (uint256)), used_);
        uint256 retained = delivered_ > max_ ? delivered_ - max_ : 0;
        assertEq(gVault.totalSupply(), b.supply - used_);
        assertEq(gVault.balanceOf(address(this)), b.shares - used_ - retained);
        assertEq(gVault.balanceOf(address(gVault)), b.selfShares + retained);
        assertEq(gVault.balanceOf(G3_RECIPIENT), b.recipientShares);
        assertEq(gVault.allowance(address(this), address(gVault)), 0, "share exit needs no allowance");
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].balanceOf(G3_RECIPIENT), b.received[i] + out_[i]);
            assertEq(gToken[i].balanceOf(address(this)), b.payer[i]);
        }
        _gAssertAllowances(b, 0, 0);
        if (blocked_) assertEq(_gFees(), b.fees);
        if (blocked_) _gBlockedPayoutState(beforeState, out_);
    }

    function _gBlockedPayoutState(Shapes.Snapshot memory before_, uint256[] memory out_) private {
        Shapes.Snapshot memory afterState = abi.decode(_gState(0, true), (Shapes.Snapshot));
        assertEq(afterState.free0, before_.free0 - out_[0]);
        assertEq(afterState.free1, before_.free1 - out_[1]);
        assertEq(afterState.fees0, before_.fees0);
        assertEq(afterState.fees1, before_.fees1);
        assertEq(afterState.positionLiquidity, before_.positionLiquidity);
        assertEq(afterState.lower, before_.lower);
        assertEq(afterState.upper, before_.upper);
        assertEq(keccak256(abi.encode(afterState.pool)), keccak256(abi.encode(before_.pool)));
    }
}
// end::TestBase_UniswapV4FullSpreadG3Ledger[]

// tag::TestBase_UniswapV4FullSpreadG3RouteFunding[]
/// @notice Missing R1/R4/R7/R8/R9 funding cells, independently instantiated by H and P.
abstract contract TestBase_UniswapV4FullSpreadG3RouteFunding is TestBase_UniswapV4FullSpreadG3Ledger {
    function _gBootstrap() internal virtual;
    function _gPoolKey() internal view virtual returns (PoolKey memory);

    struct G3CoreBook {
        uint160 price;
        uint160 lowerPrice;
        uint160 upperPrice;
        uint128 liquidity;
        uint256 last0;
        uint256 last1;
        uint256 growth0;
        uint256 growth1;
    }

    struct G3DualJoin {
        G3Balances beforeFunding;
        uint256[2] backing;
        uint256[2] local;
        uint256[2] amounts;
        uint256 minted;
    }

    /// @dev Independent observation: raw custody + signed-position principal rounded
    /// down + modular inside-fee-growth entitlement. Neither vault quotes nor its
    /// geometric-rate helper participate in the expected value.
    function _gObservedBacking() private view returns (uint256[2] memory backing, uint128 liquidity) {
        PoolKey memory key = _gPoolKey();
        IPoolManager manager = IPoolManager(gManager);
        int24 lower = TickMath.minUsableTick(key.tickSpacing);
        int24 upper = TickMath.maxUsableTick(key.tickSpacing);
        G3CoreBook memory c;
        (c.price,,,) = StateLibrary.getSlot0(manager, PoolIdLibrary.toId(key));
        (c.liquidity, c.last0, c.last1) = StateLibrary.getPositionInfo(
            manager, PoolIdLibrary.toId(key), address(gVault), lower, upper, bytes32(0));
        (c.growth0, c.growth1) = StateLibrary.getFeeGrowthInside(manager, PoolIdLibrary.toId(key), lower, upper);
        unchecked { c.growth0 -= c.last0; c.growth1 -= c.last1; }
        backing[0] = gToken[0].balanceOf(address(gVault)) + Math.mulDiv(c.growth0, c.liquidity, uint256(1) << 128);
        backing[1] = gToken[1].balanceOf(address(gVault)) + Math.mulDiv(c.growth1, c.liquidity, uint256(1) << 128);
        c.lowerPrice = TickMath.getSqrtPriceAtTick(lower);
        c.upperPrice = TickMath.getSqrtPriceAtTick(upper);
        if (c.price < c.upperPrice) backing[0] += SqrtPriceMath.getAmount0Delta(
            c.price > c.lowerPrice ? c.price : c.lowerPrice, c.upperPrice, c.liquidity, false);
        if (c.price > c.lowerPrice) backing[1] += SqrtPriceMath.getAmount1Delta(
            c.lowerPrice, c.price < c.upperPrice ? c.price : c.upperPrice, c.liquidity, false);
        liquidity = c.liquidity;
    }

    /// @notice Intentional dual excess is retained on either face and priced by F0's min floor, not F5's 1 bp gate.
    function test_unbalancedMultiJoinRetainsExcessBothFaces() public {
        _gBootstrap();
        for (uint256 face; face < 2; ++face) {
            uint256 snapshot = vm.snapshotState();
            _gUnbalancedJoin(face);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function _gUnbalancedJoin(uint256 face_) private {
        G3DualJoin memory c;
        c.beforeFunding = _gBalances();
        (c.backing,) = _gObservedBacking();
        c.local = [gToken[0].balanceOf(address(gVault)), gToken[1].balanceOf(address(gVault))];
        c.amounts = [uint256(1e18), uint256(1e18)];
        c.amounts[face_] = 9e18;
        uint256 floor0 = c.beforeFunding.supply * c.amounts[0] / c.backing[0];
        uint256 floor1 = c.beforeFunding.supply * c.amounts[1] / c.backing[1];
        c.minted = floor0 < floor1 ? floor0 : floor1;
        assertGt(c.minted, 0);
        assertGt(face_ == 0 ? floor0 : floor1, c.minted);
        uint256 attributed = Math.mulDiv(c.minted, c.backing[face_], c.beforeFunding.supply, Math.Rounding.Ceil);
        assertGt(c.amounts[face_] - attributed, c.amounts[face_] / 2, "material identified excess");
        Shapes.Snapshot memory beforeState = abi.decode(_gState(0, true), (Shapes.Snapshot));
        uint256[] memory amounts = _gAmounts(c.amounts[0], c.amounts[1]);
        assertEq(abi.decode(_gBlocked(abi.encodeCall(MultiIn.previewExchangeInManyToOne,
            (_gTokens(), amounts, IERC20(address(gVault))))), (uint256)), c.minted);
        assertEq(abi.decode(_gBlocked(abi.encodeCall(MultiIn.exchangeInManyToOne,
            (_gTokens(), amounts, IERC20(address(gVault)), c.minted, G3_RECIPIENT, false, block.timestamp))), (uint256)), c.minted);
        _gAssertDualJoinResult(c, beforeState);
    }

    function _gAssertDualJoinResult(G3DualJoin memory c, Shapes.Snapshot memory before_) private {
        assertEq(gVault.totalSupply(), c.beforeFunding.supply + c.minted);
        assertEq(gVault.balanceOf(G3_RECIPIENT), c.beforeFunding.recipientShares + c.minted);
        assertEq(gVault.balanceOf(address(this)), c.beforeFunding.shares);
        assertEq(gVault.balanceOf(address(gVault)), c.beforeFunding.selfShares);
        (uint256[2] memory backing,) = _gObservedBacking();
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].balanceOf(address(this)), c.beforeFunding.payer[i] - c.amounts[i], "no excess refund");
            assertEq(gToken[i].balanceOf(G3_RECIPIENT), c.beforeFunding.received[i]);
            assertEq(gToken[i].balanceOf(address(gVault)), c.local[i] + c.amounts[i]);
            assertEq(backing[i], c.backing[i] + c.amounts[i], "full contribution retained in backing");
        }
        Shapes.Snapshot memory afterState = abi.decode(_gState(0, true), (Shapes.Snapshot));
        assertEq(afterState.free0, before_.free0 + c.amounts[0]);
        assertEq(afterState.free1, before_.free1 + c.amounts[1]);
        assertEq(afterState.positionLiquidity, before_.positionLiquidity);
        assertEq(afterState.fees0, before_.fees0);
        assertEq(afterState.fees1, before_.fees1);
        assertEq(keccak256(abi.encode(afterState.pool)), keccak256(abi.encode(before_.pool)));
        assertEq(_gFees(), c.beforeFunding.fees);
        _gAssertAllowances(c.beforeFunding, c.amounts[0], c.amounts[1]);
        _gBooked();
    }

    /// @notice Exact SY metadata and geometric whole-book rate, including a deployed and intentionally unequal book.
    function test_SYMetadataAndGeometricExchangeRateExact() public {
        assertEq(SY(address(gVault)).exchangeRate(), 1e18, "empty rate");
        _gBootstrap();
        _gAssertSYMetadata();
        uint256 initialRate = _gAssertGeometricRate();
        _gUnbalancedJoin(0);
        assertGt(_gAssertGeometricRate(), initialRate, "retained excess increases geometric backing per share");
        _gBooked();
    }

    function _gAssertSYMetadata() private {
        bytes32 beforeState = _gDigest();
        SY sy = SY(address(gVault));
        (SY.AssetType kind, address asset, uint8 decimals) = sy.assetInfo();
        assertEq(uint256(kind), uint256(SY.AssetType.LIQUIDITY));
        assertEq(asset, gManager);
        assertEq(decimals, 18);
        assertEq(sy.yieldToken(), address(0));
        address[] memory input = sy.getTokensIn();
        address[] memory output = sy.getTokensOut();
        assertEq(input.length, 2); assertEq(output.length, 2);
        for (uint256 i; i < 2; ++i) {
            assertEq(input[i], address(gToken[i])); assertEq(output[i], address(gToken[i]));
            assertTrue(sy.isValidTokenIn(input[i])); assertTrue(sy.isValidTokenOut(output[i]));
        }
        assertFalse(sy.isValidTokenIn(address(gVault))); assertFalse(sy.isValidTokenOut(address(gVault)));
        assertFalse(sy.isValidTokenIn(address(0))); assertFalse(sy.isValidTokenOut(address(0)));
        assertEq(sy.getRewardTokens().length, 0);
        assertEq(sy.accruedRewards(address(this)).length, 0);
        assertEq(sy.rewardIndexesStored().length, 0);
        assertEq(sy.rewardIndexesCurrent().length, 0);
        assertEq(sy.claimRewards(G3_RECIPIENT).length, 0);
        assertEq(_gDigest(), beforeState, "metadata/reward surfaces preserve ledger");
    }

    function _gAssertGeometricRate() private returns (uint256 expected) {
        (uint256[2] memory backing, uint128 liquidity) = _gObservedBacking();
        assertGt(liquidity, 0, "rate includes real deployed principal");
        assertGt(backing[0], gToken[0].balanceOf(address(gVault)));
        assertGt(backing[1], gToken[1].balanceOf(address(gVault)));
        // This fixture is deliberately bounded so the independent product and
        // integer binary square root fit uint256. No production mulSqrt is reused.
        assertLe(backing[0], type(uint128).max); assertLe(backing[1], type(uint128).max);
        uint256 root = _gIntegerSqrt(backing[0] * backing[1]);
        expected = root * 1e18 / gVault.totalSupply();
        bytes32 beforeState = _gDigest();
        assertEq(SY(address(gVault)).exchangeRate(), expected);
        assertEq(abi.decode(_gBlocked(abi.encodeCall(SY.exchangeRate, ())), (uint256)), expected);
        assertEq(_gDigest(), beforeState, "rate queries preserve ledger");
    }

    function _gIntegerSqrt(uint256 value_) private pure returns (uint256 lower) {
        uint256 upper = uint256(1) << 128;
        while (lower + 1 < upper) {
            uint256 middle = (lower + upper) / 2;
            if (middle <= value_ / middle) lower = middle;
            else upper = middle;
        }
    }

    /// @notice R1 blocked exact-input preview and execution reject both directions and funding flags.
    function test_blockedDirectExactInputRejectsBothDirections() public {
        _gBootstrap();
        for (uint256 i; i < 2; ++i) {
            bytes memory errorData = abi.encodeWithSignature("UniswapV4Exchange_PoolManagerInteractionBlocked()");
            _gReject(abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
                (gToken[i], 1e18, gToken[1-i])), errorData, true);
            for (uint256 push; push < 2; ++push) {
                bytes32 beforeState = _gDigest();
                bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
                    (gToken[i], 1e18, gToken[1-i], 0, G3_RECIPIENT, push != 0, block.timestamp));
                vm.expectRevert(errorData);
                this.g3Atomic(address(gToken[i]), push == 0 ? 0 : 1e18, data, true);
                assertEq(_gDigest(), beforeState);
                _gBooked();
            }
        }
    }

    /// @notice First-ever F0 blocked activation has no position until idle public placement.
    function test_blockedFirstDualActivationThenIdlePlacement() public {
        uint256[] memory amounts = _gAmounts(1000e18, 1000e18);
        G3Balances memory fundingBefore = _gBalances();
        uint256 quote = abi.decode(_gBlocked(abi.encodeCall(MultiIn.previewExchangeInManyToOne,
            (_gTokens(), amounts, IERC20(address(gVault))))), (uint256));
        assertEq(quote, 1000e18 - 1e15);
        assertEq(abi.decode(_gBlocked(abi.encodeCall(MultiIn.exchangeInManyToOne,
            (_gTokens(), amounts, IERC20(address(gVault)), quote, G3_RECIPIENT, false, block.timestamp))), (uint256)), quote);
        assertEq(gVault.totalSupply(), 1000e18);
        assertEq(gVault.balanceOf(G3_RECIPIENT), quote);
        assertEq(gVault.balanceOf(address(0xdEaD)), 1e15);
        assertEq(gVault.balanceOf(address(this)), 0);
        Shapes.Snapshot memory beforePlacement = abi.decode(_gState(0, false), (Shapes.Snapshot));
        assertEq(beforePlacement.positionLiquidity, 0);
        assertEq(beforePlacement.free0, amounts[0]);
        assertEq(beforePlacement.free1, amounts[1]);
        _gAssertAllowances(fundingBefore, amounts[0], amounts[1]);
        _gBooked();
        IFullSpreadG3Reserve(address(gVault)).rebalanceLiquidReserve();
        Shapes.Snapshot memory afterPlacement = abi.decode(_gState(0, false), (Shapes.Snapshot));
        assertGt(afterPlacement.positionLiquidity, 0);
        assertEq(afterPlacement.lower, beforePlacement.lower);
        assertEq(afterPlacement.upper, beforePlacement.upper);
        assertEq(afterPlacement.pool.sqrtPriceX96, beforePlacement.pool.sqrtPriceX96);
        assertEq(gVault.totalSupply(), 1000e18);
        assertEq(gVault.balanceOf(G3_RECIPIENT), quote);
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].balanceOf(address(this)), fundingBefore.payer[i] - amounts[i]);
            assertEq(gToken[i].balanceOf(G3_RECIPIENT), 0);
        }
        _gAssertAllowances(fundingBefore, amounts[0], amounts[1]);
        _gBooked();
    }

    /// @notice R4 F1 exact shares: prior unprepaid quote and identical full post-state for atomic push/pull.
    function test_blockedF1AtomicPushEqualsPullOnRestoredState() public {
        _gBootstrap();
        for (uint256 i; i < 2; ++i) {
            uint256 used = abi.decode(_gBlocked(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (gToken[i], IERC20(address(gVault)), 1e18))), (uint256));
            assertEq(used, Reference.input(_gState(i, true), 1e18));
            uint256 snapshot = vm.snapshotState();
            _gF1(i, used, false);
            bytes32 pullState = _gDigest();
            assertTrue(vm.revertToStateAndDelete(snapshot));
            _gF1(i, used, true);
            assertEq(_gDigestWithPayerDebits(i == 0 ? used : 0, i == 1 ? used : 0),
                pullState, "same F1 state with exact funding-mode allowance adjustment");
        }
    }

    function _gF1(uint256 i_, uint256 used_, bool push_) private {
        G3Balances memory b = _gBalances();
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (gToken[i_], used_ + 123, IERC20(address(gVault)), 1e18, G3_RECIPIENT, push_, block.timestamp));
        assertEq(abi.decode(this.g3Atomic(address(gToken[i_]), push_ ? used_ + 123 : 0, data, true), (uint256)), used_);
        assertEq(gVault.totalSupply(), b.supply + 1e18);
        assertEq(gVault.balanceOf(G3_RECIPIENT), b.recipientShares + 1e18);
        assertEq(gVault.balanceOf(address(this)), b.shares);
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].balanceOf(address(this)), b.payer[i] - (i == i_ ? used_ : 0));
            assertEq(gToken[i].balanceOf(G3_RECIPIENT), 0);
        }
        _gAssertAllowances(b, !push_ && i_ == 0 ? used_ : 0, !push_ && i_ == 1 ? used_ : 0);
        assertEq(_gFees(), b.fees);
        _gBooked();
    }

    /// @notice R8 E6 matrix in both idle and real unavailable-manager contexts.
    function test_F3PushAndPullBudgetMatrix() public {
        _gBootstrap();
        gVault.transfer(address(gVault), 31);
        IFullSpreadG3Reserve(address(gVault)).rebalanceLiquidReserve();
        assertEq(gVault.reserveOfToken(address(gVault)), 31, "booked shares cannot finance refunds");
        uint256[] memory outputs = _gAmounts(1e18, 1e18);
        for (uint256 blocked; blocked < 2; ++blocked) {
            uint256 used = abi.decode(_gCall(abi.encodeCall(MultiOut.previewExchangeOutOneToMany,
                (IERC20(address(gVault)), _gTokens(), outputs)), blocked != 0), (uint256));
            for (uint256 i; i < 2; ++i) {
                (Shapes.Snapshot memory q, uint256 backing,) = Reference.backing(_gState(i, blocked != 0));
                assertEq(used, Math.mulDiv(outputs[i], q.supply, backing, Math.Rounding.Ceil));
            }
            _gExitMatrix(used, outputs, blocked != 0, false, 0);
        }
    }

    /// @notice F3 independently equal-ceil vectors isolate shortage in each local currency.
    function test_F3EachLocalLegShortageRollsBack() public {
        _gBootstrap();
        for (uint256 shortLeg; shortLeg < 2; ++shortLeg) {
            uint256 snapshot = vm.snapshotState();
            // Real donation makes the OTHER leg amply liquid. No reserve or token storage mutation.
            gToken[1-shortLeg].transfer(address(gVault), 3000e18);
            uint256[] memory outputs = new uint256[](2);
            uint256 burn;
            for (uint256 i; i < 2; ++i) {
                (, uint256 backing,) = Reference.backing(_gState(i, true));
                // Make backing even with a real one-unit donation, so both ceilings equal ceil(S/2).
                if (backing % 2 != 0) { gToken[i].transfer(address(gVault), 1); ++backing; }
                outputs[i] = backing / 2;
                uint256 required = Math.mulDiv(outputs[i], gVault.totalSupply(), backing, Math.Rounding.Ceil);
                if (i == 0) burn = required; else assertEq(required, burn);
            }
            assertLe(burn, gVault.balanceOf(address(this)));
            assertLe(outputs[1-shortLeg], gToken[1-shortLeg].balanceOf(address(gVault)));
            uint256 local = gToken[shortLeg].balanceOf(address(gVault));
            assertGt(outputs[shortLeg], local);
            bytes memory errorData = abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)",
                address(gToken[shortLeg]), outputs[shortLeg], local);
            bytes32 beforeHash = _gDigest();
            vm.expectRevert(errorData);
            this.g3Atomic(address(gVault), 0, abi.encodeCall(MultiOut.previewExchangeOutOneToMany,
                (IERC20(address(gVault)), _gTokens(), outputs)), true);
            assertEq(_gDigest(), beforeHash);
            for (uint256 push; push < 2; ++push) {
                vm.expectRevert(errorData);
                this.g3Atomic(address(gVault), push == 0 ? 0 : burn + 17,
                    _gExitData(burn + 17, outputs, push != 0, false, 0), true);
                assertEq(_gDigest(), beforeHash, "shortage restores both payouts, credit and approvals");
            }
            // Donated inputs intentionally remain unbooked after a rejected call.
            assertTrue(vm.revertToStateAndDelete(snapshot));
            _gBooked();
        }
    }

    /// @notice Canonical-vector validation and actual second-leg delivery are separate guards.
    function test_multiMalformedVectorsAndMissingSecondCredit() public {
        _gBootstrap();
        for (uint256 mode; mode < 7; ++mode) {
            address[] memory tokens = _gTokens();
            uint256[] memory amounts = _gAmounts(1e18, 1e18);
            IERC20 output = IERC20(address(gVault));
            if (mode == 0) { tokens[0] = address(gToken[1]); tokens[1] = address(gToken[0]); }
            if (mode == 1) tokens[1] = tokens[0];
            if (mode == 2) tokens[1] = address(this);
            if (mode == 3) output = gToken[0];
            if (mode == 4) amounts = new uint256[](1);
            if (mode == 5) amounts[0] = 0;
            if (mode == 6) amounts[1] = 0;
            bytes memory errorData = abi.encodeWithSelector(IStandardExchangeIn.ExchangeInNotAvailable.selector);
            _gReject(abi.encodeCall(MultiIn.previewExchangeInManyToOne, (tokens, amounts, output)), errorData, false);
            for (uint256 blocked; blocked < 2; ++blocked) {
                _gReject(abi.encodeCall(MultiIn.exchangeInManyToOne,
                    (tokens, amounts, output, 0, G3_RECIPIENT, false, block.timestamp)), errorData, blocked != 0);
                bytes memory outError = abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
                _gReject(abi.encodeCall(MultiOut.previewExchangeOutOneToMany,
                    (output, tokens, amounts)), outError, blocked != 0);
                _gReject(abi.encodeCall(MultiOut.exchangeOutOneToMany,
                    (output, 1e18, tokens, amounts, G3_RECIPIENT, false, block.timestamp)), outError, blocked != 0);
            }
        }
        for (uint256 blocked; blocked < 2; ++blocked) {
            bytes32 beforeState = _gDigest();
            bytes memory data = abi.encodeCall(MultiIn.exchangeInManyToOne,
                (_gTokens(), _gAmounts(1e18, 1e18), IERC20(address(gVault)), 0, G3_RECIPIENT, true, block.timestamp));
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
            this.g3Atomic(address(gToken[0]), 1e18, data, blocked != 0);
            assertEq(_gDigest(), beforeState, "first delivered leg rolled back atomically");
            _gBooked();
        }
    }

    /// @notice Both idle SY aliases preserve previews, distinct-recipient effects and entire state.
    function test_idleSYAliasesBothFaces() public {
        _gBootstrap();
        for (uint256 face; face < 2; ++face) for (uint256 mode; mode < 3; ++mode) {
            if (mode == 2) gVault.transfer(address(gVault), 1e18 + 17);
            uint256 snapshot = vm.snapshotState();
            uint256 quote = mode == 0
                ? gVault.previewExchangeIn(gToken[face], 1e18, IERC20(address(gVault)))
                : gVault.previewExchangeIn(IERC20(address(gVault)), 1e18, gToken[face]);
            uint256 syQuote = mode == 0 ? SY(address(gVault)).previewDeposit(address(gToken[face]), 1e18)
                : SY(address(gVault)).previewRedeem(address(gToken[face]), 1e18);
            assertEq(quote, syQuote);
            _gAlias(face, mode, quote, false);
            bytes32 seState = _gDigest();
            assertTrue(vm.revertToStateAndDelete(snapshot));
            _gAlias(face, mode, quote, true);
            assertEq(_gDigest(), seState);
        }
    }

    function _gAlias(uint256 face_, uint256 mode_, uint256 quote_, bool sy_) private {
        // Taken after bootstrap/prior cells and, for internal redeem, after share
        // prefunding. Restoring the comparison snapshot restores these allowances too.
        G3Balances memory b = _gBalances();
        uint256 result;
        if (sy_) result = mode_ == 0
            ? SY(address(gVault)).deposit(G3_RECIPIENT, address(gToken[face_]), 1e18, quote_)
            : SY(address(gVault)).redeem(G3_RECIPIENT, 1e18, address(gToken[face_]), quote_, mode_ == 2);
        else result = mode_ == 0
            ? gVault.exchangeIn(gToken[face_], 1e18, IERC20(address(gVault)), quote_, G3_RECIPIENT, false, block.timestamp)
            : gVault.exchangeIn(IERC20(address(gVault)), 1e18, gToken[face_], quote_, G3_RECIPIENT, mode_ == 2, block.timestamp);
        assertEq(result, quote_);
        assertEq(gVault.totalSupply(), mode_ == 0 ? b.supply + quote_ : b.supply - 1e18);
        assertEq(gVault.balanceOf(address(this)), mode_ == 1 ? b.shares - 1e18 : b.shares);
        assertEq(gVault.balanceOf(address(gVault)), mode_ == 2 ? b.selfShares - 1e18 : b.selfShares);
        assertEq(gVault.balanceOf(G3_RECIPIENT), b.recipientShares + (mode_ == 0 ? quote_ : 0));
        for (uint256 i; i < 2; ++i) {
            assertEq(gToken[i].balanceOf(address(this)), b.payer[i] - (mode_ == 0 && i == face_ ? 1e18 : 0));
            assertEq(gToken[i].balanceOf(G3_RECIPIENT), b.received[i] + (mode_ != 0 && i == face_ ? quote_ : 0));
        }
        _gAssertAllowances(b, mode_ == 0 && face_ == 0 ? 1e18 : 0, mode_ == 0 && face_ == 1 ? 1e18 : 0);
        _gBooked();
    }
}
// end::TestBase_UniswapV4FullSpreadG3RouteFunding[]

// tag::TestBase_UniswapV4FullSpreadG3LinearFunding[]
/// @notice Linear R6 funding checks use natural one-sided books, never the two-backed-leg inverse.
abstract contract TestBase_UniswapV4FullSpreadG3LinearFunding is TestBase_UniswapV4FullSpreadG3Ledger {
    function _gOneSided(uint256 face_) internal virtual;

    /// @dev Symmetric extension of the existing P OneBackedLeg exact-basket fixture.
    function _gFundLinearBasket(uint256 face_, uint160 q_, int24 spacing_) internal {
        uint160 a = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(spacing_));
        uint160 b = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(spacing_));
        uint256 amount0;
        uint256 amount1;
        bool found;
        for (uint256 i; i < 10_000; ++i) {
            uint128 liquidity;
            if (face_ == 0) {
                amount1 = 1e9 + i;
                liquidity = LiquidityAmounts.getLiquidityForAmount1(a, q_, amount1);
                amount0 = SqrtPriceMath.getAmount0Delta(q_, b, liquidity, true);
            } else {
                amount0 = 1e9 + i;
                liquidity = LiquidityAmounts.getLiquidityForAmount0(q_, b, amount0);
                amount1 = SqrtPriceMath.getAmount1Delta(a, q_, liquidity, true);
            }
            uint128 target = LiquidityAmounts.getLiquidityForAmounts(q_, a, b, amount0, amount1);
            if (target == 0) continue;
            uint256 opposingDebt = face_ == 0 ? SqrtPriceMath.getAmount1Delta(a, q_, target - 1, true)
                : SqrtPriceMath.getAmount0Delta(q_, b, target - 1, true);
            if (opposingDebt == (face_ == 0 ? amount1 : amount0)) { found = true; break; }
        }
        assertTrue(found, "exact opposing-leg placement basket");
        _gActivateLinearBasket(amount0, amount1, face_);
    }

    function _gActivateLinearBasket(uint256 amount0, uint256 amount1, uint256 face_) private {
        G3Balances memory beforeFunding = _gBalances();
        uint256 quoted = MultiIn(address(gVault)).previewExchangeInManyToOne(
            _gTokens(), _gAmounts(amount0, amount1), IERC20(address(gVault)));
        assertEq(MultiIn(address(gVault)).exchangeInManyToOne(_gTokens(), _gAmounts(amount0, amount1),
            IERC20(address(gVault)), quoted, address(this), false, block.timestamp), quoted);
        assertEq(gToken[1-face_].balanceOf(address(gVault)), 0);
        _gAssertAllowances(beforeFunding, amount0, amount1);
        _gBooked();
    }

    /// @notice Both natural one-sided orientations preserve exact payout and bounded pushed-share refunds.
    function test_linearExactOutRefundMatrixBothOrientations() public {
        for (uint256 face; face < 2; ++face) {
            uint256 snapshot = vm.snapshotState();
            _gOneSided(face);
            gVault.transfer(address(gVault), 31);
            IFullSpreadG3Reserve(address(gVault)).rebalanceLiquidReserve();
            assertEq(gVault.reserveOfToken(address(gVault)), 31);
            bytes memory state = _gState(face, true);
            (Shapes.Snapshot memory q, uint256 backing, uint256 opposite) = Reference.backing(state);
            assertEq(opposite, 0, "linear domain must be real");
            uint256 output = 1;
            uint256 used = abi.decode(_gBlocked(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (IERC20(address(gVault)), gToken[face], output))), (uint256));
            assertEq(used, Math.mulDiv(output, q.supply, backing, Math.Rounding.Ceil));
            uint256[] memory outputs = _gAmounts(face == 0 ? output : 0, face == 1 ? output : 0);
            _gExitMatrix(used, outputs, true, true, face);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }
}
// end::TestBase_UniswapV4FullSpreadG3LinearFunding[]
