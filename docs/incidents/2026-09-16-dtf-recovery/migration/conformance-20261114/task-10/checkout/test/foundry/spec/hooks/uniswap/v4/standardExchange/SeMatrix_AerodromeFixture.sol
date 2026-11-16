// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {Router} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Router.sol";
import {PoolFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/PoolFactory.sol";
import {GaugeFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/GaugeFactory.sol";
import {
    VotingRewardsFactory
} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/VotingRewardsFactory.sol";
import {
    ManagedRewardsFactory
} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/ManagedRewardsFactory.sol";
import {FactoryRegistry} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/FactoryRegistry.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/IAerodromeStandardExchangeDFPkg.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {HermeticWETH} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_AerodromeFixture
 * @notice Aerodrome V1 SE row fixture (PRD §5, M6). Face token = pair token A, an 18-decimal
 *         `SimpleMintableERC20` created here; `otherToken()` = pair token B. A volatile pool is
 *         created on a real hermetic `PoolFactory` and seeded through the real `Router`
 *         (`TestBase_Aerodrome_Pools` pattern) before the SE is deployed through the production
 *         `AerodromeStandardExchangeDFPkg` on the IndexedEx manager registry.
 * @dev The router needs a `FactoryRegistry` whose fallback pool factory is this one (the registry
 *      requires nonzero voting-rewards, gauge and managed-rewards factories, deployed as the
 *      cheap stubs `TestBase_Aerodrome` uses). The SE only calls `swapExactTokensForTokens`,
 *      `addLiquidity` and `removeLiquidity`, none of which reads the router's forwarder or voter,
 *      so those are `address(0)`; the full veAERO stack is not stood up.
 * @dev Idempotence: the package binds `aerodromePoolFactory` and `aerodromeRouter` as immutables
 *      with no getters and is CREATE3-deployed under a release salt. A later fixture of the same
 *      test passes the previous fixture as `existingFixture` and reuses its `pkg()`, `poolFactory()`
 *      and `router()`; only the tokens, the pool and the SE are new. `address(0)` deploys everything.
 * @dev R14 / D33: Aerodrome has no protocol capacity gate, so `limitCapacity` only records intent
 *      and `hasPartialCase()` is false (rounding-to-zero control). The leftover case is covered by
 *      `seBooked()` (`reserveOfToken(face)`) and `test_row_ammCallerFundSeparation`.
 */
contract SeMatrix_AerodromeFixture is SeMatrixFixture {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;

    uint256 public constant SEED_LIQUIDITY = 1_000_000 ether;

    /// @dev The test contract that created this fixture; it owns `create3Factory` (CraneTest `initEnv`).
    address internal immutable deployer;

    IPoolFactory public poolFactory;
    IRouter public router;
    IAerodromeStandardExchangeDFPkg public sePkg;

    SimpleMintableERC20 public tokenA;
    SimpleMintableERC20 public tokenB;
    IPool public pool;
    address internal seVault;

    /// @dev Recorded `limitCapacity` intent; AMMs cannot honour it (see contract NatSpec).
    uint256 public capacityIntent;
    bool public capacityLimited;

    constructor(Ctx memory c, address existingFixture) SeMatrixFixture(c) {
        deployer = msg.sender;
        if (existingFixture != address(0)) {
            SeMatrix_AerodromeFixture prev = SeMatrix_AerodromeFixture(existingFixture);
            poolFactory = prev.poolFactory();
            router = prev.router();
            sePkg = prev.sePkg();
        } else {
            _deployProtocol();
            sePkg = _deployPkg(c);
        }
        tokenA = new SimpleMintableERC20("SeMatrix Aero A", "smAA");
        tokenB = new SimpleMintableERC20("SeMatrix Aero B", "smAB");
        pool = IPool(poolFactory.createPool(address(tokenA), address(tokenB), false));
        seedLiquidity(SEED_LIQUIDITY);
        vm.prank(c.owner);
        seVault = sePkg.deployVault(pool);
        vm.label(seVault, "SeMatrix Aerodrome SE");
    }

    /// @notice Package deployed by the first fixture of a test; later fixtures reuse it.
    function pkg() public view returns (address) {
        return address(sePkg);
    }

    /// @notice Add `amountEach` of both pool tokens as independent LP (the fixture holds the LP, not the SE).
    function seedLiquidity(uint256 amountEach) public {
        tokenA.mint(address(this), amountEach);
        tokenB.mint(address(this), amountEach);
        tokenA.approve(address(router), amountEach);
        tokenB.approve(address(router), amountEach);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            false,
            amountEach,
            amountEach,
            0,
            0,
            address(this),
            block.timestamp + 1 hours
        );
    }

    function _deployProtocol() internal {
        Pool impl_ = new Pool();
        PoolFactory factory_ = new PoolFactory(address(impl_));
        FactoryRegistry registry_ = new FactoryRegistry(
            address(factory_),
            address(new VotingRewardsFactory()),
            address(new GaugeFactory()),
            address(new ManagedRewardsFactory())
        );
        HermeticWETH weth_ = new HermeticWETH();
        Router router_ = new Router(address(0), address(registry_), address(factory_), address(0), address(weth_));
        poolFactory = IPoolFactory(address(factory_));
        router = IRouter(address(router_));
    }

    function _deployPkg(Ctx memory c) internal returns (IAerodromeStandardExchangeDFPkg pkg_) {
        IAerodromeStandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        init.erc4626Facet = c.erc4626Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        // Facet deployment is owner/operator-gated on the create3 factory; the test contract owns it.
        vm.startPrank(deployer);
        init.aerodromeStandardExchangeInFacet = c.create3Factory.deployAerodromeStandardExchangeInFacet();
        init.aerodromeStandardExchangeOutFacet = c.create3Factory.deployAerodromeStandardExchangeOutFacet();
        init.aerodromeStandardExchangeOutQueryFacet = c.create3Factory.deployAerodromeStandardExchangeOutQueryFacet();
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        init.aerodromeRouter = router;
        init.aerodromePoolFactory = poolFactory;
        // Package deployment goes through the manager registry as the registry operator.
        vm.startPrank(c.owner);
        pkg_ = Aerodrome_Component_FactoryService.deployAerodromeStandardExchangeDFPkg(
            IVaultRegistryDeployment(address(c.indexedexManager)), init
        );
        vm.stopPrank();
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "AerodromeStandardExchange";
    }

    function faceToken() public view override returns (address) {
        return address(tokenA);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------ funding ------------------------------ */

    function fund(address to, uint256 amount) external override {
        tokenA.mint(to, amount);
    }

    /* -------------------------- R14 partial case -------------------------- */

    /// @inheritdoc SeMatrixFixture
    /// @dev False: an Aerodrome pool has no capacity gate, so `limitCapacity` cannot be honoured and
    ///      the row runs the rounding-to-zero control. D33 leftover handling is asserted by the AMM row.
    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    /// @dev Records intent only; AMM capacity is not gated.
    function limitCapacity(uint256 allowFace) external override {
        capacityIntent = allowFace;
        capacityLimited = true;
    }

    function openCapacity() external override {
        capacityIntent = 0;
        capacityLimited = false;
    }

    /// @notice The SE's reserved face leftover (unpaired remainder / exact-out quote leftover, D33).
    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(tokenA));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @dev Zap-in ends in `router.addLiquidity` -> `pool.mint(address)`; rejecting the pool's mint
    ///      makes the SE's operative investment revert after every precheck and the swap leg.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(bytes4(keccak256("mint(address)"))), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* ------------------------------- AMM ---------------------------------- */

    function isAmm() external pure override returns (bool) {
        return true;
    }

    function otherToken() external view override returns (address) {
        return address(tokenB);
    }

    function fundOther(address to, uint256 amount) external override {
        tokenB.mint(to, amount);
    }
}
