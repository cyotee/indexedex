// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";

/**
 * @title TestBase_AaveCrossVersionLoopV3Market_Decimals
 * @notice V3+V4 loop markets with combo-decimal `tokenA`/`tokenB`. pairToken = tokenA.
 * @dev Does not call gold Loop `setUp` (18+6). Reuses `_setUpV4Market` / `_setUpV3Market`.
 */
abstract contract TestBase_AaveCrossVersionLoopV3Market_Decimals is TestBase_AaveCrossVersionLoopV3Market {
    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        _deployTestTokenPkg();
        bytes32 saltA = keccak256(abi.encode("CLTA", _tokenADecimals(), _tokenBDecimals(), "v3m"));
        bytes32 saltB = keccak256(abi.encode("CLTB", _tokenADecimals(), _tokenBDecimals(), "v3m"));
        tokenA = IERC20(
            testTokenPkg.deployToken("Cross Loop Token A", "CLTA", _tokenADecimals(), address(this), saltA)
        );
        tokenB = IERC20(
            testTokenPkg.deployToken("Cross Loop Token B", "CLTB", _tokenBDecimals(), address(this), saltB)
        );
        _setUpV4Market();
        _setUpV3Market();
    }

    function _uA(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }
}
