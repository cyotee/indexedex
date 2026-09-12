"""Project custom wrapper deposits before the retained reserve-family donation join."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
changes = []

def stage(relative, transform):
    path = root / relative
    before = path.read_text()
    after = transform(before)
    assert before != after, relative
    changes.append((path, before, after))

def interface(source):
    anchor = '    function previewSynthetic('
    assert anchor in source
    return source.replace(anchor, '''    /// @notice Quote a custom payment wrapped into newly issued SE shares,
    /// followed by the family's existing single-asset liquidity join.
    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256 sharesOut);

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol', interface)

def leg(source):
    anchor = '    function depositAfterExchange('
    assert anchor in source
    return source.replace(anchor, '''    function afterExternalDeposit(address se, address pair, address tokenIn, uint256 amountIn, address holder)
        internal view returns (ExternalQuote memory q)
    {
        q.exchange = IStandardExchangeTransitionQuote(se);
        (q.state,) = q.exchange.quoteState(pair, holder);
        (q.state, q.assets, q.heldAssets) = IStandardExchangeExternalQuote(se)
            .quoteExternalDeposit(q.state, tokenIn, amountIn);
        q.heldShares = q.exchange.quoteShareBalance(q.state);
    }

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol', leg)

def cp(source):
    source = source.replace('import {ERC20Repo}', 'import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";\nimport {ERC20Repo}', 1)
    anchor = '    struct ZapQuote {'
    source = source.replace(anchor, '''    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256 sharesOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken) revert InvalidRoute();
        LegLib.ExternalQuote memory externalQuote = LegLib.afterExternalDeposit(
            l.standardExchange, pairToken, tokenIn, amountIn, address(this)
        );
        uint256 claim = externalQuote.heldAssets;
        if (claim == 0 && externalQuote.heldShares > 0) claim = 1;
        uint256 supply = _supplyAfterExternalDeposit(claim);
        ZapQuote memory q = _quoteShareZapStateAt(externalQuote.state, externalQuote.assets);
        (sharesOut,) = _finishDepositQuote(q, supply);
    }

    function _supplyAfterExternalDeposit(uint256 pairClaim) private view returns (uint256 supply) {
        Repo.Layout storage l = Repo._layout();
        supply = ERC20Repo._totalSupply();
        (bool feeOn,, uint256 ownerShare) = _feeOnAndShare();
        if (feeOn && l.kLast != 0 && supply > 0) {
            uint256 k = Math.toWad(IERC20(l.rawToken).balanceOf(address(this)), _decimalsOf(l.rawToken))
                * Math.toWad(pairClaim, _decimalsOf(l.pairToken));
            supply += Math.calculateProtocolFee(supply, k, l.kLast, ownerShare);
        }
    }

''' + anchor, 1)
    old = '''        Repo.Layout storage l = Repo._layout();
        q = _quoteZapState(tokenIn_, amountIn_);
        uint256 x_ = _poolOrderX(q.rawReserve, q.pairReserve);'''
    assert old in source
    source = source.replace(old, '''        q = _quoteZapState(tokenIn_, amountIn_);
        (minted_, supply_) = _finishDepositQuote(q, _supplyAfterProtocolMint());
    }

    function _finishDepositQuote(ZapQuote memory q, uint256 supply_)
        private view returns (uint256 minted_, uint256 finalSupply_)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 x_ = _poolOrderX(q.rawReserve, q.pairReserve);''', 1)
    start = source.index('    function _finishDepositQuote(')
    end = source.index('    function previewClaimAfterJoin(', start)
    body = source[start:end]
    assert '        supply_ = _supplyAfterProtocolMint();\n' in body
    body = body.replace('        supply_ = _supplyAfterProtocolMint();\n', '', 1)
    body = body.replace('        supply_ += minted_;', '        finalSupply_ = supply_ + minted_;', 1)
    source = source[:start] + body + source[end:]
    old = '''        Repo.Layout storage l = Repo._layout();
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(l.standardExchange);
        (q.state,) = quote.quoteState(l.pairToken, address(this));
        (q.state,,,) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares);'''
    assert old in source
    source = source.replace(old, '''        Repo.Layout storage l = Repo._layout();
        (bytes memory state,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteState(l.pairToken, address(this));
        return _quoteShareZapStateAt(state, shares);
    }

    function _quoteShareZapStateAt(bytes memory state, uint256 shares) private view returns (ZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(l.standardExchange);
        q.state = state;
        (q.state,,,) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares);''', 1)
    return source

stage('contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget.sol', cp)

def orbital_lib(source):
    source = source.replace('import {IERC20}', 'import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";\nimport {IERC20}', 1)
    anchor = '    struct DepositQuote {'
    assert anchor in source
    return source.replace(anchor, '''    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        uint8 index = Repo._indexOf(Repo._layout(), pairToken);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        Leg memory input = legs[index];
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(input.se, pairToken, tokenIn, amountIn, address(this));
        (input.state,,,) = Transition(input.se).quoteTransition(q.state, Transition.Operation.ReceiveShares, q.assets);
        (input.state,, amountIn,) = Transition(input.se).quoteTransition(input.state, Transition.Operation.RedeemExactIn, q.assets);
        _refresh(input);
        return _depositAtState(legs, index, amountIn);
    }

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol', orbital_lib)

def orbital_target(source):
    source = source.replace('import {UniswapV4StandardExchangeOrbitalBufferHookRepo', 'import {UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib as ExitQuoteLib} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol";\nimport {UniswapV4StandardExchangeOrbitalBufferHookRepo', 1)
    anchor = '    function radius()'
    assert anchor in source
    return source.replace(anchor, '''    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        if (!_isLive() || amountIn == 0) return 0;
        _requireZapEligibleOrOwnerMin();
        return ExitQuoteLib.previewJoinAfterDeposit(tokenIn, pairToken, amountIn);
    }

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol', orbital_target)

def weighted_query(source):
    source = source.replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";''', 1)
    anchor = '    function previewJoinProportional('
    return source.replace(anchor, '''    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = _tokenIndex(pairToken);
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[index], pairToken, tokenIn, amountIn, address(this));
        uint256[] memory inv = _invWadAll();
        inv[index] = Math.scaleTo(q.heldShares, l.invScales[index]);
        uint256 supply = _projectedJoinSupply(inv);
        uint256 fee = _feeOracle().dexSwapFeeOfVault(address(this));
        if (fee >= Math.WAD) revert InvalidFeeWad();
        return _singleJoinExactInSharesOwnerAware(inv, l.weights, index, Math.scaleTo(q.assets, l.invScales[index]), supply, fee);
    }

    function _projectedJoinSupply(uint256[] memory inv) private view returns (uint256 supply) {
        supply = _totalSupply();
        (bool feeOn,, uint256 ownerShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return supply;
        bool full = Math.isFullBookReserves(inv);
        if ((full ? 0 : 1) != l.kLastMode) return supply;
        uint256 root = full ? Math.computeV(l.weights, inv) : Math.computeInterimK(l.weights, inv);
        return supply + Math.protocolLpShares(supply, root, l.kLast, ownerShare);
    }

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget.sol', weighted_query)

def curve_query(source):
    source = source.replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";''', 1)
    anchor = '    function previewJoinProportional('
    return source.replace(anchor, '''    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = _tokenIndex(pairToken);
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[index], pairToken, tokenIn, amountIn, address(this));
        uint256[4] memory inv = _invWadAll();
        inv[index] = Math.scaleTo(q.heldShares, l.invScales[index]);
        uint256 supply = _projectedJoinSupply(inv);
        uint256 fee = _feeOracle().dexSwapFeeOfVault(address(this));
        if (fee >= Math.WAD) revert InvalidFeeWad();
        return Math.singleJoinExactInShares(inv, Math.scaleTo(q.assets, l.invScales[index]), index, _amp(), supply, fee);
    }

    function _projectedJoinSupply(uint256[4] memory inv) private view returns (uint256 supply) {
        supply = _totalSupply();
        (bool feeOn,, uint256 ownerShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0 || !Math.isFullBookReserves(inv)) return supply;
        return supply + Math.protocolLpShares(supply, Math.rootK(inv), l.kLast, ownerShare);
    }

''' + anchor, 1)

stage('contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol', curve_query)

def selector(source):
    match = re.search(r'funcs = new bytes4\[\]\((\d+)\);', source)
    assert match
    length = int(match[1])
    source = source[:match.start()] + match[0].replace(f'({length})', f'({length + 1})') + source[match.end():]
    last = re.search(rf'        funcs\[{length - 1}\] = [^;]+;', source)
    assert last
    return source[:last.end()] + f'\n        funcs[{length}] = this.previewJoinAfterDeposit.selector;' + source[last.end():]

for relative in [
    'constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet.sol',
    'orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet.sol',
    'weighted/facets/UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet.sol',
    'stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet.sol',
]:
    stage('contracts/hooks/uniswap/v4/standardExchange/' + relative, selector)

def detf(source):
    old = '''        uint256 shareAmt_ = address(token) == address(v_) ? amount : 0;
        if (shareAmt_ == 0) {
            try v_.previewExchangeIn(token, amount, IERC20(address(v_))) returns (uint256 sh_) {
                shareAmt_ = sh_;
            } catch {
                return 0;
            }
        }
        return _hook().previewJoinSingleAssetExactIn(address(v_), shareAmt_);'''
    assert old in source
    return source.replace(old, '''        if (address(token) == address(v_)) {
            return _hook().previewJoinSingleAssetExactIn(address(v_), amount);
        }
        return IDetfReserveQuote(s.hook).previewJoinAfterDeposit(address(token), _hookPairOfVault(v_), amount);''', 1)

stage('contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol', detf)

if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    assert 'function quoteExternalDeposit' in (root / 'contracts/interfaces/IStandardExchangeTransitionQuote.sol').read_text(), 'Apply provider extension first'
    for path, before, after in changes:
        assert path.read_text() == before
        path.write_text(after)
record = {'status': 'applied; validation pending' if args.apply else 'prepared; Solidity unchanged', 'scope': 'Project newly issued SE supply/fees before the retained CP/Orbital zap or Weighted/Curve inventory join. Actual donation execution and issuance economics unchanged.', 'files': [{'path':str(path.relative_to(root)), 'before_sha256':hashlib.sha256(before.encode()).hexdigest(), 'after_sha256':hashlib.sha256(after.encode()).hexdigest()} for path,before,after in changes]}
(artifacts / 'composed-donation-projection.patch').write_text(''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))) for path,before,after in changes))
(artifacts / 'composed-donation-projection.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'status':record['status'],'files':len(changes)}))
