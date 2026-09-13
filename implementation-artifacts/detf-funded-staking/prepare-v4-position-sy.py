"""Apply approved V4 position accounting/import/SY changes after the active build exits."""
from pathlib import Path
import json, hashlib
base=Path('contracts/protocols/dexes/uniswap/v4');changes=[]
def save(p,s):
 old=p.read_text();p.write_text(s);changes.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
p=base/'UniswapV4StandardExchangeCommon.sol';s=p.read_text();old='''            if ((amount0Added == 0 && reserve0Before != 0) || (amount1Added == 0 && reserve1Before != 0)) return 0;
            return amount0Added + amount1Added;''';assert old in s;s=s.replace(old,'''            if (amount0Added == 0 || amount1Added == 0) return 0;
            return FixedPointMathLib.mulSqrt(amount0Added, amount1Added);''',1)
old='''        if (totalSharesBefore == 0) {
            return amount0Added + amount1Added;
        }

        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return ConstProdUtils._depositQuote(amount0Added, amount1Added, totalSharesBefore, reserve0, reserve1);''';assert old in s;s=s.replace(old,'''        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0, reserve1);''',1);save(p,s)
p=base/'UniswapV4StandardExchangeCommon.sol';s=p.read_text();mark='''        uint256 b0 = vaultShare.balanceOf(address(this));
        if (!pretransferred) {''';replacement='''        uint256 b0 = vaultShare.balanceOf(address(this));
        if (msg.sender == address(this) && !pretransferred) {
            if (amountIn > b0) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, b0);
            return amountIn;
        }
        if (!pretransferred) {''';assert mark in s;s=s.replace(mark,replacement,1);save(p,s)
p=base/'UniswapV4PositionRepo.sol';s=p.read_text();mark='    function _isPositionCreated(Storage storage layout_)';assert mark in s;s=s.replace(mark,'''    /// @dev The emptied import NFT remains recorded, but backing uses the managed full-range book.
    function _finishImportedConversion() internal {
        Storage storage layout_ = _layout();
        layout_.importedPositionActive = false;
        layout_.centerPosition.created = false;
        layout_.centerPosition.liquidity = 0;
    }

'''+mark,1);save(p,s)
p=base/'UniswapV4StandardExchangePositionImportTarget.sol';s=p.read_text().replace('        if (deadline < block.timestamp)', '        _requireNotDisabled();\n        if (recipient == address(0)) revert UniswapV4Exchange_ZeroAmount();\n        if (deadline < block.timestamp)',1)
a=s.index('        sharesOut = _quoteImportedPositionShares');s=s[:a]+'''        // Only the assets actually delivered by this NFT fund the importer's shares.
        // The existing sleeve is assigned its own sink shares and cannot be claimed by importing.
        (uint256 sleeve0, uint256 sleeve1) = _freeBalances();
        _collectImportedAssets(positionManager, positionTokenId, info, uint128(liquidity));
        (uint256 funded0, uint256 funded1) = _freeBalances();
        funded0 -= sleeve0;
        funded1 -= sleeve1;
        sharesOut = _sharesOutForDeposit(funded0, funded1, 0, sleeve0, sleeve1);
        if (sharesOut == 0) revert UniswapV4Exchange_ZeroAmount();
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();
        uint256 residual = _initialResidualShares(funded0, funded1, sleeve0, sleeve1, sharesOut);

        UniswapV4PositionRepo._finishImportedConversion();
        _createManagedPositionsIfNeeded(_deriveManagedTicks());
        if (residual > 0) ERC20Repo._mint(DEAD_SHARES_SINK, residual);
        ERC20Repo._mint(recipient, sharesOut);
        _rebalanceLiquidReserveBestEffort();
        _refreshStoredLiquidity();
        _syncVaultReserves();
    }

    function _collectImportedAssets(
        IPositionManager positionManager, uint256 positionTokenId, PositionInfo info, uint128 liquidity
    ) private {
        IERC721(address(positionManager)).transferFrom(msg.sender, address(this), positionTokenId);
        UniswapV4PositionRepo._initializeImportedPosition(
            positionManager, positionTokenId, info.tickLower(), info.tickUpper()
        );
        uint256 nativeBefore = address(this).balance;
        // Decrease collects principal and all earned fees in one settlement.
        _burnImportedLiquidityCommon(liquidity);
        if (_currency0().isAddressZero() || _currency1().isAddressZero()) {
            uint256 nativeReceived = address(this).balance - nativeBefore;
            if (nativeReceived != 0) _weth().deposit{value: nativeReceived}();
        }
    }
}
'''
# Currency extension directives are not inherited by Solidity targets.
s=s.replace('import {IERC20}', 'import {CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";\nimport {IERC20}',1).replace('{\n    function importPosition', '{\n    using CurrencyLibrary for *;\n\n    function importPosition',1);save(p,s)
p=base/'UniswapV4StandardExchangeInBase.sol';s=p.read_text();a=s.index('    function _quoteImportedPositionShares(');b=s.index('    function _executeDirectSwapIn(',a);s=s[:a]+s[b:];save(p,s)
p=base/'UniswapV4StandardExchangeOutQueryTarget.sol';s=p.read_text();s=s.replace('import {IERC20}', '''import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20}''',1).replace('is UniswapV4StandardExchangeOutBase {','is UniswapV4StandardExchangeOutBase, NativeStandardYieldTarget {',1)
mark='    function previewExchangeOut('
methods='''    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256)
    {
        if (address(in_) == address(this) && !internal_) {
            ERC20Repo._transfer(msg.sender, address(this), amount_);
            internal_ = true;
        }
        return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
    }

    function getTokensIn() public view override returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        // V4 pools have bytes32 identifiers. The host is a liquidity identifier, not an ERC-20.
        // The complete PoolKey remains available on the existing pool metadata surface.
        return (IStandardizedYield.AssetType.LIQUIDITY, address(_poolManager()), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 1e18;
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return Math.mulDiv(FixedPointMathLib.mulSqrt(reserve0, reserve1), 1e18, supply);
    }

''';s=s.replace(mark,methods+mark,1);save(p,s)
p=base/'UniswapV4StandardExchangeOutQueryFacet.sol';s=p.read_text().replace('import {IFacet}', '''import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet}''',1).replace('interfaces = new bytes4[](0);','interfaces = new bytes4[](1);\n        interfaces[0] = type(IStandardizedYield).interfaceId;').replace('funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;','funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;\n        funcs = NativeStandardYieldSelectors._append(funcs);');save(p,s)
p=base/'UniswapV4StandardExchangeDFPkg.sol';s=p.read_text().replace('import {IERC20}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IERC20}',1).replace('interfaces = new bytes4[](13);','interfaces = new bytes4[](14);').replace('interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;','interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[13] = type(IStandardizedYield).interfaceId;');save(p,s)
Path('implementation-artifacts/detf-funded-staking/v4-position-sy-sources.json').write_text(json.dumps(changes,indent=2)+'\n')
print('Applied V4 full-range import conversion, two-token initial CP accounting and native SY surface.')
