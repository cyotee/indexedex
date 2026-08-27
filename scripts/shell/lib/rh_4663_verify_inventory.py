#!/usr/bin/env python3
"""Build the Robinhood mainnet (4663) verification inventory.

Sources, merged in order (later fills gaps, does not overwrite a name):
  1. Foundry broadcast/Phase_*/4663/run-latest.json CREATE / CREATE2
  2. deployments/anvil_robinhood_main/*.json named addresses
  3. On-chain IFacetRegistry.allFacets / IDiamondFactoryPackageRegistry.allPackages
     on the tree CREATE3 factory (when --rpc-url is reachable)

Prints a JSON array of {address, name, path, source, kind} to stdout.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

CREATE3_PROXY_INIT = "0x67363d3d37363d34f03d5260086018f3"
ZERO = "0x" + ("0" * 40)

# Canonical Robinhood / Uniswap / Morpho pins. Not IndexedEx bytecode.
PIN_KEYS = {
    "permit2",
    "weth",
    "weth9",
    "poolManager",
    "positionManagerV4",
    "universalRouter",
    "quoter",
    "stateView",
    "morpho",
    "morphoBlue",
    "morphoIrm",
    "morphoOracle",
    "uniswapV3Factory",
    "v3Factory",
    "v3Npm",
    "v3SwapRouter",
}

SKIP_JSON_KEYS = PIN_KEYS | {
    "chainId",
    "deployer",
    "owner",
    "uiWallet",
    "networkProfile",
    "rpcUrl",
}

# Diamonds / factories that are not (only) in the CREATE3 facet/package registries.
JSON_NAME = {
    "create3Factory": "Create3Factory",
    "diamondPackageFactory": "DiamondPackageCallBackFactory",
    "hookFactory": "UniswapV4HookDiamondPackageCallBackFactory",
    "hookFlagsFacet": "UniswapV4HookFlagsFacet",
    "feeCollector": "MinimalDiamondCallBackProxy",
    "indexedexManager": "MinimalDiamondCallBackProxy",
    "vaultRegistry": "MinimalDiamondCallBackProxy",
    "vaultFeeOracle": "MinimalDiamondCallBackProxy",
    "twapOracle": "MinimalDiamondCallBackProxy",
    "twapAdapterFactory": "UniswapV4TwapAdapterFactory",
    "twapOracleFacet": "UniswapV4MultiPoolTwapOracleFacet",
    "twapOraclePkg": "UniswapV4MultiPoolTwapOracleDFPkg",
    "rateProviderPkg": "StandardExchangeRateProviderDFPkg",
    "uniV4SePkg": "UniswapV4StandardExchangeDFPkg",
    "morphoBlueSePkg": "MorphoBlueStandardExchangeDFPkg",
    "bondNftVaultPkg": "DETFNFTVaultDFPkg",
    "rebasingClaimTokenPkg": "RebasingClaimTokenDFPkg",
    "cpHookPkg": "UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg",
    "weightedHookPkg": "UniswapV4StandardExchangeWeightedBufferHookDFPkg",
    "curveQuadHookPkg": "UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg",
    "cpDetfPkg": "UniswapV4SingleStandardExchangeDETDFPkg",
    "weightedDetfPkg": "UniswapV4StandardExchangeWeightedDETDFPkg",
    "curveQuadDetfPkg": "UniswapV4StandardExchangeCurveQuadStableDETDFPkg",
    "diamondCutFacet": "DiamondCutFacet",
    "erc20Facet": "ERC20Facet",
    "erc2612Facet": "ERC2612Facet",
    "erc4626Facet": "ERC4626Facet",
    "erc4626BasicVaultFacet": "ERC4626BasedBasicVaultFacet",
    "erc4626StandardVaultFacet": "ERC4626StandardVaultFacet",
    "erc5267Facet": "ERC5267Facet",
    "multiAssetBasicVaultFacet": "MultiAssetBasicVaultFacet",
    "multiAssetStandardVaultFacet": "MultiAssetStandardVaultFacet",
    "multiStepOwnableFacet": "MultiStepOwnableFacet",
    "operableFacet": "OperableFacet",
}

DECL_RE = re.compile(
    r"^\s*(?:abstract\s+)?(contract|library|interface)\s+([A-Za-z_][A-Za-z0-9_]*)\b",
    re.MULTILINE,
)


def checksum_key(addr: str) -> str:
    a = addr.strip()
    if not a.startswith("0x") and not a.startswith("0X"):
        a = "0x" + a
    return a.lower()


def is_address(value: object) -> bool:
    if not isinstance(value, str):
        return False
    v = value.strip()
    if not v.startswith("0x") or len(v) != 42:
        return False
    try:
        int(v, 16)
    except ValueError:
        return False
    return checksum_key(v) != ZERO


def kind_of(name: str) -> str:
    if name == "MinimalDiamondCallBackProxy":
        return "diamond-proxy"
    if name.endswith("DFPkg") or name.endswith("DETDFPkg"):
        return "package"
    if "Factory" in name:
        return "factory"
    if name.endswith("Facet"):
        return "facet"
    if name.endswith("Lib") or name.endswith("Math") or "Delegate" in name:
        return "library"
    return "contract"


def collect_sol_index(repo: Path) -> dict[str, list[str]]:
    roots = [
        repo / "contracts",
        repo / "lib" / "crane" / "contracts",
    ]
    index: dict[str, list[str]] = {}
    for root in roots:
        if not root.is_dir():
            continue
        for path in root.rglob("*.sol"):
            rel = path.relative_to(repo).as_posix()
            if "/test/" in f"/{rel}/" or "/tests/" in f"/{rel}/":
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for match in DECL_RE.finditer(text):
                kind, name = match.group(1), match.group(2)
                if kind == "interface":
                    continue
                index.setdefault(name, []).append(rel)
    return index


def score_path(rel: str, name: str) -> int:
    score = 0
    if rel.endswith(f"/{name}.sol"):
        score += 80
    if rel.startswith("contracts/"):
        score += 40
    if rel.startswith("lib/crane/contracts/"):
        score += 20
    if "/factories/create3/" in rel:
        score += 25
    if "/proxies/" in rel:
        score += 10
    if "/aave/" in rel or "/protocols/lending/" in rel:
        score -= 120
    if "/test/" in rel or "/mocks/" in rel or "/mock/" in rel:
        score -= 200
    return score


def resolve_path(index: dict[str, list[str]], name: str) -> str | None:
    paths = index.get(name) or []
    if not paths:
        return None
    ranked = sorted(paths, key=lambda p: (-score_path(p, name), p))
    return ranked[0]


def add_item(
    items: dict[str, dict],
    address: str,
    name: str | None,
    source: str,
    path: str | None = None,
    init_code: str | None = None,
) -> None:
    if not name:
        return
    key = checksum_key(address)
    if key == ZERO:
        return
    existing = items.get(key)
    if existing is None:
        items[key] = {
            "address": address if address.startswith("0x") else "0x" + address,
            "name": name,
            "path": path,
            "source": source,
            "kind": kind_of(name),
            "initCode": init_code,
        }
        return
    if not existing.get("path") and path:
        existing["path"] = path
    if not existing.get("initCode") and init_code:
        existing["initCode"] = init_code
    if existing.get("name") in (None, "MinimalDiamondCallBackProxy") and name != existing.get("name"):
        # Keep the more specific name when JSON mapped a diamond, broadcast named the proxy.
        if name != "MinimalDiamondCallBackProxy":
            existing["name"] = name
            existing["kind"] = kind_of(name)


def _read_broadcast_transactions(path: Path) -> list:
    """Load only the transactions array. Receipts in these files are huge."""
    buf: list[str] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if '"receipts"' in line and buf:
                break
            buf.append(line)
            if len(buf) > 500_000:
                break
    raw = "".join(buf).rstrip()
    if raw.endswith(","):
        raw = raw[:-1]
    if not raw.endswith("}"):
        raw = raw + "\n}\n"
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    txs = data.get("transactions")
    return txs if isinstance(txs, list) else []


def load_broadcast(repo: Path, chain_id: str) -> dict[str, dict]:
    items: dict[str, dict] = {}
    broadcast = repo / "broadcast"
    if not broadcast.is_dir():
        return items
    for run in sorted(broadcast.glob(f"Phase_*/{chain_id}/run-latest.json")):
        stage = run.parent.parent.name
        print(f"inventory: reading {stage}", file=sys.stderr, flush=True)
        txs = _read_broadcast_transactions(run)
        if not txs:
            continue
        for tx in txs:
            ttype = tx.get("transactionType")
            cname = tx.get("contractName")
            caddr = tx.get("contractAddress")
            if ttype in ("CREATE", "CREATE2") and cname and is_address(caddr):
                add_item(items, caddr, cname, f"broadcast:{stage}")
            for extra in tx.get("additionalContracts") or []:
                etype = extra.get("transactionType")
                ename = extra.get("contractName")
                eaddr = extra.get("address")
                init = extra.get("initCode") or ""
                if init.lower() == CREATE3_PROXY_INIT:
                    continue
                if etype in ("CREATE", "CREATE2") and ename and is_address(eaddr):
                    add_item(
                        items,
                        eaddr,
                        ename,
                        f"broadcast:{stage}",
                        init_code=init if init else None,
                    )
    return items


def load_deploy_json(repo: Path, deployments_dir: Path) -> dict[str, dict]:
    items: dict[str, dict] = {}
    if not deployments_dir.is_dir():
        return items
    files = list(deployments_dir.glob("phase*.json"))
    platform = deployments_dir / "platform.json"
    if platform.is_file():
        files.append(platform)
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict):
            continue
        for key, value in data.items():
            if key in SKIP_JSON_KEYS or not is_address(value):
                continue
            name = JSON_NAME.get(key)
            if not name:
                continue
            add_item(items, value, name, f"json:{path.name}")
    return items


def cast_call(rpc: str, address: str, sig: str, *args: str) -> str | None:
    cmd = ["cast", "call", address, sig, *args, "--rpc-url", rpc]
    try:
        proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def parse_address_list(raw: str) -> list[str]:
    out: list[str] = []
    for tok in re.findall(r"0x[a-fA-F0-9]{40}", raw):
        if checksum_key(tok) != ZERO:
            out.append(tok)
    return out


def parse_string(raw: str) -> str | None:
    text = raw.strip()
    if not text:
        return None
    if text.startswith('"') and text.endswith('"'):
        return json.loads(text)
    return text


def _name_one(rpc: str, create3: str, sig: str, addr: str, source: str) -> tuple[str, str | None, str]:
    name_raw = cast_call(rpc, create3, sig, addr)
    return addr, parse_string(name_raw) if name_raw else None, source


def load_onchain(rpc: str, create3: str) -> dict[str, dict]:
    items: dict[str, dict] = {}
    if not rpc or not is_address(create3):
        return items
    jobs: list[tuple[str, str, str]] = []
    facets_raw = cast_call(rpc, create3, "allFacets()(address[])")
    if facets_raw:
        for addr in parse_address_list(facets_raw):
            jobs.append((addr, "nameOfFacet(address)(string)", "registry:facet"))
    pkgs_raw = cast_call(rpc, create3, "allPackages()(address[])")
    if pkgs_raw:
        for addr in parse_address_list(pkgs_raw):
            jobs.append((addr, "nameOfPackage(address)(string)", "registry:package"))
    if not jobs:
        return items
    workers = min(12, max(4, len(jobs)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futs = [
            pool.submit(_name_one, rpc, create3, sig, addr, source) for addr, sig, source in jobs
        ]
        for fut in as_completed(futs):
            addr, name, source = fut.result()
            if name:
                add_item(items, addr, name, source)
    return items


def merge(*groups: dict[str, dict]) -> dict[str, dict]:
    items: dict[str, dict] = {}
    for group in groups:
        for key, row in group.items():
            add_item(
                items,
                row["address"],
                row["name"],
                row["source"],
                path=row.get("path"),
                init_code=row.get("initCode"),
            )
            # Prefer first source label if add_item kept the original.
            if items[key]["source"] != row["source"] and not items[key].get("path"):
                pass
    return items


def constructor_args_from_init(repo: Path, rel: str | None, name: str, init_code: str | None) -> str | None:
    """Suffix of CREATE3 initCode after local creation bytecode is the ctor args."""
    if not rel or not init_code:
        return None
    artifact = repo / "out" / Path(rel).name / f"{name}.json"
    if not artifact.is_file():
        return None
    try:
        data = json.loads(artifact.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    created = (data.get("bytecode") or {}).get("object") or ""
    created = created.lower().removeprefix("0x")
    init = init_code.lower().removeprefix("0x")
    if not created or not init.startswith(created):
        return None
    suffix = init[len(created) :]
    if not suffix:
        return None
    return "0x" + suffix


def kind_rank(kind: str) -> int:
    order = {
        "library": 0,
        "facet": 1,
        "package": 2,
        "factory": 3,
        "contract": 4,
        "diamond-proxy": 5,
    }
    return order.get(kind, 9)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--deployments", required=True)
    parser.add_argument("--chain-id", default="4663")
    parser.add_argument("--rpc-url", default="")
    parser.add_argument("--create3", default="")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    deployments = Path(args.deployments)
    if not deployments.is_absolute():
        deployments = repo / deployments

    index = collect_sol_index(repo)
    broadcast = load_broadcast(repo, args.chain_id)
    named = load_deploy_json(repo, deployments)

    create3 = args.create3
    if not create3:
        platform = deployments / "platform.json"
        if platform.is_file():
            try:
                create3 = json.loads(platform.read_text(encoding="utf-8")).get("create3Factory") or ""
            except (OSError, json.JSONDecodeError):
                create3 = ""

    onchain: dict[str, dict] = {}
    if args.rpc_url:
        onchain = load_onchain(args.rpc_url, create3)
        if not onchain:
            print(
                "warning: on-chain facet/package registry read returned no rows; using broadcast + JSON",
                file=sys.stderr,
            )

    items = merge(broadcast, named, onchain)
    rows = []
    missing = []
    for row in items.values():
        path = resolve_path(index, row["name"])
        row["path"] = path
        row["constructorArgs"] = constructor_args_from_init(
            repo, path, row["name"], row.get("initCode")
        )
        if not path:
            missing.append(row["name"])
        rows.append(row)

    rows.sort(key=lambda r: (kind_rank(r["kind"]), r["name"], r["address"].lower()))
    if missing:
        uniq = sorted(set(missing))
        print(f"warning: no source file for {len(uniq)} names: {', '.join(uniq)}", file=sys.stderr)

    json.dump(rows, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        raise SystemExit(0)
