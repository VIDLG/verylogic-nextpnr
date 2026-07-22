"""Smoke test for the read-only architecture graphics Python API."""

import math


TYPE_NAMES = (
    "TYPE_NONE",
    "TYPE_LINE",
    "TYPE_ARROW",
    "TYPE_BOX",
    "TYPE_CIRCLE",
    "TYPE_LABEL",
    "TYPE_LOCAL_ARROW",
    "TYPE_LOCAL_LINE",
)

STYLE_NAMES = (
    "STYLE_GRID",
    "STYLE_FRAME",
    "STYLE_HIDDEN",
    "STYLE_INACTIVE",
    "STYLE_ACTIVE",
    "STYLE_HIGHLIGHTED0",
    "STYLE_HIGHLIGHTED1",
    "STYLE_HIGHLIGHTED2",
    "STYLE_HIGHLIGHTED3",
    "STYLE_HIGHLIGHTED4",
    "STYLE_HIGHLIGHTED5",
    "STYLE_HIGHLIGHTED6",
    "STYLE_HIGHLIGHTED7",
    "STYLE_SELECTED",
    "STYLE_HOVER",
)

for name in TYPE_NAMES:
    assert hasattr(GraphicElementType, name), name
for name in STYLE_NAMES:
    assert hasattr(GraphicElementStyle, name), name

assert ctx.getGridDimX() > 0
assert ctx.getGridDimY() > 0
assert ctx.getTileBelDimZ(0, 0) >= 0
assert ctx.getTilePipDimZ(0, 0) >= 0

bels = list(ctx.getBels())
wires = list(ctx.getWires())
pips = list(ctx.getPips())
groups = list(ctx.getGroups())

assert bels
assert wires
assert pips
assert isinstance(groups, list)
assert isinstance(list(ctx.getBelPins(bels[0])), list)

if groups:
    group_members = (
        ctx.getGroupBels(groups[0]),
        ctx.getGroupWires(groups[0]),
        ctx.getGroupPips(groups[0]),
        ctx.getGroupGroups(groups[0]),
    )
    for members in group_members:
        assert all(isinstance(name, str) for name in members)

resources = (
    (bels, ctx.getBelDecal),
    (wires, ctx.getWireDecal),
    (pips, ctx.getPipDecal),
    (groups, ctx.getGroupDecal),
)

def read_decal(decal_xy):
    assert math.isfinite(decal_xy.x)
    assert math.isfinite(decal_xy.y)

    decal = decal_xy.decal
    assert not any(hasattr(decal, field) for field in ("index", "tile", "location", "z"))

    # DecalId must be an independent value, not a reference into DecalXY.
    del decal_xy
    elements = list(ctx.getDecalGraphics(decal))
    for element in elements:
        assert element.style is not None
        assert math.isfinite(element.x1)
        assert math.isfinite(element.y1)
        assert math.isfinite(element.x2)
        assert math.isfinite(element.y2)
        assert math.isfinite(element.z)
    return elements


found_graphics = False
for names, get_decal in resources:
    if names:
        found_graphics |= bool(read_decal(get_decal(names[0])))

# Some architectures start their BEL range with invisible infrastructure BELs.
# Find a drawable BEL without assuming that every BEL has graphics.
if not found_graphics:
    for bel in bels[1:]:
        if read_decal(ctx.getBelDecal(bel)):
            found_graphics = True
            break

assert found_graphics
print(
    "graphics smoke test passed: "
    f"{len(bels)} BELs, {len(wires)} wires, {len(pips)} PIPs, {len(groups)} groups"
)
