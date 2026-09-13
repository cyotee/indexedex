"""Prepare receipt-denominated ERC4626 projections without changing build inputs."""
from pathlib import Path
import difflib
import hashlib
import json

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
path = 'contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol'
before = (root / path).read_text()
text = before

def replace(old, new):
    global text
    assert text.count(old) == 1, old[:100]
    text = text.replace(old, new)

replace('        address vault;\n', '        address vault;\n        address asset;\n')
replace('        bool nativeQuote;\n', '''        bool nativeQuote;
        // Native nested snapshots track all issued shares. This separate gap
        // preserves actual wrapper custody through receipt transfers without
        // pretending those transfers mint or redeem underlying vault shares.
        uint256 nativeExcludedShares;
''')
replace('        if (asset_ != _underlying()) revert UnsupportedQuoteAsset(asset_);', '''        if (asset_ != _underlying() && asset_ != address(protocolVault())) revert UnsupportedQuoteAsset(asset_);''')
replace('        q.vault = address(protocolVault());', '        q.vault = address(protocolVault());\n        q.asset = asset_;')
replace('IStandardExchangeTransitionQuote(q.vault).quoteState(asset_, address(this))', 'IStandardExchangeTransitionQuote(q.vault).quoteState(_underlying(), address(this))')
replace('''            q.nativeQuote = true;
''', '''            q.nativeQuote = true;
            _normalizeNativeSnapshot(q);
''')
replace('''        try IStandardExchangeTransitionQuote(q.vault).quoteState(_underlying(), address(this))
            returns (bytes memory nested, uint256) {
            q.vaultState = nested;
            q.nativeQuote = true;
            _normalizeNativeSnapshot(q);
        } catch {
            q.vaultState = abi.encode(_virtualSnapshot(IERC4626(q.vault)));
        }''', '''        // IERC4626 execution is authoritative here. A nested SE can expose
        // separate deposit routes with different fees from IERC4626.deposit.
        (VirtualVault memory virtualState, bool canonical) = _virtualSnapshot(IERC4626(q.vault));
        if (!canonical) (virtualState, canonical) = _ratioSnapshot(IERC4626(q.vault));
        if (canonical) q.vaultState = abi.encode(virtualState);
        else {
            try IStandardExchangeTransitionQuote(q.vault).quoteState(_underlying(), address(this))
                returns (bytes memory nested, uint256) {
                q.vaultState = nested;
                q.nativeQuote = true;
                _normalizeNativeSnapshot(q);
            } catch { revert InvalidQuoteState(); }
        }''')
replace('''            (, vaultAdded_) = _vaultTransition(q, Operation.DepositExactIn, amount_);''', '''            (, vaultAdded_) = _vaultTransition(
                q, q.asset == q.vault ? Operation.ReceiveShares : Operation.DepositExactIn, amount_
            );''')
replace('''                QuoteState memory copy = abi.decode(abi.encode(q), (QuoteState));
                (uint256 needed_,) = _vaultTransition(copy, Operation.WithdrawExactOut, amount_);''', '''                uint256 needed_ = amount_;
                if (q.asset != q.vault) {
                    QuoteState memory copy = abi.decode(abi.encode(q), (QuoteState));
                    (needed_,) = _vaultTransition(copy, Operation.WithdrawExactOut, amount_);
                }''')
replace('''            (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, vaultOut_);''', '''            if (q.asset == q.vault) {
                _sendVaultShares(q, vaultOut_);
                amountOut_ = vaultOut_;
            } else (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, vaultOut_);''')
replace('''            uint256 vaultOut_ = q.supply == 0 ? 0 : Math.mulDiv(amountIn_, q.vaultShares, q.supply);''', '''            uint256 vaultOut_ = q.asset == q.vault && operation_ == Operation.WithdrawExactOut
                ? amount_ : (q.supply == 0 ? 0 : Math.mulDiv(amountIn_, q.vaultShares, q.supply));''')
replace('''        return _vaultAssets(q, vaultClaim_);''', '''        return q.asset == q.vault ? vaultClaim_ : _vaultAssets(q, vaultClaim_);''')
replace('''        if (tokenIn_ != q.vault) revert UnsupportedQuoteAsset(tokenIn_);
        // The external payment is already-issued protocol-vault shares. Receive
        // and redeem just those shares; the buffered holder retains its SE stake.
        _vaultTransition(q, Operation.ReceiveShares, amountIn_);
        (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, amountIn_);''', '''        if (q.asset == q.vault && tokenIn_ == _underlying()) {
            // The underlying deposit pays protocol receipts to the external
            // recipient, leaving the wrapper's existing receipt reserve intact.
            (, amountOut_) = _vaultTransition(q, Operation.DepositExactIn, amountIn_);
            _sendVaultShares(q, amountOut_);
        } else if (q.asset == _underlying() && tokenIn_ == q.vault) {
            // Redeem only the external payment, preserving buffered SE custody.
            _vaultTransition(q, Operation.ReceiveShares, amountIn_);
            (, amountOut_) = _vaultTransition(q, Operation.RedeemExactIn, amountIn_);
        } else revert UnsupportedQuoteAsset(tokenIn_);''')
replace('''        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteShareBalance(q.vaultState);''', '''        if (q.nativeQuote) return IStandardExchangeTransitionQuote(q.vault).quoteTotalSupply(q.vaultState)
            - q.nativeExcludedShares;''')
replace('''    function _virtualSnapshot(IERC4626 vault) private view returns (VirtualVault memory v) {''', '''    function _virtualSnapshot(IERC4626 vault) private view returns (VirtualVault memory v, bool canonical) {''')
replace('''        uint256 virtualShares;
''', '''        uint256 virtualShares;
        uint256 virtualAssets;
''')
replace('''        v.assets = vault.totalAssets();''', '''        v.assets = vault.totalAssets();
        v.virtualAssets = 1;''')
replace('''        if (shareDecimals < assetDecimals || shareDecimals - assetDecimals > 77) revert InvalidQuoteState();''', '''        if (shareDecimals < assetDecimals || shareDecimals - assetDecimals > 77) return (v, false);''')
replace('''        if (scaledSupply < issued + v.virtualShares) revert InvalidQuoteState();''', '''        if (scaledSupply < issued + v.virtualShares) {
            // Existing Crane packages can retain 18 metadata decimals while
            // configuring a zero arithmetic offset for a 6/9-decimal receipt.
            // Recognize the exact issued+1 denominator, not a guessed fee pot.
            if (scaledSupply != issued + 1) return (v, false);
            v.virtualShares = 1;
        }''')
replace('''        if (vault.convertToAssets(scaledSupply) != v.assets + 1) revert InvalidQuoteState();''', '''        if (vault.convertToAssets(scaledSupply) != v.assets + 1) return (v, false);''')
replace('''            || vault.previewRedeem(v.heldShares) != _virtualAssets(v, v.heldShares)) revert InvalidQuoteState();''', '''            || vault.previewRedeem(v.heldShares) != _virtualAssets(v, v.heldShares)) return (v, false);''')
replace('''                v.pendingHeldFee = v.supply - issued;
            }
        }
    }''', '''                v.pendingHeldFee = v.supply - issued;
            }
        }
        canonical = true;
    }''')
replace('''    function _virtualAssets(VirtualVault memory v, uint256 shares) private pure returns (uint256) {''', '''    /// @dev Solmate-style proportional vaults, including the retained sfrxETH
    /// integration, have no virtual offsets. Check their actual conversion and
    /// directional previews before using that distinct balance model.
    function _ratioSnapshot(IERC4626 vault) private view returns (VirtualVault memory v, bool canonical) {
        v.assets = vault.totalAssets();
        v.supply = vault.totalSupply();
        v.heldShares = vault.balanceOf(address(this));
        if (v.assets == 0 || v.supply == 0) return (v, false);
        if (vault.convertToShares(v.assets) != v.supply || vault.convertToAssets(v.supply) != v.assets) return (v, false);
        uint256 probe = 10 ** IERC20Metadata(vault.asset()).decimals();
        canonical = vault.previewDeposit(probe) == Math.mulDiv(probe, v.supply, v.assets)
            && vault.previewWithdraw(probe) == Math.mulDiv(probe, v.supply, v.assets, Math.Rounding.Ceil)
            && vault.previewRedeem(v.heldShares) == _virtualAssets(v, v.heldShares);
    }

    function _virtualAssets(VirtualVault memory v, uint256 shares) private pure returns (uint256) {''')
# Snapshot recognition retains its explicit +1 probe; only transition arithmetic
# and proportional claims use the selected model's virtual asset offset.
text = text.replace('Math.mulDiv(shares, v.assets + 1, v.supply + v.virtualShares)',
                    'Math.mulDiv(shares, v.assets + v.virtualAssets, v.supply + v.virtualShares)')
text = text.replace('Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + 1)',
                    'Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + v.virtualAssets)')
text = text.replace('Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + 1, Math.Rounding.Ceil)',
                    'Math.mulDiv(amount, v.supply + v.virtualShares, v.assets + v.virtualAssets, Math.Rounding.Ceil)')
replace('''        if (q.nativeQuote) {
            (q.vaultState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, operation, amount);
            return (amountIn, amountOut);
        }''', '''        if (q.nativeQuote) {
            if (operation == Operation.ReceiveShares) {
                if (amount > q.nativeExcludedShares) revert InvalidQuoteState();
                q.nativeExcludedShares -= amount;
                return (amount, amount);
            }
            (q.vaultState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(q.vault)
                .quoteTransition(q.vaultState, operation, amount);
            _normalizeNativeSnapshot(q);
            return (amountIn, amountOut);
        }''')
replace('''    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {''', '''    function _normalizeNativeSnapshot(QuoteState memory q) private view {
        IStandardExchangeTransitionQuote nested = IStandardExchangeTransitionQuote(q.vault);
        uint256 missing = nested.quoteTotalSupply(q.vaultState) - nested.quoteShareBalance(q.vaultState);
        if (missing == 0) return;
        q.nativeExcludedShares += missing;
        (q.vaultState,,,) = nested.quoteTransition(q.vaultState, Operation.ReceiveShares, missing);
    }

    function _sendVaultShares(QuoteState memory q, uint256 amount) private view {
        uint256 held = _vaultShareBalance(q);
        if (amount > held) revert InsufficientQuoteShares(amount, held);
        if (q.nativeQuote) q.nativeExcludedShares += amount;
        else {
            VirtualVault memory v = abi.decode(q.vaultState, (VirtualVault));
            v.heldShares -= amount;
            q.vaultState = abi.encode(v);
        }
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {''')
changes[path] = (before, text)

path = 'test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol'
before = (root / path).read_text()
text = before + '\n' + (art / 'pending-sfrxeth-projection-tests.sol.txt').read_text()
changes[path] = (before, text)

path = 'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol'
before = (root / path).read_text()
before_import = 'import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";'
assert before.count(before_import) == 1
with_import = before.replace(before_import, before_import + '\nimport {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";')
addition = '''
    function test_receiptAccounting_nestedErc4626DepositDoesNotChargeNestedSeUsageFee() public {
        _nestedErc4626FeeSemantics(6);
        _nestedErc4626FeeSemantics(9);
        _nestedErc4626FeeSemantics(18);
    }

    function _nestedErc4626FeeSemantics(uint8 decimals) private {
        uint256 unit = 10 ** decimals;
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", decimals);
        ERC4626TargetStub receipt = new ERC4626TargetStub(IERC20Metadata(address(asset)), 0, permit2);
        address inner = _deployERC4626SE(address(receipt));
        address outer = _deployERC4626SE(inner);
        asset.mint(address(this), 10_000 * unit);
        asset.approve(address(receipt), type(uint256).max);
        receipt.deposit(9_000 * unit, address(this));
        IERC20(address(receipt)).approve(inner, type(uint256).max);
        IERC4626(inner).deposit(1_000 * unit, address(this));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(inner, 7e16);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(outer, 11e16);
        vm.stopPrank();
        IERC20(address(receipt)).approve(outer, type(uint256).max);
        IStandardExchangeIn(outer).exchangeIn(IERC20(address(receipt)), 1_000 * unit, IERC20(outer), 1, address(this), false, block.timestamp);
        address fee = address(indexedexManager.feeTo());
        uint256 beforeFee = IERC20(inner).balanceOf(fee);
        _assertQuoteSequence(outer, IERC20(address(receipt)), address(this), unit);
        assertEq(IERC20(inner).balanceOf(fee), beforeFee, "nested IERC4626 deposit has no SE usage fee");
    }

    function test_receiptAccounting_canonicalVirtualVaultSequence() public {
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", 18);
        ERC4626TargetStub vault = new ERC4626TargetStub(IERC20Metadata(address(asset)), 0, permit2);
        address se = _deployERC4626SE(address(vault));
        asset.mint(address(this), 3_000 ether);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(2_000 ether, address(this));
        IERC20(address(vault)).approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(vault)), 1_000 ether, IERC20(se), 1, address(this), false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        _assertQuoteSequence(se, IERC20(address(vault)), address(this), 1 ether);
        _assertExternalExchangeQuote(se, IERC20(address(asset)), IERC20(address(vault)), 20 ether);
    }

    function test_receiptAccounting_sequentialDepositWithdrawalAndRedemption() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        _assertQuoteSequence(se, IERC20(address(vault)), address(this), 1 ether);
    }

    function test_receiptAccounting_exactOutputRetainsRoundingSurplus() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        vault.transfer(se, 90 ether);
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(se);
        (bytes memory state,) = quote.quoteState(address(vault), address(this));
        Step memory step;
        (step.state, step.input, step.output, step.claim) = quote.quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, 2
        );
        assertEq(step.output, 2, "receipt exact-output pays only the requested amount");
        uint256 before = vault.balanceOf(address(this));
        assertEq(IStandardExchangeOut(se).exchangeOut(
            IERC20(se), step.input, IERC20(address(vault)), 2, address(this), false, block.timestamp
        ), step.input);
        assertEq(vault.balanceOf(address(this)) - before, 2);
        (bytes memory actual, uint256 claim) = quote.quoteState(address(vault), address(this));
        _assertProjectedState(actual, step.state);
        assertEq(claim, step.claim, "unpaid conversion surplus remains backing");
    }

    function test_receiptAccounting_externalUnderlyingAndReceiptDeposits() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        address holder = address(indexedexManager.feeTo());
        IERC20(se).transfer(holder, IERC20(se).balanceOf(address(this)) / 2);
        _assertExternalDepositQuote(se, IERC20(address(vault)), IERC20(address(vault)), 10 ether, holder);
        _assertExternalDepositQuote(se, asset, IERC20(address(vault)), 20 ether, holder);
    }

    function test_receiptAccounting_externalUnderlyingConversionPreservesReserve() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        uint256 reserve = vault.balanceOf(se);
        uint256 issued = IERC20(se).totalSupply();
        _assertExternalExchangeQuote(se, asset, IERC20(address(vault)), 20 ether);
        assertEq(vault.balanceOf(se), reserve, "passthrough receipt belongs to paying user");
        assertEq(IERC20(se).totalSupply(), issued, "passthrough does not issue wrapper shares");
    }

    function testFuzz_receiptAccounting_sequenceWithYieldAndFeeRecipient(
        uint8 decimals_, uint64 yield_, bool feeHolder_
    ) public {
        uint256 unit = 10 ** bound(decimals_, 6, 18);
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", uint8(bound(decimals_, 6, 18)));
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(asset);
        address se = _deployERC4626SE(address(vault));
        address holder = feeHolder_ ? address(indexedexManager.feeTo()) : makeAddr("receipt quote holder");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        asset.mint(holder, 10_000 * unit);
        vm.startPrank(holder);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(9_000 * unit, holder);
        vault.approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(vault)), 1_000 * unit + 13, IERC20(se), 1, holder, false, block.timestamp);
        vm.stopPrank();
        uint256 accrued = bound(yield_, 1, 100 * unit);
        asset.mint(address(this), accrued);
        asset.approve(address(vault), accrued);
        vault.simulateYield(accrued);
        _assertQuoteSequence(se, IERC20(address(vault)), holder, unit);
    }
'''
assert before.rstrip().endswith('}')
text = with_import.rstrip()[:-1] + addition + '}\n'
changes[path] = (before, text)

patch = ''.join(''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (a, b) in changes.items())
(art / 'erc4626-receipt-projection.patch').write_text(patch)
record = {
    'status': 'PREPARED_NOT_APPLIED',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(a.encode()).hexdigest(),
        'after_sha256': hashlib.sha256(b.encode()).hexdigest()} for path, (a, b) in changes.items()],
    'scope': 'Retained protocol-receipt accounting route and actual transfer custody; no new storage, selectors, deployment arguments or execution economics.',
    'tests': 'Seven additions to the existing actual-proxy transition suite, covering virtual/no-offset snapshots, exact-output receipt surplus, nested IERC4626-vs-SE fees, and decimal/yield/fee-recipient fuzzing; four actual sfrxETH fork cases at block 24000000.',
    'limitations': 'Native nested IERC4626-vs-StandardExchange semantics and noncanonical opaque vault projection remain separate review items. This patch does not establish arbitrary ERC4626 projection support.',
    'validation': 'Pending production compilation, code-size check and actual proxy execution after session 52340 exits.',
}
record['diagnostics'] = {}
for kind, stem, suffix in [('production', 'erc4626-receipt-draft', 'compile'),
                           ('typecheck', 'erc4626-receipt-draft-test', 'typecheck')]:
    result_path = art / (stem + '-' + suffix + '.json')
    input_path = art / (stem + '-compiler-input.json')
    if not result_path.exists() or not input_path.exists():
        continue
    result = json.loads(result_path.read_text())
    compiler_input = json.loads(input_path.read_text())
    relevant = {path: after for path, (_, after) in changes.items()
                if kind == 'typecheck' or path.startswith('contracts/')}
    matches = all(compiler_input['sources'].get(path, {}).get('content') == after
                  for path, after in relevant.items())
    matches = matches and hashlib.sha256(input_path.read_bytes()).hexdigest() == result['compiler_input_sha256']
    record['diagnostics'][kind] = {
        'record': result_path.name, 'source_matches_prepared_patch': matches,
        'compiler_input_sha256': result['compiler_input_sha256'], 'errors': result['errors'],
        'runtime_bytes': result.get('runtime_bytes'), 'method_count': len(result.get('proposed_cases', [])),
    }
record['public_protocol_input_preflight'] = 'sfrxeth-projection-input-preflight.json'
(art / 'erc4626-receipt-projection-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
print('Prepared', len(changes), 'sources; no Solidity changed.')
