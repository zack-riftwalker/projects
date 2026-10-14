#!/usr/bin/env bash
# The MVGN-17 screenshot set: gfx-shots.sh <suffix> [gfx tier]   (writes docs/reports/img-gfx-network/<name>_<suffix>.png)
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/../../docs/reports/img-gfx-network"; mkdir -p "$OUT"
SUF=$1; shift
ARGS=""; [ -n "${1:-}" ] && ARGS="gfx=$1"
shot() { WAIT=${W:-40} bash "$HERE/shot.sh" "$OUT/$1_$SUF.png" "$2" $ARGS > /dev/null; }
shot N01 room:N01
shot N05 room:N05
shot N08 room:N08
shot N09 bossp3:N09:1.0
shot N09p3 bossp3:N09:0.2
shot N12 loss
shot N15 bossp3:N15:1.0
shot N15p3 bossp3:N15:0.2
shot N17 chase
shot N20 room:N20
shot N22p3 bossp3:N22:0.2
