// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {StandardExchangeReleaseBehavior} from "../remediation/StandardExchangeReleaseBehavior.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/// @dev External router fixture. The payer approves this router, never the vault.
contract FullSpreadTransferRouter {
    function deposit(IERC20 token, address vault, uint256 amount, address recipient) external returns (uint256) {
        token.transferFrom(msg.sender, vault, amount);(uint256 quotedAmountOut,uint256 refund) = IStandardExchangeIn(vault).exchangeIn(token, amount, IERC20(vault), 0, recipient, true, block.timestamp);
        if (refund != 0) token.transfer(msg.sender, refund);
        return quotedAmountOut;
    }
}

/// @dev External metadata failure fixture; the real diamond and pool remain the SUT.
contract FullSpreadRevertingMetadataToken {
    string public constant name = "Reverting metadata";
    string public constant symbol = "META";
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function decimals() external pure returns (uint8) { revert("metadata unavailable"); }
    function mint(address to, uint256 amount) external returns (bool) { balanceOf[to] += amount; return true; }
    function approve(address spender, uint256 amount) external returns (bool) { allowance[msg.sender][spender] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) { balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true; }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

/// @dev Independently funded LP using real mint/modifyLiquidity and protocol callbacks.
contract FullSpreadLiquidityProvider {
    using BalanceDeltaLibrary for BalanceDelta;
    address private active;
    IWETH private weth;
    receive() external payable {}
    function addV3(IUniswapV3Pool pool, uint128 liquidity) external {
        active = address(pool);
        pool.mint(address(this), -887220, 887220, liquidity, "");
        active = address(0);
    }
    function uniswapV3MintCallback(uint256 a, uint256 b, bytes calldata) external {
        require(msg.sender == active, "pool");
        IERC20(IUniswapV3Pool(active).token0()).transfer(active, a);
        IERC20(IUniswapV3Pool(active).token1()).transfer(active, b);
    }
    function addV4(IPoolManager manager, PoolKey memory key, IWETH wrapped, uint128 liquidity) external {
        active = address(manager); weth = wrapped;
        manager.unlock(abi.encode(key, liquidity)); active = address(0);
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == active, "manager");
        (PoolKey memory key, uint128 liquidity) = abi.decode(data, (PoolKey,uint128));
        IPoolManager manager = IPoolManager(active);
        (BalanceDelta delta,) = manager.modifyLiquidity(key,
            ModifyLiquidityParams(-887220, 887220, int256(uint256(liquidity)), bytes32(0)), "");
        _settle(manager, key.currency0, delta.amount0()); _settle(manager, key.currency1, delta.amount1());
        return "";
    }
    function _settle(IPoolManager manager, Currency currency, int128 delta) private {
        if (delta >= 0) return;
        uint256 amount = uint128(-delta);
        if (Currency.unwrap(currency) == address(0)) {
            weth.withdraw(amount); manager.settle{value: amount}();
        } else {
            manager.sync(currency); IERC20(Currency.unwrap(currency)).transfer(address(manager), amount); manager.settle();
        }
    }
}

/// @notice A0/I/E6/J/H security controls under the V3 accounting PRD.
/// @dev Same-pool manipulation exposure is accepted by ACC-18; booked custody
/// cannot subsidize funding. No retired sleeve or SY route is restored.
abstract contract StandardExchangeFullSpreadAdversarialBehavior is StandardExchangeReleaseBehavior {
    function _seedMarket() internal virtual;
    function _setDecimalFixture(uint8 da,uint8 db,bool failing) internal virtual;
    function _expectedAddedLiquidity(uint256 a,uint256 b) internal view virtual returns (uint128);

    function _join(uint256 a,uint256 b,address recipient) internal returns (uint256 shares) { (shares,)=_bundleDeposit(a,b,recipient); }
    function _decimalBoundary(uint8 da,uint8 db,bool failing) private {
        _setDecimalFixture(da,db,failing); _fund(asset0,address(this),1001); _fund(asset1,address(this),1001);
        uint128 atFloor=_expectedAddedLiquidity(1000,1000); assertLe(atFloor,1000);
        (uint256 quote,)=IStandardExchangeBundleIn(address(subject)).previewExchangeBundleInForSingleOut(_array(1000,1000),address(subject)); assertEq(quote,0);
        asset0.approve(address(subject),1001); asset1.approve(address(subject),1001);
        _reject(abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(1000,1000),address(subject),0,address(this),false,block.timestamp)),abi.encodeWithSelector(IVault.MinLiquidityNotMet.selector));
        uint128 added=_expectedAddedLiquidity(1001,1001); assertGt(added,1000);
        (quote,)=IStandardExchangeBundleIn(address(subject)).previewExchangeBundleInForSingleOut(_array(1001,1001),address(subject));
        assertEq(quote,uint256(added)-1000); assertEq(_join(1001,1001,address(this)),quote);
        assertEq(subject.balanceOf(address(0)),1000); assertEq(subject.balanceOf(address(0xdEaD)),0); assertEq(subject.totalSupply(),added); _assertAccounting();
    }
    function test_A0_fixedFloor_sixDecimals() public { _decimalBoundary(6,6,false); }
    function test_A0_fixedFloor_sixEighteen() public { _decimalBoundary(6,18,false); }
    function test_A0_fixedFloor_oddDecimalSum() public { _decimalBoundary(6,9,false); }
    function test_A0_fixedFloor_decimalSumBelowSix() public { _decimalBoundary(2,3,false); }
    function test_A0_revertingDecimalsDoesNotAffectLiquidityFloor() public { _decimalBoundary(18,18,true); }
    function test_A0_dustFirstMint_reverts() public { _decimalBoundary(18,18,false); }
    function _activationBoundary(bool blocked) private {
        if(blocked) _seedMarket();
        uint256 amount=1001; uint128 added=_expectedAddedLiquidity(amount,amount);
        bytes memory preview=abi.encodeCall(IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut,(_array(amount,amount),address(subject)));
        uint256 quote=blocked?_locked(preview,asset0,0):_execute(preview); assertEq(quote,uint256(added)-1000); assertEq(subject.totalSupply(),0);
        if(blocked) {
            _fund(asset0,address(lockedCaller),amount); _fund(asset1,address(lockedCaller),amount);
            bytes memory data=abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(amount,amount),address(subject),quote,address(this),true,block.timestamp));
            bytes32 beforeState=_stateDigest(); vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()"));
            lockedCaller.run(address(subject),data,_outputTokens(),_array(amount,amount)); assertEq(_stateDigest(),beforeState);
        } else { _fund(asset0,address(this),amount); _fund(asset1,address(this),amount); assertEq(_join(amount,amount,address(this)),quote); assertEq(subject.balanceOf(address(0)),1000); }
    }
    function test_A0_minimumPlusOne_previewAndExecution_idle() public { _activationBoundary(false); }
    function test_A0_minimumPlusOne_previewAndBlockedExecutionAtomic() public { _activationBoundary(true); }
    function test_A0_firstMintDonationVictimJoinCannotInflateAttacker() public {
        _seedMarket(); address attacker=makeAddr("first-minter"); address victim=makeAddr("victim"); uint256 first=1001; uint256 donation=1 ether;
        _fund(asset0,attacker,first+donation); _fund(asset1,attacker,first+donation); _fund(asset0,victim,donation); _fund(asset1,victim,donation);
        vm.startPrank(attacker); _join(first,first,attacker); asset0.transfer(address(subject),donation); asset1.transfer(address(subject),donation); vm.stopPrank();
        vm.startPrank(victim); _join(donation,donation,victim); vm.stopPrank();
        uint256 shares=subject.balanceOf(attacker); assertLt(shares*2,subject.totalSupply());
        vm.prank(attacker); (uint256[] memory paid,)=IStandardExchangeBundleOut(address(subject)).exchangeBundleOut(address(subject),shares,_outputTokens(),_array(0,0),attacker,false,block.timestamp);
        assertEq(subject.balanceOf(attacker),0); assertLe(paid[0],first); assertLe(paid[1],first);
        assertLe(asset0.balanceOf(attacker),first+donation); assertLe(asset1.balanceOf(attacker),first+donation); _assertAccounting();
    }
    function test_A0_ambientCustodyDoesNotMintResidualDeadShares() public {
        _stageInput(asset0,10 ether); _stageInput(asset1,10 ether); _fund(asset0,address(this),10 ether); _fund(asset1,address(this),10 ether);
        uint128 added=_expectedAddedLiquidity(10 ether,10 ether); uint256 issued=_join(10 ether,10 ether,address(this));
        assertEq(issued,uint256(added)-1000); assertEq(subject.totalSupply(),added); assertEq(subject.balanceOf(address(0)),1000); assertEq(subject.balanceOf(address(0xdEaD)),0);
        assertEq(asset0.balanceOf(address(subject)),10 ether); assertEq(asset1.balanceOf(address(subject)),10 ether); assertEq(_bookedBalance(0),0); assertEq(_bookedBalance(1),0); _assertAccounting();
    }
    function test_I_routerTransferFromUserToVault() public {
        _bootstrap(); FullSpreadTransferRouter router=new FullSpreadTransferRouter(); address user=makeAddr("router-user"); _fund(asset0,user,25 ether);
        (uint256 quote,uint256 refund)=subject.previewExchangeIn(asset0,25 ether,IERC20(address(subject)));
        vm.startPrank(user); asset0.approve(address(router),25 ether); uint256 issued=router.deposit(asset0,address(subject),25 ether,user); vm.stopPrank();
        assertEq(issued,quote); assertGt(issued,0); assertEq(subject.balanceOf(user),issued); assertEq(asset0.balanceOf(user),refund); assertEq(asset0.balanceOf(address(router)),0); assertEq(subject.balanceOf(address(router)),0); _assertAccounting();
    }
    function test_I1_pretransferredTrue_noDelivery_noFreeMint() public { _falseDeposit(true); }
    function test_I2_shortPushRefundsWithoutShares() public { _wrongTransfer(24 ether); }
    function test_I2_excessExactIn_creditsRequestedOnly() public { test_APEX001M_excessPushedTransferCreditsRequestedOnly(); }
    function test_I2_bundleOneExcessLegCreditsDeclaredAmountsOnly() public {
        _bootstrap(); AtomicPretransferCaller caller=new AtomicPretransferCaller(); _stageInput(asset0,10 ether); _stageInput(asset1,11 ether);
        (uint256 quote,uint256[] memory refunds)=IStandardExchangeBundleIn(address(subject)).previewExchangeBundleInForSingleOut(_array(10 ether,10 ether),address(subject));
        (uint256 issued,uint256[] memory paidRefunds)=abi.decode(caller.execute(address(subject),abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(10 ether,10 ether),address(subject),quote,FALSE_DEPOSITOR,true,block.timestamp))),(uint256,uint256[]));
        assertEq(issued,quote); assertEq(paidRefunds,refunds); assertEq(subject.balanceOf(FALSE_DEPOSITOR),issued);
        assertEq(asset0.balanceOf(address(caller)),refunds[0]); assertEq(asset1.balanceOf(address(caller)),refunds[1]); assertEq(asset1.balanceOf(address(subject))-_bookedBalance(1),1 ether); _assertAccounting();
    }
    function test_I3_consumedPushCannotFundSecondUnpaidMint() public { test_pullAndPushedDepositsAfterPriceMovement(); }
    function test_L1_poolTradeThenFalsePretransfer_noCredit() public { _falseDeposit(true); }
    function test_L3_spotSkew_noUnfundedMint() public { _falseDeposit(false); }
    function test_I_reservesExcludeCustodyAfterSwapAndFeeBooking() public {
        _bootstrap(); _trade(true,10 ether); _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        subject.exchangeIn(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp); assertGt(_bookedBalance(0),0); _assertAccounting(); _noCredit(asset0,1 ether,FALSE_DEPOSITOR);
    }
    function test_F5_maintenanceUnauthorizedCannotPayCaller() public {
        _bootstrap(); _trade(true,10 ether); vm.startPrank(FALSE_DEPOSITOR);
        _reject(abi.encodeCall(IVault.compound,()),abi.encodeWithSelector(IOperable.NotOperator.selector,FALSE_DEPOSITOR));
        _reject(abi.encodeCall(IVault.donate,(address(asset0),1 ether,false)),abi.encodeWithSelector(IOperable.NotOperator.selector,FALSE_DEPOSITOR)); vm.stopPrank();
        assertEq(asset0.balanceOf(FALSE_DEPOSITOR),0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),0); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0);
        uint256 supply=subject.totalSupply(); vm.prank(_feeOwner()); IVault(address(subject)).compound(); assertEq(subject.totalSupply(),supply); _assertAccounting();
    }
    function test_H_lockedExitAfterRetiredRebalanceRollsBack() public { test_lockedExitPreviewAvailableExecutionRollsBack(); _retired(abi.encodeWithSignature("rebalanceLiquidReserve()")); }
    function test_H_lockedExit_onePercentOfSupplyRollsBack() public { _lockedShareExit(100); }
    function _lockedShareExit(uint256 divisor) private {
        _bootstrap(); uint256 shares=subject.balanceOf(address(this))/divisor; subject.transfer(address(lockedCaller),shares); bytes32 beforeState=_stateDigest();
        vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()"));
        _locked(abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,0,address(this),false,block.timestamp)),asset0,0); assertEq(_stateDigest(),beforeState);
    }
    function test_H_positiveLegacySleeveCannotEnableLockedExit() public { _configureSleeve(0.2e18); _lockedShareExit(4); }
    function test_H_zeroLegacySleeveCannotEnableLockedExit() public { _configureSleeve(0); _lockedShareExit(4); }
    function test_L2_FoT_forbidden() public {
        DeliveryTestToken(address(asset1)).setFee(true); _fund(asset0,address(this),100 ether); _fund(asset1,address(this),100 ether); asset0.approve(address(subject),100 ether); asset1.approve(address(subject),100 ether);
        _reject(abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(100 ether,100 ether),address(subject),0,address(this),false,block.timestamp)),_deliveryError(100 ether,99 ether));
        assertEq(subject.totalSupply(),0); assertEq(asset0.balanceOf(address(this)),100 ether); assertEq(asset1.balanceOf(address(this)),100 ether); assertEq(asset0.allowance(address(this),address(subject)),100 ether); assertEq(asset1.allowance(address(this),address(subject)),100 ether);
    }
    function test_C1_nestedCurrentMoneyPathsRecordedAndPropagating() public {
        _bootstrap(); DeliveryTestToken token=DeliveryTestToken(address(asset1)); _fund(asset1,address(this),60 ether); asset1.approve(address(subject),60 ether);
        bytes[3] memory calls_=[_depositCall(asset1,1 ether,FALSE_DEPOSITOR),abi.encodeCall(IStandardExchangeBundleOut.exchangeBundleOut,(address(subject),1 ether,_outputTokens(),_array(0,0),FALSE_DEPOSITOR,false,block.timestamp)),abi.encodeCall(IVault.compound,())];
        for(uint256 i;i<calls_.length;++i) {
            token.setCallback(address(subject),calls_[i]); token.setCallbackPropagates(false);
            (uint256 issued,)=subject.exchangeIn(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp); assertGt(issued,0);
            assertEq(token.callbackError(),abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0); assertEq(asset0.balanceOf(FALSE_DEPOSITOR),0);
            token.setCallbackPropagates(true);
            _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp)),abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)); _assertAccounting();
        }
    }
    function test_CROPS_disabledCallerExitAllowedExactOutAndSYUnavailable() public {
        _bootstrap(); _disable(true,false);
        (uint256 paid,)=subject.exchangeIn(IERC20(address(subject)),1 ether,asset1,0,address(this),false,block.timestamp); assertGt(paid,0);
        _reject(abi.encodeCall(IStandardExchangeOut.exchangeOut,(IERC20(address(subject)),10 ether,asset1,1 ether,address(this),false,block.timestamp)),abi.encodeWithSignature("VaultDisabled(address)",address(subject)));
        _retired(abi.encodeCall(IStandardizedYield.redeem,(address(this),1 ether,address(asset1),0,false)));
        _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp)),abi.encodeWithSignature("VaultDisabled(address)",address(subject)));
    }
    function _refundFixture() private {
        _bootstrap(); _trade(true,100 ether); _trade(false,100 ether); _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        subject.exchangeIn(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp); assertGt(_bookedBalance(0),0); assertGt(_bookedBalance(1),0);
    }
    function _refundCase(bool blocked,uint8 mode) private {
        uint256 maximum=25 ether; uint256 delivered=mode==0?1 ether:mode==1?12 ether:mode==2?maximum:mode==3?maximum+1 ether:mode==4?maximum-1:0;
        uint256 booked=_bookedBalance(0); uint256 supply=subject.totalSupply();
        bytes memory data=_depositCall(asset0,maximum,FALSE_DEPOSITOR);
        if(blocked) {
            _fund(asset0,address(lockedCaller),delivered); bytes32 beforeState=_stateDigest();
            if(delivered>=maximum) { vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()")); _locked(data,asset0,delivered); assertEq(_stateDigest(),beforeState); }
            else { assertEq(_locked(data,asset0,delivered),0); assertEq(asset0.balanceOf(address(lockedCaller)),delivered); }
            assertEq(subject.totalSupply(),supply); assertEq(_bookedBalance(0),booked);
        } else {
            AtomicPretransferCaller caller=new AtomicPretransferCaller(); (uint256 quote,uint256 expectedRefund)=subject.previewExchangeIn(asset0,maximum,IERC20(address(subject)));
            (uint256 issued,uint256 refund)=_push(caller,asset0,delivered,data);
            if(delivered<maximum) { assertEq(issued,0); assertEq(refund,delivered); assertEq(subject.totalSupply(),supply); assertEq(_bookedBalance(0),booked); }
            else { assertEq(issued,quote); assertEq(refund,expectedRefund); assertEq(subject.balanceOf(FALSE_DEPOSITOR),quote); assertGe(_bookedBalance(0),booked); }
            assertEq(asset0.balanceOf(address(caller)),refund,"only current input refunded");
        }
        _assertAccounting();
    }
    function _refundMatrix(bool blocked) private { _refundFixture(); for(uint8 i;i<6;++i) { uint256 snap=vm.snapshotState(); _refundCase(blocked,i); assertTrue(vm.revertToState(snap)); } }
    function test_E6_oneTokenFatMaximumCannotRefundBookedCustody() public { _refundFixture(); _refundCase(false,0); }
    function test_E6_vaultHeldSharesCannotAuthorizeCallerBurn() public { test_vaultHeldSharesCannotFundCallerWithdrawal(); }
    function test_E6_oneTokenRefundMatrix_idle() public { _refundMatrix(false); }
    function test_E6_oneTokenRefundMatrix_blocked() public { _refundMatrix(true); }
    function _bundleRefund(bool shortLeg,bool blocked) private {
        _refundFixture(); uint256 a=100 ether; uint256 b=50 ether; uint256 supply=subject.totalSupply(); uint256 booked0=_bookedBalance(0); uint256 booked1=_bookedBalance(1);
        bytes memory data=abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(a,b),address(subject),0,FALSE_DEPOSITOR,true,block.timestamp));
        if(blocked) {
            _fund(asset0,address(lockedCaller),a); _fund(asset1,address(lockedCaller),b); bytes32 beforeState=_stateDigest();
            if(shortLeg) vm.expectRevert(bytes(""));
            else vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()"));
            lockedCaller.run(address(subject),data,_outputTokens(),_array(a,shortLeg?b-1:b)); assertEq(_stateDigest(),beforeState);
        } else {
            AtomicPretransferCaller caller=new AtomicPretransferCaller(); _stageInput(asset0,a); _stageInput(asset1,shortLeg?b-1:b);
            if(shortLeg) {
                bytes32 beforeState=_stateDigest(); (bool ok,bytes memory reason)=address(caller).call(abi.encodeCall(AtomicPretransferCaller.execute,(address(subject),data))); assertFalse(ok); assertEq(reason,bytes("")); assertEq(_stateDigest(),beforeState);
                assertEq(subject.totalSupply(),supply); assertEq(_bookedBalance(0),booked0); assertEq(_bookedBalance(1),booked1);
            } else {
                (uint256 quote,uint256[] memory refunds)=IStandardExchangeBundleIn(address(subject)).previewExchangeBundleInForSingleOut(_array(a,b),address(subject));
                (uint256 issued,uint256[] memory actual)=abi.decode(caller.execute(address(subject),data),(uint256,uint256[])); assertEq(issued,quote); assertEq(actual,refunds);
                assertEq(asset0.balanceOf(address(caller)),refunds[0]); assertEq(asset1.balanceOf(address(caller)),refunds[1]); assertGe(_bookedBalance(0),booked0); assertGe(_bookedBalance(1),booked1);
            }
        }
        _assertAccounting();
    }
    function test_E6_bundleRefundCannotPayBookedCustody() public { _bundleRefund(false,false); }
    function test_E6_bundleBlockedRefundIsAtomic() public { _bundleRefund(false,true); }
    function test_E6_bundleShortLegRejectsBeforeEitherLeg() public {
        uint256 snapshot=vm.snapshotState(); _bundleRefund(true,false); assertTrue(vm.revertToState(snapshot)); _bundleRefund(true,true);
    }
    function test_APEX005_callerShareExit_pretransferredEoaRejected() public {
        _bootstrap(); subject.transfer(FALSE_DEPOSITOR,100 ether); vm.startPrank(FALSE_DEPOSITOR); subject.transfer(address(subject),100 ether);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),100 ether,asset1,0,FALSE_DEPOSITOR,true,block.timestamp)),abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector)); vm.stopPrank(); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),0);
    }
    function test_I1_exactOutputNoDeliveryUnavailable() public { _bootstrap(); _unavailableOut(asset0,asset1,true); _unavailableOut(IERC20(address(subject)),asset1,true); }
    function test_I2_oversizedOneTokenMaximumRefundsActualOnly() public { _refundFixture(); _refundCase(false,4); }
    function test_I3_exactOutputCannotReplayStagedInput() public { _bootstrap(); _stageInput(asset0,25 ether); _unavailableOut(asset0,asset1,true); _unavailableOut(asset0,asset1,true); }
    function test_J1_currentTargetSelectorsHaveUniqueFacetOwners() public view { test_everyCurrentTargetSelectorIsInstalledOnRegistryProxy(); }
    function test_J2_allCurrentTargetSelectorsInstalledOnProxy() public view { test_everyCurrentTargetSelectorIsInstalledOnRegistryProxy(); }
    function test_J3_proxyFundedMoneyPathsAndRemovedPrepare() public {
        test_proxyRemovedPreparationSurface(); _bootstrap(); _fund(asset0,address(this),10 ether); asset0.approve(address(subject),10 ether);
        (uint256 quote,)=subject.previewExchangeIn(asset0,10 ether,IERC20(address(subject))); (uint256 issued,)=subject.exchangeIn(asset0,10 ether,IERC20(address(subject)),quote,address(this),false,block.timestamp); assertEq(issued,quote);
        (uint256 exitQuote,)=subject.previewExchangeIn(IERC20(address(subject)),issued,asset1); (uint256 paid,)=subject.exchangeIn(IERC20(address(subject)),issued,asset1,exitQuote,FALSE_DEPOSITOR,false,block.timestamp); assertEq(paid,exitQuote); _unavailableOut(IERC20(address(subject)),asset1,false); _assertAccounting();
    }
    function test_J3_retiredSYAndQuoteSelectorsAbsentCurrentQueriesCallable() public {
        _bootstrap(); bytes4[16] memory removed=[IStandardizedYield.deposit.selector,IStandardizedYield.redeem.selector,IStandardizedYield.rewardIndexesCurrent.selector,IStandardizedYield.claimRewards.selector,IStandardizedYield.exchangeRate.selector,IStandardizedYield.yieldToken.selector,IStandardizedYield.assetInfo.selector,IStandardizedYield.getTokensIn.selector,IStandardizedYield.getTokensOut.selector,IStandardizedYield.isValidTokenIn.selector,IStandardizedYield.isValidTokenOut.selector,IStandardizedYield.previewDeposit.selector,IStandardizedYield.previewRedeem.selector,IStandardizedYield.getRewardTokens.selector,IStandardizedYield.accruedRewards.selector,IStandardizedYield.rewardIndexesStored.selector];
        for(uint256 i;i<removed.length;++i) _retired(abi.encodeWithSelector(removed[i]));
        string[13] memory old=[string("deployedReserve()"),"targetLiquidReservePercentage()","actualLiquidReservePercentage(address)","localReserve(address)","quoteState(address,address)","quoteTotalSupply(bytes)","quoteShareBalance(bytes)","quoteAssets(bytes,uint256)","quoteExternalDeposit(bytes,address,uint256)","quoteExternalExchange(bytes,address,uint256)","quoteTransition(bytes,uint8,uint256)","rebalanceLiquidReserve()","unlockCallback(bytes)"];
        for(uint256 i;i<old.length;++i) _retired(abi.encodeWithSelector(bytes4(keccak256(bytes(old[i])))));
        assertGt(bytes(subject.name()).length,0); assertGt(bytes(subject.symbol()).length,0);
        (bool reservesOk,bytes memory reservesData)=address(subject).staticcall(abi.encodeWithSignature("reserves()"));
        assertTrue(reservesOk); uint256[] memory reserves=abi.decode(reservesData,(uint256[])); assertEq(reserves.length,2);
        assertEq(reserves[0],subject.reserveOfToken(address(asset0))); assertEq(reserves[1],subject.reserveOfToken(address(asset1)));
        (bool ok,bytes memory data)=address(subject).staticcall(abi.encodeWithSignature("canOpenBoundPoolOps()")); assertTrue(ok); assertTrue(abi.decode(data,(bool))); _assertAccounting();
    }
    function _callerBundleExit(bool blocked) private {
        _bootstrap(); uint256 shares=subject.balanceOf(address(this))/10;
        if(blocked) {
            subject.transfer(address(lockedCaller),shares); bytes memory data=abi.encodeCall(IStandardExchangeBundleOut.exchangeBundleOut,(address(subject),shares,_outputTokens(),_array(0,0),FALSE_DEPOSITOR,false,block.timestamp)); bytes32 beforeState=_stateDigest();
            vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()")); _locked(data,asset0,0); assertEq(_stateDigest(),beforeState);
        } else {
            // Caller-held exact shares need no transferFrom allowance, even if a larger allowance exists.
            subject.approve(address(subject),shares*4); uint256 held=subject.balanceOf(address(this));
            (uint256[] memory paid,)=IStandardExchangeBundleOut(address(subject)).exchangeBundleOut(address(subject),shares,_outputTokens(),_array(0,0),FALSE_DEPOSITOR,false,block.timestamp);
            assertEq(subject.balanceOf(address(this)),held-shares); assertEq(subject.allowance(address(this),address(subject)),shares*4); assertEq(asset0.balanceOf(FALSE_DEPOSITOR),paid[0]); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),paid[1]); _assertAccounting();
        }
    }
    function test_callerBundleExitExactBurnLeavesAllowance_idle() public { _callerBundleExit(false); }
    function test_callerBundleExitExactBurnBlockedAtomic() public { _callerBundleExit(true); }
}
