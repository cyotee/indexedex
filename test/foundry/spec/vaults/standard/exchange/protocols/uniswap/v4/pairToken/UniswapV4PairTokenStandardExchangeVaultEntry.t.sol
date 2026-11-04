// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as EntryMath} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {PoolActor} from "./harness/PoolActor.sol";

// tag::EntryArithmeticDomainControl[]
/// @notice Component-only domain probes, never an oracle for product expectations.
contract EntryArithmeticDomainControl {
    /// @notice Test an irrelevant overflowing credit quotient with an explicit cap.
    function capped() external view returns (uint256) {
        return EntryMath.credit(type(uint256).max, 1, 1, type(uint256).max, type(uint256).max, 17);
    }
}
// end::EntryArithmeticDomainControl[]

// tag::EntryFeeOnTransferToken[]
/// @notice Real ERC20 boundary actor that burns one unit on taxed transfers.
/// @dev Tax is off during healthy bootstrap and enabled for negative entry tests.
contract EntryFeeOnTransferToken is IERC20Metadata {
    string public constant override name = "Entry negative token";
    string public constant override symbol = "ENTNEG";
    uint8 public constant override decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    bool public taxed;

    /// @notice Fund only non-SUT token balances.
    function mint(address to, uint256 amount) external returns (bool) {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        return true;
    }

    /// @notice Switch actual transfer behavior, not vault or manager bytecode.
    function setTax(bool enabled) external { taxed = enabled; }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        if (approved != type(uint256).max) allowance[from][msg.sender] = approved - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        uint256 fee = taxed && amount != 0 ? 1 : 0;
        balanceOf[from] -= amount;
        balanceOf[to] += amount - fee;
        emit Transfer(from, to, amount - fee);
        if (fee != 0) {
            --totalSupply;
            emit Transfer(from, address(0), fee);
        }
    }
}
// end::EntryFeeOnTransferToken[]

// tag::UniswapV4PairTokenStandardExchangeVaultEntryTest[]
/// @notice S1-A08-A15, A44 and A64 through registered diamonds and the real manager.
/// @dev No Forge run is claimed by this source. All product expectations below
/// use canonical manager math/receipts and independent integer controls, not the
/// family planner, family math, previews, or emitted credit as their oracle.
contract UniswapV4PairTokenStandardExchangeVaultEntryTest is
    TestBase_UniswapV4PairTokenStandardExchangeVault
{
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address private constant RECIPIENT = address(0xBEEF);
    address private constant DEAD = address(0xdead);

    struct Checkpoint {
        uint256 supply;
        uint128 liquidity;
        uint160 price;
        int24 tick;
        uint256 book0;
        uint256 book1;
        uint256 principal0;
        uint256 principal1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 manager0;
        uint256 manager1;
    }

    struct Credit {
        Checkpoint incumbent;
        uint128 added;
        uint256 quote;
        uint256 used0;
        uint256 used1;
        uint256 cost0;
        uint256 cost1;
        uint256 growth0;
        uint256 growth1;
        uint256 residual0;
        uint256 residual1;
        uint256 shares;
        int128 swap0;
        int128 swap1;
    }

    /// @notice S1-A08: complete geometric mean goes to recipient, including tiny genesis.
    function test_ENT_GenesisCompleteGeometricMeanNoDeadShares() public {
        _assertGenesis(10_000, 40_000, 20_000);
    }

    /// @notice S1-A08/A09: no hidden thousand-share minimum or virtual share subtraction.
    function test_ENT_GenesisSingleShareIsNotAHiddenMinimum() public {
        _assertGenesis(1, 1, 1);
    }

    /// @notice S1-A09: zero input and therefore zero geometric mean fail atomically.
    function test_ENT_GenesisZeroInputsAndZeroMintRollback() public {
        _fund(address(this), 100, 100);
        _approveVault(address(vault));
        _pairFailure(0, 100, 0, abi.encodeWithSelector(EntryMath.ZeroShares.selector));
        _pairFailure(100, 0, 0, abi.encodeWithSelector(EntryMath.ZeroShares.selector));
        _pairFailure(0, 0, 0, abi.encodeWithSelector(EntryMath.ZeroShares.selector));
    }

    /// @notice S1-A09: the checked genesis product panics before any token pull.
    function test_ENT_GenesisCheckedProductOverflowRollback() public {
        _approveVault(address(vault));
        _pairFailure(uint256(1) << 128, uint256(1) << 128, 0, abi.encodeWithSignature("Panic(uint256)", 0x11));
    }

    /// @notice S1-A09: positive geometric mean is insufficient without fundable liquidity.
    function test_ENT_GenesisPositiveMintButZeroFundableLiquidityRollback() public {
        // An empty real pool can move without settlement; no vault state is injected.
        poolActor.swap(key, SwapParams(false, -1, TickMath.getSqrtPriceAtTick(600_000)));
        _fund(address(this), 1, 1);
        _approveVault(address(vault));
        _pairFailure(1, 1, 0, abi.encodeWithSelector(EntryMath.ZeroShares.selector));
    }

    /// @notice S1-A09: minimum is checked against actual recipient genesis shares.
    function test_ENT_GenesisActualShareMinimumRollback() public {
        _fund(address(this), 10_000, 40_000);
        _approveVault(address(vault));
        token0.approve(address(vault), 10_000);
        token1.approve(address(vault), 40_000);
        _pairFailure(10_000, 40_000, 20_001,
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, 20_001, 20_000));
        assertEq(vault.depositPair(10_000, 40_000, 20_000, RECIPIENT, block.timestamp), 20_000);
    }

    /// @notice S1-A10/A15/A64: token0 limits; ceil acceptance, G+J and actual q are exact.
    function test_ENT_PairedToken0LimitingCeilAcceptedAndFinalCreditCap() public {
        _bootstrap(1_000_003, 2_000_011, address(this));
        _assertPair(777, 50_000);
    }

    /// @notice S1-A10/A15/A64: token1 limits and excess ERC20 maxima stay with the caller.
    function test_ENT_PairedToken1LimitingCeilAcceptedAndFinalCreditCap() public {
        _bootstrap(2_000_011, 1_000_003, address(this));
        _assertPair(50_000, 777);
    }

    /// @notice S1-A10: an overflowing non-limiting quote quotient cannot reject a valid minimum.
    function test_ENT_PairedNonLimitingMaxUintQuotientDoesNotReject() public {
        _bootstrap(1e12, 1e12, address(this));
        // Supply exceeds removable reserves by rounding. max0*S/R0 exceeds uint256.
        Checkpoint memory before_ = _checkpoint();
        assertGt(before_.supply, before_.reserve0);
        _fund(address(this), 1e9, 1e9);
        _approveVault(address(vault));
        Credit memory expected = _pairControl(type(uint256).max, 1e6);
        _executePair(type(uint256).max, 1e6, expected);
    }

    /// @notice S1-A10: native maximum is reserved, only accepted input remains spent.
    function test_ENT_PairedNativeUnusedMaximumRefundIsExact() public {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "Entry native refund"));
        _bootstrap(1e12, 1e12, address(this));
        _assertPair(1e9, 1e6);
    }

    /// @notice S1-A11/A64: token0-only idle branch accepts the full live-leg maximum, without an add.
    function test_ENT_OneSidedToken0ConsumesFullLiveLegMaximum() public {
        _oneSided(true);
    }

    /// @notice S1-A11/A64: token1-only idle branch accepts the full live-leg maximum, without an add.
    function test_ENT_OneSidedToken1ConsumesFullLiveLegMaximum() public {
        _oneSided(false);
    }

    /// @notice S1-A11: tiny real genesis reaches positive supply with zero removable reserves.
    /// @dev L=1 costs ceil(1,1), but removable principal floors to (0,0).
    /// This is a genuine public-route rounding state, not fabricated vault storage.
    function test_ENT_PositiveSupplyBothZeroAfterTinyGenesisRejects() public {
        _bootstrap(1, 1, address(this));
        Checkpoint memory c = _checkpoint();
        assertEq(c.supply, 1);
        assertEq(c.liquidity, 1);
        assertEq(c.reserve0, 0);
        assertEq(c.reserve1, 0);
        _fund(address(this), 100, 100);
        _approveVault(address(vault));
        vm.expectRevert(IVault.InvalidAccountingState.selector);
        vault.previewDepositPair(100, 100);
        _pairFailure(100, 100, 0, abi.encodeWithSelector(IVault.InvalidAccountingState.selector));
        _zapFailure(true, 1, IVault.InvalidAccountingState.selector);
        _zapFailure(false, 1, IVault.InvalidAccountingState.selector);
    }

    /// @notice S1-A64: irrelevant enormous credit quotients do not bypass a finite final cap.
    function test_ENT_ComponentOnlyNonLimitingCreditOverflowUsesFinalCap() public {
        EntryArithmeticDomainControl control = new EntryArithmeticDomainControl();
        assertEq(control.capped(), 17);
    }

    /// @notice S1-A12: identical maintenance with input absent/present; incumbent fees stay theirs.
    function test_ENT_MaintenanceFeesAndPendingPairInputAreIsolated() public {
        _maintenanceInputIsolation();
    }

    /// @notice S1-A10/A12: incoming native maximum/refund never funds incumbent maintenance.
    function test_ENT_MaintenanceFeesAndPendingNativeMaximumAreIsolated() public {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "Entry native isolation"));
        _maintenanceInputIsolation();
    }

    function _maintenanceInputIsolation() private {
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e15, 7e14);
        poolActor.donate(key, 1e15, 7e14);
        _fund(address(this), 2e16, 2e16);
        _approveVault(address(vault));
        uint256 snapshot = vm.snapshotState();
        vm.recordLogs();
        vault.compound();
        bytes32 maintenance = _maintenanceDigest(vm.getRecordedLogs());
        Credit memory expected = _pairControl(1e16, 2e16);
        assertTrue(vm.revertToState(snapshot));
        vm.recordLogs();
        uint256 q = vault.depositPair{value: address(token0) == address(0) ? 1e16 : 0}(
            1e16, 2e16, expected.shares, RECIPIENT, block.timestamp
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_maintenanceDigest(logs), maintenance, "caller input changed incumbent maintenance");
        assertEq(q, expected.shares);
        _assertFinal(expected);
        _assertPairEvent(logs, expected);
        _assertNonDilution(expected, true);
    }

    /// @notice S1-A12/A13/A15/A64: token0 zap after imbalanced incumbent maintenance.
    function test_ENT_ZapToken0HalfSwapPostSwapFeesAndCallerOnlyCredit() public {
        _zapWithImbalancedBook(true);
    }

    /// @notice S1-A12/A13/A15/A64: token1 zap after imbalanced incumbent maintenance.
    function test_ENT_ZapToken1HalfSwapPostSwapFeesAndCallerOnlyCredit() public {
        _zapWithImbalancedBook(false);
    }

    /// @notice S1-A14: paired bootstrap is mandatory for either scalar entry direction.
    function test_ENT_ZapsEmptySupplyRejectBothDirections() public {
        _zapFailure(true, 100, IStandardExchangeIn.ExchangeInNotAvailable.selector);
        _zapFailure(false, 100, IStandardExchangeIn.ExchangeInNotAvailable.selector);
    }

    /// @notice S1-A14: zero input rejects without touching pool, allowance, or shares.
    function test_ENT_ZapZeroInputRollbackBothDirections() public {
        _bootstrap(1e12, 1e12, address(this));
        _zapFailure(true, 0, IVault.InvalidAccountingState.selector);
        _zapFailure(false, 0, IVault.InvalidAccountingState.selector);
    }

    /// @notice S1-A14: input exactly equal to the reserve cap succeeds; one over rejects.
    function test_ENT_ZapSizeCapEqualityAndOneOverBothDirections() public {
        IPackage.PkgArgs memory args = _defaultArgs(key, address(token0), "Entry wide tick cap");
        args.maxZapTickMove = 10_000;
        vault = _deployVault(args);
        _bootstrap(1e18, 1e18, address(this));
        uint256 initial = vm.snapshotState();
        for (uint256 direction; direction < 2; ++direction) {
            bool is0 = direction == 0;
            Checkpoint memory incumbent = _checkpoint();
            uint256 maximum = (is0 ? incumbent.reserve0 : incumbent.reserve1) * vault.maxZapBps() / 10_000;
            _fund(address(this), maximum + 1, maximum + 1);
            _approveVault(address(vault));
            bytes32 state = _stateDigest();
            vm.expectRevert(abi.encodeWithSelector(Planner.ZapSizeExceeded.selector, maximum + 1, maximum));
            _zap(is0, maximum + 1, 0);
            assertEq(_stateDigest(), state);
            _assertZap(is0, maximum);
            assertTrue(vm.revertToState(initial));
            initial = vm.snapshotState();
        }
    }

    /// @notice S1-A14: exact measured integer tick move passes and one less rejects.
    function test_ENT_ZapTickMovementEqualityAndOneOverBothDirections() public {
        _tickBoundary(true);
        _tickBoundary(false);
    }

    /// @notice S1-A14: sqrt price may move within one tick with maxZapTickMove == 0.
    function test_ENT_ZapSubTickPriceMovementWithZeroTickBound() public {
        _deployPool(false, 18, 18);
        IPackage.PkgArgs memory args = _defaultArgs(key, address(token0), "Entry zero tick");
        args.maxZapTickMove = 0;
        vault = _deployVault(args);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 1e12, 1e12);
        _approveVault(address(vault));
        (uint160 beforePrice, int24 beforeTick,,) = pool.getSlot0(key.toId());
        _assertZap(false, 1e12);
        (uint160 afterPrice, int24 afterTick,,) = pool.getSlot0(key.toId());
        assertGt(afterPrice, beforePrice);
        assertEq(afterTick, beforeTick);
    }

    /// @notice S1-A13/A15/A64: partial half-swap fills are planned, but zero final credit rejects.
    /// @dev A successful partial-fill entry is not claimed. At this reachable lower
    /// endpoint G1=0 while the incumbent retains one booked token1 unit, so q=0.
    function test_ENT_ZapPartialFillWithZeroOpposingGrowthRollsBack() public {
        _deployPool(false, 18, 18);
        key.fee = 0;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args = _defaultArgs(key, address(token0), "Entry partial fill");
        args.maxZapBps = 10_000;
        args.maxZapTickMove = 1_000;
        vault = _deployVault(args);
        _bootstrap(1e12, 1e12, address(this));
        _fund(address(poolActor), uint256(1) << 126, uint256(1) << 126);
        poolActor.swap(key, SwapParams(true, -int256(uint256(1) << 126),
            TickMath.getSqrtPriceAtTick(vault.tickLower() + 60)));
        vault.compound();
        _fund(address(this), 0, 1);
        vault.donate(address(token1), 1);
        Checkpoint memory checkpoint = _checkpoint();
        assertGt(checkpoint.reserve1, 0, "must begin with both positive reserves");
        uint256 amount = checkpoint.reserve0;
        _fund(address(this), amount, 0);
        _approveVault(address(vault));
        Credit memory expected = _zapControl(true, amount);
        assertLt(uint256(-int256(expected.swap0)), amount / 2, "control must be a partial fill");
        assertGt(expected.residual0 + expected.residual1, 0);
        assertEq(expected.growth1, 0);
        assertEq(expected.incumbent.reserve1, 1);
        assertEq(expected.shares, 0);
        _zapFailure(true, amount, EntryMath.ZeroShares.selector);
    }

    /// @notice S1-A13/A15/A64: large legitimate idle makes a positive token0 partial fill reachable.
    function test_ENT_ZapToken0PartialFillIdleImbalanceAndUncreditedResidual() public {
        _partialFillSuccess(true);
    }

    /// @notice S1-A13/A15/A64: token1 partial fill credits only G at its post-swap endpoint.
    function test_ENT_ZapToken1PartialFillIdleImbalanceAndUncreditedResidual() public {
        _partialFillSuccess(false);
    }

    /// @notice S1-A15/A64: a deterministic rounding gap caps q below qQuote.
    function test_ENT_PairedRoundingCapMinimumUsesFinalNotCandidateShares() public {
        _deployPool(false, 18, 18);
        key.fee = 0;
        pool.initialize(key, uint160(1) << 96);
        vault = _deployVault(_defaultArgs(key, address(token0), "Entry rounding cap"));
        _bootstrap(1_000_000, 1_000_000, address(this));
        _fund(address(poolActor), 10_000, 0);
        poolActor.swap(key, SwapParams(true, -10_000, TickMath.MIN_SQRT_PRICE + 1));
        _fund(address(this), 100, 100);
        _approveVault(address(vault));
        token0.approve(address(vault), 100);
        token1.approve(address(vault), 100);
        Credit memory expected = _pairControl(7, 7);
        assertLt(expected.shares, expected.quote, "fixture must distinguish final cap");
        assertEq(expected.quote, 6);
        assertEq(expected.shares, 5);
        assertEq(expected.used0, 7);
        assertEq(expected.used1, 6);
        assertEq(expected.cost0, 7);
        assertEq(expected.cost1, 6);
        assertEq(expected.growth0, 7);
        assertEq(expected.growth1, 5);
        assertGt(expected.cost1, expected.growth1);
        _pairFailure(7, 7, expected.quote,
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, expected.quote, expected.shares));
        _executePair(7, 7, expected);
    }

    /// @notice S1-A13/A15/A64: failed minimum rolls back swap, fee checkpoints and pulls.
    function test_ENT_ZapFinalMinimumRollbackBothDirections() public {
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 1e16, 1e16);
        _approveVault(address(vault));
        token0.approve(address(vault), 1e16);
        token1.approve(address(vault), 1e16);
        for (uint256 i; i < 2; ++i) {
            bool is0 = i == 0;
            Credit memory expected = _zapControl(is0, 1e15);
            bytes32 before_ = _stateDigest();
            vm.expectRevert(abi.encodeWithSelector(
                IStandardExchangeErrors.MinAmountNotMet.selector, expected.shares + 1, expected.shares
            ));
            _zap(is0, 1e15, expected.shares + 1);
            assertEq(_stateDigest(), before_, "zap minimum was not atomic");
        }
    }

    /// @notice S1-A44: 6/8, 6/18 and 8/18 metadata do not rescale raw genesis or entry units.
    function test_ENT_MixedSixEightEighteenDecimalsPairedAndBothZaps() public {
        _mixedDecimals(6, 8);
        _mixedDecimals(6, 18);
        _mixedDecimals(8, 18);
    }

    /// @notice S1-A44: a real taxed paired pull cannot borrow existing backing or unbooked funds.
    function test_ENT_ForbiddenFeeOnTransferPairedPullRollsBack() public {
        EntryFeeOnTransferToken tax = _taxPool();
        _bootstrap(1e12, 1e12, address(this));
        _fund(address(this), 1e9, 1e9);
        _approveVault(address(vault));
        tax.mint(address(vault), 1e6); // Unrelated unbooked custody cannot fill the receipt gap.
        Credit memory expected = _pairControl(1e6, 1e6);
        uint256 claimed = address(tax) == address(token0) ? expected.used0 : expected.used1;
        tax.approve(address(vault), 1e9);
        tax.setTax(true);
        _pairFailure(1e6, 1e6, 0,
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, claimed - 1));
    }

    /// @notice S1-A44: false-flag zap validates actual delivery even with old excess custody.
    function test_ENT_ForbiddenFeeOnTransferZapPullRollsBack() public {
        EntryFeeOnTransferToken tax = _taxPool();
        _bootstrap(1e12, 1e12, address(this));
        _fund(address(this), 1e9, 1e9);
        _approveVault(address(vault));
        tax.mint(address(vault), 1e6);
        tax.approve(address(vault), 1e9);
        tax.setTax(true);
        bytes32 state = _stateDigest();
        vm.expectRevert(abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector, 1e6, 1e6 - 1
        ));
        _zap(address(tax) == address(token0), 1e6, 0);
        assertEq(_stateDigest(), state);
    }

    /* -------------------------- Independent controls ------------------------- */

    function _checkpoint() private view returns (Checkpoint memory c) {
        c.supply = IERC20(address(vault)).totalSupply();
        (c.liquidity,,) = pool.getPositionInfo(
            key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0)
        );
        (c.price, c.tick,,) = pool.getSlot0(key.toId());
        (c.book0, c.book1) = vault.localReserves();
        (c.principal0, c.principal1) = _principal(c.price, c.liquidity);
        c.reserve0 = c.principal0 + c.book0;
        c.reserve1 = c.principal1 + c.book1;
        c.manager0 = _balance(true, address(pool));
        c.manager1 = _balance(false, address(pool));
    }

    function _principal(uint160 price, uint128 liquidity) private view returns (uint256 a0, uint256 a1) {
        uint160 lower = TickMath.getSqrtPriceAtTick(vault.tickLower());
        uint160 upper = TickMath.getSqrtPriceAtTick(vault.tickUpper());
        if (price <= lower) return (SqrtPriceMath.getAmount0Delta(lower, upper, liquidity, false), 0);
        if (price >= upper) return (0, SqrtPriceMath.getAmount1Delta(lower, upper, liquidity, false));
        return (
            SqrtPriceMath.getAmount0Delta(price, upper, liquidity, false),
            SqrtPriceMath.getAmount1Delta(lower, price, liquidity, false)
        );
    }

    function _addition(Credit memory e, uint256 inventory0, uint256 inventory1) private view {
        uint160 lower = TickMath.getSqrtPriceAtTick(vault.tickLower());
        uint160 upper = TickMath.getSqrtPriceAtTick(vault.tickUpper());
        uint160 price = e.incumbent.price;
        e.added = LiquidityAmounts.getLiquidityForAmounts(price, lower, upper, inventory0, inventory1);
        if (price < upper) {
            e.cost0 = SqrtPriceMath.getAmount0Delta(price <= lower ? lower : price, upper, e.added, true);
        }
        if (price > lower) {
            e.cost1 = SqrtPriceMath.getAmount1Delta(lower, price >= upper ? upper : price, e.added, true);
        }
        (uint256 final0, uint256 final1) = _principal(price, e.incumbent.liquidity + e.added);
        e.growth0 = final0 - e.incumbent.principal0;
        e.growth1 = final1 - e.incumbent.principal1;
        e.residual0 = inventory0 - e.cost0;
        e.residual1 = inventory1 - e.cost1;
    }

    function _pairControl(uint256 maximum0, uint256 maximum1) private view returns (Credit memory e) {
        e.incumbent = _checkpoint();
        Checkpoint memory c = e.incumbent;
        if (c.reserve0 == 0) {
            e.quote = FullMath.mulDiv(maximum1, c.supply, c.reserve1);
            e.used1 = maximum1;
        } else if (c.reserve1 == 0) {
            e.quote = FullMath.mulDiv(maximum0, c.supply, c.reserve0);
            e.used0 = maximum0;
        } else {
            // Tests deliberately use a max-uint non-limiting leg: first compare
            // products as 512-bit integers, then divide only the limiting ratio.
            bool zeroLimits = _productLE(maximum0, c.reserve1, maximum1, c.reserve0);
            e.quote = zeroLimits ? FullMath.mulDiv(maximum0, c.supply, c.reserve0)
                : FullMath.mulDiv(maximum1, c.supply, c.reserve1);
            e.used0 = FullMath.mulDivRoundingUp(e.quote, c.reserve0, c.supply);
            e.used1 = FullMath.mulDivRoundingUp(e.quote, c.reserve1, c.supply);
        }
        _addition(e, e.used0, e.used1);
        e.shares = _credit(c, e.growth0 + e.residual0, e.growth1 + e.residual1, e.quote);
    }

    function _zapControl(bool is0, uint256 amount) private returns (Credit memory e) {
        uint256 snapshot = vm.snapshotState();
        _fund(address(poolActor), amount, amount);
        e.incumbent = _checkpoint();
        BalanceDelta delta = poolActor.swap(key, SwapParams(
            is0, -int256(amount / 2), is0 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        ));
        e.swap0 = delta.amount0();
        e.swap1 = delta.amount1();
        (e.incumbent.price, e.incumbent.tick,,) = pool.getSlot0(key.toId());
        (e.incumbent.principal0, e.incumbent.principal1) =
            _principal(e.incumbent.price, e.incumbent.liquidity);
        (uint256 fee0, uint256 fee1) = _pendingFees();
        e.incumbent.book0 += fee0;
        e.incumbent.book1 += fee1;
        e.incumbent.reserve0 = e.incumbent.principal0 + e.incumbent.book0;
        e.incumbent.reserve1 = e.incumbent.principal1 + e.incumbent.book1;
        e.incumbent.manager0 = _balance(true, address(pool)) - fee0;
        e.incumbent.manager1 = _balance(false, address(pool)) - fee1;
        uint256 inventory0 = uint256(int256(is0 ? amount : 0) + int256(e.swap0));
        uint256 inventory1 = uint256(int256(is0 ? 0 : amount) + int256(e.swap1));
        _addition(e, inventory0, inventory1);
        e.shares = _credit(e.incumbent, e.growth0, e.growth1, type(uint256).max);
        assertTrue(vm.revertToState(snapshot));
    }

    function _pendingFees() private view returns (uint256 fee0, uint256 fee1) {
        (uint128 liquidity, uint256 last0, uint256 last1) = pool.getPositionInfo(
            key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0)
        );
        (uint256 inside0, uint256 inside1) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        unchecked {
            fee0 = FullMath.mulDiv(inside0 - last0, liquidity, uint256(1) << 128);
            fee1 = FullMath.mulDiv(inside1 - last1, liquidity, uint256(1) << 128);
        }
    }

    function _credit(Checkpoint memory c, uint256 credit0, uint256 credit1, uint256 cap)
        private pure returns (uint256 q)
    {
        q = cap;
        if (c.reserve0 != 0 && !_productLE(q, c.reserve0, c.supply, credit0)) {
            q = FullMath.mulDiv(c.supply, credit0, c.reserve0);
        }
        if (c.reserve1 != 0 && !_productLE(q, c.reserve1, c.supply, credit1)) {
            q = FullMath.mulDiv(c.supply, credit1, c.reserve1);
        }
    }

    // 512-bit comparison is independent of family math; no epsilon, scaled
    // per-share truncation or overflow-prone uint256 product is accepted.
    function _productLE(uint256 a, uint256 b, uint256 c, uint256 d) private pure returns (bool) {
        (uint256 ahi, uint256 alo) = _wideProduct(a, b);
        (uint256 chi, uint256 clo) = _wideProduct(c, d);
        return ahi < chi || (ahi == chi && alo <= clo);
    }

    function _wideProduct(uint256 a, uint256 b) private pure returns (uint256 hi, uint256 lo) {
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            lo := mul(a, b)
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /* --------------------- Product execution assertions --------------------- */

    function _assertGenesis(uint256 a0, uint256 a1, uint256 q) private {
        _fund(address(this), a0, a1);
        _approveVault(address(vault));
        (uint256 preview, uint256 used0, uint256 used1) = vault.previewDepositPair(a0, a1);
        assertEq(preview, q);
        assertEq(used0, a0);
        assertEq(used1, a1);
        Credit memory expected;
        expected.incumbent = _checkpoint();
        expected.used0 = a0;
        expected.used1 = a1;
        expected.shares = q;
        _addition(expected, a0, a1);
        vm.recordLogs();
        vm.expectEmit(true, true, false, true, address(vault));
        emit IERC20Events.Transfer(address(0), RECIPIENT, q);
        assertEq(vault.depositPair(a0, a1, q, RECIPIENT, block.timestamp), q);
        assertEq(IERC20(address(vault)).totalSupply(), q);
        assertEq(IERC20(address(vault)).balanceOf(RECIPIENT), q);
        assertEq(IERC20(address(vault)).balanceOf(DEAD), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(0)), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        Checkpoint memory c = _checkpoint();
        assertGt(c.liquidity, 0);
        assertEq(vault.positionLiquidity(), c.liquidity);
        assertEq(_balance(true, address(this)), 0);
        assertEq(_balance(false, address(this)), 0);
        _assertBook(c.book0, c.book1);
        _assertPairEvent(vm.getRecordedLogs(), expected);
        _assertFinal(expected);
    }

    function _assertPair(uint256 maximum0, uint256 maximum1) private {
        _fund(address(this), maximum0, maximum1);
        _approveVault(address(vault));
        uint256 snapshot = vm.snapshotState();
        vault.compound();
        Credit memory expected = _pairControl(maximum0, maximum1);
        assertTrue(vm.revertToState(snapshot));
        _executePair(maximum0, maximum1, expected);
    }

    function _executePair(uint256 maximum0, uint256 maximum1, Credit memory e) private {
        assertGt(e.shares, 0);
        {
            (uint256 preview, uint256 used0, uint256 used1) = vault.previewDepositPair(maximum0, maximum1);
            assertEq(preview, e.shares);
            assertEq(used0, e.used0);
            assertEq(used1, e.used1);
        }
        uint256 balance0 = _balance(true, address(this));
        uint256 balance1 = _balance(false, address(this));
        uint256 approval0 = _allowance(true);
        uint256 approval1 = _allowance(false);
        vm.recordLogs();
        uint256 q = vault.depositPair{value: address(token0) == address(0) ? maximum0 : 0}(
            maximum0, maximum1, e.shares, RECIPIENT, block.timestamp
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(q, e.shares);
        assertEq(balance0 - _balance(true, address(this)), e.used0, "unused maximum0 spent");
        assertEq(balance1 - _balance(false, address(this)), e.used1, "unused maximum1 spent");
        assertEq(_allowance(true), address(token0) == address(0) ? approval0 : approval0 - e.used0);
        assertEq(_allowance(false), approval1 - e.used1);
        assertEq(_balance(true, address(pool)) - e.incumbent.manager0, e.cost0);
        assertEq(_balance(false, address(pool)) - e.incumbent.manager1, e.cost1);
        _assertFinal(e);
        _assertPairEvent(logs, e);
        _assertNonDilution(e, true);
    }

    function _assertZap(bool is0, uint256 amount) private {
        Credit memory expected = _zapControl(is0, amount);
        _executeZap(is0, amount, expected);
    }

    function _executeZap(bool is0, uint256 amount, Credit memory e) private {
        assertGt(e.shares, 0);
        address input = is0 ? address(token0) : address(token1);(uint256 preview,) = IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(input), amount, IERC20(address(vault))
        );
        assertEq(preview, e.shares);
        {
            (uint256 q, uint256 c0, uint256 c1, uint256 j0, uint256 j1) = vault.previewZapCredit(input, amount);
            assertEq(q, e.shares);
            assertEq(c0, e.growth0);
            assertEq(c1, e.growth1);
            assertEq(j0, e.residual0);
            assertEq(j1, e.residual1);
        }
        uint256 b0 = _balance(true, address(this));
        uint256 b1 = _balance(false, address(this));
        uint256 approval = _allowance(is0);
        vm.recordLogs();
        assertEq(_zap(is0, amount, e.shares), e.shares);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(b0 - _balance(true, address(this)), is0 ? amount : 0);
        assertEq(b1 - _balance(false, address(this)), is0 ? 0 : amount);
        assertEq(_allowance(is0), input == address(0) ? approval : approval - amount);
        assertEq(_balance(true, address(pool)) - e.incumbent.manager0, e.cost0);
        assertEq(_balance(false, address(pool)) - e.incumbent.manager1, e.cost1);
        _assertFinal(e);
        _assertZapEvents(logs, input, amount, e);
        _assertNonDilution(e, false);
    }

    function _assertFinal(Credit memory e) private view {
        assertEq(IERC20(address(vault)).totalSupply(), e.incumbent.supply + e.shares);
        assertEq(IERC20(address(vault)).balanceOf(RECIPIENT), e.shares);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), e.incumbent.supply);
        Checkpoint memory actual = _checkpoint();
        assertEq(actual.liquidity, e.incumbent.liquidity + e.added);
        assertEq(vault.positionLiquidity(), actual.liquidity);
        assertEq(actual.price, e.incumbent.price);
        assertEq(actual.principal0, e.incumbent.principal0 + e.growth0);
        assertEq(actual.principal1, e.incumbent.principal1 + e.growth1);
        _assertBook(e.incumbent.book0 + e.residual0, e.incumbent.book1 + e.residual1);
        (uint256 owed0, uint256 owed1) = _pendingFees();
        assertEq(owed0, 0, "uncheckpointed incumbent fee0");
        assertEq(owed1, 0, "uncheckpointed incumbent fee1");
        (, uint256 last0, uint256 last1) = pool.getPositionInfo(
            key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0)
        );
        (uint256 inside0, uint256 inside1) = pool.getFeeGrowthInside(key.toId(), vault.tickLower(), vault.tickUpper());
        assertEq(last0, inside0);
        assertEq(last1, inside1);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0), 0);
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1), 0);
    }

    function _assertNonDilution(Credit memory e, bool paired) private pure {
        uint256 credit0 = e.growth0 + (paired ? e.residual0 : 0);
        uint256 credit1 = e.growth1 + (paired ? e.residual1 : 0);
        require(_productLE(e.shares, e.incumbent.reserve0, e.incumbent.supply, credit0), "qR0 > SC0");
        require(_productLE(e.shares, e.incumbent.reserve1, e.incumbent.supply, credit1), "qR1 > SC1");
    }

    function _assertBook(uint256 b0, uint256 b1) private view {
        (uint256 local0, uint256 local1) = vault.localReserves();
        assertEq(local0, b0);
        assertEq(local1, b1);
        assertEq(_balance(true, address(vault)), b0);
        assertEq(_balance(false, address(vault)), b1);
        address face0 = address(token0) == address(0) ? address(wrappedNative) : address(token0);
        assertEq(IBasicVault(address(vault)).reserveOfToken(face0), b0);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), b1);
    }

    function _assertPairEvent(Vm.Log[] memory logs, Credit memory e) private view {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(vault) || logs[i].topics[0] != IVault.PairDeposited.selector) continue;
            assertEq(logs[i].topics[1], bytes32(uint256(uint160(address(this)))));
            assertEq(logs[i].topics[2], bytes32(uint256(uint160(RECIPIENT))));
            assertEq(logs[i].data, abi.encode(e.used0, e.used1, e.cost0, e.cost1, e.shares));
            ++found;
        }
        assertEq(found, 1);
    }

    function _assertZapEvents(Vm.Log[] memory logs, address input, uint256 amount, Credit memory e) private view {
        uint256 credits;
        uint256 swaps;
        uint256 lastSwap;
        uint256 creditIndex;
        // The selected plan can have an incumbent-maintenance swap before the
        // caller half-swap. The latter is the final swap before mint/credit.
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics[0] == IPoolManager.Swap.selector) {
                lastSwap = i;
                ++swaps;
            }
        }
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(vault) && logs[i].topics[0] == IVault.ZapCredit.selector) {
                _assertZapCreditEvent(logs[i], input, amount, e);
                ++credits;
                creditIndex = i;
            }
            if (i == lastSwap && swaps != 0) {
                _assertSwapEvent(logs[i], e);
            }
        }
        assertEq(credits, 1);
        assertGt(swaps, 0);
        assertLt(lastSwap, creditIndex);
    }

    function _assertZapCreditEvent(Vm.Log memory log_, address input, uint256 amount, Credit memory e) private view {
        assertEq(log_.topics[1], bytes32(uint256(uint160(address(this)))));
        assertEq(log_.topics[2], bytes32(uint256(uint160(RECIPIENT))));
        assertEq(log_.topics[3], bytes32(uint256(uint160(input))));
        assertEq(log_.data, abi.encode(amount, e.growth0, e.growth1, e.residual0, e.residual1, e.shares));
    }

    function _assertSwapEvent(Vm.Log memory log_, Credit memory e) private view {
        assertEq(log_.topics[2], bytes32(uint256(uint160(address(vault)))));
        (int128 d0, int128 d1, uint160 price,, int24 tick,) =
            abi.decode(log_.data, (int128, int128, uint160, uint128, int24, uint24));
        assertEq(d0, e.swap0);
        assertEq(d1, e.swap1);
        assertEq(price, e.incumbent.price);
        assertEq(tick, e.incumbent.tick);
    }

    function _maintenanceDigest(Vm.Log[] memory logs) private view returns (bytes32 result) {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(vault) && logs[i].topics[0] == IVault.Compounded.selector) {
                result = keccak256(logs[i].data);
                ++found;
            }
        }
        assertEq(found, 1);
    }

    function _pairFailure(uint256 a0, uint256 a1, uint256 minimum, bytes memory error_) private {
        bytes32 state = _stateDigest();
        vm.expectRevert(error_);
        vault.depositPair(a0, a1, minimum, RECIPIENT, block.timestamp);
        assertEq(_stateDigest(), state, "paired failure was not atomic");
    }

    function _zapFailure(bool is0, uint256 amount, bytes4 error_) private {
        bytes32 state = _stateDigest();
        vm.expectRevert(error_);
        _zap(is0, amount, 0);
        assertEq(_stateDigest(), state, "zap failure was not atomic");
    }

    function _zap(bool is0, uint256 amount, uint256 minimum) private returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(address(vault)).exchangeIn(IERC20(is0 ? address(token0) : address(token1)), amount, IERC20(address(vault)),
            minimum, RECIPIENT, false, block.timestamp
        );
        return quotedAmountOut;
    }

    function _balance(bool is0, address account) private view returns (uint256) {
        address token = is0 ? address(token0) : address(token1);
        return token == address(0) ? account.balance : IERC20(token).balanceOf(account);
    }

    function _allowance(bool is0) private view returns (uint256) {
        address token = is0 ? address(token0) : address(token1);
        return token == address(0) ? type(uint256).max : IERC20(token).allowance(address(this), address(vault));
    }

    function _stateDigest() private view returns (bytes32) {
        bytes32 manager = _managerDigest();
        (uint256 b0, uint256 b1) = vault.localReserves();
        bytes32 custody = keccak256(abi.encode(
            b0, b1, _balance(true, address(vault)), _balance(false, address(vault))
        ));
        custody = keccak256(abi.encode(
            custody,
            _balance(true, address(this)), _balance(false, address(this)),
            _balance(true, address(pool)), _balance(false, address(pool))
        ));
        bytes32 tokenState = keccak256(abi.encode(
            IERC20(address(vault)).totalSupply(), IERC20(address(vault)).balanceOf(RECIPIENT),
            IERC20(address(vault)).balanceOf(address(this)),
            address(token0) == address(0) ? 0 : token0.allowance(address(this), address(vault)),
            token1.allowance(address(this), address(vault))
        ));
        bytes32 currencies = keccak256(abi.encode(
            address(token0) == address(0) ? 0 : token0.totalSupply(), token1.totalSupply(),
            _balance(true, RECIPIENT), _balance(false, RECIPIENT),
            _balance(true, address(poolActor)), _balance(false, address(poolActor))
        ));
        return keccak256(abi.encode(manager, custody, tokenState, currencies));
    }

    function _managerDigest() private view returns (bytes32 result) {
        {
            (uint160 price, int24 tick, uint24 protocolFee, uint24 lpFee) = pool.getSlot0(key.toId());
            result = keccak256(abi.encode(price, tick, protocolFee, lpFee));
        }
        {
            (uint128 liquidity, uint256 last0, uint256 last1) = pool.getPositionInfo(
                key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0)
            );
            result = keccak256(abi.encode(result, liquidity, last0, last1));
        }
        {
            (uint256 global0, uint256 global1) = pool.getFeeGrowthGlobals(key.toId());
            result = keccak256(abi.encode(result, global0, global1, pool.getLiquidity(key.toId())));
        }
        for (uint256 i; i < 2; ++i) {
            (uint128 gross, int128 net, uint256 outside0, uint256 outside1) =
                pool.getTickInfo(key.toId(), i == 0 ? vault.tickLower() : vault.tickUpper());
            result = keccak256(abi.encode(result, gross, net, outside0, outside1));
        }
    }

    /* --------------------------- Scenario setup ----------------------------- */

    function _partialFillSuccess(bool is0) private {
        _deployPool(false, 18, 18);
        key.fee = 0;
        // Reach the real range endpoint without exceeding the distinct-word budget.
        key.tickSpacing = 32767;
        pool.initialize(key, uint160(1) << 96);
        IPackage.PkgArgs memory args = _defaultArgs(
            key, address(token0), is0 ? "Entry partial zero" : "Entry partial one"
        );
        args.maxZapBps = 10_000;
        args.maxZapTickMove = 1_000_000;
        vault = _deployVault(args);
        _bootstrap(1e12, 1e12, address(this));
        _fund(address(this), is0 ? 1e34 : 0, is0 ? 0 : 1e34);
        vault.donate(is0 ? address(token0) : address(token1), 1e34);
        _fund(address(this), is0 ? 1e33 : 0, is0 ? 0 : 1e33);
        uint256 snapshot = vm.snapshotState();
        vault.compound();
        Checkpoint memory maintained = _checkpoint();
        assertEq(is0 ? maintained.book1 : maintained.book0, 0, "no opposing idle denominator");
        assertGt(is0 ? maintained.reserve1 : maintained.reserve0, 0, "valid pre-swap basket");
        Credit memory expected = _zapControl(is0, 1e33);
        uint256 consumed = uint256(-int256(is0 ? expected.swap0 : expected.swap1));
        assertGt(consumed, 0);
        assertLt(consumed, 1e33 / 2, "must exhaust real full-range liquidity before half input");
        assertEq(is0 ? expected.incumbent.reserve1 : expected.incumbent.reserve0, 0);
        assertGt(expected.shares, 0);
        assertGt(is0 ? expected.residual1 : expected.residual0, 0, "opposing residual is not share credit");
        assertTrue(vm.revertToState(snapshot));
        _executeZap(is0, 1e33, expected);
    }

    function _oneSided(bool live0) private {
        _bootstrap(live0 ? 2 : 1, live0 ? 1 : 2, address(this));
        Checkpoint memory c = _checkpoint();
        assertEq(live0 ? c.reserve1 : c.reserve0, 0);
        assertGt(live0 ? c.reserve0 : c.reserve1, 0);
        _fund(address(this), 123, 123);
        _approveVault(address(vault));
        Credit memory e = _pairControl(live0 ? 7 : 123, live0 ? 123 : 7);
        assertEq(live0 ? e.used0 : e.used1, 7);
        assertEq(live0 ? e.used1 : e.used0, 0);
        assertEq(e.added, 0);
        assertEq(e.growth0 + e.growth1, 0);
        assertEq(live0 ? e.residual0 : e.residual1, 7);
        _executePair(live0 ? 7 : 123, live0 ? 123 : 7, e);
        _zapFailure(live0, 1, IVault.InvalidAccountingState.selector);
    }

    function _zapWithImbalancedBook(bool is0) private {
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 3e16, 3e16);
        _approveVault(address(vault));
        vault.donate(address(token0), 1e15);
        vault.donate(address(token1), 123);
        _fund(address(poolActor), 1e16, 1e16);
        poolActor.donate(key, 1e14, 2e14);
        uint256 snapshot = vm.snapshotState();
        vault.compound();
        Credit memory expected = _zapControl(is0, 1e15 + 1); // odd input proves floor(amount/2)
        Checkpoint memory maintained = _checkpoint();
        assertGt(expected.incumbent.book0 + expected.incumbent.book1,
            maintained.book0 + maintained.book1, "entry-swap fees must belong to incumbents");
        assertGt(expected.residual0 + expected.residual1, 0);
        assertEq(uint256(-int256(is0 ? expected.swap0 : expected.swap1)), (uint256(1e15) + 1) / 2);
        assertTrue(vm.revertToState(snapshot));
        // Compare full pre-maintenance execution against the independently
        // maintained and manually half-swapped state, not a SUT preview.
        uint256 oldBalance = _balance(is0, address(this));
        vm.recordLogs();
        assertEq(_zap(is0, 1e15 + 1, expected.shares), expected.shares);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(oldBalance - _balance(is0, address(this)), 1e15 + 1);
        _assertFinal(expected);
        _assertNonDilution(expected, false);
        _assertZapEvents(logs, is0 ? address(token0) : address(token1), 1e15 + 1, expected);
    }

    function _tickBoundary(bool is0) private {
        _deployPool(false, 18, 18);
        uint256 beforeGenesis = vm.snapshotState();
        IPackage.PkgArgs memory args = _defaultArgs(key, address(token0), is0 ? "Tick zero" : "Tick one");
        args.maxZapBps = 10_000;
        args.maxZapTickMove = 10_000;
        vault = _deployVault(args);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 1e17, 1e17);
        _fund(address(poolActor), 1e17, 1e17);
        _approveVault(address(vault));
        Credit memory expected = _zapControl(is0, 1e16);
        uint256 movement = uint256(int256(expected.incumbent.tick < 0
            ? -expected.incumbent.tick : expected.incumbent.tick));
        assertGt(movement, 0);
        assertTrue(vm.revertToState(beforeGenesis));
        // Rebootstrap identical genuine positions in two immutable-bound instances
        // from the same pre-genesis state. No instance storage setters are used.
        beforeGenesis = vm.snapshotState();
        args.maxZapTickMove = int24(int256(movement));
        args.name = is0 ? "Tick equality zero" : "Tick equality one";
        vault = _deployVault(args);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 1e17, 1e17);
        _approveVault(address(vault));
        _assertZap(is0, 1e16);
        assertTrue(vm.revertToState(beforeGenesis));
        args.maxZapTickMove = int24(int256(movement - 1));
        args.name = is0 ? "Tick over zero" : "Tick over one";
        vault = _deployVault(args);
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(this), 1e17, 1e17);
        _approveVault(address(vault));
        bytes32 state = _stateDigest();
        vm.expectRevert(abi.encodeWithSelector(Planner.ZapTickMoveExceeded.selector, movement, movement - 1));
        _zap(is0, 1e16, 0);
        assertEq(_stateDigest(), state);
    }

    function _mixedDecimals(uint8 d0, uint8 d1) private {
        _deployPool(false, d0, d1);
        vault = _deployVault(_defaultArgs(key, address(token0),
            d0 == 8 ? "Entry 8 18" : d1 == 8 ? "Entry 6 8" : "Entry 6 18"));
        assertTrue(
            (IERC20Metadata(address(token0)).decimals() == d0 && IERC20Metadata(address(token1)).decimals() == d1)
            || (IERC20Metadata(address(token0)).decimals() == d1 && IERC20Metadata(address(token1)).decimals() == d0)
        );
        _bootstrap(1e12, 1e12, address(this));
        assertEq(IERC20(address(vault)).totalSupply(), 1e12, "raw-unit geometric mean");
        _assertPair(1e9, 2e9);
        // Separate recipient balances from subsequent exact-output assertions.
        uint256 recipientShares = IERC20(address(vault)).balanceOf(RECIPIENT);
        vm.prank(RECIPIENT);
        IERC20(address(vault)).transfer(address(this), recipientShares);
        _fund(address(this), 1e9, 1e9);
        _fund(address(poolActor), 1e9, 1e9);
        vault.compound();
        uint256 snapshot = vm.snapshotState();
        _assertZap(true, 1e8);
        assertTrue(vm.revertToState(snapshot));
        _assertZap(false, 1e8);
    }

    function _taxPool() private returns (EntryFeeOnTransferToken tax) {
        tax = new EntryFeeOnTransferToken();
        ERC20PermitMintableStub ordinary = new ERC20PermitMintableStub("Entry ordinary", "ORD", 18, address(this), 0);
        token0 = ERC20PermitMintableStub(address(tax) < address(ordinary) ? address(tax) : address(ordinary));
        token1 = ERC20PermitMintableStub(address(tax) < address(ordinary) ? address(ordinary) : address(tax));
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
        poolActor = new PoolActor(pool);
        vault = _deployVault(_defaultArgs(key, address(token0), "Entry real forbidden FoT"));
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultEntryTest[]
