// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;
import {StandardExchangeDeliveryBehavior} from "./StandardExchangeDeliveryBehavior.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DeliveryTestToken} from "./DeliveryTestToken.sol";

/// @notice Release security under V3-ACC-15/16/17 and V3-OWN-05.
abstract contract StandardExchangeReleaseBehavior is StandardExchangeDeliveryBehavior {
    function _family() internal pure virtual returns (string memory);
    function _disable(bool disabled, bool packageWide) internal virtual;
    function _configureSleeve(uint256 pct) internal virtual;

    function _feeOwner() internal view returns (address) {
        address oracle = address(uint160(uint256(vm.load(address(subject),keccak256("indexedex.vaults.standard.vault")))));
        return address(IVaultFeeOracleQuery(oracle).feeTo());
    }
    function _retired(bytes memory data) internal {
        bytes4 selector; assembly ("memory-safe") { selector := mload(add(data,32)) }
        assertEq(IDiamondLoupe(address(subject)).facetAddress(selector),address(0),"retired selector absent");
        _reject(data,abi.encodeWithSelector(Proxy.NoTargetFor.selector,selector));
    }
    function _disabledExit(bool packageWide) private {
        _bootstrap(); _disable(true,packageWide);
        _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp)),abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector,address(subject)));
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,1 ether,asset1,0,address(this),false,block.timestamp)),abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector,address(subject)));
        _reject(abi.encodeCall(IStandardExchangeOut.exchangeOut,(IERC20(address(subject)),10 ether,asset1,1 ether,address(this),false,block.timestamp)),abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector,address(subject)));
        uint256 shares=subject.balanceOf(address(this))/20; (uint256 quote,)=subject.previewExchangeIn(IERC20(address(subject)),shares,asset1);
        (uint256 paid,)=subject.exchangeIn(IERC20(address(subject)),shares,asset1,quote,FALSE_DEPOSITOR,false,block.timestamp);
        assertEq(paid,quote); assertGt(paid,0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),paid);
        _disable(false,packageWide); (uint256 issued,)=subject.exchangeIn(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp); assertGt(issued,0);
    }
    function test_disabledVaultRejectsDepositButPermitsWithdrawals() public { _disabledExit(false); }
    function test_disabledPackageRejectsDepositButPermitsWithdrawals() public { _disabledExit(true); }
    function test_callerShareWithdrawalNeedsNoAllowance() public {
        _bootstrap(); uint256 held=subject.balanceOf(address(this)); assertEq(subject.allowance(address(this),address(subject)),0);
        (uint256 quote,)=subject.previewExchangeIn(IERC20(address(subject)),1 ether,asset1);
        (uint256 out,)=subject.exchangeIn(IERC20(address(subject)),1 ether,asset1,quote,address(this),false,block.timestamp);
        assertEq(out,quote); assertGt(out,0); assertEq(subject.balanceOf(address(this)),held-1 ether);
    }
    function test_retiredInternalSYCannotBurnVaultHeldShares() public {
        _bootstrap(); subject.transfer(address(subject),3 ether);
        _retired(abi.encodeCall(IStandardizedYield.redeem,(address(this),1 ether,address(asset1),0,true)));
        _retired(abi.encodeCall(IStandardizedYield.redeem,(address(this),4 ether,address(asset1),0,true)));
        assertEq(subject.balanceOf(address(subject)),3 ether); assertEq(subject.reserveOfToken(address(subject)),0);
    }
    function test_callerWithdrawalRecipientAndUnfundedCallerDenied() public {
        _bootstrap(); subject.transfer(address(subject),3 ether);
        (uint256 out,)=subject.exchangeIn(IERC20(address(subject)),1 ether,asset1,0,FALSE_DEPOSITOR,false,block.timestamp);
        assertGt(out,0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),out);
        vm.startPrank(FALSE_DEPOSITOR);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),1 ether,asset1,0,FALSE_DEPOSITOR,false,block.timestamp)),abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",FALSE_DEPOSITOR,0,1 ether));
        vm.stopPrank(); assertEq(subject.balanceOf(address(subject)),3 ether);
    }
    function testFuzz_legacySleeveRatioDoesNotChangeDeposit(bool side,uint8 seed) public {
        _bootstrap(); IERC20 input=side?asset0:asset1;
        (uint256 quote,uint256 refund)=subject.previewExchangeIn(input,1 ether,IERC20(address(subject)));
        uint256[4] memory ratios=[uint256(0.02e18),0.2e18,0.5e18,1e18]; _configureSleeve(ratios[seed%4]);
        (uint256 afterQuote,uint256 afterRefund)=subject.previewExchangeIn(input,1 ether,IERC20(address(subject)));
        assertEq(afterQuote,quote); assertEq(afterRefund,refund);
        _fund(input,address(this),1 ether); input.approve(address(subject),1 ether);
        (uint256 out,uint256 actualRefund)=subject.exchangeIn(input,1 ether,IERC20(address(subject)),quote,address(this),false,block.timestamp);
        assertEq(out,quote); assertEq(actualRefund,refund); _assertAccounting();
    }
    function test_sharePermitAuthorizesOnlySignedSpenderAndCannotReplay() public {
        _bootstrap(); uint256 key=0xA11CE; address holder=vm.addr(key); subject.transfer(holder,2 ether);
        IERC20Permit permit=IERC20Permit(address(subject));
        bytes32 structHash=keccak256(abi.encode(keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),holder,address(this),1 ether,permit.nonces(holder),block.timestamp+100));
        (uint8 v,bytes32 r,bytes32 s)=vm.sign(key,keccak256(abi.encodePacked(hex"1901",permit.DOMAIN_SEPARATOR(),structHash)));
        permit.permit(holder,address(this),1 ether,block.timestamp+100,v,r,s); subject.transferFrom(holder,address(this),1 ether);
        assertEq(subject.balanceOf(holder),1 ether); assertEq(permit.nonces(holder),1);
        vm.expectPartialRevert(bytes4(0x4b800e46)); permit.permit(holder,address(this),1 ether,block.timestamp+100,v,r,s);
        vm.expectPartialRevert(bytes4(0xfb8f41b2)); subject.transferFrom(holder,address(this),1 ether);
    }
    function _assertImplementationOnlySelector(bytes4 selector) internal view returns (bool) {
        if (selector != bytes4(keccak256("UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()"))) return false;
        IDiamondLoupe loupe=IDiamondLoupe(address(subject)); assertEq(loupe.facetAddress(selector),address(0));
        (bool ok,bytes memory data)=loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector).staticcall(abi.encodeWithSelector(selector));
        assertTrue(ok); assertEq(data.length,32); assertGt(abi.decode(data,(address)).code.length,0); return true;
    }
    function test_everyCurrentTargetSelectorIsInstalledOnRegistryProxy() public view {
        string[9] memory targets=[string("InTarget"),"InQueryTarget","OutExecuteTarget","OutQueryTarget","PositionImportTarget","ReserveTarget","BundleTarget","BundleQueryTarget","MaintenanceTarget"];
        string[9] memory owners=[string("InFacet"),"InQueryFacet","OutFacet","OutQueryFacet","PositionImportFacet","ReserveFacet","BundleFacet","BundleQueryFacet","MaintenanceFacet"];
        IDiamondLoupe loupe=IDiamondLoupe(address(subject));
        for (uint256 i;i<targets.length;++i) {
            string memory name=string.concat("UniswapV3FullSpreadStandardExchangeVault",targets[i]);
            string[] memory signatures=vm.parseJsonKeys(vm.readFile(string.concat("out/",name,".sol/",name,".json")),".methodIdentifiers");
            assertGt(signatures.length,0,"current Target ABI is nonempty");
            for (uint256 j;j<signatures.length;++j) {
                bytes4 selector=bytes4(keccak256(bytes(signatures[j]))); if (_assertImplementationOnlySelector(selector)) continue;
                address facet=loupe.facetAddress(selector); assertGt(facet.code.length,0,signatures[j]);
                string memory expectedOwner=owners[i];
                if(selector==bytes4(keccak256("canOpenBoundPoolOps()"))) expectedOwner="ReserveFacet";
                if(selector==bytes4(keccak256("uniswapV3MintCallback(uint256,uint256,bytes)"))
                    || selector==bytes4(keccak256("uniswapV3SwapCallback(int256,int256,bytes)"))) expectedOwner="InFacet";
                assertEq(IFacet(facet).facetName(),string.concat("UniswapV3FullSpreadStandardExchangeVault",expectedOwner),signatures[j]);
                uint256 declarations; uint256 installations; IDiamondLoupe.Facet[] memory cuts=loupe.facets();
                for (uint256 k;k<cuts.length;++k) {
                    bytes4[] memory declared=IFacet(cuts[k].facetAddress).facetFuncs();
                    // The package installs only vaultTokens from BasicVault.
                    // Its unused reserve declarations are not competing owners.
                    if (cuts[k].facetAddress == facet) {
                        for (uint256 n;n<declared.length;++n) if(declared[n]==selector) ++declarations;
                    }
                    for (uint256 n;n<cuts[k].functionSelectors.length;++n) if(cuts[k].functionSelectors[n]==selector) ++installations;
                }
                assertEq(declarations,1,"Target selector declared by its installed facet"); assertEq(installations,1,"Target selector installed exactly once");
            }
        }
        assertFalse(IERC165(address(subject)).supportsInterface(type(IStandardizedYield).interfaceId),"SY retired");
    }
    function test_failedCallerWithdrawalMinimumRollsBackAndCanRetry() public {
        _bootstrap(); (uint256 quote,)=subject.previewExchangeIn(IERC20(address(subject)),1 ether,asset1);
        bytes memory bad=abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),1 ether,asset1,quote+1,address(this),false,block.timestamp));
        _reject(bad,abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector,quote+1,quote));
        (uint256 paid,)=subject.exchangeIn(IERC20(address(subject)),1 ether,asset1,quote,address(this),false,block.timestamp); assertEq(paid,quote);
    }
    function test_transferCallbackCannotBurnOwnedCallerSharesMidDeposit() public {
        _bootstrap(); DeliveryTestToken token=DeliveryTestToken(address(asset1)); subject.transfer(address(token),2 ether);
        token.setCallback(address(subject),abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),1 ether,asset0,0,FALSE_DEPOSITOR,false,block.timestamp)));
        _fund(asset1,address(this),10 ether); asset1.approve(address(subject),10 ether);
        (uint256 out,)=subject.exchangeIn(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertGt(out,0); assertEq(token.callbackError(),abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)); assertEq(subject.balanceOf(address(token)),2 ether); assertEq(asset0.balanceOf(FALSE_DEPOSITOR),0);
    }
    function test_transferCallbackCannotExchangeMidDeposit() public { test_transferCallbackCannotReenter(); }
    function test_retiredInternalSYMinimumCannotAlterContext() public {
        _bootstrap(); subject.transfer(address(subject),3 ether);
        _retired(abi.encodeCall(IStandardizedYield.redeem,(FALSE_DEPOSITOR,1 ether,address(asset1),type(uint256).max,true)));
        _retired(abi.encodeCall(IStandardizedYield.redeem,(FALSE_DEPOSITOR,1 ether,address(asset1),0,true)));
        vm.startPrank(FALSE_DEPOSITOR);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),1 ether,asset1,0,FALSE_DEPOSITOR,false,block.timestamp)),abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",FALSE_DEPOSITOR,0,1 ether));
        vm.stopPrank(); assertEq(subject.balanceOf(address(subject)),3 ether);
    }
}
