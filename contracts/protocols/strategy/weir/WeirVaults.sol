// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@crane/contracts/external/openzeppelin-contracts-v5/access/Ownable2Step.sol";
import {Pausable} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/Pausable.sol";
import {ReentrancyGuard} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/ReentrancyGuard.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint96} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {WeirBase} from "./base/WeirBase.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";

/// @title WeirVaults
/// @notice Auto-compounding full-range vaults on any Uniswap V4 pool, hooked or not.
/// Deposit one token (or both); the vault balances it with a swap in the same pool, adds it
/// to a single full-range position, and issues shares. Swap fees are folded back into the
/// position on every deposit, withdrawal, and whenever anyone calls `compound`, so a share
/// only ever grows in liquidity. Withdraw to both tokens, or zap out to one.
///
/// Money rules: `perfFeeBps` (default 5%, hard cap 10%) of harvested fees goes to the treasury.
/// Nothing is charged on deposits or withdrawals. Withdrawals work while paused.
contract WeirVaults is WeirBase, Ownable2Step, Pausable, ReentrancyGuard {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 internal constant BPS = 10_000;
    uint16 public constant MAX_PERF_FEE_BPS = 1_000;
    uint256 public constant MIN_SHARES = 1_000; // locked forever on the first deposit

    struct Vault {
        PoolKey key;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 totalShares;
        uint256 idle0; // dust that did not fit the price ratio, re-added on the next compound
        uint256 idle1;
        uint64 lastCompound;
        bool exists;
    }

    struct DepositParams {
        PoolKey key;
        uint256 amount0;
        uint256 amount1;
        bool zap; // swap inside the pool so the deposit matches the price ratio
        uint256 minShares;
        address recipient;
        uint256 deadline;
        bytes hookData;
    }

    struct WithdrawParams {
        PoolKey key;
        uint256 shares;
        uint8 zapTo; // 0 = both tokens, 1 = everything as currency0, 2 = everything as currency1
        uint256 min0;
        uint256 min1;
        address recipient;
        uint256 deadline;
        bytes hookData;
    }

    enum Action {
        DEPOSIT,
        WITHDRAW,
        COMPOUND
    }

    address public treasury;
    uint16 public perfFeeBps = 500;
    mapping(PoolId => Vault) internal _vaults;
    mapping(PoolId => mapping(address => uint256)) public sharesOf;
    PoolId[] public allVaults;

    event VaultCreated(PoolId indexed id, PoolKey key);
    event Deposited(PoolId indexed id, address indexed user, uint256 shares, uint256 used0, uint256 used1);
    event Withdrawn(PoolId indexed id, address indexed user, uint256 shares, uint256 out0, uint256 out1);
    event Compounded(PoolId indexed id, uint256 fees0, uint256 fees1, uint128 liquidityAdded);
    event SharesTransferred(PoolId indexed id, address indexed from, address indexed to, uint256 shares);
    event TreasurySet(address treasury);
    event PerfFeeSet(uint16 bps);

    error NoVault();
    error VaultExists();
    error PoolNotInitialized();
    error Slippage();
    error ZeroShares();
    error ZeroAddress();
    error FeeTooHigh();
    error BadZap();

    constructor(IPoolManager _pm, address _treasury, address _owner) WeirBase(_pm) Ownable(_owner) {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    // ───────────────────────────────────────────────────────────── views ──

    function vault(PoolId id) external view returns (Vault memory) {
        return _vaults[id];
    }

    function vaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    /// @notice Token amounts `shares` would redeem for right now, before pending fees.
    function previewRedeem(PoolId id, uint256 shares) public view returns (uint256 amount0, uint256 amount1) {
        Vault storage v = _vaults[id];
        if (v.totalShares == 0) return (0, 0);
        (uint160 sqrtP,,,) = poolManager.getSlot0(id);
        uint128 liq = uint128((uint256(v.liquidity) * shares) / v.totalShares);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtP, TickMath.getSqrtPriceAtTick(v.tickLower), TickMath.getSqrtPriceAtTick(v.tickUpper), liq
        );
        amount0 += (v.idle0 * shares) / v.totalShares;
        amount1 += (v.idle1 * shares) / v.totalShares;
    }

    /// @notice Swap fees waiting to be compounded, before the performance fee.
    function pendingFees(PoolId id) external view returns (uint256 fees0, uint256 fees1) {
        Vault storage v = _vaults[id];
        if (v.liquidity == 0) return (0, 0);
        (uint128 liq, uint256 last0, uint256 last1) =
            poolManager.getPositionInfo(id, address(this), v.tickLower, v.tickUpper, bytes32(0));
        (uint256 in0, uint256 in1) = poolManager.getFeeGrowthInside(id, v.tickLower, v.tickUpper);
        unchecked {
            fees0 = FullMath.mulDiv(in0 - last0, liq, FixedPoint128.Q128);
            fees1 = FullMath.mulDiv(in1 - last1, liq, FixedPoint128.Q128);
        }
    }

    // ────────────────────────────────────────────────────────────── user ──

    /// @notice Open a vault for an initialised pool. Anyone can; one vault per pool.
    function createVault(PoolKey calldata key) public returns (PoolId id) {
        id = key.toId();
        if (_vaults[id].exists) revert VaultExists();
        (uint160 sqrtP,,,) = poolManager.getSlot0(id);
        if (sqrtP == 0) revert PoolNotInitialized();
        Vault storage v = _vaults[id];
        v.key = key;
        v.tickLower = TickMath.minUsableTick(key.tickSpacing);
        v.tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        v.exists = true;
        allVaults.push(id);
        emit VaultCreated(id, key);
    }

    function deposit(DepositParams calldata p)
        external
        payable
        whenNotPaused
        nonReentrant
        checkDeadline(p.deadline)
        returns (uint256 shares)
    {
        if (p.recipient == address(0)) revert ZeroAddress();
        PoolId id = p.key.toId();
        if (!_vaults[id].exists) createVault(p.key);
        _checkNative(p.key.currency0, p.amount0, p.key.currency1, p.amount1);
        _pull(p.key.currency0, msg.sender, p.amount0);
        _pull(p.key.currency1, msg.sender, p.amount1);

        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = abi.decode(
            poolManager.unlock(abi.encode(Action.DEPOSIT, id, abi.encode(p, msg.sender))), (uint256, uint256, uint256)
        );
        if (shares < p.minShares || shares == 0) revert Slippage();
        sharesOf[id][p.recipient] += shares;
        _send(p.key.currency0, msg.sender, p.amount0 - used0);
        _send(p.key.currency1, msg.sender, p.amount1 - used1);
        emit Deposited(id, p.recipient, shares, used0, used1);
    }

    function withdraw(WithdrawParams calldata p)
        external
        nonReentrant
        checkDeadline(p.deadline)
        returns (uint256 out0, uint256 out1)
    {
        if (p.zapTo > 2) revert BadZap();
        if (p.recipient == address(0)) revert ZeroAddress();
        PoolId id = p.key.toId();
        Vault storage v = _vaults[id];
        if (!v.exists) revert NoVault();
        if (p.shares == 0) revert ZeroShares();
        sharesOf[id][msg.sender] -= p.shares; // reverts on insufficient shares

        (out0, out1) = abi.decode(poolManager.unlock(abi.encode(Action.WITHDRAW, id, abi.encode(p))), (uint256, uint256));
        if (out0 < p.min0 || out1 < p.min1) revert Slippage();
        emit Withdrawn(id, msg.sender, p.shares, out0, out1);
    }

    /// @notice Fold pending fees back into the position. Anyone can call it.
    function compound(PoolKey calldata key, bytes calldata hookData) external nonReentrant {
        PoolId id = key.toId();
        if (!_vaults[id].exists) revert NoVault();
        poolManager.unlock(abi.encode(Action.COMPOUND, id, hookData));
    }

    function transferShares(PoolId id, address to, uint256 shares) external {
        if (to == address(0)) revert ZeroAddress();
        sharesOf[id][msg.sender] -= shares;
        sharesOf[id][to] += shares;
        emit SharesTransferred(id, msg.sender, to, shares);
    }

    // ───────────────────────────────────────────────────── unlock callback ──

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        (Action action, PoolId id, bytes memory inner) = abi.decode(data, (Action, PoolId, bytes));
        Vault storage v = _vaults[id];
        if (action == Action.COMPOUND) {
            _compound(v, id, inner); // inner is the hook data itself
            return "";
        }
        if (action == Action.DEPOSIT) {
            (DepositParams memory p, address depositor) = abi.decode(inner, (DepositParams, address));
            _compound(v, id, p.hookData);
            return _deposit(v, p, depositor);
        }
        WithdrawParams memory w = abi.decode(inner, (WithdrawParams));
        _compound(v, id, w.hookData);
        return _withdraw(v, w);
    }

    struct DepositFrame {
        int256 net0;
        int256 net1;
        uint256 a0;
        uint256 a1;
        uint128 liq;
        uint256 shares;
    }

    function _deposit(Vault storage v, DepositParams memory p, address depositor) internal returns (bytes memory) {
        DepositFrame memory frame;
        frame.a0 = p.amount0;
        frame.a1 = p.amount1;
        if (p.zap) (frame.net0, frame.net1, frame.a0, frame.a1) = _balance(v.key, frame.a0, frame.a1, p.hookData);

        {
            (uint160 sqrtP,,,) = poolManager.getSlot0(v.key.toId());
            frame.liq = LiquidityAmounts.getLiquidityForAmounts(
                sqrtP,
                TickMath.getSqrtPriceAtTick(v.tickLower),
                TickMath.getSqrtPriceAtTick(v.tickUpper),
                frame.a0 > 2 ? frame.a0 - 2 : 0,
                frame.a1 > 2 ? frame.a1 - 2 : 0
            );
        }
        if (v.totalShares == 0) {
            if (frame.liq <= MIN_SHARES) revert ZeroShares();
            frame.shares = frame.liq - MIN_SHARES;
            v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
        } else {
            frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
        }
        if (frame.shares == 0) revert ZeroShares();

        (BalanceDelta d,) = poolManager.modifyLiquidity(
            v.key, ModifyLiquidityParams(v.tickLower, v.tickUpper, int256(uint256(frame.liq)), bytes32(0)), p.hookData
        );
        v.liquidity += frame.liq;
        v.totalShares += frame.shares;
        frame.net0 += d.amount0();
        frame.net1 += d.amount1();

        // Pay what is owed from the depositor's funds held here; credits go straight back to them.
        (uint256 used0, uint256 used1) = (frame.net0 < 0 ? uint256(-frame.net0) : 0, frame.net1 < 0 ? uint256(-frame.net1) : 0);
        _settle(v.key.currency0, frame.net0, depositor);
        _settle(v.key.currency1, frame.net1, depositor);
        return abi.encode(frame.shares, used0, used1);
    }

    function _withdraw(Vault storage v, WithdrawParams memory w) internal returns (bytes memory) {
        uint256 total = v.totalShares;
        uint128 liq = uint128((uint256(v.liquidity) * w.shares) / total);
        uint256 i0 = (v.idle0 * w.shares) / total;
        uint256 i1 = (v.idle1 * w.shares) / total;
        v.idle0 -= i0;
        v.idle1 -= i1;
        v.liquidity -= liq;
        v.totalShares = total - w.shares;

        int256 net0;
        int256 net1;
        if (liq > 0) {
            (BalanceDelta d,) = poolManager.modifyLiquidity(
                v.key, ModifyLiquidityParams(v.tickLower, v.tickUpper, -int256(uint256(liq)), bytes32(0)), w.hookData
            );
            net0 = d.amount0();
            net1 = d.amount1();
        }
        // Idle dust is held by this contract, not the PoolManager; pay it in first so it can be zapped too.
        _pay(v.key.currency0, i0);
        _pay(v.key.currency1, i1);
        net0 += int256(i0);
        net1 += int256(i1);

        if (w.zapTo == 1 && net1 > 0) {
            BalanceDelta s = _swap(v.key, false, uint256(net1), w.hookData);
            net0 += s.amount0();
            net1 += s.amount1();
        } else if (w.zapTo == 2 && net0 > 0) {
            BalanceDelta s = _swap(v.key, true, uint256(net0), w.hookData);
            net0 += s.amount0();
            net1 += s.amount1();
        }
        _settle(v.key.currency0, net0, w.recipient);
        _settle(v.key.currency1, net1, w.recipient);
        return abi.encode(net0 > 0 ? uint256(net0) : 0, net1 > 0 ? uint256(net1) : 0);
    }

    struct CompoundFrame {
        uint256 f0;
        uint256 f1;
        uint256 cut0;
        uint256 cut1;
        uint256 r0;
        uint256 r1;
        int256 net0;
        int256 net1;
        uint128 liq;
    }

    /// @dev Harvest fees, take the performance fee, re-add the rest plus idle dust as liquidity.
    /// Leaves this contract's PoolManager balance at zero.
    function _compound(Vault storage v, PoolId id, bytes memory hookData) internal {
        v.lastCompound = uint64(block.timestamp);
        if (v.liquidity == 0) return;
        (BalanceDelta fees,) = poolManager.modifyLiquidity(
            v.key, ModifyLiquidityParams(v.tickLower, v.tickUpper, 0, bytes32(0)), hookData
        );
        CompoundFrame memory frame;
        frame.f0 = fees.amount0() > 0 ? uint128(fees.amount0()) : 0;
        frame.f1 = fees.amount1() > 0 ? uint128(fees.amount1()) : 0;
        frame.cut0 = (frame.f0 * perfFeeBps) / BPS;
        frame.cut1 = (frame.f1 * perfFeeBps) / BPS;
        _take(v.key.currency0, treasury, frame.cut0);
        _take(v.key.currency1, treasury, frame.cut1);

        frame.r0 = frame.f0 - frame.cut0 + v.idle0;
        frame.r1 = frame.f1 - frame.cut1 + v.idle1;
        frame.net0 = int256(frame.f0 - frame.cut0);
        frame.net1 = int256(frame.f1 - frame.cut1);
        if (frame.r0 > 2 || frame.r1 > 2) {
            (uint160 sqrtP,,,) = poolManager.getSlot0(id);
            frame.liq = LiquidityAmounts.getLiquidityForAmounts(
                sqrtP,
                TickMath.getSqrtPriceAtTick(v.tickLower),
                TickMath.getSqrtPriceAtTick(v.tickUpper),
                frame.r0 > 2 ? frame.r0 - 2 : 0,
                frame.r1 > 2 ? frame.r1 - 2 : 0
            );
        }
        if (frame.liq > 0) {
            (BalanceDelta d,) = poolManager.modifyLiquidity(
                v.key, ModifyLiquidityParams(v.tickLower, v.tickUpper, int256(uint256(frame.liq)), bytes32(0)), hookData
            );
            v.liquidity += frame.liq;
            frame.net0 += d.amount0();
            frame.net1 += d.amount1();
        }
        // Positive net = fee credit left over -> hold it here as idle. Negative = idle was used -> pay it in.
        v.idle0 = uint256(int256(v.idle0) + frame.net0);
        v.idle1 = uint256(int256(v.idle1) + frame.net1);
        _settle(v.key.currency0, frame.net0, address(this));
        _settle(v.key.currency1, frame.net1, address(this));
        if (frame.f0 > 0 || frame.f1 > 0) emit Compounded(id, frame.f0, frame.f1, frame.liq);
    }

    /// @dev Swap part of the larger side so the two amounts match the pool price by value
    /// (the ratio a full-range position needs). Returns the swap delta and the new amounts.
    function _balance(PoolKey memory key, uint256 a0, uint256 a1, bytes memory hookData)
        internal
        returns (int256 net0, int256 net1, uint256 n0, uint256 n1)
    {
        (uint160 sqrtP,,,) = poolManager.getSlot0(key.toId());
        uint256 a0in1 = FullMath.mulDiv(FullMath.mulDiv(a0, sqrtP, FixedPoint96.Q96), sqrtP, FixedPoint96.Q96);
        n0 = a0;
        n1 = a1;
        BalanceDelta s;
        if (a0in1 > a1) {
            uint256 x = (a0 - FullMath.mulDiv(FullMath.mulDiv(a1, FixedPoint96.Q96, sqrtP), FixedPoint96.Q96, sqrtP)) / 2;
            if (x == 0) return (0, 0, n0, n1);
            s = _swap(key, true, x, hookData);
        } else if (a1 > a0in1) {
            uint256 x = (a1 - a0in1) / 2;
            if (x == 0) return (0, 0, n0, n1);
            s = _swap(key, false, x, hookData);
        } else {
            return (0, 0, n0, n1);
        }
        net0 = s.amount0();
        net1 = s.amount1();
        n0 = uint256(int256(a0) + net0);
        n1 = uint256(int256(a1) + net1);
    }

    function _swap(PoolKey memory key, bool zeroForOne, uint256 amountIn, bytes memory hookData)
        internal
        returns (BalanceDelta)
    {
        return poolManager.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            hookData
        );
    }

    // ───────────────────────────────────────────────────────────── admin ──

    function setTreasury(address t) external onlyOwner {
        if (t == address(0)) revert ZeroAddress();
        treasury = t;
        emit TreasurySet(t);
    }

    function setPerfFee(uint16 bps) external onlyOwner {
        if (bps > MAX_PERF_FEE_BPS) revert FeeTooHigh();
        perfFeeBps = bps;
        emit PerfFeeSet(bps);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
