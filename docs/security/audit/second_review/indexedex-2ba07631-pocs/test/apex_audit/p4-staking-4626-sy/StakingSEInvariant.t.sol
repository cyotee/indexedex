// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_EtherFiWeETHStandardExchange} from "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {P4Handler, P4Invariants, IP4Host} from "./P4Common.sol";

/// @dev Shared staking host plumbing (WETH funding, fee config, selector targeting, sanity tests).
abstract contract StakingHostMixin is P4Invariants {
    P4Handler internal handler;

    function _h() internal view override returns (P4Handler) {
        return handler;
    }

    function _famName() internal pure virtual returns (string memory);

    function _wireHandler(address host_) internal {
        handler = new P4Handler(IP4Host(host_));
        // Passive honest LP (actor 0) seeds the vault through the normal SE path.
        handler.mintExactIn(0, 0, 100 ether);
        handler.mintExactIn(3 * 1000, 1, 100 ether); // actor 0 again (seed%4==0), LST leg
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: _selectors()}));
        excludeSender(address(handler));
    }

    function afterInvariant() public {
        handler.report();
        handler.persist(string.concat("p4_counts_", _famName(), ".log"));
        (uint256 ok, uint256 fail) = handler.totals();
        assertGt(ok, 0, "non-vacuous: some handler money calls succeeded");
        assertGe(ok * 100, (ok + fail) * 60, "non-vacuous: >=60% of attempted money calls succeed");
    }

    // ---- sanity: invariants catch KNOWN bugs when un-quarantined ----
    function _sanityCraneFreeMint() internal {
        handler.setAllow4626(true);
        handler.erc4626DepositExisting(); // Crane ERC4626 facet: deposit(W) with no transfer
        handler.redeemExactIn(3, 1, 10_000); // adversary exits all shares
        handler.report();
        vm.expectRevert();
        this.invariant_perOpChecks();
        vm.expectRevert();
        this.invariant_adversaryNoProfit();
        vm.expectRevert();
        this.invariant_honestNoLoss();
    }

    function _sanityRequeue() internal {
        // create a deficit: actor 1 enters with WETH, rebalance stakes down, then honest WETH exit
        handler.mintExactIn(1, 0, 150 ether);
        handler.rebalance(1);
        handler.redeemExactOut(1, 0, 1000);
        handler.rebalance(2); // queues the deficit (pending was 0) -> allowed
        assertEq(handler.queueViolations(), 0, "first rebalance queues exactly the deficit");
        handler.setAllowRequeue(true);
        for (uint256 k; k < 3; ++k) handler.rebalance(3); // adversary re-queues with pending outstanding
        handler.report();
        vm.expectRevert();
        this.invariant_queueAccounting();
    }
}

// ======================================================================== EtherFi
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// forge-config: audit.invariant.fail-on-revert = false
contract P4_EtherFi_Invariant is TestBase_EtherFiWeETHStandardExchange, StakingHostMixin, IP4Host {
    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        hermeticWeEth.setRate(1.05e18); // non-unit rate catches rounding direction bugs
        _wireHandler(address(this));
    }

    function se() external view returns (address) { return seVault; }
    function _famName() internal pure override returns (string memory) { return "etherfi"; }

    function tokens() public view returns (address[] memory t) {
        t = new address[](3);
        t[0] = address(hermeticWeth);
        t[1] = address(hermeticWeEth);
        t[2] = address(hermeticEEth);
    }

    function fund(address token, address to, uint256 amount) external {
        if (token == address(hermeticWeth)) {
            vm.deal(address(this), amount);
            hermeticWeth.deposit{value: amount}();
            hermeticWeth.transfer(to, amount);
        } else if (token == address(hermeticEEth)) {
            hermeticEEth.mint(to, amount);
        } else {
            // weETH amount -> mint eETH face then wrap
            uint256 e = hermeticWeEth.getEETHByWeETH(amount) + 2;
            hermeticEEth.mint(address(this), e);
            hermeticEEth.approve(address(hermeticWeEth), e);
            uint256 we = hermeticWeEth.wrap(e);
            hermeticWeEth.transfer(to, we < amount ? we : amount);
        }
    }

    function fairValue(address token, uint256 amount) public view returns (uint256) {
        if (token == address(hermeticWeEth)) return hermeticWeEth.getEETHByWeETH(amount);
        return amount; // WETH, eETH at face
    }

    function _pending() internal view returns (uint256 pend, uint256 fin) {
        uint256 last = hermeticQueue.lastRequestId();
        for (uint256 id = 1; id <= last; ++id) {
            (address o, uint256 amt, bool f, bool c) = hermeticQueue.requests(id);
            if (o == seVault && !c) {
                pend += amt;
                if (f) fin += amt;
            }
        }
    }

    function portPending() external view returns (uint256, uint256) { return _pending(); }

    function fairNav() public view returns (uint256) {
        (uint256 pend,) = _pending();
        return hermeticWeth.balanceOf(seVault) + hermeticWeEth.getEETHByWeETH(hermeticWeEth.balanceOf(seVault)) + pend;
    }

    function reportedNav() external view returns (uint256) { return etherFiSe.totalReserveEth(); }
    function virtShares() external pure returns (uint256) { return 1e3; }
    function navPlus() external pure returns (uint256) { return 1; }

    function outCap(address token) external view returns (uint256) {
        if (token == address(hermeticWeth)) return hermeticWeth.balanceOf(seVault);
        if (token == address(hermeticWeEth)) return hermeticWeEth.balanceOf(seVault);
        return hermeticWeEth.getEETHByWeETH(hermeticWeEth.balanceOf(seVault)); // eETH via unwrap
    }

    function bare() external view returns (address) { return address(hermeticEEth); }
    function hasQueue() external pure returns (bool) { return true; }
    function hasRebalance() external pure returns (bool) { return true; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return false; }

    function finalizeAll() external {
        uint256 last = hermeticQueue.lastRequestId();
        for (uint256 id = 1; id <= last; ++id) {
            (address o, uint256 amt, bool f,) = hermeticQueue.requests(id);
            if (o != address(0) && !f) {
                vm.deal(address(this), amt);
                hermeticQueue.finalizeForTest{value: amt}(id);
            }
        }
    }

    function moveRate(uint256 seed) external returns (bool) {
        uint256 cur = hermeticWeEth.getRate();
        uint256 bps = bound(seed, 9_700, 10_300);
        uint256 nr = cur * bps / 10_000;
        if (nr < 0.9e18 || nr > 1.5e18) return false;
        hermeticWeEth.setRate(nr);
        return true;
    }

    function invariant_navConsistency() public view {
        uint256 r = etherFiSe.totalReserveEth();
        uint256 f = fairNav();
        assertApproxEqAbs(r, f, 1e6, "vault NAV == WETH + rate*weETH + port pending face");
    }

    function invariant_bareIdleNotFromHonestFlows() public view {
        assertLe(hermeticEEth.balanceOf(seVault), handler.ghostBareDonated() + 1e6, "idle eETH only from donations");
    }

    function test_sanity_craneFreeMint_caught() public { _sanityCraneFreeMint(); }
    function test_sanity_requeue_caught() public { _sanityRequeue(); }

    receive() external payable {}
}

// ======================================================================== Lido
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// forge-config: audit.invariant.fail-on-revert = false
contract P4_Lido_Invariant is TestBase_LidoWstETHStandardExchange, StakingHostMixin, IP4Host {
    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        _wireHandler(address(this));
    }

    function se() external view returns (address) { return seVault; }
    function _famName() internal pure override returns (string memory) { return "lido"; }

    function tokens() public view returns (address[] memory t) {
        t = new address[](3);
        t[0] = address(hermeticWeth);
        t[1] = address(hermeticWstEth);
        t[2] = address(hermeticStEth);
    }

    function fund(address token, address to, uint256 amount) external {
        if (token == address(hermeticWeth)) {
            vm.deal(address(this), amount);
            hermeticWeth.deposit{value: amount}();
            hermeticWeth.transfer(to, amount);
        } else if (token == address(hermeticStEth)) {
            hermeticStEth.mint(to, amount);
        } else {
            _mintWstViaSt(to, amount);
        }
    }

    function fairValue(address, uint256 amount) public pure returns (uint256) {
        return amount; // hermetic Lido ports are fixed 1:1
    }

    function _pending() internal view returns (uint256 pend, uint256 fin) {
        uint256 last = hermeticQueue.lastRequestId();
        for (uint256 id = 1; id <= last; ++id) {
            (address o, uint256 amt, bool f, bool c) = hermeticQueue.requests(id);
            if (o == seVault && !c) {
                pend += amt;
                if (f) fin += amt;
            }
        }
    }

    function portPending() external view returns (uint256, uint256) { return _pending(); }

    function fairNav() public view returns (uint256) {
        (uint256 pend,) = _pending();
        return hermeticWeth.balanceOf(seVault) + hermeticWstEth.getStETHByWstETH(hermeticWstEth.balanceOf(seVault)) + pend;
    }

    function reportedNav() external view returns (uint256) { return lidoSe.totalReserveEth(); }
    function virtShares() external pure returns (uint256) { return 1e3; }
    function navPlus() external pure returns (uint256) { return 1; }

    function outCap(address token) external view returns (uint256) {
        if (token == address(hermeticWeth)) return hermeticWeth.balanceOf(seVault);
        return hermeticWstEth.balanceOf(seVault);
    }

    function bare() external view returns (address) { return address(hermeticStEth); }
    function hasQueue() external pure returns (bool) { return true; }
    function hasRebalance() external pure returns (bool) { return true; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return false; }

    function finalizeAll() external {
        uint256 last = hermeticQueue.lastRequestId();
        for (uint256 id = 1; id <= last; ++id) {
            (address o, uint256 amt, bool f,) = hermeticQueue.requests(id);
            if (o != address(0) && !f) {
                vm.deal(address(this), amt);
                hermeticQueue.finalizeForTest{value: amt}(id);
            }
        }
    }

    function moveRate(uint256) external pure returns (bool) { return false; } // ports are pure 1:1

    function invariant_navConsistency() public view {
        assertApproxEqAbs(lidoSe.totalReserveEth(), fairNav(), 1e6, "vault NAV == WETH + wstETH + port pending face");
    }

    function invariant_bareIdleNotFromHonestFlows() public view {
        assertLe(hermeticStEth.balanceOf(seVault), handler.ghostBareDonated() + 1e6, "idle stETH only from donations");
    }

    function test_sanity_craneFreeMint_caught() public { _sanityCraneFreeMint(); }
    function test_sanity_requeue_caught() public { _sanityRequeue(); }

    receive() external payable {}
}

// ======================================================================== Rocket
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// forge-config: audit.invariant.fail-on-revert = false
contract P4_Rocket_Invariant is TestBase_RocketPoolRETHStandardExchange, StakingHostMixin, IP4Host {
    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        hermeticReth.setRate(1.1e18);
        _enableBurn(1_000_000 ether);
        _wireHandler(address(this));
    }

    function se() external view returns (address) { return seVault; }
    function _famName() internal pure override returns (string memory) { return "rocket"; }

    function tokens() public view returns (address[] memory t) {
        t = new address[](2);
        t[0] = address(hermeticWeth);
        t[1] = address(hermeticReth);
    }

    function fund(address token, address to, uint256 amount) external {
        if (token == address(hermeticWeth)) {
            vm.deal(address(this), amount);
            hermeticWeth.deposit{value: amount}();
            hermeticWeth.transfer(to, amount);
        } else {
            hermeticReth.mint(to, amount);
        }
    }

    function fairValue(address token, uint256 amount) public view returns (uint256) {
        if (token == address(hermeticReth)) return hermeticReth.getEthValue(amount);
        return amount;
    }

    function portPending() external pure returns (uint256, uint256) { return (0, 0); }

    function fairNav() public view returns (uint256) {
        return hermeticWeth.balanceOf(seVault) + hermeticReth.getEthValue(hermeticReth.balanceOf(seVault));
    }

    function reportedNav() external view returns (uint256) { return rocketPoolSe.totalReserveEth(); }
    function virtShares() external pure returns (uint256) { return 1e3; }
    function navPlus() external pure returns (uint256) { return 1; }

    function outCap(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(seVault);
    }

    function bare() external pure returns (address) { return address(0); }
    function hasQueue() external pure returns (bool) { return false; }
    function hasRebalance() external pure returns (bool) { return true; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return false; }
    function finalizeAll() external {}

    function moveRate(uint256 seed) external returns (bool) {
        uint256 cur = hermeticReth.rateWad();
        uint256 nr = cur * bound(seed, 9_700, 10_300) / 10_000;
        if (nr < 0.9e18 || nr > 1.5e18) return false;
        hermeticReth.setRate(nr);
        return true;
    }

    function invariant_navConsistency() public view {
        assertApproxEqAbs(rocketPoolSe.totalReserveEth(), fairNav(), 1e6, "vault NAV == WETH + rate*rETH");
    }

    function test_sanity_craneFreeMint_caught() public { _sanityCraneFreeMint(); }

    receive() external payable {}
}
