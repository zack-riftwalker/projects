#!/usr/bin/env python3
"""Rooms per region: designed (world-phase45.json) vs built (a room file exists).

For the producer board (docs/studio/PRODUCER.md). Rooms from the earlier phases
(R01-R15, D01-D07) are not in the JSON; they are counted from the files.
Usage: python3 tools/studio/rooms.py
"""
import json, os, re, collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
ROOMS = os.path.join(ROOT, 'godot', 'src', 'world', 'rooms')
WORLD = os.path.join(ROOT, 'docs', 'metroidvania', 'world-phase45.json')
NAMES = {'src': 'SOURCE TREE', 'depths': 'DEPENDENCY DEPTHS', 'heap': 'THE HEAP', 'net': 'THE NETWORK',
         'tower': 'THREAD TOWER', 'git': 'GIT HISTORY', 'hell': 'DEPENDENCY HELL', 'prod': 'PRODUCTION',
         'kernel': 'KERNEL (/boot)'}
PREFIX = {'R': 'src', 'D': 'depths', 'H': 'heap', 'N': 'net', 'T': 'tower', 'G': 'git', 'X': 'hell', 'P': 'prod'}

built = {f[:-4] for f in os.listdir(ROOMS) if f.endswith('.txt')}
zone = {r['id']: r['zone'] for r in json.load(open(WORLD, encoding='utf-8'))['rooms']}
for rid in built:                      # older rooms the JSON doesn't list; Z = the test lab, not the game
    if rid not in zone and rid[0] in PREFIX:
        zone[rid] = PREFIX[rid[0]]

total = collections.Counter(zone.values())
done = collections.Counter(z for rid, z in zone.items() if rid in built)
missing = collections.defaultdict(list)
for rid, z in sorted(zone.items()):
    if rid not in built:
        missing[z].append(rid)

for z in NAMES:
    if total[z]:
        print('%-18s %3d / %-3d %s' % (NAMES[z], done[z], total[z], ' '.join(missing[z]) if 0 < len(missing[z]) < 6 else ''))
print('%-18s %3d / %-3d (%d%%)' % ('ALL', sum(done.values()), sum(total.values()),
                                   round(100 * sum(done.values()) / sum(total.values()))))
