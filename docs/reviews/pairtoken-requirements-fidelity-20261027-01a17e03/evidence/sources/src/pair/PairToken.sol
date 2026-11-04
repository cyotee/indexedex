// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";

import {LiquidityAmounts} from "../vendor/uniswap/LiquidityAmounts.sol";
import {PriceMath} from "../base/PriceMath.sol";

/// @notice The slice of the factory a pair token reads at run time (guards + fee routing).
interface IPairTokenFactoryView {
    function feeManager() external view returns (address);
    function maxZapBps() external view returns (uint16);
    function maxZapTickMove() external view returns (int24);
    function protocolFeeBps() external view returns (uint16);
}

interface IPairTokenFeeManager {
    function notify(address token, uint256 amount, PoolId poolId) external payable;
}

/// @title PairToken
/// @notice A plain, freely transferable ERC-20 that IS a full range Uniswap v4 position.
///         Mint by depositing both legs (or zap in with one), redeem pro rata at any time,
///         fees compound back into the position on every touch. One pair, one token
///         (e.g. WETHNVDA). Deployed as an EIP-1167 clone by `PairTokenFactory`; the
///         position is held directly in the PoolManager (no position NFT).
/// @dev Shares are quoted on the vault's own redeemable basket (position amounts at the
///      live sqrt price plus idle balances). Dead shares are minted at genesis against
///      first depositor inflation; zaps are bounded in size and allowed tick move.
contract PairToken is IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;

    // ------------------------------------------------------------------ ERC-20

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ------------------------------------------------------------------ vault

    uint256 public constant BPS = 10_000;
    /// @notice Shares burned to the dead address at genesis (first depositor inflation guard).
    uint256 public constant DEAD_SHARES = 1e3;
    /// @notice Exit retention in bps, left to the remaining holders on every redeem.
    uint256 public constant RETENTION_BPS = 10;
    /// @notice Idle balances under this are not worth a pool touch.
    uint256 public constant DUST = 1e3;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public factory;
    IPoolManager public poolManager;
    PoolKey internal _key;
    PoolId public poolId;
    int24 public tickLower;
    int24 public tickUpper;
    bool public initialized;

    uint256 private _reservedNative;
    uint256 private _entered;
    bool private _skipAdd;

    enum Op {
        None,
        Add,
        Remove,
        Collect,
        Deploy
    }

    struct DeployData {
        bool zeroForOne;
        uint256 swapAmount;
    }

    struct DeployResult {
        uint256 used0;
        uint256 used1;
        uint256 swapOut;
        int24 tickBefore;
        int24 tickAfter;
        uint128 liquidityAdded;
    }

    error AlreadyInitialized();
    error NotFactory();
    error NotPoolManager();
    error Reentrancy();
    error BadGenesis();
    error MinShares();
    error MinOut();
    error ZapTooLarge();
    error ZapMovesPrice();
    error BadToken();
    error NativeMismatch();
    error TransferFailed();
    error ZeroAddress();

    event Deposit(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 shares);
    event Redeem(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 shares);
    event Compounded(uint256 fees0, uint256 fees1, uint256 protocol0, uint256 protocol1, uint128 liquidityAdded);

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    modifier nonReentrant() {
        if (_entered != 0) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    /// @notice Native legs (ETH) arrive here from the PoolManager and from refunds.
    receive() external payable {}

    // ------------------------------------------------------------------ init

    /// @notice One shot initializer, called by the factory in the same tx as the clone.
    function initialize(IPoolManager _poolManager, PoolKey calldata key, string calldata name_, string calldata symbol_)
        external
    {
        if (initialized) revert AlreadyInitialized();
        if (address(_poolManager) == address(0)) revert ZeroAddress();
        initialized = true;
        factory = msg.sender;
        poolManager = _poolManager;
        _key = key;
        poolId = key.toId();
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        name = name_;
        symbol = symbol_;
    }

    // ------------------------------------------------------------------ ERC-20

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    // ------------------------------------------------------------------ views

    function poolKey() external view returns (PoolKey memory) {
        return _key;
    }

    function token0() public view returns (address) {
        return Currency.unwrap(_key.currency0);
    }

    function token1() public view returns (address) {
        return Currency.unwrap(_key.currency1);
    }

    /// @notice Liquidity of the vault's full range position.
    function positionLiquidity() public view returns (uint128) {
        return poolManager.getPositionLiquidity(
            poolId, Position.calculatePositionKey(address(this), tickLower, tickUpper, bytes32(0))
        );
    }

    /// @notice Everything a full redemption of all shares would return, at the live price.
    function basket() public view returns (uint256 reserve0, uint256 reserve1) {
        (uint160 sqrtP,,,) = poolManager.getSlot0(poolId);
        uint128 liq = positionLiquidity();
        if (liq > 0) {
            reserve0 = SqrtPriceMath.getAmount0Delta(sqrtP, TickMath.getSqrtPriceAtTick(tickUpper), liq, false);
            reserve1 = SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(tickLower), sqrtP, liq, false);
        }
        reserve0 += _idle(_key.currency0);
        reserve1 += _idle(_key.currency1);
    }

    /// @notice Quote a paired deposit against the current basket (pending fees not included).
    function previewDeposit(uint256 amount0, uint256 amount1)
        public
        view
        returns (uint256 shares, uint256 used0, uint256 used1)
    {
        (uint256 r0, uint256 r1) = basket();
        return _quoteShares(amount0, amount1, r0, r1, totalSupply);
    }

    /// @notice Quote what `shares` redeem for right now, net of the exit retention.
    function previewRedeem(uint256 shares) external view returns (uint256 amount0, uint256 amount1) {
        uint256 supply = totalSupply;
        if (supply == 0 || shares == 0) return (0, 0);
        (uint256 r0, uint256 r1) = basket();
        uint256 payout = (shares * (BPS - RETENTION_BPS)) / BPS;
        amount0 = FullMath.mulDiv(r0, payout, supply);
        amount1 = FullMath.mulDiv(r1, payout, supply);
    }

    // ------------------------------------------------------------------ deposit

    /// @notice Deposit both legs, receive shares. Excess of the non binding leg is refunded.
    /// @dev A native leg is always currency0 and must arrive as `msg.value == amount0`.
    function deposit(uint256 amount0, uint256 amount1, uint256 minShares, address to)
        external
        payable
        nonReentrant
        returns (uint256 shares)
    {
        if (to == address(0)) revert ZeroAddress();
        _checkNative(amount0);
        _reservedNative = msg.value;
        _compound();

        (uint256 r0, uint256 r1) = basket();
        uint256 supply = totalSupply;
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = _quoteShares(amount0, amount1, r0, r1, supply);
        if (shares == 0 || shares < minShares) revert MinShares();

        used0 = _pull(_key.currency0, used0);
        used1 = _pull(_key.currency1, used1);
        // From here the pulled legs are idle vault balance, not a pending refund.
        _reservedNative = _key.currency0.isAddressZero() ? msg.value - used0 : 0;

        uint128 added = _addAll();

        if (supply == 0) {
            // Genesis must actually open the position. A pre existing pool parked at an
            // extreme price (or a seed the full range cannot absorb) would otherwise mint
            // shares against idle balances with zero pool liquidity behind them.
            if (added == 0) revert BadGenesis();
            _mint(DEAD, DEAD_SHARES);
            shares -= DEAD_SHARES;
        }
        _mint(to, shares);
        _refundNative();
        emit Deposit(msg.sender, to, used0, used1, shares);
    }

    /// @dev Mint the position liquidity that the current idle balances can fund.
    function _addAll() internal returns (uint128 liq) {
        uint256 i0 = _idle(_key.currency0);
        uint256 i1 = _idle(_key.currency1);
        (uint160 sqrtP,,,) = poolManager.getSlot0(poolId);
        liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), i0, i1
        );
        if (liq > 0) _unlock(Op.Add, abi.encode(liq));
    }

    /// @notice Deposit a single leg: half is swapped through the pool, both halves go into
    ///         the position in one lock. Bounded by `maxZapBps` of the pool reserve and by
    ///         `maxZapTickMove` so a zap can never move the price materially.
    function zapDeposit(address tokenIn, uint256 amountIn, uint256 minShares, address to)
        external
        payable
        nonReentrant
        returns (uint256 shares)
    {
        if (to == address(0)) revert ZeroAddress();
        bool zeroForOne;
        if (tokenIn == token0()) zeroForOne = true;
        else if (tokenIn == token1()) zeroForOne = false;
        else revert BadToken();
        if (_key.currency0.isAddressZero() && zeroForOne) {
            if (msg.value != amountIn) revert NativeMismatch();
        } else if (msg.value != 0) {
            revert NativeMismatch();
        }
        _reservedNative = msg.value;
        _compound();

        (uint256 r0, uint256 r1) = basket();
        uint256 supply = totalSupply;
        if (supply == 0 || r0 == 0 || r1 == 0) revert BadGenesis();
        IPairTokenFactoryView f = IPairTokenFactoryView(factory);
        uint256 reserveIn = zeroForOne ? r0 : r1;
        if (amountIn == 0 || amountIn > (reserveIn * f.maxZapBps()) / BPS) revert ZapTooLarge();

        amountIn = _pull(zeroForOne ? _key.currency0 : _key.currency1, amountIn);
        _reservedNative = 0;

        DeployResult memory res = _deploy(zeroForOne, amountIn / 2);
        int24 moved = res.tickAfter >= res.tickBefore ? res.tickAfter - res.tickBefore : res.tickBefore - res.tickAfter;
        if (moved > f.maxZapTickMove()) revert ZapMovesPrice();

        // Priced on the pre zap basket: the depositor absorbs their own swap impact.
        shares = _minShares(res.used0, res.used1, r0, r1, supply);
        if (shares == 0 || shares < minShares) revert MinShares();
        _mint(to, shares);
        emit Deposit(msg.sender, to, res.used0, res.used1, shares);
    }

    // ------------------------------------------------------------------ redeem

    /// @notice Burn shares, receive both legs pro rata (net of the 10 bps retention).
    function redeem(uint256 shares, uint256 min0, uint256 min1, address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (to == address(0)) revert ZeroAddress();
        _compound();
        (amount0, amount1) = _redeemToSelf(shares);
        if (amount0 < min0 || amount1 < min1) revert MinOut();
        if (amount0 > 0) _key.currency0.transfer(to, amount0);
        if (amount1 > 0) _key.currency1.transfer(to, amount1);
        emit Redeem(msg.sender, to, amount0, amount1, shares);
    }

    /// @notice Burn shares and receive a single leg: the other leg is swapped through the pool.
    function redeemZap(uint256 shares, address tokenOut, uint256 minOut, address to)
        external
        nonReentrant
        returns (uint256 out)
    {
        if (to == address(0)) revert ZeroAddress();
        bool wantZero;
        if (tokenOut == token0()) wantZero = true;
        else if (tokenOut == token1()) wantZero = false;
        else revert BadToken();
        _compound();
        (uint256 amount0, uint256 amount1) = _redeemToSelf(shares);
        uint256 swapIn = wantZero ? amount1 : amount0;
        uint256 swapOut;
        if (swapIn > 0) {
            // Swap the unwanted leg; nothing is added back (swapAmount only, no idle to deploy
            // beyond dust because the redeemed legs are tracked explicitly below).
            swapOut = _swapOnly(!wantZero, swapIn);
        }
        out = (wantZero ? amount0 : amount1) + swapOut;
        if (out < minOut) revert MinOut();
        (wantZero ? _key.currency0 : _key.currency1).transfer(to, out);
        emit Redeem(msg.sender, to, amount0, amount1, shares);
    }

    function _redeemToSelf(uint256 shares) internal returns (uint256 amount0, uint256 amount1) {
        uint256 supply = totalSupply;
        if (shares == 0 || supply == 0) revert MinShares();
        uint256 idle0 = _idle(_key.currency0);
        uint256 idle1 = _idle(_key.currency1);
        _burn(msg.sender, shares);
        uint256 payout = (shares * (BPS - RETENTION_BPS)) / BPS;
        uint128 liq = positionLiquidity();
        uint128 liqOut = uint128(FullMath.mulDiv(liq, payout, supply));
        if (liqOut > 0) {
            bytes memory r = _unlock(Op.Remove, abi.encode(liqOut));
            (amount0, amount1) = abi.decode(r, (uint256, uint256));
        }
        amount0 += FullMath.mulDiv(idle0, payout, supply);
        amount1 += FullMath.mulDiv(idle1, payout, supply);
    }

    // ------------------------------------------------------------------ compound

    /// @notice Collect pool fees, carve the protocol share, redeploy idle into the position.
    ///         Permissionless; also runs on every deposit and redeem.
    function compound() external nonReentrant returns (uint256 fees0, uint256 fees1) {
        return _compound();
    }

    function _compound() internal returns (uint256 fees0, uint256 fees1) {
        uint128 liq = positionLiquidity();
        if (liq > 0) {
            bytes memory r = _unlock(Op.Collect, "");
            (fees0, fees1) = abi.decode(r, (uint256, uint256));
        }
        uint256 protocol0;
        uint256 protocol1;
        if (fees0 > 0 || fees1 > 0) {
            IPairTokenFactoryView f = IPairTokenFactoryView(factory);
            address fm = f.feeManager();
            uint16 feeBps = f.protocolFeeBps();
            if (fm != address(0) && feeBps > 0) {
                protocol0 = _carve(fm, _key.currency0, (fees0 * feeBps) / BPS);
                protocol1 = _carve(fm, _key.currency1, (fees1 * feeBps) / BPS);
            }
        }

        uint128 added;
        uint256 idle0 = _idle(_key.currency0);
        uint256 idle1 = _idle(_key.currency1);
        if (idle0 > DUST || idle1 > DUST) {
            (bool zeroForOne, uint256 swapAmount) = _ratioSwap(idle0, idle1);
            DeployResult memory res = _deploy(zeroForOne, swapAmount);
            added = res.liquidityAdded;
        }
        if (fees0 > 0 || fees1 > 0 || added > 0) emit Compounded(fees0, fees1, protocol0, protocol1, added);
    }

    /// @dev Pays the protocol slice to the fee manager. Best effort: a failing fee manager
    ///      leaves the slice idle for the holders and never blocks a user action.
    function _carve(address fm, Currency currency, uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        address token = Currency.unwrap(currency);
        if (currency.isAddressZero()) {
            try IPairTokenFeeManager(fm).notify{value: amount}(token, amount, poolId) {
                return amount;
            } catch {
                return 0;
            }
        }
        if (!_tryApprove(token, fm, amount)) return 0;
        try IPairTokenFeeManager(fm).notify(token, amount, poolId) {
            return amount;
        } catch {
            _tryApprove(token, fm, 0);
            return 0;
        }
    }

    /// @dev Size the ratio swap that lets both idle legs enter the full range position.
    ///      Capped at a quarter of `maxZapBps` of the pool reserve; a swap that would need
    ///      to be larger is simply clipped (never reverts).
    function _ratioSwap(uint256 idle0, uint256 idle1) internal view returns (bool zeroForOne, uint256 swapAmount) {
        (uint160 sqrtP,,,) = poolManager.getSlot0(poolId);
        uint160 sqrtL = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtU = TickMath.getSqrtPriceAtTick(tickUpper);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(sqrtP, sqrtL, sqrtU, idle0, idle1);
        uint256 need0 = liq == 0 ? 0 : SqrtPriceMath.getAmount0Delta(sqrtP, sqrtU, liq, true);
        uint256 need1 = liq == 0 ? 0 : SqrtPriceMath.getAmount1Delta(sqrtL, sqrtP, liq, true);
        uint256 left0 = idle0 > need0 ? idle0 - need0 : 0;
        uint256 left1 = idle1 > need1 ? idle1 - need1 : 0;
        // Value both leftovers in token1 terms to pick the heavier side.
        uint256 left0In1 = FullMath.mulDiv(FullMath.mulDiv(left0, sqrtP, 1 << 96), sqrtP, 1 << 96);
        if (left0In1 >= left1) {
            if (left0 <= DUST) return (true, 0);
            zeroForOne = true;
            swapAmount = left0 / 2;
        } else {
            if (left1 <= DUST) return (false, 0);
            zeroForOne = false;
            swapAmount = left1 / 2;
        }
        uint256 poolLiq = poolManager.getLiquidity(poolId);
        if (poolLiq == 0) return (zeroForOne, 0);
        uint256 reserve = zeroForOne
            ? SqrtPriceMath.getAmount0Delta(sqrtP, sqrtU, uint128(poolLiq), false)
            : SqrtPriceMath.getAmount1Delta(sqrtL, sqrtP, uint128(poolLiq), false);
        uint256 cap = (reserve * IPairTokenFactoryView(factory).maxZapBps()) / BPS / 4;
        if (swapAmount > cap) swapAmount = cap;
    }

    // ------------------------------------------------------------------ share math

    function _quoteShares(uint256 amount0, uint256 amount1, uint256 r0, uint256 r1, uint256 supply)
        internal
        pure
        returns (uint256 shares, uint256 used0, uint256 used1)
    {
        if (supply == 0 || (r0 == 0 && r1 == 0)) {
            shares = PriceMath.sqrt(amount0 * amount1);
            if (supply == 0 && shares <= DEAD_SHARES) revert BadGenesis();
            return (shares, amount0, amount1);
        }
        if (r0 == 0) return (FullMath.mulDiv(amount1, supply, r1), 0, amount1);
        if (r1 == 0) return (FullMath.mulDiv(amount0, supply, r0), amount0, 0);
        uint256 s0 = FullMath.mulDiv(amount0, supply, r0);
        uint256 s1 = FullMath.mulDiv(amount1, supply, r1);
        shares = s0 < s1 ? s0 : s1;
        used0 = FullMath.mulDivRoundingUp(shares, r0, supply);
        used1 = FullMath.mulDivRoundingUp(shares, r1, supply);
        if (used0 > amount0) used0 = amount0;
        if (used1 > amount1) used1 = amount1;
    }

    function _minShares(uint256 used0, uint256 used1, uint256 r0, uint256 r1, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        uint256 s0 = FullMath.mulDiv(used0, supply, r0);
        uint256 s1 = FullMath.mulDiv(used1, supply, r1);
        return s0 < s1 ? s0 : s1;
    }

    // ------------------------------------------------------------------ pool plumbing

    function _deploy(bool zeroForOne, uint256 swapAmount) internal returns (DeployResult memory res) {
        bytes memory r = _unlock(Op.Deploy, abi.encode(DeployData({zeroForOne: zeroForOne, swapAmount: swapAmount})));
        res = abi.decode(r, (DeployResult));
    }

    function _swapOnly(bool zeroForOne, uint256 amountIn) internal returns (uint256 out) {
        _skipAdd = true;
        bytes memory r = _unlock(Op.Deploy, abi.encode(DeployData({zeroForOne: zeroForOne, swapAmount: amountIn})));
        _skipAdd = false;
        DeployResult memory res = abi.decode(r, (DeployResult));
        out = res.swapOut;
    }

    function _unlock(Op op, bytes memory data) internal returns (bytes memory) {
        return poolManager.unlock(abi.encode(op, data));
    }

    function unlockCallback(bytes calldata rawData) external onlyPoolManager returns (bytes memory) {
        (Op op, bytes memory data) = abi.decode(rawData, (Op, bytes));
        if (op == Op.Add) {
            uint128 liq = abi.decode(data, (uint128));
            (uint256 used0, uint256 used1,) = _modify(int256(uint256(liq)));
            return abi.encode(used0, used1);
        }
        if (op == Op.Remove) {
            uint128 liq = abi.decode(data, (uint128));
            (,, BalanceDelta delta) = _modify(-int256(uint256(liq)));
            return abi.encode(uint256(uint128(delta.amount0())), uint256(uint128(delta.amount1())));
        }
        if (op == Op.Collect) {
            (,, BalanceDelta delta) = _modify(0);
            return abi.encode(uint256(uint128(delta.amount0())), uint256(uint128(delta.amount1())));
        }
        if (op == Op.Deploy) {
            DeployData memory d = abi.decode(data, (DeployData));
            return abi.encode(_deployInLock(d));
        }
        revert NotPoolManager();
    }

    /// @dev Runs inside the lock: optional exact input swap, then add every idle wei that
    ///      fits the full range at the post swap price. Redeem zaps pass swap only (the
    ///      redeemed legs are not idle at that point, so nothing is re-added except dust).
    function _deployInLock(DeployData memory d) internal returns (DeployResult memory res) {
        (uint160 sqrtP, int24 tickBefore,,) = poolManager.getSlot0(poolId);
        res.tickBefore = tickBefore;
        res.tickAfter = tickBefore;
        if (d.swapAmount > 0) {
            BalanceDelta sd = poolManager.swap(
                _key,
                IPoolManager.SwapParams({
                    zeroForOne: d.zeroForOne,
                    amountSpecified: -int256(d.swapAmount),
                    sqrtPriceLimitX96: d.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                ""
            );
            int128 outDelta = d.zeroForOne ? sd.amount1() : sd.amount0();
            res.swapOut = outDelta > 0 ? uint256(uint128(outDelta)) : 0;
            _resolve(_key.currency0, sd.amount0());
            _resolve(_key.currency1, sd.amount1());
            (sqrtP, res.tickAfter,,) = poolManager.getSlot0(poolId);
        }
        // Redeem zaps hold the redeemed legs as balance at this point; they are paid out,
        // never re-added (`_swapOnly` raises the flag for the duration of the lock).
        if (_skipAdd) return res;
        uint256 idle0 = _idle(_key.currency0);
        uint256 idle1 = _idle(_key.currency1);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), idle0, idle1
        );
        if (liq > 0) {
            (res.used0, res.used1,) = _modify(int256(uint256(liq)));
            res.liquidityAdded = liq;
        }
    }

    function _modify(int256 liquidityDelta) internal returns (uint256 owed0, uint256 owed1, BalanceDelta callerDelta) {
        BalanceDelta fees;
        (callerDelta, fees) = poolManager.modifyLiquidity(
            _key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: liquidityDelta, salt: bytes32(0)
            }),
            ""
        );
        _resolve(_key.currency0, callerDelta.amount0());
        _resolve(_key.currency1, callerDelta.amount1());
        // Amount the position consumed, net of fees that were credited in the same call.
        int256 net0 = int256(fees.amount0()) - int256(callerDelta.amount0());
        int256 net1 = int256(fees.amount1()) - int256(callerDelta.amount1());
        owed0 = net0 > 0 ? uint256(net0) : 0;
        owed1 = net1 > 0 ? uint256(net1) : 0;
    }

    function _resolve(Currency currency, int128 delta) internal returns (uint256 amount) {
        if (delta < 0) {
            amount = uint256(uint128(-delta));
            if (currency.isAddressZero()) {
                poolManager.settle{value: amount}();
            } else {
                poolManager.sync(currency);
                _safeTransfer(Currency.unwrap(currency), address(poolManager), amount);
                poolManager.settle();
            }
        } else if (delta > 0) {
            amount = uint256(uint128(delta));
            poolManager.take(currency, address(this), amount);
        }
    }

    // ------------------------------------------------------------------ token helpers

    function _idle(Currency currency) internal view returns (uint256 bal) {
        bal = currency.balanceOfSelf();
        if (currency.isAddressZero()) bal -= _reservedNative;
    }

    function _checkNative(uint256 amount0) internal view {
        if (_key.currency0.isAddressZero()) {
            if (msg.value != amount0) revert NativeMismatch();
        } else if (msg.value != 0) {
            revert NativeMismatch();
        }
    }

    /// @dev Pulls `amount` of an ERC-20 leg from the caller (balance measured, so fee on
    ///      transfer tokens deposit what actually arrived). Native legs are already here.
    function _pull(Currency currency, uint256 amount) internal returns (uint256 received) {
        if (amount == 0) return 0;
        if (currency.isAddressZero()) return amount;
        address token = Currency.unwrap(currency);
        uint256 before = currency.balanceOfSelf();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        received = currency.balanceOfSelf() - before;
    }

    function _refundNative() internal {
        uint256 refund = _reservedNative;
        _reservedNative = 0;
        if (refund == 0) return;
        (bool ok,) = msg.sender.call{value: refund}("");
        if (!ok) revert TransferFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _tryApprove(address token, address spender, uint256 amount) internal returns (bool) {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, spender, amount));
        return ok && (data.length == 0 || abi.decode(data, (bool)));
    }
}

