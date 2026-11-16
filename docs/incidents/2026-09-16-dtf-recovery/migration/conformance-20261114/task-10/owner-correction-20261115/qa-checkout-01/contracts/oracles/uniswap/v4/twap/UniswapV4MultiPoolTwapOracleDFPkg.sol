// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapOraclePoolManagerAwareRepo
} from "contracts/oracles/uniswap/v4/twap/aware/UniswapV4TwapOraclePoolManagerAwareRepo.sol";

contract UniswapV4MultiPoolTwapOracleDFPkg is IUniswapV4MultiPoolTwapOracleDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable TWAP_ORACLE_FACET;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    mapping(address => address) internal _expectedPoolManager;

    constructor(PkgInit memory pkgInit) {
        TWAP_ORACLE_FACET = pkgInit.twapOracleFacet;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function deployOracle(PkgArgs calldata args) external returns (IUniswapV4MultiPoolTwapOracle oracle) {
        bytes memory encoded = abi.encode(args);
        address predicted = DIAMOND_FACTORY.calcAddress(this, encoded);
        if (predicted.code.length > 0) {
            return IUniswapV4MultiPoolTwapOracle(predicted);
        }
        address deployed = DIAMOND_FACTORY.deploy(this, encoded);
        emit OracleDeployed(deployed, args.poolManager);
        return IUniswapV4MultiPoolTwapOracle(deployed);
    }

    function packageName() public pure returns (string memory name_) {
        return type(UniswapV4MultiPoolTwapOracleDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](1);
        facetAddresses_[0] = address(TWAP_ORACLE_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4MultiPoolTwapOracle).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](1);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(TWAP_ORACLE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: TWAP_ORACLE_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory decoded = abi.decode(pkgArgs, (PkgArgs));
        return keccak256(abi.encode(decoded.poolManager));
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory processedPkgArgs) {
        PkgArgs memory decoded = abi.decode(pkgArgs, (PkgArgs));
        if (decoded.poolManager == address(0)) {
            revert IUniswapV4MultiPoolTwapOracle.ZeroPoolManager();
        }
        return pkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public returns (bool) {
        PkgArgs memory decoded = abi.decode(pkgArgs, (PkgArgs));
        _expectedPoolManager[expectedProxy] = decoded.poolManager;
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decoded = abi.decode(initArgs, (PkgArgs));
        UniswapV4TwapOraclePoolManagerAwareRepo._initialize(IPoolManager(decoded.poolManager));
    }

    function postDeploy(address account) public returns (bool) {
        address expected = _expectedPoolManager[account];
        delete _expectedPoolManager[account];
        if (IUniswapV4MultiPoolTwapOracle(account).poolManager() != expected) {
            revert IUniswapV4MultiPoolTwapOracle.PoolManagerMismatch();
        }
        return true;
    }
}
