"""Build the complete artifact graph, then exercise the consolidated funded suite."""
import json
import os
from pathlib import Path
import subprocess
import time
from build_provenance import capture

artifacts = Path(__file__).resolve().parent
checkout = artifacts.parent.parent
environment = os.environ.copy()
environment['FOUNDRY_PROFILE'] = 'default'
environment['FOUNDRY_TEST'] = os.environ.get(
    'DETF_TEST_ENTRY', 'test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol'
)
environment['FOUNDRY_SCRIPT'] = 'contracts/vaults/detf/common/core'
results = {'provenance': capture(checkout), 'foundry_environment': {
    key: environment[key] for key in ('FOUNDRY_PROFILE', 'FOUNDRY_TEST', 'FOUNDRY_SCRIPT')
}}
for phase, command in [
    ('build', ['forge', 'build', '--offline', '--contracts', 'contracts/vaults/detf/common/core']),
    ('test', ['forge', 'test', '--offline', '--contracts', 'contracts/vaults/detf/common/core', '-vvv']),
]:
    if phase == 'test' and os.environ.get('DETF_MATCH_TEST'):
        command += ['--match-test', os.environ['DETF_MATCH_TEST']]
    if phase == 'test' and os.environ.get('DETF_MATCH_CONTRACT'):
        command += ['--match-contract', os.environ['DETF_MATCH_CONTRACT']]
    started = time.monotonic()
    log = artifacts / f'funded-suite-{phase}.log'
    with log.open('w') as output:
        completed = subprocess.run(command, cwd=checkout, env=environment, stdout=output, stderr=subprocess.STDOUT)
    results[phase] = {'exit_code': completed.returncode, 'seconds': round(time.monotonic() - started, 3), 'command': command}
    (artifacts / 'funded-suite-run.json').write_text(json.dumps(results, indent=2) + '\n')
    print(phase, results[phase], flush=True)
    lines = log.read_text().splitlines()
    if completed.returncode:
        print('\n'.join(lines)[-4000:], flush=True)
    else:
        print('\n'.join(line for line in lines if line.startswith(('Compiling ', 'Solc ', 'Compiler run ', 'No files changed'))
                        or (line.startswith('Ran ') and 'test suites in' in line)), flush=True)
    if completed.returncode:
        raise SystemExit(completed.returncode)
