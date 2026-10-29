# 5-rte-1 — generated from 5-rte-1.qmd by tools/qmd_to_jl.py
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

using CairoMakie, DataFrames, GeoMakie, HiGHS, JuMP, Logjam, Random
# Two device pixels per figure unit, as in lectures 3.2 to 4.4, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# The colors the figures share, as in Lecture 4.1
dcc   = colorant"#1e8a3c"               # pickups
ink   = colorant"#252525"
redc  = colorant"#d21f26"               # deliveries, the depot
bluec = colorant"#1f6fb5"               # nodes
# Presentation plumbing for the prose, as in Lectures 4.1 to 4.4: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

## Sec. 1. Traveling salesman problem
# Code block 1: the routing alternatives, a row of stops each
# the colors every figure of the lecture shares
dcc   = colorant"#1e8a3c"                  # pickups
ink   = colorant"#252525"                  # text and arcs
redc  = colorant"#d21f26"                  # deliveries, the depot
bluec = colorant"#1f6fb5"                  # nodes
alts = [  # label, stops, first stop (x, y), stop offsets, empty legs
    ("(a) Point-to-point (P2P)", "PD", 3.72, 0.0, [0, 1.86], Int[]),
    ("(b) Peddling (one-to-many)", "PDDD", 0.0, -1.45,
     [0, 2.53, 3.33, 4.13], Int[]),
    ("(c) Collecting (many-to-one)", "PPPD", 0.0, -2.92,
     [0, 0.8, 1.6, 4.13], Int[]),
    ("(d) Many-to-many", "PPPDDD", 5.3, -1.45,
     [0, 0.8, 1.6, 2.5, 3.3, 4.1], Int[]),
    ("(e) Interleaved", "PDPPDD", 5.3, -2.92,
     [0, 0.8, 1.6, 2.5, 3.3, 4.1], Int[]),
    ("(f) Multiple routes", "PDPDPD", 0.43, -4.51,
     [0, 3.0, 4.75, 5.8, 7.1, 9.0], [2, 4])]
r1 = 0.26                                  # stop radius, data units
fig = Figure(size = (687, 372))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for (lab, s, x0, y0, xs, empty) in alts
    for k in 1:length(s)-1                 # each leg, outline to outline
        lines!(ax, [x0 + xs[k] + r1, x0 + xs[k+1] - r1], [y0, y0];
               color = ink, linewidth = 1.2,
               linestyle = k in empty ? :dash : :solid)
    end
    for (k, c) in enumerate(s)             # each stop over its legs
        col = c == 'P' ? dcc : redc
        poly!(ax, Circle(Point2f(x0 + xs[k], y0), r1); color = :white,
              strokecolor = col, strokewidth = 1.6)
        text!(ax, x0 + xs[k], y0; text = string(c), color = col,
              font = :bold, fontsize = 14, align = (:center, :center))
    end
    text!(ax, x0 + (xs[1] + xs[end]) / 2, y0 - 0.58; text = lab,
          color = ink, fontsize = 13, align = (:center, :center))
end
text!(ax, 3.72 - r1 - 0.12, 0.0; text = "Pickup", color = ink,
      fontsize = 13, align = (:right, :center))
text!(ax, 5.58 + r1 + 0.12, 0.0; text = "Delivery", color = ink,
      fontsize = 13, align = (:left, :center))
# the bracket beside (b) and (c)
lines!(ax, [-0.5, -0.68, -0.68, -0.5], [-1.08, -1.08, -3.25, -3.25];
       color = redc, linewidth = 1.2)
text!(ax, -0.95, -2.165; text = "TSP and VRP", color = redc,
      fontsize = 13, rotation = -pi / 2, align = (:center, :center))
# the first empty leg of (f), bracketed
xe = (0.43 + 3.0 + r1 + 0.04, 0.43 + 4.75 - r1 - 0.04)
lines!(ax, [xe[1], xe[1], xe[2], xe[2]], [-4.36, -4.28, -4.28, -4.36];
       color = bluec, linewidth = 1.0)
text!(ax, sum(xe) / 2, -4.06; text = "empty", color = bluec,
      fontsize = 12, align = (:center, :center))
xlims!(ax, -1.25, 9.75); ylims!(ax, -5.2, 0.4)
fig
# Code block 2: the six-node tour, each arc from the node it leaves
P6 = [0.0 0.0; 0.0 1.2; 0.85 2.0; 1.7 1.2; 1.7 0.0; 0.85 -0.8]  # nodes
r6 = 0.16                                  # node radius, data units
tour = [1, 2, 3, 4, 5, 6, 1]
fig = Figure(size = (300, 300))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for k in 1:length(tour)-1                  # each arc, outline to outline
    p, q = P6[tour[k], :], P6[tour[k+1], :]
    u = (q .- p) ./ hypot((q .- p)...)
    t, h = p .+ r6 .* u, q .- r6 .* u
    arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
              color = ink, shaftwidth = 1.4, tipwidth = 9, tiplength = 9)
end
for i in 1:size(P6, 1)                     # nodes over the arcs
    dep = i == tour[1]                     # the depot, in red
    poly!(ax, Circle(Point2f(P6[i, 1], P6[i, 2]), r6); color = :white,
          strokecolor = dep ? redc : bluec, strokewidth = dep ? 2.4 : 1.6)
    text!(ax, P6[i, 1], P6[i, 2]; text = string(i), color = ink,
          fontsize = 13, align = (:center, :center))
end
text!(ax, -0.25, 0.0; text = "Depot", color = redc, fontsize = 13,
      align = (:right, :center))
xlims!(ax, -1.0, 2.1); ylims!(ax, -1.1, 2.3)
fig
# Code block 3: a tour with crossing arcs, and the arcs that uncross it
PX = [0.0 0.0; 0.74 0.73; 1.79 0.73; 2.53 0.0; 1.79 -0.74; 0.74 -0.74]
rx = 0.13                                  # node radius, data units
crossing = [6, 1, 2, 5, 4, 3, 6]           # arcs 2→5 and 3→6 cross
uncrossed = [(2, 3), (3, 4), (4, 5), (5, 6)]  # 2→3, segment 3-4-5, 5→6
function arc!(ax, i, j; color = ink, dashed = false, off = 0.0)
    p, q = PX[i, :], PX[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    v = [u[2], -u[1]] .* off               # shifted off the black arc
    t, h = p .+ rx .* u .+ v, q .- rx .* u .+ v
    if dashed                              # a dashed shaft, then its head
        lines!(ax, [t[1], h[1] - 0.06u[1]], [t[2], h[2] - 0.06u[2]];
               color = color, linewidth = 1.2, linestyle = :dash)
        scatter!(ax, [h[1] - 0.04u[1]], [h[2] - 0.04u[2]];
                 marker = :rtriangle, rotation = atan(u[2], u[1]),
                 markersize = 8, color = color)
    else
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = color, shaftwidth = 1.3, tipwidth = 8,
                  tiplength = 8)
    end
end
fig = Figure(size = (300, 210))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for k in 1:length(crossing)-1
    arc!(ax, crossing[k], crossing[k+1])
end
for (i, j) in uncrossed                    # beside 4→3 and 5→4, offset
    arc!(ax, i, j; color = redc, dashed = true,
         off = i == 2 || i == 5 ? 0.0 : -0.07)
end
for i in 1:size(PX, 1)                     # nodes over the arcs
    poly!(ax, Circle(Point2f(PX[i, 1], PX[i, 2]), rx); color = :white,
          strokecolor = bluec, strokewidth = 1.6)
end
xlims!(ax, -0.3, 2.85); ylims!(ax, -1.0, 1.0)
fig

# Sec. 2. TSP as a MILP
## Model: Traveling salesman problem
# Model: traveling salesman problem
using JuMP, HiGHS
function subtours(succ)                # the cycles of a successor vector
    S, seen = Vector{Vector{Int}}(), falses(length(succ))
    for k ∈ eachindex(succ)
        seen[k] && continue
        Sₖ, i = Int[], k
        while !seen[i]                 # follow the arcs back to k
            seen[i] = true
            push!(Sₖ, i)
            i = succ[i]
        end
        push!(S, Sₖ)
    end
    return S
end

function TSP(c)
    size(c, 1) == size(c, 2) ||        # assumption (a): each pair's cost
        error("arc costs must be a square matrix")
    V = 1:size(c, 1)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[i ∈ V, j ∈ V; i ≠ j], Bin)    # no arc i to i
    @objective(model, Min,
               sum(c[i, j] * x[i, j] for i ∈ V, j ∈ V if i ≠ j))
    @constraint(model, leave[i ∈ V],
                sum(x[i, j] for j ∈ V if j ≠ i) == 1)          # (a)
    @constraint(model, enter[j ∈ V],
                sum(x[i, j] for i ∈ V if i ≠ j) == 1)          # (b)

    set_silent(model)
    set_attribute(model, "mip_rel_gap", 0.0)
    # HiGHS stops by default once its solution is proved within 0.01% of
    # the optimum; a gap of 0 makes it prove the tour optimal, which the
    # Landmark checks of Ex. 2 and 3 rely on.
    rounds = []
    while true
        optimize!(model)
        termination_status(model) == JuMP.OPTIMAL ||
            error(termination_status(model))
        succ = [findfirst(j -> j ≠ i && value(x[i, j]) > 0.5, V)
        # A solved binary can come back as 0.9999999 rather than 1, so a
        # value above 0.5 is read as 1; each node's successor is the one
        # node its row of $x$ sends it to.
                for i ∈ V]             # the node after each node
        S = subtours(succ)
        push!(rounds, (TC = objective_value(model), S = S))
        if length(S) == 1              # a single tour: done
            return (TC = objective_value(model), tour = [S[1]; S[1][1]],
                    rounds = rounds)
        end
        for Sₖ ∈ S                     # (c), for each subtour found
            @constraint(model,
            # A subtour through the nodes of $S_k$ uses $|S_k|$ arcs among
            # them, and a tour can use at most $|S_k| - 1$, so the subtour
            # just found cannot come back; others can, which is why the
            # loop solves again.
                sum(x[i, j] for i ∈ Sₖ, j ∈ Sₖ if i ≠ j) ≤ length(Sₖ) - 1,
                base_name = "singletour")
        end
    end
end

## Example 1: Ten NC cities
# Determine the minimum great circle distance tour through the ten NC
# cities with a population over 100,000 of {{< xref 4.1 example-2 >}},
# by solving the formulation of @mdl-tsp one round at a time, starting
# from its assignment problem.
# Code block 4: the NC cities over 100,000, from the Logjam gazetteer
using DataFrames, Logjam
df = filter(r -> (r.STFIP == st2fips(:NC)) && (r.POP > 100_000),
            usplace())
select!(df, :NAME, :LAT, :LON, :POP)
prt(df)
# Code block 5: great circle distances, and the TSP solved in rounds
P = hcat(df.LON, df.LAT)               # one row per city
D = dists(P, P, :mi)
nc10 = TSP(D)
rounds = DataFrame(round = eachindex(nc10.rounds),
                   mi = [rd.TC for rd in nc10.rounds],
                   subtours = [length(rd.S) for rd in nc10.rounds])
prt(rounds)
# Code block 6: each round's solution, drawn on a map
# (makemap draws one map per figure, so the three frames are plain axes in
# longitude and latitude, scaled by the cosine of the mean latitude)
(xl, yl) = mapbbox(df.LON, df.LAT; xexpand = 0.14, yexpand = 0.16)
lab = Dict(aligntext(df.LON, df.LAT; offsetamt = 5))
al, os = copy(lab[:align]), copy(lab[:offset])
# moved by hand where, in some round, an arc, the border or another name
# crosses the place Logjam's aligntext gives
for (nm, a, o) in [("Charlotte", (:right, :bottom), (-5, 3)),
                   ("Concord", (:left, :top), (5, -3)),
                   ("High Point", (:left, :top), (4, -4)),
                   ("Durham", (:left, :bottom), (5, 3)),
                   ("Cary", (:right, :top), (-6, -4)),
                   ("Fayetteville", (:right, :top), (-4, -4)),
                   ("Wilmington", (:right, :top), (-3, -4))]
    i = findfirst(==(nm), df.NAME)
    al[i], os[i] = a, o
end
fig = Figure(size = (687, 640))
cells = [fig[1, 1], fig[1, 2], fig[2, 1:2]]
for (k, rd) in enumerate(nc10.rounds)
    nS = length(rd.S)
    ax = Axis(cells[k]; autolimitaspect = 1 / cosd(sum(yl) / 2),
              title = "Round $k: $(round(rd.TC, digits = 2)) mi, " *
                      (nS == 1 ? "one tour" : "$nS subtours"),
              titlesize = 13, titlefont = :regular)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, xl[1] - 0.3, xl[2] + 0.3, yl...)   # room for the names
    lines!(ax, Logjam.usstates()...; color = (bluec, 0.6),
           linewidth = 0.75)
    for Sₖ in rd.S, (a, b) in zip(Sₖ, circshift(Sₖ, -1))
        lines!(ax, [df.LON[a], df.LON[b]], [df.LAT[a], df.LAT[b]];
               color = redc, linewidth = 1.6)
    end
    scatter!(ax, df.LON, df.LAT; color = bluec, markersize = 8)
    text!(ax, df.LON, df.LAT; text = df.NAME, fontsize = k < 3 ? 11 : 12,
          color = ink, align = al, offset = os)
end
rowsize!(fig.layout, 2, Relative(0.6))
fig

# Sec. 3. Two-opt improvement
## Model: Traveling salesman problem
# Model: traveling salesman problem, spacefilling curve construction
# Position θ in [0, 1) of the point (x, y) of the unit square along
# the spacefilling curve, using k binary digits of x and y
function sfcpos(x, y, k = 8)
    if k == 0
        return 0.5                     # center of the last square
    end
    VN = [0 1; 3 2]                    # order the quadrants are visited
    q = VN[min(floor(Int, 2x + 1), 2), min(floor(Int, 2y + 1), 2)]
    s = sfcpos(2abs(x - 0.5), 2abs(y - 0.5), k - 1)  # within q
    if q == 1 || q == 3
        s = 1 - s                      # quadrants 1 and 3 run backward
    end
    θ = (q + s - 0.5) / 4
    return θ - floor(θ)
end

# Tour of the points in the rows of XY in the order of their positions
# along the spacefilling curve, starting and ending at point 1
function tspspfillcur(XY, k = 8)
    x = XY[:, 1]
    y = XY[:, 2]
    if any(XY .< 0) || any(XY .> 1)    # scale to the unit square,
        w = max(maximum(x) - minimum(x), maximum(y) - minimum(y))
        x = (x .- minimum(x)) ./ w     # keeping the aspect ratio
        y = (y .- minimum(y)) ./ w
    end
    θ = sfcpos.(x, y, k)
    loc = sortperm(θ)                  # points in curve order
    i1 = findfirst(loc .== 1)
    return [loc[i1:end]; loc[1:i1-1]; 1]
end

## Sec. 3. Two-opt improvement
# Code block 7: the four points, their positions and their tour
XY4 = [0.8 0.8; 0.1 0.2; 0.3 0.7; 0.7 0.2]       # points 1 to 4
θ4 = sfcpos.(XY4[:, 1], XY4[:, 2])
@show round.(θ4, digits = 3)
@show tspspfillcur(XY4);
# Code block 8: positions on a grid, rows from y = 1 down to y = 0
g = (0:10) ./ 10
Θ = [sfcpos(x, y) for y in reverse(g), x in g]
prt(round.(Θ, RoundNearestTiesAway, digits = 3);
    rows = string.(reverse(g)), cols = string.(g), row_title = "y",
    allfrac = 3)
# Code block 9: the curve, drawn by joining a grid's points in curve order
gr = 0:0.02:1
X = [x for y in gr, x in gr]
Y = [y for y in gr, x in gr]
ij = sortperm(vec(sfcpos.(X, Y)))      # the grid's points in curve order
fig = Figure(size = (360, 360))
ax = Axis(fig[1, 1]; aspect = DataAspect(), xticks = 0:0.2:1,
          yticks = 0:0.2:1, xgridvisible = false, ygridvisible = false)
lines!(ax, vec(X)[ij], vec(Y)[ij]; color = (ink, 0.55), linewidth = 0.5)
# each label on a white card, centred beside its point and clear of the
# tour (the axis is about 300 px across its 0 to 1)
at = XY4 .+ [0.0 0.08; 0.10 -0.07; -0.10 0.07; 0.10 -0.07]
scatter!(ax, at[:, 1], at[:, 2]; marker = Rect, color = :white,
         markersize = fill((76, 26), 4))
r4 = tspspfillcur(XY4)
lines!(ax, XY4[r4, 1], XY4[r4, 2]; color = bluec, linewidth = 2)
scatter!(ax, XY4[:, 1], XY4[:, 2]; color = redc, markersize = 10)
text!(ax, at[:, 1], at[:, 2];
      text = [rich("$i: ", rich(string(round(θ4[i], digits = 3)),
                                color = bluec)) for i in 1:4],
      color = ink, fontsize = 13, align = (:center, :center))
limits!(ax, 0, 1, 0, 1)
fig
# Code block 10: the changes that remove arc a with arc c, and with arc d,
# beside the table of all nine changes
tourarcs = [(1, 2, "a"), (2, 3, "b"), (3, 4, "c"), (4, 5, "d"),
            (5, 6, "e"), (6, 1, "f")]      # 1-2-3-4-5-6-1, lettered
function arc6!(ax, i, j; color = ink, dashed = false, off = 0.0)
    p, q = P6[i, :], P6[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    v = [u[2], -u[1]] .* off               # shifted to the arc's right
    t, h = p .+ r6 .* u .+ v, q .- r6 .* u .+ v
    if dashed                              # a dashed shaft, then its head
        lines!(ax, [t[1], h[1] - 0.11u[1]], [t[2], h[2] - 0.11u[2]];
               color = color, linewidth = 1.3, linestyle = :dash)
        scatter!(ax, [h[1] - 0.09u[1]], [h[2] - 0.09u[2]];
                 marker = :rtriangle, rotation = atan(u[2], u[1]),
                 markersize = 9, color = color)
    else
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = color, shaftwidth = 1.4, tipwidth = 9,
                  tiplength = 9)
    end
end
mid(i, j) = (P6[i, :] .+ P6[j, :]) ./ 2
fig = Figure(size = (687, 360))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for (i, j, lab) in tourarcs                # the tour, each arc lettered
    arc6!(ax, i, j)
    p, q = P6[i, :], P6[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    m = mid(i, j) .- 0.24 .* [u[2], -u[1]]  # outside the tour
    text!(ax, m[1], m[2]; text = lab, color = dcc, fontsize = 15,
          align = (:center, :center))
end
for (i, j, off) in [(1, 3, 0.0), (3, 2, 0.07), (2, 4, 0.0)]   # a with c
    arc6!(ax, i, j; color = redc, dashed = true, off = off)
end
for (i, j, off) in [(1, 4, 0.0), (4, 3, 0.07), (3, 2, -0.07),
                    (2, 5, 0.0)]           # a with d
    arc6!(ax, i, j; color = bluec, dashed = true, off = off)
end
for (i, j, c, dy) in [(1, 2, redc, -0.12), (1, 2, bluec, 0.12),
                      (3, 4, redc, 0.0), (4, 5, bluec, 0.0)]  # removed
    m = mid(i, j)                          # a mark on the arc
    scatter!(ax, [m[1]], [m[2] + dy]; marker = '×', markersize = 22,
             color = c)
end
for i in 1:size(P6, 1)                     # nodes over the arcs
    poly!(ax, Circle(Point2f(P6[i, 1], P6[i, 2]), r6); color = :white,
          strokecolor = bluec, strokewidth = 1.6)
    text!(ax, P6[i, 1], P6[i, 2]; text = string(i), color = ink,
          fontsize = 13, align = (:center, :center))
end
xlims!(ax, -0.6, 2.3); ylims!(ax, -1.1, 2.3)
# the table beside it: the arc letters over the tour, then each change of
# the loop of Code block 11, its reversed segment boxed
tb = Axis(fig[1, 2])
hidedecorations!(tb); hidespines!(tb)
text!(tb, (1:6) .+ 0.5, zeros(6); text = last.(tourarcs), color = dcc,
      font = :bold, fontsize = 15, align = (:center, :center))
text!(tb, 1:7, fill(-1.0, 7); text = string.(tour), color = ink,
      fontsize = 14, align = (:center, :center))
for y in (-0.5, -1.5)                      # the rules around the tour
    lines!(tb, [-0.7, 7.5], [y, y]; color = ink, linewidth = 1.0)
end
changes = [(i, j) for i = 1:length(tour)-2
           for j = i+2:min(length(tour)-1, length(tour)+i-3)]
for (k, (i, j)) in enumerate(changes)
    y = -1.0 - k
    rk = vcat(tour[1:i], reverse(tour[i+1:j]), tour[j+1:end])
    text!(tb, 0.0, y; text = tourarcs[i][3] * "-" * tourarcs[j][3],
          color = dcc, font = :bold, fontsize = 14,
          align = (:center, :center))
    text!(tb, 1:7, fill(y, 7); text = string.(rk), color = ink,
          fontsize = 14, align = (:center, :center))
    c = k == 1 ? redc : k == 2 ? bluec : dcc   # a-c and a-d as drawn
    lines!(tb, [i + 0.6, j + 0.4, j + 0.4, i + 0.6, i + 0.6],
           [y - 0.38, y - 0.38, y + 0.38, y + 0.38, y - 0.38];
           color = c, linewidth = 1.1, linestyle = :dash)
end
xlims!(tb, -0.8, 7.6); ylims!(tb, -10.6, 0.5)
colsize!(fig.layout, 1, Aspect(1, 2.9 / 3.4))   # the tour at its aspect
fig
# Code block 11: the nine 2-opt changes of the tour 1-2-3-4-5-6-1
r = [1:6; 1]
println(r)
for i = 1:length(r)-2
    for j = i+2:min(length(r)-1, length(r)+i-3)
    # $j$ starts two past $i$, so the two arcs removed are never adjacent,
    # and when $i = 1$ it stops one short, since the last arc, back into
    # node 1, is adjacent to the first.
        println(vcat(r[1:i], reverse(r[i+1:j]), r[j+1:end]))
        # The tour up to $r_i$, then the segment from $r_{i+1}$ to $r_j$
        # reversed, then the rest: the arcs out of $r_i$ and out of $r_j$
        # are removed, and arcs from $r_i$ to $r_j$ and from $r_{i+1}$ to
        # $r_{j+1}$ are added.
    end
end

## Model: Traveling salesman problem
logjam_rung(:twoopt, "TSP, two-opt improvement"; keywords = false)
# Model: traveling salesman problem, multi-start
using Random
randtour(n) = (tour = randperm(n); push!(tour, tour[1]))

function multistart(n, rTCh; nruns = 100)
    rᵒ, TCᵒ = nothing, Inf
    for i = 1:nruns
        r, TC = twoopt(randtour(n), rTCh)
        if TC < TCᵒ
            rᵒ, TCᵒ = r, TC
            println(i, ": ", TCᵒ)
        end
    end
    return rᵒ, TCᵒ
end

# Example 2: Six-node tour
## Example 2(a): By hand
# Determine the tour that 2-opt reaches from 1-2-3-4-5-6-1, listing each
# sequence in the order the procedure considers it, with its cost.
# Ex. 2's arc costs, for the figure and the table that follow; Code blocks
# 12 and 13, in Ex. 2(b), show the same
D = [
     0     8     6     9     1     5
     3     0     1     5     4     2
     9     2     0     3     1     1
     8     2     1     0    10     6
     6     7    10     1     0    10
     6     2     5     2     1     0]
rTCh(r) = sum(segcost(r, D))
# The tours of Ex. 2(a), each one the loop of twoopt kept:
# twoopt's loop, as in the pseudocode above, recording every sequence
# it considers and whether it kept it
function twoopt_steps(r, rTCh)
    rᵒ, TCᵒ = copy(r), rTCh(r)
    tried = [(r = copy(r), TC = TCᵒ, kept = true, seg = 1:0)]
    done = false
    while !done
        done = true
        for i = 1:length(r)-2
            for j = i+2:min(length(r)-1, length(r)+i-3)
                r′ = vcat(r[1:i], reverse(r[i+1:j]), r[j+1:end])
                TC = rTCh(r′)
                push!(tried, (r = r′, TC = TC, kept = TC < TCᵒ,
                              seg = i+1:j))   # the positions reversed
                if TC < TCᵒ
                    rᵒ, TCᵒ = r′, TC
                    done = false
                    break
                end
            end
            if done == false
                break
            end
        end
        r = copy(rᵒ)
    end
    return tried
end
tried = twoopt_steps(r, rTCh)
steps = filter(t -> t.kept, tried)     # the start, then each kept tour
function segdist(c, p, q)             # from point c to the segment p-q,
    d = q .- p                         # to keep each label clear
    t = clamp(sum((c .- p) .* d) / sum(d .^ 2), 0, 1)
    return hypot((c .- (p .+ t .* d))...)
end
fig = Figure(size = (687, 270))
for (k, s) in enumerate(steps)
    old = k == 1 ? s.r : steps[k-1].r
    ttl = k == 1 ? rich("start: ", rich("$(s.TC)", color = bluec)) :
          rich("step $(k - 1): ",
               rich("$(steps[k-1].TC)", color = (ink, 0.45)),
               " → ", rich("$(s.TC)", color = bluec))
    ax = Axis(fig[1, k]; aspect = DataAspect(), title = ttl,
              titlesize = 13, titlefont = :regular)
    hidedecorations!(ax); hidespines!(ax)
    oldarcs = [(old[m], old[m+1]) for m in 1:length(old)-1]
    newarcs = [(s.r[m], s.r[m+1]) for m in 1:length(s.r)-1]
    gone = [(i, j) for (i, j) in oldarcs                # removed, not
            if !((i, j) in newarcs || (j, i) in newarcs)]  # reversed
    for (i, j) in gone                 # dashed and crossed out, in ink
        arc6!(ax, i, j; color = (ink, 0.35), dashed = true)
        m = mid(i, j)                  # a mark on the arc, not a label
        scatter!(ax, [m[1]], [m[2]]; marker = '×', markersize = 16,
                 color = ink)
    end
    for (i, j) in newarcs              # each arc, the ones the change adds blue
        arc6!(ax, i, j; color = (i, j) in oldarcs ? ink : bluec)
    end
    segs = [(P6[i, :], P6[j, :]) for (i, j) in [newarcs; gone]]
    placed = Vector{Float64}[]         # the costs labeled so far
    for (i, j) in newarcs              # each cost, given, where it is clearest
        p, q = P6[i, :], P6[j, :]
        u = (q .- p) ./ hypot((q .- p)...)
        w = [-u[2], u[1]]
        cands = [p .+ t .* (q .- p) .+ sg * o .* w
                 for t in 0.2:0.1:0.8, sg in (1, -1), o in (0.24, 0.32)]
        others = [sg for sg in segs if !(sg[1] == p && sg[2] == q)]
        room(c) = minimum([[segdist(c, a, b) for (a, b) in others];
                           [hypot((c .- P6[n, :])...) - r6 for n in 1:6];
                           [hypot((c .- l)...) - 0.2 for l in placed]])
        c = cands[argmax(room.(cands))]
        push!(placed, c)
        text!(ax, c[1], c[2]; text = string(D[i, j]), fontsize = 12,
              color = redc, align = (:center, :center))
    end
    for i in 1:size(P6, 1)             # nodes over the arcs, in ink
        poly!(ax, Circle(Point2f(P6[i, 1], P6[i, 2]), r6);
              color = :white, strokecolor = ink, strokewidth = 1.4)
        text!(ax, P6[i, 1], P6[i, 2]; text = string(i), color = ink,
              fontsize = 12, align = (:center, :center))
    end
    xlims!(ax, -0.5, 2.2); ylims!(ax, -1.15, 2.35)
end
colgap!(fig.layout, 2)
fig

## Example 2(b): In Julia
# Determine the same trace in Julia, and the same tour with Logjam's
# twoopt, and determine whether they agree with Ex. 2(a).
# Code block 12: the arc costs of Ex. 2, and each arc's cost on the tour
D = [
     0     8     6     9     1     5
     3     0     1     5     4     2
     9     2     0     3     1     1
     8     2     1     0    10     6
     6     7    10     1     0    10
     6     2     5     2     1     0]

@show r
segcost(r, D)
# Code block 13: the tour's cost
rTCh(r) = sum(segcost(r, D))
rTCh(r)
# Code block 14: twoopt, printing each sequence it considers
function twoopt_prt(r, rTCh)
    rᵒ, TCᵒ = copy(r), rTCh(r)
    println("*", TCᵒ, ": ", rᵒ)
    done = false
    while !done
        done = true
        for i = 1:length(r)-2
            for j = i+2:min(length(r)-1, length(r)+i-3)
                r′ = vcat(r[1:i], reverse(r[i+1:j]), r[j+1:end])
                TC = rTCh(r′)
                if TC < TCᵒ
                    rᵒ, TCᵒ = r′, TC
                    println("*", TCᵒ, ": ", rᵒ)
                    done = false
                    break
                else
                    println(" ", TC, ": ", r′)
                end
            end
            if done == false
                break
            end
        end
        r = copy(rᵒ)
    end
    return rᵒ, TCᵒ
end

twoopt_prt(r, rTCh)
twoopt(r, rTCh)                        # Code block 15: Logjam's 2-opt

## Example 2(c): Multi-start
# Determine the best tour that multi-start finds from 100 random
# starting tours.
# Code block 16: a random tour, the construction of multi-start
Random.seed!(2024)

@show r = randtour(6);
# Code block 17: multi-start, 2-opt from 100 random tours
n, nruns = 6, 100
rᵒ, TCᵒ = multistart(n, rTCh; nruns)
@show rᵒ
@show TCᵒ;

## Example 2(d): Against the optimum
# Determine the optimal tour, by looking at all 120 tours and by solving
# the formulation of @mdl-tsp, and how far the tours of Ex. 2(a) and
# 2(c) are from it.
# Code block 18: all 120 tours by brute force, and the formulation
using Combinatorics
tours = [[1; p; 1] for p ∈ permutations(2:6)]
TCs = rTCh.(tours)
ex2 = TSP(D)
@show length(tours)                    # the tours looked at
@show minimum(TCs)                     # the cheapest of them
@show count(==(minimum(TCs)), TCs)     # how many are that cheap
@show ex2.TC                           # the formulation's optimum
@show ex2.tour
@show length(ex2.rounds);              # its rounds
# The checks the prose states, and the trace published with this example
@assert steps[1].TC == 38 && steps[end].TC == 12     # 38 to 12, by hand
@assert count(==(minimum(TCs)), TCs) == 1            # one optimal tour
@assert TCᵒ == ex2.TC == minimum(TCs)                # multi-start optimal

## Sec. 4. Expected tour length
# Code block 19: the pairwise saving of two customers served from a DC
PS = [0.0 0.0; 0.15 1.0; 1.1 0.25]     # the DC, customer i, customer j
rs = 0.09                              # node radius, data units
function trip!(ax, i, j; color = ink, dashed = false, off = 0.035)
    p, q = PS[i, :], PS[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    v = [-u[2], u[1]] .* off           # shifted to the trip's left
    e = sqrt(rs^2 - off^2)             # so that it ends on the outline
    t, h = p .+ e .* u .+ v, q .- e .* u .+ v
    if dashed                          # a trip the route saves
        lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = color,
               linewidth = 1.3, linestyle = :dash)
    else
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = color, shaftwidth = 1.4, tipwidth = 9,
                  tiplength = 9)
    end
end
function nodes!(ax, cost)              # the nodes over the trips, labeled
    for (k, name) in enumerate(["DC", L"i", L"j"])
        dc = k == 1                    # the DC, in red
        poly!(ax, Circle(Point2f(PS[k, 1], PS[k, 2]), rs); color = :white,
              strokecolor = dc ? redc : bluec,
              strokewidth = dc ? 2.4 : 1.6)
        text!(ax, PS[k, 1], PS[k, 2]; text = name, color = ink,
              fontsize = dc ? 11 : 16, align = (:center, :center))
    end
    text!(ax, PS[2, 1] / 2 - 0.07, PS[2, 2] / 2; text = L"d_i",
          color = ink, fontsize = 16, align = (:right, :center))
    text!(ax, PS[3, 1] / 2 + 0.03, PS[3, 2] / 2 - 0.07; text = L"d_j",
          color = ink, fontsize = 16, align = (:center, :top))
    text!(ax, 0.5, -0.3; text = cost, color = ink, fontsize = 15,
          align = (:center, :bottom))  # the cost of the trips
    hidedecorations!(ax); hidespines!(ax)
    xlims!(ax, -0.35, 1.35); ylims!(ax, -0.3, 1.2)
    return nothing
end

fig = Figure(size = (687, 320))
ax1 = Axis(fig[1, 1]; aspect = DataAspect())   # individually
trip!(ax1, 1, 2); trip!(ax1, 2, 1)             # two round trips
trip!(ax1, 1, 3); trip!(ax1, 3, 1)
nodes!(ax1, L"2d_i + 2d_j")
Label(fig[2, 1], "(a)"; color = ink, fontsize = 14, tellwidth = false)
ax2 = Axis(fig[1, 2]; aspect = DataAspect())   # together
trip!(ax2, 2, 1; color = (ink, 0.45), dashed = true)  # the trips saved
trip!(ax2, 1, 3; color = (ink, 0.45), dashed = true)
trip!(ax2, 1, 2); trip!(ax2, 3, 1)             # one route,
trip!(ax2, 2, 3; off = 0.0)                    # with the arc between
text!(ax2, sum(PS[2:3, 1]) / 2 + 0.02, sum(PS[2:3, 2]) / 2 + 0.02;
      text = L"d_{ij}", color = ink, fontsize = 16,
      align = (:left, :bottom))
nodes!(ax2, L"d_i + d_{ij} + d_j")
Label(fig[2, 2], "(b)"; color = ink, fontsize = 14, tellwidth = false)
fig
# Code block 20: the two-customer route in a circle of radius 1
fig = Figure(size = (330, 330))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
θ = range(0, 2π, length = 361)
lines!(ax, cos.(θ), sin.(θ); color = bluec, linewidth = 1.6)  # r = 1
lines!(ax, (2/3) .* cos.(θ), (2/3) .* sin.(θ); color = dcc,
       linewidth = 1.3, linestyle = :dash)     # the expected distance
d = 2 / 3
arrows2d!(ax, [0.0, 0.0, d], [0.0, d, 0.0], [0.0, d, -d], [d, -d, 0.0];
          color = ink, shaftwidth = 1.4, tipwidth = 9, tiplength = 9)
lines!(ax, [0.0, 0.08, 0.08], [0.08, 0.08, 0.0]; color = ink,
       linewidth = 1.0)                        # the right angle
arrows2d!(ax, [0.0], [0.0], [cosd(-45)], [sind(-45)]; color = bluec,
          shaftwidth = 1.2, tipwidth = 8, tiplength = 8)
scatter!(ax, [0.0], [0.0]; color = ink, markersize = 7)
text!(ax, -0.05, -0.02; text = "DC", color = ink, fontsize = 13,
      align = (:right, :top))
text!(ax, -0.05, d / 2; text = L"\frac{2}{3}", color = ink, fontsize = 15,
      align = (:right, :center))
text!(ax, 0.47, -0.04; text = L"\frac{2}{3}", color = ink, fontsize = 15,
      align = (:center, :top))
text!(ax, d / 2 - 0.035, d / 2 - 0.035;       # inside the triangle,
      text = L"\sqrt{2(2/3)^2}", color = ink, # clear of the dashed circle
      fontsize = 14, rotation = -π / 4, align = (:center, :top))
text!(ax, 0.82cosd(-45) + 0.025cosd(45),
      0.82sind(-45) + 0.025sind(45);
      text = L"r = 1", color = bluec, fontsize = 13, rotation = -π / 4,
      align = (:center, :bottom))              # between the two circles
text!(ax, 0.0, 1.0 - 0.06; text = L"a = \pi", color = ink, fontsize = 15,
      align = (:center, :top))
xlims!(ax, -1.08, 1.08); ylims!(ax, -1.08, 1.08)
fig
# Code block 21: the average angle between two random points, simulated
Random.seed!(1)
absdiffdeg(a, b) = min(360 - mod(a - b, 360), mod(a - b, 360))
# mod gives the angle from $b$ to $a$ going one way around the circle,
# between 0 and 360; the smaller of it and the rest of the circle is the
# angle between them.
n = 10^6
sims = DataFrame(span = [360, 180], min = 0.0, max = 0.0, mean = 0.0)
for row in eachrow(sims)
    x, y = rand(n) * row.span, rand(n) * row.span
    ang = absdiffdeg.(x, y)            # abs difference between two angles
    row.min, row.max, row.mean = minimum(ang), maximum(ang), sum(ang) / n
end
prt(sims)
# Code block 22: customers spread uniformly, and the square each one has
Random.seed!(242)
mpts = 300                             # customers in the circle
P = Matrix{Float64}(undef, 0, 2)
while size(P, 1) < mpts                # uniform in the unit disk,
    global P                           # a script's `while`: soft scope
    p = 2 .* rand(1, 2) .- 1           # by rejection from the square
    if sum(p .^ 2) < 1
        P = [P; p]
    end
end
fig = Figure(size = (687, 320))
ax1 = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax1); hidespines!(ax1)
θ = range(0, 2π, length = 361)
lines!(ax1, cos.(θ), sin.(θ); color = bluec, linewidth = 1.6)
scatter!(ax1, P[:, 1], P[:, 2]; color = redc, markersize = 3)
scatter!(ax1, [0.0], [0.0]; color = ink, markersize = 7)
# each label where the customers leave it the most room
gap(c) = minimum(hypot.(P[:, 1] .- c[1], P[:, 2] .- c[2]))
cDC = argmax(gap, [r .* (cosd(t), sind(t))
                   for t in 0:15:345 for r in (0.14, 0.17)])
ca = argmax(gap, [(x, y) for x in -0.7:0.02:-0.4
                  for y in 0.4:0.02:0.7 if hypot(x, y) < 0.8])
text!(ax1, cDC...; text = "DC", color = ink, fontsize = 12,
      align = (:center, :center))
text!(ax1, ca...; text = L"a", color = ink, fontsize = 18,
      align = (:center, :center))
Label(fig[2, 1], "(a)"; color = ink, fontsize = 14,
      tellwidth = false)               # caption below
b = (0.45, -0.05, 0.14)                # the square (b) zooms into
lines!(ax1, [b[1], b[1] + b[3], b[1] + b[3], b[1], b[1]],
       [b[2], b[2], b[2] + b[3], b[2] + b[3], b[2]]; color = ink,
       linewidth = 1.0)
Label(fig[1, 2], "→"; fontsize = 30, color = ink, tellheight = false)
ax2 = Axis(fig[1, 3]; aspect = DataAspect())
hidedecorations!(ax2); hidespines!(ax2)
for i in 0:2, j in 0:2                 # one customer per square
    lines!(ax2, [i, i + 1, i + 1, i, i], [j, j, j + 1, j + 1, j];
           color = (ink, 0.6), linestyle = :dash, linewidth = 0.9)
    scatter!(ax2, [i + 0.5], [j + 0.5]; color = redc, markersize = 12)
end
lines!(ax2, [1, 2, 2, 1, 1], [2, 2, 3, 3, 2]; color = ink, linewidth = 2)
text!(ax2, 1.5, 3.1;
      text = L"\frac{1}{\sqrt{\delta}} = \sqrt{\frac{a}{m}}",
      color = ink, fontsize = 15, align = (:center, :bottom))
text!(ax2, 3.1, 1.5; text = L"\sqrt{\frac{a}{m}}", color = ink,
      fontsize = 15, align = (:left, :center))
Label(fig[2, 3], "(b)"; color = ink, fontsize = 14,
      tellwidth = false)               # caption below
xlims!(ax1, -1.05, 1.05); ylims!(ax1, -1.05, 1.05)
xlims!(ax2, -0.2, 4.0); ylims!(ax2, -0.2, 3.9)
colsize!(fig.layout, 1, Relative(0.47))
fig
# Code block 23: the estimate against optimal and 2-opt tours
function disk(m)                     # m points uniform in the unit disk,
    P = Matrix{Float64}(undef, 0, 2) # by rejection from the square
    while size(P, 1) < m
        p = 2 .* rand(1, 2) .- 1
        # A point uniform in the square from $-1$ to 1 is kept only if it
        # falls inside the unit circle, which leaves the kept points
        # uniform over the circle; about $\pi/4$ of them, 79%, are kept.
        # Code block 22 draws its customers the same way.
        if sum(p .^ 2) < 1
            P = [P; p]
        end
    end
    return P
end
φ = 2(sqrt(2) + 1) / (3sqrt(π))
Random.seed!(150)
est = DataFrame(m = Int[], reps = Int[], estimate = Float64[],
                exact = Float64[], twoopt = Float64[])
for m in (2, 5, 10, 20, 50, 100, 200)
    reps = 1000 ÷ m                             # 1,000 customers per m
    Ps = [[0.0 0.0; disk(m)] for _ in 1:reps]   # the DC at the center
    Ds = [dists(P, P, 2) for P in Ps]           # Euclidean
    TC = m ≤ 50 ? [TSP(D).TC for D in Ds] : [NaN]   # exact, to m = 50
    TC2 = [twoopt([1:m+1; 1], r -> sum(segcost(r, D)))[2]
    # 2-opt starts from the tour that visits the customers in the order
    # they were drawn, which is itself a random tour, so it needs no
    # random start of its own.
           for D in Ds]
    push!(est, (m, reps, φ * sqrt(m * π), sum(TC) / length(TC),
                sum(TC2) / reps))
end
est.ratio = est.estimate ./ est.exact
est.ratio2opt = est.estimate ./ est.twoopt
prt(est)

# Sec. 4. Expected tour length
# Example 3: Tour of North Carolina
## Example 3(a): Estimate first
# Determine the length of the tour that @eq-tsp-est estimates, before
# any tour is built.
# Code block 24: the NC counties, from the Logjam gazetteer
df = filter(r -> (r.STFIP == st2fips(:NC)), uscounty());
# Code block 25: the estimated length of the tour
@show a = sum(df.ALAND) + sum(df.AWATER)
@show TCᴱ = 0.908sqrt(nrow(df)*a);
# The numbers the display above sets, held to the code
@assert round(a, digits = 2) == 53818.56
@assert round(sqrt(nrow(df) * a), digits = 2) == 2319.88
@assert round(TCᴱ, digits = 2) == 2106.45
# F24's published estimate, made with 0.9, on the same data
@assert round(0.9sqrt(nrow(df) * a), digits = 2) == 2087.89

## Example 3(b): Multi-start 2-opt
# Determine the best tour that 2-opt finds from 100 random starting
# tours, under great circle distances.
# Code block 26: great circle distances between the county points
XY = hcat(df.LON, df.LAT)
D = dists(XY, XY, :mi);
# Code block 27: a random tour of the counties, and its cost
Random.seed!(2024)
r = randtour(nrow(df))
@show rTCh(r);
# Code block 28: the random tour on a map
fig, ax = makemap(df.LON, df.LAT; xexpand=0.05)
resize!(fig, 687, 300)
lines!(ax, df.LON[r], df.LAT[r], color=:red, linewidth=.5)
fig
# Code block 29: multi-start, 2-opt from 100 random tours of the counties
Random.seed!(2024)

n, nruns = nrow(df), 100
rᵒ, TCᵒ = multistart(n, rTCh; nruns);
# Code block 30: the best tour on a map
fig, ax = makemap(df.LON, df.LAT; xexpand=0.05)
resize!(fig, 687, 300)
lines!(ax, df.LON[rᵒ], df.LAT[rᵒ], color=:red, linewidth=.5)
fig

## Example 3(c): Against the optimum
# Determine the optimal tour, by solving the formulation of @mdl-tsp,
# and how far the estimate and the multi-start tour are from it.
# Code block 31: the optimal tour of the counties, by the formulation
nc = TSP(D)
@show round(nc.TC, digits = 2)
@show length(nc.rounds);
# Code block 32: the spacefilling curve's tour, and that tour after 2-opt
rsfc = tspspfillcur(XY)
rsfc2, TCsfc2 = twoopt(rsfc, rTCh)
@show round(rTCh(rsfc), digits = 2)
@show round(TCsfc2, digits = 2);
# Code block 33: each tour and estimate of Ex. 3 against the optimum
cmp = DataFrame(tour = ["estimate", "multi-start 2-opt", "optimal"],
                mi = [TCᴱ, TCᵒ, nc.TC])
cmp.above = 100 .* (cmp.mi ./ nc.TC .- 1)      # % above the optimum
prt(cmp)
# The answers Ex. 3 gives, the second published with this example
@assert round(TCᴱ, digits = 2) == 2106.45          # the estimate, 0.908
@assert round(TCᵒ, digits = 2) == 2141.21          # 100 random starts

## Example 3(d): On the roads
# Determine the optimal tour of the counties on the road miles of
# Logjam's FAF5 road network, and how much the circuity factor of 1.2 of
# Lecture 2.2, Sec. 7, and the estimate of @eq-tsp-est must be adjusted
# to match it.
# Code block 34: road distances between the county points, on FAF5
using SimpleWeightedGraphs
N, L = prune_reindex(faf5nodes(), faf5links())   # nodes numbered from 1
Nc, Lc = cropnetwork(N, L, df.LON, df.LAT)       # a box around the points
Nc, Lc = addconnectors(Nc, Lc, df.LON, df.LAT; add_nf_nf = false)
fw, bw = Lc.DIR .!= -1, Lc.DIR .!= 1             # each link's directions
g = SimpleWeightedDiGraph([Lc.SRC[fw]; Lc.DST[bw]],
                          [Lc.DST[fw]; Lc.SRC[bw]],
                          [Lc.DIST[fw]; Lc.DIST[bw]]; combine = min)
Dr, Pr = shortestpaths(g, nrow(df))              # road mi, and the paths

# every pair of different points, and those under 50 mi apart
off = [i ≠ j for i in 1:nrow(df), j in 1:nrow(df)]
short = off .& (D .< 50)
@show all(Dr[off] .≥ D[off])           # no road below great circle
@show sum(Dr[off]) / sum(D[off])       # circuity, all pairs
@show sum(Dr[short]) / sum(D[short]);  # circuity under 50 mi
# Code block 35: the optimal tour on road miles
ncr = TSP(Dr)
@show 1.2nc.TC                         # great circle optimum, x 1.2
@show sum(segcost(nc.tour, Dr))        # the great circle tour, driven
@show ncr.TC                           # the road optimum
@show ncr.TC / (φ * sqrt(nrow(df) * a)); # factor the estimate needs
# Code block 36: the optimal road tour, each leg along its roads
legs = zip(ncr.tour[1:end-1], ncr.tour[2:end])
path = reduce(vcat, [tracepath(Pr[i], i, j)[1:end-1] for (i, j) in legs])
push!(path, path[1])                       # back to where it started
fig, ax = makemap(df.LON, df.LAT; xexpand = 0.05)
resize!(fig, 687, 300)
lines!(ax, Nc.LON[path], Nc.LAT[path]; color = redc, linewidth = 1.2)
scatter!(ax, df.LON, df.LAT; color = ink, markersize = 4)
# each Interstate labeled beside its link nearest a chosen point, from the
# sign FAF5 gives each link; the cities from the gazetteer
sg = coalesce.(Lc.SIGN, "")
function near(s, lon, lat)                 # the link of sign s nearest
    k = findall(==(s), sg)
    x = (Nc.LON[Lc.SRC[k]] .+ Nc.LON[Lc.DST[k]]) ./ 2
    y = (Nc.LAT[Lc.SRC[k]] .+ Nc.LAT[Lc.DST[k]]) ./ 2
    j = argmin(hypot.(x .- lon, y .- lat))
    return x[j], y[j]
end
signs = [("I 40", -81.0, 35.75, (:center, :top), (0, -6)),
         ("I 85", -79.6, 35.55, (:left, :top), (4, 0)),
         ("I 95", -78.0, 35.2, (:left, :center), (4, 0)),
         ("I 77", -80.9, 36.3, (:right, :center), (4, 0)),
         ("I 26", -82.45, 35.3, (:left, :bottom), (5, 4))]
for (s, lon, lat, al, off) in signs
    text!(ax, near(s, lon, lat)...; text = replace(s, " " => "-"),
          fontsize = 10, color = (ink, 0.7), font = :bold, align = al,
          offset = off)
end
places = [("Raleigh", (:left, :center), (6, 0)),      # each clear
          ("Charlotte", (:right, :top), (-14, -14)),  # of the tour
          ("Wilmington", (:left, :top), (5, -4)),
          ("Asheville", (:left, :bottom), (14, 14))]
for (nm, al, off) in places
    c = only(filter(r -> r.STFIP == st2fips(:NC) && r.NAME == nm,
                    usplace()))
    text!(ax, c.LON, c.LAT; text = nm, fontsize = 11, color = ink,
          align = al, offset = off)
end
fig
