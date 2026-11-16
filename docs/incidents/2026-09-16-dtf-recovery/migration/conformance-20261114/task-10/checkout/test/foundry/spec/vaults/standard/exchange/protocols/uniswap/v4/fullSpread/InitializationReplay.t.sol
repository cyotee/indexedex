// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFactoryCallBack} from "@crane/contracts/interfaces/IFactoryCallBack.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault as TestBase, IFullSpreadVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVault_InitializationReplay_Test is TestBase {
    function test_doubleInitializationAbortsRealProxyConstruction() public {
        FullSpreadInitReplayDriver driver = new FullSpreadInitReplayDriver(diamondFactory);
        IPackage.PkgInit memory init_ = packageInit;
        init_.diamondFactory = IDiamondPackageCallBackFactory(address(driver));
        bytes memory packageCode = ArtifactCreationCode.creationCode(
            "UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadStandardExchangeVaultDFPkg"
        );
        vm.prank(owner);
        IPackage replayPackage = IPackage(indexedexManager.deployPkg(
            packageCode, abi.encode(init_), keccak256(abi.encode("FullSpread.InitializationReplay.Package", init_))
        ));
        assertEq(replayPackage.bindingHash(), keccak256(abi.encode(init_)));
        bytes memory args = abi.encode(IPackage.PkgArgs(key));
        bytes memory proxyCode = ArtifactCreationCode.creationCode(
            "MinimalDiamondCallBackProxy.sol:MinimalDiamondCallBackProxy"
        );
        bytes32 salt = keccak256("FullSpread.InitializationReplay");
        address predicted = driver.predict(salt);
        bytes32 registryBefore = keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults()));

        vm.expectRevert(IPackage.AlreadyInitialized.selector);
        driver.deploy(IDiamondFactoryPackage(address(replayPackage)), args, proxyCode, salt, true);
        assertEq(predicted.code.length, 0, "second initialization leaves no usable proxy");
        assertEq(address(driver.pkgOfAccount(predicted)), address(0), "failed construction rolls back registration");
        assertEq(driver.pkgArgsOfAccount(predicted).length, 0);
        assertFalse(driver.repeatOfAccount(predicted));
        assertEq(vm.load(predicted, bytes32(uint256(Repo.STORAGE_SLOT) + 5)), bytes32(0),
            "first initialization storage rolled back with construction");
        assertEq(keccak256(abi.encode(IVaultRegistryVaultQuery(address(indexedexManager)).vaults())), registryBefore);

        // The identical real-code constructor succeeds when the replay is disabled.
        address control = driver.deploy(IDiamondFactoryPackage(address(replayPackage)), args, proxyCode, salt, false);
        assertEq(control, predicted);
        assertGt(control.code.length, 0);
        assertEq(IFullSpreadVault(control).totalSupply(), 0);
        address[] memory faces = IFullSpreadVault(control).vaultTokens();
        assertEq(faces.length, 2);
        assertEq(faces[0], address(token0));
        assertEq(faces[1], address(token1));
        IStandardVault.VaultConfig memory config = IStandardVault(control).vaultConfig();
        vm.prank(owner);
        assertTrue(IVaultRegistryVaultManager(address(indexedexManager)).registerVault(control, address(replayPackage), config));
        _fund(address(this), 100 ether, 100 ether);
        _approve(control);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        (uint256 minted,) = IFullSpreadVault(control).exchangeBundleInForSingleOut(
            amounts, control, 1, address(this), false, block.timestamp
        );
        assertGt(minted, 0, "single-initialization control reaches real money execution");
        assertEq(IERC20(control).balanceOf(address(this)), minted);
        assertEq(IERC20(control).balanceOf(address(0)), 1000);
    }
}

/// @dev Non-SUT fault driver for the constructor replay that the production factory
/// never performs. Uses exact production proxy creation code and delegates the first
/// initialization and finalization to the real factory implementation. The package,
/// facets, proxy, manager and registry remain real; no SUT storage is injected.
contract FullSpreadInitReplayDriver is IFactoryCallBack {
    address private immutable SELF = address(this);
    IDiamondPackageCallBackFactory private immutable FACTORY;
    bytes32 private immutable PROXY_HASH;
    mapping(address => IDiamondFactoryPackage) public pkgOfAccount;
    mapping(address => bytes) public pkgArgsOfAccount;
    mapping(address => bool) public repeatOfAccount;

    constructor(IDiamondPackageCallBackFactory factory_) {
        FACTORY = factory_;
        PROXY_HASH = factory_.PROXY_INIT_HASH();
    }

    function predict(bytes32 salt_) public view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), SELF, salt_, PROXY_HASH)))));
    }

    function deploy(IDiamondFactoryPackage pkg_, bytes memory args_, bytes memory code_, bytes32 salt_, bool repeat_)
        external returns (address account_)
    {
        require(keccak256(code_) == PROXY_HASH, "production proxy code");
        address expected_ = predict(salt_);
        pkgOfAccount[expected_] = pkg_;
        pkgArgsOfAccount[expected_] = args_;
        repeatOfAccount[expected_] = repeat_;
        pkg_.updatePkg(expected_, args_);
        assembly ("memory-safe") {
            account_ := create2(0, add(code_, 32), mload(code_), salt_)
            if iszero(account_) {
                let size := returndatasize()
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        require(account_ == expected_, "predicted proxy");
        pkg_.postDeploy(account_);
    }

    function pkgConfig() external view returns (IDiamondFactoryPackage pkg_, bytes memory args_) {
        return (pkgOfAccount[msg.sender], pkgArgsOfAccount[msg.sender]);
    }

    function initAccount() external returns (bool) {
        require(address(this) != SELF && msg.sender == SELF, "constructor callback only");
        (IDiamondFactoryPackage pkg_, bytes memory args_) = IFactoryCallBack(SELF).pkgConfig();
        _delegate(address(FACTORY), abi.encodeCall(IDiamondPackageCallBackFactory.initAccount, (pkg_, args_)));
        if (FullSpreadInitReplayDriver(SELF).repeatOfAccount(address(this))) {
            _delegate(address(pkg_), abi.encodeCall(IDiamondFactoryPackage.initAccount, (args_)));
        }
        _delegate(address(FACTORY), abi.encodeWithSignature("postDeploy(address)", address(this)));
        return true;
    }

    function _delegate(address target_, bytes memory data_) private {
        (bool ok_, bytes memory result_) = target_.delegatecall(data_);
        if (!ok_) {
            assembly ("memory-safe") {
                revert(add(result_, 32), mload(result_))
            }
        }
    }
}
