"""Apply deployment/premine propagation after the active Solidity run exits. Not applied yet."""
from pathlib import Path
import json,hashlib
changed=[]
def save(p,s):
 old=p.read_text();p.write_text(s);changed.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
p=Path('contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol');s=p.read_text();assert 'ownerOnlyLiquidity: true,' in s;save(p,s.replace('ownerOnlyLiquidity: true,','ownerOnlyLiquidity: args.ownerOnlyLiquidity,'))
p=Path('scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol');s=p.read_text().replace('        IUniswapV4Detf.PkgArgs memory args;','        IUniswapV4Detf.PkgArgs memory args;\n        args.ownerOnlyLiquidity = true;',1).replace('        args.thresholdMode = ThresholdMode.Policy;\n','').replace('uint8(18) : HookPkgArgsDecimalsLib.tokenDec(predicted)','uint8(9) : HookPkgArgsDecimalsLib.tokenDec(predicted)').replace('ownerOnlyLiquidity: true,','ownerOnlyLiquidity: args.ownerOnlyLiquidity,');save(p,s)
p=Path('scripts/foundry/anvil_robinhood_testnet/ProtocolDetfInstanceLib.sol');s=p.read_text()
for f in ('_dtfDetfArgs','_dolQArgs'):
 mark=f'    function {f}(LaunchState storage s) private view returns (IUniswapV4Detf.PkgArgs memory args) {{'
 assert mark in s;s=s.replace(mark,mark+'\n        args.ownerOnlyLiquidity = true;',1)
# Premine and deployment derive their hook policy from the same DETF arguments.
a=s.index('    function _cpMineNonce(');b=s.index('    function _deployDtfDetf(',a)
part=s[a:b].replace('ownerOnlyLiquidity: true,','ownerOnlyLiquidity: _dtfDetfArgs(s).ownerOnlyLiquidity,');s=s[:a]+part+s[b:]
a=s.index('    function _deployDtfDetf(');b=s.index('    function _dolQArgs(',a)
part=s[a:b].replace('ownerOnlyLiquidity: true,','ownerOnlyLiquidity: args.ownerOnlyLiquidity,');s=s[:a]+part+s[b:]
s=s.replace('ownerOnlyLiquidity: true,','ownerOnlyLiquidity: _dolQArgs(s).ownerOnlyLiquidity,').replace('uint8(18) : HookPkgArgsDecimalsLib.tokenDec(predicted)','uint8(9) : HookPkgArgsDecimalsLib.tokenDec(predicted)')
# The predicted DETF is not deployed yet; other token scales are read from their real metadata.
s=s.replace('tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals4(toks),','tokenDecimals: _quadTokenDecimals(toks, predicted),')
mark='    function _quadMineNonce('
helper='''    function _quadTokenDecimals(address[4] memory tokens_, address predicted_) private view returns (uint8[4] memory scales_) {
        for (uint256 i_; i_ < 4; ++i_) {
            scales_[i_] = tokens_[i_] == predicted_ ? 9 : HookPkgArgsDecimalsLib.tokenDec(tokens_[i_]);
        }
    }

'''
assert mark in s;s=s.replace(mark,helper+mark,1);save(p,s)
p=Path('test/foundry/spec/fee/collector/FeeCollectorManagerFacet_IFacet.t.sol');s=p.read_text().replace('controlFuncs = new bytes4[](3);','controlFuncs = new bytes4[](4);').replace('        controlFuncs[2] = IFeeCollectorManager.pullFee.selector;','        controlFuncs[2] = IFeeCollectorManager.pullFee.selector;\n        controlFuncs[3] = IFeeCollectorManager.redeemReserveLiquidity.selector;');save(p,s)
p=Path('test/foundry/spec/fee/collector/FeeCollectorProxy_Selectors.t.sol');s=p.read_text().replace('^ IFeeCollectorManager.pullFee.selector;', '^ IFeeCollectorManager.pullFee.selector ^ IFeeCollectorManager.redeemReserveLiquidity.selector;');save(p,s)
Path('implementation-artifacts/detf-funded-staking/v4-launch-policy-sources.json').write_text(json.dumps(changed,indent=2)+'\n')
