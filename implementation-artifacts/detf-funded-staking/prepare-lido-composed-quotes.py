"""Prepare, do not apply, existing-target Lido projections and production-proxy tests."""
from pathlib import Path
import difflib,re,json,datetime
root=Path(__file__).resolve().parents[2];art=Path(__file__).resolve().parent
changes={}
def stage(name,transform):
 p=root/name;old=p.read_text();new=transform(old);assert old!=new,name;changes[name]=(old,new)
def imports(s,text):
 end=re.search(r'pragma solidity [^;]+;',s).end();return s[:end]+'\n'+text+s[end:]
quoteimport='import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\n'
base='contracts/protocols/staking/lido/'
def target(s):
 s=imports(s,quoteimport+'''import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {LidoWstETHStandardExchangeRepo} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeRepo.sol";
''')
 s=s.replace('    IStandardExchangeIn\n{','    IStandardExchangeIn,\n    IStandardExchangeTransitionQuote,\n    IStandardExchangeExternalQuote\n{')
 end=s.rfind('}');return s[:end]+(art/'lido-transition-functions.prepared.txt').read_text()+'\n'+s[end:]
stage(base+'LidoWstETHStandardExchangeInTarget.sol',target)
def facet(s):
 s=imports(s,quoteimport).replace('new bytes4[](1)','new bytes4[](3)').replace('interfaces[0] = type(IStandardExchangeIn).interfaceId;','interfaces[0] = type(IStandardExchangeIn).interfaceId;\n        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;')
 s=s.replace('new bytes4[](3);\n        funcs','new bytes4[](10);\n        funcs')
 anchor='        funcs[2] = this.exchangeInEth.selector;';addition=''
 for n,(interface,method) in enumerate([( 'IStandardExchangeTransitionQuote',x) for x in ['quoteState','quoteAssets','quoteShareBalance','quoteTotalSupply','quoteTransition']]+[('IStandardExchangeExternalQuote',x) for x in ['quoteExternalDeposit','quoteExternalExchange']],3):addition+='\n        funcs['+str(n)+'] = '+interface+'.'+method+'.selector;'
 return s.replace(anchor,anchor+addition)
stage(base+'LidoWstETHStandardExchangeInFacet.sol',facet)
def package(s):
 s=imports(s,quoteimport).replace('new bytes4[](11)','new bytes4[](13)')
 a='        interfaces[10] = type(IStandardizedYield).interfaceId;'
 return s.replace(a,a+'\n        interfaces[11] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[12] = type(IStandardExchangeExternalQuote).interfaceId;')
stage(base+'LidoWstETHStandardExchangeDFPkg.sol',package)
def factory(s):
 pattern=r'instance = create3Factory\.deployFacet\(\s*ArtifactCreationCode.creationCode\("([^\"]+)"\),\s*(abi.encode\("([^\"]+)"\)\._hash\(\))\s*\);'
 def replace(m):return 'bytes memory code = ArtifactCreationCode.creationCode("'+m[1]+'");\n        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt('+m[2]+', code, ""));'
 s,count=re.subn(pattern,replace,s);assert count==4,count
 start=s.index('        instance = ILidoWstETHStandardExchangeDFPkg(');end=s.index('        vm.label(address(instance), "LidoWstETHStandardExchangeDFPkg");',start)
 return s[:start]+'''        bytes memory code = ArtifactCreationCode.creationCode("LidoWstETHStandardExchangeDFPkg.sol:LidoWstETHStandardExchangeDFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = ILidoWstETHStandardExchangeDFPkg(IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("LidoWstETHStandardExchangeDFPkg")._hash(), code, args)
        ));
'''+s[end:]
stage(base+'LidoWstETH_Component_FactoryService.sol',factory)
def tests(s):
 s=imports(s,'''import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
''').replace('contract LidoNativeSYTest is TestBase_LidoWstETHStandardExchange, LiquidStakingSYBehavior {','contract LidoNativeSYTest is TestBase_LidoWstETHStandardExchange, LiquidStakingSYBehavior, TransitionQuoteAssertions {')
 anchor='    function _subject() internal view override returns (address) { return seVault; }'
 pos=s.index(anchor,s.index('contract LidoNativeSYTest'))
 new='''    function _seedLidoQuoteBook() private {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.07e18);
        _seedVaultInventory(200 ether, 200 ether);
        _dealWeth(address(this), 100 ether);
        _mintWstViaSt(address(this), 100 ether);
    }

    function test_lidoLiquidSleeveSequenceProjectsFundedFeesAndShares() public {
        _seedLidoQuoteBook();
        _assertQuoteSequence(seVault, IERC20(address(hermeticWeth)), address(this), 1 ether);
    }

    function test_lidoWrappedReceiptSequenceProjectsCompleteReserve() public {
        _seedLidoQuoteBook();
        _assertQuoteSequence(seVault, IERC20(address(hermeticWstEth)), address(this), 1 ether);
    }

    function test_lidoExternalWrappedDepositPreservesBufferedHolderAndFeeRecipient() public {
        _seedLidoQuoteBook();
        address feeRecipient = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 7 ether + 19, address(this));
        _assertExternalDepositQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 3 ether + 11, feeRecipient);
    }

    function test_lidoExternalConversionsPreserveFundedSEInventory() public {
        _seedLidoQuoteBook();
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWstEth)), IERC20(address(hermeticWeth)), 3 ether + 17);
        _assertExternalExchangeQuote(seVault, IERC20(address(hermeticWeth)), IERC20(address(hermeticWstEth)), 7 ether + 29);
    }

'''
 return s[:pos]+new+s[pos:]
stage('test/foundry/spec/vaults/standard/sy/LiquidStakingNativeSY.t.sol',tests)
patch=''.join(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=p,tofile=p)) for p,(old,new) in changes.items())
(art/'lido-composed-quotes.patch').write_text(patch)
(art/'lido-composed-quotes-prepared.json').write_text(json.dumps({'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PREPARED_NOT_APPLIED_OR_VALIDATED','scope':'Lido standard provider projections for non-rebasing accounting assets WETH and wstETH, with existing WETH/stETH/wstETH payment conversions; no deployment allowlist','files':list(changes),'remaining':['Review exact fractional receipt accounting against real Lido fork','Apply only after current full build exits','Compile and run actual package tests before any completion claim']},indent=2)+'\n')
print('Prepared',len(changes),'files; main sources unchanged')
