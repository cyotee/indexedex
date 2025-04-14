"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hasBytecode = exports.isZeroAddress = exports.ZERO_ADDR = void 0;
exports.ZERO_ADDR = '0x0000000000000000000000000000000000000000';
function isZeroAddress(address) {
    return address.toLowerCase() === exports.ZERO_ADDR;
}
exports.isZeroAddress = isZeroAddress;
async function hasBytecode(client, address) {
    const bytecode = await client.getBytecode({ address });
    return !!bytecode && bytecode !== '0x';
}
exports.hasBytecode = hasBytecode;
