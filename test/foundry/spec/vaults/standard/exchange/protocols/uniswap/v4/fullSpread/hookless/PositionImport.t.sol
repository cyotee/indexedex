// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport as Import} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";

// tag::HooklessPositionImportTest[]
contract HooklessPositionImportTest is Acceptance {
    using PoolIdLibrary for *;
    IPositionManager internal positions;

    function _positionManagerForTests() internal override returns (IPositionManager) {
        // Descriptor is not exercised by mint/import; all financial components are real.
        positions = IPositionManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PositionManager.sol:PositionManager"),
            abi.encode(poolManager, permit2, uint256(100_000), address(0), weth),
            keccak256(abi.encode("HooklessPositionImportTest.PositionManager"))
        ));
        return positions;
    }

    function test_narrowNftConvertsToFullRangeAndRetainsEmptyNft() public {
        uint256 id = _mintPosition();
        token0.transfer(address(vault), 1e18);
        token1.transfer(address(vault), 1e18);
        uint256 received = Import(address(vault)).importPosition(positions, id, 0, address(this), address(this), block.timestamp);
        assertGt(received, 0);
        assertEq(vault.balanceOf(address(this)), received);
        assertGt(vault.balanceOf(address(0xdEaD)), 1e15);
        assertEq(positions.getPositionLiquidity(id), 0);
        assertEq(IERC721(address(positions)).ownerOf(id), address(vault));
        (uint128 liquidity,,) = StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault),
            TickMath.minUsableTick(60), TickMath.maxUsableTick(60), bytes32(0));
        assertGt(liquidity, 0);
        _assertBooked();
    }

    function test_importDuringOuterUnlockRejectedWithoutNftTransfer() public {
        uint256 id = _mintPosition();
        vm.expectRevert(Common.UniswapV4Exchange_PoolManagerInteractionBlocked.selector);
        _nested(abi.encodeCall(Import.importPosition, (positions, id, 0, address(this), address(this), block.timestamp)));
        assertEq(IERC721(address(positions)).ownerOf(id), address(this));
        assertGt(positions.getPositionLiquidity(id), 0);
    }

    function _mintPosition() internal returns (uint256 id_) {
        token0.approve(address(permit2), type(uint256).max);
        token1.approve(address(permit2), type(uint256).max);
        permit2.approve(address(token0), address(positions), type(uint160).max, type(uint48).max);
        permit2.approve(address(token1), address(positions), type(uint160).max, type(uint48).max);
        id_ = positions.nextTokenId();
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, int24(-120), int24(120), uint256(1_000e18), uint128(10e18), uint128(10e18), address(this), bytes(""));
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        positions.modifyLiquidities(abi.encode(abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR)), params), block.timestamp);
        IERC721(address(positions)).approve(address(vault), id_);
    }
}
// end::HooklessPositionImportTest[]
