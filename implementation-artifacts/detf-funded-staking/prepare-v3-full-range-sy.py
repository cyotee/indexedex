"""Implement the selected full-range V3 book and expose its native SY surface."""
from pathlib import Path
import hashlib, json, re
root=Path(__file__).resolve().parents[2]; rows=[]
def edit(name, fn):
 p=root/name; old=p.read_text(); new=fn(old); assert old!=new,name
 rows.append({'path':name,'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(new.encode()).hexdigest()});p.write_text(new)
f='contracts/protocols/dexes/uniswap/v3/'
def common(s):
 old='''            if ((amount0Added == 0 && reserve0Before != 0) || (amount1Added == 0 && reserve1Before != 0)) return 0;
            return amount0Added + amount1Added;'''
 assert old in s;s=s.replace(old,'''            if (amount0Added == 0 || amount1Added == 0) return 0;
            return FixedPointMathLib.mulSqrt(amount0Added, amount1Added);''',1)
 s=s.replace('        if (!pretransferred) {\n            vaultShare.safeTransferFrom', '''        if (msg.sender == address(this)) {
            if (amountIn > b0) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, b0);
            return amountIn;
        }
        if (!pretransferred) {
            vaultShare.safeTransferFrom''',1)
 s=s.replace('/// @dev One full-range center. Import uses stored NFT ticks.','/// @dev Ordinary and imported books use the same maximum usable range.',1)
 return s
edit(f+'UniswapV3StandardExchangeCommon.sol',common)
def imports(s):
 s=s.replace('import {ERC20Repo}', 'import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";\nimport {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";\nimport {ERC20Repo}',1)
 s=s.replace('Center ticks stay the NFT range (D34).','Collected principal and fees join the canonical full-range book (D57).',1)
 s=s.replace('    error UniswapV3ExchangeImport_SlippageExceeded();','    error UniswapV3ExchangeImport_SlippageExceeded();\n    error UniswapV3ExchangeImport_UnauthorizedOwner();',1)
 s=s.replace('        _requireCanOpenBoundPoolOps();','''        _requireCanOpenBoundPoolOps();
        IERC721 nft = IERC721(address(positionManager));
        if (nft.ownerOf(positionTokenId) != owner || (msg.sender != owner && nft.getApproved(positionTokenId) != msg.sender
            && !nft.isApprovedForAll(owner, msg.sender))) revert UniswapV3ExchangeImport_UnauthorizedOwner();''',1)
 s=s.replace('positionManager, positionTokenId, owner, deadline, token0, token1, tickLower, tickUpper, liquidity','positionManager, positionTokenId, owner, deadline, token0, token1, liquidity',1)
 s=s.replace('    /// @dev Exit the NFT onto the vault, book imported ticks, mint A0 residual, return user inbound shares.','    /// @dev Exit the NFT to the sleeve, select full-range ticks, and credit only actual inbound assets.',1)
 s=s.replace('        address token1,\n        int24 tickLower,\n        int24 tickUpper,\n        uint128 liquidity','        address token1,\n        uint128 liquidity',1)
 s=s.replace('        UniswapV3VaultRepo._initializeImportedCenter(address(positionManager), positionTokenId, tickLower, tickUpper);','''        ManagedTicks memory fullRange = _deriveManagedTicks();
        UniswapV3VaultRepo._initializeImportedCenter(
            address(positionManager), positionTokenId, fullRange.centerLower, fullRange.centerUpper
        );''',1)
 # Decode the NPM into a memory struct to retain fee growth without increasing stack pressure.
 a=s.index('    function _quoteImportShares(');b=s.index('    function _requireMatchingPool',a)
 s=s[:a]+'''    struct ImportedPosition {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 lower;
        int24 upper;
        uint128 liquidity;
        uint256 growth0;
        uint256 growth1;
        uint128 owed0;
        uint128 owed1;
    }

    function _quoteImportShares(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        internal view returns (uint256 sharesOut)
    {
        (bool ok, bytes memory result) = address(positionManager).staticcall(
            abi.encodeCall(INonfungiblePositionManager.positions, (positionTokenId))
        );
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        ImportedPosition memory p = abi.decode(result, (ImportedPosition));
        if (p.liquidity == 0) revert UniswapV3ExchangeImport_ZeroLiquidity();
        _requireMatchingPool(p.token0, p.token1, p.fee);
        if (positionManager.factory() != _pool().factory()) revert UniswapV3ExchangeImport_InvalidImportedPool();
        (,, uint160 price,,) = _loadPoolState();
        (uint256 amount0, uint256 amount1) = UniswapV3Utils._quoteAmountsForLiquidity(price, p.lower, p.upper, p.liquidity);
        (uint256 growth0, uint256 growth1) = _feeGrowthInside(p.lower, p.upper);
        uint256 fee0; uint256 fee1;
        unchecked {
            fee0 = FullMath.mulDiv(growth0 - p.growth0, p.liquidity, FixedPoint128.Q128);
            fee1 = FullMath.mulDiv(growth1 - p.growth1, p.liquidity, FixedPoint128.Q128);
        }
        sharesOut = _quoteInitialShares(amount0 + p.owed0 + fee0, amount1 + p.owed1 + fee1);
        if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();
    }

'''+s[b:]
 return s
edit(f+'UniswapV3StandardExchangePositionImportTarget.sol',imports)
edit(f+'UniswapV3VaultRepo.sol',lambda s:s.replace('Imported books keep the NFT ticks as that center.','Imported books convert to the same full-range center.').replace('Mark the imported NFT range as the single center (ticks as-is; D34).','Record import custody and the converted full-range center.'))
def query(s):
 s=s.replace('import {IERC20}', 'import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";\nimport {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";\nimport {Math} from "@crane/contracts/utils/Math.sol";\nimport {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";\nimport {IERC20}',1)
 s=s.replace('is UniswapV3StandardExchangeOutBase {','is UniswapV3StandardExchangeOutBase, NativeStandardYieldTarget {',1)
 a=s.index('    function previewExchangeOut(')
 return s[:a]+'''    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256)
    {
        if (address(in_) == address(this) && !internal_) {
            // SY redemption spends the caller's own native shares without a self-approval.
            ERC20Repo._transfer(msg.sender, address(this), amount_);
            internal_ = true;
        }
        return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
    }
    function getTokensIn() public view override returns (address[] memory tokens) {
        tokens = new address[](2); tokens[0] = _token0(); tokens[1] = _token1();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(_pool()), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 1e18;
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return Math.mulDiv(FixedPointMathLib.mulSqrt(reserve0, reserve1), 1e18, supply);
    }

'''+s[a:]
edit(f+'UniswapV3StandardExchangeOutQueryTarget.sol',query)
def facet(s):
 s=s.replace('import {IFacet}', 'import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";\nimport {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IFacet}',1)
 s=s.replace('interfaces = new bytes4[](1)','interfaces = new bytes4[](2)',1).replace('        interfaces[0] = type(IStandardExchangeOut).interfaceId;','        interfaces[0] = type(IStandardExchangeOut).interfaceId;\n        interfaces[1] = type(IStandardizedYield).interfaceId;',1)
 return s.replace('        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;','        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;\n        funcs = NativeStandardYieldSelectors._append(funcs);',1)
edit(f+'UniswapV3StandardExchangeOutQueryFacet.sol',facet)
def pkg(s):
 s=s.replace('import {IStandardExchangeTransitionQuote}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IStandardExchangeTransitionQuote}',1)
 s=s.replace('new bytes4[](13)','new bytes4[](14)',1)
 return s.replace('        interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;','        interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[13] = type(IStandardizedYield).interfaceId;',1)
edit(f+'UniswapV3StandardExchangeDFPkg.sol',pkg)
def base(s):
 names=re.findall(r'creationCode\("([^\"]+)\.sol:([^\"]+)"',(root/(f+'UniswapV3_Component_FactoryService.sol')).read_text())
 imp=''
 for filename,name in sorted(set(names)):
  line=f'import {{{name}}} from "{f}{filename}.sol";'
  if line not in s:imp+=line+'\n'
 return s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\n// Compile each artifact loaded by the canonical fixture FactoryService.\n'+imp,1)
edit(f+'test/bases/TestBase_UniswapV3StandardExchange.sol',base)
(root/'implementation-artifacts/detf-funded-staking/v3-full-range-sy-sources.json').write_text(json.dumps({'requirements':['D57','D58','D59'],'validation':'pending; V4/Slipstream remain separate unfinished implementations','files':rows},indent=2)+'\n')
print('Applied',len(rows),'V3 production/fixture changes')
