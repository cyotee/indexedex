#!/usr/bin/env python3
import glob
import json
import os
import shutil
import sys
import time


def usage() -> int:
    print(
        "Usage: export_frontend_artifacts.py <deployments_dir> <frontend_dir> <chain_id>",
        file=sys.stderr,
    )
    return 1


if len(sys.argv) != 4:
    raise SystemExit(usage())


deployments_dir = sys.argv[1]
frontend_dir = sys.argv[2]
chain_id = int(sys.argv[3])
frontend_export_prefix = os.environ.get("FRONTEND_EXPORT_PREFIX", "").strip()
frontend_export_tokenlist_prefix = os.environ.get("FRONTEND_EXPORT_TOKENLIST_PREFIX", "").strip()
frontend_export_contractlist_prefix = os.environ.get("FRONTEND_EXPORT_CONTRACTLIST_PREFIX", "").strip()

if frontend_export_prefix:
    if not frontend_export_tokenlist_prefix:
        frontend_export_tokenlist_prefix = frontend_export_prefix
    if not frontend_export_contractlist_prefix:
        frontend_export_contractlist_prefix = frontend_export_prefix

os.makedirs(frontend_dir, exist_ok=True)


def remap_filename(filename: str, prefix: str) -> str:
    if not prefix:
        return filename
    if "-" not in filename:
        return filename
    _, suffix = filename.split("-", 1)
    return f"{prefix}-{suffix}"

for path in glob.glob(os.path.join(deployments_dir, "*.tokenlist.json")):
    filename = remap_filename(os.path.basename(path), frontend_export_tokenlist_prefix)
    shutil.copy2(path, os.path.join(frontend_dir, filename))

copied_contractlists = False
for path in glob.glob(os.path.join(deployments_dir, "*.contractlist.json")):
    filename = remap_filename(os.path.basename(path), frontend_export_contractlist_prefix)
    shutil.copy2(path, os.path.join(frontend_dir, filename))
    copied_contractlists = True

if frontend_export_contractlist_prefix and not copied_contractlists:
    with open(os.path.join(frontend_dir, f"{frontend_export_contractlist_prefix}-factories.contractlist.json"), "w", encoding="utf-8") as handle:
        json.dump([], handle, indent=2)
        handle.write("\n")

def sort_key(path: str) -> tuple[int, str]:
    name = os.path.basename(path)
    if len(name) > 2 and name[:2].isdigit() and name[2] in {"_", "-"}:
        return (0, name)
    if name == "deployment_summary.json":
        return (2, name)
    return (1, name)


platform = {}
for path in sorted(glob.glob(os.path.join(deployments_dir, "*.json")), key=sort_key):
    if path.endswith(".tokenlist.json"):
        continue
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception:
        continue
    if isinstance(data, dict):
        platform.update(data)

platform["chainId"] = chain_id
platform["exportedAt"] = str(int(time.time()))
if "create3Factory" in platform and "craneFactory" not in platform:
    platform["craneFactory"] = platform["create3Factory"]
if "diamondPackageFactory" in platform and "craneDiamondFactory" not in platform:
    platform["craneDiamondFactory"] = platform["diamondPackageFactory"]
if "uniswapV2Pkg" in platform and "uniswapV2StandardStrategyVaultPkg" not in platform:
    platform["uniswapV2StandardStrategyVaultPkg"] = platform["uniswapV2Pkg"]

with open(os.path.join(frontend_dir, "base_deployments.json"), "w", encoding="utf-8") as handle:
    json.dump(platform, handle, indent=2)
    handle.write("\n")
