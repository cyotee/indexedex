// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadNativeImport as ImportChecks} from "contracts/test/bases/TestBase_UniswapV4FullSpreadNativeImport.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultNativePositionImportFundingTest is Acceptance, ImportChecks {
    IPositionManager private nativePositions;
    receive() external payable {}
    function _native() internal pure override returns (bool) { return true; }
    function _positionManagerForTests() internal override returns (IPositionManager) {
        nativePositions = IPositionManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PositionManager.sol:PositionManager"),
            abi.encode(poolManager, permit2, uint256(100_000), address(0), weth),
            keccak256(abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultNativePositionImportFundingTest.PositionManager"))));
        return nativePositions;
    }
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        _startImport(vault, poolManager, nativePositions, permit2, weth, poolKey);
    }
    function test_nativeImportActualFundingExcludesPriorSleeve() public { _nativeImportFundingAndDonationExclusion(); }
    function test_nativeImportLateGuardRestoresNftAndBalances() public { _nativeImportRollback(); }
}
