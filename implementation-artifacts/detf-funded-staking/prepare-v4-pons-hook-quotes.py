from pathlib import Path
import sys,hashlib,json
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';base=r/'contracts/protocols/dexes/uniswap/v4';files={}
p=base/'UniswapV4QuoteService.sol';s=p.read_text();s=s.replace('library UniswapV4QuoteService {','''library UniswapV4QuoteService {
    /// @dev Pons V2 takes separate floored cuts on the unspecified swap leg.
    /// Read the immutable per-pool launch terms, not the policy for future launches.
    function _ponsHookFees(PoolKey memory key)
        private view returns (bool supported, uint256 feeBps, uint256 taxBps)
    {
        uint160 flags = uint160(address(key.hooks)) & Hooks.ALL_HOOK_MASK;
        if (flags != (Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG)) {
            return (false, 0, 0);
        }
        (bool ok, bytes memory result) = address(key.hooks).staticcall(
            abi.encodeWithSignature("launches(bytes32)", PoolId.unwrap(key.toId()))
        );
        if (!ok || result.length != 13 * 32) return (false, 0, 0);
        PonsV2MemeHook.LaunchInfo memory info = abi.decode(result, (PonsV2MemeHook.LaunchInfo));
        if (!info.registered || info.hookFeeBps + uint256(info.creatorTaxBps) > 2_000) return (false, 0, 0);
        if (info.memecoin != Currency.unwrap(info.memecoinIsCurrency0 ? key.currency0 : key.currency1)
            || info.quoteToken != Currency.unwrap(info.memecoinIsCurrency0 ? key.currency1 : key.currency0)) {
            return (false, 0, 0);
        }
        return (true, info.hookFeeBps, info.creatorTaxBps);
    }

    function _supportsProjectedHook(PoolKey memory key) internal view returns (bool) {
        if (address(key.hooks) == address(0)) return true;
        (bool supported,,) = _ponsHookFees(key);
        return supported;
    }

    function _adjustHookSwap(PoolKey memory key, uint256 amount, bool exactInput)
        internal view returns (uint256)
    {
        if (address(key.hooks) == address(0) || address(key.hooks) == address(this) || amount == 0) return amount;
        (bool supported, uint256 feeBps, uint256 taxBps) = _ponsHookFees(key);
        if (!supported) return amount; // Retain the existing quote path for other hooks.
        uint256 charge = amount * feeBps / 10_000 + amount * taxBps / 10_000;
        return exactInput ? amount - charge : amount + charge;
    }

    using PoolIdLibrary for PoolKey;
''')
s=s.replace('import {IPoolManager}', '''import {PonsV2MemeHook} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IPoolManager}''')
s=s.replace('return quote.amountOut;','return _adjustHookSwap(p.key, quote.amountOut, true);').replace('return quote.amountIn;','return _adjustHookSwap(p.key, quote.amountIn, false);');files[p]=s
p=base/'UniswapV4StandardExchangeCommon.sol';s=p.read_text().replace('return address(_poolKey().hooks) == address(0) && !UniswapV4PositionRepo._isImportedPosition()','return UniswapV4QuoteService._supportsProjectedHook(_poolKey()) && !UniswapV4PositionRepo._isImportedPosition()');s=s.replace('return result.amountOut;','return UniswapV4QuoteService._adjustHookSwap(_poolKey(), result.amountOut, true);').replace('return quote.amountOut;','return UniswapV4QuoteService._adjustHookSwap(_poolKey(), quote.amountOut, true);');files[p]=s
rows=[]
for p,s in files.items():
 old=p.read_text();assert old!=s
 rows.append({'path':str(p.relative_to(r)),'before':hashlib.sha256(old.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(a/('pending-pons-hook-'+p.name+'.txt')).write_text(s)
(a/('v4-pons-hook-quotes.json' if '--apply' in sys.argv else 'pending-v4-pons-hook-quotes.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':rows,'reference':'Pinned Crane PonsV2MemeHook._afterSwap and immutable launches(poolId) terms; two independent floors on unspecified swap leg; no fixture fee disabling.','validation_required':['Pons existing donation and primary burn exact-preview tests','Actual external SE-share redemption projection','All in-scope V4 SE/hook proxy facet and delegate EIP-170 limits','Direct exact-input and exact-output swaps including nonzero creator tax']},indent=2)+'\n')
print(len(files),'applied' if '--apply' in sys.argv else 'prepared')
