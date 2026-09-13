import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';

const root = process.cwd();
const require = createRequire(path.join(root, 'frontend/apps/dtf/package.json'));
const { build } = require('esbuild');
const built = await build({
  stdin: { contents: `
    export * as deployment from './frontend/apps/dtf/app/create/lib/detfAbi.ts';
    export * as insights from './frontend/apps/dtf/app/insights/lib/insightsAbi.ts';
    export * as purchase from './frontend/apps/dtf/app/lib/detf/bondRoute.ts';
    export * as bonds from './frontend/apps/dtf/app/lib/detf/bondNftVault.ts';
  `, resolveDir: root, loader: 'ts' },
  bundle: true, write: false, format: 'esm', platform: 'node', metafile: true,
});
const frontend = await import('data:text/javascript;base64,' + Buffer.from(built.outputFiles[0].text).toString('base64'));
const sha = data => createHash('sha256').update(data).digest('hex');
const canonical = item => item.type.startsWith('tuple')
  ? '(' + item.components.map(canonical).join(',') + ')' + item.type.slice(5) : item.type;
const signature = entry => entry.name + '(' + entry.inputs.map(canonical).join(',') + ')';
const artifact = name => {
  const file = `out/${name}.sol/${name}.json`;
  const raw = fs.readFileSync(file);
  return { file, sha256: sha(raw), ...JSON.parse(raw) };
};
const declarations = [];
function compare(label, entries, names) {
  const compiled = names.map(artifact);
  for (const entry of entries.filter(e => e.type === 'function')) {
    const sig = signature(entry);
    const matches = compiled.flatMap(a => a.abi.filter(e => e.type === 'function' && signature(e) === sig)
      .map(e => ({ artifact: a.file, artifact_sha256: a.sha256, declaration: e })));
    const compatible = matches.some(m => JSON.stringify(m.declaration.outputs.map(canonical)) === JSON.stringify(entry.outputs.map(canonical))
      && m.declaration.stateMutability === entry.stateMutability);
    declarations.push({ label, signature: sig, frontend_outputs: entry.outputs.map(canonical), compatible,
      matches: matches.map(({ declaration, ...rest }) => ({ ...rest, outputs: declaration.outputs.map(canonical) })) });
  }
}
compare('DETF deployment', frontend.deployment.UNI_V4_DETF_PKG_ABI, ['UniswapV4DetfDFPkg']);
compare('Weighted hook deployment', frontend.deployment.WEIGHTED_HOOK_DEPLOY_ABI, ['UniswapV4StandardExchangeWeightedBufferHookDFPkg']);
compare('CP hook deployment', frontend.deployment.CP_HOOK_DEPLOY_ABI, ['UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg']);
compare('Curve Quad hook deployment', frontend.deployment.QUAD_HOOK_DEPLOY_ABI, ['UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg']);
compare('Current DETF exchange and discovery', frontend.insights.insightsViewAbi.filter(e => [
  'mintThreshold', 'burnThreshold', 'isReserveLive', 'rebasingClaimToken', 'reservePool',
  'acceptedBondTokens', 'isMintingAllowed', 'isBurningAllowed', 'bondNftVault', 'previewExchangeIn', 'exchangeIn',
].includes(e.name)), ['UniswapV4DetfExchangeFacet', 'UniswapV4DetfQueryFacet', 'UniswapV4DetfMaintenanceFacet']);
compare('Funded V4 bond purchase', frontend.purchase.FUNDED_BOND_ABI.filter(e => e.inputs.length === 6), ['UniswapV4DetfBondFacet']);
compare('Funded V4 bond quote', frontend.purchase.V4_BOND_PREVIEW_ABI, ['UniswapV4DetfQueryFacet']);
compare('Funded bond ownership and payouts', frontend.bonds.BOND_NFT_POSITION_ABI,
  ['DETFNFTVaultFacet', 'ERC721Facet', 'DETFFundedBondMetadataFacet']);
compare('Direct/composed staking exchange', frontend.insights.insightsViewAbi.filter(e => ['previewExchangeIn', 'exchangeIn'].includes(e.name)), ['RebasingClaimTokenFacet']);
const sources = Object.keys(built.metafile.inputs).filter(file => file.startsWith('frontend/apps/dtf/'))
  .sort().map(file => ({ path: file, sha256: sha(fs.readFileSync(file)) }));
const report = {
  checked_at_utc: new Date().toISOString(),
  method: 'Bundle the actual exported TypeScript ABI constants and compare canonical input/output tuple shapes and mutability with compiled production interfaces/facets/packages. Live proxy installation is independently covered by Solidity surface tests and the release rehearsal.',
  frontend_sources: sources, declarations,
  all_compatible: declarations.every(row => row.compatible),
  optional_historical_getters: [
    { signature: 'reserveHook()', disposition: 'InsightsPageClient uses reserveHookFromDetf ?? reservePool; reservePool() is the required current V4 getter checked above.' },
    { signature: 'pairTokens()', disposition: 'Historical weighted-family discovery with retry: 0. Current action routes use supported tokensIn()/tokensOut() and acceptedBondTokens(); pairTokens is only an optional display label source.' },
  ],
  existing_multi_family_views: 'Insights intentionally uses allowFailure for historical-family discovery getters. Only supported current V4 write and required view routes are asserted here; their selectors are not replaced with historical alternatives.',
  limitations: 'No deployment address bindings changed. Full app lint/typecheck/410 tests are recorded separately; this is ABI reconciliation, not a new browser transaction run.',
};
fs.writeFileSync('implementation-artifacts/detf-funded-staking/production-readiness/frontend-abi-reconciliation.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ compared: declarations.length, incompatible: declarations.filter(row => !row.compatible) }));
if (!report.all_compatible) process.exitCode = 1;
