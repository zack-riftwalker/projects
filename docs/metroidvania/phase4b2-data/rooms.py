# NETWORK (phase 4B-2) room data: draws every room file and its rooms.json entry.
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canvas import C

R = {}      # id -> (canvas, meta)


def room(rid, title, w, h, x, y, doors, **kw):
    c = C(w, h)
    meta = {"file": rid + ".txt", "title": title, "size": [w, h], "origin": [x, y], "world": 6, "music": "w6", "zone": "net",
            "signs": [], "doors": []}
    for d in doors:
        dd = {"id": d[0], "side": d[1], "a": d[2], "b": d[3], "to": d[4]}
        if len(d) > 5 and d[5]:
            dd["lock"] = d[5]
        meta["doors"].append(dd)
    meta.update(kw)
    R[rid] = (c, meta)
    return c


def open_doors(c, meta):
    """cut every door into the edge (W/E: the edge column; N/S: the edge row)"""
    for d in meta["doors"]:
        s, a, b = d["side"], d["a"], d["b"]
        for i in range(a, b + 1):
            if s == "W":
                c.g[i][0] = " " if c.g[i][0] == "#" else c.g[i][0]
            elif s == "E":
                c.g[i][c.w - 1] = " " if c.g[i][c.w - 1] == "#" else c.g[i][c.w - 1]
            elif s == "N":
                c.g[0][i] = " " if c.g[0][i] == "#" else c.g[0][i]
            else:
                c.g[c.h - 1][i] = " " if c.g[c.h - 1][i] == "#" else c.g[c.h - 1][i]


# ------------------------------------------------------------------ N01 eth0 (48x16): the gate from the HEAP; the airgap lands here
c = room("N01", "eth0", 48, 16, 1260, -52, [
    ("N01:W", "W", 9, 12, "H11:E"), ("N01:E", "E", 9, 12, "N04:W"), ("N01:S", "S", 34, 37, "N03:N"),
    ("N01:N", "N", 1, 46, "N11:S2", "oneway")],
    landmarks=["tower"])
c.box(top=1, bottom=3).rect(1, 0, 46, 0, " ")             # the open sky under the airgap
c.put(34, 13, "====").rect(34, 14, 37, 15, " ")            # the hatch down to the router (a lid: [down]+[jump] to drop)
c.put(5, 12, "T").put(12, 12, "o o o").put(42, 6, "d")
R["N01"][1]["signs"] = ["PING /net (eth0): 64 bytes from /proc/heap: icmp_seq=1 ttl=64 time=4.20 ms. Someone is listening."]
R["N01"][1]["decor"] = [{"kind": "fiber", "x": 1, "y": 13, "w": 46}]

# ------------------------------------------------------------------ N04 robots.txt (32x16): the clue
c = room("N04", "robots.txt", 32, 16, 1308, -52, [
    ("N04:W", "W", 9, 12, "N01:E"), ("N04:E", "E", 9, 12, "N05:W"), ("N04:N", "N", 1, 30, "N11:S3", "oneway")])
c.box(top=1, bottom=3).rect(1, 0, 30, 0, " ")
c.rect(13, 11, 15, 12, "#").put(13, 10, "ooo").put(7, 12, "T").put(24, 12, "G")
R["N04"][1]["signs"] = ["robots.txt\nUser-agent: *\nDisallow: /backup"]

# ------------------------------------------------------------------ N05 sitemap.xml (120x20): webs, scrapers, two dead-code secrets
c = room("N05", "sitemap.xml", 120, 20, 1340, -58, [
    ("N05:W", "W", 15, 18, "N04:E"), ("N05:E", "E", 15, 18, "N08:W"),
    ("N05:N", "N", 70, 73, "N19:S"), ("N05:S", "S", 52, 55, "N20:N")],
    landmarks=["ci"], dead_quiet=[[70, 0]],
    variants=[{"if": "boss:CRAWLER", "rect": [0, 0, 120, 20], "from": "h", "to": " "}])
c.box(top=1, bottom=1)
c.put(70, 0, ";;;;")                                       # /backup: the ceiling is dead code (no moths: the clue is robots.txt)
c.put(52, 19, ";;;;")                                      # 404: dead code floor under the one-way lid, one moth
c.put(50, 17, "========").put(50, 18, "##").put(56, 18, "##")
# webs at knee height (jump them); off after the WEB CRAWLER
c.put(18, 18, "hhh").put(34, 18, "hhh").put(88, 18, "hhh").put(104, 18, "hhh")
# the climb to the /backup ledge (a dead end with tokens: the robots.txt clue says why)
c.put(59, 16, "=====").put(62, 13, "=====").put(65, 10, "=====").put(66, 7, "=====").put(68, 4, "========").put(70, 3, "ooo")
# an upper catwalk on the east half and its tokens
c.put(80, 14, "======").put(86, 11, "======").put(87, 10, "ooo")
# scrapers on hooks (GET rings after the WEB CRAWLER) and a drone
c.put(28, 3, "c").put(44, 3, "c").put(84, 3, "c").put(100, 3, "c").put(110, 8, "d")
c.put(8, 18, "T").put(112, 18, "T")
R["N05"][1]["signs"] = ["sitemap.xml: every page the crawler found. It is still crawling.",
                        "<url><loc>/net/crawl_queue</loc><priority>1.0</priority></url>"]

# ------------------------------------------------------------------ N08 crawl_queue (26x72): the climb to the WEB CRAWLER
c = room("N08", "crawl_queue", 26, 72, 1460, -110, [
    ("N08:W", "W", 67, 70, "N05:E"), ("N08:W2", "W", 13, 16, "N09:E", "fight"), ("N08:E", "E", 50, 53, "N18:W")],
    landmarks=["ci"], sighting={"kind": "crawler", "row": 30},
    variants=[{"if": "boss:CRAWLER", "rect": [0, 0, 26, 72], "from": "h", "to": " "}])
c.box(top=1, bottom=1)
c.rect(1, 17, 6, 17, "#")                                  # the floor in front of the arena door
L = {68: (9, 14), 65: (2, 7), 62: (2, 7), 59: (2, 7), 56: (2, 7), 53: (2, 7), 50: (2, 7), 47: (2, 7), 44: (9, 14), 41: (17, 22),
     38: (9, 14), 35: (2, 7), 32: (9, 14), 29: (17, 22), 26: (9, 14), 23: (2, 7), 20: (8, 13)}
for row, (a, b) in L.items():
    c.put(a, row, "=" * (b - a + 1))
# the curl stub to token_ring: a pocket in the east wall, roofed so nobody drops in from above
c.rect(21, 54, 24, 54, "#").rect(11, 49, 24, 49, "#")     # the lip, and a wide roof: no drop from above curls into it
c.put(13, 52, "@").put(19, 52, "@")
# hooks (scrapers now, GET rings after the boss): a fast curl climb on the way back
for (hx, hy) in [(12, 64), (5, 58), (16, 39), (12, 34), (19, 27), (12, 22), (5, 19)]:
    c.put(hx, hy, "c")
# webs: a strand across the right side and one under the left ledges
c.put(15, 45, "hhhhhh").put(1, 37, "hhh").put(18, 33, "hhhh")
c.put(4, 70, "T").put(3, 16, "T").put(4, 46, "o").put(4, 43, "o")
R["N08"][1]["signs"] = ["crawl_queue: 1,042 URLs waiting. The crawler takes them from the top.",
                        "Disallow: /. (it did not listen.)"]

# ------------------------------------------------------------------ N09 WEB CRAWLER (24x14)
c = room("N09", "WEB CRAWLER", 24, 14, 1436, -104, [
    ("N09:E", "E", 7, 10, "N08:W2", "fight"), ("N09:W", "W", 7, 10, "N10:E", "until:boss:CRAWLER")],
    boss={"id": "CRAWLER", "class": "CrawlerBoss", "name": "WEB CRAWLER", "sub": "it follows every link", "trigger_x": 304,
          "trigger_side": "E", "T": 80, "u": 0.7, "reward": "curl", "banner": "curl",
          "banner_sub": "near a GET ring, press [special]: you zip to it", "music": "boss", "drop": 40})
c.box(top=1, bottom=3)
c.put(1, 8, "===").put(20, 8, "===").put(8, 10, "B")

# ------------------------------------------------------------------ N10 GET.http (96x20): curl, single to chains
c = room("N10", "GET.http", 96, 20, 1340, -112, [
    ("N10:E", "E", 15, 18, "N09:W"), ("N10:W", "W", 15, 18, "N11:E")],
    landmarks=["ci"])
c.box(top=1, bottom=1)
c.put(70, 19, "^" * 10).put(74, 14, "@")
c.put(46, 19, "^" * 16).put(57, 14, "@").put(50, 14, "@")
c.put(14, 19, "^" * 22).put(31, 13, "@").put(25, 12, "@").put(19, 13, "@")
c.put(40, 9, "@").put(36, 7, "=========").put(38, 6, "ooo")
c.put(88, 18, "T").put(6, 18, "T")
R["N10"][1]["signs"] = ["GET /curl HTTP/1.1\n200 OK\nNear a blue GET ring, press [special]: you zip to it and pop up. Chain them.",
                        "GET /airgap: 301 Moved. Mind the gap."]

# ------------------------------------------------------------------ N11 airgap (100x52)
c = room("N11", "airgap", 100, 52, 1240, -104, [
    ("N11:E", "E", 7, 10, "N10:W"), ("N11:W", "W", 41, 44, "T01:E"), ("N11:N", "N", 40, 43, "T16:S"),
    ("N11:S1", "S", 10, 18, "H11:N2"), ("N11:S2", "S", 21, 66, "N01:N"), ("N11:S3", "S", 69, 98, "N04:N")],
    landmarks=["tower"], end="to be continued in /dev/threads")
c.box(top=1, bottom=0)
c.rect(1, 51, 98, 51, " ")                                 # the whole floor is open sky (three drops)
c.rect(0, 45, 9, 51, "#").rect(19, 51, 20, 51, "#").rect(67, 51, 68, 51, "#")
c.rect(88, 11, 98, 13, "#")                                # the shelf at the door from GET.http
for (rx, ry) in [(84, 12), (79, 14), (74, 16), (61, 19), (56, 21), (51, 23), (46, 25), (32, 28), (27, 30), (22, 32), (17, 34), (13, 40)]:
    c.put(rx, ry, "@")
c.rect(66, 19, 70, 19, "#").rect(37, 28, 43, 28, "#").rect(9, 37, 13, 37, "#")
c.put(94, 10, "T").put(7, 44, "T").put(3, 44, "D")
R["N11"][1]["signs"] = ["airgap: no cable between these machines. GET your way across. (fall, and eth0 catches you.)",
                        "/dev/threads: the tower is closed tonight."]

# ------------------------------------------------------------------ N03 core_router (24x34): hub and terminal
c = room("N03", "core_router", 24, 34, 1290, -36, [
    ("N03:N", "N", 4, 7, "N01:S"), ("N03:S", "S", 10, 13, "N22:N")],
    terminal=True)
c.box(top=1, bottom=1)
c.rect(1, 3, 10, 3, "#").put(2, 2, "C").put(9, 2, "T")
P = {6: (13, 18), 9: (18, 22), 12: (13, 17), 15: (7, 11), 18: (2, 6), 21: (7, 11), 24: (13, 17), 27: (18, 22), 29: (13, 17), 31: (9, 14)}
for row, (a, b) in P.items():
    c.put(a, row, "=" * (b - a + 1))
R["N03"][1]["signs"] = ["core_router: every route comes through here. Rest, and travel between terminals."]

# ------------------------------------------------------------------ N22 review_queue (24x14): under the hub; THE REVIEWER #2 (optional)
c = room("N22", "review_queue", 24, 14, 1290, -2, [
    ("N22:N", "N", 10, 13, "N03:S", "fight"), ("N22:W", "W", 7, 10, "N06:E", "fight"), ("N22:E", "E", 7, 10, "N12:W", "fight")],
    boss={"id": "REVIEWER2", "class": "Reviewer2", "name": "THE REVIEWER #2", "sub": "second review", "trigger": "pad",
          "pad": [11, 10], "pad_needs": "1of:ability:curl,ability:ssh", "T": 70, "u": 0.84, "reward": "plugin:review_cache",
          "banner": "review cache", "banner_sub": "plugin - after a catch, your next claw hits harder", "music": "tension", "drop": 30},
    decor=[{"kind": "chair", "x": 11, "y": 10}])
c.box(top=1, bottom=3)
c.put(2, 8, "====").put(18, 8, "====").put(6, 5, "====").put(14, 5, "====").put(9, 2, "======")
c.put(7, 10, "T").put(16, 10, "B")
R["N22"][1]["signs"] = [{"text": "2nd review: pending. (sit, when you have something new to show.)",
                         "alt": [{"if": "boss:REVIEWER2", "text": "2nd review: approved. LGTM."}]}]

# ------------------------------------------------------------------ N06 traceroute (52x16): the cartographer
c = room("N06", "traceroute", 52, 16, 1238, -3, [
    ("N06:E", "E", 8, 11, "N22:W"), ("N06:S", "S", 26, 29, "N07:N")],
    npc=[{"kind": "tree", "x": 38, "y": 8, "zone": "net", "price": 40}],
    decor=[{"kind": "scrap", "x": 33, "y": 11}, {"kind": "scrap", "x": 34, "y": 10}, {"kind": "scrap", "x": 35, "y": 9}])
c.box(top=1, bottom=2).rect(30, 12, 50, 13, "#")         # west floor row 14, east floor row 12 (the door side)
c.rect(26, 14, 29, 15, " ")
c.put(36, 9, "=====").put(46, 11, "T").put(41, 11, "T").put(33, 11, "T").put(10, 13, "T").put(3, 13, "ooooo")
R["N06"][1]["signs"] = ["traceroute to 127.0.0.1 (loopback), 64 hops max", " 1  core_router  0.42 ms", " 2  * * *",
                        " 3  ttl  (down the shaft)  ...  loopback"]

# ------------------------------------------------------------------ N07 ttl (24x32): wall jumps only
c = room("N07", "ttl", 24, 32, 1260, 13, [
    ("N07:N", "N", 4, 7, "N06:S"), ("N07:S", "S", 4, 7, "N02:N")])
c.rect(4, 0, 7, 10, " ")                                   # upper chimney
c.rect(1, 9, 22, 10, " ")                                  # landing 1 (floor row 11)
c.rect(14, 11, 17, 20, " ")                                # middle chimney
c.rect(1, 20, 22, 21, " ")                                 # landing 2 (floor row 22)
c.rect(4, 22, 7, 31, " ")                                  # lower chimney
c.put(19, 10, "T").put(10, 10, "ooo").put(11, 21, "ooo")
R["N07"][1]["signs"] = ["ttl=64. Every hop takes one. At zero the packet is dropped."]

# ------------------------------------------------------------------ N02 loopback (48x16): the back door from DEPTHS; the lever
c = room("N02", "loopback", 48, 16, 1236, 45, [
    ("N02:N", "N", 28, 31, "N07:S"), ("N02:W", "W", 9, 12, "D07:E")],
    levers=[{"x": 4, "y": 12, "flag": "lever:D06"}])
c.box(top=1, bottom=3)
c.rect(1, 1, 26, 1, "#").rect(33, 1, 46, 1, "#")
c.rect(27, 1, 27, 8, "#").rect(32, 1, 32, 8, "#")         # the chimney walls under the hole
c.put(25, 10, "==========").put(4, 12, "I").put(8, 12, "T").put(40, 12, "G").put(14, 12, "ooo")
R["N02"][1]["signs"] = ["loopback: 127.0.0.1. Home is a short way back. (the lever opens the slot gate in symlink.sh)"]

# ------------------------------------------------------------------ N12 port_scan (72x16): ride the packets through the ports
c = room("N12", "port_scan", 72, 16, 1314, -2, [
    ("N12:W", "W", 7, 10, "N22:E"), ("N12:E", "E", 7, 10, "N13:W")],
    packets={"every": 4.0, "speed": 64.0, "w": 4, "lead": 32, "lag": 16},
    variants=[{"if": "boss:FIREWALL", "rect": [0, 0, 72, 16], "from": "3", "to": " "}])
c.box(top=1, bottom=5)
for px in (18, 36, 54):
    c.rect(px, 1, px, 10, "3")
c.put(2, 8, "J").put(69, 8, "|").put(28, 3, "z").put(46, 3, "z").put(6, 10, "T")
R["N12"][1]["signs"] = ["nmap -p 22,80,443 /net: the ports open for packets. Ride one, or time them on foot."]

# ------------------------------------------------------------------ N13 iptables (80x24): worms in the firewall
c = room("N13", "iptables", 80, 24, 1386, -12, [
    ("N13:W", "W", 17, 20, "N12:E"), ("N13:E", "E", 17, 20, "N14:W"), ("N13:S", "S", 34, 37, "N21:N")],
    decor=[{"kind": "window", "x": 60, "y": 13, "w": 4, "h": 3, "shadow": "firewall"}])
c.box(top=1, bottom=3)
c.rect(34, 21, 37, 21, "%").rect(34, 22, 37, 23, " ")     # the honeypot crack
c.put(20, 18, "N").put(20, 19, "W").put(20, 20, "N")      # firewall membranes, a worm inside each
c.put(50, 18, "N").put(50, 19, "W").put(50, 20, "N")
c.rect(29, 10, 31, 11, "#").put(30, 12, "e")               # spyware under a hanging block
# the ssh vista: tokens behind a 2-thick firewall, up the platforms on the right
c.put(56, 18, "=====").put(60, 15, "====").put(57, 12, "====").put(58, 9, "######")
c.rect(64, 4, 77, 4, "#").rect(64, 9, 77, 9, "#").rect(64, 5, 65, 8, "N").put(68, 8, "oooooo")
c.put(32, 20, "T").put(8, 20, "T").put(70, 20, "G")
R["N13"][1]["signs"] = ["iptables -P INPUT DROP. Red bricks: thin firewall. Something lives in them.",
                        "iptables -A INPUT --dport 31337 -j HONEYPOT  # nothing to see here"]

# ------------------------------------------------------------------ N21 honeypot (48x16): a trap; DDOS waves; rate_limit
c = room("N21", "honeypot", 48, 16, 1400, 12, [
    ("N21:N", "N", 20, 23, "N13:S", "until:wave:N21")],
    secret=True, plugins=["rate_limit"],
    wave={"flag": "wave:N21", "waves": [[[10, 6], [38, 6]], [[8, 6], [24, 4], [40, 6]], [[6, 6], [18, 4], [30, 4], [42, 6]]]})
c.box(top=1, bottom=3)
c.put(12, 10, "=====").put(16, 7, "====").put(19, 4, "======")
c.put(40, 12, "U").put(6, 12, "T")
R["N21"][1]["signs"] = ["honeypot: you were not supposed to find this. (you were.)"]

# ------------------------------------------------------------------ N14 dmz (32x16): the bench before the FIREWALL; the ssh shaft up
c = room("N14", "dmz", 32, 16, 1466, -4, [
    ("N14:W", "W", 9, 12, "N13:E"), ("N14:E", "E", 9, 12, "N15:W", "fight"), ("N14:N", "N", 24, 27, "N18:S")])
c.box(top=1, bottom=3)
c.rect(22, 0, 23, 2, "#").rect(22, 3, 23, 6, "N")          # the firewall in front of the shaft (2 thick)
c.rect(24, 0, 27, 6, " ").rect(28, 0, 30, 6, "#").rect(22, 7, 30, 7, "#")
c.put(10, 10, "====").put(14, 7, "========")
c.put(6, 12, "C").put(2, 12, "T").put(12, 12, "T")
R["N14"][1]["signs"] = ["dmz: the last bench before the firewall.", "unsent: I could use a hand"]

# ------------------------------------------------------------------ N15 FIREWALL (24x14)
c = room("N15", "FIREWALL", 24, 14, 1498, -2, [
    ("N15:W", "W", 7, 10, "N14:E", "fight"), ("N15:E", "E", 7, 10, "N16:W", "until:boss:FIREWALL")],
    boss={"id": "FIREWALL", "class": "FirewallBoss", "name": "THE FIREWALL", "sub": "deny by default", "trigger_x": 80,
          "T": 85, "u": 0.7, "reward": "ssh", "banner": "ssh",
          "banner_sub": "keep pushing into a thin red firewall: you tunnel through", "music": "boss", "drop": 40})
c.box(top=1, bottom=3)
c.put(7, 8, "N").put(7, 9, "N").put(7, 10, "N").put(16, 8, "N").put(16, 9, "N").put(16, 10, "N")
c.put(1, 8, "===").put(20, 8, "===").put(18, 10, "B")

# ------------------------------------------------------------------ N16 ssh_tunnel (40x16): ssh, thin then thick
c = room("N16", "ssh_tunnel", 40, 16, 1522, -6, [
    ("N16:W", "W", 11, 14, "N15:E"), ("N16:E", "E", 7, 10, "N17:W")])
c.box(top=1, bottom=1)
c.rect(12, 1, 12, 14, "N").rect(22, 1, 23, 14, "N")
c.rect(27, 13, 38, 14, "#").rect(30, 11, 38, 12, "#")
c.rect(39, 7, 39, 10, "N")                                 # the east door is firewall
c.put(5, 14, "T").put(16, 14, "ooo").put(32, 10, "ooo")
R["N16"][1]["signs"] = ["ssh: walk into a thin red firewall and keep pushing. 0.3 s. You are through. (2 bricks at most.)"]

# ------------------------------------------------------------------ N17 22/tcp (26x82): down to .git
c = room("N17", "22/tcp", 26, 82, 1562, -6, [
    ("N17:W", "W", 7, 10, "N16:E"), ("N17:E", "E", 33, 36, "P15:W", "until:lever:CDN"), ("N17:S", "S", 4, 7, "G01:N")],
    end="to be continued in .git")
c.box(top=1, bottom=0)
c.rect(0, 7, 0, 10, "N")                                   # this side of the ssh door is firewall too (2 bricks across the door)
c.rect(1, 11, 8, 11, "#")
c.rect(1, 81, 24, 81, "#").rect(4, 81, 7, 81, " ")         # the closed hatch to G01 in the floor
c.rect(18, 37, 24, 37, "#")                                # the ledge under the door without a handle
S = {14: (10, 15), 17: (17, 22), 20: (10, 15), 23: (3, 8), 26: (10, 15), 29: (17, 22), 32: (10, 15), 35: (3, 8),
     40: (10, 15), 43: (17, 22), 46: (10, 15), 49: (3, 8), 52: (10, 15), 55: (17, 22), 58: (10, 15), 61: (3, 8),
     64: (10, 15), 67: (17, 22), 70: (10, 15), 73: (3, 8), 76: (10, 15), 78: (17, 22)}
for row, (a, b) in S.items():
    c.put(a, row, "=" * (b - a + 1))
c.put(20, 10, "d").put(12, 45, "e").put(18, 60, "d").put(12, 69, "z")
c.put(3, 10, "T").put(14, 80, "T").put(20, 80, "D").put(21, 36, "T")
R["N17"][1]["signs"] = ["22/tcp: open. ssh all the way down to .git.", "This door has no handle. It opens from the other side.",
                        "200 OK. I missed you too."]

# ------------------------------------------------------------------ N18 token_ring (24x76): the loop behind the hub
c = room("N18", "token_ring", 24, 76, 1486, -80, [
    ("N18:W", "W", 20, 23, "N08:E"), ("N18:S", "S", 4, 7, "N14:N")],
    packets={"every": 3.0, "speed": 56.0, "w": 3, "lead": 0, "lag": 0})
c.box(top=1, bottom=0)
c.rect(1, 24, 5, 24, "#")                                  # the ledge at the door from crawl_queue
c.rect(1, 75, 22, 75, "#").rect(4, 75, 7, 75, " ")
c.put(2, 73, "========")
Q = {70: (9, 13), 67: (15, 20), 64: (9, 13), 61: (2, 6), 58: (9, 13), 55: (15, 20), 52: (9, 13), 49: (2, 6), 46: (9, 13),
     43: (15, 20), 40: (9, 13), 37: (2, 6), 34: (9, 13), 31: (15, 20), 28: (9, 13), 25: (2, 6), 21: (8, 12), 18: (14, 19)}
for row, (a, b) in Q.items():
    c.put(a, row, "=" * (b - a + 1))
c.put(1, 14, "J").put(22, 14, "|").put(1, 44, "J").put(22, 44, "|")    # two packet lanes: tokens ride in a ring
c.put(15, 17, "oooo").put(12, 50, "z").put(16, 36, "d").put(3, 72, "T")
R["N18"][1]["signs"] = ["token_ring: only the one holding the token may speak. Pass it on."]

# ------------------------------------------------------------------ N19 /backup (32x14)
c = room("N19", "/backup", 32, 14, 1400, -72, [("N19:S", "S", 10, 13, "N05:N")],
         secret=True, pages=[[5, 11, 2]])
c.box(top=1, bottom=2)
c.put(10, 12, "====").rect(10, 13, 13, 13, " ")
c.put(26, 11, "*").put(16, 11, "T")
R["N19"][1]["signs"] = ["README.md.bak (last week): keep the little orange one."]

# ------------------------------------------------------------------ N20 404 (32x14)
c = room("N20", "404", 32, 14, 1380, -38, [("N20:N", "N", 12, 15, "N05:S")],
         offmap=True, agents=[[24, 11]])
c.box(top=1, bottom=2)
c.rect(12, 0, 15, 0, " ")
c.put(6, 9, "=====").put(10, 6, "====").put(11, 3, "======").put(26, 11, "ooooo").put(4, 11, "T")
R["N20"][1]["signs"] = ["404 Not Found. This room is on no map. You are not here."]

for rid, (cv, meta) in R.items():
    open_doors(cv, meta)

# ------------------------------------------------------------------ edits to built rooms (applied by apply.py)
EDITS = {
    "H11": {"cells": [[190, 0, "         "], [194, 12, " "]],
            "doors_add": [{"id": "H11:N2", "side": "N", "a": 190, "b": 198, "to": "N11:S1", "lock": "oneway"}],
            "del": ["end"], "sign": [1, "/net: connection established. eth0 is up."]},
    "D07": {"cells": [[23, 9, " "], [23, 10, " "], [23, 11, " "], [23, 12, " "]],
            "doors_add": [{"id": "D07:E", "side": "E", "a": 9, "b": 12, "to": "N02:W"}]},
    "D06": {"cells": [[20, 12, " "]], "del": ["end"], "set": {"gate_lever": "lever:D06"}},
}


def write(out):
    os.makedirs(os.path.join(out, "rooms"), exist_ok=True)
    for rid, (cv, meta) in R.items():
        open(os.path.join(out, "rooms", rid + ".txt"), "w").write("\n".join(cv.rows()))
    json.dump({k: v[1] for k, v in R.items()}, open(os.path.join(out, "rooms-4b2.json"), "w"), indent=1, ensure_ascii=False)
    json.dump(EDITS, open(os.path.join(out, "room-edits-4b2.json"), "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    write(os.path.dirname(os.path.abspath(__file__)))
    for rid, (cv, meta) in R.items():
        print(rid, meta["size"], len(cv.rows()), set(len(r) for r in cv.rows()))
