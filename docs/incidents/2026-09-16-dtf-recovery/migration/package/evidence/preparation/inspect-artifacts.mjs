// Run from the phase-03 worktree with Bun. Reads artifacts; never compiles or writes them.
const parent = "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/";
const bond = "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
const staking = "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
const initialization = parent + "UniswapV4DetfInitializationLib.sol";
const packageSource = parent + "UniswapV4DetfDFPkg.sol";
const sources = [
  initialization, packageSource, bond, staking,
  "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol",
];
const sourceHashes = new Map();
for (const path of sources) {
  const bytes = await Bun.file(path).bytes();
  const hash = await Bun.$`/Users/cyotee/.foundry/bin/cast keccak ${"0x" + Buffer.from(bytes).toString("hex")}`.quiet().text();
  const hashes = {
    path,
    sha256: new Bun.CryptoHasher("sha256").update(bytes).digest("hex"),
    keccak256: hash.trim(),
  };
  sourceHashes.set(path, hashes);
  console.log(JSON.stringify({ source: hashes }));
}
const bindings = [
  ["UniswapV4DetfDFPkg", [initialization, packageSource]],
  ["UniswapV4DetfBondNFTVaultFacet", [bond]],
  ["RebasingClaimTokenFacet", [staking]],
  ["DETFNFTVaultFacet", [bond]],
  ["UniswapV4DetfExchangeFacet", []],
  ["UniswapV4DetfBondFacet", []],
  ["UniswapV4DetfMaintenanceFacet", []],
  ["UniswapV4DetfClaimFacet", []],
  ["UniswapV4DetfQueryFacet", []],
];
for (const [name, dependencies] of bindings) {
  const path = `out/${name}.sol/${name}.json`;
  const file = Bun.file(path);
  const bytes = await file.bytes();
  const artifact = JSON.parse(Buffer.from(bytes).toString("utf8"));
  const metadata = artifact.metadata;
  const matches = dependencies.map(source => ({
    source,
    expected: sourceHashes.get(source).keccak256,
    actual: metadata.sources[source]?.keccak256,
    matches: metadata.sources[source]?.keccak256 === sourceHashes.get(source).keccak256,
  }));
  const creationBytes = (artifact.bytecode.object.length - 2) / 2;
  const runtimeBytes = (artifact.deployedBytecode.object.length - 2) / 2;
  if (creationBytes <= 0 || runtimeBytes <= 0 || matches.some(match => !match.matches)) {
    console.error(JSON.stringify({ invalidArtifact: path, matches, creationBytes, runtimeBytes }));
    process.exit(1);
  }
  console.log(JSON.stringify({
    artifact: path,
    sha256: new Bun.CryptoHasher("sha256").update(bytes).digest("hex"),
    compiler: metadata.compiler,
    target: metadata.settings.compilationTarget,
    optimizer: metadata.settings.optimizer,
    evmVersion: metadata.settings.evmVersion,
    creationBytes, runtimeBytes,
    linkReferences: artifact.bytecode.linkReferences,
    matches,
  }));
}
console.log("ARTIFACT_SOURCE_BINDINGS=PASS");
