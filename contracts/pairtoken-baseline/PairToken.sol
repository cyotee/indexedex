// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PairTokenMath} from "./PairTokenMath.sol";
import {
    PoolKey,
    ModifyLiquidityParams,
    SwapParams,
    IPoolManager,
    IPairTokenFactory,
    IPairTokenFeeManager
} from "./interfaces/IPairTokenDependencies.sol";

interface IPairTokenCurrency {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Standalone baseline specified by pairtoken-unified-prd-r2.
contract PairToken {
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
    error WrappedError(address target, bytes4 selector, bytes reason, bytes details);
    error NativeTransferFailed();
    error ERC20TransferFailed();
    error InvalidTick(int24 tick);
    error InvalidPrice();
    error SafeCastOverflow();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 shares);
    event Redeem(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 shares);
    event Compounded(uint256 fees0, uint256 fees1, uint256 protocol0, uint256 protocol1, uint128 liquidityAdded);

    uint8 public constant decimals = 18;
    uint256 public constant BPS = 10000;
    uint256 public constant DEAD_SHARES = 1000;
    uint256 public constant RETENTION_BPS = 10;
    uint256 public constant DUST = 1000;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant Q96 = 1 << 96;
    uint160 private constant MIN_SWAP_PRICE = 4295128740;
    uint160 private constant MAX_SWAP_PRICE = 1461446703485210103287273052203988822378723970341;
    bytes4 private constant TRANSFER = 0xa9059cbb;
    bytes4 private constant TRANSFER_FROM = 0x23b872dd;
    bytes4 private constant APPROVE = 0x095ea7b3;

    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public initialized;
    address public factory;
    IPoolManager public poolManager;
    bytes32 public poolId;
    int24 public tickLower;
    int24 public tickUpper;

    PoolKey private _key;
    uint256 private _nativeReservation;
    bool private _entered;
    bool private _skipAdd;

    enum Operation {
        None,
        Add,
        Remove,
        Collect,
        Deploy
    }

    struct Quote {
        uint256 shares;
        uint256 amount0;
        uint256 amount1;
    }

    struct DeployResult {
        uint256 used0;
        uint256 used1;
        uint256 swapOut;
        int24 tickBefore;
        int24 tickAfter;
        uint128 liquidityAdded;
    }

    struct EntryState {
        uint256 reserve0;
        uint256 reserve1;
        uint256 supply;
    }

    struct RatioState {
        uint160 price;
        uint160 lower;
        uint160 upper;
        uint256 leftover0;
        uint256 leftover1;
    }

    modifier guarded() {
        if (_entered) revert Reentrancy();
        _entered = true;
        _;
        _entered = false;
    }

    receive() external payable {}

    function initialize(IPoolManager manager, PoolKey calldata key, string calldata name_, string calldata symbol_)
        external
    {
        if (initialized) revert AlreadyInitialized();
        if (address(manager) == address(0)) revert ZeroAddress();
        factory = msg.sender;
        poolManager = manager;
        _key = key;
        poolId = keccak256(abi.encode(key));
        tickLower = (int24(-887272) / key.tickSpacing) * key.tickSpacing;
        tickUpper = (int24(887272) / key.tickSpacing) * key.tickSpacing;
        name = name_;
        symbol = symbol_;
        initialized = true;
    }

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
        uint256 approved = allowance[from][msg.sender];
        if (approved != type(uint256).max) allowance[from][msg.sender] = approved - amount;
        _transfer(from, to, amount);
        return true;
    }

    function poolKey() external view returns (PoolKey memory) {
        return _key;
    }

    function token0() public view returns (address) {
        return _key.currency0;
    }

    function token1() public view returns (address) {
        return _key.currency1;
    }

    function positionLiquidity() public view returns (uint128) {
        bytes32 positionKey = keccak256(abi.encodePacked(address(this), tickLower, tickUpper, bytes32(0)));
        bytes32 slot = keccak256(abi.encode(positionKey, bytes32(uint256(_poolSlot()) + 6)));
        return uint128(uint256(poolManager.extsload(slot)));
    }

    function basket() public view returns (uint256 reserve0, uint256 reserve1) {
        (uint160 price,) = _slot0();
        uint128 liquidity = positionLiquidity();
        if (liquidity > 0) {
            reserve0 = PairTokenMath.A0down(price, PairTokenMath.T(tickUpper), liquidity) + _idle(token0());
            reserve1 = PairTokenMath.A1down(PairTokenMath.T(tickLower), price, liquidity) + _idle(token1());
        } else {
            reserve0 = _idle(token0());
            reserve1 = _idle(token1());
        }
    }

    function previewDeposit(uint256 amount0, uint256 amount1)
        public
        view
        returns (uint256 shares, uint256 used0, uint256 used1)
    {
        (uint256 reserve0, uint256 reserve1) = basket();
        Quote memory q = _quote(amount0, amount1, reserve0, reserve1, totalSupply);
        return (q.shares, q.amount0, q.amount1);
    }

    function previewRedeem(uint256 shares) external view returns (uint256 amount0, uint256 amount1) {
        uint256 supply = totalSupply;
        if (supply == 0 || shares == 0) return (0, 0);
        (uint256 reserve0, uint256 reserve1) = basket();
        uint256 payout = shares * (BPS - RETENTION_BPS) / BPS;
        return (PairTokenMath.MD(reserve0, payout, supply), PairTokenMath.MD(reserve1, payout, supply));
    }

    function deposit(uint256 amount0, uint256 amount1, uint256 minShares, address to)
        external
        payable
        guarded
        returns (uint256 shares)
    {
        if (to == address(0)) revert ZeroAddress();
        if (msg.value != (token0() == address(0) ? amount0 : 0)) revert NativeMismatch();
        _nativeReservation = msg.value;
        _compound();
        (uint256 reserve0, uint256 reserve1) = basket();
        uint256 supply = totalSupply;
        Quote memory q = _quote(amount0, amount1, reserve0, reserve1, supply);
        if (q.shares == 0 || q.shares < minShares) revert MinShares();
        q.amount0 = _pull(token0(), q.amount0);
        q.amount1 = _pull(token1(), q.amount1);
        _nativeReservation = token0() == address(0) ? msg.value - q.amount0 : 0;
        uint128 addition = _pairedAddition();
        shares = q.shares;
        if (supply == 0) {
            if (addition == 0) revert BadGenesis();
            _mint(DEAD, DEAD_SHARES);
            shares -= DEAD_SHARES;
        }
        _mint(to, shares);
        uint256 refund = _nativeReservation;
        _nativeReservation = 0;
        if (refund > 0) {
            (bool success,) = msg.sender.call{value: refund}("");
            if (!success) revert TransferFailed();
        }
        emit Deposit(msg.sender, to, q.amount0, q.amount1, shares);
    }

    function zapDeposit(address tokenIn, uint256 amountIn, uint256 minShares, address to)
        external
        payable
        guarded
        returns (uint256 shares)
    {
        if (to == address(0)) revert ZeroAddress();
        bool zeroForOne = _selectToken(tokenIn);
        if (msg.value != (zeroForOne && token0() == address(0) ? amountIn : 0)) revert NativeMismatch();
        _nativeReservation = msg.value;
        _compound();
        EntryState memory state;
        (state.reserve0, state.reserve1) = basket();
        state.supply = totalSupply;
        if (state.supply == 0 || state.reserve0 == 0 || state.reserve1 == 0) revert BadGenesis();
        if (
            amountIn == 0
                || amountIn
                    > (zeroForOne ? state.reserve0 : state.reserve1)
                        * IPairTokenFactory(factory).maxZapBps() / BPS
        ) revert ZapTooLarge();
        uint256 received = _pull(tokenIn, amountIn);
        _nativeReservation = 0;
        DeployResult memory result = _requestDeploy(zeroForOne, received / 2);
        int24 movement = result.tickAfter - result.tickBefore;
        if (movement < 0) movement = -movement;
        if (movement > IPairTokenFactory(factory).maxZapTickMove()) revert ZapMovesPrice();
        shares = _min(
            PairTokenMath.MD(result.used0, state.supply, state.reserve0),
            PairTokenMath.MD(result.used1, state.supply, state.reserve1)
        );
        if (shares == 0 || shares < minShares) revert MinShares();
        _mint(to, shares);
        emit Deposit(msg.sender, to, result.used0, result.used1, shares);
    }

    function redeem(uint256 shares, uint256 min0, uint256 min1, address to)
        external
        guarded
        returns (uint256 amount0, uint256 amount1)
    {
        if (to == address(0)) revert ZeroAddress();
        (amount0, amount1) = _redeem(shares);
        if (amount0 < min0 || amount1 < min1) revert MinOut();
        if (amount0 > 0) _pay(token0(), to, amount0);
        if (amount1 > 0) _pay(token1(), to, amount1);
        emit Redeem(msg.sender, to, amount0, amount1, shares);
    }

    function redeemZap(uint256 shares, address tokenOut, uint256 minOut, address to)
        external
        guarded
        returns (uint256 out)
    {
        if (to == address(0)) revert ZeroAddress();
        bool output0 = _selectToken(tokenOut);
        (uint256 amount0, uint256 amount1) = _redeem(shares);
        uint256 unwanted = output0 ? amount1 : amount0;
        uint256 swapOut = 0;
        if (unwanted > 0) {
            _skipAdd = true;
            DeployResult memory result = _requestDeploy(!output0, unwanted);
            _skipAdd = false;
            swapOut = result.swapOut;
        }
        out = (output0 ? amount0 : amount1) + swapOut;
        if (out < minOut) revert MinOut();
        _pay(tokenOut, to, out);
        emit Redeem(msg.sender, to, amount0, amount1, shares);
    }

    function compound() external guarded returns (uint256 fees0, uint256 fees1) {
        return _compound();
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (Operation operation, bytes memory payload) = abi.decode(rawData, (Operation, bytes));
        if (operation == Operation.Add) {
            (uint256 used0, uint256 used1) = _add(abi.decode(payload, (uint128)));
            return abi.encode(used0, used1);
        }
        if (operation == Operation.Remove || operation == Operation.Collect) {
            int256 change = operation == Operation.Collect ? int256(0) : -int256(uint256(abi.decode(payload, (uint128))));
            (int256 callerDelta,) = _modify(change);
            return abi.encode(
                PairTokenMath.U128(_delta0(callerDelta)), PairTokenMath.U128(_delta1(callerDelta))
            );
        }
        if (operation == Operation.Deploy) {
            (bool zeroForOne, uint256 swapAmount) = abi.decode(payload, (bool, uint256));
            return abi.encode(_deploy(zeroForOne, swapAmount));
        }
        revert NotPoolManager();
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (to == address(0)) revert ZeroAddress();
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) private {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) private {
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _poolSlot() private view returns (bytes32) {
        return keccak256(abi.encode(poolId, bytes32(uint256(6))));
    }

    function _slot0() private view returns (uint160 price, int24 tick) {
        uint256 word = uint256(poolManager.extsload(_poolSlot()));
        price = uint160(word);
        tick = int24(uint24(word >> 160));
    }

    function _idle(address currency) private view returns (uint256) {
        if (currency == address(0)) return address(this).balance - _nativeReservation;
        return IPairTokenCurrency(currency).balanceOf(address(this));
    }

    function _quote(uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1, uint256 supply)
        private
        pure
        returns (Quote memory q)
    {
        if (supply == 0 || (reserve0 == 0 && reserve1 == 0)) {
            q.shares = PairTokenMath.sqrt(amount0 * amount1);
            if (supply == 0 && q.shares <= DEAD_SHARES) revert BadGenesis();
            q.amount0 = amount0;
            q.amount1 = amount1;
        } else if (reserve0 == 0) {
            q.shares = PairTokenMath.MD(amount1, supply, reserve1);
            q.amount1 = amount1;
        } else if (reserve1 == 0) {
            q.shares = PairTokenMath.MD(amount0, supply, reserve0);
            q.amount0 = amount0;
        } else {
            q.shares = _min(PairTokenMath.MD(amount0, supply, reserve0), PairTokenMath.MD(amount1, supply, reserve1));
            q.amount0 = _min(amount0, PairTokenMath.MU(q.shares, reserve0, supply));
            q.amount1 = _min(amount1, PairTokenMath.MU(q.shares, reserve1, supply));
        }
    }

    function _pairedAddition() private returns (uint128 addition) {
        uint256 idle0 = _idle(token0());
        uint256 idle1 = _idle(token1());
        (uint160 price,) = _slot0();
        addition = PairTokenMath.Fit(price, PairTokenMath.T(tickLower), PairTokenMath.T(tickUpper), idle0, idle1);
        if (addition > 0) poolManager.unlock(abi.encode(Operation.Add, abi.encode(addition)));
    }

    function _redeem(uint256 shares) private returns (uint256 amount0, uint256 amount1) {
        _compound();
        uint256 supply = totalSupply;
        if (shares == 0 || supply == 0) revert MinShares();
        uint256 idle0 = _idle(token0());
        uint256 idle1 = _idle(token1());
        _burn(msg.sender, shares);
        uint256 payout = shares * (BPS - RETENTION_BPS) / BPS;
        uint128 removal = uint128(PairTokenMath.MD(positionLiquidity(), payout, supply));
        if (removal > 0) {
            (amount0, amount1) = abi.decode(
                poolManager.unlock(abi.encode(Operation.Remove, abi.encode(removal))), (uint256, uint256)
            );
        }
        amount0 += PairTokenMath.MD(idle0, payout, supply);
        amount1 += PairTokenMath.MD(idle1, payout, supply);
    }

    function _compound() private returns (uint256 fees0, uint256 fees1) {
        if (positionLiquidity() > 0) {
            (fees0, fees1) = abi.decode(
                poolManager.unlock(abi.encode(Operation.Collect, bytes(""))), (uint256, uint256)
            );
        }
        uint256 protocol0 = 0;
        uint256 protocol1 = 0;
        if (fees0 > 0 || fees1 > 0) {
            address feeManager = IPairTokenFactory(factory).feeManager();
            uint16 feeBps = IPairTokenFactory(factory).protocolFeeBps();
            if (feeManager != address(0) && feeBps != 0) {
                protocol0 = _routeProtocol(token0(), feeManager, fees0 * feeBps / BPS);
                protocol1 = _routeProtocol(token1(), feeManager, fees1 * feeBps / BPS);
            }
        }
        uint256 idle0 = _idle(token0());
        uint256 idle1 = _idle(token1());
        uint128 addition = 0;
        if (idle0 > DUST || idle1 > DUST) {
            (bool zeroForOne, uint256 swapAmount) = _ratioSwap(idle0, idle1);
            DeployResult memory result = _requestDeploy(zeroForOne, swapAmount);
            addition = result.liquidityAdded;
        }
        if (fees0 > 0 || fees1 > 0 || addition > 0) {
            emit Compounded(fees0, fees1, protocol0, protocol1, addition);
        }
    }

    function _routeProtocol(address currency, address feeManager, uint256 amount) private returns (uint256) {
        if (amount == 0) return 0;
        if (currency == address(0)) {
            try IPairTokenFeeManager(feeManager).notify{value: amount}(currency, amount, poolId) {
                return amount;
            } catch {
                return 0;
            }
        }
        if (!_approveCurrency(currency, feeManager, amount)) return 0;
        try IPairTokenFeeManager(feeManager).notify(currency, amount, poolId) {
            return amount;
        } catch {
            _approveCurrency(currency, feeManager, 0);
            return 0;
        }
    }

    function _ratioSwap(uint256 idle0, uint256 idle1) private view returns (bool zeroForOne, uint256 amount) {
        RatioState memory state;
        (state.price,) = _slot0();
        state.lower = PairTokenMath.T(tickLower);
        state.upper = PairTokenMath.T(tickUpper);
        uint128 fit = PairTokenMath.Fit(state.price, state.lower, state.upper, idle0, idle1);
        uint256 need0 = 0;
        uint256 need1 = 0;
        if (fit > 0) {
            need0 = PairTokenMath.A0up(state.price, state.upper, fit);
            need1 = PairTokenMath.A1up(state.lower, state.price, fit);
        }
        state.leftover0 = idle0 > need0 ? idle0 - need0 : 0;
        state.leftover1 = idle1 > need1 ? idle1 - need1 : 0;
        uint256 value0 = PairTokenMath.MD(PairTokenMath.MD(state.leftover0, state.price, Q96), state.price, Q96);
        zeroForOne = value0 >= state.leftover1;
        uint256 leftover = zeroForOne ? state.leftover0 : state.leftover1;
        if (leftover <= DUST) return (zeroForOne, 0);
        amount = leftover / 2;
        uint128 activeLiquidity = uint128(uint256(poolManager.extsload(bytes32(uint256(_poolSlot()) + 3))));
        if (activeLiquidity == 0) return (zeroForOne, 0);
        uint256 reserve = zeroForOne
            ? PairTokenMath.A0down(state.price, state.upper, activeLiquidity)
            : PairTokenMath.A1down(state.lower, state.price, activeLiquidity);
        uint256 cap = reserve * IPairTokenFactory(factory).maxZapBps() / BPS / 4;
        amount = _min(amount, cap);
    }

    function _requestDeploy(bool zeroForOne, uint256 swapAmount) private returns (DeployResult memory) {
        return abi.decode(
            poolManager.unlock(abi.encode(Operation.Deploy, abi.encode(zeroForOne, swapAmount))), (DeployResult)
        );
    }

    function _deploy(bool zeroForOne, uint256 swapAmount) private returns (DeployResult memory result) {
        uint160 price;
        (price, result.tickBefore) = _slot0();
        result.tickAfter = result.tickBefore;
        if (swapAmount > 0) {
            int256 delta = poolManager.swap(
                _key,
                SwapParams(zeroForOne, -int256(swapAmount), zeroForOne ? MIN_SWAP_PRICE : MAX_SWAP_PRICE),
                bytes("")
            );
            int128 output = zeroForOne ? _delta1(delta) : _delta0(delta);
            if (output > 0) result.swapOut = uint256(uint128(output));
            _resolve(token0(), _delta0(delta));
            _resolve(token1(), _delta1(delta));
            (price, result.tickAfter) = _slot0();
        }
        if (_skipAdd) return result;
        uint256 idle0 = _idle(token0());
        uint256 idle1 = _idle(token1());
        result.liquidityAdded =
            PairTokenMath.Fit(price, PairTokenMath.T(tickLower), PairTokenMath.T(tickUpper), idle0, idle1);
        if (result.liquidityAdded > 0) {
            (result.used0, result.used1) = _add(result.liquidityAdded);
        }
    }

    function _modify(int256 change) private returns (int256 callerDelta, int256 feesAccrued) {
        (callerDelta, feesAccrued) = poolManager.modifyLiquidity(
            _key, ModifyLiquidityParams(tickLower, tickUpper, change, bytes32(0)), bytes("")
        );
        _resolve(token0(), _delta0(callerDelta));
        _resolve(token1(), _delta1(callerDelta));
    }

    function _add(uint128 liquidity) private returns (uint256 used0, uint256 used1) {
        (int256 callerDelta, int256 feesAccrued) = _modify(int256(uint256(liquidity)));
        int256 difference0 = int256(_delta0(feesAccrued)) - int256(_delta0(callerDelta));
        int256 difference1 = int256(_delta1(feesAccrued)) - int256(_delta1(callerDelta));
        if (difference0 > 0) used0 = uint256(difference0);
        if (difference1 > 0) used1 = uint256(difference1);
    }

    function _delta0(int256 delta) private pure returns (int128) {
        return int128(delta >> 128);
    }

    function _delta1(int256 delta) private pure returns (int128) {
        return int128(delta);
    }

    function _resolve(address currency, int128 delta) private {
        if (delta < 0) {
            // Negate before widening: int128 minimum must retain its overflow panic.
            uint256 amount = uint256(uint128(-delta));
            if (currency == address(0)) {
                poolManager.settle{value: amount}();
            } else {
                poolManager.sync(currency);
                _transferCurrency(currency, address(poolManager), amount);
                poolManager.settle();
            }
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint256(uint128(delta)));
        }
    }

    function _pull(address currency, uint256 amount) private returns (uint256) {
        if (amount == 0) return 0;
        if (currency == address(0)) return amount;
        uint256 beforeBalance = IPairTokenCurrency(currency).balanceOf(address(this));
        (bool success, bytes memory result) =
            currency.call(abi.encodeWithSelector(TRANSFER_FROM, msg.sender, address(this), amount));
        if (!success || (result.length != 0 && !abi.decode(result, (bool)))) revert TransferFailed();
        return IPairTokenCurrency(currency).balanceOf(address(this)) - beforeBalance;
    }

    function _transferCurrency(address currency, address to, uint256 amount) private {
        (bool success, bytes memory result) = currency.call(abi.encodeWithSelector(TRANSFER, to, amount));
        if (!success || (result.length != 0 && !abi.decode(result, (bool)))) revert TransferFailed();
    }

    function _approveCurrency(address currency, address spender, uint256 amount) private returns (bool) {
        (bool success, bytes memory result) = currency.call(abi.encodeWithSelector(APPROVE, spender, amount));
        return success && (result.length == 0 || abi.decode(result, (bool)));
    }

    function _pay(address currency, address to, uint256 amount) private {
        bool success;
        bytes memory result;
        if (currency == address(0)) {
            (success, result) = to.call{value: amount}("");
            if (!success) {
                revert WrappedError(to, bytes4(0), result, abi.encodePacked(NativeTransferFailed.selector));
            }
        } else {
            (success, result) = currency.call(abi.encodeWithSelector(TRANSFER, to, amount));
            bool accepted = result.length == 0;
            if (result.length >= 32) {
                uint256 firstWord;
                assembly ("memory-safe") {
                    firstWord := mload(add(result, 32))
                }
                accepted = firstWord == 1;
            }
            if (!success || !accepted) {
                revert WrappedError(currency, TRANSFER, result, abi.encodePacked(ERC20TransferFailed.selector));
            }
        }
    }

    function _selectToken(address currency) private view returns (bool is0) {
        if (currency == token0()) return true;
        if (currency == token1()) return false;
        revert BadToken();
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
