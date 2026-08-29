// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_Orbital_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Policy.sol";
import {UniswapV4Detf_Alignment_RedeemD15Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15Base.sol";

/// @notice Orbital gold D15 via IRebasingClaimToken (WP-UDPL-OR). D15-5 multi-leg leftover dump.
contract UniswapV4Detf_Orbital_Alignment_RedeemD15 is
    TestBase_UniswapV4Detf_Orbital_Policy,
    UniswapV4Detf_Alignment_RedeemD15Base
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Orbital_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._deployInstance(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._expectInvalidCreationRate(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (IERC20 tok)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._mintTokenOf(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._skewSyntheticDown(d);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._pushSyntheticUp(d);
    }

    struct D15_5Snap {
        address hook;
        address largestTok;
        uint256 claimBal;
        uint256 detfBefore;
        uint256 pair0Before;
        uint256 pair1Before;
        uint256 se0Before;
        uint256 se1Before;
        uint256 lpBefore;
    }

    /// @notice D15-5: snapshot DETF-buying power once; dump largest leftover first; recipient DETF only.
    function test_D15_5_multiLegLeftoverDump() public {
        _firstBond(100 ether);
        vm.startPrank(detfUser);
        uint256 minted1_ = detfInfo.mint(
            IERC20(address(pair1)),
            50 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted1_, 0, "pair1 live so both leftover legs exist");

        (uint256 sellId,) = _firstBond(60 ether);
        _warpMature(sellId);
        _d10SellToClaimOn(detf, sellId, detfUser);

        D15_5Snap memory s = _d15_5Snapshot();
        assertGt(s.claimBal, 0, "D15-5 claim");
        assertTrue(s.largestTok != address(0), "largest leftover");

        vm.recordLogs();
        uint256 out_ = _redeemOn(detf, detfUser, s.claimBal);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();

        assertGt(out_, 0, "D15-5 DETF paid");
        assertEq(IERC20(detf).balanceOf(detfUser) - s.detfBefore, out_, "recipient DETF only");
        assertEq(pair0.balanceOf(detfUser), s.pair0Before, "pair0 unchanged");
        assertEq(pair1.balanceOf(detfUser), s.pair1Before, "pair1 unchanged");
        assertEq(IERC20(se0).balanceOf(detfUser), s.se0Before, "se0 unchanged");
        assertEq(IERC20(se1).balanceOf(detfUser), s.se1Before, "se1 unchanged");
        assertEq(IERC20(s.hook).balanceOf(detfUser), s.lpBefore, "hook LP unchanged");

        address firstDump_ = _firstOwnerSwapTokenIn(logs_, s.hook);
        if (firstDump_ != address(0)) {
            assertEq(firstDump_, s.largestTok, "largest leftover dumped first");
        }
        assertLe(IERC20(s.largestTok).balanceOf(detf), 10, "largest leftover dumped");
    }

    function _d15_5Snapshot() internal view returns (D15_5Snap memory s) {
        s.claimBal = _claimTok().balanceOf(detfUser);
        s.hook = detfInfo.hook();
        s.largestTok = _d15_5LargestLeftover(s.hook);
        s.detfBefore = IERC20(detf).balanceOf(detfUser);
        s.pair0Before = pair0.balanceOf(detfUser);
        s.pair1Before = pair1.balanceOf(detfUser);
        s.se0Before = IERC20(se0).balanceOf(detfUser);
        s.se1Before = IERC20(se1).balanceOf(detfUser);
        s.lpBefore = IERC20(s.hook).balanceOf(detfUser);
    }

    function _d15_5LargestLeftover(address hook_) internal view returns (address largestTok_) {
        IDETFNFTVault nft_ = _nft();
        uint256 orig_ = nft_.originalSharesOf(nft_.detfNFTId());
        assertGt(orig_, 0, "id0 originalShares");
        uint256 unwind_ = orig_;
        try nft_.convertToAssets(orig_) returns (uint256 a_) {
            if (a_ > 0) unwind_ = a_;
        } catch {}
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory withdrawn_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(unwind_);
        uint256 n_ = toks_.length < withdrawn_.length ? toks_.length : withdrawn_.length;
        uint256 largestQuote_;
        uint256 snapshotCount_;
        for (uint256 i; i < n_; ++i) {
            if (toks_[i] == detf || withdrawn_[i] == 0) continue;
            uint256 q_;
            try IUniswapV4SeBufferHook(hook_).previewSwapExactIn(toks_[i], detf, withdrawn_[i])
                returns (uint256 d_)
            {
                q_ = d_;
            } catch {}
            if (q_ == 0) q_ = withdrawn_[i];
            unchecked {
                ++snapshotCount_;
            }
            if (q_ > largestQuote_) {
                largestQuote_ = q_;
                largestTok_ = toks_[i];
            }
        }
        assertGt(snapshotCount_, 1, "multi-leg leftover snapshot");
    }

    function _firstOwnerSwapTokenIn(Vm.Log[] memory logs_, address hook_)
        internal
        view
        returns (address tokenIn_)
    {
        bytes4 sel_ = IUniswapV4SeBufferHook.ownerSwapExactIn.selector;
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].emitter != hook_) continue;
            if (logs_[i].topics.length == 0) continue;
        }
        sel_;
        bytes32 transferSig_ = keccak256("Transfer(address,address,uint256)");
        for (uint256 j; j < logs_.length; ++j) {
            if (logs_[j].topics.length < 3) continue;
            if (logs_[j].topics[0] != transferSig_) continue;
            address from_ = address(uint160(uint256(logs_[j].topics[1])));
            address to_ = address(uint160(uint256(logs_[j].topics[2])));
            if (to_ == hook_ && from_ == detf) {
                return logs_[j].emitter;
            }
        }
    }
}
