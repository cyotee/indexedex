// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeReleaseBehavior} from "../remediation/StandardExchangeReleaseBehavior.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {StandardExchangeConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
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
        token.transferFrom(msg.sender, vault, amount);
        return IStandardExchangeIn(vault).exchangeIn(token, amount, IERC20(vault), 0, recipient, true, block.timestamp);
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

/// @notice Greppable attack controls inherited by both real production package families.
/// @dev K1 live-book stray transfers are donor loss. M1/M2 have no arbitrary-call surface;
/// N1 has no bond hook. O1/O2 have no Permit2 user entry; share permit remains tested.
/// M3 is closed by removing imported increases; import custody/allowance controls are family-specific.
abstract contract StandardExchangeFullSpreadAdversarialBehavior is StandardExchangeReleaseBehavior {
    function _seedMarket() internal virtual;
    function _setDecimalFixture(uint8 da, uint8 db, bool failing) internal virtual;

    function test_A0_dustFirstMint_reverts_sixDecimals() public { _decimalBoundary(6,6,false,1e3); }
    function test_A0_floor_sixEighteen() public { _decimalBoundary(6,18,false,1e9); }
    function test_A0_floor_oddDecimalSum() public { _decimalBoundary(6,9,false,1e4); }
    function test_A0_floor_decimalSumBelowSix() public { _decimalBoundary(2,3,false,1); }
    /// @dev D34: no metadata fallback. A token whose `decimals()` reverts surfaces its own revert on
    ///      the first-mint floor check, both in preview and in execution, with no state change.
    function test_A0_revertingMetadata_propagatesDependencyRevert_D34() public {
        _setDecimalFixture(18,18,true); _configureSleeve(1e18);
        _fund(asset0,address(this),1e15+1); _fund(asset1,address(this),1e15+1);
        asset0.approve(address(subject),1e15+1); asset1.approve(address(subject),1e15+1);
        vm.expectRevert(bytes("metadata unavailable"));
        IStandardExchangeInMulti(address(subject)).previewExchangeInManyToOne(_tokens(),_amounts(1e15,1e15),IERC20(address(subject)));
        vm.expectRevert(bytes("metadata unavailable"));
        IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(_tokens(),_amounts(1e15,1e15),IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertEq(subject.totalSupply(),0); _bookMatchesBalances();
    }
    function _decimalBoundary(uint8 da,uint8 db,bool failing,uint256 minimum) private {
        _setDecimalFixture(da,db,failing); _configureSleeve(1e18);
        _fund(asset0,address(this),minimum+1); _fund(asset1,address(this),minimum+1);
        asset0.approve(address(subject),minimum+1); asset1.approve(address(subject),minimum+1);
        bytes memory expected=abi.encodeWithSelector(StandardExchangeConstantProduct.InsufficientMinimumLiquidity.selector,minimum,minimum);
        vm.expectRevert(expected);
        IStandardExchangeInMulti(address(subject)).previewExchangeInManyToOne(_tokens(),_amounts(minimum,minimum),IERC20(address(subject)));
        vm.expectRevert(expected);
        IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(_tokens(),_amounts(minimum,minimum),IERC20(address(subject)),0,address(this),false,block.timestamp);
        assertEq(subject.totalSupply(),0); _bookMatchesBalances();
        assertEq(IStandardExchangeInMulti(address(subject)).previewExchangeInManyToOne(_tokens(),_amounts(minimum+1,minimum+1),IERC20(address(subject))),1);
        assertEq(_join(minimum+1,minimum+1,address(this)),1);
        assertEq(subject.balanceOf(address(0xdEaD)),minimum); assertEq(subject.totalSupply(),minimum+1);
    }

    function _tokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2); tokens[0] = address(asset0); tokens[1] = address(asset1);
    }
    function _amounts(uint256 a, uint256 b) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2); amounts[0] = a; amounts[1] = b;
    }
    function _join(uint256 a, uint256 b, address recipient) internal returns (uint256) {
        asset0.approve(address(subject), a); asset1.approve(address(subject), b);
        return IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(
            _tokens(), _amounts(a,b), IERC20(address(subject)), 0, recipient, false, block.timestamp);
    }
    function _bookMatchesBalances() internal view {
        assertEq(subject.reserveOfToken(address(asset0)), asset0.balanceOf(address(subject)));
        assertEq(subject.reserveOfToken(address(asset1)), asset1.balanceOf(address(subject)));
        assertEq(subject.reserveOfToken(address(subject)), subject.balanceOf(address(subject)));
    }
    function test_A0_dustFirstMint_reverts() public {
        _fund(asset0, address(this), 1e15); _fund(asset1, address(this), 1e15);
        asset0.approve(address(subject), 1e15); asset1.approve(address(subject), 1e15);
        bytes memory expected = abi.encodeWithSelector(StandardExchangeConstantProduct.InsufficientMinimumLiquidity.selector, 1e15, 1e15);
        vm.expectRevert(expected);
        IStandardExchangeInMulti(address(subject)).previewExchangeInManyToOne(_tokens(), _amounts(1e15,1e15), IERC20(address(subject)));
        vm.expectRevert(expected);
        IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(_tokens(), _amounts(1e15,1e15), IERC20(address(subject)), 0, address(this), false, block.timestamp);
        assertEq(subject.totalSupply(), 0); _bookMatchesBalances();
    }
    function test_A0_minimumPlusOne_previewAndExecution_idleAndBlocked() public {
        _activationBoundary(false);
    }
    function test_A0_minimumPlusOne_previewAndExecution_blocked() public {
        _activationBoundary(true);
    }
    function _activationBoundary(bool blocked) private {
        if (blocked) _seedMarket(); // V3 flash requires a live external pool.
        uint256 amount = 1e15 + 1;
        bytes memory preview = abi.encodeCall(IStandardExchangeInMulti.previewExchangeInManyToOne,
            (_tokens(), _amounts(amount,amount), IERC20(address(subject))));
        uint256 quote = blocked ? _locked(preview, asset0, 0) : _execute(preview);
        assertEq(quote, 1); assertEq(subject.totalSupply(), 0);
        if (blocked) {
            _fund(asset0, address(lockedCaller), amount); _fund(asset1, address(lockedCaller), amount);
            bytes memory data = abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
                (_tokens(), _amounts(amount,amount), IERC20(address(subject)), quote, address(this), true, block.timestamp));
            assertEq(lockedCaller.run(address(subject), data, _tokens(), _amounts(amount,amount)), quote);
        } else {
            _fund(asset0, address(this), amount); _fund(asset1, address(this), amount);
            assertEq(_join(amount, amount, address(this)), quote);
        }
        assertEq(subject.balanceOf(address(0xdEaD)), 1e15); assertEq(subject.totalSupply(), amount);
    }
    function test_A0_dustFirstMint_thenDonate_victimJoin_attackerCannotTakeHalf() public {
        _configureSleeve(1e18); _seedMarket();
        address attacker = makeAddr("first-minter"); address victim = makeAddr("victim");
        uint256 first = 1e15 + 1; uint256 donation = 1 ether;
        _fund(asset0, attacker, first + donation); _fund(asset1, attacker, first + donation);
        _fund(asset0, victim, donation); _fund(asset1, victim, donation);
        uint256 before0 = asset0.balanceOf(attacker); uint256 before1 = asset1.balanceOf(attacker);
        vm.startPrank(attacker); _join(first, first, attacker);
        asset0.transfer(address(subject), donation); asset1.transfer(address(subject), donation); vm.stopPrank();
        vm.startPrank(victim); _join(donation, donation, victim); vm.stopPrank();
        (uint256 out0,uint256 out1)=_exitFirstMinter(attacker);
        assertLe(asset0.balanceOf(attacker), before0); assertLe(asset1.balanceOf(attacker), before1);
        assertLe(out0, first + donation); assertLe(out1, first + donation);
    }
    function _exitFirstMinter(address attacker) private returns(uint256 out0,uint256 out1) {
        uint256 shares=subject.balanceOf(attacker);uint256 supply=subject.totalSupply();
        assertLt(shares*2,supply);
        out0=asset0.balanceOf(address(subject))*shares/supply;out1=asset1.balanceOf(address(subject))*shares/supply;
        vm.startPrank(attacker);subject.approve(address(subject),shares);
        uint256 burned=IStandardExchangeOutMulti(address(subject)).exchangeOutOneToMany(
            IERC20(address(subject)),shares,_tokens(),_amounts(out0,out1),attacker,false,block.timestamp);
        vm.stopPrank();assertEq(burned,shares);assertEq(subject.balanceOf(attacker),0);
    }
    function test_A0_residualDeadShares_firstMinterNotWhole() public {
        _configureSleeve(1e18);
        _fund(asset0, address(subject), 10 ether); _fund(asset1, address(subject), 10 ether);
        _fund(asset0, address(this), 10 ether); _fund(asset1, address(this), 10 ether);
        uint256 issued = _join(10 ether,10 ether,address(this));
        assertEq(issued, 10 ether - 1e15);
        assertEq(subject.balanceOf(address(0xdEaD)), issued + 1e15);
        assertEq(subject.totalSupply(), 2 * issued + 1e15);
    }
    function test_I_routerTransferFromUserToVault() public {
        _bootstrap(); FullSpreadTransferRouter router = new FullSpreadTransferRouter();
        address user = makeAddr("router-user"); _fund(asset0,user,25 ether);
        vm.startPrank(user); asset0.approve(address(router),25 ether);
        uint256 shares = router.deposit(asset0,address(subject),25 ether,user); vm.stopPrank();
        assertGt(shares,0); assertEq(subject.balanceOf(user),shares);
        assertEq(asset0.balanceOf(user),0); assertEq(asset0.balanceOf(address(router)),0);
        assertEq(subject.balanceOf(address(router)),0); _bookMatchesBalances();
    }
    function test_I1_pretransferredTrue_noDelivery_noFreeMint() public {
        _bootstrap();
        bytes memory data = _depositCall(asset0, 25 ether, FALSE_DEPOSITOR);
        vm.startPrank(FALSE_DEPOSITOR);
        _reject(data, abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
        vm.stopPrank();
        _reject(data, _deliveryError(25 ether, 0));
        assertEq(subject.balanceOf(FALSE_DEPOSITOR),0);
    }
    function test_I2_shortPush_pretransferred_claimedGtDelta_reverts() public { _wrongTransfer(24 ether); }
    function test_I2_excessExactIn_creditsRequestedOnly() public {
        _bootstrap();
        bytes memory data = _depositCall(asset0, 25 ether, address(this));
        _fund(asset0, address(this), 26 ether);
        asset0.transfer(address(subject), 26 ether);
        uint256 minted = _execute(data);
        assertGt(minted, 0);
        assertEq(asset0.balanceOf(address(this)), 0);
    }
    function test_I2_dualJoinOneExcessLeg_creditsRequestedOnly() public {
        _bootstrap(); _fund(asset0,address(this),10 ether); _fund(asset1,address(this),11 ether);
        asset0.transfer(address(subject),10 ether); asset1.transfer(address(subject),11 ether);
        uint256 minted = IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(
            _tokens(), _amounts(10 ether, 10 ether), IERC20(address(subject)), 0, address(this), true, block.timestamp);
        assertGt(minted, 0);
        assertEq(asset1.balanceOf(address(this)), 0);
    }
    function test_I3_residualAfterSuccessfulPush_cannotFundSecondFreePretransfer() public { test_pullAndPushedDepositsAfterPriceMovement(); }
    function test_L1_poolTradeThenFalsePretransfer_noCredit() public { _falseDeposit(true); }
    function test_L3_spotSkew_noUnfundedMint() public { _falseDeposit(false); }
    function test_I_reserveOfTokenWrittenAfterRebalanceAndSwap() public {
        _bootstrap(); _trade(true,10 ether); _rebalance(); _bookMatchesBalances();
        _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        subject.exchangeIn(asset0,1 ether,asset1,0,address(this),false,block.timestamp);
        _bookMatchesBalances(); _reject(_depositCall(asset0,1 ether,FALSE_DEPOSITOR),_deliveryError(1 ether,0));
    }
    function test_F5_rebalancePaysCallerNothing() public {
        _bootstrap(); uint256 free0=asset0.balanceOf(address(subject)); uint256 free1=asset1.balanceOf(address(subject));
        vm.prank(FALSE_DEPOSITOR); _rebalance();
        assertEq(asset0.balanceOf(FALSE_DEPOSITOR),0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),0); assertEq(subject.balanceOf(FALSE_DEPOSITOR),0);
        assertApproxEqAbs(asset0.balanceOf(address(subject)),200 ether,10 ether);
        assertApproxEqAbs(asset1.balanceOf(address(subject)),200 ether,10 ether);
        assertEq(asset0.balanceOf(address(subject)),free0); assertEq(asset1.balanceOf(address(subject)),free1); _bookMatchesBalances();
    }
    function test_H_lockedExitAfterPermissionlessRebalance() public { _lockedExit(10,190 ether); }
    function test_H_lockedExit_onePercentOfSupply() public { _lockedExit(100,19.9 ether); }
    function _lockedExit(uint256 divisor,uint256 expected) private {
        _bootstrap(); vm.prank(FALSE_DEPOSITOR); _rebalance();
        uint256 shares=subject.totalSupply()/divisor; subject.transfer(address(lockedCaller),shares);
        bytes memory data=abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(subject)),shares,asset1,0,address(this),true,block.timestamp));
        assertApproxEqAbs(_locked(data,IERC20(address(subject)),shares),expected,5);
        assertApproxEqAbs(asset1.balanceOf(address(this)),expected,5); _bookMatchesBalances();
    }
    function test_H_positiveSleeveInsufficientCapacity_rollsBack() public { _lockedInsufficient(0.2e18); }
    function test_H_zeroSleeveCanBlockLockedExit() public { _lockedInsufficient(0); }
    function _lockedInsufficient(uint256 pct) private {
        _bootstrap(); _configureSleeve(pct); _rebalance();
        uint256 shares=subject.totalSupply()/4; subject.transfer(address(lockedCaller),shares);
        uint256 supply=subject.totalSupply(); uint256 free=asset1.balanceOf(address(subject));
        // The forward quote itself checks sleeve capacity; use independent CP entitlement.
        uint256 required=_independentSingleExit(shares,supply);
        bytes memory expected=abi.encodeWithSignature(string.concat(_family(),"Exchange_InsufficientLocalReserve(address,uint256,uint256)"),address(asset1),required,free);
        bytes memory data=abi.encodeCall(IStandardExchangeIn.exchangeIn,(IERC20(address(subject)),shares,asset1,0,address(this),true,block.timestamp));
        vm.expectRevert(expected); _locked(data,IERC20(address(subject)),shares);
        assertEq(subject.balanceOf(address(lockedCaller)),shares); assertEq(subject.totalSupply(),supply);
        assertEq(asset1.balanceOf(address(subject)),free); _bookMatchesBalances();
    }
    function _independentSingleExit(uint256 shares,uint256 supply) private view returns (uint256) {
        (uint256 deployed0,uint256 deployed1)=_deployed();
        uint256 totalOut=asset1.balanceOf(address(subject))+deployed1;
        uint256 totalOther=asset0.balanceOf(address(subject))+deployed0;
        uint256 first=totalOut*shares/supply;
        uint256 other=totalOther*shares/supply;
        return first+(totalOut-first)*other/totalOther;
    }
    function test_L2_FoT_forbidden() public {
        _seedMarket(); DeliveryTestToken(address(asset1)).setFee(true);
        _fund(asset0,address(this),100 ether); _fund(asset1,address(this),100 ether);
        asset0.approve(address(subject),100 ether); asset1.approve(address(subject),100 ether);
        bytes memory data=abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_tokens(),_amounts(100 ether,100 ether),IERC20(address(subject)),0,address(this),false,block.timestamp));
        _reject(data,_deliveryError(100 ether,99 ether));
        assertEq(subject.totalSupply(),0); assertEq(asset0.balanceOf(address(this)),100 ether); assertEq(asset1.balanceOf(address(this)),100 ether);
        assertEq(asset0.allowance(address(this),address(subject)),100 ether); assertEq(asset1.allowance(address(this),address(subject)),100 ether); _bookMatchesBalances();
    }
    function test_C1_nestedMoneyPaths_recordedAndPropagating() public {
        _bootstrap(); DeliveryTestToken token=DeliveryTestToken(address(asset1));
        _fund(asset1,address(this),60 ether); asset1.approve(address(subject),60 ether);
        bytes[3] memory calls_=[_depositCall(asset1,1 ether,FALSE_DEPOSITOR),
            abi.encodeCall(IStandardExchangeOut.exchangeOut,(asset1,1 ether,asset0,1,FALSE_DEPOSITOR,false,block.timestamp)),
            abi.encodeWithSignature("rebalanceLiquidReserve()")];
        for(uint256 i;i<calls_.length;++i){
            token.setCallback(address(subject),calls_[i]); token.setCallbackPropagates(false);
            assertGt(subject.exchangeIn(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp),0);
            assertEq(token.callbackError(),abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            assertEq(subject.balanceOf(FALSE_DEPOSITOR),0); assertEq(asset0.balanceOf(FALSE_DEPOSITOR),0);
            token.setCallbackPropagates(true);
            uint256 allowance_=asset1.allowance(address(this),address(subject)); uint256 balance_=asset1.balanceOf(address(this));
            bytes memory outer=abi.encodeCall(IStandardExchangeIn.exchangeIn,(asset1,10 ether,IERC20(address(subject)),0,address(this),false,block.timestamp));
            _reject(outer,abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            assertEq(asset1.allowance(address(this),address(subject)),allowance_); assertEq(asset1.balanceOf(address(this)),balance_); _bookMatchesBalances();
        }
    }
    function test_CROPS_disableInboundStillAllowsExitAndSY() public {
        _bootstrap(); _disable(true,false);
        uint256 used=subject.exchangeOut(IERC20(address(subject)),10 ether,asset1,1 ether,address(this),false,block.timestamp);
        assertGt(used,0); assertGt(IStandardizedYield(address(subject)).redeem(address(this),1 ether,address(asset1),0,false),0);
        _fund(asset0,address(this),1 ether); asset0.approve(address(subject),1 ether);
        vm.expectRevert(abi.encodeWithSignature("VaultDisabled(address)",address(subject)));
        subject.exchangeIn(asset0,1 ether,IERC20(address(subject)),0,address(this),false,block.timestamp);
    }
    struct RefundCase {
        IERC20 input;
        uint256 used;
        uint256 maximum;
        uint256 delivered;
        uint256 booked;
        uint256 payerAfterTransfer;
        uint256 supply;
        bytes data;
    }
    function _refundFixture() private {
        _configureSleeve(1e18); _seedMarket();
        _fund(asset0,address(this),1000 ether); _fund(asset1,address(this),1000 ether);
        _join(1000 ether,1000 ether,address(this));
        subject.transfer(address(subject),50 ether); _rebalance();
        (uint256 deployed0,uint256 deployed1)=_deployed(); assertEq(deployed0,0); assertEq(deployed1,0);
        _bookMatchesBalances();
    }
    function _refundCase(uint8 route,bool blocked,uint8 deliveryCase) private {
        RefundCase memory c;
        c.input=route==0?asset0:IERC20(address(subject));
        c.booked=subject.reserveOfToken(address(c.input)); c.supply=subject.totalSupply();
        bytes memory quote=route==2?
            abi.encodeCall(IStandardExchangeOutMulti.previewExchangeOutOneToMany,(c.input,_tokens(),_amounts(10 ether,10 ether))):
            abi.encodeCall(IStandardExchangeOut.previewExchangeOut,(c.input,asset1,10 ether));
        c.used=blocked?_locked(quote,asset0,0):_execute(quote); assertGt(c.used,0);
        c.maximum=c.used*4;
        // 0: used only; 1: used < actual < max; 2: max; 3: over max; 4: short; 5: none.
        c.delivered=deliveryCase==0?c.used:deliveryCase==1?c.used*2:deliveryCase==2?c.maximum:deliveryCase==3?c.maximum+c.used:deliveryCase==4?c.used-1:0;
        c.data=route==2?
            abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,(c.input,c.maximum,_tokens(),_amounts(10 ether,10 ether),FALSE_DEPOSITOR,true,block.timestamp)):
            abi.encodeCall(IStandardExchangeOut.exchangeOut,(c.input,c.maximum,asset1,10 ether,FALSE_DEPOSITOR,true,block.timestamp));
        address payer=blocked?address(lockedCaller):address(this);
        if(route==0) _fund(c.input,payer,c.delivered);
        else if(blocked) subject.transfer(payer,c.delivered);
        uint256 payerBefore=c.input.balanceOf(payer);
        if(!blocked) c.input.transfer(address(subject),c.delivered);
        c.payerAfterTransfer=payerBefore-c.delivered;
        uint256 entryBalance0=asset0.balanceOf(address(subject)); uint256 entryBalance1=asset1.balanceOf(address(subject));
        if(deliveryCase>=4){
            if(blocked){vm.expectRevert(_deliveryError(c.used,c.delivered));_locked(c.data,c.input,c.delivered);}
            else _reject(c.data,_deliveryError(c.used,c.delivered));
            assertEq(c.input.balanceOf(payer),blocked?payerBefore:c.payerAfterTransfer);
            assertEq(subject.totalSupply(),c.supply); assertEq(subject.reserveOfToken(address(c.input)),c.booked);
            assertEq(asset0.balanceOf(address(subject)),entryBalance0); assertEq(asset1.balanceOf(address(subject)),entryBalance1);
            return;
        }
        uint256 used=blocked?_locked(c.data,c.input,c.delivered):_execute(c.data);
        assertEq(used,c.used);
        uint256 capped=c.delivered<c.maximum?c.delivered:c.maximum;
        assertEq(c.input.balanceOf(payer),c.payerAfterTransfer+capped-c.used,"refund is this-call unused inbound capped by max");
        assertGe(asset1.balanceOf(FALSE_DEPOSITOR),10 ether);
        if(route==2) assertEq(asset0.balanceOf(FALSE_DEPOSITOR),10 ether);
        assertEq(subject.reserveOfToken(address(c.input)),c.booked+c.delivered-capped,"booked inventory intact");
        assertEq(c.input.balanceOf(address(subject)),c.booked+c.delivered-capped);
        if(route!=0) assertEq(subject.totalSupply(),c.supply-c.used);
        _bookMatchesBalances();
        uint256 nextUsed=blocked?_locked(quote,asset0,0):_execute(quote);
        if(blocked){vm.expectRevert(_deliveryError(nextUsed,0));_locked(c.data,c.input,0);}
        else _reject(c.data,_deliveryError(nextUsed,0));
    }
    function _refundMatrix(uint8 route,bool blocked) private {
        _refundFixture();
        for(uint8 i;i<4;++i){uint256 snap=vm.snapshotState();_refundCase(route,blocked,i);assertTrue(vm.revertToState(snap));}
    }
    function test_E6_exchangeOut_tokenExactOut_fatMax_transferOnlyUsed_doesNotPayBooked() public { _refundMatrix(0,false); }
    function test_E6_pretransferredZapOut_cannotBurnMoreThanDelivered() public {
        _refundFixture(); uint256 snap=vm.snapshotState(); _refundCase(1,false,4); assertTrue(vm.revertToState(snap)); _refundCase(1,true,4);
    }
    function test_E6_zapOut_refundMatrix_idle() public { _refundMatrix(1,false); }
    function test_E6_zapOut_refundMatrix_blocked() public { _refundMatrix(1,true); }
    function test_E6_dualExit_unusedShares_fatMax_transferOnlyUsed_doesNotPayBooked() public { _refundMatrix(2,false); }
    function test_E6_dualExit_refundMatrix_blocked() public { _refundMatrix(2,true); }
    function test_E6_dualExit_shortShares_idleAndBlocked() public {
        _refundFixture(); uint256 snap=vm.snapshotState(); _refundCase(2,false,4); assertTrue(vm.revertToState(snap)); _refundCase(2,true,4);
    }
    /// @dev D9 on the zap-out execution delegate: resting self-shares from an EOA are never credited.
    function test_APEX005_zapOut_pretransferred_eoaRejected() public {
        _refundFixture();
        subject.transfer(FALSE_DEPOSITOR,100 ether);
        vm.startPrank(FALSE_DEPOSITOR);
        subject.transfer(address(subject),100 ether);
        bytes memory data=abi.encodeCall(IStandardExchangeOut.exchangeOut,(IERC20(address(subject)),100 ether,asset1,1 ether,FALSE_DEPOSITOR,true,block.timestamp));
        _reject(data,abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
        vm.stopPrank();
        assertEq(subject.balanceOf(FALSE_DEPOSITOR),0); assertEq(asset1.balanceOf(FALSE_DEPOSITOR),0);
    }

    function test_I1_exchangeOut_pretransferredTrue_noDelivery() public {
        _refundFixture(); uint256 snap=vm.snapshotState();
        _refundCase(0,false,5); assertTrue(vm.revertToState(snap)); _refundCase(1,false,5);
    }
    function test_I2_exchangeOut_usedGtActualIn_reverts() public {
        _refundFixture(); uint256 snap=vm.snapshotState();
        _refundCase(0,false,4); assertTrue(vm.revertToState(snap)); _refundCase(1,false,4);
    }
    function test_I3_exchangeOut_residualAfterSuccessfulPush() public { _refundFixture(); _refundCase(0,false,3); }

    function test_J1_TargetSelectorsMatchFacetDeclarations() public view {
        string[10] memory targets=[string("InTarget"),"InQueryTarget","InMultiTarget","InMultiQueryTarget","OutExecuteTarget","OutQueryTarget","OutMultiTarget","OutMultiQueryTarget","LiquidReserveTarget","PositionImportTarget"];
        for(uint256 i;i<targets.length;++i){
            string memory name=string.concat(_family(),"FullSpreadStandardExchangeVault",targets[i]);
            string memory artifact=vm.readFile(string.concat("out/",name,".sol/",name,".json"));
            string[] memory signatures=vm.parseJsonKeys(artifact,".methodIdentifiers");
            for(uint256 j;j<signatures.length;++j){
                bytes4 selector=bytes4(keccak256(bytes(signatures[j])));
                address facet=IDiamondLoupe(address(subject)).facetAddress(selector); assertTrue(facet!=address(0),signatures[j]);
                assertEq(IFacet(facet).facetName(), _expectedFacet(i, targets[i], selector), signatures[j]);
                bytes4[] memory declared=IFacet(facet).facetFuncs(); bool found;
                for(uint256 k;k<declared.length;++k) if(declared[k]==selector) found=true;
                assertTrue(found,signatures[j]);
            }
        }
    }
    function _expectedFacet(uint256 index, string memory target, bytes4 selector) private pure returns (string memory) {
        string memory suffix = index == 4 ? "OutFacet" : string.concat(_withoutTarget(target), "Facet");
        // Common exposes these inherited methods on every Target ABI. The package
        // assigns each shared selector once, to its canonical facet.
        if (selector == bytes4(keccak256("canOpenBoundPoolOps()"))
            || selector == bytes4(keccak256("canOpenPoolManagerUnlock()"))
            || selector == bytes4(keccak256("twapOracle()"))) suffix = "LiquidReserveFacet";
        if (selector == bytes4(keccak256("uniswapV3MintCallback(uint256,uint256,bytes)"))
            || selector == bytes4(keccak256("uniswapV3SwapCallback(int256,int256,bytes)"))
            || selector == bytes4(keccak256("unlockCallback(bytes)"))) suffix = "InFacet";
        return string.concat(_family(), "FullSpreadStandardExchangeVault", suffix);
    }
    function _withoutTarget(string memory name) private pure returns (string memory) {
        bytes memory original = bytes(name);
        bytes memory stem = new bytes(original.length - 6);
        for (uint256 i; i < stem.length; ++i) stem[i] = original[i];
        return string(stem);
    }
    function test_J2_allTargetSelectorsInstalledOnProxy() public view { test_everyTargetSelectorIsInstalledOnRegistryProxy(); }
    function test_J3_proxyFundedMoneyPathsAndRemovedPrepare() public {
        test_proxyRemovedPreparationSurface(); _bootstrap();
        _fund(asset0,address(this),10 ether); asset0.approve(address(subject),10 ether);
        uint256 quote=subject.previewExchangeIn(asset0,10 ether,IERC20(address(subject)));
        assertEq(subject.exchangeIn(asset0,10 ether,IERC20(address(subject)),quote,address(this),false,block.timestamp),quote);
        uint256 used=subject.previewExchangeOut(IERC20(address(subject)),asset1,1 ether);
        assertEq(subject.exchangeOut(IERC20(address(subject)),used,asset1,1 ether,address(this),false,block.timestamp),used);
        _bookMatchesBalances();
    }

    function test_J3_queryAndNativeSYProductSelectors() public {
        _bootstrap();
        string[13] memory views_ = [string("assetInfo()"), "deployedReserve()", "exchangeRate()",
            "getRewardTokens()", "getTokensIn()", "getTokensOut()", "rewardIndexesCurrent()",
            "rewardIndexesStored()", "targetLiquidReservePercentage()", "yieldToken()",
            "totalSupply()", "name()", "symbol()"];
        for (uint256 i; i < views_.length; ++i) _surfaceCall(abi.encodeWithSignature(views_[i]));
        _surfaceCall(abi.encodeWithSignature("accruedRewards(address)", address(this)));
        _surfaceCall(abi.encodeWithSignature("claimRewards(address)", address(this)));
        _surfaceCall(abi.encodeWithSignature("actualLiquidReservePercentage(address)", address(asset0)));
        _surfaceCall(abi.encodeWithSignature("localReserve(address)", address(asset0)));
        _surfaceCall(abi.encodeWithSignature("isValidTokenIn(address)", address(asset0)));
        _surfaceCall(abi.encodeWithSignature("isValidTokenOut(address)", address(asset1)));
        _surfaceCall(abi.encodeWithSignature("previewDeposit(address,uint256)", address(asset0), 1 ether));
        _surfaceCall(abi.encodeWithSignature("previewRedeem(address,uint256)", address(asset1), 1 ether));
        bytes memory encoded = _surfaceCall(abi.encodeWithSignature("quoteState(address,address)", address(asset0), address(this)));
        (bytes memory state,) = abi.decode(encoded, (bytes,uint256));
        _surfaceCall(abi.encodeWithSignature("quoteTotalSupply(bytes)", state));
        _surfaceCall(abi.encodeWithSignature("quoteShareBalance(bytes)", state));
        _surfaceCall(abi.encodeWithSignature("quoteAssets(bytes,uint256)", state, 1 ether));
        _surfaceCall(abi.encodeWithSignature("quoteExternalDeposit(bytes,address,uint256)", state, address(asset0), 1 ether));
        _surfaceCall(abi.encodeWithSignature("quoteExternalExchange(bytes,address,uint256)", state, address(asset1), 1 ether));
        _surfaceCall(abi.encodeWithSignature("quoteTransition(bytes,uint8,uint256)", state, uint8(0), 1 ether));
        bool v3 = keccak256(bytes(_family())) == keccak256("UniswapV3");
        _surfaceCall(abi.encodeWithSignature(v3 ? "canOpenBoundPoolOps()" : "canOpenPoolManagerUnlock()"));
        if (!v3) _surfaceCall(abi.encodeWithSignature("twapOracle()"));
        _fund(asset0,address(this),1 ether);asset0.approve(address(subject),1 ether);
        assertGt(IStandardizedYield(address(subject)).deposit(address(this),address(asset0),1 ether,0),0);
        assertGt(IStandardizedYield(address(subject)).redeem(address(this),1 ether,address(asset1),0,false),0);
        _bookMatchesBalances();
    }
    function _surfaceCall(bytes memory data) private returns (bytes memory result) {
        bool ok;
        (ok,result) = address(subject).call(data);
        assertTrue(ok, "retained query/product selector must execute through proxy");
    }

    function test_pullDualExit_maxAllowanceAndBalance_idle() public { _pullMatrix(false); }
    function test_pullDualExit_maxAllowanceAndBalance_blocked() public { _pullMatrix(true); }
    function _pullMatrix(bool blocked) private {
        _refundFixture();
        for(uint8 mode;mode<4;++mode){uint256 snap=vm.snapshotState();_pullCase(blocked,mode);assertTrue(vm.revertToState(snap));}
    }
    function _pullCase(bool blocked,uint8 mode) private {
        RefundCase memory c; c.input=IERC20(address(subject)); c.booked=subject.reserveOfToken(address(subject)); c.supply=subject.totalSupply();
        bytes memory quote=mode==3?
            abi.encodeCall(IStandardExchangeOut.previewExchangeOut,(c.input,asset1,10 ether)):
            abi.encodeCall(IStandardExchangeOutMulti.previewExchangeOutOneToMany,(c.input,_tokens(),_amounts(10 ether,10 ether)));
        c.used=blocked?_locked(quote,asset0,0):_execute(quote); c.maximum=c.used*4;
        address payer=blocked?address(lockedCaller):address(this);
        uint256 payerBalance=mode>=2?c.used:c.maximum;
        if(blocked) subject.transfer(payer,payerBalance);
        else subject.transfer(makeAddr("other-holder"),subject.balanceOf(address(this))-payerBalance);
        uint256 allowed=mode==3?0:mode==1?c.used:c.maximum;
        vm.prank(payer);subject.approve(address(subject),allowed);
        c.data=mode==3?
            abi.encodeCall(IStandardExchangeOut.exchangeOut,(c.input,c.maximum,asset1,10 ether,FALSE_DEPOSITOR,false,block.timestamp)):
            abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,(c.input,c.maximum,_tokens(),_amounts(10 ether,10 ether),FALSE_DEPOSITOR,false,block.timestamp));
        uint256 used=blocked?_locked(c.data,c.input,0):_execute(c.data);
        assertEq(used,c.used);
        assertEq(subject.balanceOf(payer),payerBalance-c.used);
        assertEq(subject.totalSupply(),c.supply-c.used);
        assertEq(
            subject.allowance(payer,address(subject)),
            mode==3?allowed:allowed-used,
            "false-flag spends quoted used via transferFrom except single-share burn"
        );
        assertGe(asset1.balanceOf(FALSE_DEPOSITOR),10 ether);
        assertEq(subject.reserveOfToken(address(subject)),c.booked);assertEq(subject.balanceOf(address(subject)),c.booked);_bookMatchesBalances();
    }
}
