#!/usr/bin/env python3
"""Builds the puzzle rooms and their bot test cases.

Each room is laid out in code, so distances that the puzzle depends on
(smell rings, seats, throws) can be stated and checked in one place. Running
this rewrites the puzzle rooms at the top of scripts/level_maps.gd and the
test cases in scripts/dev/puzzle_cases.gd.

    python3 tools/gen_rooms.py

Numbers the rooms rely on (keep in step with the scripts):
    tile 32 px; player runs 260 px/s and jumps 3.5 tiles high
    smell ring = 32 + 48 * pips px, halved while the dog is under orders
    stay holds 3 s / 8 s / forever and seeks a seat within 110 / 220 / 360 px
    fetch reaches 320 / 640 / 1200 px from the dog
    a thrown sandwich lands 234 px ahead on level ground
    a bramble is drawn to a sitting dog within 240 px and stops 96 px short
    a gate needs its plate at least two tiles away, or you can slip through
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H, G = 22, 14  # rows in a room, and the row of the main ground
F = G - 1      # the row things stand in


def c(col):
    """Pixel x of the centre of a column."""
    return col * 32 + 16


def ring(pips, staying=False):
    return (32 + 48 * pips) * (0.5 if staying else 1.0)


def grid(width):
    g = [["."] * width for _ in range(H)]
    fill(g, 0, width - 1, G, H - 1)
    return g


def fill(g, x0, x1, y0, y1, ch="#"):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch


def gate(g, col, ch="|", feet=F):
    """A gate, with a block above it so it cannot be jumped."""
    fill(g, col - 1, col + 1, max(0, feet - 11), feet - 3)
    g[feet][col] = ch


def hill(g, first, last, step_from=None):
    """A raised deck with a crawlspace under it that only the dog fits."""
    fill(g, first, last, 9, 12)
    if step_from is not None:
        fill(g, step_from, first - 1, 11, 12)


rooms = []
cases = []

# The commands a room introduces. They pop up as key hints when it begins,
# the first time only. There is no other text in the rooms.
KEYS = {
    "Sit. Stay.": ["move", "jump", "stay", "call_dog"],
    "Good dog": ["feed"],
    "Fetch": ["fetch"],
    "Featherweight": ["throw"],
}


def room(name, g, labels=None, hunger=1, skills=None, extra=None, solve=None, mistakes=None):
    # Lowercase letters once marked where teaching text went; rooms carry none now.
    rows = ["".join("." if ch.islower() else ch for ch in r) for r in g]
    rooms.append({
        "name": name, "keys": KEYS.get(name, []), "map": "\n".join(rows),
        "hunger": hunger, "skills": skills or {}, "extra": extra or {},
    })
    if solve:
        cases.append({"room": name, "what": "solution", "expect": "finish", "steps": solve})
    for what, expect, steps in mistakes or []:
        cases.append({"room": name, "what": what, "expect": expect, "steps": steps})


# ---------------------------------------------------------------- teaching rooms

# 1. Hold the door for each other.
g = grid(34)
g[F][3], g[F][5] = "P", "D"
g[F][10] = "="
gate(g, 16)
g[F][21] = "="
g[F][28] = ">"
g[8][2], g[9][2] = "a", "b"
room("Sit. Stay.", g,
     {"a": "S: stay. On a plate, it holds the gate for as long as the ring lasts.",
      "b": "E: come. You leave together or not at all, so hold the door for each other."},
     solve=[["right", c(11.5)], ["until", "dog_near"], ["press", "stay"], ["until", "plateA"],
            ["right", c(21) - 8], ["press", "call_dog"], ["until", "dog_near"], ["right", c(28)]])

# 2. A stay only lasts as long as it has been practised.
g = grid(56)
g[F][3], g[F][4] = "P", "D"
g[F][6] = "="
g[F][10] = "*"
gate(g, 42)
g[F][46] = "="
g[F][52] = ">"
g[8][2], g[9][2] = "a", "b"
room("Good dog", g,
     {"a": "Three seconds will not get you to that gate.",
      "b": "T: a biscuit, straight after a trick, teaches it."},
     solve=[["right", c(10.5)], ["left", c(7.6)], ["until", "dog_near"], ["press", "stay"], ["until", "plateA"],
            ["press", "feed"], ["wait", 0.3], ["right", c(46) - 8], ["press", "call_dog"],
            ["until", "dog_near"], ["right", c(52)]],
     mistakes=[["no biscuit", "stuck",
                [["left", c(7.6)], ["until", "dog_near"], ["press", "stay"], ["until", "plateA"], ["right", c(46)]]]])

# 3. Fetch, through a gap only the dog fits.
g = grid(40)
g[F][2] = ">"
gate(g, 6, "&")
g[F][12], g[F][14] = "P", "D"
fill(g, 22, 26, 3, 12)
g[F][28] = "$"
fill(g, 33, 39, 3, 13)
g[8][9], g[9][9] = "a", "b"
room("Fetch", g,
     {"a": "G: fetch. It has to be near enough, and able to walk there.",
      "b": "It fits where you do not."},
     solve=[["right", 690], ["until", "dog_near"], ["press", "fetch"], ["until", "has_key"], ["left", c(2)]])

# 4. Planks hold the dog; a thrown sandwich sends it across.
g = grid(36)
g[F][1] = ">"
g[F][3] = "="
gate(g, 7)
g[F][11], g[F][12] = "P", "D"
g[F][14] = "+"
fill(g, 18, 25, G, H - 1, ".")
fill(g, 18, 25, G, G, "~")
g[F][27] = "="
fill(g, 32, 35, 3, 13)
g[8][9], g[9][9] = "a", "b"
room("Featherweight", g,
     {"a": "Rotten planks carry a dog. They will not carry you.",
      "b": "Hold H to aim a sandwich. Let go, and the dog goes where it lands."},
     solve=[["right", 560], ["wait", 0.3], ["press", "throw"], ["until", "dog_ate"], ["press", "stay"],
            ["until", "plateA"], ["left", c(3) + 8], ["press", "call_dog"], ["until", "dog_near"], ["left", c(1)]])

# 5. A hungry dog and food in a pit. The plate is 96 px from the food:
#    inside the ring of a hungry dog even under orders, outside it once fed.
food, plate = c(23), c(20)
assert ring(4, True) >= food - plate > ring(1), "Temptation: feeding must be both needed and enough"
g = grid(30)
g[F][1] = ">"
g[F][3] = "="
gate(g, 7)
g[F][11], g[F][12] = "P", "D"
g[F][13] = "+"
g[F][20] = "="
fill(g, 22, 24, G, 18, ".")
g[18][23] = "%"
fill(g, 25, 29, 3, 13)
g[7][9], g[8][9], g[9][9] = "a", "b", "c"
room("Temptation", g,
     {"a": "The ring is how far the smell reaches. It grows with hunger.",
      "b": "Inside it no order holds, and that pit is too deep to climb out of.",
      "c": "Eating takes three pips off."},
     hunger=3,
     solve=[["right", 430], ["wait", 0.3], ["press", "throw"], ["until", "dog_ate"], ["press", "stay"],
            ["until", "plateA"], ["left", c(3) + 8], ["press", "call_dog"], ["until", "dog_near"], ["left", c(1)]],
     mistakes=[["walk it over unfed", "dog_trapped", [["right", c(20)], ["wait", 3.0]]]])

# 6. A squirrel on the deck drives the dog along the crawlspace below.
g = grid(44)
hill(g, 12, 34, step_from=9)
g[F][3], g[F][5] = "P", "D"
g[F][9] = "^"
g[8][17] = "S"
gate(g, 32, "|", feet=8)
g[F][33] = "="
g[F][41] = ">"
g[5][2], g[6][2] = "a", "b"
room("Squirrel!", g,
     {"a": "No dog can ignore a squirrel, and a squirrel runs from whoever startles it.",
      "b": "The dog only has to hear it."},
     skills={"stay": 2},
     solve=[["right", 250], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"],
            ["rightj", c(13.5)], ["right", c(30)], ["until", "dog_chased"], ["press", "stay"], ["until", "plateA"],
            ["right", c(37)], ["wait", 0.5], ["press", "call_dog"], ["until", "dog_near"], ["right", c(41)]],
     mistakes=[["take the dog up too", "stuck",
                [["rightj", c(13.5)], ["right", c(30)], ["wait", 4.0], ["press", "stay"], ["right", c(41)]]]])

# 7. A sitting dog draws a bramble to it.
g = grid(54)
fill(g, 12, 44, 4, 11)
g[F][3], g[F][5] = "P", "D"
g[F][22] = "^"
g[F][28] = "E"
g[F][50] = ">"
g[12][2], g[11][2] = "b", "a"
room("Hold its eye", g,
     {"a": "A bramble is drawn to a sitting dog and cannot look away.",
      "b": "One touch from a bramble and the room starts again."},
     skills={"stay": 3},
     solve=[["right", 500], ["until", "dog_near"], ["press", "stay"], ["until", "held"], ["right", 1430],
            ["press", "call_dog"], ["until", "dog_near"], ["right", c(50)]])

# ---------------------------------------------------------------------- puzzles

# 8. Dead weight. Only the bramble can hold the stone plate, and it stops three
#    tiles short of wherever the dog sits: on the plate, if the dog is on the
#    mat beyond the gate.
home, stone, mat = c(15), c(28), c(31)
assert mat - stone == 96, "Dead weight: the bramble must stop on the stone plate"
assert stone - home <= 440, "Dead weight: the plate must be within the bramble's leash"
assert mat - (home + 96) > 240, "Dead weight: the bramble must not wander over by itself"
g = grid(40)
g[F][15] = "E"
g[F][24], g[F][25] = "P", "D"
g[F][28] = "_"
gate(g, 30, ":")
g[F][31] = "^"
g[F][36] = ">"
g[8][19] = "a"
room("Dead weight", g,
     {"a": "The stone plate needs real weight. The dog is far too light."},
     skills={"stay": 3},
     solve=[["right", stone - 6], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"],
            ["left", 700], ["until", "hunting"], ["right", c(29.3)], ["until", "plateB"],
            ["right", c(34)], ["press", "call_dog"], ["until", "dog_near"], ["right", c(36)]],
     mistakes=[["stand on it yourself", "stuck",
                [["right", stone - 6], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"],
                 ["right", c(34)]]]])

# 9. Good appetite. No order reaches the plate in the crawlspace. The food
#    on the way is out of reach of the smell ring until the dog has been
#    given two orders; then, released, it goes by itself.
mat, food, plate = c(7), c(13), c(18)
assert ring(3) < food - mat <= ring(4), "Good appetite: four pips to be pulled from the mat"
assert ring(4, True) < food - mat, "Good appetite: it must hold while still under orders"
assert plate - food <= 220 < plate - mat, "Good appetite: the plate is in reach only from the food"
g = grid(46)
hill(g, 12, 36, step_from=9)
g[F][3], g[F][5] = "P", "D"
g[F][7] = "^"
g[F][13] = "%"
g[F][18] = "="
gate(g, 22, "|", feet=8)
g[F][42] = ">"
g[5][2] = "a"
room("Good appetite", g,
     {"a": "Every order makes it a little hungrier."},
     hunger=2, skills={"stay": 2},
     solve=[["right", 250], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"], ["press", "stay"],
            ["wait", 0.3], ["press", "stay"], ["until", "dog_seated"], ["rightj", c(13.5)], ["right", c(20.5)],
            ["press", "stay"], ["until", "dog_ate"], ["press", "stay"], ["until", "plateA"],
            ["right", c(38.5)], ["wait", 0.5], ["press", "call_dog"], ["until", "dog_near"], ["right", c(42)]],
     mistakes=[["one order only", "stuck",
                [["right", 250], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"],
                 ["rightj", c(13.5)], ["right", c(20.5)], ["press", "stay"], ["wait", 3.0], ["press", "stay"],
                 ["wait", 2.0], ["right", c(42)]]]])

# 10. Just hungry enough. Fetching makes the dog hungry enough for the pit
#     beside the key to take it. The only way to feed it is the food in the
#     other burrow, and it will only go for that when it is hungrier still.
mat, snack, key, pit = c(13), c(7), c(24), c(29)
assert ring(3) < mat - snack <= ring(4), "Just hungry enough: four pips to go for the snack"
assert ring(2) < pit - key - 10 and pit - key + 10 < ring(3), "Just hungry enough: safe at two pips, lost at three"
assert pit - c(17) > ring(5), "Just hungry enough: the pit must never pull from the start"
g = grid(40)
fill(g, 0, 12, 3, 12)
fill(g, 0, 4, 13, 13)
g[F][7] = "%"
g[F][13] = "^"
g[F][16], g[F][17] = "P", "D"
fill(g, 20, 37, 11, 12)
fill(g, 31, 37, 13, 13)
g[F][24] = "$"
fill(g, 28, 30, G, 18, ".")
g[18][29] = "%"
gate(g, 26, "&", feet=10)
g[10][33] = ">"
g[8][14] = "a"
room("Just hungry enough", g,
     {"a": "Watch the rings before you give an order."},
     hunger=2,
     solve=[["left", c(13.5)], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"], ["press", "stay"],
            ["wait", 0.3], ["press", "stay"], ["until", "dog_seated"], ["press", "stay"], ["until", "dog_ate"],
            ["right", c(17)], ["until", "dog_near"], ["press", "fetch"], ["until", "has_key"],
            ["rightj", c(30)], ["until", "dog_near"], ["right", c(33)]],
     mistakes=[["fetch straight away", "dog_trapped", [["wait", 0.5], ["press", "fetch"], ["wait", 4.0]]],
               ["one order too many", "dog_trapped",
                [["press", "stay"], ["until", "dog_seated"], ["press", "stay"], ["wait", 0.3],
                 ["press", "stay"], ["until", "dog_seated"], ["press", "stay"], ["wait", 0.3],
                 ["press", "stay"], ["until", "dog_seated"], ["press", "stay"], ["wait", 0.3],
                 ["left", c(13.5)], ["until", "dog_ate"], ["right", c(17)], ["until", "dog_near"],
                 ["press", "fetch"], ["wait", 4.0]]]])

# 11. A better offer. The dog can only hold the plate beside the pit while it
#     is under orders. Calling it off is the end of it; a sandwich thrown
#     through the gate you are holding open is not.
pit, plate = c(2), c(7)
assert ring(4, True) < plate - pit <= ring(4), "A better offer: safe sitting, lost standing"
assert ring(1) < plate - pit, "A better offer: safe once it has eaten"
g = grid(34)
fill(g, 0, 0, 3, 13)
fill(g, 1, 3, G, 18, ".")
g[18][2] = "%"
g[F][7] = "="
g[F][12], g[F][13] = "D", "P"
gate(g, 16)
g[F][19] = "+"
g[F][25] = "="
g[F][30] = ">"
g[8][9] = "a"
room("A better offer", g,
     {"a": "Under orders, it can resist what it otherwise could not."},
     hunger=3, skills={"stay": 3},
     solve=[["press", "stay"], ["until", "plateA"], ["right", c(25) - 8], ["press", "move_left"], ["press", "throw"],
            ["until", "dog_ate"], ["until", "dog_near"], ["right", c(30)]],
     mistakes=[["call it off the plate", "dog_trapped",
                [["press", "stay"], ["until", "plateA"], ["right", c(25) - 8], ["press", "call_dog"], ["wait", 4.0]]]])

# 12. Under the hill. Everything at once: seat the dog in the mouth of the
#     burrow, startle the squirrel so the dog runs the length of it past the
#     bramble, sit it on the far mat so the bramble stops on the stone plate,
#     then have it fetch the key on its way out.
bramble, stone, mat, key = c(25), c(28), c(31), c(36)
assert mat - stone == 96 and mat - bramble < 240, "Under the hill: the bramble must come and stop on the plate"
assert key - mat <= 320, "Under the hill: the key must be in reach from the mat"
g = grid(54)
hill(g, 12, 40, step_from=9)
g[F][3], g[F][5] = "P", "D"
g[F][9] = "^"
g[8][17] = "S"
g[F][25] = "E"
g[F][28] = "_"
g[F][31] = "^"
g[F][36] = "$"
gate(g, 34, ":", feet=8)
gate(g, 46, "&")
g[F][50] = ">"
g[5][2] = "a"
room("Under the hill", g,
     {"a": "You know all of it now."},
     hunger=1, skills={"stay": 2}, extra={"patrol": 0},
     solve=[["right", 250], ["until", "dog_near"], ["press", "stay"], ["until", "dog_seated"],
            ["rightj", c(13.5)], ["right", 1070], ["until", "dog_chased"], ["press", "stay"], ["until", "plateB"],
            ["right", c(42)], ["wait", 0.5], ["press", "fetch"], ["until", "has_key"], ["right", c(50)]])


# ------------------------------------------------------------------- write out

def entry(r):
    out = '\t{\n\t\t"name": "%s",\n\t\t"theme": "gloam",\n\t\t"puzzle": true,\n\t\t"hunger": %d,\n' % (r["name"], r["hunger"])
    if r["skills"]:
        out += '\t\t"skills": %s,\n' % json.dumps(r["skills"])
    for key, value in r["extra"].items():
        out += '\t\t"%s": %s,\n' % (key, json.dumps(value))
    if r["keys"]:
        out += '\t\t"keys": %s,\n' % json.dumps(r["keys"])
    return out + '\t\t"map": """\n%s\n""",\n\t},\n' % r["map"]


path = os.path.join(ROOT, "scripts", "level_maps.gd")
text = open(path).read()
start = text.index("const LEVELS := [\n")
end = text.index('\t{\n\t\t"name": "Movement gym"')
text = text[:start] + "const LEVELS := [\n" + "".join(entry(r) for r in rooms) + text[end:]
open(path, "w").write(text)

lines = ["class_name PuzzleCases",
         "## Generated by tools/gen_rooms.py. Bot runs that prove each puzzle room can be",
         "## finished, and that the tempting mistakes really do fail.",
         "", "const CASES := ["]
for case in cases:
    lines.append("\t" + json.dumps(case) + ",")
lines.append("]")
open(os.path.join(ROOT, "scripts", "dev", "puzzle_cases.gd"), "w").write("\n".join(lines) + "\n")
print("%d rooms, %d test cases" % (len(rooms), len(cases)))
