#!/usr/bin/env node
/* WCAG contrast check for the main colour pairs of the navy/gold theme. Fails (exit 1) if any pair is < 4.5:1. */
const L = (h) => { const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((v) => v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4)); return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]; };
const ratio = (a, b) => { const x = L(a), y = L(b); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };
const C = { bg: '#0A1630', bg2: '#0E1F42', surface: '#132A55', surface2: '#1A3668', gold: '#E8B54A', goldHi: '#F6D27A', text: '#F3F6FC', text2: '#A9B8D6', muted: '#8294BA', onGold: '#0A1630', ok: '#3DDC97', bad: '#FF7A6B', info: '#5BB8FF' };
const pairs = [['text', 'bg'], ['text', 'surface'], ['text', 'surface2'], ['text2', 'bg'], ['text2', 'surface'], ['muted', 'surface'], ['onGold', 'gold'], ['onGold', 'goldHi'], ['gold', 'surface'], ['ok', 'surface'], ['bad', 'surface'], ['info', 'surface'], ['gold', 'bg']];
let bad = 0;
for (const [f, b] of pairs) { const r = ratio(C[f], C[b]); const ok = r >= 4.5; if (!ok) bad++; console.log((ok ? 'ok  ' : 'FAIL') + ' ' + f + ' on ' + b + ' ' + r.toFixed(2)); }
process.exit(bad ? 1 : 0);
