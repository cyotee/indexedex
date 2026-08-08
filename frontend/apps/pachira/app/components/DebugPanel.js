"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = require("react");
function DebugPanel({ title = 'Debug Information', children, className = '' }) {
    const [isOpen, setIsOpen] = (0, react_1.useState)(false);
    return (<div className={`mt-6 bg-slate-700/30 rounded-lg ${className}`}>
      <button onClick={() => setIsOpen(!isOpen)} className="w-full p-4 text-left flex items-center justify-between hover:bg-slate-600/30 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-600 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-800 rounded-lg">
        <span className="text-sm font-medium text-gray-300">{title}</span>
        <svg className={`w-4 h-4 text-gray-400 transition-transform ${isOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7"/>
        </svg>
      </button>
      
      {isOpen && (<div className="px-4 pb-4 border-t border-slate-600">
          <div className="pt-4 text-xs text-gray-400">
            {children}
          </div>
        </div>)}
    </div>);
}
exports.default = DebugPanel;
