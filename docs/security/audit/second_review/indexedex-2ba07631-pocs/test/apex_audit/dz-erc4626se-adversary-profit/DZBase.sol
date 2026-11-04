// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {DZHandler, DZInvariants, IDZHost} from "./DZCommon.sol";

/// @notice Generic ERC4626 SE (ReceiptBacked IERC4626 facet + SE routes + native SY), numeraire = underlying.
/// forge-config: audit.invariant.runs = 64
/// forge-config: audit.invariant.depth = 50
/// forge-config: audit.invariant.fail-on-revert = false
contract DZ_ERC4626SE_Base is TestBase_ERC4626StandardExchange, DZInvariants, IDZHost {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal seAddr;
    DZHandler internal handler;
    address internal constant DEAD = address(0xdEaD);

    function _h() internal view override returns (DZHandler) {
        return handler;
    }

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        seAddr = _deployERC4626SE(address(protocolVault));
        _zeroFee(seAddr);
        // QUARANTINE receiptbacked-first-deposit-inflation: the vault is never empty. A dead holder
        // owns 1e18 shares so supply cannot return to 0 (the known bug needs an empty vault).
        _deadSeed(seAddr, 1 ether);
        // non-unit protocol rate
        underlying.mint(address(this), 10 ether);
        underlying.approve(address(protocolVault), type(uint256).max);
        protocolVault.simulateYield(0.37 ether);
        _wire();
    }

    function _zeroFee(address v) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(v, 0);
        vm.stopPrank();
    }

    function _deadSeed(address v, uint256 amt) internal {
        underlying.mint(address(this), amt);
        underlying.approve(v, amt);
        (bool ok,) = v.call(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
                address(underlying), amt, v, 1, DEAD, false, block.timestamp
            )
        );
        require(ok, "dead seed");
    }

    function _wire() internal {
        handler = new DZHandler(IDZHost(address(this)));
        handler.mintExactIn(0, 1, 100 ether); // actor 0, underlying
        handler.mintExactIn(4, 0, 100 ether); // actor 0, receipt
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: _selectors()}));
    }

    function _famName() internal pure returns (string memory) { return "erc4626se"; }

    // ---------------------------------------------------------------- host
    function se() external view returns (address) { return seAddr; }

    function tokens() public view returns (address[] memory t) {
        t = new address[](2);
        t[0] = address(protocolVault);
        t[1] = address(underlying);
    }

    function fund(address token, address to, uint256 amount) external {
        if (token == address(underlying)) {
            underlying.mint(to, amount);
        } else {
            uint256 a = protocolVault.previewMint(amount) + 1;
            underlying.mint(address(this), a);
            protocolVault.mint(amount, to);
        }
    }

    function fairValue(address token, uint256 amount) public view returns (uint256) {
        if (token == address(protocolVault)) return protocolVault.convertToAssets(amount);
        return amount;
    }

    function _local() internal view returns (uint256) {
        uint256 booked = IBasicVault(seAddr).reserveOfToken(address(underlying));
        uint256 bal = underlying.balanceOf(seAddr);
        return booked < bal ? booked : bal;
    }

    function fairNav() public view returns (uint256) {
        return protocolVault.convertToAssets(protocolVault.balanceOf(seAddr)) + _local();
    }

    function reportedNav() public view returns (uint256) {
        return protocolVault.convertToAssets(IERC4626(seAddr).totalAssets());
    }

    function virtShares() external pure returns (uint256) { return 0; }
    function navPlus() external pure returns (uint256) { return 0; }

    function outCap(address token) external view returns (uint256) {
        if (token == address(protocolVault)) return protocolVault.balanceOf(seAddr);
        return fairNav();
    }

    function bare() external pure returns (address) { return address(0); }
    function hasQueue() external pure returns (bool) { return false; }
    function portPending() external pure returns (uint256, uint256) { return (0, 0); }
    function finalizeAll() external {}
    function hasRebalance() external pure returns (bool) { return false; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return true; }

    function moveRate(uint256 seed) external returns (bool) {
        uint256 ta = protocolVault.totalAssets();
        uint256 y = ta * bound(seed, 1, 300) / 10_000; // up to +3% yield (exogenous)
        if (y == 0) return false;
        underlying.mint(address(this), y);
        protocolVault.simulateYield(y);
        return true;
    }

    // ---------------------------------------------------------------- family invariants
    function invariant_navConsistency() public view {
        // ReceiptBacked totalAssets (receipt units) vs independent held receipts + local underlying
        assertApproxEqAbs(reportedNav(), fairNav(), 1e6, "IERC4626.totalAssets == held receipts + booked local");
    }

    function invariant_convertToAssetsConsistency() public view {
        uint256 s = IERC20(seAddr).totalSupply();
        if (s == 0) return;
        uint256 probe = s / 7 + 1;
        uint256 c = IERC4626(seAddr).convertToAssets(probe); // receipt units
        uint256 p = IERC4626(seAddr).previewRedeem(probe);
        uint256 fair = probe * IERC4626(seAddr).totalAssets() / s;
        assertLe(p, c + 1, "previewRedeem <= convertToAssets");
        assertApproxEqAbs(c, fair, 2, "convertToAssets == shares * backing / supply");// SE redemption preview to receipts equals the IERC4626 view
        (uint256 seView,) = IStdExDZ(seAddr).previewExchangeIn(IERC20(seAddr), probe, IERC20(address(protocolVault)));
        assertApproxEqAbs(seView, c, 2, "SE previewExchangeIn(share->receipt) == convertToAssets");
    }

    function afterInvariant() public {
        handler.report();
        handler.persist(string.concat("p4_counts_", _famName(), ".log"));
        (uint256 ok, uint256 fail) = handler.totals();
        assertGt(ok, 0, "non-vacuous");
        assertGe(ok * 100, (ok + fail) * 60, "non-vacuous: >=60% of attempted money calls succeed");
    }

    // ---------------------------------------------------------------- sanity: known bug is caught
    /// Un-quarantined: fresh EMPTY vault (no dead seed) -> receiptbacked-first-deposit-inflation.
    function test_sanity_receiptBackedInflation_caught() public {
        SimpleYieldERC4626 pv2 = new SimpleYieldERC4626(underlying);
        protocolVault = pv2;
        seAddr = _deployERC4626SE(address(pv2));
        _zeroFee(seAddr);
        underlying.approve(address(pv2), type(uint256).max);
        handler = new DZHandler(IDZHost(address(this)));
        address adv = handler.wallet(3);
        address vic = handler.wallet(1);
        handler.sanityFund(3, address(pv2), 10_001 ether);
        handler.sanityExec(3, address(pv2), abi.encodeCall(IERC20.approve, (seAddr, type(uint256).max)));
        handler.sanityExec(3, seAddr, abi.encodeCall(IERC4626.deposit, (1, adv)));
        handler.sanityExec(3, address(pv2), abi.encodeCall(IERC20.transfer, (seAddr, 10_000 ether)));
        handler.sanityFund(1, address(pv2), 9_999 ether);
        handler.sanityExec(1, address(pv2), abi.encodeCall(IERC20.approve, (seAddr, type(uint256).max)));
        handler.sanityExec(1, seAddr, abi.encodeCall(IERC4626.deposit, (9_999 ether, vic)));
        console2.log("victim shares", IERC20(seAddr).balanceOf(vic));
        handler.report();
        vm.expectRevert();
        this.invariant_honestNoLoss();
        vm.expectRevert();
        this.invariant_adversaryNoProfit();
    }
}

interface IStdExDZ {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
}
