# figure_labels.jl -- every text label in a lecture figure clears the plotted lines.
#
# THE RULE (docs/figure-conventions.md Sec. 5, "Adjacent, never overlapping"): a label
# touches neither its own feature's linework, nor another element, nor a marker. Until
# this file, NOTHING MEASURED IT, and the figure conventions call it "the single most-
# iterated property".
#
# HIS WORDS (instructor, 2026-10-03, verdict 3-tran-3 #41, on 3.3's fig-charge-range):
#   "The minimum charge label intersects one of the curves. Can you please reposition
#    it? Label intersection with lines should be something that's checked
#    automatically, so there should be a rule or reg for this."
# It was the second time in one lecture: entry 18 was 3.3's fig-sawtooth, whose q peak
# labels were cut by the blue lines until they were moved by hand.
#
# WHY IT MEASURES THE DRAWN FIGURE, AND NOT THE SOURCE. Whether a label clears a curve
# is a fact about pixels: the label's glyphs at their fontsize, rotation, alignment and
# offset, against the curve projected through the axis limits the layout settled on. No
# reading of the `.qmd` can see it. Makie computes every one of those quantities to draw
# the figure, so the check asks Makie (0.24, pinned by Manifest.toml) for them, after
# the figure is drawn, in the figure's own pixel space:
#   * a label is its INK, not its layout box: the union of each glyph's ink rectangle
#     per text line, as an oriented box rotated with the text, plus a LaTeX label's
#     fraction bars. Per line, because a curve through the empty corner of a two-line
#     label's union box ("Allocated\ntruckload") touches nothing; oriented, because a
#     label set parallel to a curve has an axis-aligned box that the curve crosses.
#   * an obstacle is every VISIBLE stroke in the axis -- a Lines or LineSegments
#     segment as a capsule of its own linewidth (hlines, vlines, poly outlines, brackets,
#     a map's state borders included), a Scatter marker as the outline Makie actually
#     draws (its path, which for :circle is 0.705 of markersize across, not the
#     markersize square), an arrow's triangles, a visible axis spine -- and every other
#     label. Fills (poly, band, bar) and gridlines are not obstacles: a label inside a
#     shaded region is a placement, and a gridline under a label is the axis. On a map,
#     a stroke fainter than FAINT_ALPHA is the muted base (the road background) and is
#     filed apart, under "faint", without failing.
#   * a label ENCLOSED by an opaque marker (a node number inside its node) is inside
#     it, not across it, and a stroke passing under that marker is hidden by it.
#   * every 2-D axis is measured, an `Axis` or a GeoMakie `GeoAxis` (Logjam's
#     `makemap`); a 3-D axis is listed as skipped, never silently passed.
# A label FAILS when its ink comes within CLEAR_PX of an obstacle's edge.
#
# HOW IT RUNS, AND WHY NOT BY RE-EXECUTING THE LECTURE. Including this file installs a
# display hook: when Quarto's Julia engine shows a figure, the hook lets Makie draw it,
# then measures that same figure object and files the result under
# `.quarto/figure-labels/<stem>.json`, keyed by the chunk's `fig-` label and the
# lecture's sha256. The render already executes every figure (`freeze: false`), so the
# measurement costs about what drawing the PNG does (34 ms against 30 ms, measured on an
# 8,000-point line with 80 markers and 12 labels, once compiled) and measures exactly
# what the page shows. Verified
# 2026-10-03 under QuartoNotebookRunner 0.17.3, the runner Quarto pins: it evaluates
# every chunk and every display in one stable task, whose `:SOURCE_PATH` it sets to the
# `.qmd` (refresh.jl), and hands the chunk's options to `show` in the IOContext key
# `:QuartoNotebookRunner` -- which is how the hook knows the lecture and the label.
# `tools/check_figure_labels.py` reads those files; `tools/figure_labels_sweep.jl`
# executes a lecture's chunks outside a render through the SAME hook, for the self-test
# and for a lecture with no fresh render behind it.
#
# INCLUDED FROM A HIDDEN, `# qmd_to_jl: skip` CHUNK, AND IN THE `joinpath` FORM:
#     include(joinpath(@__DIR__, "..", "_common", "julia", "figure_labels.jl"))
# The literal `include("../_common/...")` form would be hoisted by tools/qmd_to_jl.py
# into the student companion script, and this file does not ship to students
# (tools/publish_scripts.py ships apparatus.jl only), so that script would fail.
#
# MEASURED 2026-10-03: see tools/check_figure_labels.py's docstring for the corpus run,
# the planted controls, and the real MC case from git history.

module FigureLabels

import CairoMakie
const Makie = CairoMakie.Makie

# A label's ink must stay at least this far, in figure units (CSS px), from the edge of
# any stroke, marker or other label. One pixel of daylight: closer than that the two
# antialiased edges merge on the page and the label reads as touching. Override for a
# threshold study with ENV["FIGLABELS_CLEAR"].
const CLEAR_PX = 1.0
# Pairs closer than this but not failing are filed as near misses, for calibration.
const NEAR_PX = 4.0
# ON A MAP, a stroke drawn fainter than this is the MUTED BASE a label sits over (Sec. 2,
# the accurate base under the stylized overlay; Sec. 3, "muted base, saturated
# features"): makemap's interstate-road background is alpha 0.2 and crosses 8 of the 10
# city labels on 2.2's map. Its contacts are filed under "faint", counted, and do not
# fail. ONLY ON A MAP: on a plot there is no base register, so a faint stroke is still a
# feature the author drew -- 3.2's dashed scale-break line visibly crosses its "qI"
# label at alpha below this, and that is a finding.
const FAINT_ALPHA = 0.35

const P2 = NTuple{2,Float64}

clear_px() = something(tryparse(Float64, get(ENV, "FIGLABELS_CLEAR", "")), CLEAR_PX)

struct LabelBox
    text::String          # this line of the label
    whole::String         # the whole label string
    plot::Int             # draw-order index of its Text plot
    block::Int            # string index inside that Text plot
    anchor::String        # the label's anchor in data coordinates, for the report
    poly::Vector{P2}      # oriented ink box, scene pixel coordinates, 4 corners
end

struct Obstacle
    kind::Symbol          # :line, :faint (a map's muted base), :marker, :arrow, :spine
    poly::Vector{P2}      # 2 vertices (a segment), 3 (an arrow triangle), or a marker's
                          # drawn outline as a convex polygon
    pad::Float64          # half the linewidth, or half a marker's stroke
    plot::Int             # draw-order index, for occlusion
    group::Int            # the top-level plot it belongs to, so one arrow is one finding
    who::String           # what it is, for the report
end

struct Occluder           # an opaque marker that hides whatever was drawn before it
    poly::Vector{P2}      # its outline as a convex polygon (a disc as a 32-gon inside it)
    plot::Int
    id::Int               # the marker obstacle it is, so a label is not enclosed by another
end

# ----------------------------------------------------------------------------------
# geometry
# ----------------------------------------------------------------------------------

_dot(a, b) = a[1] * b[1] + a[2] * b[2]

function _segdist(p::P2, a::P2, b::P2)
    d = (b[1] - a[1], b[2] - a[2])
    L = _dot(d, d)
    t = L == 0 ? 0.0 : clamp(((p[1] - a[1]) * d[1] + (p[2] - a[2]) * d[2]) / L, 0, 1)
    q = (a[1] + t * d[1], a[2] + t * d[2])
    return hypot(p[1] - q[1], p[2] - q[2])
end

_edges(P) = length(P) == 1 ? [(P[1], P[1])] :
            length(P) == 2 ? [(P[1], P[2])] :
            [(P[i], P[mod1(i + 1, length(P))]) for i in eachindex(P)]

# Separating-axis test for two convex polygons (a segment and a point are degenerate
# convex polygons; the box contributes the axes a point needs).
function _intersects(P, Q)
    for poly in (P, Q), (a, b) in _edges(poly)
        ax = (-(b[2] - a[2]), b[1] - a[1])
        (ax[1] == 0 && ax[2] == 0) && continue
        pmin, pmax = extrema(_dot(p, ax) for p in P)
        qmin, qmax = extrema(_dot(q, ax) for q in Q)
        (pmax < qmin || qmax < pmin) && return false
    end
    return true
end

"Distance between two convex polygons; 0 when they intersect."
function convex_distance(P, Q)
    _intersects(P, Q) && return 0.0
    d = Inf
    for (A, B) in ((P, Q), (Q, P)), p in A, (a, b) in _edges(B)
        d = min(d, _segdist(p, a, b))
    end
    return d
end

function _foot(p::P2, a::P2, b::P2)
    d = (b[1] - a[1], b[2] - a[2])
    L = _dot(d, d)
    t = L == 0 ? 0.0 : clamp(((p[1] - a[1]) * d[1] + (p[2] - a[2]) * d[2]) / L, 0, 1)
    return (a[1] + t * d[1], a[2] + t * d[2])
end

# The point of obstacle Q nearest label P, for the report's "at" coordinate: where the
# two touch, or, when they cross, where Q passes nearest the label's centre.
function _closest_point(P, Q)
    if _intersects(P, Q)
        c = (sum(first, P) / length(P), sum(last, P) / length(P))
        length(Q) == 1 && return Q[1]
        return argmin(q -> hypot(q[1] - c[1], q[2] - c[2]), [_foot(c, a, b) for (a, b) in _edges(Q)])
    end
    best, at = Inf, Q[1]
    for q in Q, (a, b) in _edges(P)                 # a vertex of Q against P's edges
        d = _segdist(q, a, b)
        d < best && ((best, at) = (d, q))
    end
    for p in P, (a, b) in _edges(Q)                 # P's corners against Q's edges
        f = _foot(p, a, b)
        d = hypot(p[1] - f[1], p[2] - f[2])
        d < best && ((best, at) = (d, f))
    end
    return at
end

_bbox(P) = (minimum(first.(P)), maximum(first.(P)), minimum(last.(P)), maximum(last.(P)))
_far(A, B, m) = A[2] + m < B[1] || B[2] + m < A[1] || A[4] + m < B[3] || B[4] + m < A[3]

_cross(o, a, b) = (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])

"Convex hull, counter-clockwise (Andrew's monotone chain)."
function _hull(pts::Vector{P2})
    ps = sort(unique(pts))
    length(ps) <= 2 && return ps
    lower, upper = P2[], P2[]
    for p in ps
        while length(lower) >= 2 && _cross(lower[end - 1], lower[end], p) <= 0
            pop!(lower)
        end
        push!(lower, p)
    end
    for p in reverse(ps)
        while length(upper) >= 2 && _cross(upper[end - 1], upper[end], p) <= 0
            pop!(upper)
        end
        push!(upper, p)
    end
    return vcat(lower[1:(end - 1)], upper[1:(end - 1)])
end

"Is every vertex of P inside the convex polygon Q, at least m from its edges?"
function _inside(P, Q, m)
    length(Q) < 3 && return false
    for p in P
        all(_cross(a, b, p) >= 0 for (a, b) in _edges(Q)) || return false
        minimum(_segdist(p, a, b) for (a, b) in _edges(Q)) >= m || return false
    end
    return true
end

_ngon(c::P2, r, n = 32) = P2[(c[1] + r * cos(2pi * k / n), c[2] + r * sin(2pi * k / n))
                             for k in 0:(n - 1)]

# Liang-Barsky: clip a segment to the axis viewport, since nothing outside it is drawn.
function _clip(a::P2, b::P2, w, h)
    t0, t1 = 0.0, 1.0
    dx, dy = b[1] - a[1], b[2] - a[2]
    for (p, q) in ((-dx, a[1]), (dx, w - a[1]), (-dy, a[2]), (dy, h - a[2]))
        if p == 0
            q < 0 && return nothing
        else
            r = q / p
            if p < 0
                r > t1 && return nothing
                t0 = max(t0, r)
            else
                r < t0 && return nothing
                t1 = min(t1, r)
            end
        end
    end
    return ((a[1] + t0 * dx, a[2] + t0 * dy), (a[1] + t1 * dx, a[2] + t1 * dy))
end

# ----------------------------------------------------------------------------------
# reading the figure
# ----------------------------------------------------------------------------------

_attr(p, k, default = nothing) = haskey(p.attributes, k) ? getproperty(p, k)[] : default
_name(p) = string(Makie.plotsym(typeof(p)))

function _px(p)
    k = :figlabels_px
    haskey(p.attributes, k) ||
        Makie.register_projected_positions!(p; output_space = :pixel, output_name = k)
    return getproperty(p, k)[]
end

function _color(c)
    try
        col = Makie.to_color(c)
        return col isa Makie.Colors.Colorant ? col : nothing
    catch
        return nothing
    end
end
_alpha(c) = c === nothing ? 1.0 : Float64(Makie.Colors.alpha(c))
_hex(c) = c === nothing ? "varied colour" : "#" * lowercase(Makie.Colors.hex(Makie.Colors.RGB(c)))

# The opacity a stroke is drawn at: its colour's alpha times the plot's `alpha`.
function _opacity(p)
    _attr(p, :visible, true) || return 0.0
    a = _attr(p, :alpha, 1.0)
    return (a isa Real ? Float64(a) : 1.0) * _alpha(_color(_attr(p, :color)))
end
_visible_stroke(p) = _opacity(p) > 0

_lw(lw, i) = Float64(lw isa AbstractVector ? lw[min(i, length(lw))] : lw)

function _describe(top, p, lw)
    c = _color(_attr(p, :color))
    ls = _attr(p, :linestyle)
    st = ls === nothing ? "solid" : ls isa AbstractVector ? "dashed" : string(ls)
    kind = top == _name(p) ? top : "$top/$(_name(p))"
    return "$kind ($(_hex(c)), $st, $(round(lw, digits = 2)) px)"
end

function _anchor(t, b)
    try
        pos = t[1][]
        x = pos isa AbstractVector ? pos[b] : pos
        return "(" * join(string.(round.(Float64.(collect(x)[1:2]), sigdigits = 5)), ", ") * ")"
    catch
        return "?"
    end
end

function _string(x)
    x isa AbstractString && return String(x)
    return string(x)
end

# The oriented ink boxes of one Text plot, one per text line of each string.
function _labels!(out, t, scene, idx)
    _attr(t, :visible, true) || return
    blocks = t.text_blocks[]
    origins, exts = t.glyph_origins[], t.glyph_extents[]
    scales, rots, gidx = t.text_scales[], t.text_rotation[], t.glyphindices[]
    anchors = Makie.register_markerspace_positions!(t)[]
    offs = t.offset[]
    texts = t.input_text[]
    segs, lws, lidx = t.linesegments[], t.linewidths[], t.lineindices[]
    ms = t.markerspace[]
    for (b, r) in enumerate(blocks)
        isempty(r) && continue
        anchor = anchors[b]
        any(isnan, anchor) && continue                  # clipped away
        off = Makie.sv_getindex(offs, b)
        q = rots[first(r)]
        ex, ey = q * Makie.Vec3f(1, 0, 0), q * Makie.Vec3f(0, 1, 0)
        un(v) = (Float64(v[1] * ex[1] + v[2] * ex[2]), Float64(v[1] * ey[1] + v[2] * ey[2]))
        str = texts isa AbstractVector ? texts[b] : texts
        latex = str isa Makie.LaTeXString
        rects = NTuple{5,Float64}[]                       # x0, x1, y0, y1, baseline
        fs = 0.0
        for i in r
            gidx[i] == 0 && continue
            ink = exts[i].ink_bounding_box
            o, w = Makie.origin(ink), Makie.widths(ink)
            (w[1] <= 0 || w[2] <= 0) && continue
            s = scales[i]
            fs = max(fs, Float64(s[2]))
            u = un(origins[i])
            push!(rects, (u[1] + o[1] * s[1], u[1] + (o[1] + w[1]) * s[1],
                          u[2] + o[2] * s[2], u[2] + (o[2] + w[2]) * s[2], u[2]))
        end
        for k in 1:2:length(segs)                        # a LaTeX label's rules
            first(lidx[k]) == b || continue
            h = Float64(lws[k]) / 2
            p0, p1 = un(segs[k] .- off), un(segs[k + 1] .- off)
            push!(rects, (min(p0[1], p1[1]), max(p0[1], p1[1]),
                          min(p0[2], p1[2]) - h, max(p0[2], p1[2]) + h, p0[2]))
        end
        isempty(rects) && continue
        # Group into text lines by baseline: one group for LaTeX, whose numerator and
        # denominator are one visual unit; otherwise baselines within half a font size.
        groups = Vector{Vector{NTuple{5,Float64}}}()
        if latex
            push!(groups, rects)
        else
            for rc in sort(rects; by = x -> -x[5])
                if !isempty(groups) && abs(groups[end][1][5] - rc[5]) < 0.5 * max(fs, 1)
                    push!(groups[end], rc)
                else
                    push!(groups, [rc])
                end
            end
        end
        whole = _string(str)
        lines = split(whole, '\n')
        for (gi, g) in enumerate(groups)
            x0, x1 = minimum(x[1] for x in g), maximum(x[2] for x in g)
            y0, y1 = minimum(x[3] for x in g), maximum(x[4] for x in g)
            poly = P2[]
            for (lx, ly) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))
                P = Makie.Point3f(anchor[1] + off[1] + lx * ex[1] + ly * ey[1],
                                  anchor[2] + off[2] + lx * ex[2] + ly * ey[2], 0)
                if ms !== :pixel
                    P = Makie.project(scene, ms, :pixel, P)
                end
                push!(poly, (Float64(P[1]), Float64(P[2])))
            end
            line = (!latex && length(lines) == length(groups)) ? String(lines[gi]) : whole
            push!(out, LabelBox(line, whole, idx, b, _anchor(t, b), poly))
        end
    end
end

function _strokes!(out, p, top, idx, group, w, h; kind = :line)
    _visible_stroke(p) || return
    pts = _px(p)
    lw = _attr(p, :linewidth, 1.0)
    step = p isa Makie.LineSegments ? 2 : 1
    for i in 1:step:(length(pts) - 1)
        a, b = pts[i], pts[i + 1]
        (any(isnan, a) || any(isnan, b)) && continue
        hw = max(_lw(lw, i), _lw(lw, i + 1)) / 2
        hw <= 0 && continue
        seg = _clip((Float64(a[1]), Float64(a[2])), (Float64(b[1]), Float64(b[2])), w, h)
        seg === nothing && continue
        push!(out, Obstacle(kind, [seg[1], seg[2]], hw, idx, group,
                            _describe(top, p, 2hw)))
    end
end

# A marker's outline in Makie's unit marker square, which markersize scales. The
# symbol markers are BezierPaths, and NOT the full square: measured 2026-10-03,
# markersize 40 draws :circle 28 px across (radius 0.3525, from the path) and centres
# a triangle on its centroid, 4 px off the point. So the path is read, never assumed.
function _marker_shape(m, font = "default")
    if m isa Makie.BezierPath
        pts = P2[]
        for c in m.commands
            if c isa Makie.MoveTo || c isa Makie.LineTo
                push!(pts, (Float64(c.p[1]), Float64(c.p[2])))
            elseif c isa Makie.CurveTo
                for q in (c.c1, c.c2, c.p)          # the hull of a Bezier holds it
                    push!(pts, (Float64(q[1]), Float64(q[2])))
                end
            elseif c isa Makie.EllipticalArc
                for k in 0:31
                    t = 2pi * k / 32
                    x, y = c.r1 * cos(t), c.r2 * sin(t)
                    push!(pts, (c.c[1] + x * cos(c.angle) - y * sin(c.angle),
                                c.c[2] + x * sin(c.angle) + y * cos(c.angle)))
                end
            end
        end
        return _hull(pts)
    elseif m isa Makie.Rect || (m isa Type && m <: Makie.Rect)
        return P2[(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]
    elseif m isa Char
        # A character marker is its glyph's INK, centred on the point at fontsize =
        # markersize (CairoMakie's draw_marker). 2.7's transmitter map marks every
        # county with '.' at markersize 24: a 3 px dot, not a 24 px disc.
        try
            f = font isa Makie.FreeTypeAbstraction.FTFont ? font :
                Makie.to_font(font isa AbstractString ? font : "default")
            ink = Makie.FreeTypeAbstraction.inkboundingbox(
                      Makie.FreeTypeAbstraction.get_extent(f, m))
            w, h = Float64.(Makie.widths(ink))
            return P2[(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        catch
        end
    end
    return _ngon((0.0, 0.0), 0.5)                    # Circle, an image, or unknown
end

function _angle(r)
    r isa Real && return Float64(r)
    if r isa Makie.Quaternion
        v = r * Makie.Vec3f(1, 0, 0)
        return Float64(atan(v[2], v[1]))
    end
    return 0.0                                       # Billboard: upright on screen
end

function _markers!(out, occ, p, top, idx, group, w, h)
    _attr(p, :visible, true) || return
    pts = _px(p)
    ms = _attr(p, :markersize, 9.0)
    mk = _attr(p, :marker)
    font = _attr(p, :font, "default")
    rot = _attr(p, :rotation, 0.0)
    sw = Float64(_attr(p, :strokewidth, 0.0))
    fill = _color(_attr(p, :color))
    stroke = _color(_attr(p, :strokecolor))
    pad = sw > 0 && _alpha(stroke) > 0 ? sw / 2 : 0.0
    shapes = Dict{Any,Vector{P2}}()
    for (i, c) in enumerate(pts)
        any(isnan, c) && continue
        s = ms isa AbstractVector ? ms[min(i, length(ms))] : ms
        sx, sy = s isa Number ? (Float64(s), Float64(s)) : (Float64(s[1]), Float64(s[2]))
        m = mk isa AbstractVector ? mk[min(i, length(mk))] : mk
        unit = get!(() -> _marker_shape(m, font), shapes, m)
        a = _angle(rot isa AbstractVector ? rot[min(i, length(rot))] : rot)
        ca, sa = cos(a), sin(a)
        poly = P2[(c[1] + ca * x * sx - sa * y * sy, c[2] + sa * x * sx + ca * y * sy)
                  for (x, y) in unit]
        bb = _bbox(poly)
        _far(bb, (0.0, w, 0.0, h), pad) && continue      # outside the axis: not drawn
        desc = "$(top == "Scatter" ? "Scatter" : top * "/Scatter") marker " *
               "($(_hex(fill)), $(round(max(bb[2] - bb[1], bb[4] - bb[3]), digits = 1)) px drawn)"
        if _alpha(fill) > 0 || pad > 0
            push!(out, Obstacle(:marker, poly, pad, idx, group, desc))
            _alpha(fill) >= 0.99 && push!(occ, Occluder(poly, idx, length(out)))
        end
    end
end

function _arrows!(out, p, top, idx, group)
    _attr(p, :visible, true) || return
    m = p[1][]
    meshes = m isa AbstractVector ? m : [m]
    sp = _attr(p, :space, :data)
    for mesh in meshes
        vs = Makie.GeometryBasics.coordinates(mesh)
        for f in Makie.GeometryBasics.faces(mesh)
            tri = P2[]
            for k in 1:3
                v = vs[Int(Makie.GeometryBasics.value(f[k]))]
                P = Makie.Point3f(v[1], v[2], 0)
                sp === :pixel || (P = Makie.project(Makie.parent_scene(p), sp, :pixel, P))
                push!(tri, (Float64(P[1]), Float64(P[2])))
            end
            push!(out, Obstacle(:arrow, tri, 0.0, idx, group,
                                "$top ($(_hex(_color(_attr(p, :color)))))"))
        end
    end
end

# Walk the axis's plots in draw order. A Text plot's own children (its LaTeX rules)
# belong to the label, never to the obstacles.
function _walk!(labels, obs, occ, p, top, group, scene, counter, w, h; inarrow = false,
                basemap = false)
    counter[] += 1
    idx = counter[]
    group == 0 && (group = idx)                     # a top-level plot is its own group
    _attr(p, :visible, true) || return
    if p isa Makie.Text
        _labels!(labels, p, scene, idx)
    elseif p isa Makie.Lines || p isa Makie.LineSegments
        # An arrow's outline is the arrow, so it is reported as one, once; a stroke
        # fainter than FAINT_ALPHA is the muted base, filed apart.
        kind = inarrow ? :arrow : basemap && _opacity(p) < FAINT_ALPHA ? :faint : :line
        _strokes!(obs, p, top, idx, group, w, h; kind = kind)
    elseif p isa Makie.Scatter
        _markers!(obs, occ, p, top, idx, group, w, h)
    elseif p isa Makie.Mesh
        inarrow && _arrows!(obs, p, top, idx, group)
    else
        isarrow = inarrow || occursin("Arrows", _name(p))
        for c in p.plots
            _walk!(labels, obs, occ, c, top, group, scene, counter, w, h; inarrow = isarrow,
                   basemap = basemap)
        end
    end
end

"""
    measure(fig) -> NamedTuple

Every label-versus-obstacle pair in every 2-D axis of `fig` (an `Axis`, or a GeoMakie
`GeoAxis` such as Logjam's `makemap` draws) closer than `NEAR_PX`, split into `findings`
(closer than `CLEAR_PX`: the rule), `near` (not failing) and `faint` (contacts with
the muted base, not failing). Call it after the figure has been drawn, which is what
the display hook does. A 3-D axis is listed in `skipped`, never silently passed.
"""
function measure(fig::Makie.Figure)
    clear = clear_px()
    findings, near, faint = Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[]
    skipped = String[]
    nlab = nobs = 0
    for (ai, ax) in enumerate(filter(b -> b isa Makie.AbstractAxis, fig.content))
        if ax isa Makie.Axis3 || !hasproperty(ax, :scene)
            push!(skipped, string(nameof(typeof(ax))))
            continue
        end
        scene = ax.scene
        w, h = Float64.(Makie.widths(scene.viewport[]))
        labels, obs, occ = LabelBox[], Obstacle[], Occluder[]
        counter = Ref(0)
        # The axis's own decorations: a GeoAxis draws its graticule and frame INTO its
        # scene and names them in `ax.elements`; they are gridlines, not features.
        decor = hasproperty(ax, :elements) ?
                Set{UInt}(objectid(v) for v in values(ax.elements)) : Set{UInt}()
        for p in scene.plots
            objectid(p) in decor && continue
            _walk!(labels, obs, occ, p, _name(p), 0, scene, counter, w, h;
                   basemap = !(ax isa Makie.Axis))
        end
        # The visible spines, which sit on the viewport's edges (an Axis has them; a
        # GeoAxis draws its frame differently and is left to its own linework).
        if ax isa Makie.Axis
            sw = Float64(ax.spinewidth[]) / 2
            for (k, (vis, a, b, nm)) in enumerate((
                    (ax.bottomspinevisible[], (0.0, 0.0), (w, 0.0), "bottom"),
                    (ax.topspinevisible[], (0.0, h), (w, h), "top"),
                    (ax.leftspinevisible[], (0.0, 0.0), (0.0, h), "left"),
                    (ax.rightspinevisible[], (w, 0.0), (w, h), "right")))
                vis && push!(obs, Obstacle(:spine, [a, b], sw, 0, -k, "the $nm axis spine"))
            end
        end
        nlab += length(labels); nobs += length(obs)
        _pairs!(findings, near, faint, labels, obs, occ, clear, ai, scene, ax)
    end
    return (labels = nlab, obstacles = nobs, findings = findings, near = near,
            faint = faint, skipped = skipped, clear_px = clear)
end
measure(fig::Makie.FigureAxisPlot) = measure(fig.figure)

function _pairs!(findings, near, faint, labels, obs, occ, clear, ai, scene, ax)
    best = Dict{Tuple{Int,Int,Symbol},Tuple{Float64,Any,Obstacle}}()
    # Where it happens, in the axis's own data coordinates, so the author can find it.
    function todata(at)
        try
            q = Makie.project(scene, :pixel, :data, Makie.Point3f(at[1], at[2], 0))
            # A map reports lon/lat: a GeoAxis carries its own inverse projection.
            itf = hasproperty(ax, :inv_transform_func) ? ax.inv_transform_func[] :
                  Makie.inverse_transform(Makie.transform_func(scene))
            itf === nothing || (q = Makie.apply_transform(itf, Makie.Point2d(q[1], q[2])))
            return [round(Float64(q[1]), sigdigits = 4), round(Float64(q[2]), sigdigits = 4)]
        catch
            return nothing
        end
    end
    lbb = [_bbox(L.poly) for L in labels]
    for (li, L) in enumerate(labels), (oi, o) in enumerate(obs)
        _far(lbb[li], _bbox(o.poly), o.pad + NEAR_PX) && continue
        # A label inside its marker (a node's number) is enclosed, not crossing. Inside
        # means within the marker's outline, the stroke's centre line, and no margin:
        # an ink box's CORNERS are empty for the digits such labels carry, and 2.5's
        # aggregation figures put "2" to "6" in 13.4 px rings with box corners 0.5 px
        # from the ring's inner edge and the glyphs visibly clear of it.
        o.kind === :marker && _inside(L.poly, o.poly, 0.0) && continue
        d = convex_distance(L.poly, o.poly) - o.pad
        d >= NEAR_PX && continue
        # Whatever lies under an opaque marker drawn after it is hidden where a label
        # inside that marker sits: a graph's edge under the node carrying the number.
        any(c -> c.id != oi && c.plot > o.plot && L.plot > c.plot &&
                 _inside(L.poly, c.poly, 0.0), occ) && continue
        key = (li, o.group, o.kind)              # one finding per label, plot and kind
        if !haskey(best, key) || d < best[key][1]
            best[key] = (d, _closest_point(L.poly, o.poly), o)
        end
    end
    box(L) = [[round(c[1], digits = 1), round(c[2], digits = 1)] for c in L.poly]
    for ((li, _, _), (d, at, o)) in best
        L = labels[li]
        push!(o.kind === :faint ? (d < clear ? faint : near) : d < clear ? findings : near,
              Dict{String,Any}(
            "axis" => ai, "label" => L.text, "whole" => L.whole, "anchor" => L.anchor,
            "kind" => string(o.kind), "with" => o.who,
            "clearance_px" => round(d, digits = 2), "box_px" => box(L),
            "at_px" => [round(at[1], digits = 1), round(at[2], digits = 1)],
            "at_data" => todata(at)))
    end
    # Label against label, each pair once; lines of one label are not a pair.
    for i in eachindex(labels), j in (i + 1):length(labels)
        A, B = labels[i], labels[j]
        (A.plot == B.plot && A.block == B.block) && continue
        _far(lbb[i], lbb[j], NEAR_PX) && continue
        d = convex_distance(A.poly, B.poly)
        d >= NEAR_PX && continue
        at = _closest_point(A.poly, B.poly)
        push!(d < clear ? findings : near, Dict{String,Any}(
            "axis" => ai, "label" => A.text, "whole" => A.whole, "anchor" => A.anchor,
            "kind" => "label", "with" => "the label \"$(B.text)\" at $(B.anchor)",
            "clearance_px" => round(d, digits = 2), "box_px" => box(A),
            "at_px" => [round(at[1], digits = 1), round(at[2], digits = 1)],
            "at_data" => todata(at)))
    end
    for v in (findings, near, faint)
        sort!(v; by = f -> (f["axis"], f["label"], f["with"]))
    end
end

# ----------------------------------------------------------------------------------
# filing the result: .quarto/figure-labels/<stem>.json, rewritten on every display
# ----------------------------------------------------------------------------------

const RUN = Ref{Union{Nothing,Dict{String,Any}}}(nothing)

function _json(io, x)
    if x isa AbstractDict
        print(io, "{")
        for (i, k) in enumerate(sort!(collect(keys(x))))
            i > 1 && print(io, ", ")
            _json(io, string(k)); print(io, ": "); _json(io, x[k])
        end
        print(io, "}")
    elseif x isa AbstractVector || x isa Tuple
        print(io, "[")
        for (i, v) in enumerate(x)
            i > 1 && print(io, ", ")
            _json(io, v)
        end
        print(io, "]")
    elseif x isa AbstractString || x isa Symbol
        print(io, '"')
        for c in string(x)
            c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") :
            c == '\n' ? print(io, "\\n") : c < ' ' ? print(io, "\\u", string(UInt16(c), base = 16, pad = 4)) :
            print(io, c)
        end
        print(io, '"')
    elseif x isa Bool
        print(io, x ? "true" : "false")
    elseif x === nothing
        print(io, "null")
    elseif x isa Real
        print(io, isfinite(x) ? x : "null")
    else
        _json(io, string(x))
    end
end

function _root(qmd)
    d = dirname(abspath(qmd))
    while true
        isfile(joinpath(d, "_quarto.yml")) && return d
        p = dirname(d)
        p == d && return dirname(abspath(qmd))
        d = p
    end
end

function _sha256(path)
    try
        sha = Base.require(Base.PkgId(Base.UUID("ea8e919c-243c-51af-8825-aaa63cd721ce"), "SHA"))
        return bytes2hex(Base.invokelatest(sha.sha256, read(path)))
    catch
        return ""
    end
end

function _target(qmd)
    dir = get(ENV, "FIGLABELS_OUT", "")
    isempty(dir) && (dir = joinpath(_root(qmd), ".quarto", "figure-labels"))
    return joinpath(dir, splitext(basename(qmd))[1] * ".json")
end

function _source_path()
    p = get(task_local_storage(), :SOURCE_PATH, nothing)
    return (p isa AbstractString && endswith(lowercase(p), ".qmd")) ? String(p) : nothing
end

function _cell_label(io)
    ctx = get(io, :QuartoNotebookRunner, nothing)
    ctx === nothing && return nothing
    opts = hasproperty(ctx, :cell_options) ? ctx.cell_options : nothing
    opts isa AbstractDict || return nothing
    l = get(opts, "label", nothing)
    return l isa AbstractString ? String(l) : nothing
end

function _file!(qmd, entry)
    run = RUN[]
    if run === nothing || run["source"] != qmd
        root = _root(qmd)
        run = Dict{String,Any}(
            "lecture" => splitext(basename(qmd))[1],
            "source" => qmd,
            "qmd" => replace(relpath(abspath(qmd), root), "\\" => "/"),
            # The text actually executed: the lecture, or a revision the sweep ran as it.
            "qmd_sha256" => _sha256(get(ENV, "FIGLABELS_SOURCE", qmd)),
            "generator" => get(ENV, "FIGLABELS_GENERATOR", "render"),
            "clear_px" => clear_px(),
            "figures" => Dict{String,Any}[])
        RUN[] = run
    end
    figs = run["figures"]
    i = findfirst(f -> f["label"] == entry["label"], figs)
    i === nothing ? push!(figs, entry) : (figs[i] = entry)
    path = _target(qmd)
    mkpath(dirname(path))
    tmp = path * ".tmp"
    open(tmp, "w") do io
        _json(io, Dict(k => v for (k, v) in run if k != "source"))
        println(io)
    end
    mv(tmp, path; force = true)
    return nothing
end

"""
    record(io, fig)

Measure `fig` and file it under the lecture the render is executing. Never throws: a
measurement that fails is filed as an error, so the gate reads "not measured", never
"clean".
"""
function record(io, fig)
    qmd = _source_path()
    qmd === nothing && return nothing
    label = something(_cell_label(io), "(unlabelled)")
    entry = Dict{String,Any}("label" => label)
    try
        f = fig isa Makie.FigureAxisPlot ? fig.figure : fig
        f isa Makie.Figure || return nothing
        res = measure(f)
        merge!(entry, Dict{String,Any}(string(k) => v for (k, v) in pairs(res)))
    catch err
        entry["error"] = sprint(showerror, err)
    end
    try
        _file!(qmd, entry)
    catch
    end
    return nothing
end

# THE DISPLAY HOOK. Quarto's Julia engine shows a figure through Base.show with an
# image MIME; Makie's own method is for any MIME, so this one, for the two image MIMEs
# and a Figure, is more specific and runs instead. It lets Makie draw first, so the
# layout and limits it measures are the ones on the page, then measures.
for M in (MIME"image/png", MIME"image/svg+xml")
    @eval function Base.show(io::IO, m::$M,
                             fig::Union{Makie.Figure,Makie.FigureAxisPlot}; kw...)
        screen = invoke(Base.show, Tuple{IO,MIME,Makie.FigureLike}, io, m, fig; kw...)
        FigureLabels.record(io, fig)
        return screen
    end
end

end # module FigureLabels

nothing
