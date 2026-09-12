"""Locate a source-less solc error without changing compiler settings or sources.

This diagnostic uses the exact settings exported by Forge. It only narrows the
requested bytecode outputs; it is not a replacement for the release build.
"""
from pathlib import Path
import copy
import json
import subprocess
import time

art = Path(__file__).resolve().parent
root = art.parent.parent
settings = json.loads((art / 'script-base-main-compiler-input.json').read_text())['settings']
assert settings['viaIR'] is False
assert settings['optimizer'] == {'enabled': True, 'runs': 1}
paths = json.loads((art / 'maintained-script-build-scope.json').read_text())['included_sources']
solc = Path.home() / '.svm/0.8.35/solc-0.8.35'
record_path = art / 'script-codegen-isolation.json'
record = {'status': 'RUNNING', 'settings': settings, 'runs': [], 'failing_sources': []}
record_path.write_text(json.dumps(record, indent=2) + '\n')


def check(selected):
    local_settings = copy.deepcopy(settings)
    local_settings['outputSelection'] = {p: {'*': ['evm.bytecode.object']} for p in selected}
    compiler_input = {'language': 'Solidity', 'settings': local_settings,
                      'sources': {p: {'urls': [p]} for p in selected}}
    started = time.monotonic()
    result = subprocess.run([str(solc), '--base-path', str(root), '--allow-paths', str(root),
                             '--standard-json'], input=json.dumps(compiler_input),
                            capture_output=True, text=True, cwd=root)
    output = json.loads(result.stdout)
    errors = [e for e in output.get('errors', []) if e['severity'] == 'error']
    row = {'sources': selected, 'seconds': round(time.monotonic() - started, 3),
           'exit_code': result.returncode, 'errors': errors,
           'compiled_source_count': len(output.get('contracts', {}))}
    record['runs'].append(row)
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'sources': len(selected), 'seconds': row['seconds'],
                      'errors': [e['message'] for e in errors]}), flush=True)
    return bool(errors)


def isolate(selected):
    if not check(selected):
        return
    if len(selected) == 1:
        record['failing_sources'].extend(selected)
        print('FAILING SOURCE ' + selected[0], flush=True)
        return
    middle = len(selected) // 2
    isolate(selected[:middle])
    isolate(selected[middle:])


# The complete Forge caller build has already failed. Test both partitions so
# independent errors cannot be hidden by whichever source solc reports first.
middle = len(paths) // 2
isolate(paths[:middle])
isolate(paths[middle:])
record['status'] = 'COMPLETED'
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'failing_sources': record['failing_sources']}), flush=True)
