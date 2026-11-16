import { mkdir } from "node:fs/promises";
import { join, resolve } from "node:path";
import { child, FORGE } from "../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { save } from "../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const kind = process.argv[2];
const destination = process.argv[3];
if (!destination || !["hermetic", "fork", "operator"].includes(kind ?? "")) {
  throw new Error("expected hermetic|fork|operator and a new evidence directory");
}
const evidence = resolve(destination);
await mkdir(evidence, { recursive: false });
const profile = kind === "fork" ? "fork" : "default";
const environment = { ...process.env, FOUNDRY_PROFILE: profile };
const commands: readonly (readonly string[])[] = [
  [FORGE, "--version"],
  ["solar", "--version"],
  ["uname", "-sm"],
  ...(kind === "hermetic" ? [
    [FORGE, "build", "--use", "solar"],
    [FORGE, "test", "--use", "solar", "-vv", "--no-match-path", "**/fork/**", "--no-match-contract", "Fork"],
  ] : kind === "fork" ? [
    ["python3", "scripts/forge-artifacts.py", "test",
      "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol",
      "--test-root", "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration",
      "--", "-j", "1", "--compute-units-per-second", "10", "--rpc-timeout", "120", "-vv"],
  ] : [
    ["/bin/zsh", "-c", "bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts"],
    ["/bin/zsh", "-c", "bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts"],
  ]),
];
await save(join(evidence, "environment.json"), {
  cwd: process.cwd(), profile, platform: process.platform, arch: process.arch, versions: process.versions,
});
const results: { command: readonly string[]; code: unknown; signal: unknown; log: string }[] = [];
try {
  for (const [index, command] of commands.entries()) {
    const log = join(evidence, `${String(index).padStart(2, "0")}.log`);
    console.log(`CHECK_BEGIN ${kind} ${index}`);
    const result = await child(command, log, environment);
    results.push({ command, code: result.code, signal: result.signal, log });
    for (const line of result.output.split("\n")) {
      if (/^Ran \d+ test suites? in|^\s*\d+ (pass|fail)$|^\[FAIL|^Error|^error:/.test(line)) console.log(line);
    }
    console.log(`CHECK_END ${kind} ${index} ${String(result.code)}`);
    if (result.code !== 0) throw new Error(`validation failed: ${kind} command ${index}`);
  }
  console.log(`VERIFICATION_COMPLETE ${kind}`);
} finally {
  await save(join(evidence, "results.json"), { kind, results,
    completed: results.length === commands.length && results.every((result) => result.code === 0) });
}
