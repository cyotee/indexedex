// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookMath.sol";

/**
 * @title UniswapV4OrbitalSwapHookCommon
 * @notice Immutables, reserves, fee oracle reads, take/settle, reentrancy, LP helpers.
 */
abstract contract UniswapV4OrbitalSwapHookCommon {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error SameToken();
    error NotPoolManager();
    error DeadlineExpired();
    error InsufficientSharesOut();
    error InsufficientTokenOut();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    error Reentrancy();
    error NotLive();
    error InvalidRoute();
    error FullBookRequiresThreeLegs();
    error ReservesExceedRadius();
    error InvalidPermit2Data();
    error FirstMintRequiresTwoLegs();

    event LiquidityAdded(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeWad
    );
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);

    IPoolManager internal immutable _poolManager;
    IVaultFeeOracleQuery internal immutable _feeOracle;
    address internal immutable _token0;
    address internal immutable _token1;
    address internal immutable _token2;

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address token0_,
        address token1_,
        address token2_
    ) {
        _poolManager = poolManager_;
        _feeOracle = feeOracle_;
        _token0 = token0_;
        _token1 = token1_;
        _token2 = token2_;
    }

    /* ---------------------------------------------------------------------- */
    /*                                   views                                */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view virtual returns (IPoolManager) {
        return _poolManager;
    }

    function feeOracle() public view virtual returns (IVaultFeeOracleQuery) {
        return _feeOracle;
    }

    function token0() public view virtual returns (address) {
        return _token0;
    }

    function token1() public view virtual returns (address) {
        return _token1;
    }

    function token2() public view virtual returns (address) {
        return _token2;
    }

    function radius() public view virtual returns (uint256) {
        return Repo._layout().R;
    }

    function lSquared() public view virtual returns (uint256) {
        return Repo._layout().L_SQUARED;
    }

    function reserveOf(address token) public view virtual returns (uint256) {
        return Repo._layout().reserves[token];
    }

    function dexSwapFee() public view virtual returns (uint256) {
        return _feeOracle.dexSwapFeeOfVault(address(this));
    }

    function usageFee() public view virtual returns (uint256) {
        return _feeOracle.usageFeeOfVault(address(this));
    }

    function feeTo() public view virtual returns (address) {
        return address(_feeOracle.feeTo());
    }

    function kLast() public view virtual returns (uint256) {
        return Repo._layout().kLast;
    }

    function kLastMode() public view virtual returns (IUniswapV4OrbitalSwapHook.KLastMode) {
        return IUniswapV4OrbitalSwapHook.KLastMode(Repo._layout().kLastMode);
    }

    function permit2() public pure virtual returns (address) {
        return PERMIT2;
    }

    /* ---------------------------------------------------------------------- */
    /*                              token helpers                             */
    /* ---------------------------------------------------------------------- */

    function _isBound(address token) internal view returns (bool) {
        return token == _token0 || token == _token1 || token == _token2;
    }

    function _decimalsOf(address token) internal view returns (uint8) {
        Repo.Layout storage l = Repo._layout();
        if (token == _token0) return l.decimals0;
        if (token == _token1) return l.decimals1;
        if (token == _token2) return l.decimals2;
        revert InvalidPoolToken();
    }

    function _toWad(address token, uint256 amount) internal view returns (uint256) {
        return Math.toWad(amount, _decimalsOf(token));
    }

    function _fromWadFloor(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadFloor(amountWad, _decimalsOf(token));
    }

    function _fromWadCeil(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadCeil(amountWad, _decimalsOf(token));
    }

    function _readDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _reserveWad(address token) internal view returns (uint256) {
        return _toWad(token, Repo._layout().reserves[token]);
    }

    function _reservesWad()
        internal
        view
        returns (uint256 r0, uint256 r1, uint256 r2)
    {
        r0 = _reserveWad(_token0);
        r1 = _reserveWad(_token1);
        r2 = _reserveWad(_token2);
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != address(_poolManager)) revert NotPoolManager();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    /* ---------------------------------------------------------------------- */
    /*                           fee-on / growth measure                      */
    /* ---------------------------------------------------------------------- */

    function _feeOnAndShare()
        internal
        view
        returns (bool feeOn, address feeTo_, uint256 ownerFeeShare, uint256 usageFeeWad)
    {
        feeTo_ = address(_feeOracle.feeTo());
        usageFeeWad = _feeOracle.usageFeeOfVault(address(this));
        ownerFeeShare = (usageFeeWad * Repo.FEE_DENOMINATOR) / Math.WAD;
        feeOn = feeTo_ != address(0) && usageFeeWad != 0 && usageFeeWad < Math.WAD
            && ownerFeeShare != 0;
    }

    /// @dev Returns (mode, k, rootK). mode 0 FullProduct, 1 SumInterim.
    function _measureK(uint256 r0, uint256 r1, uint256 r2)
        internal
        pure
        returns (uint8 mode, uint256 k, uint256 rootK)
    {
        if (r0 > 0 && r1 > 0 && r2 > 0) {
            mode = 0;
            k = r0 * r1 * r2;
            rootK = Math.cbrt(k);
        } else {
            mode = 1;
            k = r0 + r1 + r2;
            rootK = k;
        }
    }

    function _rootFromStored(uint8 mode, uint256 kStored) internal pure returns (uint256) {
        if (kStored == 0) return 0;
        if (mode == 0) return Math.cbrt(kStored);
        return kStored;
    }

    /* ---------------------------------------------------------------------- */
    /*                              take / settle                             */
    /* ---------------------------------------------------------------------- */

    function _take(Currency currency, address to, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.take(currency, to, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(_poolManager), amount);
        _poolManager.settle();
    }

    /* ---------------------------------------------------------------------- */
    /*                              reentrancy                                */
    /* ---------------------------------------------------------------------- */

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    function _lock() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
    }

    function _unlock() internal {
        Repo._layout().reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* ---------------------------------------------------------------------- */
    /*                              ERC-20 mint/burn                          */
    /* ---------------------------------------------------------------------- */

    function _mint(address to, uint256 amount) internal virtual {
        Repo.Layout storage l = Repo._layout();
        l.totalSupply += amount;
        l.balanceOf[to] += amount;
        _emitTransfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        Repo.Layout storage l = Repo._layout();
        l.balanceOf[from] -= amount;
        l.totalSupply -= amount;
        _emitTransfer(from, address(0), amount);
    }

    function _emitTransfer(address from, address to, uint256 amount) internal virtual;

    // Transfer events emitted via IERC20 inheritance on wire

    function _recomputeL2() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) {
            l.L_SQUARED = 0;
            return;
        }
        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        l.L_SQUARED = Math.recomputeL2(l.R, r0, r1, r2);
    }

    function _requirePostUnderRadius() internal view {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) return;
        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        if (r0 >= l.R || r1 >= l.R || r2 >= l.R) revert ReservesExceedRadius();
    }

    function _witnessAndLegs(address tokenIn, address tokenOut)
        internal
        view
        returns (address tokenZ)
    {
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) revert InvalidRoute();
        if (tokenIn != _token0 && tokenOut != _token0) return _token0;
        if (tokenIn != _token1 && tokenOut != _token1) return _token1;
        return _token2;
    }

    function _buildLpMetadata()
        internal
        view
        returns (string memory name_, string memory symbol_)
    {
        string memory s0 = _symbolOrFragment(_token0);
        string memory s1 = _symbolOrFragment(_token1);
        string memory s2 = _symbolOrFragment(_token2);
        name_ = string.concat("Orbital ", s0, "-", s1, "-", s2);
        symbol_ = string.concat("ORB-", s0, "-", s1, "-", s2);
    }

    function _symbolOrFragment(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            if (bytes(s).length > 0) return s;
        } catch {}
        return _addressFragment(token);
    }

    function _addressFragment(address token) internal pure returns (string memory) {
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory b = new bytes(6);
        uint160 v = uint160(token);
        for (uint256 i = 0; i < 6; i++) {
            b[5 - i] = hexSymbols[v & 0xf];
            v >>= 4;
        }
        return string(b);
    }
}
