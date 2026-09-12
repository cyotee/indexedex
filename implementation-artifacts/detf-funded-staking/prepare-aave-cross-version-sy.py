"""Prepare the native SY adapter in the main checkout after the active Forge run exits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
output = artifacts / 'aave-cross-version-sy-sources.json'
assert not output.exists(), 'Already applied; preserve source provenance.'
directory = Path('contracts/protocols/lending/aave/cross-version')
staged = {}

def read(name):
    return (root / directory / name).read_text()

def stage(name, source):
    staged[directory / name] = source

base = read('AaveCrossVersionLoopExchangeBase.sol')
base = base.replace('import {IERC20} from', '''import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC20} from''', 1)
base = base.replace('abstract contract AaveCrossVersionLoopExchangeBase {', '''abstract contract AaveCrossVersionLoopExchangeBase is ReentrancyLockModifiers, IStandardExchangeErrors {
    using SafeERC20 for IERC20;

    error ZeroLoopAmount();
    error InvalidLoopReceiver();
    error EmptyLoopNAV();''', 1)
index = base.rfind('\n}')
base = base[:index] + '''
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
''' + base[index:]
stage('AaveCrossVersionLoopExchangeBase.sol', base)

stage('AaveCrossVersionLoopExchangeInTarget.sol', '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "./CrossVersionLoopService.sol";

/// @notice Canonical tokenA deposit and share redemption at the vault's retained live NAV.
contract AaveCrossVersionLoopExchangeInTarget is AaveCrossVersionLoopExchangeBase, IStandardExchangeIn {
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external view returns (uint256 amountOut)
    {
        ReentrancyLockRepo._onlyUnlocked();
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) == address(this) && tokenOut == m.tokenA) return _amountForShares(m, amountIn);
        if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
        uint256 supply_ = ERC20Repo._totalSupply();
        amountOut = CrossVersionLoopService.sharesForDeposit(CrossVersionLoopExecutor.navUsd(m), supply_,
            CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn));
        if (supply_ == 0) amountOut = amountOut > MINIMUM_LIQUIDITY ? amountOut - MINIMUM_LIQUIDITY : 0;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut,
        address recipient, bool pretransferred, uint256 deadline)
        external nonReentrant returns (uint256 amountOut)
    {
        _requireExchange(deadline, amountIn, recipient);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) == address(this) && tokenOut == m.tokenA) {
            amountOut = _amountForShares(m, amountIn);
            if (amountOut == 0) revert ZeroLoopAmount();
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            _burnWithdrawalShares(amountIn, pretransferred);
            _withdrawAndPay(m, amountOut, recipient);
            return amountOut;
        }
        if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
        if (pretransferred) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, 0);
        return _depositInput(m, amountIn, minAmountOut, recipient);
    }

    function _depositInput(CrossVersionLoopExecutor.Market memory m, uint256 amountIn,
        uint256 minAmountOut, address recipient) private returns (uint256 amountOut)
    {
        IERC20 tokenIn = m.tokenA;
        uint256 nav_ = CrossVersionLoopExecutor.navUsd(m);
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 before_ = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 received_ = tokenIn.balanceOf(address(this)) - before_;
        if (received_ < amountIn) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, received_);
        amountOut = CrossVersionLoopService.sharesForDeposit(nav_, supply_,
            CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn));
        if (supply_ == 0) {
            if (amountOut <= MINIMUM_LIQUIDITY) revert ZeroLoopAmount();
            amountOut -= MINIMUM_LIQUIDITY;
            ERC20Repo._mint(address(1), MINIMUM_LIQUIDITY);
        }
        if (amountOut == 0) revert ZeroLoopAmount();
        if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
        CrossVersionLoopExecutor.depositLoopAFirst(m, amountIn, _loopConfig());
        ERC20Repo._mint(recipient, amountOut);
    }
}
''')

stage('AaveCrossVersionLoopExchangeOutTarget.sol', '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {LoopPositionRepo} from "./LoopPositionRepo.sol";

/// @notice Exact-output withdrawals and native SY reuse the canonical funded standard routes.
contract AaveCrossVersionLoopExchangeOutTarget is
    AaveCrossVersionLoopExchangeBase, IStandardExchangeOut, NativeStandardYieldTarget
{
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn)
    {
        ReentrancyLockRepo._onlyUnlocked();
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        _requireFreeable(m, amountOut);
        return _sharesForAmountOut(m, amountOut);
    }

    function exchangeOut(IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut,
        address recipient, bool pretransferred, uint256 deadline)
        external nonReentrant returns (uint256 amountIn)
    {
        _requireExchange(deadline, amountOut, recipient);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        _requireFreeable(m, amountOut);
        amountIn = _sharesForAmountOut(m, amountOut);
        if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);
        _burnWithdrawalShares(amountIn, pretransferred);
        _withdrawAndPay(m, amountOut, recipient);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(LoopPositionRepo._tokenA());
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }

    /// @dev The existing native position accounting unit is USD at oracle-base precision 8.
    /// The vault identifies that composite position; it is not an ERC20 accounting-asset address.
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 8);
    }

    function exchangeRate() external view override returns (uint256) {
        ReentrancyLockRepo._onlyUnlocked();
        uint256 supply_ = ERC20Repo._totalSupply();
        return supply_ == 0 ? 1e18 : Math.mulDiv(CrossVersionLoopExecutor.navUsd(_market()), 1e18, supply_);
    }
}
''')

facet = read('AaveCrossVersionLoopExchangeOutFacet.sol')
facet = facet.replace('import {IFacet}', '''import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet}''', 1)
facet = facet.replace('interfaces = new bytes4[](1);', 'interfaces = new bytes4[](2);', 1)
facet = facet.replace('interfaces[0] = type(IStandardExchangeOut).interfaceId;',
    'interfaces[0] = type(IStandardExchangeOut).interfaceId;\n        interfaces[1] = type(IStandardizedYield).interfaceId;', 1)
facet = facet.replace('funcs[1] = IStandardExchangeOut.exchangeOut.selector;',
    'funcs[1] = IStandardExchangeOut.exchangeOut.selector;\n        funcs = NativeStandardYieldSelectors._append(funcs);', 1)
stage('AaveCrossVersionLoopExchangeOutFacet.sol', facet)

pkg = read('AaveCrossVersionLoopDFPkg.sol')
pkg = pkg.replace('import {IFacet}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IFacet}', 1)
pkg = pkg.replace('interfaces = new bytes4[](3);', 'interfaces = new bytes4[](4);', 1)
pkg = pkg.replace('interfaces[2] = type(IAaveCrossVersionLoopVault).interfaceId;',
    'interfaces[2] = type(IAaveCrossVersionLoopVault).interfaceId;\n        interfaces[3] = type(IStandardizedYield).interfaceId;', 1)
stage('AaveCrossVersionLoopDFPkg.sol', pkg)

rebalance = read('AaveCrossVersionLoopRebalanceTarget.sol')
rebalance = rebalance.replace('import {IERC20} from', 'import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";\nimport {IERC20} from', 1)
rebalance = rebalance.replace('function previewNetCarry() external view returns (int256) {',
    'function previewNetCarry() external view returns (int256) {\n        ReentrancyLockRepo._onlyUnlocked();', 1)
rebalance = rebalance.replace('function rebalance() external {', 'function rebalance() external nonReentrant {', 1)
rebalance = rebalance.replace('function forceRepay() external {', 'function forceRepay() external nonReentrant {', 1)
stage('AaveCrossVersionLoopRebalanceTarget.sol', rebalance)

rows = []
for path, source in staged.items():
    before = (root / path).read_text()
    rows.append({'source': str(path), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(source.encode()).hexdigest()})
for path, source in staged.items():
    (root / path).write_text(source)
output.write_text(json.dumps({'status': 'applied; tests and build validation pending', 'rows': rows,
    'preserved': '18-decimal shares, actual V3/V4 NAV, A-first issuance, V3 freeable collateral limit, no withdrawal borrowing, existing fee behavior.',
    'new': 'Canonical exact-input share redemption, native SY, shared exchange/rebalance lock, positive exact-output share rounding and actual withdrawal funding checks.'}, indent=2) + '\n')
print('Applied native cross-version SY and canonical redemption; validation pending.')
