// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {AaveV36PoolAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV36PoolAwareRepo.sol";
import {AaveV4SpokeAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV4SpokeAwareRepo.sol";
import {LoopPositionRepo} from "contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";

/**
 * @title AaveCrossVersionLoopExchangeBase
 * @author cyotee doge <doge.cyotee>
 * @notice Shared storage wiring + market builder for the cross-version loop exchange facets (In/Out).
 *         Both facets operate on the same diamond storage (AwareRepos, LoopPositionRepo, ERC20 share).
 */
abstract contract AaveCrossVersionLoopExchangeBase is ReentrancyLockModifiers, IStandardExchangeErrors {
    using SafeERC20 for IERC20;

    error ZeroLoopAmount();
    error InvalidLoopReceiver();
    error EmptyLoopNAV();
    uint256 internal constant MINIMUM_LIQUIDITY = 1000; // permanent first-deposit lock (decision 21)

    struct InitArgs {
        IPool v36Pool;
        IPoolAddressesProvider v36AddressesProvider;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IAaveOracleV4 v4Oracle;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 v4AssetIdA;
        uint256 v4ReserveIdA;
        uint256 v4AssetIdB;
        uint256 v4ReserveIdB;
        string shareName;
        string shareSymbol;
    }

    /// @dev Initializes the vault's AwareRepos, pair, and share token. In production this is invoked
    ///      from the Package `initAccount`; exposed here for standalone wiring/tests.
    function initCrossVersionLoop(InitArgs memory a) public {
        AaveV36PoolAwareRepo._initialize(a.v36Pool, a.v36AddressesProvider, a.v36Oracle);
        AaveV4SpokeAwareRepo._initialize(a.v4Spoke, a.v4Hub, a.v4Oracle);
        AaveV4SpokeAwareRepo._setTokenIds(address(a.tokenA), a.v4AssetIdA, a.v4ReserveIdA);
        AaveV4SpokeAwareRepo._setTokenIds(address(a.tokenB), a.v4AssetIdB, a.v4ReserveIdB);
        LoopPositionRepo._initialize(a.tokenA, a.tokenB);
        ERC20Repo._initialize(a.shareName, a.shareSymbol, 18);
    }

    function _market() internal view returns (CrossVersionLoopExecutor.Market memory) {
        IERC20 tokenA = LoopPositionRepo._tokenA();
        IERC20 tokenB = LoopPositionRepo._tokenB();
        return CrossVersionLoopExecutor.Market({
            v36Pool: AaveV36PoolAwareRepo._pool(),
            v36Oracle: AaveV36PoolAwareRepo._oracle(),
            v4Spoke: AaveV4SpokeAwareRepo._spoke(),
            v4Hub: AaveV4SpokeAwareRepo._hub(),
            tokenA: tokenA,
            tokenB: tokenB,
            v4ReserveIdA: AaveV4SpokeAwareRepo._reserveIdOf(address(tokenA)),
            v4ReserveIdB: AaveV4SpokeAwareRepo._reserveIdOf(address(tokenB))
        });
    }

    function _loopConfig() internal pure returns (CrossVersionLoopExecutor.LoopConfig memory) {
        return CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10});
    }
    function _requireExchange(uint256 deadline_, uint256 amount_, address receiver_) internal view {
        if (deadline_ < block.timestamp) revert DeadlineExceeded(deadline_, block.timestamp);
        if (amount_ == 0) revert ZeroLoopAmount();
        if (receiver_ == address(0)) revert InvalidLoopReceiver();
    }

    function _requireFreeable(CrossVersionLoopExecutor.Market memory m_, uint256 amount_) internal view {
        uint256 freeable_ = CrossVersionLoopExecutor.maxWithdrawableA(m_);
        if (amount_ > freeable_) revert AmountOutNotMet(amount_, freeable_);
    }

    /// @dev Exact-input redemption keeps the existing NAV and its two conservative conversion floors.
    function _amountForShares(CrossVersionLoopExecutor.Market memory m_, uint256 shares_)
        internal view returns (uint256 amount_)
    {
        if (shares_ == 0) return 0;
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) revert EmptyLoopNAV();
        uint256 value_ = Math.mulDiv(shares_, CrossVersionLoopExecutor.navUsd(m_), supply_);
        amount_ = Math.mulDiv(value_, 10 ** IERC20Metadata(address(m_.tokenA)).decimals(),
            m_.v36Oracle.getAssetPrice(address(m_.tokenA)));
        _requireFreeable(m_, amount_);
    }

    /// @dev Round both exact-output conversions upward. A positive sub-oracle-unit payment must
    /// consume shares; flooring its USD value used to permit a positive withdrawal for zero shares.
    function _sharesForAmountOut(CrossVersionLoopExecutor.Market memory m_, uint256 amount_)
        internal view returns (uint256 shares_)
    {
        if (amount_ == 0) return 0;
        uint256 nav_ = CrossVersionLoopExecutor.navUsd(m_);
        uint256 supply_ = ERC20Repo._totalSupply();
        if (nav_ == 0 || supply_ == 0) revert EmptyLoopNAV();
        uint256 value_ = Math.mulDiv(amount_, m_.v36Oracle.getAssetPrice(address(m_.tokenA)),
            10 ** IERC20Metadata(address(m_.tokenA)).decimals(), Math.Rounding.Ceil);
        shares_ = Math.mulDiv(value_, supply_, nav_, Math.Rounding.Ceil);
    }

    /// @dev Public pretransfer credit is unavailable. Native SY internal-balance redemption calls
    /// as the diamond and burns only the requested quantity from its actual self-share balance.
    function _burnWithdrawalShares(uint256 shares_, bool prepaid_) internal {
        if (shares_ == 0) revert ZeroLoopAmount();
        if (prepaid_) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, 0);
        ERC20Repo._burn(msg.sender, shares_);
    }

    function _withdrawAndPay(CrossVersionLoopExecutor.Market memory m_, uint256 amount_, address receiver_) internal {
        uint256 before_ = m_.tokenA.balanceOf(address(this));
        uint256 withdrawn_ = CrossVersionLoopExecutor.withdrawA(m_, amount_);
        uint256 received_ = m_.tokenA.balanceOf(address(this)) - before_;
        if (withdrawn_ != amount_ || received_ != amount_) revert AmountOutNotMet(amount_, received_);
        m_.tokenA.safeTransfer(receiver_, amount_);
    }

}
