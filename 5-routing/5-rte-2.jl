# 5-rte-2 — generated from 5-rte-2.qmd by tools/qmd_to_jl.py
# (do not edit by hand; rerun the generator after editing the .qmd)
# Cells (## title) follow the Julia VS Code extension convention.
# Run a cell: click inside it, then press Alt+Enter.

## Get class-ready — install packages
# Run this cell once. It installs every package the course uses, at the
# versions pinned in the shared Manifest.toml, by activating the course
# project and instantiating it. The project is the nearest folder above
# this one holding a Project.toml, or an env/ or materials/env/ beside
# one -- this repo keeps it at the root, the materials repo under env/,
# so a copy under work/ finds it as ISE754/materials/env. Idempotent:
# packages already present at the right version are skipped.
import Pkg
let dir = @__DIR__
    isproj = d -> isfile(joinpath(d, "Project.toml"))
    env = d -> isproj(joinpath(d, "env")) ? joinpath(d, "env") :
               joinpath(d, "materials", "env")
    while !isproj(dir) && !isproj(env(dir)) &&
          dir != dirname(dir)
        dir = dirname(dir)
    end
    isproj(env(dir)) && (dir = env(dir))
    isproj(dir) ||
        error("no course project above $(@__DIR__)")
    Pkg.activate(dir)
    Pkg.instantiate()
end

## Setup

# apparatus.jl ships beside the lectures in the materials
# repository. Find it from the activated project rather
# than from this file, so the script still works from a
# copy under work/.
let p = dirname(Base.active_project())
    include(joinpath(basename(p) == "env" ? dirname(p) : p,
                     "_common", "julia", "apparatus.jl"))
end

using CairoMakie, DataFrames, GeoMakie, Logjam, Random
# Two device pixels per figure unit, as in lectures 3.2 to 5.1, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# The colors the figures share, as in Lecture 5.1
dcc   = colorant"#1e8a3c"  # pickups
ink   = colorant"#252525"
redc  = colorant"#d21f26"  # deliveries
bluec = colorant"#1f6fb5"  # shipments, nodes
# Presentation plumbing for the prose, as in Lectures 4.1 to 5.1: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

## Sec. 1. Route sequencing
# Code block 1: three shipments and the roads between their locations
P = [0.0 0.0; 4.0 0.0; 0.35 0.75; 3.65 0.75;  # locations 1 to 6
     0.35 -1.1; 3.65 -1.1]
rn = 0.17  # location radius, data units
links = [(1, 2, 300), (3, 4, 250), (5, 6, 275), (1, 3, 30), (4, 2, 30),
         (1, 5, 60), (6, 2, 60)]  # road links, with their miles
# points along a curve from p to q, bowed toward c
curvepts(p, c, q; n = 60) = [(1 - s)^2 .* p .+ 2(1 - s) * s .* c .+
                             s^2 .* q for s in range(0, 1, length = n)]
# the part of a curve outside the circles around a and b, cut on each
# outline
function clipnodes(pts, a, b; r = rn)
    ins(x, o) = hypot((x .- o)...) < r
    function cross(u, v, o)  # where u to v crosses the outline around o
        lo, hi = 0.0, 1.0
        for _ in 1:40
            mid = (lo + hi) / 2
            ins(u .+ mid .* (v .- u), o) ? (lo = mid) : (hi = mid)
        end
        return u .+ hi .* (v .- u)
    end
    i = findfirst(x -> !ins(x, a), pts)
    j = findlast(x -> !ins(x, b), pts)
    return vcat([cross(pts[i-1], pts[i], a)], pts[i:j],
                [cross(pts[j+1], pts[j], b)])
end
function arrowline!(ax, pts, col; lw = 2.5)  # its tip on the last point
    lines!(ax, first.(pts), last.(pts); color = col, linewidth = lw)
    j = findlast(x -> hypot((pts[end] .- x)...) > 0.25, pts)
    u, v = pts[j], pts[end]
    arrows2d!(ax, [u[1]], [u[2]], [v[1] - u[1]], [v[2] - u[2]];
              color = col, shaftwidth = lw,
              tipwidth = 11, tiplength = 11)
end
function drawlink!(ax, i, j, d)  # a road, dotted, with its miles
    p, q = P[i, :], P[j, :]
    seg = clipnodes(curvepts(p, (p .+ q) ./ 2, q), p, q)
    lines!(ax, first.(seg), last.(seg); color = redc, linestyle = :dot,
           linewidth = 1.5)
    m, long = (p .+ q) ./ 2, abs(q[1] - p[1]) > 1
    side = m[1] < 2 ? -1 : 1  # a short link's miles beside it
    text!(ax, m[1], m[2]; text = string(d), color = redc, fontsize = 13,
          align = long ? (:center, :top) :
                  (side < 0 ? :right : :left, :center),
          offset = long ? (0, -4) : (6side, 0))
end
function drawshipment!(ax, b, e, label)  # bowed above its road
    p, q = P[b, :], P[e, :]
    c = [(p[1] + q[1]) / 2, p[2] + 0.38]
    arrowline!(ax, clipnodes(curvepts(p, c, q), p, q), bluec)
    top = (p .+ q) ./ 4 .+ c ./ 2  # the curve's highest point
    text!(ax, top[1], top[2]; text = label, color = bluec,
          fontsize = 13, align = (:center, :bottom), offset = (0, 3))
end
function drawnodes!(ax, idx)  # locations, over everything
    for i in idx
        poly!(ax, Circle(Point2f(P[i, 1], P[i, 2]), rn); color = :white,
              strokecolor = ink, strokewidth = 1.5)
        text!(ax, P[i, 1], P[i, 2]; text = string(i), color = ink,
              fontsize = 13, align = (:center, :center))
    end
end
# an arrowhead partway along each leg of a route through x, y, so its
# direction shows; on a map, x and y are longitude and latitude, and
# each leg is taken as the map's Mercator projection draws it
merc(φ) = log(tand(45 + φ / 2))
function legarrows!(ax, x, y; color, onmap = false, at = 0.55,
                    size = 12, every = 1)
    Y = onmap ? merc.(y) : y
    for i in 1:every:length(x)-1
        dx, dy = x[i+1] - x[i], Y[i+1] - Y[i]
        dx == dy == 0 && continue          # a location visited twice
        xm, ym = x[i] + at * dx, Y[i] + at * dy
        scatter!(ax, [xm], [onmap ? 2atand(exp(ym)) - 90 : ym];
                 marker = :rtriangle, markersize = size,
                 rotation = atan(dy, onmap ? deg2rad(dx) : dx),
                 color = color isa AbstractVector ? color[i] : color)
    end
end
# the shipments loaded (L) and unloaded (U) at location i: (L1,2:U3)
function ldlabel(i, sh)
    L, U = findall(==(i), sh.b), findall(==(i), sh.e)
    parts = [isempty(L) ? "" : "L" * join(L, ","),
             isempty(U) ? "" : "U" * join(U, ",")]
    s = join(filter(!isempty, parts), ":")
    return isempty(s) ? "" : "($s)"
end
let fig = Figure(size = (560, 330))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    foreach(l -> drawlink!(ax, l...), links)
    for (k, (b, e)) in enumerate([(1, 2), (3, 4), (5, 6)])
        drawshipment!(ax, b, e, "Shipment $k")
    end
    drawnodes!(ax, 1:6)
    xlims!(ax, -0.5, 4.5); ylims!(ax, -1.5, 1.25)
    fig
end

# Sec. 1. Route sequencing
# Example 1: Three shipments on one route
## Example 1(b): In Julia
# Determine the same location sequence and cost with Logjam's isorigin,
# rte2loc and rteTC, from the costs $D$ between the six locations.
# Code block 2: the costs between the six locations, and the shipments
using Graphs, SimpleWeightedGraphs
i = [1, 3, 5, 1, 4, 1, 6]              # one end of each road
j = [2, 4, 6, 3, 2, 5, 2]              # its other end
w = [300, 250, 275, 30, 30, 60, 60]    # its miles
g = SimpleWeightedGraph(i, j, w)       # a network of two-way roads
D, _ = shortestpaths(g, weights(g), nv(g))  # from every location
# shortestpaths(g, weights(g), n) runs Dijkstra's procedure from each of
# the first n nodes, here all six, and returns the shortest distances
# between them and the predecessors, of which only the distances are kept,
# as in Lecture 4.1; Int.(D) then gives the distances as the whole miles
# they are.
D = Int.(D)                            # whole miles
sh = DataFrame(b = [1, 3, 5], e = [2, 4, 6])  # origin, destination
D
# The check the prose states: D is the matrix the lecture sets out
@assert D == [  0  300   30  280   60  335
              300    0  280   30  335   60
               30  280    0  250   90  340
              280   30  250    0  340   90
               60  335   90  340    0  275
              335   60  340   90  275    0]
# Code block 3: the route's loadings, location sequence and cost
R = [3, 1, 2, 2, 1, 3]
@show isorigin(R)  # true where a shipment is loaded
@show X = rte2loc(R, sh)  # the location of each element
@show segcost(X, D)                           # the cost of each segment
@show rteTC(R, sh, D)                         # the route's cost
@show sum(D[sh.b[k], sh.e[k]] for k in 1:3);  # three independent

## Example 1(c): Every route
# Determine the least costly of every route of the three shipments, by
# brute force.
# Code block 4: all 60 routes by brute force
using Combinatorics
rtesegsum(r, x) =
# rtesegsum gives the cumulative sum of a value of each shipment over each
# segment of a route: isorigin is true for each element that is a loading,
# the first appearance of its shipment, as Code block 10 shows, so the
# value is added at the shipment's loading and subtracted at its
# unloading. With a 1 for each shipment it gives the number of shipments
# on the truck over each segment, and with each shipment's weight it would
# give the weight on board.
    cumsum(x[r] .* ifelse.(isorigin(r), 1, -1))[1:end-1]
v = [1, 1, 2, 2, 3, 3]
rtes = (r for r ∈ multiset_permutations(v, 6)
# multiset_permutations(v, 6) gives the distinct orderings of all 6
# elements of v, each once, though shipments 1, 2 and 3 each appear twice
# in it: 90 of them, against the 720 of permutations(v). The parentheses
# make rtes a generator, which produces the routes one at a time as the
# next line finds their costs, rather than storing all 60 first.
        if all(>(0), rtesegsum(r, ones(3))))
        # The if keeps the 60 orderings on which the truck carries at
        # least one shipment over every segment, the routes.
TCᵒ, rᵒ = minimum((rteTC(r, sh, D), r) for r ∈ rtes)
# Each route is paired with its cost, and minimum compares the pairs by
# cost first, so it returns the cheapest cost together with its route, as
# Code block 5 of Lecture 5.1 does for tours.

@show length(multiset_permutations(v, 6))   # the orderings
@show length(collect(rtes))                 # the routes
@show TCᵒ                                   # the cheapest of them
@show count(rteTC(r, sh, D) == TCᵒ for r ∈ rtes)  # how many that cheap
rᵒ                                          # the cheapest route

## Sec. 1. Route sequencing
# Code block 5: zip codes to locations, and the distances between them
shz = DataFrame(orig = [27606, 32606, 48234, 32606],
                dest = [48234, 27518, 32606, 48234])
zips = sort(unique([shz.orig; shz.dest]))  # each zip code once
loc = 1:length(zips)                       # the location indices
shz.b = indexin(shz.orig, zips)            # each origin's location
shz.e = indexin(shz.dest, zips)            # each destination's
z = uszcta5()
XY = Matrix(z[indexin(zips, z.ZCTA5), [:LON, :LAT]])
Dz = dists(XY, XY, :mi) * 1.2              # road miles, circuity 1.2
@show DataFrame(loc = loc, zip = zips)
@show shz
round.(Dz, digits = 2)

## Example 2: Three shipments across the Southeast
# Determine the total distance of three shipments, from Raleigh to
# Athens, from Asheville to Jacksonville and from Savannah to
# Gainesville, shipped independently and consolidated on one route, for
# several routes.
# Code block 6: the six cities, and the road distances between them
City = ["Raleigh", "Athens", "Asheville", "Jacksonville", "Savannah",
        "Gainesville"]
St = [:NC, :GA, :NC, :FL, :GA, :FL]
loc = [loc2lonlat(c; state = s) for (c, s) in zip(City, St)]
x, y = [r.LON for r in loc], [r.LAT for r in loc]
D = dists(hcat(x, y), hcat(x, y), :mi) * 1.2
# Code block 7: the shipments
sh = DataFrame(b = [1, 3, 5], e = [2, 4, 6]);
# Code block 8: the three shipments shipped independently
@show TD = sum(D[b, e] for (b,e) in zip(sh.b, sh.e));
# Code block 9: the three independent shipments on a map
fig, ax = makemap(x, y; xexpand=0.3)
resize!(fig, 600, 520)

sh2ln(sh, x) = vcat(collect([x[b], x[e], NaN]
                            for (b, e) in zip(sh.b, sh.e))...)
# each city's name over the shipments loaded and unloaded there, one
# label placed by hand clear of the lines, flush to its point's side
citylabel(i, sh) = City[i] * "\n" * ldlabel(i, sh)
lalign = [(:left, :center), (:right, :center), (:left, :top),
          (:left, :center), (:left, :top), (:center, :top)]
loff = [(5, 0), (-5, 0), (9, -9), (19, 0), (8, -8), (0, -5)]

lines!(ax, sh2ln(sh, x), sh2ln(sh, y), color=:red)
for (b, e) in zip(sh.b, sh.e)  # each shipment's direction, Code block 1
    legarrows!(ax, x[[b, e]], y[[b, e]]; color=:red, onmap=true)
end
scatter!(ax, x, y)
text!(ax, x, y, text=citylabel.(eachindex(City), Ref(sh));
      align = lalign, offset = loff)
fig
# Code block 10: which elements of a route are loadings
rte = [1, 2, 1, 3, 3, 2]
isorigin(rte)
# Code block 11: the route's location sequence
loc = rte2loc(rte, sh)
prt(hcat(rte, loc); cols = ["Shipment", "Location"],
    row_title = "Element")
# Code block 12: the cost of each segment of the route
d = segcost(loc, D)
@show sum(d)
d
# Code block 13: the route's cost, in one call
rteTC(rte, sh, D)
# Code block 14: the costs of some single- and multi-shipment routes
rTDh(rte) = rteTC(rte, sh, D)
@show rTDh([1, 1])
@show rTDh([1, 1]) + rTDh([2, 2]) + rTDh([3, 3])
@show rTDh([1, 2, 2, 1]) + rTDh([3, 3])
@show rTDh([1, 2, 1, 2]) + rTDh([3, 3])
@show rTDh([1, 2, 3, 1, 2, 3])
@show rTDh([1, 2, 1, 3, 3, 2])

## Sec. 2. Minimum cost insertion
# Code block 15: the positions minimum cost insertion tries
let  # set in the lecture math's serif, as is the route (1, 2, 2, 1)
    fig = Figure(size = (470, 542), figure_padding = 4,
                 fonts = (; regular = Makie.MathTeXEngine.texfont()))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    w, dy = 0.78, 0.62  # a column's width, a row's height
    X(c) = c * w
    # position (i, j) loads the shipment in gap i, unloads it in gap j;
    # each gap has two columns, and the route's stops are at 3, 6, ...
    function slots(i, j)
        sx(g, s) = 3(g - 1) + s
        return i == j ? (sx(i, 1), sx(i, 2)) : (sx(i, 2), sx(j, 1))
    end
    # a table's rules, its column rules, and its subcaption below
    function frame!(y0, yb, xr, cap; ncol = 0.0)
        for yy in (y0 + 0.5dy, y0 - 0.5dy, yb)
            lines!(ax, [X(-1.25), xr], [yy, yy]; color = ink,
                   linewidth = 1)
        end
        lines!(ax, [X(-0.2), X(-0.2)], [y0 + 0.5dy, yb]; color = ink,
               linewidth = 1)
        ncol > 0 && lines!(ax, [ncol, ncol], [y0 + 0.5dy, yb];
                           color = ink, linewidth = 1)
        text!(ax, (X(-1.25) + xr) / 2, yb - 0.12; text = cap,
              fontsize = 15, color = ink, align = (:center, :top))
    end
    # bad: the rows that are not routes, a red × in place of their cost
    function postable!(route, k, pos, y0, best, bad, cap)
        m = length(route)
        stops = X.(3 .* (1:m))
        ncol = X(3m + 2.6)                 # the rule before the costs
        xr = ncol + 1.25
        text!(ax, stops, fill(y0, m); text = string.(route),
              fontsize = 16, color = ink, align = (:center, :center))
        for (r, (i, j)) in enumerate(pos)  # one row per position
            y = y0 - r * dy
            r == best && poly!(ax, Rect(X(-1.25), y - dy / 2,
                                        xr - X(-1.25), dy);
                               color = (bluec, 0.14))  # the least
            text!(ax, X(-0.7), y; text = string(r), fontsize = 16,
                  color = ink, align = (:center, :center))
            scatter!(ax, stops, fill(y, m); color = ink, markersize = 6)
            text!(ax, X.(collect(slots(i, j))), [y, y];
                  text = fill("$k", 2), fontsize = 16, color = ink,
                  align = (:center, :center))
            r in bad ?
                text!(ax, ncol + 0.15, y; text = "×", fontsize = 20,
                      color = redc, align = (:left, :center)) :
                text!(ax, ncol + 0.15, y; text = L"c_{%$r}",
                      fontsize = 17, color = r == best ? bluec : ink,
                      align = (:left, :center))
            r == best && scatter!(ax, [ncol + 0.95], [y];
                                  marker = :star5, markersize = 15,
                                  color = bluec)
        end
        yb = y0 - (length(pos) + 0.5) * dy
        frame!(y0, yb, xr, cap; ncol)
        return yb
    end
    # rows 1 and 6 of (a), the end and the front, leave the truck empty
    pos2 = [(3, 3), (1, 3), (2, 2), (2, 3), (1, 2), (1, 1)]
    yb = postable!([1, 1], 2, pos2, 0.0, 3, [1, 6],
                   "(a) Shipment 2 inserted into the route (1, 1)")
    pos3 = [(i, j) for i in 1:5 for j in i:5 if (i, j) != (1, 1)]
    push!(pos3, (1, 1))                    # the front last, as in (a)
    yb3 = postable!([1, 2, 2, 1], 3, pos3, yb - 1.25, 4, [14, 15],
                    "(b) Shipment 3 inserted into the route " *
                    "(1, 2, 2, 1)")
    xr = X(3 * 4 + 2.6) + 1.25             # the right edge of (b)
    xlims!(ax, -1.4w, xr + 0.1); ylims!(ax, yb3 - 0.7, 0.5)
    fig
end

# Sec. 2. Minimum cost insertion
## Model: Route sequencing
# Model: route sequencing, minimum cost insertion
function mincostinsert_rte(idx, rte, rteTCh)
    rteᵒ, TCᵒ = copy(rte), Inf
    for i = 1:length(rte)
        for j = max(2,i):length(rte) + 1
            rte′ = vcat(rte[1:i-1], idx, rte[i:j-1], idx, rte[j:end])
            TC = rteTCh(rte′)
            if TC < TCᵒ
                rteᵒ, TCᵒ = rte′, TC
            end
        end
    end
    return rteᵒ, TCᵒ
end

# Example 3: Minimum cost insertion
## Example 3(a): Three shipments on one route
# Determine every route the two insertions evaluate for the shipments of
# @fig-three-shipments, and the least costly of each.
# Code block 16: Ex. 1's costs and shipments, again
D1 = Int.(shortestpaths(g, weights(g), nv(g))[1])  # g of Code block 2
sh1 = DataFrame(b = [1, 3, 5], e = [2, 4, 6])
rTD1h(rte) = rteTC(rte, sh1, D1);
# Code block 17: insertion, printing every route it evaluates
function mincostinsert_prt(idx, rte, rteTCh)
    rteᵒ, TCᵒ = copy(rte), Inf
    for i = 1:length(rte)
        for j = max(2,i):length(rte) + 1
            rte′ = vcat(rte[1:i-1], idx, rte[i:j-1], idx, rte[j:end])
            TC = rteTCh(rte′)
            println(i,",",j,": ",rte′, " = ", TC)
            if TC < TCᵒ
                rteᵒ, TCᵒ = rte′, TC
            end
        end
    end
    return rteᵒ, TCᵒ
end

# insert shmt 2 route into shmt 1 route
rte12, TD12 = mincostinsert_prt(2, [1, 1], rTD1h)
@show rte12
@show TD12
# insert shmt 3 route into shmt 1&2 route
rte123, TD123 = mincostinsert_prt(3, rte12, rTD1h)
@show rte123
@show TD123;
# Code block 18: the same two insertions, by the implementation
r, TC = mincostinsert_rte(2, [1, 1], rTD1h)
r, TC = mincostinsert_rte(3, r, rTD1h)
@show r
@show TC;

## Example 3(b): Three shipments across the Southeast
# Determine the same two insertions for the three shipments of Ex. 2,
# and the route they give.
# Code block 19: the two insertions for Ex. 2's shipments
# insert shmt 2 route into shmt 1 route
rte12, TD12 = mincostinsert_prt(2, [1, 1], rTDh)
@show rte12
@show TD12
# insert shmt 3 route into shmt 1&2 route
rte123, TD123 = mincostinsert_prt(3, rte12, rTDh)
@show rte123
@show TD123;
# Code block 20: the consolidated route on the map
loc = rte2loc(rte123, sh)
lines!(ax, x[loc], y[loc], color=:green)
legarrows!(ax, x[loc], y[loc]; color=:green, onmap=true, at=0.4)
fig

## Model: Route sequencing
# Model: route sequencing, modified two-opt, the twoopt of a route
function twoopt_rte(r, rTCh)
    rᵒ, TCᵒ = copy(r), rTCh(r)
    done = false
    while !done
        done = true
        for i = 1:length(r)-1, j = i+1:length(r)
            r′ = vcat(r[1:i-1], reverse(r[i:j]), r[j+1:end])
            all(>(0), rtesegsum(r′, ones(maximum(r′)))) || continue
            TC = rTCh(r′)
            if TC < TCᵒ
                rᵒ, TCᵒ = r′, TC
                done = false
                break
            end
        end
        r = copy(rᵒ)
    end
    return rᵒ, TCᵒ
end
# Model: route sequencing, insert and improve
function insertimprove(L, rTCh)
    r = [L[1], L[1]]
    for k in L[2:end]
        r = mincostinsert_rte(k, r, rTCh)[1]
        r = twoopt_rte(r, rTCh)[1]
    end
    return r, rTCh(r)
end

# Example 4: Insert and improve
## Example 4(a): Six load orders
# Determine the route insert and improve builds from each load order $L$
# of the three shipments.
# Code block 21: insert and improve, from each of the six load orders
for L in permutations(1:3)
    r, TC = insertimprove(L, rTD1h)
    println(L, " => ", r, " = ", TC)
end

## Example 4(b): Five shipments in North Carolina
# Determine the route insert and improve builds for the five shipments
# of @fig-five-shipments, loaded in the order $(1, \ldots, 5)$.
# Code block 22: the five shipments, their seven locations and distances
using CSV
xy = CSV.read("data/shmtNC30-xy.csv", DataFrame)
X5 = Matrix(xy[[5, 27, 3, 38, 24, 18, 1], [:x, :y]])  # locations 1 to 7
D5 = dists(X5, X5, :mi) * 1.2                 # road miles, circuity 1.2
sh5 = DataFrame(b = [1, 3, 4, 6, 7], e = [2, 2, 5, 2, 1])
rTD5h(rte) = rteTC(rte, sh5, D5);
# Code block 23: insert and improve, loading in the order 1, ..., 5
r5, TC5 = insertimprove(1:5, rTD5h)
@show r5
@show TC5
@show rte2loc(r5, sh5)                       # its location sequence
@show rTD5h([3, 2, 5, 5, 1, 4, 3, 1, 2, 4])  # the published route
sum(rTD5h([k, k]) for k in 1:5)              # shipped independently
# Code block 24: the five shipments and their route on a map
let x5 = X5[:, 1], y5 = X5[:, 2]
    fig5, ax5 = makemap(x5, y5; xexpand = 0.25, yexpand = 0.12,
                        doRoadbkgd = false)
    # no base map: its one state line, at the top, read as a shipment
    foreach(p -> p.visible = false, ax5.scene.plots)
    φ = sum(y5) / length(y5)  # mid-latitude, for angles on the map
    # placed by hand, so no line runs along another or through a
    # location: each shipment bowed by bulge, bent at along of the way,
    # its arrow at ta of the way and its label at tl, above or below it
    bulge = [0.4, -1.0, 0.1, -0.1, 0.2]
    along = [0.9, 0.5, 0.9, 0.5, 0.5]
    ta = [0.3, 0.45, 0.35, 0.5, 0.5]
    tl = [0.35, 0.15, 0.15, 0.2, 0.65]
    above = [true, true, true, false, true]
    for (k, (b, e)) in enumerate(zip(sh5.b, sh5.e))  # each shipment
        p, q = [x5[b], y5[b]], [x5[e], y5[e]]
        nk = [-(q[2] - p[2]), q[1] - p[1]] ./ hypot((q .- p)...)
        c = p .+ along[k] .* (q .- p) .+ bulge[k] .* nk
        pts = curvepts(p, c, q)              # Code block 1's curve
        lines!(ax5, first.(pts), last.(pts); color = bluec,
               linewidth = 2.5)
        j = round(Int, 1 + ta[k] * 59)
        u, v = pts[j-2], pts[j+2]
        θ = atan((v[2] - u[2]) / cosd(φ), v[1] - u[1])
        scatter!(ax5, [pts[j][1]], [pts[j][2]]; marker = :rtriangle,
                 rotation = θ, markersize = 14, color = bluec)
        i = round(Int, 1 + tl[k] * 59)
        a, z = pts[i-2], pts[i+2]
        θt = atan((z[2] - a[2]) / cosd(φ), z[1] - a[1])
        text!(ax5, pts[i][1], pts[i][2]; text = "Shmt $k",
              color = bluec, fontsize = 13,
              rotation = abs(θt) > pi / 2 ? θt + pi : θt,
              align = (:center, above[k] ? :bottom : :top),
              offset = (0, above[k] ? 5 : -5))
    end
    loc5 = rte2loc(r5, sh5)
    lines!(ax5, x5[loc5], y5[loc5]; color = redc, linestyle = :dash,
           linewidth = 2.5)              # the route, over the shipments
    legarrows!(ax5, x5[loc5], y5[loc5]; color = redc, onmap = true)
    labs = ldlabel.(1:7, Ref(sh5))  # loaded and unloaded, Code block 1
    al = [(:right, :center), (:left, :center), (:right, :center),
          (:right, :center), (:right, :bottom), (:right, :center),
          (:right, :center)]                  # each label, by hand
    of = [(-14, -2), (14, 0), (-14, 0), (-14, 0), (-10, 8), (-14, -6),
          (-14, 0)]
    scatter!(ax5, x5, y5; color = :white, strokecolor = ink,
             strokewidth = 1.5, markersize = 22)
    text!(ax5, x5, y5; text = string.(1:7), color = ink, fontsize = 13,
          align = (:center, :center))
    for i in 1:7
        text!(ax5, x5[i], y5[i]; text = labs[i], color = redc,
              fontsize = 13, font = :bold, align = al[i],
              offset = of[i])
    end
    lim = ax5.finallimits[]               # the figure fitted to the map
    resize!(fig5, 600,
            round(Int, 600 * lim.widths[2] / lim.widths[1]) + 10)
    fig5
end

## Sec. 3. Savings
# Code block 25: the pairwise saving of shipments 1 and 2
let fig = Figure(size = (560, 260))  # with Code block 1's helpers
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    # the roads among locations 1 to 4
    foreach(l -> drawlink!(ax, l...), links[[1, 2, 4, 5]])
    drawshipment!(ax, 1, 2, "Shipment 1")
    drawshipment!(ax, 3, 4, "Shipment 2")
    p1, p2, p3, p4 = (P[i, :] for i in 1:4)  # the route 1-3-4-2 (green)
    leg = clipnodes(curvepts(p1, (p1 .+ p3) ./ 2, p3), p1, p3)
    lines!(ax, first.(leg), last.(leg); color = dcc, linewidth = 2.5)
    arrowline!(ax, clipnodes(curvepts(p3, [2.0, 2.05], p4), p3, p4),
               dcc)
    arrowline!(ax, clipnodes(curvepts(p4, (p4 .+ p2) ./ 2, p2), p4, p2),
               dcc)
    text!(ax, 2.0, 1.4; text = "Shipments 1 and 2", color = dcc,
          fontsize = 13, align = (:center, :bottom), offset = (0, 3))
    drawnodes!(ax, 1:4)
    xlims!(ax, -0.6, 4.6); ylims!(ax, -0.4, 1.75)
    fig
end

# Sec. 3. Savings
# Example 5: Clarke-Wright savings
## Example 5(a): By hand
# Determine the savings of every pair of customers, and the route the
# procedure builds from them, pair by pair.
# The starting state, then a frame per join; hidden, since Ex. 5(a) is by hand
let XY = [0.463 0.478; 0.118 0.671; 0.896 0.273   # where nodes 1 to 6 lie
          0.542 0.846; 0.507 0.148; 0.864 0.738],
    steps = [(nothing, "(a) Start: each customer out and back", Int[]),
             ((4, 6), "(b) Step 1: (4, 6), new route", [1, 4, 6, 1]),
             ((3, 6), "(c) Step 2: (3, 6), add 3", [1, 4, 6, 3, 1]),
             ((3, 5), "(d) Step 3: (3, 5), add 5", [1, 4, 6, 3, 5, 1]),
             ((2, 4), "(e) Step 4: (2, 4), add 2", [1, 2, 4, 6, 3, 5, 1])]
    fig = Figure(size = (560, 640), figure_padding = 4)
    for (k, (ij, what, loc)) in enumerate(steps)  # a frame a step
        ax = Axis(fig[(k - 1) ÷ 2 + 1, (k - 1) % 2 + 1];
                  aspect = DataAspect(), xlabel = what, xlabelsize = 13)
        hidedecorations!(ax; label = false)    # its subcaption below it
        hidespines!(ax)
        for c in setdiff(2:6, loc)             # out and back
            lines!(ax, XY[[1, c], 1], XY[[1, c], 2]; color = (ink, 0.6),
                   linestyle = :dot, linewidth = 1.5)
        end
        isempty(loc) || lines!(ax, XY[loc, 1], XY[loc, 2]; color = bluec,
                               linewidth = 2.5)
        ij === nothing || lines!(ax, XY[collect(ij), 1],
                                 XY[collect(ij), 2]; color = redc,
                                 linewidth = 4)  # the pair joined
        if !isempty(loc)                       # the route's direction
            legc = [ij !== nothing && Set(loc[i:i+1]) == Set(ij) ?
                    redc : bluec for i in 1:length(loc)-1]
            legarrows!(ax, XY[loc, 1], XY[loc, 2]; color = legc, size = 11)
        end
        scatter!(ax, XY[2:end, 1], XY[2:end, 2]; color = :white,
                 strokecolor = ink, strokewidth = 1.5, markersize = 22)
        scatter!(ax, [XY[1, 1]], [XY[1, 2]]; marker = :rect,
                 color = colorant"#f2d9a0", strokecolor = ink,
                 strokewidth = 1.5, markersize = 22)  # the depot
        text!(ax, XY[:, 1], XY[:, 2]; text = string.(1:6), color = ink,
              fontsize = 12, align = (:center, :center))
        xlims!(ax, 0.05, 0.96); ylims!(ax, 0.08, 0.91)
    end
    fig
end

## Example 5(b): In Julia
# Determine the same savings in Julia, and how the route compares with
# every tour from the depot.
# Code block 26: the savings, largest first, and all 120 tours
Ccw = [ 0  40  48  38  33  48
       40   0  87  46  65  75
       48  87   0  67  41  47
       38  46  67   0  70  34
       33  65  41  70   0  69
       48  75  47  34  69   0]
iˢ = [i for i in 2:6 for j in i+1:6]          # the pairs (i, j), i < j
jˢ = [j for i in 2:6 for j in i+1:6]
sˢ = [Ccw[1, i] + Ccw[1, j] - Ccw[i, j] for (i, j) in zip(iˢ, jˢ)]
k = sortperm(sˢ, rev = true)                  # largest first
prt(hcat(iˢ[k], jˢ[k], sˢ[k]); cols = ["i", "j", "Saving"],
    row_title = "Pair")
TCs = [sum(segcost([1; p; 1], Ccw)) for p ∈ permutations(2:6)]
@show length(TCs)                             # the tours looked at
@show minimum(TCs)                            # the cheapest of them
sum(segcost([1, 2, 4, 6, 3, 5, 1], Ccw))      # the Clarke-Wright route

## Model: Route sequencing
logjam_rung(:savings, "Route sequencing, savings construction")

# Example 6: Savings construction
## Example 6(b): In Julia
# Determine the same pairwise savings and route with Logjam's
# pairwisesavings and savings, and compare them with Ex. 6(a).
# Code block 27: pairwise savings and savings, for Ex. 1's shipments
ijs = pairwisesavings(rTD1h, sh1)
prt(hcat(ijs...); cols = ["i", "j", "Saving"], row_title = "Pair")
r = savings(rTD1h, sh1)
@show r
rTD1h.(r)

## Example 6(c): Three shipments across the Southeast
# Determine the pairwise savings of the three shipments of Ex. 2 and the
# route savings constructs for them.
# Code block 28: the pairwise saving of Ex. 2's shipments 1 and 2
@show c1 = rTDh([1, 1])
@show c2 = rTDh([2, 2])
@show c1 + c2
@show c12 = rTDh(rte12)
@show s12 = c1 + c2 - c12;
# Code block 29: every pairwise saving, largest first
ijs = pairwisesavings(rTDh, sh)
prt(hcat(ijs...); cols = ["i", "j", "Saving"], row_title = "Pair")
# Code block 30: the savings route, and its cost
@show r = savings(rTDh, sh)
rTDh.(r)
# Code block 31: Ex. 2's 60 routes by brute force
TCᵒ, rᵒ = minimum((rTDh(r), r) for r ∈ rtes)  # paired, as Code block 4
@show TCᵒ                            # the cheapest of them
rᵒ                                   # the cheapest route

## Example 6(d): Tour from Raleigh
# Determine the tour savings constructs from Raleigh to the other five
# cities of Ex. 2 and back, and its improvement by 2-opt.
# Code block 32: a shipment from Raleigh to each city, a truck, savings
shR = DataFrame(b = ones(Int, 5), e = [2:6;])
tr = (b = 1, e = 1)
rTDRh(rte) = rteTC(rte, shR, D, tr)
rte = savings(rTDRh, shR)[1]
@show rTDRh(rte)
prt(hcat(vcat(0, rte, 0), rte2loc(rte, shR, tr));
    cols = ["Shipment", "Location"], row_title = "Element")
# Code block 33: the savings tour on a map
fig, ax = makemap(x, y; xexpand=0.3)
resize!(fig, 600, 520)

loc = rte2loc(rte, shR, tr)
lines!(ax, x[loc], y[loc], color=:red)
legarrows!(ax, x[loc], y[loc]; color=:red, onmap=true, at=0.4)
scatter!(ax, x, y)
text!(ax, x, y, text=citylabel.(eachindex(City), Ref(shR));
      align=lalign, offset=loff)  # placed as in Fig. 2
fig
# Code block 34: the tour improved by 2-opt
r2, TC2 = twoopt_rte(rte, rTDRh)
@show TC2
prt(hcat(rte, r2); cols = ["Savings", "2-opt"], row_title = "Element")
# Code block 35: the improved tour on a map
fig, ax = makemap(x, y; xexpand=0.3)
resize!(fig, 600, 520)

loc = rte2loc(r2, shR, tr)
lines!(ax, x[loc], y[loc], color=:red)
legarrows!(ax, x[loc], y[loc]; color=:red, onmap=true, at=0.4)
scatter!(ax, x, y)
text!(ax, x, y, text=citylabel.(eachindex(City), Ref(shR));
      align=lalign, offset=loff)  # placed as in Fig. 2
fig
# Code block 36: all 120 tours from Raleigh by brute force
TCs = [rTDRh([p; p]) for p ∈ permutations(1:5)]   # only the costs
@show length(TCs)                                 # the tours looked at
minimum(TCs)                                      # the cheapest of them

## Example 7: Tour of North Carolina by savings
# Determine the tour of the 100 NC counties that savings constructs, and
# its improvement by 2-opt, against the tours of {{< xref 5.1 example-4
# >}}.
# Code block 37: the NC counties, a shipment from county 1 to each
df = filter(r -> (r.STFIP == st2fips(:NC)), uscounty())
XY = hcat(df.LON, df.LAT)
DN = dists(XY, XY, :mi)
n = nrow(df)
# Node 1 has same b,e so can be ignored
shN = DataFrame(b = ones(Int, n-1), e = [2:n;])
rTDNh(rte) = rteTC(rte, shN, DN, tr)
rteN = savings(rTDNh, shN)[1]
rTDNh(rteN)
# The checks the prose states: Lecture 5.1's estimate, from these counties
aN = sum(df.ALAND) + sum(df.AWATER)
@assert round(0.908sqrt(n * aN), digits = 2) == 2106.45
# Code block 38: the savings tour on a map
fig, ax = makemap(df.LON, df.LAT; xexpand=0.05)
loc = rte2loc(rteN, shN, tr)
lines!(ax, df.LON[loc], df.LAT[loc], color=:red, linewidth=.5)
# Code block 1's arrowheads, on every third leg
legarrows!(ax, df.LON[loc], df.LAT[loc]; color=:red, onmap=true,
           size=7, every=3)
lim = ax.finallimits[]                    # the figure fitted to the map
resize!(fig, 600, round(Int, 600 * lim.widths[2] / lim.widths[1]) + 10)
fig
# Code block 39: the savings tour improved by 2-opt, as a tour
loc = rte2loc(rteN, shN, tr)
π = [1; loc[loc .!= 1]; 1]          # county 1, then each county once
πTCh(π) = sum(segcost(π, DN))
π′, TD = twoopt(π, πTCh)
TD
# Code block 40: the improved tour on a map
fig, ax = makemap(df.LON, df.LAT; xexpand=0.05)
lines!(ax, df.LON[π′], df.LAT[π′], color=:red, linewidth=.5)
# Code block 1's arrowheads, on every third leg
legarrows!(ax, df.LON[π′], df.LAT[π′]; color=:red, onmap=true,
           size=7, every=3)
lim = ax.finallimits[]                    # the figure fitted to the map
resize!(fig, 600, round(Int, 600 * lim.widths[2] / lim.widths[1]) + 10)
fig

## Model: Route sequencing
# Model: route sequencing, randomized savings
function randreorder(ijs, p)            # each pair moved with prob. p
    mv = rand(length(ijs[1])) .< p
    return Tuple([v[.!mv]; v[mv]] for v in ijs)
end

function savings_ijs(rteTCh, sh, ijs)   # Logjam's savings, list given
    TC = nothing
    rte = [[i, i] for i in 1:nrow(sh)]
    inr = [1:nrow(sh);]
    iˢ, jˢ = ijs
    for (i, j) in zip(iˢ, jˢ)
        if inr[i] != inr[j]
            inr_src, inr_tgt =
                length(rte[inr[i]]) < length(rte[inr[j]]) ?
                (inr[i], inr[j]) : (inr[j], inr[i])
            rte′ = copy(rte[inr_tgt])
            idx_src = unique(rte[inr_src])
            for k in idx_src
                rte′, TC = mincostinsert(k, rte′, rteTCh)
                isinf(TC) && break
            end
            if !isinf(TC)
                rte[inr_tgt] = rte′
                inr[idx_src] .= inr_tgt
                rte[inr_src] = []
            end
        end
    end
    return filter!(!isempty, rte)
end

function randsavings(rteTCh, sh; p = 0.1, nruns = 30)
    ijs = pairwisesavings(rteTCh, sh)
    rteᵒ, TCᵒ = nothing, Inf
    for k = 1:nruns
        rte = savings_ijs(rteTCh, sh, randreorder(ijs, p))
        rte = [twoopt_rte(r, rteTCh)[1] for r in rte]
        TC = sum(rteTCh.(rte))
        if TC < TCᵒ
            rteᵒ, TCᵒ = rte, TC
            println(k, ": ", TCᵒ)
        end
    end
    return rteᵒ, TCᵒ
end
# Model: route sequencing, randomized insertion
function randinsert(rteTCh, sh; nruns = 30)
    rteᵒ, TCᵒ = nothing, Inf
    for k = 1:nruns
        rte, TC = insertimprove(randperm(nrow(sh)), rteTCh)
        if TC < TCᵒ
            rteᵒ, TCᵒ = rte, TC
            println(k, ": ", TCᵒ)
        end
    end
    return rteᵒ, TCᵒ
end

## Example 8: One route for thirty shipments
# Determine the least costly single route that carries 30 shipments
# among locations in North Carolina, each with its own origin and
# destination, by savings, randomized savings, random routes improved by
# 2-opt and randomized insertion.
# Code block 41: the 30 shipments, and the distances between locations
xy = CSV.read("data/shmtNC30-xy.csv", DataFrame)  # the 54 locations
sh30 = DataFrame(
    b = [15, 26, 23, 53, 17, 3, 39, 47, 44, 45, 43, 8, 29, 34, 38,
         41, 18, 40, 1, 11, 7, 30, 33, 22, 20, 19, 16, 48, 37, 14],
    e = [42, 27, 40, 51, 32, 27, 50, 28, 35, 10, 2, 12, 39, 52, 24,
         36, 27, 13, 5, 4, 6, 49, 9, 25, 46, 31, 21, 10, 54, 13])
X30 = Matrix(xy[:, [:x, :y]])
D30 = dists(X30, X30, :mi) * 1.2             # road miles, circuity 1.2
rTD30h(rte) = rteTC(rte, sh30, D30)
size(D30)
# Code block 42: the 30 shipments on a map
function basemap(x, y)  # makemap around the points, its borders in gray
    # close at the sides; tall enough to show the state's borders whole
    fig, ax = makemap(x, y; xexpand = 0.02, yexpand = 0.12,
                      doRoadbkgd = false)
    for p in ax.scene.plots                        # the state borders
        p.color, p.linewidth = (ink, 0.45), 1.5
    end
    return fig, ax
end
function fitmap!(fig, ax)  # the figure's height fitted to the map
    lim = ax.finallimits[]
    resize!(fig, 600,
            round(Int, 600 * lim.widths[2] / lim.widths[1]) + 10)
    return fig
end
function shmtmap(sh, X)  # each shipment, origin to destination
    x, y = X[:, 1], X[:, 2]
    used = unique([sh.b; sh.e])                    # its locations only
    fig, ax = basemap(x[used], y[used])
    for (b, e) in zip(sh.b, sh.e)
        lines!(ax, x[[b, e]], y[[b, e]]; color = redc, linewidth = 0.8)
        legarrows!(ax, x[[b, e]], y[[b, e]]; color = redc,
                   onmap = true, size = 7)
    end
    scatter!(ax, x[used], y[used]; color = ink, markersize = 4)
    fitmap!(fig, ax)
    return fig, ax
end
function milabel!(ax, what, d)  # a distance, at the map's lower left
    s = commas(round(d, digits = 2))
    s = "$what: $(rpad(s, findfirst('.', s) + 2, '0')) mi"
    text!(ax, 0.02, 0.03; text = s, space = :relative, color = ink,
          fontsize = 13, font = :bold, align = (:left, :bottom))
end
fig, ax = shmtmap(sh30, X30)
TD30 = sum(rTD30h([k, k]) for k in 1:nrow(sh30))
milabel!(ax, "Each from origin to destination", TD30)
fig
# Code block 43: savings and 2-opt, then one route for all 30
function oneroute(R, rTCh)  # one route: the longest, the rest inserted
    r = R[argmax(length.(R))]
    for k in setdiff(reduce(vcat, R), r)       # each one not on it,
        r′ = mincostinsert_rte(k, r, rTCh)[1]  # inserted at least cost,
        r = twoopt_rte(r′, rTCh)[1]            # then improved by 2-opt
    end
    return r, rTCh(r)
end
r30 = [twoopt_rte(r, rTD30h)[1] for r in savings(rTD30h, sh30)]
@show length.(r30) .÷ 2                        # shipments per route
rs30, TC30 = oneroute(r30, rTD30h)
TC30
# Code block 44: the route on a map
function rtemap(R, sh, X)  # the routes, a single-shipment route in red
    x, y = X[:, 1], X[:, 2]
    used = unique([sh.b; sh.e])
    fig, ax = basemap(x[used], y[used])            # Code block 42
    for r in R
        loc, col = rte2loc(r, sh), length(r) > 2 ? dcc : redc
        lines!(ax, x[loc], y[loc]; color = col, linewidth = 0.8)
        legarrows!(ax, x[loc], y[loc]; color = col, onmap = true,
                   size = 7, every = length(r) > 2 ? 3 : 1)
    end
    scatter!(ax, x[used], y[used]; color = ink, markersize = 4)
    fitmap!(fig, ax)
    return fig, ax
end
fig, ax = rtemap([rs30], sh30, X30)
milabel!(ax, "Savings, one route", TC30)           # Code block 42
fig
# Code block 45: randomized savings, 30 starts, then one route
Random.seed!(1234)
rr30, _ = randsavings(rTD30h, sh30; p = 0.1, nruns = 30)
rr30, TCr30 = oneroute(rr30, rTD30h)
TCr30
# Code block 46: 2-opt from 30 random routes
Random.seed!(1234)
rteᵒ, TCᵒ = nothing, Inf
for k = 1:30
    p = randperm(nrow(sh30))
    rk, TCk = twoopt_rte([p; p], rTD30h)  # load in order p, then unload
    if TCk < TCᵒ
        global rteᵒ, TCᵒ = rk, TCk
        println(k, ": ", TCᵒ)
    end
end
TCᵒ
# Code block 47: randomized insertion, 30 starts
Random.seed!(1234)
ri30, TCi30 = randinsert(rTD30h, sh30; nruns = 30)
TCi30
# Code block 48: the best route of randomized insertion, by rtemap
fig, ax = rtemap([ri30], sh30, X30)
milabel!(ax, "Randomized insertion, best of 30", TCi30)
fig

## Sec. 4. Load formation
# Code block 49: rte2idx and sh2rte
# a route's shipments, or those of each route of a vector of routes
rte2idx(r::AbstractVector{<:Integer}) = r[isorigin(r)]
# :: restricts an argument to a type, so this definition, a method of
# rte2idx, applies only when r is a single route: AbstractVector is any
# one-dimensional array, and {<:Integer} requires its elements to be
# integers, <: reading "is a subtype of". It returns the elements of the
# route that are loadings, its shipments in the order they are loaded.
rte2idx(R::AbstractVector{<:AbstractVector}) = rte2idx.(R)
# A second method of the same function, for a vector whose elements are
# themselves vectors, a vector of routes, which {<:AbstractVector}
# requires. Julia runs the method that matches the type of the argument,
# the multiple dispatch of Lecture 1.2, so rte2idx of a route gives its
# shipments, and rte2idx of a vector of routes applies the first method to
# each route, by the dot, and gives the shipments of each.
# a single-shipment route (k, k) for each shipment k on no route
function sh2rte(idx, R)
    idx1 = setdiff(idx, rte2idx(reduce(vcat, R; init = Int[])))
    return [R; [[k, k] for k in idx1]], idx1
end

R, idx1 = sh2rte(1:5, [[1, 2, 1, 2]])
@show idx1                                # on no route
R

# Sec. 4. Load formation
## Model: Load formation
# Model: load formation
function loadform(rteTCh, sh)
    R = [twoopt_rte(r, rteTCh)[1] for r in savings(rteTCh, sh)
         if length(r) > 2]                  # multi-shipment routes
    return sh2rte(1:nrow(sh), R)    # the others, single-shipment routes
end

# Example 9: Load formation for 30 shipments
## Example 9(a): Independent charges
# Determine each shipment's independent transport charge as a P2P TL
# shipment.
# Code block 50: the 30 shipments, and each one's independent charge
shL = DataFrame(
    b = [15, 26, 23, 53, 35, 30, 39, 33, 34, 3, 9, 8, 29, 34, 38,
         32, 18, 17, 4, 4, 7, 30, 33, 22, 6, 19, 16, 8, 37, 14],
    e = [19, 27, 18, 51, 30, 36, 33, 35, 38, 10, 2, 12, 39, 29, 37,
         36, 22, 13, 1, 9, 15, 34, 39, 15, 11, 14, 21, 5, 32, 13])
dL = [D30[b, e] for (b, e) in zip(shL.b, shL.e)]  # D30: Code block 41
c₀ = max.(2.00 .* dL, mincharge_tl())   # = charge_tl, one truckload
sum(c₀)                                 # all 30 shipped independently
# Code block 51: the 30 shipments on a map, by Code block 42's shmtmap
shmtmap(shL, X30)[1]

## Example 9(b): Shipments on no route
# Determine the pairwise savings of the 30 shipments, relative to their
# independent charges, and the shipments in no pair with a positive
# saving, which no route of more than one shipment carries.
# Code block 52: route charge, and the pairwise savings
rTCLh(rte) = max(2.00 * rteTC(rte, shL, D30), mincharge_tl())
@assert all(rTCLh([k, k]) ≈ c₀[k] for k in 1:nrow(shL))
ijs = pairwisesavings(rTCLh, shL)          # positive, largest first
prt(hcat(ijs...)[1:5, :]; cols = ["i", "j", "Saving"],
    row_title = "Pair")                    # the five largest
@show length(ijs[3])                       # pairs with a positive saving
idx1 = setdiff(1:nrow(shL), ijs[1], ijs[2])  # the shipments in none

## Example 9(c): The loads
# Determine the routes and the shipments shipped independently, and the
# charge of the loads.
# Code block 53: load formation on the 30 shipments
RL, indL = loadform(rTCLh, shL)
@assert indL == idx1                    # those in no positive saving
for i in eachindex(RL)                  # the vector of routes
    println("RL[$i] = [", join(RL[i], ","), "]")
end
TCload = sum(rTCLh.(RL))                # a single-shipment route at c₀
# Code block 54: the loads on a map, by Code block 44's rtemap
function rtelabels!(ax, R, at)  # each route's label, placed by hand
    for (i, lon, lat, al) in at
        one = length(R[i]) == 2                    # one shipment
        text!(ax, lon, lat; color = one ? redc : dcc, fontsize = 13,
              font = :bold, align = al, justification = :center,
              text = one ? "Route $i\n(Shmt $(R[i][1]))" : "Route $i")
    end
end
fig, ax = rtemap(RL, shL, X30)
rtelabels!(ax, RL, [(1, -80.62, 35.25, (:left, :center)),
                    (2, -79.33, 36.13, (:left, :center)),
                    (3, -78.70, 35.37, (:center, :top)),
                    (4, -77.54, 35.97, (:center, :bottom)),
                    (5, -81.13, 35.91, (:left, :center))])
fig
