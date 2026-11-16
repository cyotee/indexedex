# Actual core eval function bodies

Recorded after the completed witness. These functions ran in the persistent
Bun kernel; this Markdown is documentation, not a new executable or contract.
The fixed constants, interfaces, derivations and ordered invocations are in
method.md and raw evidence. No production file imports these functions.

## rpc

```javascript
async function(method,params=[]){const request=JSON.stringify({jsonrpc:'2.0',id:++reqid,method,params});const response=await fetch('http://127.0.0.1:18572',{method:'POST',headers:{'content-type':'application/json'},body:request,signal:AbortSignal.timeout(90000)});const body=await response.text();wire.push({request,response:body,status:response.status});assert.equal(response.status,200);const parsed=JSON.parse(body);assert.equal(parsed.id,reqid);if(parsed.error)throw Object.assign(new Error('Local RPC returned error'),{rpcError:parsed.error});return parsed.result;}
```

## call

```javascript
async function(to,sig,args=[],from){const tx={to,data:iface.encodeFunctionData(sig,args),...(from?{from}: {})};return await rpc('eth_call',[tx,'latest']);}
```

## uint

```javascript
async function(to,sig,args=[]){return BigInt(await call(to,sig,args));}
```

## capture

```javascript
async function(){const b={block:await rpc('eth_blockNumber'),weights:{},rewards:{},sy:{},vaultShares:{}};for(const a of actors){b.weights[a]=String(await uint(T,'balanceOf',[a]));b.rewards[a]=String(await uint(T,'rewards',[a]));}for(const a of [...actors,T,V])b.sy[a]=String(await uint(Y,'balanceOf',[a]));for(const a of [...actors,T])b.vaultShares[a]=String(await uint(V,'balanceOf',[a]));b.weightSupply=String(await uint(T,'totalSupply'));b.vaultSupply=String(await uint(V,'totalSupply'));b.vaultAssets=String(await uint(V,'totalAssets'));b.sySupply=String(await uint(Y,'totalSupply'));return b;}
```

## signed

```javascript
async function(wallet,tx){const nonce=Number(BigInt(await rpc('eth_getTransactionCount',[wallet.address,'latest'])));const raw=await wallet.signTransaction({...tx,chainId:4663,type:0,gasPrice:2000000000n,gasLimit:5000000n,nonce});const record={authority:'real controlled development signature',raw,hash:ethers.keccak256(raw),signer:wallet.address};transactions.push(record);assert.equal(await rpc('eth_sendRawTransaction',[raw]),record.hash);await rpc('evm_mine');record.receipt=await rpc('eth_getTransactionReceipt',[record.hash]);record.canonical=await rpc('eth_getTransactionByHash',[record.hash]);record.trace=await rpc('debug_traceTransaction',[record.hash,{tracer:'callTracer'}]);return record;}
```

## claim

```javascript
async function(wallet,weight,label){const before=await capture(),w=lower(wallet.address);const shares=weight*BigInt(before.vaultShares[T])/BigInt(before.weightSupply);const preview=String(await uint(T,'previewClaim',[w,weight]));const vaultPreview=String(await uint(V,'previewRedeem',[shares]));const simulated=await call(T,'withdrawClaim',[weight],w);const tx=await signed(wallet,{to:T,data:iface.encodeFunctionData('withdrawClaim',[weight])});assert.equal(tx.receipt.status,'0x1');const after=await capture();const div=(n,d)=>({numerator:String(n),denominator:String(d),quotient:String(n/d),remainder:String(n%d)});const o={label,wallet:w,weight:String(weight),before,preview,vaultPreview,simulated,transactionHash:tx.hash,traceReturn:tx.trace.output,after,output:String(BigInt(after.sy[w])-BigInt(before.sy[w])),sharesBurned:String(BigInt(before.vaultShares[T])-BigInt(after.vaultShares[T])),weightShareFloor:div(weight*BigInt(before.vaultShares[T]),BigInt(before.weightSupply)),vaultRoundingCandidate:div(shares*(BigInt(before.vaultAssets)+1n),BigInt(before.vaultSupply)+10000000000n)};observations.push(o);assert.equal(BigInt(o.output),BigInt(simulated));assert.equal(o.preview,o.output);assert.equal(o.vaultPreview,o.output);print({label,wallet:w,q:o.weight,shares:o.sharesBurned,sy:o.output,hash:tx.hash});return o;}
```

## auditEvidence

```javascript
function(wire,transactions,observations,identities){const exchanges=wire.map(w=>{const q=JSON.parse(w.request),a=JSON.parse(w.response);assert.equal(w.status,200);assert.equal(q.id,a.id);assert.equal(a.jsonrpc,'2.0');return {q,a};});const bound=(method,hash)=>{const row=exchanges.find(x=>x.q.method===method&&x.q.params[0]===hash);assert.ok(row,method+hash);return row.a.result;};const sigs=[];for(const t of transactions){assert.deepEqual(t.canonical,bound('eth_getTransactionByHash',t.hash));assert.deepEqual(t.receipt,bound('eth_getTransactionReceipt',t.hash));assert.deepEqual(t.trace,bound('debug_traceTransaction',t.hash));const c=t.canonical,r=t.receipt;assert.equal(c.hash,t.hash);assert.equal(r.transactionHash,t.hash);for(const k of ['blockHash','blockNumber','transactionIndex','from','to','type'])assert.equal(c[k],r[k]);for(const l of r.logs)for(const k of ['blockHash','blockNumber','transactionHash','transactionIndex'])assert.equal(l[k],r[k]);if(t.raw){const tx=ethers.Transaction.from(t.raw);assert.equal(tx.hash,t.hash);assert.equal(ethers.keccak256(t.raw),t.hash);assert.equal(lower(tx.from),r.from);assert.equal(lower(ethers.recoverAddress(tx.unsignedHash,tx.signature)),r.from);assert.equal(lower(t.signer),r.from);assert.equal(tx.chainId,4663n);assert.equal(BigInt(c.nonce),BigInt(tx.nonce));assert.equal(tx.data,c.input);assert.equal(lower(tx.to),c.to);for(const [k,f]of [['value','value'],['gasLimit','gas'],['gasPrice','gasPrice']])assert.equal(tx[k],BigInt(c[f]));assert.ok(exchanges.some(x=>x.q.method==='eth_sendRawTransaction'&&x.q.params[0]===t.raw&&x.a.result===t.hash),'signed submission');sigs.push({hash:t.hash,signer:tx.from,nonce:tx.nonce});}else{assert.equal(c.from,donor);assert.equal(c.to,T);assert.equal(c.input.slice(0,10),'0xcc447fba');assert.ok(t.authority.includes('impersonated'));}}const claims=[];for(const o of observations){const b=o.before,a=o.after,w=lower(o.wallet),q=BigInt(o.weight),s=q*BigInt(b.vaultShares[T])/BigInt(b.weightSupply),out=BigInt(a.sy[w])-BigInt(b.sy[w]);assert.equal(BigInt(b.weights[w])-BigInt(a.weights[w]),q);assert.equal(BigInt(b.weightSupply)-BigInt(a.weightSupply),q);assert.equal(BigInt(b.vaultShares[T])-BigInt(a.vaultShares[T]),s);assert.equal(BigInt(b.vaultSupply)-BigInt(a.vaultSupply),s);assert.equal(BigInt(b.sy[V])-BigInt(a.sy[V]),out);assert.equal(BigInt(b.vaultAssets)-BigInt(a.vaultAssets),out);assert.equal(a.sySupply,b.sySupply);assert.deepEqual(a.rewards,b.rewards);for(const other of Object.keys(b.weights).filter(x=>x!==w)){assert.equal(a.weights[other],b.weights[other]);assert.equal(a.sy[other],b.sy[other]);}for(const other of Object.keys(b.vaultShares).filter(x=>x!==T))assert.equal(a.vaultShares[other],b.vaultShares[other]);const div=(n,d)=>({numerator:String(n),denominator:String(d),quotient:String(n/d),remainder:String(n%d)});assert.deepEqual(o.weightShareFloor,div(q*BigInt(b.vaultShares[T]),BigInt(b.weightSupply)));assert.deepEqual(o.vaultRoundingCandidate,div(s*(BigInt(b.vaultAssets)+1n),BigInt(b.vaultSupply)+10000000000n));for(const k of ['output','preview','vaultPreview','simulated','traceReturn'])assert.equal(BigInt(o[k]),out);const t=transactions.find(t=>t.hash===o.transactionHash);assert.ok(t);assert.equal(t.receipt.status,'0x1');assert.equal(t.receipt.from,w);assert.equal(t.canonical.input,iface.encodeFunctionData('withdrawClaim',[q]));assert.equal(BigInt(t.trace.output),out);const redeem=walk(t.trace).filter(c=>c.type==='CALL'&&c.to===V&&c.input.startsWith('0xba087652'));assert.equal(redeem.length,1);const args=iface.decodeFunctionData('redeem',redeem[0].input);assert.equal(args[0],s);assert.equal(lower(args[1]),w);assert.equal(lower(args[2]),T);assert.equal(BigInt(redeem[0].output),out);const logs=t.receipt.logs.filter(l=>l.address===T&&l.topics[0]===ethers.id('ClaimWithdrawn(address,uint256,uint256)'));assert.equal(logs.length,1);const e=iface.parseLog(logs[0]);assert.equal(lower(e.args[0]),w);assert.equal(e.args[1],q);assert.equal(e.args[2],out);claims.push({hash:t.hash,wallet:w,weight:String(q),shares:String(s),sy:String(out),weightDivision:o.weightShareFloor,syDivision:o.vaultRoundingCandidate,redeem:{receiver:args[1],owner:args[2]}});}for(const i of identities.identities){assert.equal(ethers.keccak256(i.code),i.codeHash);for(const b of i.bindings){assert.equal(ethers.id(b.sig).slice(0,10),b.selector);assert.equal(ethers.keccak256(b.runtime),b.codeHash);if(b.facet!==ethers.ZeroAddress)assert.ok(exchanges.some(x=>x.q.method==='eth_getCode'&&x.q.params[0]===b.facet&&x.a.result===b.runtime),'code '+b.sig);const data=iface.encodeFunctionData('facetAddress',[b.selector]);assert.ok(exchanges.some(x=>x.q.method==='eth_call'&&x.q.params[0].to===i.target&&x.q.params[0].data===data&&lower(abi.decode(['address'],x.a.result)[0])===b.facet),'binding '+b.sig);}}return {exchanges:wire.length,transactions:transactions.length,signatures:sigs,claims,identityChecks:true};}
```

## auditStates

```javascript
function(wire,book){let block=108944663n;const calls=new Map();for(const w of wire){const q=JSON.parse(w.request),a=JSON.parse(w.response);if(q.method==='evm_mine'&&!a.error)block+=1n;if(q.method==='eth_blockNumber'){assert.equal(BigInt(a.result),block);}if(q.method==='eth_call'&&!a.error){const tx=q.params[0];const key=String(block)+'|'+tx.to+'|'+tx.data;const prior=calls.get(key);if(prior!==undefined)assert.equal(prior,a.result);calls.set(key,a.result);}}const states=[book.initialState,book.preparedState,book.finalPreparedState,...book.observations.flatMap(o=>[o.before,o.after]),book.failures.repeated.before,book.failures.repeated.after,book.failures.tiny.before,book.failures.tiny.after];let fields=0;for(const s of states){const check=(to,sig,args,value)=>{const key=String(BigInt(s.block))+'|'+to+'|'+iface.encodeFunctionData(sig,args);assert.ok(calls.has(key),'missing raw state '+key);assert.equal(BigInt(calls.get(key)),BigInt(value));fields++;};for(const [field,to,sig]of [['weights',T,'balanceOf'],['rewards',T,'rewards'],['sy',Y,'balanceOf'],['vaultShares',V,'balanceOf']])for(const [wallet,n]of Object.entries(s[field]))check(to,sig,[wallet],n);for(const [field,to,sig]of [['weightSupply',T,'totalSupply'],['vaultSupply',V,'totalSupply'],['vaultAssets',V,'totalAssets'],['sySupply',Y,'totalSupply']])check(to,sig,[],s[field]);}assert.deepEqual(economic(book.failures.repeated.before),economic(book.failures.repeated.after));assert.deepEqual(economic(book.failures.tiny.before),economic(book.failures.tiny.after));return {snapshots:states.length,stateFieldsMatched:fields,chronology:'exact manual evm_mine count and eth_blockNumber',lastBlock:String(block)};}
```
