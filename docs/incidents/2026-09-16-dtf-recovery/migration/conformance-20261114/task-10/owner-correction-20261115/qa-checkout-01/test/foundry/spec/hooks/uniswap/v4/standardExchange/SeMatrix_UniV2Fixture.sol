// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/IUniswapV2StandardExchangeDFPkg.sol";
import {
    UniswapV2_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {HermeticWETH} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_UniV2Fixture
 * @notice Uni V2 SE row fixture (PRD §5, M6). Face token = pair token A, an 18-decimal
 *         `SimpleMintableERC20` created here; `otherToken()` = pair token B. The pair is created on
 *         a real hermetic `UniV2Factory` / `UniV2Router02` and seeded through `router.addLiquidity`
 *         (the `TestBase_UniswapV2_Pools` pattern) before the SE is deployed through the production
 *         `UniswapV2StandardExchangeDFPkg` on the IndexedEx manager registry, so the SE can quote.
 * @dev Idempotence: the package is CREATE3-deployed under a release salt and binds the factory and
 *      router as immutables with no getters. A later fixture of the same test therefore passes the
 *      previous fixture as `existingFixture` and reuses its `pkg()`, `factory()` and `router()`;
 *      only the tokens, the pair and the SE are new. `address(0)` deploys everything.
 * @dev R14 / D33: Uni V2 has no protocol capacity gate, so `limitCapacity` only records intent and
 *      `hasPartialCase()` is false (the row runs the rounding-to-zero control). The AMM leftover
 *      case is covered by `seBooked()` (the SE's reserved face leftover, `reserveOfToken(face)`)
 *      and `test_row_ammCallerFundSeparation`: booked leftover is never refunded or paired with a
 *      later caller's other token.
 */
contract SeMatrix_UniV2Fixture is SeMatrixFixture {
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;

    uint256 public constant SEED_LIQUIDITY = 1_000_000 ether;

    /// @dev The test contract that created this fixture; it owns `create3Factory` (CraneTest `initEnv`).
    address internal immutable deployer;

    IUniswapV2Factory public factory;
    IUniswapV2Router public router;
    IUniswapV2StandardExchangeDFPkg public sePkg;

    SimpleMintableERC20 public tokenA;
    SimpleMintableERC20 public tokenB;
    IUniswapV2Pair public pair;
    address internal seVault;

    /// @dev Recorded `limitCapacity` intent; AMMs cannot honour it (see contract NatSpec).
    uint256 public capacityIntent;
    bool public capacityLimited;

    constructor(Ctx memory c, address existingFixture) SeMatrixFixture(c) {
        deployer = msg.sender;
        if (existingFixture != address(0)) {
            SeMatrix_UniV2Fixture prev = SeMatrix_UniV2Fixture(existingFixture);
            factory = prev.factory();
            router = prev.router();
            sePkg = prev.sePkg();
        } else {
            HermeticWETH weth_ = new HermeticWETH();
            factory = IUniswapV2Factory(address(new UniV2Factory(c.owner)));
            router = IUniswapV2Router(address(new UniV2Router02(address(factory), address(weth_))));
            sePkg = _deployPkg(c);
        }
        tokenA = new SimpleMintableERC20("SeMatrix UniV2 A", "smUA");
        tokenB = new SimpleMintableERC20("SeMatrix UniV2 B", "smUB");
        pair = IUniswapV2Pair(factory.createPair(address(tokenA), address(tokenB)));
        seedLiquidity(SEED_LIQUIDITY);
        vm.prank(c.owner);
        seVault = sePkg.deployVault(pair);
        vm.label(seVault, "SeMatrix UniV2 SE");
    }

    /// @notice Package deployed by the first fixture of a test; later fixtures reuse it.
    function pkg() public view returns (address) {
        return address(sePkg);
    }

    /// @notice Add `amountEach` of both pair tokens as independent LP (the fixture holds the LP, not the SE).
    function seedLiquidity(uint256 amountEach) public {
        tokenA.mint(address(this), amountEach);
        tokenB.mint(address(this), amountEach);
        tokenA.approve(address(router), amountEach);
        tokenB.approve(address(router), amountEach);
        router.addLiquidity(
            address(tokenA), address(tokenB), amountEach, amountEach, 0, 0, address(this), block.timestamp + 1 hours
        );
    }

    function _deployPkg(Ctx memory c) internal returns (IUniswapV2StandardExchangeDFPkg pkg_) {
        IUniswapV2StandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc2612Facet = c.erc2612Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc4626Facet = c.erc4626Facet;
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        // Facet deployment is owner/operator-gated on the create3 factory; the test contract owns it.
        vm.startPrank(deployer);
        init.uniswapV2StandardExchangeInFacet = c.create3Factory.deployUniswapV2StandardExchangeInFacet();
        init.uniswapV2StandardExchangeOutFacet = c.create3Factory.deployUniswapV2StandardExchangeOutFacet();
        init.uniswapV2StandardExchangeQueryFacet = c.create3Factory.deployUniswapV2StandardExchangeQueryFacet();
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        init.uniswapV2Factory = factory;
        init.uniswapV2Router = router;
        // Package deployment goes through the manager registry as the registry operator.
        vm.startPrank(c.owner);
        pkg_ = UniswapV2_Component_FactoryService.deployUniswapV2StandardExchangeDFPkg(
            IVaultRegistryDeployment(address(c.indexedexManager)), init
        );
        vm.stopPrank();
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "UniswapV2StandardExchange";
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
    /// @dev False: a Uni V2 pair has no capacity gate, so `limitCapacity` cannot be honoured and the
    ///      row runs the rounding-to-zero control. D33 leftover handling is asserted by the AMM row.
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

    /// @dev Zap-in ends in `router.addLiquidity` -> `pair.mint(address)`; rejecting the pair's mint
    ///      makes the SE's operative investment revert after every precheck and the swap leg.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(pair), abi.encodeWithSelector(bytes4(keccak256("mint(address)"))), rejectBytes());
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
