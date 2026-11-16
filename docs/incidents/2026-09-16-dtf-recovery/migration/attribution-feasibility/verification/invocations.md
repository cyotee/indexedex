# Independent verification invocations

Date: 2026-11-11. Only verification/ is written through apply_patch.
No producer function was imported or invoked. No new runtime probe was needed.

## Worktree identity

Initial ordinary git status exited 128:

```text
error: expected submodule path 'lib/crane' not to be a symbolic link
```

The next symlink-safe command printed the expected branch and HEAD; its final
`ls -ld lib/* node_modules out cache_forge 2>/dev/null` exited 1 because the
warm-artifact directories are absent. Neither result was called a clean check.
The following isolated corrected command exited 0:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2 &&
GIT_MASTER=1 git status --short --ignore-submodules=all &&
GIT_MASTER=1 git diff --exit-code --ignore-submodules=all &&
GIT_MASTER=1 git diff --cached --exit-code --ignore-submodules=all &&
GIT_MASTER=1 git branch --show-current &&
GIT_MASTER=1 git rev-parse HEAD
```

```text
?? docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility/
work/dtf-migration-phase-06-e2
5021e8d4a62bcbddc555f580ef98f8666d993aab
```

Existing upstream evidence was already present. This verifier does not claim
it began with an empty untracked tree. lib/crane and node_modules resolve to
the main checkout; no link, submodule or configuration was changed.

## Offline evidence audit

Actual execution: resident Bun 1.4.4 evaluation; normal return, 33/33 assertions
passed. Of 242 complete receipt-list comparisons, 240 mutated lists failed
original-root equality and the two unchanged controls matched. Every input
sequence and resulting root is retained in audit.json. No subprocess was used,
so no process exit code is invented. The arithmetic results are also retained.

The following is a whitespace-reformatted reproduction of the actual function,
not a separately executed second run. It uses a recursive trie encoder rather
than the construction lane's fixed two/three-leaf encoder. Only tiny fixtures
and receipt types 0, 2 and 106 were exercised. It is not an audited general
proof library. Mutated lists are supplied-byte attacks, not valid signed chain
histories. Whole-batch replay prevention is not supplied by a receipt root.

```javascript
function independentAudit(ar, fr, cp, ts, v) {
  const checks=[];
  const check=(name,ok,details={})=>{checks.push({name,pass:!!ok,details});if(!ok)throw Error(name);};
  const A=id=>JSON.parse(ar.requests.find(r=>r.request.id===id).raw);
  const F=i=>JSON.parse(fr.records[i].raw).result;
  const integer=x=>BigInt(x)===0n?'0x':v.toHex(BigInt(x));
  const encodeReceipt=r=>{const body=v.toRlp([r.root??integer(r.status),integer(r.cumulativeGasUsed),r.logsBloom,r.logs.map(l=>[l.address,l.topics,l.data])]);if(![0n,2n,106n].includes(BigInt(r.type)))throw Error('unexamined receipt type');return BigInt(r.type)===0n?body:v.toHex(BigInt(r.type),{size:1})+body.slice(2);};
  const nibbles=h=>[...h.slice(2)].map(x=>parseInt(x,16));
  const compact=(path,leaf)=>{const flag=leaf?2:0;return '0x'+(path.length%2?[flag+1,...path]:[flag,0,...path]).map(x=>x.toString(16)).join('');};
  const ref=node=>{const bytes=v.toRlp(node);return (bytes.length-2)/2<32?node:v.keccak256(bytes);};
  const node=rows=>{if(rows.length===1)return [compact(rows[0].path,true),rows[0].value];let prefix=0;while(rows.every(r=>r.path.length>prefix&&r.path[prefix]===rows[0].path[prefix]))prefix++;if(prefix)return [compact(rows[0].path.slice(0,prefix),false),ref(node(rows.map(r=>({...r,path:r.path.slice(prefix)}))))];const branch=Array(17).fill('0x');for(let k=0;k<16;k++){const subset=rows.filter(r=>r.path[0]===k);if(subset.length)branch[k]=ref(node(subset.map(r=>({...r,path:r.path.slice(1)}))));}const terminal=rows.find(r=>!r.path.length);if(terminal)branch[16]=terminal.value;return branch;};
  const trie=receipts=>receipts.length?v.keccak256(v.toRlp(node(receipts.map((r,i)=>({path:nibbles(v.toRlp(integer(i))),value:encodeReceipt(r)}))))):v.keccak256(v.toRlp('0x'));
  const header=h=>v.toRlp([h.parentHash,h.sha3Uncles,h.miner,h.stateRoot,h.transactionsRoot,h.receiptsRoot,h.logsBloom,integer(h.difficulty),integer(h.number),integer(h.gasLimit),integer(h.gasUsed),integer(h.timestamp),h.extraData,h.mixHash,h.nonce,integer(h.baseFeePerGas)]);
  for(const id of [3,5,42])check('native header '+id,v.keccak256(header(A(id).result))===A(id).result.hash);
  check('parent anchor connection',A(14).result===A(42).result.hash&&A(27).result===A(14).result);
  check('historical typed receipt root',trie([A(54).result,A(52).result])===A(3).result.receiptsRoot);
  check('history runtime identity',A(20).result===A(24).result&&v.keccak256(A(20).result)==='0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff');
  check('ArbSys boundary',!!A(14).result&&!!A(15).result&&[16,17,18].every(i=>A(i).error?.data.startsWith('0xd5dc642d')));
  check('history boundary',!!A(32).result&&!!A(36).result&&[33,34,37,38,49,50].every(i=>A(i).error?.data==='0x'));
  check('nested history returns real parent',A(51).result==='0x'+'1'.padStart(64,'0')+'20'.padStart(64,'0')+A(14).result.slice(2));
  check('NodeInterface nested empty result',A(48).result==='0x'+'1'.padStart(64,'0')+'0'.repeat(64));
  check('NUMBER domain',BigInt(A(22).result)===26367659n&&BigInt(A(11).result)===108944663n);
  check('finalized tag only hash is anchored',A(57).result===A(10).result.hash);
  const token=fr.result.subjects.token,facet=fr.result.subjects.facet;
  check('deployed generic facet bytes bound',v.keccak256(F(66)[facet].code)===cp.contracts[facet].codeHash&&F(66)[facet].code===F(87)[facet].code);
  const branches=[{name:'control',rs:[62,64,63].map(F),block:F(65)},{name:'mixing',rs:[84,83,85].map(F),block:F(86)}];
  const mutations=[];
  for(const b of branches){check(b.name+' full raw trie',trie(b.rs)===b.block.receiptsRoot);check(b.name+' ordered runtime receipts',b.rs.every((r,i)=>r.status==='0x1'&&BigInt(r.transactionIndex)===BigInt(i)&&r.blockHash===b.block.hash&&r.transactionHash===b.block.transactions[i]));
    const visit=seq=>{const root=trie(seq.map(i=>b.rs[i]));const canonical=seq.join(',')==='0,1,2';if((root===b.block.receiptsRoot)!==canonical)throw Error('unexpected root equality '+b.name+seq);mutations.push({branch:b.name,sequence:seq,root,canonical});if(seq.length<4)for(let i=0;i<3;i++)visit([...seq,i]);};visit([]);
    check(b.name+' omission reorder repeat variants',mutations.filter(x=>x.branch===b.name).length===121,{rejected:120,accepted:1});
    const metadata=b.rs.map(r=>({...r,transactionIndex:'0x99',blockHash:'0x'+'ab'.repeat(32),logs:r.logs.map(l=>({...l,logIndex:'0xffff'}))}));
    check(b.name+' unauthenticated metadata does not change root',trie(metadata)===b.block.receiptsRoot);
  }
  check('same selected storage',Bun.deepEquals(F(66)[token].storage,F(87)[token].storage));
  check('same custody request',Bun.deepEquals(fr.records[60].params,fr.records[81].params));
  check('same parent',branches[0].block.parentHash===branches[1].block.parentHash);
  check('not equal full custody receipt',encodeReceipt(branches[0].rs[2])!==encodeReceipt(branches[1].rs[2]));
  check('not equal whole traced prestate',!Bun.deepEquals(F(66),F(87)));
  const {alice,bob,custody}=fr.result.subjects;
  const replay=rs=>{const ledger=new Map([[alice,[100n,1000n]],[bob,[100n,3000n]],[custody,[0n,0n]]]);for(const r of rs)for(const l of r.logs){if(l.topics[0]!=='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef')continue;if(l.address!==token)throw Error('wrong source');const from='0x'+l.topics[1].slice(-40),to='0x'+l.topics[2].slice(-40),q=BigInt(l.data);const a=ledger.get(from),b=ledger.get(to);if(!a||!b||q>a[0])throw Error('bad transition');if(from!==to){const c=q===a[0]?a[1]:a[1]*q/a[0];a[0]-=q;a[1]-=c;b[0]+=q;b[1]+=c;}}return Object.fromEntries([...ledger].map(([a,p])=>[a,p.map(String)]));};
  const credit={control:replay(branches[0].rs),mixing:replay(branches[1].rs),omittedPrefix:replay([branches[1].rs[2]]),repeatedPrefix:replay([branches[1].rs[0],branches[1].rs[1],branches[1].rs[0],branches[1].rs[1],branches[1].rs[2]])};
  check('raw events yield unequal awards',credit.control[custody][1]==='500'&&credit.mixing[custody][1]==='833',credit);
  check('omission and repeated prefix alter credit without final units',credit.omittedPrefix[custody][1]==='500'&&credit.repeatedPrefix[custody][1]==='944'&&Object.values(credit).every(l=>l[alice][0]==='50'&&l[bob][0]==='100'&&l[custody][0]==='50'));
  check('all variant credit conserved',Object.values(credit).every(l=>Object.values(l).reduce((s,p)=>s+BigInt(p[1]),0n)===4000n));
  const T=i=>JSON.parse(ts.rpc[i].response).result;
  check('claimant facet byte identity',v.keccak256(T(3))==='0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742');
  const reverted=ts.checks[0].attempt;const rawFail=ts.rpc.filter(r=>r.method==='eth_getTransactionReceipt').map(r=>JSON.parse(r.response).result).find(r=>r.transactionHash===reverted.hash);
  check('ordinary claimant forwarding actually reverts',rawFail.status==='0x0'&&reverted.trace.output.startsWith('0x936d426d')&&reverted.trace.output.slice(10,74).endsWith(ts.checks[0].forwarder.address.slice(2)));
  const successful=ts.checks[1].reassignment;const flatten=t=>[t,...(t.calls??[]).flatMap(flatten)];
  check('claimant reassignment has no receiver call',successful.receipt.status==='0x1'&&!flatten(successful.trace).some(t=>t.to===ts.checks[1].rejectingReceiver.address)&&T(38)==='0x'+'0'.repeat(64)&&BigInt(T(39))===64890781291192882058375n);
  check('snapshot restoration recorded',[76,97,98].every(i=>F(i)===true)&&T(42)===true);
  return {runtime:{bun:Bun.version},checks,mutations,credit,scope:'Offline evidence audit; no E2 verifier or runtime probe',limits:['Synthetic baseline, not actual awards','Root mutants are supplied-byte attacks, not new legal signed chain histories','No deployed continuation, source-complete replay, prefix authentication or funded-bond integration']};
}
```

Inputs and invocation in the resident interface (read/print are host helpers):

```javascript
const wt = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2";
const f = wt + "/docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility";
const p1 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration";
const v = await import(wt + "/node_modules/viem/_esm/index.js");
const ar = JSON.parse(await read(f + "/anchors/rpc.json"));
const fr = JSON.parse(await read(f + "/freshness/runtime-evidence.json"));
const cp = JSON.parse(await read(p1 + "/evidence/earlier-cp/probe-alchemy-retry.source.json"));
const ts = JSON.parse(await read(p1 + "/evidence/verification/tokenstaking-caller.json"));
const result = independentAudit(ar, fr, cp, ts, v);
print(JSON.stringify(result, null, 2));
```

The producer commands/results remain in anchors/commands.md,
freshness/invocations.md and construction/invocations.md. They were read, not
rerun. All raw requests/results used by this audit remain in their original
files. No public RPC request, fork, transaction or compilation was performed
by this verifier. Assigned port 18554 was unused.

## Primary documentation and display issues

Read-only web opens corroborated the pinned ArbSys source and the official
finality/reorg model. Exact primary locators:

```text
https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/ArbSys.go
https://docs.arbitrum.io/how-arbitrum-works/reference/finality-and-reorgs
```

Primary protocol excerpts and deployed archives were inspected directly.
Report line citations use the archived raw source line numbers, not the web
renderer, which collapses blank lines. The source archive's whole-file hashes
do not imply that whole upstream files were archived; it retains excerpts.

Initial tool-object/escaped-JSON displays were truncated. Full inputs were
then read through the resident read helper and relevant fields printed in
newline-preserving form. Runtime bytecode was hashed/compared directly rather
than treating an elided display as a complete visual inspection.
An unawaited schema lookup printed a pending Promise; awaiting it supplied the
schema before any write. During first artifact assembly, a function declaration
from the completed audit cell was unavailable in the next cell:
`independentAudit is not defined`. The successful audit result remained in
memory; no write had run. The reproduction text was retained explicitly and
only artifact assembly was retried. No valid probe or audit was rerun.

## Scope and cleanup

Final input-preservation hashes, owned Markdown/JSON/link checks, Git identity
and assigned-port results are in cleanup.json. No node, temporary root or
server was created; no process or directory deletion is needed. No Forge,
test-suite run, production/test edit, dependency/config edit, commit, public
transaction or delegation occurred. No LSP result is claimed for Markdown/JSON.

## Root's deployed-model clarification

After the initial report, root requested that the result distinguish a finite
missing runtime/surface check from an appeal to unspecified stronger systems.
Report sections 1.1 and 7.1 answer that request. The concrete admitted
completed-parent/selected-observation construction is refuted; overall E2
remains unproven, with no claim that an omitted known RPC query rescues it.

Read-only primary-source retrieval used `webfetch`, text format, timeout 30:

```text
https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/precompiles.go
result: 404: Not Found

https://api.github.com/repos/OffchainLabs/nitro/contents/precompiles?ref=70fa99a6e711f09eedd96a907290c3df0f3bcf7d
result: directory entries identified precompile.go, ArbInfo.go and ArbStatistics.go

https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/precompile.go
https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/ArbInfo.go
https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/ArbStatistics.go
result: source text retrieved; exact hashes, inspected ranges and observations
        retained in native-surface-scope.json
```

The source registration enumeration returned 18 names. An initial explanatory
string said 17; it was corrected to the actual 18 before final validation.
No handler completeness or new onchain behavior is claimed from that listing.
The report names the finite version-gated method/dataflow inventory and
conditional named native probe that would close that protocol question; it
does not require another generic investigation to reject the failed candidate.
No new chain probe, process, compiler or dependency was used.

