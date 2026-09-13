#!/usr/bin/env python3
"""Audit Solidity import fan-out and refresh runtime deployment artifacts.

Uses current source imports, never Foundry's possibly stale dependency cache.
Only `build` and `test` compile; `audit` and `plan` do not modify out/cache_forge.
"""

import argparse
from collections import defaultdict
import glob
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


TOKEN = re.compile(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|//[^\n]*|/\*[\s\S]*?\*/''')
IMPORT = re.compile(r'''\bimport\s+(?:[^;]*?\bfrom\s+)?["']([^"']+)["'][^;]*;''')
ARTIFACT = re.compile(r'''["']([^"'\s]+\.sol:[A-Za-z_$][\w$]*)["']''')
DECLARATION = re.compile(r"\b(?:(abstract)\s+)?(contract|library|interface)\s+([A-Za-z_$][\w$]*)")
CREATION = re.compile(r"\btype\s*\(\s*([A-Za-z_$][\w$]*)\s*\)\s*\.\s*creationCode\b")
ONCHAIN_CREATION = {
    "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol":
        "Live onchain CREATE3 deployment/address prediction cannot read local artifacts.",
    "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol":
        "Onchain CREATE2 proxy init hash must match deployed proxy creation code.",
    "contracts/test/balancer/v3/PoolFactoryMock.sol":
        "PoolFactoryMock implements pool creation inside the simulated chain.",
}


def without_comments(source):
    return TOKEN.sub(lambda match: match.group(1) or re.sub(r"[^\n]", " ", match.group()), source)


def non_source_helper(path):
    parts = Path(path).parts
    name = Path(path).name
    return ("test" in parts or "tests" in parts or "script" in parts or "scripts" in parts
            or name.startswith("TestBase") or name.endswith((".t.sol", ".s.sol"))
            or "ArtifactSeed" in name or name.endswith("Artifacts.sol"))


class SourceGraph:
    def __init__(self, root, config=None):
        self.root = Path(root).resolve()
        if config is None:
            result = subprocess.run(["forge", "config", "--json"], cwd=self.root,
                                    capture_output=True, text=True, check=False)
            if result.returncode:
                raise ValueError(f"Cannot resolve Foundry configuration: {result.stderr.strip()}")
            config = json.loads(result.stdout)
        self.config = config
        self.src = self.config.get("src", "src")
        self.out = self.config.get("out", "out")
        remappings = self.config.get("remappings", [])
        self.remappings = []
        for remapping in remappings:
            prefix, destination = remapping.split("=", 1)
            context, separator, prefix_only = prefix.rpartition(":")
            self.remappings.append((context if separator else "", prefix_only, destination))
        self.remappings.sort(key=lambda item: len(item[1]), reverse=True)
        self.sources = {}
        self.forward = defaultdict(set)
        self.reverse = defaultdict(set)
        self.unresolved = defaultdict(set)
        self.by_basename = defaultdict(set)
        self.declarations = {}
        self.artifacts = {}
        self.runtime_sources = set()
        self.own_sources = set()
        roots = {self.src, "test", "script", "scripts/foundry", self.config.get("test", "test")}
        for directory in sorted(roots):
            for file in self._files(directory):
                self.own_sources.add(file)
        # Discover artifact roots even after consumers stop importing them.
        discovery = set(self.own_sources)
        for _, _, destination in self.remappings:
            directory = Path(destination)
            if (self.root / directory / "contracts").is_dir():
                directory /= "contracts"
            discovery.update(self._files(directory))
        for path in discovery:
            self.by_basename[Path(path).name].add(path)
        self.load_sources(self.own_sources)
        # Artifact roots are source roots, without adding a Solidity dependency
        # edge from the consumer. Inspect their imports for reverse invalidation.
        visited = set()
        while True:
            unvisited = set(self.sources) - visited
            if not unvisited:
                break
            artifact_sources = set()
            for path in unvisited:
                visited.add(path)
                for artifact in self.artifacts[path]:
                    try:
                        artifact_sources.add(self.resolve_artifact(artifact))
                    except ValueError:
                        pass  # Resolve selected artifacts strictly when planning.
            self.runtime_sources.update(artifact_sources)
            self.load_sources(artifact_sources)

    def load_sources(self, paths):
        pending = list(paths)
        while pending:
            path = pending.pop()
            if path in self.sources:
                continue
            source = without_comments((self.root / path).read_text())
            self.sources[path] = source
            self.by_basename[Path(path).name].add(path)
            self.declarations[path] = [(kind, name, bool(abstract))
                                       for abstract, kind, name in DECLARATION.findall(source)]
            self.artifacts[path] = set(ARTIFACT.findall(source))
            for imported in IMPORT.findall(source):
                resolved = self.resolve_import(imported, path)
                if resolved is None:
                    self.unresolved[path].add(imported)
                    continue
                self.forward[path].add(resolved)
                self.reverse[resolved].add(path)
                pending.append(resolved)

    def _files(self, directory):
        base = self.root / directory
        if not base.is_dir():
            return
        for current, directories, files in os.walk(base):
            directories[:] = [name for name in directories if name not in {".git", "node_modules", "out", "cache_forge"}]
            for name in files:
                if name.endswith(".sol"):
                    yield Path(current, name).relative_to(self.root).as_posix()

    def normalize(self, path):
        absolute = Path(os.path.normpath(self.root / path))
        try:
            return absolute.relative_to(self.root).as_posix()
        except ValueError as error:
            raise ValueError(f"Source path outside repository: {path}") from error

    def resolve_import(self, imported, importer=""):
        if imported.startswith("."):
            candidate = self.normalize(Path(importer).parent / imported)
        else:
            candidate = imported
            for context, prefix, destination in self.remappings:
                if imported.startswith(prefix) and (not context or importer.startswith(context)):
                    candidate = destination + imported[len(prefix):]
                    break
            candidate = self.normalize(candidate)
        return candidate if (self.root / candidate).is_file() else None

    def resolve_artifact(self, artifact):
        source, contract = artifact.rsplit(":", 1)
        exact = self.resolve_import(source)
        candidates = {exact} if exact else set(self.by_basename.get(Path(source).name, ()))
        if "/" in source and not exact:
            candidates = {path for path in candidates if path.endswith(source)}
        for path in candidates:
            if path not in self.declarations:
                self.declarations[path] = [(kind, name, bool(abstract)) for abstract, kind, name in
                                          DECLARATION.findall(without_comments((self.root / path).read_text()))]
        candidates = {path for path in candidates if any(name == contract
                      for _, name, _ in self.declarations[path])}
        if len(candidates) != 1:
            raise ValueError(f"Artifact {artifact!r} resolves to {len(candidates)} sources: {sorted(candidates)}")
        return next(iter(candidates))

    def closure(self, paths, reverse=False):
        pending = [self.normalize(path) for path in paths]
        unknown = set(pending) - self.sources.keys()
        for path in unknown:
            if not path.endswith(".sol") or not (self.root / path).is_file():
                raise ValueError(f"Solidity source not found in project graph: {path}")
        # Callers may explicitly select archive or other sources outside the
        # initial project roots. Never silently treat an unread source as a leaf.
        self.load_sources(unknown)
        graph = self.reverse if reverse else self.forward
        seen = set()
        while pending:
            path = pending.pop()
            if path in seen:
                continue
            seen.add(path)
            pending.extend(graph.get(path, ()))
        return seen

    def impact(self, source):
        affected = self.closure([source], reverse=True) - {source}
        return {"source": source, "dependents": len(affected),
                "hermetic_dependents": sum(path.startswith("test/foundry/spec/") for path in affected),
                "production_dependents": sum(not non_source_helper(path) for path in affected)}

    def library_artifacts(self, artifact):
        source, contract = artifact.rsplit(":", 1)
        parts = Path(source).parts
        artifact_path = next((self.root / self.out / Path(*parts[index:]) / f"{contract}.json"
                              for index in range(len(parts))
                              if (self.root / self.out / Path(*parts[index:]) / f"{contract}.json").is_file()), None)
        if artifact_path is None:
            return set()
        try:
            data = json.loads(artifact_path.read_text())
        except (OSError, ValueError) as error:
            raise ValueError(f"Cannot read link references from {artifact_path}: {error}") from error
        return {f"{library_source}:{name}"
                for library_source, libraries in data.get("bytecode", {}).get("linkReferences", {}).items()
                for name in libraries}

    def plan(self, changed, consumers=(), all_artifacts=False, allow_empty=False):
        changed = {self.normalize(path) for path in changed}
        consumers = {self.normalize(path) for path in consumers}
        for path in changed | consumers:
            if path not in self.sources:
                if not path.endswith(".sol") or not (self.root / path).is_file():
                    raise ValueError(f"Solidity source not found in project graph: {path}")
                self.load_sources([path])
        affected = self.closure(changed, reverse=True)
        roots = {path for path in affected if (not non_source_helper(path) or path in self.runtime_sources)
                 and any(kind in {"contract", "library"} and not abstract
                         for kind, _, abstract in self.declarations.get(path, []))}
        roots.update(path for path in changed if not non_source_helper(path) or path in self.runtime_sources)
        pending = self.closure(roots | consumers | changed)
        if all_artifacts:
            # Literal strings in individual negative tests intentionally name
            # nonexistent artifacts. Seed deployment helpers, not every test input.
            pending.update(path for path in self.own_sources
                           if path.startswith(self.src + "/") or path.startswith("scripts/foundry/"))
        visited = set()
        artifact_ids = set()
        while pending:
            path = pending.pop()
            if path in visited:
                continue
            visited.add(path)
            for artifact in self.artifacts.get(path, ()):
                queue = [artifact]
                while queue:
                    current = queue.pop()
                    if current in artifact_ids:
                        continue
                    artifact_ids.add(current)
                    artifact_source = self.resolve_artifact(current)
                    self.load_sources([artifact_source])
                    roots.add(artifact_source)
                    pending.update(self.closure([artifact_source]) - visited)
                    # Existing artifacts expose external linking dependencies. A cold
                    # build gets them through the current Solidity import closure.
                    queue.extend(self.library_artifacts(current) - artifact_ids)
        compile_closure = self.closure(roots)
        missing = {path: sorted(self.unresolved[path]) for path in sorted(compile_closure)
                   if self.unresolved[path]}
        if missing:
            raise ValueError(f"Unresolved imports in selected compilation graph: {json.dumps(missing)}")
        if not roots and not allow_empty:
            raise ValueError("No artifact build roots selected; supply production sources, --consumer, or --all-artifacts.")
        return {"changed": sorted(changed), "consumers": sorted(consumers),
                "impact": [self.impact(path) for path in sorted(changed)],
                "roots": sorted(roots), "runtime_artifacts": sorted(artifact_ids),
                "compile_source_count": len(compile_closure),
                "command": (["forge", "build", *sorted(roots)] if roots else [])}

    def audit(self, sources):
        creation = []
        imported_artifacts = []
        for path in sorted(self.own_sources):
            for match in CREATION.finditer(self.sources[path]):
                creation.append({"path": path, "line": self.sources[path].count("\n", 0, match.start()) + 1,
                                 "contract": match.group(1), "exception": ONCHAIN_CREATION.get(path)})
            for artifact in sorted(self.artifacts[path]):
                try:
                    dependency = self.resolve_artifact(artifact)
                except ValueError:
                    continue  # Fixture and negative-test strings need not be real artifacts.
                if dependency in self.forward[path]:
                    imported_artifacts.append({"path": path, "artifact": artifact, "import": dependency})
        return {"source_count": len(self.sources),
                "impact": [self.impact(self.normalize(path)) for path in sources],
                "creation_code": creation, "artifact_implementation_imports": imported_artifacts}


def expand_consumers(root, patterns):
    paths = set()
    for pattern in patterns:
        matches = glob.glob(str(root / pattern), recursive=True)
        files = {str(Path(path).relative_to(root)) for path in matches if Path(path).is_file()}
        if not files:
            raise ValueError(f"No consumer source matches {pattern!r}")
        paths.update(files)
    return paths


def test_scope(graph, selected):
    path = graph.normalize(selected)
    absolute = graph.root / path
    active_test = Path(graph.normalize(graph.config.get("test", "test")))
    if not Path(path).is_relative_to(active_test):
        raise ValueError(f"Test root {path} is outside the active profile's test root {active_test}; "
                         "select the appropriate existing profile before running its tests.")
    if absolute.is_file() and path.endswith(".t.sol"):
        consumers = {path}
    elif absolute.is_dir():
        consumers = {file.relative_to(graph.root).as_posix() for file in absolute.rglob("*.t.sol")}
    else:
        raise ValueError(f"Test root must be an existing .t.sol file or directory: {path}")
    if not consumers:
        raise ValueError(f"No .t.sol test files under {path}")
    return path, consumers


def test_skip_patterns(graph, selected):
    """Exclude unrelated input roots while preserving Foundry's configured paths.

    Foundry applies skip filters before resolving imports. Dependencies of the
    selected tests remain in the graph, including linked-library outputs.
    """
    selected = [graph.root / path for path in selected]
    patterns = set()

    def exclude_unselected(path):
        if path in selected or not path.exists():
            return
        if path.is_dir() and any(target.is_relative_to(path) for target in selected):
            for child in sorted(path.iterdir()):
                exclude_unselected(child)
        elif path.is_dir():
            patterns.add(path.relative_to(graph.root).as_posix() + "/**")
        elif path.suffix == ".sol":
            patterns.add(path.relative_to(graph.root).as_posix())

    for root in {graph.src, graph.config.get("test", "test"), graph.config.get("script", "script")}:
        exclude_unselected(graph.root / root)
    return sorted(patterns)


def test_plan(graph, changed, selected, consumers=(), all_artifacts=False,
              no_consumer_artifacts=False, forge_args=()):
    selections = [selected] if isinstance(selected, (str, Path)) else selected
    test_roots = set()
    test_consumers = set()
    for selection in selections:
        path, scoped_consumers = test_scope(graph, selection)
        test_roots.add(path)
        test_consumers.update(scoped_consumers)
    if not test_roots:
        raise ValueError("At least one test root is required")
    test_roots = sorted(test_roots)
    runtime_consumers = set(consumers)
    if not no_consumer_artifacts:
        runtime_consumers.update(test_consumers)
    elif not changed and not runtime_consumers:
        raise ValueError("--no-consumer-artifacts requires explicit production/fixture sources or --consumer.")
    result = graph.plan(changed, runtime_consumers, all_artifacts, allow_empty=True)
    extra_test_imports = sorted(source for source in graph.closure(test_consumers) - test_consumers
                                if source.endswith(".t.sol"))
    test_args = list(forge_args)
    has_path_filter = any(argument.split("=", 1)[0] in {"--match-path", "--mp"} for argument in test_args)
    if extra_test_imports and not has_path_filter:
        # No filter skips Forge 1.5.1's ABI preflight. When tests import other test
        # files, add one to keep execution inside the user's exact requested scope.
        patterns = [path if path.endswith(".t.sol") else path + "/**" for path in test_roots]
        test_args += ["--match-path", patterns[0] if len(patterns) == 1 else "{" + ",".join(patterns) + "}"]
    skip_patterns = test_skip_patterns(graph, test_roots)
    for pattern in skip_patterns:
        test_args += ["--skip", pattern]
    result.update({"test_roots": test_roots, "test_files": sorted(test_consumers),
                   "extra_test_imports": extra_test_imports,
                   "test_skip_patterns": skip_patterns,
                   "test_command": ["forge", "test", *test_args]})
    return result


def execute_plan(root, plan, run_tests=False):
    if plan["command"]:
        result = subprocess.run(plan["command"], cwd=root, check=False)
        if result.returncode:
            return result.returncode
    if run_tests:
        return subprocess.run(plan["test_command"], cwd=root, check=False).returncode
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("audit", "plan", "build", "test"))
    parser.add_argument("sources", nargs="*", help="Edited Solidity source paths, including targets/interfaces/libraries")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--consumer", action="append", default=[], help="Test/script path or quoted glob whose runtime artifacts must be refreshed")
    parser.add_argument("--all-artifacts", action="store_true", help="Seed literal runtime artifacts referenced by production/deployment helper sources")
    parser.add_argument("--test-root", action="append", help="Exact .t.sol file or directory to run; repeat to select a union; excludes other roots with --skip")
    parser.add_argument("--no-consumer-artifacts", action="store_true", help="For negative loader tests, prepare explicit sources/consumers instead of scanning test artifact literals")
    parser.add_argument("--json", action="store_true", help="Print machine-readable audit/plan")
    argv = sys.argv[1:]
    separator = argv.index("--") if "--" in argv else len(argv)
    args = parser.parse_intermixed_args(argv[:separator])
    forge_args = argv[separator + 1:]
    if args.action == "test" and not args.test_root:
        parser.error("test requires --test-root with an exact test file or directory")
    if (args.test_root or args.no_consumer_artifacts or forge_args) and args.action not in {"plan", "test"}:
        parser.error("--test-root, --no-consumer-artifacts and arguments after -- require plan or test")
    if (args.no_consumer_artifacts or forge_args) and not args.test_root:
        parser.error("--no-consumer-artifacts and arguments after -- require --test-root")
    try:
        graph = SourceGraph(args.root)
        if args.action == "audit":
            result = graph.audit(args.sources)
        else:
            consumers = expand_consumers(graph.root, args.consumer)
            if args.test_root:
                result = test_plan(graph, args.sources, args.test_root, consumers, args.all_artifacts,
                                   args.no_consumer_artifacts, forge_args)
            else:
                result = graph.plan(args.sources, consumers, args.all_artifacts)
        if args.json or args.action == "audit":
            print(json.dumps(result, indent=2))
        else:
            print(f"{len(result['roots'])} build roots; {result['compile_source_count']} sources in import closure; "
                  f"{len(result['runtime_artifacts'])} runtime artifact IDs.")
            if result["command"]:
                print(shlex.join(result["command"]), flush=True)
            if args.test_root:
                print(shlex.join(result["test_command"]), flush=True)
        if args.action in {"build", "test"}:
            return execute_plan(graph.root, result, run_tests=args.action == "test")
        return 0
    except (OSError, ValueError) as error:
        print(f"forge-artifacts: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
