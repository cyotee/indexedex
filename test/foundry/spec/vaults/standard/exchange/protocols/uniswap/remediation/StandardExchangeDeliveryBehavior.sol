// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/libraries/LiquidityAmounts.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {StandardExchangeLockedCaller} from "./StandardExchangeLockedCaller.sol";
import {DeliveryTestToken} from "./DeliveryTestToken.sol";

/// @notice V3-ACC-09/10 delivery and custody assertions on real registered proxies.
/// @dev Historical virtual hooks stay source-compatible with the Delivery adapter.
abstract contract StandardExchangeDeliveryBehavior is Test {
    StandardExchangeLockedCaller internal lockedCaller;
    IStandardExchangeProxy internal subject;
    IERC20 internal asset0;
    IERC20 internal asset1;
    address internal constant FALSE_DEPOSITOR = address(0xBAD);
    bytes32 private constant BOOK_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v3.vault");

    function _trade(bool zeroForOne, uint256 amount) internal virtual;
    function _deployed() internal view virtual returns (uint256, uint256);
    function _rebalance() internal virtual;

    function _fund(IERC20 token, address recipient, uint256 amount) internal virtual {
        ERC20PermitMintableStub(address(token)).mint(recipient, amount);
    }
    function _stageInput(IERC20 token, uint256 amount) internal {
        _fund(token,address(this),amount);
        token.transfer(address(subject),amount);
    }
    function _boundPool() internal view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(lockedCaller.boundPool());
    }
    function _deliveryPositionKey() internal view returns (bytes32) {
        IUniswapV3Pool p = _boundPool();
        return keccak256(abi.encodePacked(address(subject), TickMath.minUsableTick(p.tickSpacing()), TickMath.maxUsableTick(p.tickSpacing())));
    }
    function _deliveryLiquidity() internal view returns (uint128 liquidity) {
        (liquidity,,,,) = _boundPool().positions(_deliveryPositionKey());
    }
    function _bookedBalance(uint256 index) internal view returns (uint256) {
        return uint256(vm.load(address(subject), bytes32(uint256(BOOK_SLOT) + 1 + index)));
    }
    function _array(uint256 a, uint256 b) internal pure returns (uint256[] memory values) {
        values = new uint256[](2); values[0] = a; values[1] = b;
    }
    function _outputTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2); tokens[0] = address(asset0); tokens[1] = address(asset1);
    }
    function _bundleDeposit(uint256 a, uint256 b, address recipient) internal returns (uint256 shares, uint256[] memory refunds) {
        asset0.approve(address(subject), a); asset1.approve(address(subject), b);
        return IStandardExchangeBundleIn(address(subject)).exchangeBundleInForSingleOut(_array(a,b), address(subject), 0, recipient, false, block.timestamp);
    }
    function _bootstrap() internal {
        _fund(asset0, address(this), 1000 ether); _fund(asset1, address(this), 1000 ether);
        (uint256 shares,) = _bundleDeposit(1000 ether, 1000 ether, address(this));
        assertGt(shares, 0, "funded genesis"); assertGt(_deliveryLiquidity(), 1000, "deployed position");
        assertEq(subject.balanceOf(address(0)), 1000, "fixed zero-address floor");
        _assertAccounting();
    }
    function _depositCall(IERC20 token, uint256 amount, address recipient) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn, (token, amount, IERC20(address(subject)), 0, recipient, true, block.timestamp));
    }
    function _deliveryError(uint256 required, uint256 delivered) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, required, delivered);
    }
    function _execute(bytes memory data) internal returns (uint256 result) {
        (bool ok, bytes memory returned) = address(subject).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned,32),mload(returned)) }
        return abi.decode(returned,(uint256));
    }
    function _stateDigest() internal view returns (bytes32 digest) {
        IUniswapV3Pool p = _boundPool();
        (bool ok, bytes memory state) = address(p).staticcall(abi.encodeWithSignature("positions(bytes32)", _deliveryPositionKey()));
        assertTrue(ok); digest = keccak256(abi.encode(state, subject.totalSupply(), subject.balanceOf(address(0)), subject.balanceOf(address(0xdEaD)), p.feeGrowthGlobal0X128(), p.feeGrowthGlobal1X128()));
        (uint160 price, int24 tick,,,,,bool unlocked) = p.slot0();
        digest = keccak256(abi.encode(digest, price, tick, unlocked));
        address[4] memory accounts = [address(this), address(subject), FALSE_DEPOSITOR, address(lockedCaller)];
        for (uint256 i; i < accounts.length; ++i) {
            digest = keccak256(abi.encode(digest, asset0.balanceOf(accounts[i]), asset1.balanceOf(accounts[i]), subject.balanceOf(accounts[i]), asset0.allowance(accounts[i],address(subject)), asset1.allowance(accounts[i],address(subject)), subject.allowance(accounts[i],address(subject))));
        }
        for (uint256 i; i <= 6; ++i) digest = keccak256(abi.encode(digest, vm.load(address(subject),bytes32(uint256(BOOK_SLOT)+i))));
        return keccak256(abi.encode(digest,asset0.balanceOf(address(p)),asset1.balanceOf(address(p))));
    }
    function _reject(bytes memory data, bytes memory expected) internal {
        bytes32 beforeState = _stateDigest();
        (bool ok, bytes memory returned) = address(subject).call(data);
        assertFalse(ok, "invalid operation succeeded"); assertEq(returned, expected, "specific failure");
        assertEq(_stateDigest(), beforeState, "tokens shares allowances position and ledgers unchanged");
    }
    function _assertAccounting() internal view {
        IUniswapV3Pool p = _boundPool();
        int24 lower = TickMath.minUsableTick(p.tickSpacing()); int24 upper = TickMath.maxUsableTick(p.tickSpacing());
        (uint128 liquidity, uint256 last0, uint256 last1, uint128 owed0, uint128 owed1) = p.positions(_deliveryPositionKey());
        (uint160 price, int24 tick,,,,,) = p.slot0();
        (uint256 principal0,uint256 principal1) = LiquidityAmounts.getAmountsForLiquidity(price,TickMath.getSqrtRatioAtTick(lower),TickMath.getSqrtRatioAtTick(upper),liquidity);
        (,,uint256 lo0,uint256 lo1,,,,) = p.ticks(lower); (,,uint256 hi0,uint256 hi1,,,,) = p.ticks(upper);
        uint256 inside0; uint256 inside1;
        unchecked {
            uint256 below0 = tick >= lower ? lo0 : p.feeGrowthGlobal0X128()-lo0;
            uint256 below1 = tick >= lower ? lo1 : p.feeGrowthGlobal1X128()-lo1;
            uint256 above0 = tick < upper ? hi0 : p.feeGrowthGlobal0X128()-hi0;
            uint256 above1 = tick < upper ? hi1 : p.feeGrowthGlobal1X128()-hi1;
            inside0 = p.feeGrowthGlobal0X128()-below0-above0-last0;
            inside1 = p.feeGrowthGlobal1X128()-below1-above1-last1;
        }
        assertEq(subject.reserveOfToken(address(asset0)), principal0+owed0+FullMath.mulDiv(inside0,liquidity,1<<128), "token0 deployed plus unpaid fees");
        assertEq(subject.reserveOfToken(address(asset1)), principal1+owed1+FullMath.mulDiv(inside1,liquidity,1<<128), "token1 deployed plus unpaid fees");
        assertEq(subject.reserveOfToken(address(subject)),0,"self-shares are not reserves");
        assertGe(asset0.balanceOf(address(subject)),_bookedBalance(0)); assertGe(asset1.balanceOf(address(subject)),_bookedBalance(1));
        for (uint256 i = 3; i <= 6; ++i) assertEq(vm.load(address(subject),bytes32(uint256(BOOK_SLOT)+i)),bytes32(0),"operation custody settled");
    }
    function _push(AtomicPretransferCaller caller, IERC20 token, uint256 delivered, bytes memory data) internal returns (uint256 out, uint256 refund) {
        _fund(token,address(caller),delivered);
        caller.execute(address(token),abi.encodeCall(IERC20.approve,(address(caller),delivered)));
        return abi.decode(caller.consumePretransfer(token,address(caller),address(subject),delivered,data),(uint256,uint256));
    }
    function _noCredit(IERC20 token, uint256 amount, address recipient) internal {
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = subject.totalSupply(); uint256 beforeShares = subject.balanceOf(recipient);
        (uint256 out,uint256 refund) = abi.decode(caller.execute(address(subject),_depositCall(token,amount,recipient)),(uint256,uint256));
        assertEq(out,0); assertEq(refund,0); assertEq(subject.totalSupply(),supply); assertEq(subject.balanceOf(recipient),beforeShares);
        _assertAccounting();
    }
    function _falseDeposit(bool zeroForOne) internal {
        _bootstrap();
        (uint160 beforePrice,,,,,,) = _boundPool().slot0();
        _trade(zeroForOne,100 ether);
        (uint160 afterPrice,,,,,,) = _boundPool().slot0();
        assertTrue(afterPrice != beforePrice, "real pool price moved");
        IERC20 token = zeroForOne ? asset0 : asset1;
        _fund(token,address(this),1 ether); token.approve(address(subject),1 ether);
        subject.exchangeIn(token,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertGt(_bookedBalance(zeroForOne ? 0 : 1),0,"existing booked custody is not deposit credit");
        uint256 supply = subject.totalSupply();
        vm.startPrank(FALSE_DEPOSITOR); _reject(_depositCall(token,25 ether,FALSE_DEPOSITOR),abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector)); vm.stopPrank();
        _noCredit(token,25 ether,FALSE_DEPOSITOR);
        assertEq(subject.totalSupply(),supply); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0); assertEq(token.balanceOf(FALSE_DEPOSITOR),0);
    }
    function _wrongTransfer(uint256 delivered) internal {
        _bootstrap(); AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = subject.totalSupply(); uint256 booked = _bookedBalance(0);
        _fund(asset0,address(caller),delivered);
        caller.execute(address(asset0),abi.encodeCall(IERC20.approve,(address(caller),delivered)));
        bytes memory minimumCall = abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,25 ether,IERC20(address(subject)),1,FALSE_DEPOSITOR,true,block.timestamp));
        bytes32 beforeState = _stateDigest();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector,1,0));
        caller.consumePretransfer(asset0,address(caller),address(subject),delivered,minimumCall);
        assertEq(_stateDigest(),beforeState); assertEq(asset0.balanceOf(address(caller)),delivered);
        assertEq(asset0.allowance(address(caller),address(caller)),delivered,"atomic failure restores caller approval");
        (uint256 out,uint256 refund) = abi.decode(caller.consumePretransfer(asset0,address(caller),address(subject),delivered,_depositCall(asset0,25 ether,FALSE_DEPOSITOR)),(uint256,uint256));
        assertEq(out,0); assertEq(refund,delivered); assertEq(asset0.balanceOf(address(caller)),delivered);
        assertEq(subject.totalSupply(),supply); assertEq(_bookedBalance(0),booked); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0);
        _fund(asset0,address(caller),25 ether-delivered);
        caller.execute(address(asset0),abi.encodeCall(IERC20.approve,(address(caller),25 ether)));
        (out,refund) = abi.decode(caller.consumePretransfer(asset0,address(caller),address(subject),25 ether,_depositCall(asset0,25 ether,FALSE_DEPOSITOR)),(uint256,uint256));
        assertGt(out,0); assertEq(subject.balanceOf(FALSE_DEPOSITOR),out); assertEq(asset0.balanceOf(address(caller)),refund);
        _assertAccounting();
    }
    function _locked(bytes memory data, IERC20 token, uint256 amount) internal returns (uint256) {
        address[] memory tokens = new address[](amount == 0 ? 0 : 1); uint256[] memory amounts = new uint256[](tokens.length);
        if (amount != 0) { tokens[0] = address(token); amounts[0] = amount; }
        return lockedCaller.run(address(subject),data,tokens,amounts);
    }
    function _unavailableOut(IERC20 input, IERC20 output, bool pushed) internal {
        assertEq(subject.previewExchangeOut(input,output,1 ether),0);
        _reject(abi.encodeCall(IStandardExchangeOut.exchangeOut,(input,100 ether,output,1 ether,address(this),pushed,block.timestamp)),abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector));
    }

    function test_priceMoveCannotCreditPhantomDeposit_token0() public { _falseDeposit(true); }
    function test_priceMoveCannotCreditPhantomDeposit_token1() public { _falseDeposit(false); }
    function test_APEX001M_eoaAndContractZeroInputNoFreeMint_token0() public { _falseDeposit(true); }
    function test_APEX001M_eoaAndContractZeroInputNoFreeMint_token1() public { _falseDeposit(false); }
    function test_pullAndPushedDepositsAfterPriceMovement() public {
        _bootstrap(); _trade(true,100 ether); _fund(asset0,address(this),20 ether); asset0.approve(address(subject),20 ether);
        uint256 before = asset0.balanceOf(address(this));
        (uint256 pulled,uint256 refund) = subject.exchangeIn(asset0,20 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertGt(pulled,0); assertEq(before-asset0.balanceOf(address(this)),20 ether-refund);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        (uint256 pushed,uint256 pushedRefund) = _push(caller,asset0,20 ether,_depositCall(asset0,20 ether,address(this)));
        assertGt(pushed,0); assertEq(asset0.balanceOf(address(caller)),pushedRefund); _noCredit(asset0,20 ether,FALSE_DEPOSITOR);
    }
    function test_shortPushedTransferRefundedWithoutShares() public { _wrongTransfer(24 ether); }
    function test_APEX001M_excessPushedTransferCreditsRequestedOnly() public {
        _bootstrap(); AtomicPretransferCaller caller = new AtomicPretransferCaller();
        (uint256 out,uint256 refund) = _push(caller,asset0,26 ether,_depositCall(asset0,25 ether,address(this)));
        assertGt(out,0); assertEq(asset0.balanceOf(address(caller)),refund);
        assertEq(asset0.balanceOf(address(subject))-_bookedBalance(0),1 ether,"above declaration stays unbooked"); _assertAccounting();
    }
    function test_fundedCallerMaySelectRecipient() public {
        _bootstrap(); AtomicPretransferCaller caller = new AtomicPretransferCaller();
        (uint256 out,uint256 refund) = _push(caller,asset0,25 ether,_depositCall(asset0,25 ether,FALSE_DEPOSITOR));
        assertGt(out,0); assertEq(subject.balanceOf(FALSE_DEPOSITOR),out); assertEq(subject.balanceOf(address(caller)),0); assertEq(asset0.balanceOf(address(caller)),refund);
    }
    function test_APEX001M_atomicFundedSucceedsAfterPriceMovement() public {
        _bootstrap(); _trade(true,100 ether); AtomicPretransferCaller caller = new AtomicPretransferCaller();
        (uint256 out,uint256 refund) = _push(caller,asset0,25 ether,_depositCall(asset0,25 ether,address(this)));
        assertGt(out,0); assertEq(asset0.balanceOf(address(caller)),refund); _assertAccounting();
    }
    function test_retiredRebalanceCannotCreatePushedCredit() public {
        _bootstrap(); _trade(true,100 ether);
        bytes4 sel = bytes4(keccak256("rebalanceLiquidReserve()")); _reject(abi.encodeWithSelector(sel),abi.encodeWithSelector(Proxy.NoTargetFor.selector,sel));
        _noCredit(asset0,25 ether,FALSE_DEPOSITOR);
    }
    function test_pushedBundleMissingSecondTokenRollsBackBothLegs() public {
        _bootstrap(); AtomicPretransferCaller caller = new AtomicPretransferCaller(); _stageInput(asset0,10 ether);
        bytes memory data = abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,(_array(10 ether,10 ether),address(subject),0,address(this),true,block.timestamp));
        bytes32 beforeState = _stateDigest(); (bool ok,bytes memory reason) = address(caller).call(abi.encodeCall(AtomicPretransferCaller.execute,(address(subject),data)));
        assertFalse(ok); assertEq(reason,bytes("")); assertEq(_stateDigest(),beforeState);
        _stageInput(asset1,10 ether); uint256 out = abi.decode(caller.execute(address(subject),data),(uint256)); assertGt(out,0); _assertAccounting();
    }
    function test_unfundedPassThroughAndUnavailableExactOutputCannotPay() public {
        _bootstrap(); AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data=abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,25 ether,asset1,0,FALSE_DEPOSITOR,true,block.timestamp));
        (uint256 out,uint256 refund)=abi.decode(caller.execute(address(subject),data),(uint256,uint256)); assertEq(out,0); assertEq(refund,0); _unavailableOut(asset0,asset1,true);
    }
    function test_exactOutputCannotSpendStagedUnderlying() public { _bootstrap(); _stageInput(asset0,25 ether); _unavailableOut(asset0,asset1,true); }
    function test_vaultHeldSharesCannotFundCallerWithdrawal() public {
        _bootstrap(); uint256 shares=subject.balanceOf(address(this))/10; subject.transfer(address(subject),shares);
        AtomicPretransferCaller caller=new AtomicPretransferCaller();
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",address(caller),0,shares));
        caller.execute(address(subject),abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,0,FALSE_DEPOSITOR,true,block.timestamp)));
        assertEq(subject.balanceOf(address(subject)),shares);
        subject.transfer(address(caller),shares-1);
        bytes32 beforeShort=_stateDigest();
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",address(caller),shares-1,shares));
        caller.execute(address(subject),abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,0,FALSE_DEPOSITOR,true,block.timestamp)));
        assertEq(_stateDigest(),beforeShort); assertEq(subject.balanceOf(address(caller)),shares-1);
        subject.transfer(address(caller),1);
        (uint256 quote,)=subject.previewExchangeIn(IERC20(address(subject)),shares,asset1);
        bytes memory data=abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,quote,FALSE_DEPOSITOR,true,block.timestamp));
        (uint256 paid,uint256 refund)=abi.decode(caller.execute(address(subject),data),(uint256,uint256));
        assertEq(paid,quote); assertGt(paid,0); assertEq(refund,0);
        assertEq(subject.balanceOf(address(caller)),0); assertEq(subject.balanceOf(address(subject)),shares);
        assertEq(asset1.balanceOf(FALSE_DEPOSITOR),paid);
        bytes32 beforeReplay=_stateDigest();
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",address(caller),0,shares));
        caller.execute(address(subject),data);
        assertEq(_stateDigest(),beforeReplay); _assertAccounting();
    }
    function test_vaultHeldSharesAreNotReserveCredit() public { test_vaultHeldSharesCannotFundCallerWithdrawal(); assertEq(subject.reserveOfToken(address(subject)),0); }
    function test_proxyRemovedPreparationSurface() public {
        bytes4 sel=bytes4(keccak256("preparePretransfer(address[],uint256[],bytes32)"));
        assertEq(IDiamondLoupe(address(subject)).facetAddress(sel),address(0)); assertFalse(IERC165(address(subject)).supportsInterface(sel));
        _reject(abi.encodeWithSelector(sel,new address[](0),new uint256[](0),bytes32(0)),abi.encodeWithSelector(Proxy.NoTargetFor.selector,sel)); assertEq(subject.decimals(),18);
    }
    function testFuzz_noPhantomCreditAfterTrade(bool side,uint96 amount) public { _bootstrap(); _trade(side,bound(uint256(amount),1e12,500 ether)); _noCredit(side?asset0:asset1,1 ether,FALSE_DEPOSITOR); }
    function test_lockedPushedDepositRollsBack() public {
        _bootstrap(); _fund(asset0,address(lockedCaller),20 ether); bytes32 beforeState=_stateDigest();
        vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()")); _locked(_depositCall(asset0,20 ether,address(this)),asset0,20 ether);
        assertEq(_stateDigest(),beforeState);
    }
    function test_lockedExitPreviewAvailableExecutionRollsBack() public {
        _bootstrap(); uint256 shares=subject.totalSupply()/10;
        (uint256 quote,)=subject.previewExchangeIn(IERC20(address(subject)),shares,asset1); assertGt(quote,0);
        assertEq(_locked(abi.encodeCall(IStandardExchangeIn.previewExchangeIn,(IERC20(address(subject)),shares,asset1)),asset0,0),quote);
        subject.transfer(address(lockedCaller),shares); bytes32 beforeState=_stateDigest();
        vm.expectRevert(abi.encodeWithSignature("UniswapV3Exchange_BoundPoolInteractionBlocked()"));
        _locked(abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,quote,address(this),false,block.timestamp)),asset0,0);
        assertEq(_stateDigest(),beforeState);
    }
    function test_lockedExactOutputRemainsUnavailable() public {
        _bootstrap(); vm.expectRevert(abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector));
        _locked(abi.encodeCall(IStandardExchangeOut.exchangeOut,(IERC20(address(subject)),100 ether,asset1,1 ether,address(this),false,block.timestamp)),asset0,0);
    }
    function test_exactOutputCannotConsumeVaultHeldShares() public { _bootstrap(); subject.transfer(address(subject),10 ether); _unavailableOut(IERC20(address(subject)),asset1,true); }
    function test_failedMinimumRollsBackCreditAndCanRetry() public {
        _bootstrap(); AtomicPretransferCaller caller=new AtomicPretransferCaller(); _fund(asset0,address(caller),20 ether);
        caller.execute(address(asset0),abi.encodeCall(IERC20.approve,(address(caller),20 ether))); bytes32 beforeState=_stateDigest();
        bytes memory bad=abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,20 ether,IERC20(address(subject)),type(uint256).max,address(this),true,block.timestamp));
        (uint256 quote,)=subject.previewExchangeIn(asset0,20 ether,IERC20(address(subject)));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector,type(uint256).max,quote));
        caller.consumePretransfer(asset0,address(caller),address(subject),20 ether,bad);
        assertEq(_stateDigest(),beforeState); assertEq(asset0.balanceOf(address(caller)),20 ether);
        uint256 out=abi.decode(caller.consumePretransfer(asset0,address(caller),address(subject),20 ether,_depositCall(asset0,20 ether,address(this))),(uint256)); assertEq(out,quote);
    }
    function test_feeOnTransferInputRejectedAndRolledBack() public {
        _bootstrap(); DeliveryTestToken(address(asset1)).setFee(true); _fund(asset1,address(this),100 ether); asset1.approve(address(subject),100 ether);
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset1,100 ether,IERC20(address(subject)),0,address(this),false,block.timestamp)),_deliveryError(100 ether,99 ether));
    }
    function test_transferCallbackCannotReenter() public {
        _bootstrap(); DeliveryTestToken token=DeliveryTestToken(address(asset1)); token.setCallback(address(subject),_depositCall(asset1,10 ether,FALSE_DEPOSITOR));
        _fund(asset1,address(this),10 ether); asset1.approve(address(subject),10 ether);
        (uint256 out,)=subject.exchangeIn(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertGt(out,0); assertEq(token.callbackError(),abi.encodeWithSelector(IReentrancyLock.IsLocked.selector)); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0);
    }
    function test_noPositionUnfundedGenesisCannotActivate() public {
        AtomicPretransferCaller caller=new AtomicPretransferCaller(); vm.expectRevert(abi.encodeWithSelector(IVault.MinLiquidityNotMet.selector)); caller.execute(address(subject),_depositCall(asset0,10 ether,FALSE_DEPOSITOR)); assertEq(subject.totalSupply(),0);
    }
    function test_bundleWithdrawalBurnsExactCallerShares() public {
        _bootstrap(); uint256 shares=subject.balanceOf(address(this))/10; uint256 beforeShares=subject.balanceOf(address(this));
        (uint256[] memory quote,)=IStandardExchangeBundleOut(address(subject)).previewExchangeBundleOut(address(subject),shares,_outputTokens());
        (uint256[] memory paid,uint256 refund)=IStandardExchangeBundleOut(address(subject)).exchangeBundleOut(address(subject),shares,_outputTokens(),quote,FALSE_DEPOSITOR,false,block.timestamp);
        assertEq(paid,quote); assertEq(refund,0); assertEq(subject.balanceOf(address(this)),beforeShares-shares); assertEq(asset0.balanceOf(FALSE_DEPOSITOR),paid[0]); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),paid[1]); _assertAccounting();
    }
    function test_pushedDirectExactInputSwapRefundsOnlyUnusedInput() public {
        _bootstrap(); _trade(true,100 ether); AtomicPretransferCaller caller=new AtomicPretransferCaller();
        bytes memory data=abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset0,10 ether,asset1,0,FALSE_DEPOSITOR,true,block.timestamp));
        uint256 supply=subject.totalSupply(); (uint256 out,uint256 refund)=_push(caller,asset0,10 ether,data);
        assertGt(out,0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),out); assertEq(asset0.balanceOf(address(caller)),refund); assertEq(subject.totalSupply(),supply); _assertAccounting();
    }
}
