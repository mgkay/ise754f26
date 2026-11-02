# label_place.jl -- place each label of a figure beside its point, clear of everything
# drawn, in any number of lines, and print the placement for the lecture to write out.
#
# HIS WORDS (instructor, 2026-11-01, on the route maps of lecture 5.2): "the load and
# load parenthetical comments are still not aligned ... Should be a way of making it so
# that this can be right below the label name and still have it aligned correctly. What
# if a label was two lines for something other than this? It still should work.
# Currently, it seems like anything that's two lines can't be labeled ... the procedure
# needs to be robust enough that this is a normal application of a two-line label.
# Please fix this so that labels and figures, going forward, can be two lines and have
# it aligned correctly." And: "This would be something to fix by hand for this lecture
# going forward, for anything that's not student-visible ... It's probably never going
# to be possible to eliminate the need for some by hand, so the rules and regs should
# still be there."
#
# WHAT WENT WRONG BEFORE, so the method below is not a guess. A city's label on 5.2's maps
# was two pieces of information, its name and the shipments loaded and unloaded there.
#   * Round 0 drew them as one two-line string and searched only a few offsets per city
#     for the whole block; the block fit nowhere near Asheville, Jacksonville or
#     Gainesville, so it was pushed out by hand until it cleared, 21 px from its point:
#     "the labels are now far offset from the points."
#   * Round 1 split them into two labels placed independently, as figure-conventions.md
#     Sec. 5 then said ("Do NOT stack them"). Each cleared the lines, and each went where
#     it fit, so the loads sat left of one city, under another, above a third: "still not
#     aligned ... This is actually worse than before."
# The fix is not a different alignment rule. It is to place the two-line block as ONE
# label, at the nearest of many candidate positions, with its lines justified to the
# side away from the point, and to search close in before far out.
#
# THE METHOD. For each label, in turn and then again until nothing moves:
#   1. Compass positions at growing radius, nearest first: E, W, NE, NW, SE, SW, N, S at
#      radius r for r in `radii`. The alignment follows the side, (:left, :center) east of
#      the point, (:right, :bottom) north-west, (:center, :top) south, and so on, and a
#      multi-line label's justification follows its horizontal alignment (Makie's
#      default), so its lines are flush left east of the point, flush right west of it,
#      and centred above or below it. That is what "aligned correctly" means for a block.
#   2. If no compass position clears, every offset on a 2 px grid out to the largest
#      radius, nearest first, with the alignment of the quadrant the offset points into.
#   A position is taken when the label's ink, line by line (FigureLabels' own boxes),
#   comes no closer than `clear` px to any stroke, marker, arrow or other label in EVERY
#   drawing passed, and stays inside the axis viewport (a label cut off at the map's edge
#   is not placed; FigureLabels.measure does not see that case, filed 2026-11-01).
# Several drawings may share one placement: a lecture that draws a route over an earlier
# map (5.2's Fig. 4 over Fig. 2) reuses that map's labels, so both are passed and a
# position must clear in both.
#
# WHAT IT IS FOR. Drafting, never the student page. It prints the two vectors, `align`
# and `offset`, as Julia literals; the lecture writes them out by hand in the figure's
# folded code, which stays the reproducible record. FigureLabels' render-time check then
# measures the result as it measures every figure. Logjam's `aligntext` places a label by
# the angles to its Delaunay neighbours and knows neither the label's size nor the lines
# drawn, which is why it cannot do this; docs/logjam-change-requests.md CR 52 asks for a
# Logjam export on this method, so that students can run it next semester.
#
# USE (a drafting script):
#     include(joinpath(<repo>, "_common", "julia", "label_place.jl"))
#     fig, ax = makemap(x, y); ...draw everything...
#     tp = text!(ax, x, y; text = labels)            # any number of lines each
#     align, offset = LabelPlace.place([(fig, ax, tp)])
module LabelPlace

isdefined(Main, :FigureLabels) ||
    Base.include(Main, joinpath(@__DIR__, "figure_labels.jl"))
const FL = Main.FigureLabels
using CairoMakie
const Makie = CairoMakie.Makie

const P2 = NTuple{2,Float64}

# Nearest first: beside the point, then its corners, then above and below it.
const DIRS = [((:left, :center), (1.0, 0.0)), ((:right, :center), (-1.0, 0.0)),
              ((:left, :bottom), (0.7, 0.7)), ((:right, :bottom), (-0.7, 0.7)),
              ((:left, :top), (0.7, -0.7)), ((:right, :top), (-0.7, -0.7)),
              ((:center, :bottom), (0.0, 1.0)), ((:center, :top), (0.0, -1.0))]

# The alignment for an offset (dx, dy) in pixels: the label sits on the side it points to.
function quadrant(dx, dy)
    h = dx > 2 ? :left : dx < -2 ? :right : :center
    v = dy > 2 ? :bottom : dy < -2 ? :top : :center
    return (h, v)
end

function candidates(radii)
    c = [(a, (round(Int, r * d[1]), round(Int, r * d[2]))) for r in radii for (a, d) in DIRS]
    R = maximum(radii)
    g = [(quadrant(dx, dy), (dx, dy)) for dx in -R:2:R for dy in -R:2:R
         if minimum(radii) <= hypot(dx, dy) <= R]
    sort!(g; by = c -> hypot(c[2]...))
    return c, g
end

# One drawing: its obstacles, collected once by the label check's own walk, with every
# other Text plot's ink as fixed obstacles too.
function drawing(fig, ax, tp)
    Makie.colorbuffer(fig)                      # lay it out, as a save would
    scene = ax.scene
    w, h = Float64.(Makie.widths(scene.viewport[]))
    labels, obs, occ = FL.LabelBox[], FL.Obstacle[], FL.Occluder[]
    decor = hasproperty(ax, :elements) ?
            Set{UInt}(objectid(v) for v in values(ax.elements)) : Set{UInt}()
    counter = Ref(0)
    for p in scene.plots
        (objectid(p) in decor || p === tp) && continue
        FL._walk!(labels, obs, occ, p, FL._name(p), 0, scene, counter, w, h;
                  basemap = !(ax isa Makie.Axis))
    end
    filter!(o -> o.kind !== :faint, obs)        # a map's muted roads never block
    fixed = [L.poly for L in labels]            # the other labels, as drawn
    anchors = Makie.register_markerspace_positions!(tp)[]
    return (; fig, ax, tp, scene, w, h, obs, obb = [FL._bbox(o.poly) for o in obs],
            fixed, fbb = [FL._bbox(q) for q in fixed], anchors)
end

function boxes(m, align, offset)
    m.tp.align = align
    m.tp.offset = offset
    out = FL.LabelBox[]
    FL._labels!(out, m.tp, m.scene, 1)
    return out
end

# Label i of drawing m, at the placement `align`, `offset`: inside, and clear.
function clear_in(m, i, align, offset, clear)
    bs = boxes(m, align, offset)
    for L in bs
        L.block == i || continue
        any(q -> q[1] < 1 || q[1] > m.w - 1 || q[2] < 1 || q[2] > m.h - 1, L.poly) &&
            return false
        bb = FL._bbox(L.poly)
        for (o, ob) in zip(m.obs, m.obb)
            FL._far(bb, ob, o.pad + clear) && continue
            o.kind === :marker && FL._inside(L.poly, o.poly, 0.0) && continue
            FL.convex_distance(L.poly, o.poly) - o.pad < clear && return false
        end
        for (q, qb) in zip(m.fixed, m.fbb)
            FL._far(bb, qb, clear) && continue
            FL.convex_distance(L.poly, q) < clear && return false
        end
        for B in bs
            B.block == i && continue
            FL._far(bb, FL._bbox(B.poly), clear) && continue
            FL.convex_distance(L.poly, B.poly) < clear && return false
        end
    end
    return true
end
clear_all(ms, i, align, offset, clear) = all(m -> clear_in(m, i, align, offset, clear), ms)

# The gap, in px, between a label's point and the nearest of its lines' ink.
function gap(m, i, align, offset)
    a = m.anchors[i]
    p = [(Float64(a[1]), Float64(a[2]))]
    d = Inf
    for L in boxes(m, align, offset)
        L.block == i && (d = min(d, FL.convex_distance(p, L.poly)))
    end
    return d
end

"""
    place(ms; radii = 5:2:29, clear = FigureLabels.CLEAR_PX, passes = 4)
        -> (align, offset)

Place every label of the Text plot in each drawing of `ms`, a vector of `(fig, ax, tp)`
sharing one placement, at the nearest position that clears all of them; see the file
header. Prints the placement as Julia literals, each label's gap to its point, any label
it could not place, and the label check's own findings on the result.
"""
function place(ms; radii = 5:2:29, clear = FL.CLEAR_PX, passes = 4)
    D = [drawing(fig, ax, tp) for (fig, ax, tp) in ms]
    n = length(D[1].anchors)
    comp, grid = candidates(radii)
    align = fill((:left, :center), n)
    offset = fill((first(radii), 0), n)
    for _ in 1:passes
        moved = false
        for i in 1:n
            clear_all(D, i, align, offset, clear) && continue
            for (a, o) in Iterators.flatten((comp, grid))
                A, O = copy(align), copy(offset)
                A[i], O[i] = a, o
                if clear_all(D, i, A, O, clear)
                    align, offset, moved = A, O, true
                    break
                end
            end
        end
        moved || break
    end
    left = [i for i in 1:n if !clear_all(D, i, align, offset, clear)]
    println("align = ", align)
    println("offset = ", offset)
    println("gap to its point, px: ",
            [round(gap(D[1], i, align, offset), digits = 1) for i in 1:n])
    isempty(left) || println("NOT PLACED: labels ", left)
    for (k, m) in enumerate(D)
        boxes(m, align, offset)
        Makie.colorbuffer(m.fig)
        for f in FL.measure(m.fig).findings
            println("  CHECK drawing $k: ", f["whole"], " :: ", f["with"])
        end
    end
    return align, offset
end

end # module LabelPlace

nothing
