"""Prepare common V4 integration fixtures for approved position activation law."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json, re

art=Path(__file__).resolve().parent
root=art.parent.parent
base='contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/'
drafts=art/'production-se-fixture-followup-drafts'
drafts.mkdir(exist_ok=True)
changes=[]
patch=[]

def save(path,after,reason):
    before=(root/path).read_text()
    assert before!=after
    draft=drafts/(Path(path).name+'.txt')
    assert not draft.exists(),'Preserve prepared evidence.'
    draft.write_text(after)
    changes.append({'path':path,'draft':str(draft.relative_to(root)),'reason':reason,
        'before_sha256':hashlib.sha256(before.encode()).hexdigest(),
        'after_sha256':hashlib.sha256(after.encode()).hexdigest()})
    patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=path,tofile=path))

path=base+'UniswapV4DetfProductionSeDeployLib.sol'
s=(root/path).read_text()
s=s.replace('import {Vm}', '''import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Vm}''',1)
old='''        int24 tickLower = (-887220 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887220 / tickSpacing) * tickSpacing;
        if (tickLower >= tickUpper) {
            tickLower = -tickSpacing * 1000;
            tickUpper = tickSpacing * 1000;
        }
        uint128 liq = liquidity < 1e18 ? 50_000_000e18 : liquidity;
        pool.mint(address(this), tickLower, tickUpper, liq, abi.encode(address(this)));'''
assert old in s
s=s.replace(old,'''        int24 tickLower = TickMathV4.minUsableTick(tickSpacing);
        int24 tickUpper = TickMathV4.maxUsableTick(tickSpacing);
        require(liquidity > 0, "funded seed liquidity");
        pool.mint(address(this), tickLower, tickUpper, liquidity, abi.encode(address(this)));''')
old='        seeder.seedFullRange(pool, 50_000_000e18);'
assert old in s
s=s.replace(old,'''        (uint160 sqrtPrice,,,,,,) = pool.slot0();
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPrice,
            TickMathV4.getSqrtPriceAtTick(TickMathV4.minUsableTick(pool.tickSpacing())),
            TickMathV4.getSqrtPriceAtTick(TickMathV4.maxUsableTick(pool.tickSpacing())),
            _humanUnits(t0, 50_000_000), _humanUnits(t1, 50_000_000)
        );
        seeder.seedFullRange(pool, liquidity);''')
anchor='    function deployUniv3Vault('
assert anchor in s
helper='''    /// @dev Activate existing V3/V4 SEs before a DETF can make later one-token deposits.
    /// Generic test assets are minted; real Pons payment tokens come from the
    /// fixture's existing purchases and WETH is actually wrapped from ETH.
    function activatePositionVault(address vault, address payment, address payer, address weth) internal {
        (IStandardizedYield.AssetType kind,,) = IStandardizedYield(vault).assetInfo();
        if (kind != IStandardizedYield.AssetType.LIQUIDITY || IERC20(vault).totalSupply() != 0) return;
        address[] memory discovered = IStandardizedYield(vault).getTokensIn();
        address[] memory tokens = new address[](2);
        uint256 found;
        for (uint256 i; i < discovered.length; ++i) {
            if (discovered[i] == vault) continue;
            require(found < 2, "two position currencies");
            tokens[found++] = discovered[i];
        }
        require(found == 2 && (tokens[0] == payment || tokens[1] == payment), "position payment leg");
        uint256 paymentIndex = tokens[0] == payment ? 0 : 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[paymentIndex] = Math.min(_humanUnits(payment, 100), IERC20(payment).balanceOf(payer) / 100);
        address other = tokens[1 - paymentIndex];
        amounts[1 - paymentIndex] = IStandardExchangeIn(vault).previewExchangeIn(
            IERC20(payment), amounts[paymentIndex], IERC20(other)
        );
        require(amounts[0] > 0 && amounts[1] > 0, "fund both position legs");
        if (other == weth) {
            vm.deal(payer, payer.balance + amounts[1 - paymentIndex]);
            vm.prank(payer);
            IWETH(other).deposit{value: amounts[1 - paymentIndex]}();
        } else {
            IProdSeMintable(other).mint(payer, amounts[1 - paymentIndex]);
        }
        address seedHolder = address(uint160(uint256(keccak256("production-position-seed-holder"))));
        vm.startPrank(payer);
        IERC20(tokens[0]).approve(vault, type(uint256).max);
        IERC20(tokens[1]).approve(vault, type(uint256).max);
        uint256 quote = IStandardExchangeInMulti(vault).previewExchangeInManyToOne(tokens, amounts, IERC20(vault));
        uint256 minted = IStandardExchangeInMulti(vault).exchangeInManyToOne(
            tokens, amounts, IERC20(vault), quote, seedHolder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(minted > 0 && minted == quote, "position activation quote/execution");
        require(IERC20(vault).balanceOf(seedHolder) == minted, "external seed shares");
    }

'''
s=s.replace(anchor,helper+anchor,1)
save(path,s,'Use exact funded mixed-decimal V3 seed liquidity and a shared real two-token position activation helper; protocol product contracts unchanged.')

for suffix in ('','_Decimals'):
    path=base+'TestBase_UniswapV4Detf_Quad_ProdSe'+suffix+'.sol'
    s=(root/path).read_text()
    assert s.count('        _fundAndApprove();')==1
    s=s.replace('        _fundAndApprove();','''        _fundAndApprove();
        SeLib.activatePositionVault(hookSe0, hookPair0, detfUser, address(weth));
        SeLib.activatePositionVault(hookSe1, hookPair1, detfUser, address(weth));
        SeLib.activatePositionVault(hookSe2, hookPair2, detfUser, address(weth));''')
    save(path,s,'Activate each position underlier after actual fixture funding; Morpho accounting assets remain on their existing initialization path.')
    for family in ('Univ3Se','Univ4Se','PonsV1Se'):
        path=base+'TestBase_UniswapV4Detf_Cp_'+family+suffix+'.sol'
        s=(root/path).read_text()
        start=s.index('    function setUp()')
        opening=s.index('{',start)
        depth=1;end=opening+1
        while depth:
            depth+=(s[end]=='{')-(s[end]=='}');end+=1
        weth='address(0)' if family=='Univ3Se' else 'address(weth)'
        s=s[:end-1]+f'    SeLib.activatePositionVault(se, mintToken, detfUser, {weth});\n    '+s[end-1:]
        save(path,s,'Activate the real SE with both currencies after its user funding and before DETF first-bond execution.')

record={'status':'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
    'gate':'Wait for the entire active validation parent session 4255 to exit before application.',
    'changes':changes,'observed_failures':['V3 mixed-decimal pool setup balance reverts from fixed oversized liquidity.',
        'V4/pons position underliers still have zero SE supply at the subsequent one-token first-bond deposit.'],
    'scope':'Existing V4 production-provider TestBases and their local protocol fixture library; retain every test leaf and all production economics.',
    'validation_passed':False,'required_validation':'Draft typecheck followed by actual affected production-provider suites. Other final full-suite failures still need independent review.'}
(art/'production-se-fixture-followups-prepared.json').write_text(json.dumps(record,indent=2)+'\n')
(art/'production-se-fixture-followups.patch').write_text(''.join(patch))
print(json.dumps({'status':record['status'],'draft_sources':len(changes),'canonical_sources_changed':0}))
