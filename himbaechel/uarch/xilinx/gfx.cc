/*
 *  nextpnr -- Next Generation Place and Route
 *
 *  Copyright (C) 2026  VeryLogic contributors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <algorithm>
#include <utility>

#include "xilinx.h"

#define HIMBAECHEL_CONSTIDS "uarch/xilinx/constids.inc"
#include "himbaechel_constids.h"

NEXTPNR_NAMESPACE_BEGIN

namespace {

float track_position(int32_t tilewire)
{
    constexpr int tracks = 32;
    int32_t track = tilewire % tracks;
    if (track < 0)
        track += tracks;
    return 0.08f + 0.84f * (float(track) + 0.5f) / float(tracks);
}

bool is_horizontal(IdString type)
{
    return type.in(id_NODE_GLOBAL_HROUTE, id_NODE_GLOBAL_HDISTR, id_NODE_HLONG, id_NODE_HQUAD, id_HLONG, id_HQUAD,
                   id_BENTQUAD, id_DOUBLE);
}

bool is_vertical(IdString type)
{
    return type.in(id_NODE_GLOBAL_VDISTR, id_NODE_GLOBAL_VROUTE, id_NODE_VLONG, id_NODE_VQUAD, id_VLONG, id_VLONG12,
                   id_VQUAD, id_SVLONG);
}

std::pair<float, float> wire_anchor(Loc loc, IdString type, int32_t tilewire)
{
    float track = track_position(tilewire);
    if (is_horizontal(type))
        return {loc.x + 0.5f, loc.y + track};
    if (is_vertical(type))
        return {loc.x + track, loc.y + 0.5f};

    constexpr int local_columns = 8;
    int32_t slot = tilewire % 64;
    if (slot < 0)
        slot += 64;
    float x = 0.18f + 0.64f * (float(slot % local_columns) + 0.5f) / float(local_columns);
    float y = 0.18f + 0.64f * (float(slot / local_columns) + 0.5f) / float(local_columns);
    return {loc.x + x, loc.y + y};
}

} // namespace

void XilinxImpl::drawBel(std::vector<GraphicElement> &g, GraphicElement::style_t style, IdString bel_type, Loc loc)
{
    GraphicElement el;
    el.type = GraphicElement::TYPE_BOX;
    el.style = style;

    if (bel_type.in(id_SLICE_LUTX, id_SLICE_FFX, id_F7MUX, id_F8MUX, id_F9MUX, id_CARRY4, id_CARRY8)) {
        int lane = (loc.z >> 4) & 0x7;
        int function = loc.z & 0xf;
        el.y1 = loc.y + 0.08f + lane * 0.105f;
        el.y2 = el.y1 + 0.07f;
        if (function == BEL_6LUT || function == BEL_5LUT) {
            el.x1 = loc.x + 0.58f + (function == BEL_5LUT ? 0.10f : 0.0f);
            el.x2 = el.x1 + 0.09f;
        } else if (function == BEL_FF || function == BEL_FF2) {
            el.x1 = loc.x + 0.82f + (function == BEL_FF2 ? 0.05f : 0.0f);
            el.x2 = el.x1 + 0.04f;
        } else {
            el.x1 = loc.x + 0.46f;
            el.x2 = el.x1 + 0.08f;
        }
    } else {
        constexpr int columns = 5;
        int slot = std::max(loc.z, 0) % 40;
        int column = slot % columns;
        int row = slot / columns;
        el.x1 = loc.x + 0.12f + column * 0.16f;
        el.x2 = el.x1 + 0.12f;
        el.y1 = loc.y + 0.10f + row * 0.105f;
        el.y2 = el.y1 + 0.075f;
    }
    g.push_back(el);
}

void XilinxImpl::drawWire(std::vector<GraphicElement> &g, GraphicElement::style_t style, Loc loc, IdString wire_type,
                          int32_t tilewire, IdString tile_type)
{
    (void)tile_type;
    GraphicElement el;
    el.type = GraphicElement::TYPE_LINE;
    el.style = style;
    float track = track_position(tilewire);

    if (is_horizontal(wire_type)) {
        el.x1 = loc.x;
        el.x2 = loc.x + 1.0f;
        el.y1 = el.y2 = loc.y + track;
    } else if (is_vertical(wire_type)) {
        el.x1 = el.x2 = loc.x + track;
        el.y1 = loc.y;
        el.y2 = loc.y + 1.0f;
    } else {
        auto anchor = wire_anchor(loc, wire_type, tilewire);
        if ((tilewire & 1) == 0) {
            el.x1 = anchor.first - 0.035f;
            el.x2 = anchor.first + 0.035f;
            el.y1 = el.y2 = anchor.second;
        } else {
            el.x1 = el.x2 = anchor.first;
            el.y1 = anchor.second - 0.035f;
            el.y2 = anchor.second + 0.035f;
        }
    }
    g.push_back(el);
}

void XilinxImpl::drawPip(std::vector<GraphicElement> &g, GraphicElement::style_t style, Loc loc, WireId src,
                         IdString src_type, int32_t src_id, WireId dst, IdString dst_type, int32_t dst_id)
{
    (void)src;
    (void)dst;
    auto src_anchor = wire_anchor(loc, src_type, src_id);
    auto dst_anchor = wire_anchor(loc, dst_type, dst_id);
    if (src_anchor == dst_anchor)
        dst_anchor.first += 0.02f;

    GraphicElement el;
    el.type = GraphicElement::TYPE_ARROW;
    el.style = style;
    el.x1 = src_anchor.first;
    el.y1 = src_anchor.second;
    el.x2 = dst_anchor.first;
    el.y2 = dst_anchor.second;
    g.push_back(el);
}

NEXTPNR_NAMESPACE_END
