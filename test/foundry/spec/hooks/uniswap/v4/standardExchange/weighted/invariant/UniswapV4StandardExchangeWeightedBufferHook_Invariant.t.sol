// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {HookLiquidityInvariantHandler, IInvariantHookLiquidity} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol";
import {HookComponentLedger} from "../../HookComponentAccountingBehavior.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {HostileReentrantERC20} from "../HostileReentrantERC20.sol";

/// @dev Concrete test-root artifact exposes the handler ABI to focused invariant runs.
contract Handler_WeightedLiquidity is HookLiquidityInvariantHandler {
    constructor(Config memory config_) HookLiquidityInvariantHandler(config_) {}
}

/// @notice Real weighted proxy with a six-decimal pair, eighteen-decimal SE share and raw leg.
/// @dev This is an ERC4626 integration control, not evidence of mixed-decimal FullSpread backing pools.
contract UniswapV4StandardExchangeWeightedBufferHook_MixedDecimalsOwnership is TestBase, HookComponentLedger {
    MintableERC20Decimals private sixDecimalPair;
    SimpleYieldERC4626 private sixDecimalVault;
    address private sixDecimalSe;
    HostileReentrantERC20 private callbackRaw;
    address private constant SECOND_LP = address(0xB0B16);
    uint256 private constant MINT_FEE = 2e16;

    function setUp() public override {
        super.setUp();
        sixDecimalPair = new MintableERC20Decimals("Six decimal pair", "SIX", 6);
        sixDecimalVault = new SimpleYieldERC4626(sixDecimalPair);
        sixDecimalSe = _deployERC4626SE(address(sixDecimalVault));
        callbackRaw = new HostileReentrantERC20("Callback raw", "CALL");
        address[] memory pairs_ = new address[](2);
        address[] memory ses_ = new address[](2);
        uint256 buffered_ = address(sixDecimalPair) < address(callbackRaw) ? 0 : 1;
        pairs_[buffered_] = address(sixDecimalPair);
        pairs_[1 - buffered_] = address(callbackRaw);
        ses_[buffered_] = sixDecimalSe;
        uint256[] memory weights_ = new uint256[](2);
        weights_[0] = 0.5e18;
        weights_[1] = 0.5e18;
        _deployHookWithArgs(_pkgArgs(pairs_, weights_, ses_, new address[](2)));
        _setUsageFee(MINT_FEE);
        _ledgerInit(hook, pairs_, ses_, address(feeCollector));
    }

    function test_HB16_mixedNativeDecimalsJoinYieldExit() public {
        assertEq(sixDecimalPair.decimals(), 6);
        assertEq(MintableERC20Decimals(sixDecimalSe).decimals(), 18);
        _mixedJoin(user, 100, true);
        _mixedJoin(SECOND_LP, 10, false);
        uint256 rateBefore_ = sixDecimalVault.convertToAssets(1 ether);
        sixDecimalPair.mint(address(this), 10e6);
        sixDecimalPair.approve(address(sixDecimalVault), 10e6);
        sixDecimalVault.simulateYield(10e6);
        assertGt(sixDecimalVault.convertToAssets(1 ether), rateBefore_);
        _ledgerAssert();
        _mixedExit(SECOND_LP, ledgerLp[SECOND_LP] / 2);
        for (uint256 i_; i_ < 3; ++i_) {
            _mixedJoin(SECOND_LP, i_ + 1, i_ % 2 == 0);
            _mixedExit(user, ledgerLp[user] / 10);
        }
        _mixedExit(SECOND_LP, ledgerLp[SECOND_LP]);
        _mixedExit(user, ledgerLp[user]);
        _mixedExit(address(feeCollector), ledgerFeeBalance);
        assertEq(ledgerSupply, 1000);
    }

    /// @notice A nested proportional join cannot consume the outer caller's pending basket.
    function test_HB16_reentryCannotSpendPendingCallerComponents() public {
        _mixedJoin(user, 100, true);
        callbackRaw.arm(hook, abi.encodeCall(
            weighted.joinProportionalFlexible,
            (new uint256[](2), new bool[](2), SECOND_LP, 0, block.timestamp)
        ));
        _mixedJoin(SECOND_LP, 2, true);
        assertEq(callbackRaw.reentryAttempts(), 1, "deterministic transfer callback");
        assertFalse(callbackRaw.nestedCallSucceeded(), "pending components are not spendable");
        assertEq(callbackRaw.nestedErrorSelector(), bytes4(keccak256("Reentrancy()")), "guard before intake");
        _mixedExit(SECOND_LP, ledgerLp[SECOND_LP]);
        _ledgerAssert();
    }

    function _mixedJoin(address actor_, uint256 wholeTokens_, bool sharesIn_) private {
        uint256[] memory amounts_ = new uint256[](2);
        bool[] memory flags_ = new bool[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            NativeLeg storage leg_ = nativeBooks[i_];
            MintableERC20Decimals pair_ = MintableERC20Decimals(leg_.pair);
            amounts_[i_] = wholeTokens_ * 10 ** pair_.decimals();
            pair_.mint(actor_, amounts_[i_]);
            vm.startPrank(actor_);
            if (leg_.se != address(0) && sharesIn_) {
                pair_.approve(leg_.se, amounts_[i_]);
                (amounts_[i_],) = IStandardExchangeIn(leg_.se).exchangeIn(
                    IERC20(leg_.pair), amounts_[i_], IERC20(leg_.se), 1, actor_, false, block.timestamp
                );
                IERC20(leg_.se).approve(hook, amounts_[i_]);
                flags_[i_] = true;
            } else pair_.approve(hook, amounts_[i_]);
            vm.stopPrank();
        }
        _ledgerBegin(actor_);
        vm.prank(actor_);
        (uint256 net_,) = weighted.joinProportionalFlexible(amounts_, flags_, actor_, 1, block.timestamp);
        _ledgerJoin(actor_, amounts_, flags_, net_, MINT_FEE);
    }

    function _mixedExit(address actor_, uint256 burned_) private {
        _ledgerBegin(actor_);
        vm.prank(actor_);
        weighted.exitProportionalFlexible(burned_, actor_, new bool[](2), new uint256[](2), block.timestamp);
        _ledgerExit(actor_, burned_);
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4StandardExchangeWeightedBufferHook_Invariant is TestBase {
    HookLiquidityInvariantHandler internal handler;

    function setUp() public override {
        super.setUp();
        WrapperExactOutRouter route_ = swapRouter;
        HookLiquidityInvariantHandler.Config memory c;
        c.hook = hook;
        c.mode = 0;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.standardExchanges = new address[](c.tokens.length);
        for (uint256 i; i < c.tokens.length; ++i) {
            c.standardExchanges[i] = IInvariantHookLiquidity(hook).standardExchangeOf(address(c.tokens[i]));
        }
        c.input = address(token0);
        c.output = address(token1);
        c.inputSE = se0;
        c.inputVault = address(vault0);
        c.feeRecipient = address(feeCollector);
        c.feeOracle = address(indexedexManager);
        c.router = route_;
        c.key = poolKey01;
        c.observedTokens = new IERC20[](5);
        c.observedTokens[0] = IERC20(address(token0));
        c.observedTokens[1] = IERC20(address(token1));
        c.observedTokens[2] = IERC20(address(se0));
        c.observedTokens[3] = IERC20(address(vault0));
        c.observedTokens[4] = IERC20(address(hook));
        c.observedHolders = new address[](8);
        c.observedHolders[0] = address(hook);
        c.observedHolders[1] = address(se0);
        c.observedHolders[2] = address(vault0);
        c.observedHolders[3] = address(address(pm));
        c.observedHolders[4] = address(address(route_));
        c.observedHolders[5] = address(address(feeCollector));
        c.observedHolders[6] = address(user);
        c.observedHolders[7] = address(address(0));
        handler = new Handler_WeightedLiquidity(c);
        bytes4[] memory selectors_ = new bytes4[](1);
        selectors_[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors_}));
    }

    function invariant_liquidityAccounting() public view { handler.assertAccounting(); }
    function afterInvariant() public {
        handler.assertAccounting();
        // A persisted, shrunk counterexample may replay fewer than 24 calls.
        // Complete the deterministic actor/action prefix without discarding it.
        for (uint256 i = handler.attempted(); i < 24; ++i) handler.cycle(10 ether, i, i);
        handler.assertCampaign();
    }

    function test_shortReplayCompletesActorActionCoverage() public {
        handler.cycle(1 ether, 0, 0);
        afterInvariant();
        assertEq(handler.attempted(), 24);
    }

    function test_deterministicLifecycle() public {
        for (uint256 i; i < 24; ++i) handler.cycle(10 ether, i, i);
        assertEq(handler.ghost_join(), 24);
        assertEq(handler.ghost_exit(), 24);
        handler.assertCampaign();
    }
}
