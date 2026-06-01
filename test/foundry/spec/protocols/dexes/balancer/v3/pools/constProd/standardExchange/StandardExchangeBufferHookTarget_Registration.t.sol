// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HookFlags, TokenConfig, TokenType, LiquidityManagement} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {StandardExchangeBufferPoolRepo as Repo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {StandardExchangeBufferHookTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol";

contract StaticRateProvider is IRateProvider {
    uint256 immutable R;
    constructor(uint256 r) { R = r; }
    function getRate() external view returns (uint256) { return R; }
}

contract HookHarness is StandardExchangeBufferHookTarget {
    address public immutable VAULT;
    address public immutable FACTORY;
    constructor(address v, address f, IERC20 tta, IERC20 sh, IStandardExchange sev, IRateProvider rp) {
        VAULT = v; FACTORY = f;
        Repo._initialize(tta, sh, sev, rp, 0, 1);
    }
    function _balancerV3Vault() internal view override returns (address) { return VAULT; }
    function _expectedFactory() internal view override returns (address) { return FACTORY; }

    function virtualTTA() external view returns (uint256) { return Repo._virtualTTA(); }
    function hookSharesDelta() external view returns (int256) { return Repo._hookSharesDelta(); }
}

contract HookRegistrationTest is Test {
    HookHarness h;
    address vault = address(0xCAFE);
    address factory = address(0xFACE);
    IERC20 tta = IERC20(address(0xA));
    IERC20 shares = IERC20(address(0xB));
    StaticRateProvider rp;

    function setUp() public {
        rp = new StaticRateProvider(1e18);
        h = new HookHarness(vault, factory, tta, shares, IStandardExchange(address(0xC)), rp);
    }

    function _tc(IERC20 t, TokenType tt, address rprov) internal pure returns (TokenConfig memory) {
        return TokenConfig({token: t, tokenType: tt, rateProvider: IRateProvider(rprov), paysYieldFees: false});
    }

    function _lm() internal pure returns (LiquidityManagement memory) {
        return LiquidityManagement({
            disableUnbalancedLiquidity: true,
            enableAddLiquidityCustom: true,
            enableRemoveLiquidityCustom: true,
            enableDonation: true
        });
    }

    function test_getHookFlags_matchesSpec() public view {
        HookFlags memory flags = h.getHookFlags();
        assertFalse(flags.enableHookAdjustedAmounts);
        assertTrue(flags.shouldCallBeforeInitialize);
        assertFalse(flags.shouldCallAfterInitialize);
        assertFalse(flags.shouldCallComputeDynamicSwapFee);
        assertTrue(flags.shouldCallBeforeSwap);
        assertTrue(flags.shouldCallAfterSwap);
        assertTrue(flags.shouldCallBeforeAddLiquidity);
        assertTrue(flags.shouldCallAfterAddLiquidity);
        assertFalse(flags.shouldCallBeforeRemoveLiquidity);
        assertTrue(flags.shouldCallAfterRemoveLiquidity);
    }

    function test_onRegister_acceptsValid() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(h), cfg, _lm());
        assertTrue(ok);
    }

    function test_onRegister_rejectsWrongSender() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        vm.prank(address(0xDEAD));
        bool ok = h.onRegister(factory, address(h), cfg, _lm());
        assertFalse(ok);
    }

    function test_onRegister_rejectsWrongFactory() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        vm.prank(vault);
        bool ok = h.onRegister(address(0xBAD), address(h), cfg, _lm());
        assertFalse(ok);
    }

    function test_onRegister_rejectsWrongPool() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(0xBAD), cfg, _lm());
        assertFalse(ok);
    }

    function test_onRegister_rejectsBadLM() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.STANDARD, address(0));
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        LiquidityManagement memory bad = _lm();
        bad.disableUnbalancedLiquidity = false;
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(h), cfg, bad);
        assertFalse(ok);
    }

    function test_onRegister_rejectsWrongTokenType() public {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _tc(tta, TokenType.WITH_RATE, address(rp)); // wrong: TTA should be STANDARD
        cfg[1] = _tc(shares, TokenType.WITH_RATE, address(rp));
        vm.prank(vault);
        bool ok = h.onRegister(factory, address(h), cfg, _lm());
        assertFalse(ok);
    }

    function test_onBeforeInitialize_seedsState() public {
        uint256[] memory amts = new uint256[](2);
        amts[0] = 0;       // ttaIdx
        amts[1] = 50e18;   // sharesIdx
        vm.prank(vault);
        bool ok = h.onBeforeInitialize(amts, "");
        assertTrue(ok);
        // rate = 1e18, so virtualTTA = 50e18 * 1e18 / 1e18 = 50e18
        assertEq(h.virtualTTA(), 50e18);
        assertEq(h.hookSharesDelta(), 0);
    }
}
