// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial} from "./TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial.sol";

/// @notice F6 receipt parity retained for exact-in; ACC-17 retires successful exact-out.
contract UniswapV3FullSpreadStandardExchangeVault_F6Diagnostic is TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial {
    function _prepareF6() private returns (uint256 burn) {
        _seedMarket(); _fund(asset0,address(this),1500 ether); _fund(asset1,address(this),1000 ether);
        return _join(1000 ether,1000 ether,address(this))/10;
    }
    function _advanceF6(uint256 state) private {
        if(state==1) {
            asset0.approve(address(subject),500 ether);
            subject.exchangeIn(asset0,500 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
        } else if(state==2) { _trade(true,100 ether); _trade(false,100 ether); }
        else if(state==3) { vm.prank(_feeOwner()); IVault(address(subject)).compound(); }
    }
    function test_F6_exactInPreviewEqualsReceiptAcrossFeeAndMaintenanceStates() public {
        uint256 burn=_prepareF6();
        for(uint256 state;state<4;++state) {
            _advanceF6(state); _assertReceipt(asset0,burn); _assertReceipt(asset1,burn);
        }
    }
    function _assertReceipt(IERC20 tokenOut,uint256 burn) private {
        uint256 snapshot=vm.snapshotState(); uint256 supply=subject.totalSupply(); uint256 held=subject.balanceOf(address(this));
        (uint256 preview,)=subject.previewExchangeIn(IERC20(address(subject)),burn,tokenOut); assertGt(preview,0,"F6 payable preview");
        uint256 beforeBalance=tokenOut.balanceOf(FALSE_DEPOSITOR);
        (uint256 paid,uint256 refund)=subject.exchangeIn(IERC20(address(subject)),burn,tokenOut,preview,FALSE_DEPOSITOR,false,block.timestamp);
        assertEq(paid,preview,"F6 full receipt equals preview to the wei"); assertEq(tokenOut.balanceOf(FALSE_DEPOSITOR)-beforeBalance,paid);
        assertEq(refund,0); assertEq(subject.balanceOf(address(this)),held-burn); assertEq(subject.totalSupply(),supply-burn);
        _assertAccounting(); assertTrue(vm.revertToState(snapshot));
    }
    function test_F6_exactOutUnavailableAcrossFeeAndMaintenanceStates() public {
        _prepareF6();
        for(uint256 state;state<4;++state) {
            _advanceF6(state);
            _unavailableOut(IERC20(address(subject)),asset0,false); _unavailableOut(IERC20(address(subject)),asset1,true);
            _unavailableOut(asset0,IERC20(address(subject)),false); _unavailableOut(asset1,asset0,true);
        }
    }
}
