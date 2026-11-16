// Read-only receipt audit against the two owned, literal loopback endpoints.
const dev = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
let id = 0;
async function rpc(port, method, params) {
    const request = { jsonrpc: "2.0", id: ++id, method, params };
    const response = await fetch(`http://127.0.0.1:${port}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(request),
        signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = await response.json();
    console.log(JSON.stringify({ port, request, response: body }));
    if (body.error || body.id !== request.id || !("result" in body)) {
        throw new Error(`RPC failure for ${method}`);
    }
    return body.result;
}
const last = Number(BigInt(await rpc(18546, "eth_blockNumber", [])));
let count = 0;
let maximumGas = 0;
for (let number = 1; number <= last; ++number) {
    const block = await rpc(18546, "eth_getBlockByNumber", [`0x${number.toString(16)}`, false]);
    if (BigInt(block.gasLimit) !== 100000000n) throw new Error("unexpected block gas limit");
    for (const hash of block.transactions) {
        const receipt = await rpc(18546, "eth_getTransactionReceipt", [hash]);
        const tx = await rpc(18546, "eth_getTransactionByHash", [hash]);
        if (!receipt || receipt.status !== "0x1" || receipt.transactionHash !== hash ||
            receipt.from.toLowerCase() !== dev || tx.from.toLowerCase() !== dev ||
            Number(BigInt(tx.nonce)) !== count || receipt.blockNumber !== block.number) {
            throw new Error(`invalid mined receipt ${hash}`);
        }
        maximumGas = Math.max(maximumGas, Number(BigInt(receipt.gasUsed)));
        ++count;
    }
}
const nonce = Number(BigInt(await rpc(18546, "eth_getTransactionCount", [dev, "latest"])));
const pending = Number(BigInt(await rpc(18546, "eth_getTransactionCount", [dev, "pending"])));
const otherNonce = await rpc(18547, "eth_getTransactionCount", [dev, "latest"]);
const otherBlock = await rpc(18547, "eth_blockNumber", []);
if (count !== 233 || nonce !== count || pending !== count ||
        otherNonce !== "0x0" || otherBlock !== "0x0") throw new Error("transaction coverage mismatch");
console.log(JSON.stringify({ result: "MINED_RECEIPTS_PASS", count, nonce, pending, last, maximumGas,
    otherNonce, otherBlock }));
