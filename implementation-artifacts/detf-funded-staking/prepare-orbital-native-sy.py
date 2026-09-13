"""Apply Orbital native SY and its actual single-asset exit after the current build exits."""
from pathlib import Path
import hashlib,json
base=Path('contracts/hooks/uniswap/v4/standardExchange/orbital');changes=[]
def save(p,s):
 old=p.read_text() if p.exists() else ''
 p.write_text(s)
 changes.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
def replace(s,a,b):
 assert s.count(a)==1,(a,s.count(a))
 return s.replace(a,b)
p=base/'UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol';s=p.read_text()
s=replace(s,'import {IERC20}', '''import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20}''')
s=replace(s,'is UniswapV4StandardExchangeOrbitalBufferHookCommon {','is UniswapV4StandardExchangeOrbitalBufferHookCommon, NativeStandardYieldTarget {')
s=replace(s,'        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);','        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewIn(tokenIn, amountIn, tokenOut);\n        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);')
s=replace(s,'        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);','        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewOut(tokenIn, tokenOut, amountOut);\n        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);')
for name,returns,params,args in (
('exchangeIn','amountOut','IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline','tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline'),
('exchangeOut','amountIn','IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline','tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline')):
 a=s.index('    function '+name+'(');b=s.index('{',a);signature=s[a:b]
 s=s[:a]+f'''    function {name}({params}) external returns (uint256 {returns}) {{
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.{name}({args});
        return _swap{name[0].upper()+name[1:]}({args});
    }}

'''+signature.replace('function '+name+'(', 'function _swap'+name[0].upper()+name[1:]+'(').replace('external nonReentrant','internal nonReentrant')+s[b:]
s=replace(s,'    function previewExchangeIn(','''    function getTokensIn() public view override returns (address[] memory tokens) {
        Repo.Layout storage l = Repo._layout();
        uint256 count = 3;
        for (uint8 i; i < 3; ++i) if (Repo._seAt(l, i) != address(0)) ++count;
        tokens = new address[](count);
        count = 3;
        for (uint8 i; i < 3; ++i) {
            tokens[i] = Repo._tokenAt(l, i);
            address se = Repo._seAt(l, i);
            if (se != address(0)) tokens[count++] = se;
        }
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        (, uint256 supply) = _previewProtocolMintShares();
        if (supply == 0) return 1e18;
        (uint256 x, uint256 y, uint256 z) = _effectiveWad();
        (,, uint256 root) = _measureK(x, y, z);
        return FullMath.mulDiv(root, 1e18, supply);
    }

    function previewExchangeIn(''');save(p,s)
p=base/'facets/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol';s=p.read_text()
s=replace(s,'import {IFacet}', '''import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet}''')
s=replace(s,'interfaces = new bytes4[](2);','interfaces = new bytes4[](3);')
s=replace(s,'interfaces[1] = type(IStandardExchangeOut).interfaceId;','interfaces[1] = type(IStandardExchangeOut).interfaceId;\n        interfaces[2] = type(IStandardizedYield).interfaceId;')
s=replace(s,'funcs[5] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;','funcs[5] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;\n        funcs = NativeStandardYieldSelectors._append(funcs);');save(p,s)
p=base/'UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol';s=p.read_text()
s=replace(s,'import {IERC20}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IERC20}')
s=replace(s,'interfaces = new bytes4[](12);','interfaces = new bytes4[](13);')
s=replace(s,'interfaces[11] = type(IDetfReserveQuote).interfaceId;','interfaces[11] = type(IDetfReserveQuote).interfaceId;\n        interfaces[12] = type(IStandardizedYield).interfaceId;');save(p,s)
p=base/'UniswapV4StandardExchangeOrbitalBufferHookCommon.sol';s=p.read_text()
s=replace(s,'''        uint256 got = IStandardExchangeOut(se).exchangeOut(''','''        uint256 beforeOut = IERC20(token).balanceOf(address(this));
        IStandardExchangeOut(se).exchangeOut(''')
s=replace(s,'''        if (got < amountOut) revert InsufficientTokenOut();''','''        if (IERC20(token).balanceOf(address(this)) - beforeOut < amountOut) revert InsufficientTokenOut();''')
a=s.index('    function _removeLiquidity(');b=s.index('        _requireDeadline(deadline);',a)
s=s[:b]+'''        return _removeLiquidityAndSettle(shares, to, a0Min, a1Min, a2Min, deadline, true);
    }

    function _removeLiquidityAndSettle(uint256 shares, address to, uint256 a0Min, uint256 a1Min,
        uint256 a2Min, uint256 deadline, bool refundFree)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
'''+s[b:]
s=replace(s,'_burnAndPay(shares, to, a0, a1, a2);','_burnAndPay(shares, to, a0, a1, a2, refundFree);')
s=replace(s,'function _burnAndPay(uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2)','function _burnAndPay(uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2, bool refundFree)')
a=s.index('    function _burnAndPay(');b=s.index('    function _depositFlexible(',a)
part=s[a:b];part=replace(part,'        _refundConservation(msg.sender);','        if (refundFree) _refundConservation(msg.sender);');s=s[:a]+part+s[b:];save(p,s)
p=base/'UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget.sol';s=p.read_text()
s=replace(s,'import {IERC20}', '''import {UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib as ExitQuoteLib} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol";
import {IERC20}''')
s=replace(s,'''        sharesIn;
        to;
        amountOutMin;
        deadline;
        revert InvalidRoute(tokenOut, address(0));''','''        amountOut = _exitSingleAsset(tokenOut, sharesIn, to, deadline);
        if (amountOut < amountOutMin) revert InsufficientTokenOut();''')
s=replace(s,'''    function previewExitSingleAssetExactBptIn(address, uint256) external view returns (uint256) {
        return 0;
    }''','''    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 shares) external view returns (uint256) {
        if (!_isLive() || _resolveBurnTokenOut(tokenOut) == address(0)) return 0;
        (, uint256 supply) = _previewProtocolMintShares();
        return ExitQuoteLib.preview(shares, supply, tokenOut);
    }

    function _exitSingleAsset(address tokenOut, uint256 shares, address to, uint256 deadline)
        private returns (uint256 amountOut)
    {
        address pair = _resolveBurnTokenOut(tokenOut);
        if (pair == address(0)) revert InvalidRoute(tokenOut, address(0));
        if (to == address(0)) revert ZeroAddress();
        uint256 freeBefore = _freeTokenBalance(pair);
        uint256[3] memory amounts;
        (amounts[0], amounts[1], amounts[2]) = _removeLiquidityAndSettle(
            shares, address(this), 0, 0, 0, deadline, false
        );
        for (uint8 i; i < 3; ++i) {
            address input = Repo._tokenAt(Repo._layout(), i);
            if (input == pair || amounts[i] == 0) continue;
            _swapExitResidual(input, pair, amounts[i]);
        }
        amountOut = _freeTokenBalance(pair) - freeBefore;
        if (tokenOut != pair && amountOut > 0) amountOut = _bufferToken(pair, amountOut);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncVaultReserves();
    }

    function _swapExitResidual(address tokenIn, address tokenOut, uint256 amountIn) private {
        uint256 quoted = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        if (_seOf(tokenOut) != address(0)) _unwrapExactTokenOut(tokenOut, quoted);
        else Repo._layout().reserves[tokenOut] -= quoted;
        _bufferToken(tokenIn, amountIn);
        _recomputeL2();
    }''')
s=replace(s,'/// @dev H10: prop exit of `lpAmount`, convert non-tokenOut legs via swap quotes (no exitSingleAsset*).','/// @dev Retained reserve quote delegates to the same sequential standard single-asset exit quote.')
a=s.index('        if (lpAmount == 0',s.index('    function previewBurnToToken('));b=s.index('    function _resolveBurnTokenOut(',a)
s=s[:a]+'''        if (!_isLive() || _resolveBurnTokenOut(tokenOut) == address(0)) return 0;
        (, uint256 supply) = _previewProtocolMintShares();
        return ExitQuoteLib.preview(lpAmount, supply, tokenOut);
    }

'''+s[b:]
a=s.index('    function _tryPreviewSwap(');s=s[:a]+'}\n';save(p,s)
p=base/'UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol'
s=Path('implementation-artifacts/detf-funded-staking/orbital-single-exit.sol.pending').read_text();save(p,s)
Path('implementation-artifacts/detf-funded-staking/orbital-native-sy-sources.json').write_text(json.dumps(changes,indent=2)+'\n')
