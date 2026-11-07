// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {Vm} from "forge-std/Vm.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SinglePositionAware} from "@crane/contracts/interfaces/IUniswapV4SinglePositionAware.sol";
import {IUniswapV4ProtocolAware} from "@crane/contracts/interfaces/IUniswapV4ProtocolAware.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

/// @notice Native ownership ledger shared by deterministic FullSpread cases and fuzz campaigns.
/// @dev Only external conversion transfers are observations. Accepted/withdrawn components are
/// derived independently; hook balance/book getters never become the next expected book.
abstract contract HookComponentLedger is Test {
    struct NativeLeg {
        address pair;
        address se;
        uint256 shares;
        uint256 local;
        uint256 raw;
        uint256 ambientPair;
        uint256 ambientShares;
        uint256 bootstrapBurn;
        uint256 bootstrapReceipt;
    }

    struct ConversionReceipt {
        uint256 pairIn;
        uint256 pairOut;
        uint256 sharesMinted;
        uint256 sharesBurned;
    }

    struct CallerInventory {
        uint256 pairBefore;
        uint256 sharesBefore;
        uint256 availablePair;
        uint256 availableShares;
        uint256 acceptedPair;
        uint256 acceptedShares;
        uint256 returnedPair;
        uint256 returnedShares;
    }

    NativeLeg[] internal nativeBooks;
    CallerInventory[] internal callerInventory;
    address internal ledgerHook;
    address internal ledgerFeeTo;
    uint256 internal ledgerSupply;
    uint256 internal ledgerFeeBalance;
    uint256 internal ledgerGrossMinted;
    uint256 internal ledgerNetMinted;
    uint256 internal ledgerFeeMinted;
    uint256 internal ledgerBurned;
    mapping(address => uint256) internal ledgerLp;

    function _ledgerInit(address hook_, address[] memory pairs_, address[] memory ses_, address feeTo_) internal {
        assertEq(IERC20(hook_).totalSupply(), 0, "ledger witnesses genesis, not a copied live book");
        assertEq(nativeBooks.length, 0, "one ledger initialization");
        ledgerHook = hook_;
        ledgerFeeTo = feeTo_;
        for (uint256 i; i < pairs_.length; ++i) {
            nativeBooks.push(NativeLeg(pairs_[i], ses_[i], 0, 0, 0, 0, 0, 0, 0));
            callerInventory.push();
        }
        _ledgerAssert();
    }

    function _ledgerBegin(address actor_) internal {
        _ledgerAssert();
        assertEq(IERC20(ledgerHook).balanceOf(actor_),
            actor_ == ledgerFeeTo ? ledgerFeeBalance : ledgerLp[actor_], "independent caller LP");
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            delete callerInventory[i];
            callerInventory[i].pairBefore = IERC20(leg.pair).balanceOf(actor_);
            if (leg.se != address(0)) callerInventory[i].sharesBefore = IERC20(leg.se).balanceOf(actor_);
        }
        vm.recordLogs();
    }

    /// @dev External vaults may pay directly from their underlying protocol. Exclude only the
    /// caller and settlement boundary; neither is an external conversion receipt. These fixtures
    /// have disjoint token roles and no transfer-tax/rebasing assets.
    function _ledgerReceipt(Vm.Log[] memory logs_, uint256 i_, address actor_, address boundary_)
        internal view returns (ConversionReceipt memory r)
    {
        NativeLeg storage leg = nativeBooks[i_];
        if (leg.se == address(0)) return r;
        for (uint256 j; j < logs_.length; ++j) {
            Vm.Log memory entry = logs_[j];
            if (entry.topics.length != 3 || entry.topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(entry.topics[1])));
            address to = address(uint160(uint256(entry.topics[2])));
            uint256 amount = abi.decode(entry.data, (uint256));
            if (entry.emitter == leg.se) {
                if (from == address(0) && to == ledgerHook) r.sharesMinted += amount;
                if (from == ledgerHook && to == address(0)) r.sharesBurned += amount;
            } else if (entry.emitter == leg.pair) {
                if (to == ledgerHook && from != actor_ && from != boundary_) r.pairIn += amount;
                if (from == ledgerHook && to != actor_ && to != boundary_) r.pairOut += amount;
            }
        }
    }

    function _ledgerJoin(address actor_, uint256[] memory amounts_, bool[] memory sharesIn_, uint256 net_, uint256 fee_)
        internal
    {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 oldSupply = ledgerSupply;
        uint256 gross = type(uint256).max;
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            CallerInventory storage inventory = callerInventory[i];
            ConversionReceipt memory receipt = _ledgerReceipt(logs_, i, actor_, address(0));
            inventory.availablePair = (sharesIn_[i] ? 0 : amounts_[i]) + receipt.pairIn - receipt.pairOut;
            inventory.availableShares = (sharesIn_[i] ? amounts_[i] : 0) + receipt.sharesMinted - receipt.sharesBurned;
            if (oldSupply == 0 && leg.se != address(0)) {
                assertEq(receipt.sharesMinted, 0, "genesis cannot mint SE shares internally");
                assertEq(receipt.sharesBurned, amounts_[i] / 20, "actual five percent share burn");
                assertGt(receipt.sharesBurned, 0, "funded seed burns shares");
                assertGt(receipt.pairIn, 0, "funded seed receives real pair tokens");
                assertEq(receipt.pairOut, 0, "bootstrap never redeposits its local receipt");
                leg.bootstrapBurn = receipt.sharesBurned;
                leg.bootstrapReceipt = receipt.pairIn;
            }
            if (oldSupply != 0) {
                uint256 pairBook = leg.se == address(0) ? leg.raw : leg.local;
                if (pairBook != 0) gross = Math.min(gross, Math.mulDiv(inventory.availablePair, oldSupply, pairBook));
                if (leg.shares != 0) gross = Math.min(gross, Math.mulDiv(inventory.availableShares, oldSupply, leg.shares));
            }
        }
        // Genesis denomination remains family-specific. All later gross issuance is independently
        // determined from the limiting native component of the actual assembled caller basket.
        if (oldSupply == 0) gross = IERC20(ledgerHook).totalSupply() - 1000;
        assertGt(gross, 0, "nonzero backed gross");
        assertLt(gross, type(uint256).max, "a live positive component limits issuance");
        uint256 feeLp = ledgerFeeTo == address(0) ? 0 : Math.mulDiv(gross, fee_, 1e18);
        if (net_ != gross - feeLp) {
            emit log_named_uint("ledger pre-intake supply", oldSupply);
            emit log_named_uint("ledger gross", gross);
            emit log_named_uint("ledger fee", feeLp);
            for (uint256 i; i < nativeBooks.length; ++i) {
                emit log_named_address("ledger leg", nativeBooks[i].pair);
                emit log_named_uint("ledger booked pair", nativeBooks[i].se == address(0) ? nativeBooks[i].raw : nativeBooks[i].local);
                emit log_named_uint("ledger booked shares", nativeBooks[i].shares);
                emit log_named_uint("ledger available pair", callerInventory[i].availablePair);
                emit log_named_uint("ledger available shares", callerInventory[i].availableShares);
            }
        }
        assertEq(net_, gross - feeLp, "net follows independent gross and configured fee");
        ledgerSupply += gross + (oldSupply == 0 ? 1000 : 0);
        ledgerFeeBalance += feeLp;
        ledgerLp[actor_] += net_;
        ledgerGrossMinted += gross;
        ledgerNetMinted += net_;
        ledgerFeeMinted += feeLp;
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            CallerInventory storage inventory = callerInventory[i];
            uint256 pairBook = leg.se == address(0) ? leg.raw : leg.local;
            inventory.acceptedPair = oldSupply == 0 ? inventory.availablePair : _ledgerCeil(gross, pairBook, oldSupply);
            inventory.acceptedShares = oldSupply == 0 ? inventory.availableShares : _ledgerCeil(gross, leg.shares, oldSupply);
            inventory.returnedPair = inventory.availablePair - inventory.acceptedPair;
            inventory.returnedShares = inventory.availableShares - inventory.acceptedShares;
            if (leg.se == address(0)) leg.raw += inventory.acceptedPair;
            else leg.local += inventory.acceptedPair;
            leg.shares += inventory.acceptedShares;
            assertEq(IERC20(leg.pair).balanceOf(actor_),
                inventory.pairBefore - (sharesIn_[i] ? 0 : amounts_[i]) + inventory.returnedPair, "caller pair inventory/refund");
            if (leg.se != address(0)) {
                assertEq(IERC20(leg.se).balanceOf(actor_),
                    inventory.sharesBefore - (sharesIn_[i] ? amounts_[i] : 0) + inventory.returnedShares, "caller share inventory/refund");
            }
        }
        assertEq(IERC20(ledgerHook).balanceOf(actor_), ledgerLp[actor_], "net depositor LP");
        _ledgerAssert();
    }

    function _ledgerCeil(uint256 amount_, uint256 book_, uint256 supply_) internal pure returns (uint256) {
        uint256 floor = Math.mulDiv(amount_, book_, supply_);
        return floor + (mulmod(amount_, book_, supply_) == 0 ? 0 : 1);
    }

    function _ledgerExit(address actor_, uint256 burned_) internal {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            ConversionReceipt memory receipt = _ledgerReceipt(logs_, i, actor_, address(0));
            uint256 pairClaim = Math.mulDiv(burned_, leg.se == address(0) ? leg.raw : leg.local, ledgerSupply);
            uint256 shareClaim = Math.mulDiv(burned_, leg.shares, ledgerSupply);
            assertEq(receipt.sharesBurned, shareClaim, "redeem only independently allocated shares");
            assertEq(receipt.sharesMinted, 0, "exit never mints SE shares");
            assertEq(receipt.pairOut, 0, "exit never deposits remaining local custody");
            assertEq(IERC20(leg.pair).balanceOf(actor_) - callerInventory[i].pairBefore,
                pairClaim + receipt.pairIn, "payout is local allocation plus actual redemption");
            if (leg.se == address(0)) leg.raw -= pairClaim;
            else {
                leg.local -= pairClaim;
                assertEq(IERC20(leg.se).balanceOf(actor_), callerInventory[i].sharesBefore, "pair-only exit");
            }
            leg.shares -= shareClaim;
        }
        ledgerSupply -= burned_;
        ledgerBurned += burned_;
        if (actor_ == ledgerFeeTo) ledgerFeeBalance -= burned_;
        else ledgerLp[actor_] -= burned_;
        assertEq(IERC20(ledgerHook).balanceOf(actor_),
            actor_ == ledgerFeeTo ? ledgerFeeBalance : ledgerLp[actor_], "independent LP burn");
        _ledgerAssert();
    }

    function _ledgerSwap(address actor_, address boundary_, address input_, address output_, uint256 spent_, uint256 paid_)
        internal
    {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            ConversionReceipt memory receipt = _ledgerReceipt(logs_, i, actor_, boundary_);
            uint256 credit = leg.pair == input_ ? spent_ : 0;
            uint256 debit = leg.pair == output_ ? paid_ : 0;
            if (leg.se == address(0)) leg.raw = leg.raw + credit - debit;
            else {
                if (debit != 0 && debit <= leg.local) assertEq(receipt.sharesBurned, 0, "local-only output cannot redeem");
                leg.local = leg.local + credit + receipt.pairIn - receipt.pairOut - debit;
                leg.shares = leg.shares + receipt.sharesMinted - receipt.sharesBurned;
            }
        }
        _ledgerAssert();
    }

    function _ledgerAssert() internal view {
        assertEq(IERC20(ledgerHook).totalSupply(), ledgerSupply, "independent gross mint/burn supply");
        assertEq(IERC20(ledgerHook).balanceOf(address(0)), ledgerSupply == 0 ? 0 : 1000, "floor allocated once");
        if (ledgerFeeTo != address(0)) assertEq(IERC20(ledgerHook).balanceOf(ledgerFeeTo), ledgerFeeBalance, "independent protocol LP");
        assertEq(ledgerGrossMinted, ledgerNetMinted + ledgerFeeMinted, "gross equals net plus fee");
        for (uint256 i; i < nativeBooks.length; ++i) {
            NativeLeg storage leg = nativeBooks[i];
            assertEq(IERC20(leg.pair).balanceOf(ledgerHook),
                (leg.se == address(0) ? leg.raw : leg.local) + leg.ambientPair, "native pair book plus ambient");
            if (leg.se != address(0)) assertEq(IERC20(leg.se).balanceOf(ledgerHook),
                leg.shares + leg.ambientShares, "native share book plus ambient");
        }
    }
}

/// @notice Shared custody assertions; conversion-only H1 never inherits LP tests.
abstract contract HookComponentCustodyBehavior is Test {
    function _hbHook() internal view virtual returns (address);
    function _hbPairs() internal view virtual returns (address[] memory);
    function _hbExchanges() internal view virtual returns (address[] memory);

    function test_HB40_memberPairsSeparateFromImplicitShares() public view {
        address[] memory pairs_ = _hbPairs();
        address[] memory exchanges_ = _hbExchanges();
        assertEq(pairs_.length, exchanges_.length);
        assertGt(_hbHook().code.length, 0);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            if (exchanges_[i_] == address(0)) continue; // A raw leg has no SE.
            address[] memory members_ = IBasicVault(exchanges_[i_]).vaultTokens();
            bool member_;
            for (uint256 j_; j_ < members_.length; ++j_) {
                assertNotEq(members_[j_], exchanges_[i_], "fixture omits implicit own share");
                if (members_[j_] == pairs_[i_]) member_ = true;
            }
            assertTrue(member_, "configured pair is a real member");
        }
    }
}

/// @notice Independent native-component ownership oracles on real family proxies.
/// @dev Adapters only fund and invoke installed product selectors. They never supply
/// expected component arithmetic. Ordinary fixtures have no ambient custody;
/// the staged-transfer case adds it explicitly and compares the untouched excess.
abstract contract HookComponentAccountingBehavior is HookComponentCustodyBehavior, HookComponentLedger {
    address internal constant HB_ALICE = address(0xA11CE40);
    address internal constant HB_BOB = address(0xB0B40);
    uint256 internal constant HB_FEE = 2e16;

    struct ComponentSnapshot {
        uint256 supply;
        uint256 userLp;
        uint256 feeLp;
        uint256[] pairs;
        uint256[] shares;
        uint256[] shareSupply;
        uint256[] userPairs;
        uint256[] userShares;
        uint256[] pairAllowance;
        uint256[] shareAllowance;
    }

    function _hbSetFee(uint256 fee_) internal virtual;
    function _hbEffectiveMintFee(uint256 configured_) internal pure virtual returns (uint256) {
        return configured_;
    }
    function _hbFeeRecipient() internal view virtual returns (address);
    function _hbFundShares(address actor_, uint256 budget_) internal virtual returns (uint256[] memory);
    function _hbFundPairs(address actor_, uint256 budget_) internal virtual returns (uint256[] memory);
    function _hbJoinShares(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal virtual returns (uint256);
    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal virtual returns (uint256);
    function _hbExitPairs(address actor_, uint256 burned_) internal virtual;
    function _hbMoveUnderlyingMarket() internal virtual;
    function _hbRate() internal view virtual returns (uint256);
    function _hbMinimumError() internal pure virtual returns (bytes4);
    function _hbInitialPairError() internal pure virtual returns (bytes4);
    function _hbInitialPairErrorData() internal view virtual returns (bytes memory) {
        return abi.encodePacked(_hbInitialPairError());
    }
    function _hbDisable(bool byPackage_, bool disabled_) internal virtual;
    function _hbTrade(address actor_, uint256 inputIndex_, uint256 outputIndex_, uint256 amount_)
        internal virtual returns (uint256);

    /// @notice Same actor joins, moves the real backing market, exits, and unwinds its
    /// separately acquired underlying position. Conversion PnL is never LP ownership.
    function test_HB16_joinMarketExitUnderlyingUnwind() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
        _hbLedgerJoin(HB_BOB, 10 ether, true, HB_FEE);
        address se_ = nativeBooks[0].se;
        address pair_ = nativeBooks[0].pair;
        _hbFundPairs(HB_BOB, 50_000 ether);
        uint256 rateBefore_ = _hbRate();
        uint256 positionBefore_ = IUniswapV4SinglePositionAware(se_).positionLiquidity();
        uint256 sharesBefore_ = IERC20(se_).balanceOf(HB_BOB);
        uint256 pairBefore_ = IERC20(pair_).balanceOf(HB_BOB);
        vm.startPrank(HB_BOB);
        IERC20(pair_).approve(se_, 50_000 ether);
        (uint256 marketShares_, uint256 refunded_) = IStandardExchangeIn(se_).exchangeIn(
            IERC20(pair_), 50_000 ether, IERC20(se_), 1, HB_BOB, false, block.timestamp
        );
        vm.stopPrank();
        uint256 marketSpent_ = pairBefore_ - IERC20(pair_).balanceOf(HB_BOB);
        assertEq(marketSpent_, 50_000 ether - refunded_, "actual external position cost");
        assertEq(IERC20(se_).balanceOf(HB_BOB) - sharesBefore_, marketShares_);
        assertGt(IUniswapV4SinglePositionAware(se_).positionLiquidity(), positionBefore_, "real backing position added");
        assertNotEq(_hbRate(), rateBefore_, "real backing market/rate changed");
        _ledgerAssert();
        // Full exit of this actor, leaving Alice, protocol LP and the locked floor.
        _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB]);
        _hbUnwindMarketPosition(se_, pair_, marketShares_, marketSpent_);
        _ledgerAssert();
        _hbLedgerJoin(HB_ALICE, 2 ether, true, HB_FEE);
        _hbLedgerExit(HB_ALICE, ledgerLp[HB_ALICE] / 4);
    }

    function _hbUnwindMarketPosition(address se_, address pair_, uint256 shares_, uint256 spent_) private {
        uint256 position_ = IUniswapV4SinglePositionAware(se_).positionLiquidity();
        uint256 supply_ = IERC20(se_).totalSupply();
        uint256 actorShares_ = IERC20(se_).balanceOf(HB_BOB);
        uint256 actorPair_ = IERC20(pair_).balanceOf(HB_BOB);
        vm.prank(HB_BOB);
        (uint256 receipt_, uint256 refund_) = IStandardExchangeIn(se_).exchangeIn(
            IERC20(se_), shares_, IERC20(pair_), 1, HB_BOB, false, block.timestamp
        );
        assertEq(refund_, 0);
        assertEq(IERC20(se_).totalSupply(), supply_ - shares_, "underlying shares actually burned");
        assertEq(IERC20(se_).balanceOf(HB_BOB), actorShares_ - shares_, "unwind only separate market position");
        assertEq(IERC20(pair_).balanceOf(HB_BOB) - actorPair_, receipt_, "actual unwind receipt");
        assertEq(IUniswapV4SinglePositionAware(se_).positionLiquidity(),
            position_ - Math.mulDiv(shares_, position_, supply_), "real underlying liquidity removed");
        // Both values are in this one pair token's native units. Do not aggregate other legs
        // or call this PnL evidence of broad swap-manipulation resistance.
        emit log_named_uint("external position pair spent", spent_);
        emit log_named_uint("external position pair recovered", receipt_);
        emit log_named_int("external conversion and trading PnL", int256(receipt_) - int256(spent_));
    }

    function test_HB16_feeChangesAndProtocolExitUseIndependentBooks() public {
        _hbSetFee(0);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, 0);
        uint256[3] memory fees_ = [uint256(1), HB_FEE, uint256(0)];
        for (uint256 i_; i_ < fees_.length; ++i_) {
            _hbSetFee(fees_[i_]);
            _hbLedgerJoin(HB_BOB, 2 ether, i_ != 1, fees_[i_]);
            _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB] / 3);
        }
        assertGt(ledgerFeeBalance, 0, "protocol acquired funded LP");
        _hbLedgerExit(ledgerFeeTo, ledgerFeeBalance);
        _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB]);
        _hbLedgerExit(HB_ALICE, ledgerLp[HB_ALICE]);
        assertEq(ledgerSupply, 1000, "only locked-floor ownership remains");
    }

    function test_HB16_addressDisableReenableAmbientAndRefundInventory() public { _hbLedgerDisabled(false); }
    function test_HB16_packageDisableReenableAmbientAndRefundInventory() public { _hbLedgerDisabled(true); }

    /// @notice An intentionally unequal proportional budget guarantees a limiting leg and refunds.
    function test_HB16_unbalancedBudgetsReturnCallerInventory() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        amounts_[amounts_.length - 1] /= 2;
        _hbLedgerAccept(HB_BOB, amounts_, true, HB_FEE);
        bool returned_;
        for (uint256 i_; i_ < callerInventory.length; ++i_) {
            if (callerInventory[i_].returnedPair != 0 || callerInventory[i_].returnedShares != 0) returned_ = true;
        }
        assertTrue(returned_, "nonlimiting caller components are actually returned");
        _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB]);
    }

    function _hbLedgerDisabled(bool byPackage_) private {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
        uint256[] memory staged_ = _hbFundShares(HB_ALICE, 3 ether);
        _hbFundPairs(HB_ALICE, 3 ether);
        for (uint256 i_; i_ < nativeBooks.length; ++i_) {
            NativeLeg storage leg_ = nativeBooks[i_];
            vm.prank(HB_ALICE);
            IERC20(leg_.pair).transfer(ledgerHook, 3 ether);
            leg_.ambientPair += 3 ether;
            if (leg_.se != address(0)) {
                vm.prank(HB_ALICE);
                IERC20(leg_.se).transfer(ledgerHook, staged_[i_]);
                leg_.ambientShares += staged_[i_];
            }
        }
        _ledgerAssert();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        _hbDisable(byPackage_, true);
        _hbLedgerAccept(HB_BOB, amounts_, true, HB_FEE);
        _hbFundPairs(HB_BOB, 1 ether);
        uint256 localBefore_ = nativeBooks[0].local;
        uint256 sharesBefore_ = nativeBooks[0].shares;
        _ledgerBegin(HB_BOB);
        uint256 paid_ = _hbTrade(HB_BOB, 0, 1, 1e12);
        _ledgerSwap(HB_BOB, address(0), nativeBooks[0].pair, nativeBooks[1].pair, 1e12, paid_);
        assertEq(nativeBooks[0].local, localBefore_ + 1e12, "disabled input credited once");
        assertEq(nativeBooks[0].shares, sharesBefore_, "disabled mint never attempted");
        _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB] / 4);
        _hbDisable(byPackage_, false);
        _ledgerAssert();
        _hbLedgerJoin(HB_BOB, 2 ether, true, HB_FEE);
        _hbLedgerExit(HB_BOB, ledgerLp[HB_BOB]);
    }

    function test_HB16_failedFundingPreservesIndependentBooks() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        uint256 checkpoint_ = vm.snapshotState();
        _hbLedgerAccept(HB_BOB, amounts_, true, HB_FEE);
        assertTrue(vm.revertToState(checkpoint_), "same-size funded control succeeds");
        NativeLeg storage last_ = nativeBooks[nativeBooks.length - 1];
        IERC20 token_ = IERC20(last_.se == address(0) ? last_.pair : last_.se);
        uint256 unfunded_ = token_.balanceOf(HB_BOB);
        vm.prank(HB_BOB);
        token_.transfer(address(0xDEAD16), unfunded_);
        bytes32 before_ = _hbCompleteState(HB_BOB);
        (bool ok_, bytes memory reason_) = address(this).call(
            abi.encodeCall(this.hbJoinShares, (HB_BOB, amounts_, 1))
        );
        assertFalse(ok_, "unfunded final input must fail");
        assertGt(reason_.length, 0, "funding failure returns a reason");
        assertEq(_hbCompleteState(HB_BOB), before_, "failed funding restores real vaults, manager and caller");
        _ledgerAssert();
        _hbLedgerJoin(HB_BOB, 2 ether, true, HB_FEE);
    }

    function test_HB16_failedBootstrapRedemptionRestoresAllLegs() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        uint256 failingLeg_;
        for (uint256 i_; i_ < nativeBooks.length; ++i_) if (nativeBooks[i_].se != address(0)) failingLeg_ = i_;
        amounts_[failingLeg_] = 19; // floor(19 * 5 / 100) == 0; never a completed redemption.
        bytes32 before_ = _hbCompleteState(HB_ALICE);
        (bool ok_, bytes memory reason_) = address(this).call(
            abi.encodeCall(this.hbJoinShares, (HB_ALICE, amounts_, 1))
        );
        assertFalse(ok_, "a funded SE leg with zero redemption cannot seed");
        assertGt(reason_.length, 0);
        assertEq(_hbCompleteState(HB_ALICE), before_, "earlier legs and all LP allocations restore");
        _ledgerAssert();
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
    }

    function test_HB16_failedOuterSettlementRestoresIndependentBooks() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbLedgerJoin(HB_ALICE, 100 ether, true, HB_FEE);
        IPoolManager manager_ = IUniswapV4ProtocolAware(nativeBooks[0].se).poolManager();
        HookComponentOuterSettlementCaller caller_ = new HookComponentOuterSettlementCaller(
            manager_, ledgerHook, nativeBooks[1].pair, nativeBooks[0].pair
        );
        _hbFundPairs(address(caller_), 1 ether);
        bytes32 before_ = _hbCompleteState(address(caller_));
        vm.expectRevert(IPoolManager.CurrencyNotSettled.selector);
        caller_.run(1e12, true);
        assertEq(_hbCompleteState(address(caller_)), before_, "outer debt rolls back completed hook swap");
        _ledgerAssert();
        _ledgerBegin(address(caller_));
        uint256 paid_ = caller_.run(1e12, false);
        _ledgerSwap(address(caller_), address(manager_), nativeBooks[1].pair, nativeBooks[0].pair, 1e12, paid_);
        assertGt(paid_, 0, "same funded operation succeeds with settled outer context");
    }

    function _hbAssertMissingComponentRoutes(address actor_, bytes[] memory calls_) internal {
        address target_ = _hbHook();
        for (uint256 i_; i_ < calls_.length; ++i_) {
            bytes32 before_ = _hbCompleteState(actor_);
            vm.prank(actor_);
            (bool ok_, bytes memory reason_) = target_.call(calls_[i_]);
            assertFalse(ok_, "missing caller components cannot be bought from the incumbent book");
            assertGt(reason_.length, 0, "unsupported basket returns a reason");
            assertEq(_hbCompleteState(actor_), before_, "failed alias preserves caller and incumbent state");
        }
    }

    function _hbCompleteState(address actor_) internal view returns (bytes32 state_) {
        state_ = keccak256(abi.encode(_hbSnapshot(actor_)));
        for (uint256 i_; i_ < nativeBooks.length; ++i_) {
            address se_ = nativeBooks[i_].se;
            if (se_ == address(0)) continue;
            address manager_ = address(IUniswapV4ProtocolAware(se_).poolManager());
            state_ = keccak256(abi.encode(state_, IUniswapV4SinglePositionAware(se_).positionLiquidity()));
            address[] memory members_ = IBasicVault(se_).vaultTokens();
            for (uint256 j_; j_ < members_.length; ++j_) {
                state_ = keccak256(abi.encode(state_, IERC20(members_[j_]).balanceOf(se_),
                    IERC20(members_[j_]).balanceOf(manager_), IERC20(members_[j_]).balanceOf(actor_)));
            }
        }
    }

    function _hbLedgerJoin(address actor_, uint256 budget_, bool asShares_, uint256 fee_) private {
        uint256[] memory amounts_ = asShares_ ? _hbFundShares(actor_, budget_) : _hbFundPairs(actor_, budget_);
        _hbLedgerAccept(actor_, amounts_, asShares_, fee_);
    }

    function _hbLedgerAccept(address actor_, uint256[] memory amounts_, bool asShares_, uint256 fee_) private {
        bool[] memory flags_ = new bool[](nativeBooks.length);
        for (uint256 i_; i_ < flags_.length; ++i_) flags_[i_] = asShares_ && nativeBooks[i_].se != address(0);
        _ledgerBegin(actor_);
        uint256 net_ = asShares_ ? _hbJoinShares(actor_, amounts_, 1) : _hbJoinPairs(actor_, amounts_, 1);
        _ledgerJoin(actor_, amounts_, flags_, net_, _hbEffectiveMintFee(fee_));
    }

    function _hbLedgerExit(address actor_, uint256 burned_) private {
        _ledgerBegin(actor_);
        _hbExitPairs(actor_, burned_);
        _ledgerExit(actor_, burned_);
    }

    function _hbSnapshot(address actor_) internal view returns (ComponentSnapshot memory s_) {
        address hook_ = _hbHook();
        address[] memory pairs_ = _hbPairs();
        address[] memory exchanges_ = _hbExchanges();
        s_.supply = IERC20(hook_).totalSupply();
        s_.userLp = IERC20(hook_).balanceOf(actor_);
        s_.feeLp = IERC20(hook_).balanceOf(_hbFeeRecipient());
        s_.pairs = new uint256[](pairs_.length);
        s_.shares = new uint256[](pairs_.length);
        s_.shareSupply = new uint256[](pairs_.length);
        s_.userPairs = new uint256[](pairs_.length);
        s_.userShares = new uint256[](pairs_.length);
        s_.pairAllowance = new uint256[](pairs_.length);
        s_.shareAllowance = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            s_.pairs[i_] = IERC20(pairs_[i_]).balanceOf(hook_);
            s_.userPairs[i_] = IERC20(pairs_[i_]).balanceOf(actor_);
            s_.pairAllowance[i_] = IERC20(pairs_[i_]).allowance(actor_, hook_);
            if (exchanges_[i_] != address(0)) {
                s_.shares[i_] = IERC20(exchanges_[i_]).balanceOf(hook_);
                s_.shareSupply[i_] = IERC20(exchanges_[i_]).totalSupply();
                s_.userShares[i_] = IERC20(exchanges_[i_]).balanceOf(actor_);
                s_.shareAllowance[i_] = IERC20(exchanges_[i_]).allowance(actor_, hook_);
            }
        }
    }

    function _hbBootstrap() internal returns (uint256 net_) {
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        net_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        assertGt(net_, 0, "real share-funded seed");
    }

    function _hbAssertFee(ComponentSnapshot memory before_, ComponentSnapshot memory after_, uint256 net_) internal pure {
        uint256 gross_ = after_.supply - before_.supply;
        if (before_.supply == 0) gross_ -= 1000;
        uint256 fee_ = gross_ * HB_FEE / 1e18;
        assertEq(after_.feeLp - before_.feeLp, fee_, "fee comes out of backed gross");
        assertEq(after_.userLp - before_.userLp, net_);
        assertEq(net_ + fee_, gross_, "no fee mint on top");
    }

    function test_HB47_mintFeeSplitsBackedGross() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 net_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        _hbAssertFee(before_, _hbSnapshot(HB_ALICE), net_);
        assertEq(IERC20(_hbHook()).balanceOf(address(0)), 1000, "floor allocated once");
    }

    function test_HB47_rateOnlyMovementMintsNoLp() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 rateBefore_ = _hbRate();
        _hbMoveUnderlyingMarket();
        assertNotEq(_hbRate(), rateBefore_, "exercise real market movement");
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertEq(after_.supply, before_.supply);
        assertEq(after_.feeLp, before_.feeLp);
        assertEq(after_.pairs, before_.pairs);
        assertEq(after_.shares, before_.shares);
    }

    function test_HB48_genesisRedeemsFivePercentOfShares() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 net_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        address[] memory exchanges_ = _hbExchanges();
        for (uint256 i_; i_ < amounts_.length; ++i_) {
            if (exchanges_[i_] == address(0)) {
                assertEq(after_.pairs[i_] - before_.pairs[i_], amounts_[i_]);
            } else {
                uint256 redeemed_ = amounts_[i_] / 20;
                assertGt(redeemed_, 0);
                assertEq(before_.shareSupply[i_] - after_.shareSupply[i_], redeemed_);
                assertEq(after_.shares[i_] - before_.shares[i_], amounts_[i_] - redeemed_);
                assertEq(before_.userShares[i_] - after_.userShares[i_], amounts_[i_]);
                assertGt(after_.pairs[i_] - before_.pairs[i_], 0, "actual paired receipt");
            }
        }
        _hbAssertFee(before_, after_, net_);
    }

    function test_HB48_genesisFailureRollsBackEveryLeg() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.expectRevert(_hbMinimumError());
        this.hbJoinShares(HB_ALICE, amounts_, type(uint256).max);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_), "all funded legs and allowances restore");
    }

    function test_HB48_initialPairInputAcquiresSharesAndSeedsEveryLeg() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(_hbHook(), _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        uint256[] memory amounts_ = _hbFundPairs(HB_ALICE, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.recordLogs();
        uint256 net_ = _hbJoinPairs(HB_ALICE, amounts_, 1);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertGt(net_, 0, "one supplied asset per leg funds initial liquidity");
        for (uint256 i_; i_ < amounts_.length; ++i_) {
            uint256 spent_ = before_.userPairs[i_] - after_.userPairs[i_];
            assertLe(spent_, amounts_[i_], "only the caller's declared input is used");
            if (_hbExchanges()[i_] == address(0)) {
                assertEq(after_.pairs[i_] - before_.pairs[i_], spent_);
            } else {
                ConversionReceipt memory receipt_ = _ledgerReceipt(logs_, i_, HB_ALICE, address(0));
                assertGt(receipt_.sharesMinted, 0, "caller pair input acquired actual SE shares");
                assertEq(receipt_.sharesBurned, receipt_.sharesMinted / 20, "five percent of acquired shares redeemed");
                assertGt(receipt_.sharesBurned, 0);
                assertEq(after_.shares[i_] - before_.shares[i_], receipt_.sharesMinted - receipt_.sharesBurned);
                assertEq(after_.pairs[i_] - before_.pairs[i_], spent_ + receipt_.pairIn - receipt_.pairOut);
                assertGt(receipt_.pairIn, 0, "actual local seed received");
            }
        }
        _hbAssertFee(before_, after_, net_);
    }

    function test_HB48_laterJoinUsesCurrentComponents() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net_ = _hbJoinShares(HB_BOB, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net_);
        _hbAssertContributions(before_, after_);
    }

    function test_HB43_pairInputConversionBacksEveryAcceptedComponent() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundPairs(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net_ = _hbJoinPairs(HB_BOB, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net_);
        _hbAssertContributions(before_, after_);
        for (uint256 i_; i_ < amounts_.length; ++i_) {
            assertLe(before_.userPairs[i_] - after_.userPairs[i_], amounts_[i_], "caller conversion budget");
        }
    }

    function test_HB48_seedLpIndependentOfRedemptionPrice() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        uint256 rateBefore_ = _hbRate();
        uint256 checkpoint_ = vm.snapshotState();
        uint256 controlNet_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        ComponentSnapshot memory control_ = _hbSnapshot(HB_ALICE);
        assertTrue(vm.revertToState(checkpoint_));
        _hbMoveUnderlyingMarket();
        assertNotEq(_hbRate(), rateBefore_);
        uint256 net_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertEq(net_, controlNet_, "same retained-share/raw seed coordinates");
        assertEq(after_.supply, control_.supply);
        assertEq(after_.shares, control_.shares);
        assertNotEq(after_.pairs[0], control_.pairs[0], "actual redemption proceeds vary");
    }

    function test_HB48_ambientCustodyDoesNotBecomeGenesisBacking() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts_ = _hbFundShares(HB_ALICE, 100 ether);
        uint256[] memory staged_ = _hbFundShares(HB_BOB, 3 ether);
        uint256 checkpoint_ = vm.snapshotState();
        uint256 controlNet_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        ComponentSnapshot memory control_ = _hbSnapshot(HB_ALICE);
        assertTrue(vm.revertToState(checkpoint_));
        address[] memory pairs_ = _hbPairs();
        address[] memory exchanges_ = _hbExchanges();
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            address token_ = exchanges_[i_] == address(0) ? pairs_[i_] : exchanges_[i_];
            vm.prank(HB_BOB);
            IERC20(token_).transfer(_hbHook(), staged_[i_]);
        }
        uint256 net_ = _hbJoinShares(HB_ALICE, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertEq(net_, controlNet_);
        assertEq(after_.supply, control_.supply);
        assertEq(after_.userShares, control_.userShares);
        assertEq(after_.userPairs, control_.userPairs);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            assertEq(after_.pairs[i_], control_.pairs[i_] + (exchanges_[i_] == address(0) ? staged_[i_] : 0));
            assertEq(after_.shares[i_], control_.shares[i_] + (exchanges_[i_] == address(0) ? 0 : staged_[i_]));
        }
    }

    function _hbAssertContributions(ComponentSnapshot memory before_, ComponentSnapshot memory after_) internal pure {
        uint256 gross_ = after_.supply - before_.supply;
        assertGt(gross_, 0);
        for (uint256 i_; i_ < before_.pairs.length; ++i_) {
            uint256 pairProduct_ = gross_ * before_.pairs[i_];
            uint256 shareProduct_ = gross_ * before_.shares[i_];
            uint256 pairRequired_ = pairProduct_ / before_.supply + (pairProduct_ % before_.supply == 0 ? 0 : 1);
            uint256 sharesRequired_ = shareProduct_ / before_.supply + (shareProduct_ % before_.supply == 0 ? 0 : 1);
            assertEq(after_.pairs[i_] - before_.pairs[i_], pairRequired_, "ceil native pair contribution");
            assertEq(after_.shares[i_] - before_.shares[i_], sharesRequired_, "ceil native share contribution");
            assertGe(after_.pairs[i_] * before_.supply, before_.pairs[i_] * after_.supply);
            assertGe(after_.shares[i_] * before_.supply, before_.shares[i_] * after_.supply);
        }
    }

    function test_HB44_twoHoldersExitOnlyTheirComponentFractions() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        _hbJoinShares(HB_BOB, amounts_, 1);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 burn_ = before_.userLp / 3;
        _hbExitPairs(HB_ALICE, burn_);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertEq(after_.supply, before_.supply - burn_);
        assertEq(after_.feeLp, before_.feeLp, "no withdrawal fee mint");
        assertEq(after_.userLp, before_.userLp - burn_);
        for (uint256 i_; i_ < before_.pairs.length; ++i_) {
            assertEq(after_.pairs[i_], before_.pairs[i_] - burn_ * before_.pairs[i_] / before_.supply);
            assertEq(after_.shares[i_], before_.shares[i_] - burn_ * before_.shares[i_] / before_.supply);
            assertGt(after_.userPairs[i_], before_.userPairs[i_], "actual pair-only payout");
        }
    }

    function test_HB41_ambientPairTransfersDoNotFundLaterJoin() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        _hbFundPairs(HB_ALICE, 3 ether);
        uint256 checkpoint_ = vm.snapshotState();
        uint256 controlNet_ = _hbJoinShares(HB_BOB, amounts_, 1);
        ComponentSnapshot memory control_ = _hbSnapshot(HB_BOB);
        assertTrue(vm.revertToState(checkpoint_));
        address[] memory pairs_ = _hbPairs();
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            vm.prank(HB_ALICE);
            IERC20(pairs_[i_]).transfer(_hbHook(), 3 ether);
        }
        uint256 net_ = _hbJoinShares(HB_BOB, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(net_, controlNet_, "ambient custody buys no LP");
        assertEq(after_.supply, control_.supply);
        assertEq(after_.feeLp, control_.feeLp);
        assertEq(after_.shares, control_.shares);
        assertEq(after_.userShares, control_.userShares);
        assertEq(after_.userPairs, control_.userPairs, "ambient custody is not a caller refund");
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            assertEq(after_.pairs[i_], control_.pairs[i_] + 3 ether);
        }
    }

    function test_HB42_localOnlyOutputDoesNotRedeemSe() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        assertGt(before_.pairs[0], 1000);
        uint256 output_ = _hbTrade(HB_BOB, 1, 0, before_.pairs[0] / 1000);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(output_, 0);
        assertLe(output_, before_.pairs[0], "local-only fixture threshold");
        assertEq(after_.pairs[0], before_.pairs[0] - output_);
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0], "no SE redemption");
        assertEq(after_.userPairs[0] - before_.userPairs[0], output_);
    }

    function test_HB42_outputDeficitRedeemsOnlyAfterLocalBook() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        assertGt(before_.pairs[0], 0);
        uint256 output_ = _hbTrade(HB_BOB, 1, 0, before_.pairs[0] * 4);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(output_, before_.pairs[0], "exercise a real deficit");
        assertEq(after_.pairs[0], 0, "local output consumed first");
        assertLt(after_.shares[0], before_.shares[0]);
        assertEq(before_.shareSupply[0] - after_.shareSupply[0], before_.shares[0] - after_.shares[0]);
        assertEq(after_.userPairs[0] - before_.userPairs[0], output_);
    }

    function test_HB45_preownedSharesJoinWithoutDisabledMint() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts_ = _hbFundShares(HB_BOB, 10 ether);
        _hbDisable(false, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net_ = _hbJoinShares(HB_BOB, amounts_, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net_);
        _hbAssertContributions(before_, after_);
        assertLe(after_.shareSupply[0], before_.shareSupply[0], "no disabled SE mint");
    }

    function test_HB45_disabledAddressBooksInputAndPermitsExit() public { _hbDisabledFlow(false); }
    function test_HB45_disabledPackageBooksInputAndPermitsExit() public { _hbDisabledFlow(true); }

    function _hbDisabledFlow(bool byPackage_) internal {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        _hbDisable(byPackage_, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 output_ = _hbTrade(HB_BOB, 0, 1, 1 ether);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(output_, 0);
        assertEq(after_.pairs[0], before_.pairs[0] + 1 ether, "disabled input stays local");
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0], "no prohibited mint");
        assertEq(before_.userPairs[0] - after_.userPairs[0], 1 ether);
        before_ = _hbSnapshot(HB_ALICE);
        uint256 burned_ = before_.userLp / 4;
        _hbExitPairs(HB_ALICE, burned_);
        after_ = _hbSnapshot(HB_ALICE);
        assertEq(after_.supply, before_.supply - burned_);
        assertEq(after_.pairs[0], before_.pairs[0] - burned_ * before_.pairs[0] / before_.supply);
        assertEq(after_.shares[0], before_.shares[0] - burned_ * before_.shares[0] / before_.supply);
        assertGt(after_.userPairs[0], before_.userPairs[0], "permitted pair payout");
        _hbDisable(byPackage_, false);
        ComponentSnapshot memory restored_ = _hbSnapshot(HB_ALICE);
        assertEq(restored_.pairs, after_.pairs);
        assertEq(restored_.shares, after_.shares);
        assertEq(restored_.supply, after_.supply);
    }

    /// @dev External test boundary lets revert assertions cover the complete real hook call.
    function hbJoinShares(address actor_, uint256[] memory amounts_, uint256 minimum_) external returns (uint256) {
        return _hbJoinShares(actor_, amounts_, minimum_);
    }

    function hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_) external returns (uint256) {
        return _hbJoinPairs(actor_, amounts_, minimum_);
    }
}

/// @notice Non-SUT integrating caller leaves actual manager debt after a successful hook operation.
contract HookComponentOuterSettlementCaller is IUnlockCallback {
    IPoolManager private immutable manager;
    address private immutable hook;
    address private immutable input;
    address private immutable output;

    constructor(IPoolManager manager_, address hook_, address input_, address output_) {
        manager = manager_;
        hook = hook_;
        input = input_;
        output = output_;
    }

    function run(uint256 amount_, bool fail_) external returns (uint256) {
        return abi.decode(manager.unlock(abi.encode(amount_, fail_)), (uint256));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager only");
        (uint256 amount_, bool fail_) = abi.decode(data_, (uint256, bool));
        (uint256 paid_,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(input), amount_, IERC20(output), 1, address(this), false, block.timestamp
        );
        require(paid_ != 0, "hook operation must finish before outer failure");
        if (fail_) manager.take(Currency.wrap(output), address(this), 1);
        return abi.encode(paid_);
    }
}

/// @notice Only families with a supported exact-net execution inherit this extension.
/// @dev A deliberately unavailable route gets a concrete rejection test instead,
/// never an early-returning passing exact-net test.
abstract contract HookExactNetComponentAccountingBehavior is HookComponentAccountingBehavior {
    function _hbExactNetRequest() internal view virtual returns (uint256 net_, uint256 maximum_);
    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal virtual returns (uint256);

    function test_HB47_exactNetPaysForMissingLegsAndSplitsBackedGross() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        (uint256 net_, uint256 maximum_) = _hbExactNetRequest();
        uint256 spent_ = _hbExactNet(HB_BOB, net_, maximum_);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(spent_, 0, "preparation is paid by the caller");
        assertLe(spent_, maximum_, "exact-net input stays within caller budget");
        assertEq(after_.userLp - before_.userLp, net_);
        _hbAssertFee(before_, after_, net_);
    }

    function hbExactNet(address actor_, uint256 net_, uint256 maximum_) external returns (uint256) {
        return _hbExactNet(actor_, net_, maximum_);
    }
}
