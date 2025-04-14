"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.debugError = exports.debugWarn = exports.debugLog = void 0;
const DEBUG_ENABLED = process.env.NEXT_PUBLIC_DEBUG === 'true';
function debugLog(...args) {
    if (!DEBUG_ENABLED)
        return;
    // eslint-disable-next-line no-console
    console.log(...args);
}
exports.debugLog = debugLog;
function debugWarn(...args) {
    if (!DEBUG_ENABLED)
        return;
    // eslint-disable-next-line no-console
    console.warn(...args);
}
exports.debugWarn = debugWarn;
function debugError(...args) {
    if (!DEBUG_ENABLED)
        return;
    // eslint-disable-next-line no-console
    console.error(...args);
}
exports.debugError = debugError;
