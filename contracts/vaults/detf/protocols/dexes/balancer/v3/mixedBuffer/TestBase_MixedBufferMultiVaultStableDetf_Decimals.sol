// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as Math} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_MixedBufferMultiVaultStableDetf} from "./TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "./MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @notice Real decimal token books; funded package deployments and lifecycle helpers are shared.
abstract contract TestBase_MixedBufferMultiVaultStableDetf_Decimals is
    TestBase_MixedBufferMultiVaultStableDetf
{
    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal rateAsset;
    MintableERC20Decimals internal otherToken;
    MintableERC20Decimals internal restToken;

    uint8[3] private selectedNativeBook = [uint8(18), 18, 18];

    event NativeDecimalBook(uint8 pairDecimals, uint8 rateDecimals, uint8 restDecimals);

    function _pairDecimals() internal view virtual returns (uint8) { return selectedNativeBook[0]; }
    function _rateDecimals() internal view virtual returns (uint8) { return selectedNativeBook[1]; }
    function _restDecimals() internal view virtual returns (uint8) { return selectedNativeBook[2]; }

    /// @dev Each assertion runs against eight fresh token/SE/DETF books on shared real infrastructure.
    /// Snapshot restoration isolates the books without duplicating compiled test contracts.
    function _runAllNativeBooks(function() internal setup_, function() internal assertion_) internal {
        _initializeMixedInfrastructure();
        uint8[3][8] memory books_ = [
            [uint8(6), 6, 6], [uint8(9), 9, 9], [uint8(6), 9, 18], [uint8(6), 18, 18],
            [uint8(9), 6, 18], [uint8(9), 18, 18], [uint8(18), 6, 18], [uint8(18), 9, 18]
        ];
        for (uint256 i_; i_ < books_.length; ++i_) {
            uint256 snapshot_ = vm.snapshotState();
            selectedNativeBook = books_[i_];
            emit NativeDecimalBook(books_[i_][0], books_[i_][1], books_[i_][2]);
            setup_();
            assertion_();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function _fixtureBufferToken() internal view virtual override returns (IERC20) {
        return IERC20(address(pairToken));
    }

    function _initializeMixedFixtureLegs() internal virtual override {
        fixtureBufferDecimals = _pairDecimals();
        _initComboTokens();
        _createComboFirstSeVault();
        seVaults[0] = daiUsdcVault;
        seShares[0] = IERC20(address(daiUsdcVault));
        legTokenA[0] = address(pairToken);
        legTokenB[0] = address(rateAsset);
        seVaultReady = 1;
    }

    function _warpPastUnlock(address instance_, uint256 tokenId_) internal {
        Math.BondPosition memory position_ = _bondNftVault(instance_).positionOf(tokenId_);
        uint256 end_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < end_) vm.warp(end_);
    }

    function _bondNftVault(address instance_) internal view returns (IDetfBondNFT) {
        return IDetfBondNFT(IMixedBufferMultiVaultStableDetfInfo(instance_).bondNftVault());
    }

    function _from18(address token, uint256 wad) internal view returns (uint256 raw) {
        uint8 d = MintableERC20Decimals(token).decimals();
        if (d == 18) return wad;
        if (d > 18) return wad * (10 ** (uint256(d) - 18));
        raw = wad / (10 ** (18 - uint256(d)));
        if (raw == 0) raw = 1;
    }

    function _mintCombo(MintableERC20Decimals token, address to, uint256 wad18) internal {
        token.mint(to, _from18(address(token), wad18));
    }

    function _initComboTokens() internal {
        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        rateAsset = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        otherToken = rateAsset;
        restToken = new MintableERC20Decimals("Rest", "REST", _restDecimals());
        vm.label(address(pairToken), "pairToken");
        vm.label(address(rateAsset), "rateAsset");
        vm.label(address(restToken), "restToken");
    }

    function _deployExtraDaiSeVault(uint8 idx) internal virtual override {
        if (idx == 0) return; // already set from daiUsdcVault
        // Pair/buffer token is pairToken (documented mixed-buffer pair). Other legs use rate/rest.
        address tokenA = address(pairToken);
        // First SE is pairToken/rateAsset. Extra vaults must use a distinct second asset
        // or Aerodrome createPool / DETF reserve deploy reverts PoolAlreadyExists.
        address tokenB = idx == 1 ? address(restToken) : address(new MintableERC20Decimals("ExtraB", "EXB", _restDecimals()));
        address poolAddr = aerodromePoolFactory.createPool(tokenA, tokenB, false);
        Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroDaiPair_", vm.toString(uint256(idx))));

        uint256 amt = AERODROME_POOL_INIT_AMOUNT;
        _mintToken(tokenA, address(this), amt);
        _mintToken(tokenB, address(this), amt);
        IERC20(tokenA).approve(address(aerodromeRouter), amt);
        IERC20(tokenB).approve(address(aerodromeRouter), amt);
        aerodromeRouter.addLiquidity(tokenA, tokenB, false, amt, amt, 1, 1, address(this), block.timestamp + 1 hours);

        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVaults[idx] = IStandardExchangeProxy(vaultAddr);
        seShares[idx] = IERC20(vaultAddr);
        legTokenA[idx] = tokenA;
        legTokenB[idx] = tokenB;
        vm.label(vaultAddr, string.concat("SeVault_dai_", vm.toString(uint256(idx))));
    }

    function _createComboFirstSeVault() internal {
        // WAD-raw both legs so SE books stay deep enough for pool-pkg buffer probes
        // (1 whole token and 1e18) on every decimal combo.
        uint256 initPair = AERODROME_POOL_INIT_AMOUNT;
        uint256 initRate = AERODROME_POOL_INIT_AMOUNT;
        address poolAddr = aerodromePoolFactory.createPool(address(pairToken), address(rateAsset), false);
        aeroDaiUsdcPool = Pool(poolAddr);
        pairToken.mint(lp, initPair);
        rateAsset.mint(lp, initRate);
        vm.startPrank(lp);
        pairToken.approve(address(aerodromeRouter), initPair);
        rateAsset.approve(address(aerodromeRouter), initRate);
        aerodromeRouter.addLiquidity(
            address(pairToken), address(rateAsset), false, initPair, initRate, 1, 1, lp, block.timestamp + 1 hours
        );
        vm.stopPrank();
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(address(aeroDaiUsdcPool)));
        daiUsdcVault = IStandardExchangeProxy(vaultAddr);
        _approveVaultForAllUsers();
    }

}
