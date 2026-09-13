"""Share live/projected rate logic and wire it into the composed V4 quote."""
from pathlib import Path
import json,datetime,hashlib
root=Path.cwd(); changes=[]
def save(p,b,s):
 assert b!=s,p
 p.write_text(s);changes.append({'path':str(p.relative_to(root)), 'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
base=root/'contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange'
imp='import {IStandardExchangeTransitionQuote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\n'
p=base/'StandardExchangeRateProviderFacet.sol';b=p.read_text();s=b.replace('import {IStandardExchange}',imp+'import {IStandardExchange}',1)
s=s.replace('function getRate() external view returns (uint256) {','''function getRate() external view returns (uint256) {
        return _getRate("");
    }

    function quoteRate(address exchange, address asset, bytes calldata state) external view returns (uint256) {
        StandardExchangeRateProviderRepo.Storage storage l = StandardExchangeRateProviderRepo._layout();
        address subject = address(l.rateSubject);
        if (subject == address(0)) subject = address(l.reserveVault);
        // An independent subject keeps its live rate. The projected state belongs
        // only to the supplied SE and is denominated in its selected quote asset.
        if (exchange != address(l.reserveVault) || asset != address(l.rateTarget) || subject != exchange) {
            return _getRate("");
        }
        return _getRate(state);
    }

    function _getRate(bytes memory state) private view returns (uint256) {''',1)
s=s.replace('uint256 totalShares = subject_.totalSupply();','uint256 totalShares = state.length == 0 ? subject_.totalSupply()\n            : IStandardExchangeTransitionQuote(address(layoutStruct.reserveVault)).quoteTotalSupply(state);',1)
s=s.replace('quoteAmount, layoutStruct.rateTarget);','quoteAmount, layoutStruct.rateTarget, state);').replace('nextQuote, layoutStruct.rateTarget);','nextQuote, layoutStruct.rateTarget, state);')
s=s.replace('IERC20 rateTarget_\n    )','IERC20 rateTarget_,\n        bytes memory state\n    )',1)
needle='        try reserveVault_.previewExchangeIn(subject_, quoteAmount_, rateTarget_)'
s=s.replace(needle,'''        if (state.length != 0) {
            try IStandardExchangeTransitionQuote(address(reserveVault_)).quoteAssets(state, quoteAmount_)
                returns (uint256 quotedOut) { return (true, quotedOut); }
            catch { return (false, 0); }
        }
'''+needle,1)
s=s.replace('new bytes4[](2)','new bytes4[](3)').replace('interfaces_[1] = type(IStandardExchangeRateProvider).interfaceId;', 'interfaces_[1] = type(IStandardExchangeRateProvider).interfaceId;\n        interfaces_[2] = type(IStandardExchangeRateQuote).interfaceId;')
s=s.replace('funcs_ = new bytes4[](3)','funcs_ = new bytes4[](4)').replace('funcs_[2] = IStandardExchangeRateProvider.rateTarget.selector;', 'funcs_[2] = IStandardExchangeRateProvider.rateTarget.selector;\n        funcs_[3] = IStandardExchangeRateQuote.quoteRate.selector;');save(p,b,s)
p=base/'StandardExchangeRateProviderDFPkg.sol';b=p.read_text();s=b.replace('import {IStandardExchange}',imp+'import {IStandardExchange}',1).replace('interfaces_ = new bytes4[](1)','interfaces_ = new bytes4[](2)').replace('interfaces_[0] = type(IRateProvider).interfaceId;', 'interfaces_[0] = type(IRateProvider).interfaceId;\n        interfaces_[1] = type(IStandardExchangeRateQuote).interfaceId;');save(p,b,s)
p=base/'wrapped/WrappedStandardExchangeRateProviderTarget.sol';b=p.read_text();s=b.replace('import {IRateProvider}',imp+'import {IRateProvider}',1)
s=s.replace('function getRate() public view returns (uint256) {','''function getRate() public view returns (uint256) {
        return _getRate("");
    }

    function quoteRate(address exchange, address asset, bytes calldata state) external view returns (uint256) {
        WrappedStandardExchangeRateProviderRepo.Storage storage l = WrappedStandardExchangeRateProviderRepo._layoutStruct();
        if (exchange != address(l.standardExchange) || asset != address(l.rateTarget)
            || address(l.reserveVaultToken) != exchange) return _getRate("");
        return _getRate(state);
    }

    function _getRate(bytes memory state) private view returns (uint256) {''',1)
s=s.replace('reserveShareAmount, layoutStruct.rateTarget','reserveShareAmount, layoutStruct.rateTarget, state').replace('nextRedeem, layoutStruct.rateTarget','nextRedeem, layoutStruct.rateTarget, state')
s=s.replace('IERC20 rateTarget_\n\t)', 'IERC20 rateTarget_,\n        bytes memory state\n\t)',1)
needle='\t\ttry standardExchange_.previewExchangeIn(reserveVaultToken_, reserveShareAmount_, rateTarget_)'
s=s.replace(needle,'''        if (state.length != 0) {
            try IStandardExchangeTransitionQuote(address(standardExchange_)).quoteAssets(state, reserveShareAmount_)
                returns (uint256 quotedOut) { return (true, quotedOut); }
            catch { return (false, 0); }
        }
'''+needle,1);save(p,b,s)
for name in ('Facet','DFPkg'):
 p=base/f'wrapped/WrappedStandardExchangeRateProvider{name}.sol';b=p.read_text();s=b.replace('import {IRateProvider}',imp+'import {IRateProvider}',1).replace('interfaces_ = new bytes4[](2)','interfaces_ = new bytes4[](3)').replace('interfaces_[1] = type(IWrappedStandardExchangeRateProvider).interfaceId;','interfaces_[1] = type(IWrappedStandardExchangeRateProvider).interfaceId;\n        interfaces_[2] = type(IStandardExchangeRateQuote).interfaceId;')
 if name=='Facet':s=s.replace('funcs_ = new bytes4[](4)','funcs_ = new bytes4[](5)').replace('funcs_[3] = IWrappedStandardExchangeRateProvider.rateTarget.selector;','funcs_[3] = IWrappedStandardExchangeRateProvider.rateTarget.selector;\n        funcs_[4] = IStandardExchangeRateQuote.quoteRate.selector;')
 save(p,b,s)
(root/'implementation-artifacts/detf-funded-staking/se-dependent-rate-projection.json').write_text(json.dumps({'status':'APPLIED_TESTS_AND_HOST_WIRING_PENDING','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':changes},indent=2)+'\n')
print(len(changes),'rate provider files updated')
