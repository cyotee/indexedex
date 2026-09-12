"""Prepare current-source EtherFi projections; never apply while Forge runs."""
from pathlib import Path
from datetime import datetime, timezone
import difflib
import hashlib
import json
import re

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
base = 'contracts/protocols/staking/etherfi/'
quote_import = 'import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\n'


def imports(source, text):
    end = re.search(r'pragma solidity [^;]+;', source).end()
    return source[:end] + '\n' + text + source[end:]


def stage(path, transform):
    before = (root / path).read_text()
    after = transform(before)
    assert before != after, path
    changes[path] = (before, after)


def target(source):
    source = imports(source, quote_import + '''import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {EtherFiWeETHStandardExchangeRepo} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeRepo.sol";
''')
    source = source.replace('    IStandardExchangeIn\n{', '    IStandardExchangeIn,\n    IStandardExchangeTransitionQuote,\n    IStandardExchangeExternalQuote\n{')
    end = source.rfind('}')
    return source[:end] + (art / 'pending-etherfi-projection-body.txt').read_text() + '\n' + source[end:]


stage(base + 'EtherFiWeETHStandardExchangeInTarget.sol', target)


def facet(source):
    source = imports(source, quote_import)
    source = source.replace('@dev facetFuncs: previewExchangeIn + exchangeIn ONLY (no exchangeInEth).', '@dev Exact-input routes and optional sequential provider quotes; no native ETH entry.')
    source = source.replace('new bytes4[](1)', 'new bytes4[](3)')
    anchor = '        interfaces[0] = type(IStandardExchangeIn).interfaceId;'
    source = source.replace(anchor, anchor + '\n        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;')
    source = source.replace('new bytes4[](2)', 'new bytes4[](9)')
    anchor = '        funcs[1] = IStandardExchangeIn.exchangeIn.selector;'
    methods = [('IStandardExchangeTransitionQuote', name) for name in ('quoteState', 'quoteAssets', 'quoteShareBalance', 'quoteTotalSupply', 'quoteTransition')]
    methods += [('IStandardExchangeExternalQuote', name) for name in ('quoteExternalDeposit', 'quoteExternalExchange')]
    return source.replace(anchor, anchor + ''.join('\n        funcs[%d] = %s.%s.selector;' % (i, interface, method) for i, (interface, method) in enumerate(methods, 2)))


stage(base + 'EtherFiWeETHStandardExchangeInFacet.sol', facet)


def package(source):
    source = imports(source, quote_import).replace('new bytes4[](11)', 'new bytes4[](13)')
    anchor = '        interfaces[10] = type(IStandardizedYield).interfaceId;'
    return source.replace(anchor, anchor + '\n        interfaces[11] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[12] = type(IStandardExchangeExternalQuote).interfaceId;')


stage(base + 'EtherFiWeETHStandardExchangeDFPkg.sol', package)


def factory(source):
    pattern = r'instance = create3Factory\.deployFacet\(\s*ArtifactCreationCode.creationCode\("([^\"]+)"\),\s*(abi.encode\("([^\"]+)"\)\._hash\(\))\s*\);'
    def replacement(match):
        return 'bytes memory code = ArtifactCreationCode.creationCode("' + match[1] + '");\n        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(' + match[2] + ', code, ""));'
    source, count = re.subn(pattern, replacement, source)
    assert count == 4, count
    start = source.index('        instance = IEtherFiWeETHStandardExchangeDFPkg(')
    end = source.index('        vm.label(address(instance), "EtherFiWeETHStandardExchangeDFPkg");', start)
    return source[:start] + '''        bytes memory code = ArtifactCreationCode.creationCode("EtherFiWeETHStandardExchangeDFPkg.sol:EtherFiWeETHStandardExchangeDFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = IEtherFiWeETHStandardExchangeDFPkg(IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("EtherFiWeETHStandardExchangeDFPkg")._hash(), code, args)
        ));
''' + source[end:]


stage(base + 'EtherFiWeETH_Component_FactoryService.sol', factory)


def fork_tests(source):
    source = imports(source, quote_import + '''import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
''')
    return source + '''
/// @notice Whole projected provider states compared with live EtherFi execution.
/// An unavailable archive endpoint fails setup; these cases cannot silently pass.
contract EtherFiStandardExchangeProjectionFork is EtherFiWeETHStandardExchange_Fork_Test, TransitionQuoteAssertions {
    function setUp() public override {
        vm.createSelectFork("ethereum_mainnet_alchemy", 24_000_000);
        super.setUp();
        assertGt(seVault.code.length, 0, "actual registry SE");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.07e18);
        vm.deal(address(this), 1_000 ether);
        IWETH(payable(WETH)).deposit{value: 600 ether}();
        IEtherFiLiquidityPool(LIQUIDITY_POOL).deposit{value: 400 ether}();
        uint256 received = IERC20(EETH).balanceOf(address(this));
        IERC20(EETH).approve(WEETH, received);
        IWeETH(WEETH).wrap(received);
        IERC20(WETH).approve(seVault, 200 ether);
        seIn.exchangeIn(IERC20(WETH), 200 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        IERC20(WEETH).approve(seVault, 100 ether);
        seIn.exchangeIn(IERC20(WEETH), 100 ether, IERC20(seVault), 1, address(this), false, block.timestamp);
        assertGt(IWeETH(WEETH).getEETHByWeETH(1e18), 1e18, "actual fractional rate");
    }

    function test_etherFiLiveSequentialLiquidAndWrappedBooks() public {
        _assertQuoteSequence(seVault, IERC20(WETH), address(this), 1 ether);
        _assertQuoteSequence(seVault, IERC20(WEETH), address(this), 1 ether);
    }

    function test_etherFiLiveExternalDepositAndStandingFeeRecipient() public {
        _assertExternalDepositQuote(seVault, IERC20(WETH), IERC20(WEETH), 7 ether + 19, address(this));
        address beneficiary = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _assertExternalDepositQuote(seVault, IERC20(WEETH), IERC20(WETH), 3 ether + 11, beneficiary);
    }

    function test_etherFiLiveExternalStakingAndLiquidConversion() public {
        _assertExternalExchangeQuote(seVault, IERC20(WEETH), IERC20(WETH), 3 ether + 17);
        _assertExternalExchangeQuote(seVault, IERC20(WETH), IERC20(WEETH), 7 ether + 29);
    }

    function test_etherFiLiveRebasingReceiptRounding() public {
        vm.deal(address(this), 5 ether);
        IEtherFiLiquidityPool(LIQUIDITY_POOL).deposit{value: 5 ether}();
        _assertExternalDepositQuote(seVault, IERC20(EETH), IERC20(WETH), IERC20(EETH).balanceOf(address(this)) / 2, address(this));
        _assertExternalExchangeQuote(seVault, IERC20(EETH), IERC20(WEETH), IERC20(EETH).balanceOf(address(this)) / 2);
    }

    function test_etherFiLiveInstantRedemptionProjectsFeesAndGlobalShares() public {
        // This consumes the whole sleeve and exercises the actual redemption
        // manager's fee/share burn before comparing the complete next state.
        uint256 amount = etherFiSe.liquidReserveEth() + 2 ether;
        IStandardExchangeTransitionQuote quotes = IStandardExchangeTransitionQuote(seVault);
        (bytes memory beforeState,) = quotes.quoteState(WETH, address(this));
        (bytes memory nextState, uint256 required,,) = quotes.quoteTransition(
            beforeState, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, amount
        );
        uint256 beforeBalance = IERC20(WETH).balanceOf(address(this));
        uint256 spent = seOut.exchangeOut(IERC20(seVault), required, IERC20(WETH), amount, address(this), false, block.timestamp);
        assertEq(spent, required, "exact output required shares");
        assertEq(IERC20(WETH).balanceOf(address(this)) - beforeBalance, amount, "actual payout");
        (bytes memory actual,) = quotes.quoteState(WETH, address(this));
        assertEq(nextState, actual, "whole live state including instant redemption fees");
    }
}
'''


stage('test/foundry/fork/eth_main/vaults/staking/etherfi/EtherFiWeETHStandardExchange_Fork.t.sol', fork_tests)
patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=path, tofile=path)) for path, (before, after) in changes.items())
(art / 'etherfi-composed-quotes.patch').write_text(patch)
(art / 'etherfi-composed-quotes-prepared.json').write_text(json.dumps({
    'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
    'status': 'PREPARED_NOT_APPLIED_NOT_COMPILED_NOT_VALIDATED',
    'scope': 'Existing EtherFi input target/facet/package/factory and existing actual-protocol fork suite; no new deployment argument or route allowlist.',
    'files': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'prepared_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'remaining': ['Review exact live protocol/version and instant redemption snapshot', 'Wait for active full build before applying', 'Compile under unchanged settings and check EIP-170', 'Run actual fork and existing hermetic SY tests; do not claim projected parity from source inspection'],
}, indent=2) + '\n')
print('Prepared %d current-source files; Solidity unchanged.' % len(changes))
