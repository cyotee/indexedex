from pathlib import Path
f=Path("test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol")
s=f.read_text()
s=s.replace('import {IFacet}', 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\nimport {IFacet}', 1)
s=s.replace('controlInterfaces = new bytes4[](1);', 'controlInterfaces = new bytes4[](2);', 1)
s=s.replace('controlInterfaces[0] = type(IStandardExchangeOutMulti).interfaceId;', 'controlInterfaces[0] = type(IStandardExchangeOutMulti).interfaceId;\n        controlInterfaces[1] = type(IStandardizedYield).interfaceId;', 1)
s=s.replace('controlFuncs = new bytes4[](1);', 'controlFuncs = new bytes4[](17);', 1)
functions=['deposit','redeem','exchangeRate','yieldToken','assetInfo','getTokensIn','getTokensOut','isValidTokenIn','isValidTokenOut','previewDeposit','previewRedeem','getRewardTokens','accruedRewards','rewardIndexesCurrent','rewardIndexesStored','claimRewards']
needle='        controlFuncs[0] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;'
s=s.replace(needle, needle+''.join('\n        controlFuncs['+str(i+1)+'] = IStandardizedYield.'+name+'.selector;' for i,name in enumerate(functions)),1)
f.write_text(s)
f=Path("test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol")
s=f.read_text();s+='\nimport {UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test} from "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol";\n';f.write_text(s)
