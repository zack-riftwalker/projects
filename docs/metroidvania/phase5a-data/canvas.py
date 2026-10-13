# tiny drawing helper for room files
class C:
    def __init__(s, w, h, fill="#"):
        s.w, s.h = w, h
        s.g = [[fill] * w for _ in range(h)]

    def rect(s, x0, y0, x1, y1, ch):          # inclusive
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.g[y][x] = ch
        return s

    def box(s, top=1, bottom=1, side=1):       # hollow out the interior, walls of the given thickness
        return s.rect(side, top, s.w - 1 - side, s.h - 1 - bottom, " ")

    def put(s, x, y, text):
        for i, ch in enumerate(text):
            s.g[y][x + i] = ch
        return s

    def at(s, x, y):
        return s.g[y][x]

    def rows(s):
        return ["".join(r) for r in s.g]
