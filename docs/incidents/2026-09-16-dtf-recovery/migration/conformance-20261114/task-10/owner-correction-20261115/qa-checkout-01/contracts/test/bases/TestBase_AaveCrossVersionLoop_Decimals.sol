// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_AaveCrossVersionLoop} from "contracts/test/bases/TestBase_AaveCrossVersionLoop.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

/**
 * @title TestBase_AaveCrossVersionLoop_Decimals
 * @notice Aave loop two-token combos. `tokenA` is pair; keep `ERC20MintBurnOwnableOperableDFPkg`.
 * @dev Does not call gold `setUp` token construction (gold is 18+6 PARTIAL `P18_R6`).
 */
abstract contract TestBase_AaveCrossVersionLoop_Decimals is TestBase_AaveCrossVersionLoop {
    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        _deployTestTokenPkg();
        bytes32 saltA = keccak256(abi.encode("CLTA", _tokenADecimals(), _tokenBDecimals()));
        bytes32 saltB = keccak256(abi.encode("CLTB", _tokenADecimals(), _tokenBDecimals()));
        tokenA = IERC20(
            testTokenPkg.deployToken("Cross Loop Token A", "CLTA", _tokenADecimals(), address(this), saltA)
        );
        tokenB = IERC20(
            testTokenPkg.deployToken("Cross Loop Token B", "CLTB", _tokenBDecimals(), address(this), saltB)
        );
    }

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }
}
