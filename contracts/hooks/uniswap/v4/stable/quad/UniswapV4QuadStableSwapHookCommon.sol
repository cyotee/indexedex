// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {
    UniswapV4QuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookRepo.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";

/**
 * @title UniswapV4QuadStableSwapHookCommon
 * @notice Immutables, rates (fail-closed), pull/push, take/settle, LP metadata helpers.
 * @dev No BaseHook / DeltaResolver inheritance — pattern-copy settle only.
 */
abstract contract UniswapV4QuadStableSwapHookCommon {
    using SafeERC20 for IERC20;

    error InvalidTokenOrder();
    error InvalidToken();
    error InvalidFee();
    error InvalidAmp();
    error ZeroAmount();
    error Slippage();
    error NotZapEligible();
    error SwapNotLive();
    error InvariantFailed();
    error RateProviderFailed();
    error InvalidRoute();
    error InvalidPoolKey();
    error LiquidityNotAllowed();
    error DonateNotAllowed();
    error HookNotImplemented();
    error NotPoolManager();
    error Reentrancy();
    error ZeroAddress();
    error TransferFailed();

    IPoolManager internal immutable _poolManager;
    address internal immutable _token0;
    address internal immutable _token1;
    address internal immutable _token2;
    address internal immutable _token3;
    uint24 internal immutable _lpFeePips;
    uint256 internal immutable _baseAmp;
    address internal immutable _rateProvider0;
    address internal immutable _rateProvider1;
    address internal immutable _rateProvider2;
    address internal immutable _rateProvider3;
    uint8 internal immutable _decimals0;
    uint8 internal immutable _decimals1;
    uint8 internal immutable _decimals2;
    uint8 internal immutable _decimals3;
    uint256 internal immutable _baseScale0;
    uint256 internal immutable _baseScale1;
    uint256 internal immutable _baseScale2;
    uint256 internal immutable _baseScale3;

    constructor(
        IPoolManager poolManager_,
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 lpFeePips_,
        uint256 baseAmp_,
        address[4] memory rateProviders_
    ) {
        if (address(poolManager_) == address(0)) revert ZeroAddress();
        if (token0_ == address(0) || token1_ == address(0) || token2_ == address(0) || token3_ == address(0)) {
            revert InvalidToken();
        }
        // native ETH forbidden (address(0) already); no other check needed
        if (!(token0_ < token1_ && token1_ < token2_ && token2_ < token3_)) {
            revert InvalidTokenOrder();
        }
        if (lpFeePips_ == 0 || lpFeePips_ >= Math.FEE_DENOMINATOR) revert InvalidFee();
        if (baseAmp_ == 0 || baseAmp_ >= Math.MAX_AMP) revert InvalidAmp();

        uint8 d0 = _readDecimalsFailClosed(token0_);
        uint8 d1 = _readDecimalsFailClosed(token1_);
        uint8 d2 = _readDecimalsFailClosed(token2_);
        uint8 d3 = _readDecimalsFailClosed(token3_);

        _poolManager = poolManager_;
        _token0 = token0_;
        _token1 = token1_;
        _token2 = token2_;
        _token3 = token3_;
        _lpFeePips = lpFeePips_;
        _baseAmp = baseAmp_;
        _rateProvider0 = rateProviders_[0];
        _rateProvider1 = rateProviders_[1];
        _rateProvider2 = rateProviders_[2];
        _rateProvider3 = rateProviders_[3];
        _decimals0 = d0;
        _decimals1 = d1;
        _decimals2 = d2;
        _decimals3 = d3;
        _baseScale0 = Math.baseScaleFromDecimals(d0);
        _baseScale1 = Math.baseScaleFromDecimals(d1);
        _baseScale2 = Math.baseScaleFromDecimals(d2);
        _baseScale3 = Math.baseScaleFromDecimals(d3);
    }

    /* ---------------------------------------------------------------------- */
    /*                              public views                              */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view returns (IPoolManager) {
        return _poolManager;
    }

    function token0() public view returns (address) {
        return _token0;
    }

    function token1() public view returns (address) {
        return _token1;
    }

    function token2() public view returns (address) {
        return _token2;
    }

    function token3() public view returns (address) {
        return _token3;
    }

    function tokens() public view returns (address[4] memory t) {
        t[0] = _token0;
        t[1] = _token1;
        t[2] = _token2;
        t[3] = _token3;
    }

    function lpFeePips() public view returns (uint24) {
        return _lpFeePips;
    }

    function baseAmp() public view returns (uint256) {
        return _baseAmp;
    }

    function getCurrentAmp() public view returns (uint256) {
        return _baseAmp * Math.AMP_PRECISION;
    }

    function rateProvider(uint256 index) public view returns (address) {
        if (index == 0) return _rateProvider0;
        if (index == 1) return _rateProvider1;
        if (index == 2) return _rateProvider2;
        if (index == 3) return _rateProvider3;
        revert InvalidRoute();
    }

    function rateProviders() public view returns (address[4] memory p) {
        p[0] = _rateProvider0;
        p[1] = _rateProvider1;
        p[2] = _rateProvider2;
        p[3] = _rateProvider3;
    }

    function reserveOf(address token) public view returns (uint256) {
        return Repo._layout().reserves[_tokenIndex(token)];
    }

    function reserves() public view returns (uint256[4] memory) {
        return Repo._layout().reserves;
    }

    /// @notice Fail-closed rate read (D74).
    function effectiveRate(uint256 index) public view returns (uint256) {
        return _effectiveRate(index);
    }

    /* ---------------------------------------------------------------------- */
    /*                              token helpers                             */
    /* ---------------------------------------------------------------------- */

    function _tokenIndex(address token) internal view returns (uint256) {
        if (token == _token0) return 0;
        if (token == _token1) return 1;
        if (token == _token2) return 2;
        if (token == _token3) return 3;
        revert InvalidRoute();
    }

    function _tokenAt(uint256 index) internal view returns (address) {
        if (index == 0) return _token0;
        if (index == 1) return _token1;
        if (index == 2) return _token2;
        if (index == 3) return _token3;
        revert InvalidRoute();
    }

    function _baseScaleAt(uint256 index) internal view returns (uint256) {
        if (index == 0) return _baseScale0;
        if (index == 1) return _baseScale1;
        if (index == 2) return _baseScale2;
        if (index == 3) return _baseScale3;
        revert InvalidRoute();
    }

    function _providerAt(uint256 index) internal view returns (address) {
        return rateProvider(index);
    }

    function _effectiveRate(uint256 index) internal view returns (uint256) {
        uint256 base = _baseScaleAt(index);
        address provider = _providerAt(index);
        uint256 oracleRate = Math.RATE_PRECISION;
        if (provider != address(0)) {
            oracleRate = _getRateFailClosed(provider);
        }
        return (base * oracleRate) / Math.RATE_PRECISION;
    }

    function _loadRates() internal view returns (uint256[4] memory rates) {
        rates[0] = _effectiveRate(0);
        rates[1] = _effectiveRate(1);
        rates[2] = _effectiveRate(2);
        rates[3] = _effectiveRate(3);
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function _readDecimalsFailClosed(address token) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) =
            token.staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (!ok || ret.length < 32) revert InvalidToken();
        uint256 raw = abi.decode(ret, (uint256));
        if (raw < 6 || raw > 18) revert InvalidToken();
        d = uint8(raw);
    }

    /// @dev Soft-fallback: last 4 hex of address (no 0x) if symbol missing/reverts.
    function _readSymbolSoft(address token) internal view returns (string memory) {
        (bool ok, bytes memory ret) =
            token.staticcall(abi.encodeWithSelector(IERC20Metadata.symbol.selector));
        if (ok && ret.length >= 64) {
            // try decode string
            string memory s = abi.decode(ret, (string));
            if (bytes(s).length > 0) return s;
        }
        return _last4Hex(token);
    }

    function _last4Hex(address token) internal pure returns (string memory) {
        bytes16 hexChars = "0123456789abcdef";
        uint160 v = uint160(token);
        bytes memory out = new bytes(4);
        out[0] = hexChars[uint8((v >> 12) & 0xf)];
        out[1] = hexChars[uint8((v >> 8) & 0xf)];
        out[2] = hexChars[uint8((v >> 4) & 0xf)];
        out[3] = hexChars[uint8(v & 0xf)];
        return string(out);
    }

    function _buildLpMetadata(address t0, address t1, address t2, address t3)
        internal
        view
        returns (string memory name_, string memory symbol_)
    {
        string memory s0 = _readSymbolSoft(t0);
        string memory s1 = _readSymbolSoft(t1);
        string memory s2 = _readSymbolSoft(t2);
        string memory s3 = _readSymbolSoft(t3);
        string memory qsBody = string.concat(s0, "-", s1, "-", s2, "-", s3);
        string memory qsFull = string.concat("QS-", qsBody);
        symbol_ = _truncateUtf8(qsFull, Math.LP_SYMBOL_MAX);
        name_ = _truncateUtf8(string.concat("Quad Stable ", qsFull), Math.LP_NAME_MAX);
    }

    function _truncateUtf8(string memory s, uint256 maxBytes) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length <= maxBytes) return s;
        // hard cut; drop incomplete trailing UTF-8 code units
        uint256 end = maxBytes;
        while (end > 0 && (uint8(b[end]) & 0xC0) == 0x80) {
            --end;
        }
        bytes memory out = new bytes(end);
        for (uint256 i; i < end; ++i) {
            out[i] = b[i];
        }
        return string(out);
    }

    /* ---------------------------------------------------------------------- */
    /*                           pull / push / settle                         */
    /* ---------------------------------------------------------------------- */

    function _onlyPoolManager() internal view {
        if (msg.sender != address(_poolManager)) revert NotPoolManager();
    }

    function _pull(address token, uint256 amount) internal {
        if (amount == 0) return;
        // Bubble original returndata (e.g. nested Reentrancy()) — SafeERC20 would wrap.
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount));
    }

    function _push(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    }

    /// @dev Like OZ callOptionalReturn but reverts with original returndata when present.
    function _callOptionalReturn(address token, bytes memory data) private {
        (bool success, bytes memory returndata) = token.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        // Optional bool return must be true when present
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "ERC20 op false");
        }
    }

    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.take(currency, recipient, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.sync(currency);
        _callOptionalReturn(
            Currency.unwrap(currency),
            abi.encodeWithSelector(IERC20.transfer.selector, address(_poolManager), amount)
        );
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

    /* ---------------------------------------------------------------------- */
    /*                            zap eligibility                             */
    /* ---------------------------------------------------------------------- */

    function _isZapEligible() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (l.totalSupply <= Math.MINIMUM_LIQUIDITY) return false;
        return l.reserves[0] > 0 && l.reserves[1] > 0 && l.reserves[2] > 0 && l.reserves[3] > 0;
    }

    function _requireZapEligible() internal view {
        if (!_isZapEligible()) revert NotZapEligible();
    }
}
