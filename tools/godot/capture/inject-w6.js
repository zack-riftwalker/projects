// THE NETWORK (world 6) exists only in Godot: the JS game has no theme or song for it. capture.js runs this in the page (INJECT=w6) so the
// tile, theme and music captures can use the game's own renderers with these values. public/index.html is not touched.
module.exports = function inject() {
  G.THEME[6] = { name: 'THE NETWORK', path: '/net', time: '04:47', music: 'w6', ambient: '#8aa0e0',
    base: '#141a3a', dark: '#0b0f24', lite: '#24306a', cap: '#5ad1ff', capHi: '#d6f6ff', capLo: '#2a6fa8',
    code: ['#1c2550', '#26326a', '#3a2a6a', '#1c2550'],
    plat: '#c04a9a', platHi: '#ff9ad8', platLo: '#5a1f4a', accent: '#5ad1ff', fx: '#ff6ad5', glow: '#9ae8ff',
    liq: '#ff6ad5', liqHi: '#ffe0f6', liqLo: '#7a1f5a' };
  // 138 bpm, A minor (Am | F | C | G); I = intro, A = the glass arpeggio with the off-beat "packet" pulse, B = the motif; loop from A; `hi` is the layer an octave up
  const CH = 'Am | F | C | G | Am | F | C | G';
  G.SONGS.w6 = {
    bpm: 138,
    inst: { lead: 'bell', bass: 'sub' },
    sections: {
      I: { bars: 4, chords: 'Am | F | C | G', pad: { pad: true, v: 1.0 },
        arp: { arp: '0 . 2 . 3 . 2 .', u: 2, oct: 4, inst: 'glass', v: 0.55 } },
      A: { bars: 8, chords: CH, pad: { pad: true, v: 0.9 },
        arp: { arp: '0 2 1 2 3 2 1 2', u: 1, oct: 4, inst: 'glass', v: 0.65 },
        bass: { bass: '. 1 . 1 . 1 . 1', u: 2, v: 0.8 },
        tick: { arp: '. 3 . 3 . 3 . 3', u: 2, oct: 5, inst: 'glass', v: 0.3 },
        drums: { k: 'x...x...x...x...', h: '..x...x...x...x.', r: '............x...' },
        hi: { arp: '0 1 2 3 2 1 2 3', u: 1, oct: 5, inst: 'chip', v: 0.35 } },
      B: { bars: 8, chords: CH, pad: { pad: true, v: 0.9 },
        lead: `a5 - c6 - e6 - c6 a5 | f5 - a5 - c6 - a5 - | c6 - e6 - g6 - e6 c6 | b5 - d6 - g5 - - - |
               a5 - c6 - e6 - a6 - | a6 - f6 - c6 - a5 - | g6 - e6 - c6 - e6 - | d6 - b5 - g5 - - - |`,
        bass: { bass: '1 . . 1 . . 1 .', u: 2, v: 0.8 },
        arp: { arp: '0 2 1 2 3 2 1 2', u: 1, oct: 4, inst: 'glass', v: 0.45 },
        drums: { k: 'x...x...x...x...', s: '....x.......x...', h: 'x.x.x.x.x.x.x.x.' },
        hi: { arp: '0 2 1 3 2 4 3 2', u: 1, oct: 5, inst: 'chip', v: 0.3 } },
    },
    order: ['I', 'A', 'B', 'A', 'B'], loop: 1,
  };
};
