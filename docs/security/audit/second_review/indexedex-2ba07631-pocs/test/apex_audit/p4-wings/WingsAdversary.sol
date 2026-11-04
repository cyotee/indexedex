// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

interface IJitObserver {
    function onJit(uint8 stage) external;
}

/// @notice Unprivileged adversary. Holds its own capital (fully counted), never holds vault shares in the
///         quarantined harness. Every op is a real PoolManager unlock settled in the same call.
contract WingsAdversary is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;
    using StateLibrary for IPoolManager;

    IPoolManager public immutable manager;
    address public immutable controller;
    PoolKey internal key;
    bytes32 public constant JIT_SALT = bytes32(uint256(0xA11CE));
    bytes32 public constant PERSIST_SALT = bytes32(uint256(0xB0B0));

    // UNSAFE (known spot-nav) op parameters
    address internal unsafeVault;
    uint256 public unsafeMinted;
    uint256 public unsafePaid;

    constructor(IPoolManager manager_, PoolKey memory key_, address controller_) {
        manager = manager_; key = key_; controller = controller_;
    }

    modifier onlyController() { require(msg.sender == controller, "adv: controller"); _; }

    function modify(int24 lower_, int24 upper_, int256 liquidity_) external onlyController {
        manager.unlock(abi.encode(uint8(0), abi.encode(lower_, upper_, liquidity_)));
    }

    function swap(bool zeroForOne_, uint256 amount_, uint160 limit_) external onlyController {
        manager.unlock(abi.encode(uint8(1), abi.encode(zeroForOne_, amount_, limit_)));
    }

    /// @notice One unlock: add JIT liquidity, observe, optional swap, observe, restore price, observe, remove, settle.
    function jitView(int24 lower_, int24 upper_, uint256 liquidity_, bool zeroForOne_, uint256 amount_, uint160 restore_)
        external onlyController
    {
        manager.unlock(abi.encode(uint8(2), abi.encode(lower_, upper_, liquidity_, zeroForOne_, amount_, restore_)));
    }

    /// @notice KNOWN finding wings-spot-nav, used ONLY by the sanity test: flash take, deposit, JIT add, redeem,
    ///         JIT remove, settle -- all inside the adversary's own unlock.
    function unsafeJitDepositRedeem(address vault_, uint256 deposit_, uint256 liquidity_) external onlyController {
        unsafeVault = vault_;
        IERC20(Currency.unwrap(key.currency0)).approve(vault_, type(uint256).max);
        IERC20(Currency.unwrap(key.currency1)).approve(vault_, type(uint256).max);
        manager.unlock(abi.encode(uint8(3), abi.encode(deposit_, liquidity_)));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager), "adv: pm");
        (uint8 op, bytes memory payload) = abi.decode(data_, (uint8, bytes));
        if (op == 0) {
            (int24 lo, int24 up, int256 l) = abi.decode(payload, (int24, int24, int256));
            manager.modifyLiquidity(key, ModifyLiquidityParams(lo, up, l, PERSIST_SALT), "");
        } else if (op == 1) {
            (bool zf, uint256 amt, uint160 lim) = abi.decode(payload, (bool, uint256, uint160));
            manager.swap(key, SwapParams(zf, -int256(amt), lim), "");
        } else if (op == 2) {
            _jit(payload);
        } else {
            _unsafe(payload);
        }
        _settle(key.currency0);
        _settle(key.currency1);
        return "";
    }

    function _jit(bytes memory payload_) private {
        (int24 lo, int24 up, uint256 l, bool zf, uint256 amt, uint160 restore) =
            abi.decode(payload_, (int24, int24, uint256, bool, uint256, uint160));
        manager.modifyLiquidity(key, ModifyLiquidityParams(lo, up, int256(l), JIT_SALT), "");
        IJitObserver(controller).onJit(0);
        if (amt != 0) {
            manager.swap(key, SwapParams(zf, -int256(amt), zf ? 4295128740 : 1461446703485210103287273052203988822378723970341), "");
            IJitObserver(controller).onJit(1);
            (uint160 p,,,) = manager.getSlot0(key.toId());
            if (p != restore) manager.swap(key, SwapParams(p > restore, -int256(uint256(1e30)), restore), "");
            IJitObserver(controller).onJit(2);
        }
        manager.modifyLiquidity(key, ModifyLiquidityParams(lo, up, -int256(l), JIT_SALT), "");
    }

    function _unsafe(bytes memory payload_) private {
        (uint256 dep, uint256 l) = abi.decode(payload_, (uint256, uint256));
        address v = unsafeVault;
        IERC20 target = IERC20(IVaultTarget(v).targetToken());
        Currency c = Currency.wrap(address(target));
        manager.take(c, address(this), dep);unsafeMinted = IStandardExchangeIn(v).exchangeIn(target, dep, IERC20(v), 0, address(this), false, block.timestamp);
        manager.modifyLiquidity(key, ModifyLiquidityParams(-887220, 887220, int256(l), JIT_SALT), "");unsafePaid = IStandardExchangeIn(v).exchangeIn(IERC20(v), unsafeMinted, target, 0, address(this), false, block.timestamp);
        manager.modifyLiquidity(key, ModifyLiquidityParams(-887220, 887220, -int256(l), JIT_SALT), "");
    }

    function _settle(Currency c_) private {
        int256 d = manager.currencyDelta(address(this), c_);
        if (d < 0) {
            manager.sync(c_);
            require(IERC20(Currency.unwrap(c_)).transfer(address(manager), uint256(-d)), "adv: pay");
            manager.settle();
        } else if (d > 0) {
            manager.take(c_, address(this), uint256(d));
        }
    }
}

interface IVaultTarget { function targetToken() external view returns (address); }

/// @notice Honest contract router: pretransfer + pushed exchangeIn atomically (the only legitimate pushed usage).
contract WingsPushRouter {
    function pushDeposit(address vault_, IERC20 token_, uint256 amount_, address recipient_) external returns (uint256) {
        require(token_.transfer(vault_, amount_), "router: transfer");return IStandardExchangeIn(vault_).exchangeIn(token_, amount_, IERC20(vault_), 0, recipient_, true, block.timestamp);
    }
}
