"""Retain independent issuance and SE conversion controls on the standard surface."""
from pathlib import Path
import re,json,hashlib
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';F=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf';rows=[]
for suffix,sub in [('',F),('_Decimals',F/'decimals')]:
 p=sub/('UniswapV4Detf_Mint'+suffix+('.sol' if suffix else '.t.sol'));b=p.read_text();s=b
 s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";')
 s=s.replace('    function test_T7_6_', '''    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = 2.2e18;
    }

    function test_T7_6_''')
 s=re.sub(r'        \(uint256 grossPred, uint256 userPred, uint256 lpPred\) =\s*detfInfo.previewMint\(IERC20\(address\(pairToken\)\), mintIn\);\s*assertGt\(grossPred, 0, "gross"\);', '''        assertTrue(detfInfo.isMintingAllowed(IERC20(address(pairToken))), "rich launch selects primary issuance");
        uint256 userPred = IStandardExchangeIn(detf).previewExchangeIn(IERC20(address(pairToken)), mintIn, IERC20(detf));
        uint256 lpPred = IUniswapV4SeBufferHook(reserveHook).previewJoinSingleAssetExactIn(address(pairToken), mintIn);''',s)
 s=s.replace('assertEq(grossPred, swapQuote, "Gross = previewSwapExactIn(pair, detf, pairEq*(1+p))");','assertEq(userPred, Math.mulDiv(swapQuote, ONE_WAD - p, ONE_WAD), "ordinary net = floor((1-p) * boosted live quote)");\n        uint256 reward = Math.mulDiv(swapQuote, p, ONE_WAD);\n        uint256 backingBefore = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());')
 s=s.replace('assertGe(IERC20(detf).totalSupply(), supplyBefore + userDetf, "D11 supply rose by minted Gross split");','assertEq(IERC20(detf).totalSupply() - supplyBefore, userDetf + reward, "D11 exact new issuance; no matching liquidity DETF");\n        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()) - backingBefore, reward, "ordinary reward pot actually funds staking");')
 rows.append((p,b,s))
 p=sub/('UniswapV4Detf_IoTablesGoldBase'+suffix+'.sol');b=p.read_text();s=b
 s=s.replace('(uint256 grossPred_, uint256 userPred_,) = detfInfo.previewMint(IERC20(se), shareAmt_);\n        assertEq(grossPred_, swapQuote_, "Gross = previewSwapExactIn(pair, detf, pairEq*(1+p))");', '''uint256 userPred_ = IStandardExchangeIn(detf).previewExchangeIn(IERC20(se), shareAmt_, IERC20(detf));
        uint256 expected_ = detfInfo.isMintingAllowed(IERC20(se))
            ? Math.mulDiv(swapQuote_, ONE_WAD - p_, ONE_WAD)
            : IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(address(pairToken), detf, pairEq_);
        assertEq(userPred_, expected_, "SE share conversion feeds the selected primary or swap route");''')
 assert s!=b,p
 rows.append((p,b,s))
for p,b,s in rows:
 p.write_text(s)
(ART/'v4-ordinary-mint-test-migration.json').write_text(json.dumps({'status':'applied; validation pending','coverage':'T7.6 rich primary ordinary gross/net floors, exact reward custody and zero additional G. T7.7 actual SE share-to-pair conversion, exact inverse and branch-aware standard preview/execution. All native decimal fixtures retained.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in rows]},indent=2)+'\n')
print('applied',len(rows))
