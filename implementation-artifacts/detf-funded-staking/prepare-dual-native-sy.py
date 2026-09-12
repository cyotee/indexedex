"""Add native SY over Dual's installed liquidity routes after the active build exits."""
from pathlib import Path
import hashlib,json
base=Path('contracts/hooks/uniswap/v4/standardExchange/dual');changes=[]
def save(p,s):
 old=p.read_text();p.write_text(s);changes.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
p=base/'UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol';s=p.read_text().replace('import {IERC20}', '''import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20}''',1).replace('is UniswapV4DualStandardExchangeBufferConstantProductHookCommon {','is UniswapV4DualStandardExchangeBufferConstantProductHookCommon, NativeStandardYieldTarget {',1)
s=s.replace('''        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactIn(zfo, amountIn);''','''        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewIn(tokenIn, amountIn, tokenOut);
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactIn(zfo, amountIn);''',1)
s=s.replace('''        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactOut(zfo, amountOut);''','''        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.previewOut(tokenIn, tokenOut, amountOut);
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactOut(zfo, amountOut);''',1)
for name,returns,params,args,call in (
('exchangeIn','amountOut','IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline','tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline','exchangeIn'),
('exchangeOut','amountIn','IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline','tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline','exchangeOut')):
 a=s.index('    function '+name+'(');b=s.index('{',a);signature=s[a:b];s=s[:a]+f'''    function {name}({params}) external returns (uint256 {returns}) {{
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.{call}({args});
        return _swap{name[0].upper()+name[1:]}({args});
    }}

'''+signature.replace('function '+name+'(', 'function _swap'+name[0].upper()+name[1:]+'(').replace('external nonReentrant','internal nonReentrant')+s[b:]
mark='    function previewExchangeIn('
methods='''    function getTokensIn() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l = Repo._layout();
        tokens_ = new address[](4);
        tokens_[0] = l.token0;
        tokens_[1] = l.token1;
        tokens_[2] = l.se0;
        tokens_[3] = l.se1;
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _supplyAfterProtocolMint();
        return supply_ == 0 ? 1e18 : FullMath.mulDiv(Math.sqrt(_wadProduct()), 1e18, supply_);
    }

''';s=s.replace(mark,methods+mark,1);save(p,s)
p=base/'facets/UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.sol';s=p.read_text().replace('import {IFacet}', '''import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet}''',1).replace('interfaces = new bytes4[](2);','interfaces = new bytes4[](3);').replace('interfaces[1] = type(IStandardExchangeOut).interfaceId;','interfaces[1] = type(IStandardExchangeOut).interfaceId;\n        interfaces[2] = type(IStandardizedYield).interfaceId;').replace('funcs[5] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;','funcs[5] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;\n        funcs = NativeStandardYieldSelectors._append(funcs);');save(p,s)
p=base/'UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol';s=p.read_text().replace('import {IERC20}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IERC20}',1).replace('interfaces = new bytes4[](11);','interfaces = new bytes4[](12);').replace('interfaces[10] = type(IDetfReserveQuote).interfaceId;','interfaces[10] = type(IDetfReserveQuote).interfaceId;\n        interfaces[11] = type(IStandardizedYield).interfaceId;');save(p,s)
Path('implementation-artifacts/detf-funded-staking/dual-native-sy-sources.json').write_text(json.dumps(changes,indent=2)+'\n')
