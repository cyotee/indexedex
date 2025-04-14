// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ERC20} from "@crane/contracts/tokens/ERC20/ERC20.sol";

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ISeigniorageNFTVaultDFPkg,
    SeigniorageNFTVaultDFPkg
} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";
import {
    Seigniorage_Component_FactoryService
} from "contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol";

/* -------------------------------------------------------------------------- */
/*                                 Mock Tokens                                */
/* -------------------------------------------------------------------------- */

/**
 * @title MockERC20MintBurn
 * @notice Simple ERC20 with mint/burn capabilities for testing.
 */
contract MockERC20MintBurn is ERC20, IERC20MintBurn {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external override returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external override returns (bool) {
        _burn(account, amount);
        return true;
    }
}

/**
 * @title MockSeigniorageNFTVaultDFPkg
 * @notice Mock package that doesn't require vault registry caller check.
 */
contract MockSeigniorageNFTVaultDFPkg is SeigniorageNFTVaultDFPkg {
    constructor(PkgInit memory pkgInit) SeigniorageNFTVaultDFPkg(pkgInit) {}

    // Override to allow direct deployment for testing
    function processArgs(bytes memory pkgArgs) public pure override returns (bytes memory) {
        return pkgArgs;
    }
}

/**
 * @title MockSeigniorageDETF
 * @notice Minimal mock for ISeigniorageDETF for testing.
 * @dev Implements the ISeigniorageDETF interface for NFT vault testing.
 */
contract MockSeigniorageDETF is ISeigniorageDETF {
    IERC20 public override seigniorageToken;
    ISeigniorageNFTVault public override seigniorageNFTVault;
    IERC20 public override reserveVaultRateTarget;
    address public override reservePool;
    IERC20 public lpToken;

    /// @notice Tracks claimed amounts per recipient for test assertions
    mapping(address => uint256) public claimedAmounts;
    /// @notice Simulated LP token reserve
    uint256 public lpTokenReserve;

    constructor(IERC20 rateTarget_, IERC20 lpToken_) {
        reserveVaultRateTarget = rateTarget_;
        lpToken = lpToken_;
        lpTokenReserve = 0;
    }

    function setNFTVault(ISeigniorageNFTVault vault) external {
        seigniorageNFTVault = vault;
    }

    function setLpTokenReserve(uint256 reserve) external {
        lpTokenReserve = reserve;
    }

    function underwrite(IERC20, uint256, uint256, address, bool) external pure returns (uint256) {
        return 0; // Not needed for NFT vault tests
    }

    function previewClaimLiquidity(uint256 lpAmount) external pure returns (uint256 liquidityOut) {
        return lpAmount; // 1:1 for testing
    }

    /**
     * @notice Mock claimLiquidity - simulates DETF extracting value for NFT holder.
     * @dev In the real system, DETF uses `tokenId` to determine how much LP/liquidity
     *      to redeem; for testing we return the locked `sharesAwarded`.
     */
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity) {
        claimedAmounts[recipient] += lpAmount;
        extractedLiquidity = lpAmount;
    }

    function withdrawRewards(uint256, address) external pure returns (uint256 rewards) {
        return 0; // Not needed for NFT vault tests
    }

    /// @notice IBasicVault.reserveOfToken - returns LP token reserve for share calculations
    function reserveOfToken(address token_) external view returns (uint256 reserve) {
        if (token_ == address(lpToken)) {
            return lpTokenReserve;
        }
        return 0;
    }
}

    /* -------------------------------------------------------------------------- */
    /*                                  Test Base                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @title TestBase_SeigniorageNFTVault
     * @notice Base test contract for SeigniorageNFTVault tests.
     * @dev Provides infrastructure for testing NFT vault operations:
     *      - Lock/unlock positions
     *      - Bonus multiplier calculations
     *      - Reward distribution
     */
    contract TestBase_SeigniorageNFTVault is IndexedexTest {
        using Seigniorage_Component_FactoryService for *;

        /* ---------------------------------------------------------------------- */
        /*                              Test Constants                            */
        /* ---------------------------------------------------------------------- */

        uint256 internal constant INITIAL_MINT = 1_000_000e18;
        uint256 internal constant LOCK_AMOUNT = 1000e18;

        uint256 internal constant MIN_LOCK_DURATION = 1 days;
        uint256 internal constant MAX_LOCK_DURATION = 365 days;
        uint256 internal constant BASE_BONUS_MULTIPLIER = ONE_WAD; // 1x
        uint256 internal constant MAX_BONUS_MULTIPLIER = 4 * ONE_WAD; // 4x

        /* ---------------------------------------------------------------------- */
        /*                               Test Users                               */
        /* ---------------------------------------------------------------------- */

        address internal alice;
        address internal bob;
        address internal charlie;

        /* ---------------------------------------------------------------------- */
        /*                              Mock Tokens                               */
        /* ---------------------------------------------------------------------- */

        MockERC20MintBurn internal claimToken;
        MockERC20MintBurn internal rewardToken;
        MockERC20MintBurn internal lpToken;
        MockSeigniorageDETF internal mockSeigniorageDETF;

        /* ---------------------------------------------------------------------- */
        /*                           Vault Components                             */
        /* ---------------------------------------------------------------------- */

        IFacet internal erc721Facet;
        IFacet internal seigniorageNFTVaultFacet;
        IFacet internal erc4626BasicVaultFacet;
        IFacet internal erc4626StandardVaultFacet;
        ISeigniorageNFTVaultDFPkg internal nftVaultDFPkg;
        ISeigniorageNFTVault internal nftVault;

        /// @notice The owner of the NFT vault (simulates the DETF in production)
        address internal nftVaultOwner;

        /* ---------------------------------------------------------------------- */
        /*                                 Setup                                  */
        /* ---------------------------------------------------------------------- */

        function setUp() public virtual override {
            // Initialize Indexedex infrastructure (factories, fee collector, manager)
            IndexedexTest.setUp();

            // Create test users
            alice = makeAddr("alice");
            bob = makeAddr("bob");
            charlie = makeAddr("charlie");

            // Create NFT vault owner (simulates DETF in production)
            nftVaultOwner = makeAddr("nftVaultOwner");

            // Deploy mock tokens
            _deployMockTokens();

            // Deploy NFT vault components
            _deployNFTVaultFacets();
            _deployNFTVaultPackage();
            _deployNFTVault();

            // Distribute tokens to users
            _distributeTokens();
        }

        /* ---------------------------------------------------------------------- */
        /*                           Mock Token Setup                             */
        /* ---------------------------------------------------------------------- */

        function _deployMockTokens() internal virtual {
            claimToken = new MockERC20MintBurn("Claim Token", "CLAIM", 18);
            vm.label(address(claimToken), "claimToken");

            rewardToken = new MockERC20MintBurn("Reward Token", "sRBT", 18);
            vm.label(address(rewardToken), "rewardToken");

            lpToken = new MockERC20MintBurn("LP Token", "BPT", 18);
            vm.label(address(lpToken), "lpToken");

            mockSeigniorageDETF = new MockSeigniorageDETF(IERC20(address(claimToken)), IERC20(address(lpToken)));
            vm.label(address(mockSeigniorageDETF), "mockSeigniorageDETF");
        }

        function _distributeTokens() internal virtual {
            // Mint claim tokens to test users (for reference, not actually used in new flow)
            claimToken.mint(alice, INITIAL_MINT);
            claimToken.mint(bob, INITIAL_MINT);
            claimToken.mint(charlie, INITIAL_MINT);

            // In the new architecture:
            // - Users deposit to DETF (not directly to NFT vault)
            // - DETF handles pool deposits and calls nftVault.lockShares()
            // - NFT vault just tracks shares, doesn't hold actual tokens
            // - On unlock, NFT vault calls DETF.claimLiquidity() which sends tokens to user
        }

        /* ---------------------------------------------------------------------- */
        /*                         NFT Vault Deployment                           */
        /* ---------------------------------------------------------------------- */

        function _deployNFTVaultFacets() internal virtual {
            // Deploy ERC721 facet directly (not via factory service)
            erc721Facet = IFacet(address(new ERC721Facet()));
            vm.label(address(erc721Facet), "ERC721Facet");

            // Deploy vault view facets via CREATE3
            erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
            erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();

            // Deploy SeigniorageNFTVaultFacet via factory service
            seigniorageNFTVaultFacet = create3Factory.deploySeigniorageNFTVaultFacet();
        }

        function _deployNFTVaultPackage() internal virtual {
            // Deploy package directly (not through vault registry) since
            // tests may not have registry ownership configured.
            ISeigniorageNFTVaultDFPkg.PkgInit memory pkgInit = ISeigniorageNFTVaultDFPkg.PkgInit({
                erc721Facet: erc721Facet,
                erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                seigniorageNFTVaultFacet: seigniorageNFTVaultFacet,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager))
            });

            nftVaultDFPkg = ISeigniorageNFTVaultDFPkg(address(new MockSeigniorageNFTVaultDFPkg(pkgInit)));
            vm.label(address(nftVaultDFPkg), "SeigniorageNFTVaultDFPkg");
        }

        function _deployNFTVault() internal virtual {
            // Construct PkgArgs directly to avoid stack-depth issues
            ISeigniorageNFTVaultDFPkg.PkgArgs memory pkgArgs = ISeigniorageNFTVaultDFPkg.PkgArgs({
                name: "Seigniorage NFT Vault",
                symbol: "sNFT",
                detfToken: ISeigniorageDETF(address(mockSeigniorageDETF)),
                claimToken: IERC20(address(claimToken)),
                lpToken: IERC20(address(lpToken)),
                rewardToken: IERC20MintBurn(address(rewardToken)),
                decimalOffset: 0,
                owner: nftVaultOwner
            });

            // Deploy the NFT vault instance via diamond package factory
            address nftVaultAddr =
                diamondPackageFactory.deploy(IDiamondFactoryPackage(address(nftVaultDFPkg)), abi.encode(pkgArgs));

            nftVault = ISeigniorageNFTVault(nftVaultAddr);
            vm.label(nftVaultAddr, "SeigniorageNFTVault");

            // Set the NFT vault reference in mock DETF
            mockSeigniorageDETF.setNFTVault(nftVault);
        }

        /* ---------------------------------------------------------------------- */
        /*                            Helper Functions                            */
        /* ---------------------------------------------------------------------- */

        /**
         * @notice Lock shares for a user and return the token ID.
         * @dev In production, the DETF (owner) deposits to the Balancer pool and
         *      calls lockFromDetf with the resulting BPT amount and the BPT reserve before mint.
         *      Here we simulate the owner calling lockFromDetf and keep the mock DETF reserve in sync.
         *      The NFT vault tracks shares; the DETF holds actual BPT.
         */
        function _lockSharesForUser(address user, uint256 amount, uint256 lockDuration)
            internal
            returns (uint256 tokenId)
        {
            // Owner (DETF) calls lockFromDetf on behalf of user.
            // Capture the mock reserve before and then update it after, simulating the BPT mint.
            uint256 bptReserveBefore = mockSeigniorageDETF.lpTokenReserve();

            vm.prank(nftVaultOwner);
            tokenId = nftVault.lockFromDetf(amount, bptReserveBefore, lockDuration, user);

            mockSeigniorageDETF.setLpTokenReserve(bptReserveBefore + amount);
        }

        /**
         * @notice Distribute reward tokens to the NFT vault.
         */
        function _distributeRewards(uint256 amount) internal {
            rewardToken.mint(address(nftVault), amount);
        }

        /**
         * @notice Skip time by a given duration.
         */
        function _skipTime(uint256 duration) internal {
            skip(duration);
        }

        /**
         * @notice Warp to a position's unlock time.
         */
        function _warpToUnlock(uint256 tokenId) internal {
            ISeigniorageNFTVault.LockInfo memory info = nftVault.lockInfoOf(tokenId);
            vm.warp(info.unlockTime);
        }

        /**
         * @notice Calculate expected bonus multiplier for a lock duration.
         * @dev Uses quadratic scaling: base + (max - base) * (duration / maxDuration)^2
         */
        function _expectedBonusMultiplier(uint256 lockDuration) internal pure returns (uint256) {
            if (lockDuration >= MAX_LOCK_DURATION) {
                return MAX_BONUS_MULTIPLIER;
            }

            uint256 bonusRange = MAX_BONUS_MULTIPLIER - BASE_BONUS_MULTIPLIER;
            uint256 ratio = (lockDuration * ONE_WAD) / MAX_LOCK_DURATION;
            uint256 quadraticRatio = (ratio * ratio) / ONE_WAD;
            return BASE_BONUS_MULTIPLIER + (bonusRange * quadraticRatio) / ONE_WAD;
        }

        /**
         * @notice Calculate expected effective shares for given original shares and lock duration.
         */
        function _expectedEffectiveShares(uint256 originalShares, uint256 lockDuration)
            internal
            pure
            returns (uint256)
        {
            uint256 bonus = _expectedBonusMultiplier(lockDuration);
            return (originalShares * bonus) / ONE_WAD;
        }
    }
