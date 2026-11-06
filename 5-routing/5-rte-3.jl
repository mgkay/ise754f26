# 5-rte-3 — generated from 5-rte-3.qmd by tools/qmd_to_jl.py
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
using CairoMakie, CSV, DataFrames, GeoMakie, HiGHS, JuMP, Logjam, Random
# Two device pixels per figure unit, as in lectures 3.2 to 5.1, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# The colors the figures share, as in Lectures 4.1 and 5.1
dcc   = colorant"#1e8a3c"               # pickups
ink   = colorant"#252525"
redc  = colorant"#d21f26"               # deliveries, the depot
bluec = colorant"#1f6fb5"               # nodes
# Presentation plumbing for the prose, as in Lectures 4.1 to 5.1: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end
# Presentation plumbing for the route figures, as in Lecture 5.2: an
# arrowhead partway along each leg of a route through x, y, so its
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

# Sec. 1. Vehicle routing problem
## Model: Vehicle routing from a depot
# apparatus.jl ships beside the lectures in the materials
# repository. Find it from the activated project rather
# than from this file, so the script still works from a
# copy under work/.
let p = dirname(Base.active_project())
    include(joinpath(basename(p) == "env" ? dirname(p) : p,
                     "_common", "julia", "apparatus.jl"))
end
logjam_rung(:savings, "Vehicle routing from a depot, savings construction")

# Example 1: Clarke-Wright savings with capacity
## Example 1(a): By brute force
# Determine the routes of least total cost that serve every customer
# within the capacity, by enumerating every way of dividing the
# customers among routes.
# Code block 1: the depot, the customers and their demands
XYcw = [0.463 0.478; 0.118 0.671; 0.896 0.273   # where nodes 1 to 6 lie
        0.542 0.846; 0.507 0.148; 0.864 0.738]
qcw = [0, 8, 5, 4, 7, 6]                         # each node's demand
function cwnodes!(ax)  # the nodes, and each demand away from the depot
    scatter!(ax, XYcw[2:end, 1], XYcw[2:end, 2]; color = :white,
             strokecolor = ink, strokewidth = 1.5, markersize = 22)
    scatter!(ax, [XYcw[1, 1]], [XYcw[1, 2]]; marker = :rect,
             color = colorant"#f2d9a0", strokecolor = ink,
             strokewidth = 1.5, markersize = 22)  # the depot
    text!(ax, XYcw[:, 1], XYcw[:, 2]; text = string.(1:6), color = ink,
          fontsize = 12, align = (:center, :center))
    for c in 2:6
        d = XYcw[c, :] .- XYcw[1, :]           # away from the depot
        u = d ./ hypot(d...)
        text!(ax, XYcw[c, 1] + 0.075u[1], XYcw[c, 2] + 0.075u[2];
              text = string(qcw[c]), color = redc, fontsize = 12,
              font = :bold, align = (:center, :center))
    end
end
let fig = Figure(size = (280, 260), figure_padding = 4)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    cwnodes!(ax)
    xlims!(ax, 0.02, 0.99); ylims!(ax, 0.05, 0.94)
    fig
end
# Code block 2: every partition into routes that fit, by brute force
using Combinatorics
Ccw = [ 0  40  48  38  33  48   # the costs of Ex. 5 of Lecture 5.2
       40   0  87  46  65  75
       48  87   0  67  41  47
       38  46  67   0  70  34
       33  65  41  70   0  69
       48  75  47  34  69   0]
K = 15                          # the vehicle's capacity
besttour(S) =                   # a route's customers in their best order
    minimum((sum(segcost([1; p; 1], Ccw)), [1; p; 1])
    # Each order of a route's customers is paired with its cost, and
    # minimum compares the pairs by cost first, so it returns the least
    # cost together with its order, as Code block 4 of Lecture 5.2 does
    # for routes.
            for p in permutations(S))
BF = DataFrame(Vehicles = Int[], TC = Int[], Routes = String[])
for P in partitions(2:6)
# partitions(2:6), from the Combinatorics package, generates every
# partition of customers 2 to 6, one at a time. A partition divides a set
# into non-empty, disjoint subsets whose union is the set, so each P is
# one way of dividing the customers among routes, a vector of subsets such
# as [[2, 5], [3, 4, 6]], a route for each subset.
    all(S -> sum(qcw[S]) <= K, P) || continue  # a route over capacity
    tours = besttour.(P)
    rs = ["(" * join(r, ",") * ")" for r in last.(tours)]  # as text
    push!(BF, (length(P), sum(first.(tours)), join(rs, " ")))
end
sort!(BF, :TC)                  # least TC first
@show length(partitions(2:6))   # the partitions looked at
@show nrow(BF)                  # those in which every route fits
prt(first(BF, 3))

## Example 1(b): By hand
# Determine the routes Clarke-Wright constructs, pair by pair, refusing
# any join that would exceed the capacity.
# The starting state, then a frame per join; hidden, since Ex. 1(b) is by hand
let steps = [(nothing, "(a) Start: each customer out and back", Vector{Int}[]),
             ((4, 6), "(b) Step 1: (4, 6), new route", [[1, 4, 6, 1]]),
             ((3, 6), "(c) Step 2: (3, 6), add 3", [[1, 4, 6, 3, 1]]),
             ((2, 5), "(d) Step 8: (2, 5), new route",
              [[1, 4, 6, 3, 1], [1, 2, 5, 1]])]
    fig = Figure(size = (560, 520), figure_padding = 4)
    for (k, (ij, what, R)) in enumerate(steps)  # a frame a step
        ax = Axis(fig[(k - 1) ÷ 2 + 1, (k - 1) % 2 + 1];
                  aspect = DataAspect(), xlabel = what, xlabelsize = 13)
        hidedecorations!(ax; label = false)     # its subcaption below it
        hidespines!(ax)
        served = isempty(R) ? Int[] : reduce(vcat, R)
        for c in setdiff(2:6, served)           # out and back
            lines!(ax, XYcw[[1, c], 1], XYcw[[1, c], 2];
                   color = (ink, 0.6), linestyle = :dot, linewidth = 1.5)
        end
        for r in R                              # each route, the pair in red
            lines!(ax, XYcw[r, 1], XYcw[r, 2]; color = bluec,
                   linewidth = 2.5)
            legc = [ij !== nothing && Set(r[i:i+1]) == Set(ij) ? redc :
                    bluec for i in 1:length(r)-1]
            legarrows!(ax, XYcw[r, 1], XYcw[r, 2]; color = legc, size = 11)
        end
        ij === nothing || lines!(ax, XYcw[collect(ij), 1],
                                 XYcw[collect(ij), 2]; color = redc,
                                 linewidth = 4)  # the pair joined
        cwnodes!(ax)
        xlims!(ax, 0.02, 0.99); ylims!(ax, 0.05, 0.94)
    end
    fig
end

## Example 1(c): In Julia
# Determine the routes Logjam's savings procedure constructs with the
# capacity in the route cost, and compare them and their savings with
# those of Ex. 1(a) and 1(b).
# Code block 3: the route functions of Lecture 5.2
rtesegsum(r, x) =                  # each segment's sum of x on board
    cumsum(x[r] .* ifelse.(isorigin(r), 1, -1))[1:end-1]
function twoopt_rte(r, rTCh)       # 2-opt that keeps r a route
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
rte2idx(r::AbstractVector{<:Integer}) = r[isorigin(r)]  # its shipments
rte2idx(R::AbstractVector{<:AbstractVector}) = rte2idx.(R)  # per route
# Code block 4: savings, with the capacity in the route cost
shcw = DataFrame(b = ones(Int, 5), e = [2:6;], q = qcw[2:6])
tr = (b = 1, e = 1)
function rTCcwh(rte)          # its cost, or Inf if over capacity
    TC = rteTC(rte, shcw, Ccw, tr)
    return sum(shcw.q[unique(rte)]) <= K ? TC : Inf
end
R1 = [twoopt_rte(r, rTCcwh)[1] for r in savings(rTCcwh, shcw)]
@show rTCcwh.(R1)
[rte2loc(r, shcw, tr) for r in R1]   # each route's location sequence
# Code block 5: the pairwise savings, largest first, as nodes
ijs = pairwisesavings(rTCcwh, shcw)
prt(hcat(ijs[1] .+ 1, ijs[2] .+ 1, ijs[3]); cols = ["i", "j", "Saving"],
    row_title = "Pair")

# Example 2: Thirty NC customers
## Example 2(a): No constraint
# Determine the tour that savings and 2-opt construct from the depot
# through all 30 customers, and how it compares with the optimal tour.
# Code block 6: the depot and the 30 customers, and their distances
xy = CSV.read("data/shmtNC30-xy.csv", DataFrame)   # the 54 locations
sh0 = CSV.read("data/shmtNC30-sh.csv", DataFrame)  # the 30 shipments
e1 = sh0.e[1]                                # shipment 1's destination
X = Matrix(xy[[e1; sh0.b], [:x, :y]])        # the depot, then customers
D = dists(X, X, :mi) * 1.2                   # road miles, circuity 1.2
n = nrow(sh0)                                # 30 customers
sh = DataFrame(b = ones(Int, n), e = [2:n+1;])  # a delivery to each
tr = (b = 1, e = 1)                          # each route from the depot
prt(first(hcat(sh, sh0[:, [:q, :s]]), 5))    # the first 5 of 30
# Code block 7: the depot and the customers on a map
function basemap(x, y; roads = false)  # makemap around the points, its
    # borders in gray, and its interstates faded behind them if roads;
    # close at the sides, tall enough to show the state's borders whole
    fig, ax = makemap(x, y; xexpand = 0.02, yexpand = 0.12,
                      doRoadbkgd = roads)
    for p in ax.scene.plots          # the state borders, drawn opaque;
        to_color(p.color[]).alpha < 1 && continue    # the roads are faded
        p.color, p.linewidth = (ink, 0.45), 1.5
    end
    return fig, ax
end
rtecols = [bluec, dcc, colorant"#c26a00", colorant"#7b3294", redc,
           colorant"#8c564b", colorant"#d6439a", colorant"#0f8f9e"]
rtecol(k) = rtecols[mod1(k, length(rtecols))]    # route k's color
function rtelabels!(ax, R, sh, X, tr, lab)  # each route's number at the
    # centroid of its stops, in its color; lab = (align, offset), one of
    # each a route, moves each clear of every line (placed by hand)
    n = length(R)
    al, off = something(lab, (fill((:center, :center), n),
                              fill((0, 0), n)))  # unplaced: centered
    c = [let loc = filter(!=(tr.b), rte2loc(r, sh, tr))  # not the depot
             (sum(X[loc, 1]) / length(loc), sum(X[loc, 2]) / length(loc))
         end for r in R]
    return text!(ax, first.(c), last.(c); text = string.(1:n),
                 color = rtecol.(1:n), font = :bold, fontsize = 13,
                 align = al, offset = off)
end
function fitmap!(fig, ax)  # the figure's height fitted to the map
    lim = ax.finallimits[]
    resize!(fig, 600,
            round(Int, 600 * lim.widths[2] / lim.widths[1]) + 10)
    return fig
end
function milabel!(ax, what, d)  # a distance, at the map's lower left
    s = commas(round(d, digits = 2))
    s = "$what: $(rpad(s, findfirst('.', s) + 2, '0')) mi"
    return text!(ax, 0.02, 0.03; text = s, space = :relative,
                 color = ink, fontsize = 13, font = :bold,
                 align = (:left, :bottom))
end
function depot!(ax, X)  # the depot, a tan square over everything
    return scatter!(ax, [X[1, 1]], [X[1, 2]]; marker = :rect,
                    color = colorant"#f2d9a0", strokecolor = ink,
                    strokewidth = 1.5, markersize = 13)
end
function vrpmap(R, sh, X, tr; lab = nothing)  # each route from the depot
    x, y = X[:, 1], X[:, 2]                     # and back, in its color
    fig, ax = basemap(x, y)
    for (k, r) in enumerate(R)
        loc = rte2loc(r, sh, tr)
        lines!(ax, x[loc], y[loc]; color = rtecol(k), linewidth = 1.2)
        legarrows!(ax, x[loc], y[loc]; color = rtecol(k), onmap = true,
                   size = 7, every = 2)
    end
    scatter!(ax, x[2:end], y[2:end]; color = ink, markersize = 4)
    depot!(ax, X)
    fitmap!(fig, ax)
    tp = length(R) > 1 ? rtelabels!(ax, R, sh, X, tr, lab) : nothing
    return fig, ax, tp                          # tp: the routes' numbers
end
fig, ax = basemap(X[:, 1], X[:, 2]; roads = true)
scatter!(ax, X[2:end, 1], X[2:end, 2]; color = ink, markersize = 5)
depot!(ax, X)
fitmap!(fig, ax)
# Code block 8: savings, then 2-opt, with no constraint
rTDh(rte) = rteTC(rte, sh, D, tr)
r1 = twoopt_rte(savings(rTDh, sh)[1], rTDh)[1]
@show length(r1)        # a pickup and a delivery for each shipment
TD1 = rTDh(r1)
# Code block 9: the TSP formulation of Lecture 5.1
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
    rounds = []
    while true
        optimize!(model)
        termination_status(model) == JuMP.OPTIMAL ||
            error(termination_status(model))
        succ = [findfirst(j -> j ≠ i && value(x[i, j]) > 0.5, V)
                for i ∈ V]             # the node after each node
        S = subtours(succ)
        push!(rounds, (TC = objective_value(model), S = S))
        if length(S) == 1              # a single tour: done
            return (TC = objective_value(model), tour = [S[1]; S[1][1]],
                    rounds = rounds)
        end
        for Sₖ ∈ S                     # (c), for each subtour found
            @constraint(model,
                sum(x[i, j] for i ∈ Sₖ, j ∈ Sₖ if i ≠ j) ≤ length(Sₖ) - 1,
                base_name = "singletour")
        end
    end
end
# Code block 10: the optimal tour, and every customer out and back
TDᵒ = TSP(D).TC
@show TDᵒ                            # the optimal tour
@show sum(rTDh([k, k]) for k in 1:n)   # every customer out and back
TD1 / TDᵒ - 1                        # the tour, above the optimum
# Code block 11: the tour on a map
fig, ax = vrpmap([r1], sh, X, tr)                 # Code block 7
milabel!(ax, "Savings and 2-opt, no constraint", TD1)
fig

## Example 2(b): Capacity
# Determine the routes with a truck that carries at most 25 tons and
# 2,750 ft³, first by a route cost of one's own and then by a route cost
# that reads the truck's capacity, and each route's weight and cube.
# Code block 12: Logjam's rteTC does not read a truck's capacity
sh.q, sh.s = sh0.q, sh0.s                # each shipment's weight, density
tr = (b = 1, e = 1, Kwt = 25, Kcu = 2750)
cu = 2000sh.q ./ sh.s                    # each shipment's cube, ft³
@show sum(sh.q[rte2idx(r1)])             # the tour's weight, t
@show sum(cu[rte2idx(r1)])               # and cube: more than 2,750
rteTC(r1, sh, D, tr)                     # a cost all the same
# Code block 13: capacity in a route cost of one's own
function rTDh(rte)
    rTD = rteTC(rte, sh, D, tr)
    idxsh = unique(rte)
    wtfeas = sum(sh.q[idxsh]) <= tr.Kwt
    # A route exactly at the capacity is feasible: a route is infeasible
    # only when its load exceeds the capacity.
    cufeas = sum(2000sh.q[idxsh] ./ sh.s[idxsh]) <= tr.Kcu
    return wtfeas && cufeas ? rTD : Inf
end
@show rTDh(r1)                           # the tour: over capacity
R2 = [twoopt_rte(r, rTDh)[1] for r in savings(rTDh, sh)]
TD2 = rTDh.(R2)
# Code block 14: each route's distance, weight and cube
Wt = [sum(sh.q[rte2idx(r)]) for r in R2]
Cube = [sum(cu[rte2idx(r)]) for r in R2]
prt(DataFrame(TD = TD2, Wt = Wt, Cube = Cube))
# Code block 15: rteTC_vrp, a route's cost, exit flag and schedule, with
# capacity, loading and unloading, a maximum cost and time windows
function rte2ldmx(rte)  # the shipments on board at each load mix
    isL, on, ld = isorigin(rte), Int[], Vector{Int}[]
    for i in 1:length(rte)-1
        isL[i] ? push!(on, rte[i]) : filter!(!=(rte[i]), on)
        isL[i] && !isL[i+1] && push!(ld, copy(on))  # a load mix
    end
    return ld
end

function rteTC_vrp(rte::AbstractVector{<:Integer}, sh, C, tr = (;))
    has(f) = hasproperty(sh, f)                 # a column of sh?
    col(f, v) = has(f) ? float.(sh[rte, f]) : fill(v, length(rte))
    isL, istr = isorigin(rte), haskey(tr, :b)   # truck's b and e?
    loc = rte2loc(rte, sh, istr ? tr : (b = [], e = []))
    Xflg = 1
    if istr && tr.b == tr.e        # back at the truck's location early:
        k = filter(!=(0), diff(loc[2:end-1] .== tr.b))  # two routes
        (length(k) > 2 || length(k) == 2 && k != [-1, 1]) && (Xflg = -1)
    end
    if Xflg > 0 && has(:q)                      # each load mix's
        for ld in rte2ldmx(rte)                 # weight and cube
            if haskey(tr, :Kwt) && sum(sh.q[ld]) > tr.Kwt
                Xflg = -2; break
            elseif haskey(tr, :Kcu) && 2000sum(sh.q[ld] ./ sh.s[ld]) >
                   tr.Kcu + 0.01sqrt(eps())     # a rounding tolerance
                Xflg = -3; break
            end
        end
    end
    Xflg < 0 && return Inf, Xflg, DataFrame()
    t = [k == 1 || loc[k] == loc[k-1] ? zero(eltype(C)) :
         C[loc[k-1], loc[k]] for k in eachindex(loc)]  # same place: 0
    tLU = ifelse.(isL, col(:tL, 0.0), col(:tU, 0.0))  # load, unload
    istr && (tLU = [0; tLU; 0])
    TC = foldl(+, t) + foldl(+, tLU)    # added in order, left to right
    haskey(tr, :maxTC) && TC > tr.maxTC && return Inf, -4, DataFrame()
    R = istr ? [0; rte; 0] : rte
    tw = (:tbmin, :tbmax, :temin, :temax)
    if !any(f -> has(f) || haskey(tr, f), tw)
        out = DataFrame(Rte = R, Loc = loc, Cost = t)  # no windows
        (has(:tL) || has(:tU)) && (out.LU = tLU)
        return TC, Xflg, out
    end
    lo = ifelse.(isL, col(:tbmin, -Inf), col(:temin, -Inf))  # windows
    hi = ifelse.(isL, col(:tbmax, Inf), col(:temax, Inf))
    if istr              # the truck's, also at stops at its b and its e
        lo = [get(tr, :tbmin, -Inf); lo; get(tr, :temin, -Inf)]
        hi = [get(tr, :tbmax, Inf); hi; get(tr, :temax, Inf)]
        c = [1; findall(diff(loc) .!= 0) .+ 1]  # where location changes
        n = length(loc)
        for (ix, j) in ((2:c[2]-1, 1), (c[end]:n-1, n))  # stops at b, e
            lo[ix] = replace(lo[ix], -Inf => lo[j])
            hi[ix] = replace(hi[ix], Inf => hi[j])
        end
    end
    TC, _, _, s = scanTW(t, tLU, lo, hi)        # Sec. 2's scan, its c
    isinf(TC) && return Inf, -5, DataFrame()
    isnan(TC) && (TC = sum(t) + sum(tLU))       # no window at all
    # the waits, from the schedule, none below 0 from rounding
    w = max.(0, [0; s[2:end] - s[1:end-1] - tLU[1:end-1] - t[2:end]])
    out = DataFrame(Rte = R, Loc = loc, Cost = t,
        Arrive = [0; s[2:end] - w[2:end]], Wait = w, TWmin = lo,
        Start = s, LU = tLU, Depart = s + tLU, TWmax = hi,
        Total = t + w + tLU)
    return TC, Xflg, out
end
function rteTC_vrp(R::AbstractVector{<:AbstractVector}, sh, C, tr = (;))
    v = [rteTC_vrp(r, sh, C, tr) for r in R]    # each route of R
    return first.(v), getindex.(v, 2), last.(v)
end
# Code block 16: the same, by the route cost that reads them
rTDh(rte) = rteTC_vrp(rte, sh, D, tr)[1]
@show rteTC_vrp(r1, sh, D, tr)[1:2]   # the tour: Inf, -3, cube exceeded
R2b = [twoopt_rte(r, rTDh)[1] for r in savings(rTDh, sh)]
R2b == R2                             # the routes of Code block 13
# Code block 17: the routes on a map
fig, ax = vrpmap(R2, sh, X, tr;                   # Code block 7
                 lab = ([(:center, :center), (:left, :center)],
                        [(55, -60), (5, 0)]))    # numbers clear of lines
milabel!(ax, "Capacity, $(length(R2)) routes", sum(TD2))
fig

## Example 2(c): Maximum distance by a route cost of one's own
# Determine the routes when, besides the capacity, no route may exceed
# 600 mi, by a route cost of one's own around the route cost of Ex.
# 2(b).
# Code block 18: a maximum distance, by a route cost of one's own
rTDh0(rte) = rteTC_vrp(rte, sh, D, tr)[1]   # capacity, as Ex. 2(b)
maxdist = 600
function rTDh(rte)                    # my VRP constraint
    TC = rTDh0(rte)
    return TC > maxdist ? Inf : TC
end
R3 = [twoopt_rte(r, rTDh)[1] for r in savings(rTDh, sh)]
TD3 = rTDh.(R3)
Wt = [sum(sh.q[rte2idx(r)]) for r in R3]
Cube = [sum(cu[rte2idx(r)]) for r in R3]
prt(DataFrame(TD = TD3, Wt = Wt, Cube = Cube))
# Code block 19: the routes on a map
fig, ax = vrpmap(R3, sh, X, tr;                   # Code block 7
                 lab = ([(:left, :center), (:left, :center),
                         (:left, :bottom)],
                        [(5, 0), (5, 0), (4, 4)]))  # clear of lines
milabel!(ax, "Capacity and 600 mi, $(length(R3)) routes", sum(TD3))
fig

## Example 2(d): Maximum distance by the truck's own limit
# Determine the routes of Ex. 2(c) with the maximum distance given to
# the route cost as the truck's own limit.
# Code block 20: the same limit, built in
tr = (tr..., maxTC = 600)
rTDh(rte) = rteTC_vrp(rte, sh, D, tr)[1]
R4 = [twoopt_rte(r, rTDh)[1] for r in savings(rTDh, sh)]
@show R4 == R3                          # the routes of Code block 18
r13 = [rte2idx(R4[1]); rte2idx(R4[3])]  # routes 1 and 3's shipments
rteTC_vrp([r13; r13], sh, D, tr)[1:2]   # on one route

## Sec. 1. Vehicle routing problem
# Code block 21: the load mixes of two routes
let  # set in the lecture math's serif, as the insertion positions are
    fig = Figure(size = (380, 250), figure_padding = 4,
                 fonts = (; regular = Makie.MathTeXEngine.texfont()))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    dy = 0.62  # a row's height
    # a route's stops along a rule, beneath each segment the shipments on
    # board, and a box around each load mix: a loading followed by an
    # unloading, where what is on board peaks
    function loadmix!(r, y0, cap)
        n, ld = length(r), isorigin(r)
        text!(ax, 2.0 .* (0:n-1), fill(y0, n); text = string.(r),
              fontsize = 16, color = ink, align = (:center, :center))
        lines!(ax, [-0.4, 2n - 1.6], [y0 - 0.45, y0 - 0.45]; color = ink,
               linewidth = 1)
        onboard(k) = sort(setdiff(r[1:k][ld[1:k]], r[1:k][.!ld[1:k]]))
        depth = maximum(length(onboard(k)) for k in 1:n-1)
        for k in 1:n-1                     # the segment after stop k
            s = onboard(k)
            ys = y0 - 0.95 .- dy .* (0:length(s)-1)
            text!(ax, fill(2k - 1.0, length(s)), ys; text = string.(s),
                  fontsize = 16, color = ink, align = (:center, :center))
            if ld[k] && !ld[k+1]           # a load mix, boxed
                poly!(ax, Rect(2k - 1.42, ys[end] - 0.36, 0.84,
                               y0 - 0.2 - ys[end] + 0.36);
                      color = :transparent, strokecolor = bluec,
                      strokewidth = 1.5)
            end
        end
        yb = y0 - 0.95 - dy * (depth - 1) - 0.5
        text!(ax, n - 1.0, yb; text = cap, fontsize = 15, color = ink,
              align = (:center, :top))     # its subcaption
        return yb
    end
    yb = loadmix!([1, 2, 3, 3, 2, 1], 0.0, "(a) A single load mix")
    yb = loadmix!([1, 2, 1, 3, 2, 3], yb - 1.3,
                  "(b) A first and a second load mix")
    xlims!(ax, -0.6, 10.6); ylims!(ax, yb - 0.6, 0.45)
    fig
end

## Example 3: Southeast shipments with capacity
# Determine the loads of @mdl-vrp-pd for the three shipments of {{< xref
# 5.2 example-2 >}}, from Raleigh to Athens, from Asheville to
# Jacksonville and from Savannah to Gainesville, with a truck that
# carries at most 25 tons: (a) by hand, which routes of the three fit
# when each shipment weighs 10 tons; (b) by brute force and by savings,
# the least costly loads; and (c) the same when the shipments weigh 10,
# 14 and 12 tons.
# Code block 22: the six cities and three shipments of Lecture 5.2's Ex. 2
City = ["Raleigh", "Athens", "Asheville", "Jacksonville", "Savannah",
        "Gainesville"]
St = [:NC, :GA, :NC, :FL, :GA, :FL]
loc3 = [loc2lonlat(c; state = s) for (c, s) in zip(City, St)]
x3, y3 = [r.LON for r in loc3], [r.LAT for r in loc3]
D3 = dists(hcat(x3, y3), hcat(x3, y3), :mi) * 1.2  # road miles
sh3 = DataFrame(b = [1, 3, 5], e = [2, 4, 6], q = [10, 10, 10])
tr3 = (Kwt = 25,)                        # a truck of 25 tons
# Code block 23: the three shipments on a map
function ldlabel(i, sh)  # the shipments loaded (L) and unloaded (U) at i
    L, U = findall(==(i), sh.b), findall(==(i), sh.e)
    parts = [isempty(L) ? "" : "L" * join(L, ","),
             isempty(U) ? "" : "U" * join(U, ",")]
    s = join(filter(!isempty, parts), ":")
    return isempty(s) ? "" : "($s)"
end
sh2ln(sh, x) = vcat(collect([x[b], x[e], NaN]
                            for (b, e) in zip(sh.b, sh.e))...)
# each city's name over the shipments loaded and unloaded there, one
# label placed by hand clear of the lines, as in Lecture 5.2
citylabel(i, sh) = City[i] * "\n" * ldlabel(i, sh)
lalign = [(:left, :center), (:right, :center), (:left, :top),
          (:left, :center), (:left, :top), (:center, :top)]
loff = [(5, 0), (-5, 0), (9, -9), (19, 0), (8, -8), (0, -5)]
fig, ax = makemap(x3, y3; xexpand=0.3)
resize!(fig, 600, 520)
lines!(ax, sh2ln(sh3, x3), sh2ln(sh3, y3), color=:red)
for (b, e) in zip(sh3.b, sh3.e)  # each shipment's direction
    legarrows!(ax, x3[[b, e]], y3[[b, e]]; color=:red, onmap=true)
end
scatter!(ax, x3, y3)
text!(ax, x3, y3, text=citylabel.(eachindex(City), Ref(sh3));
      align = lalign, offset = loff)
fig

# Example 3: Southeast shipments with capacity
## Example 3(b): By brute force and by savings
# Determine how many of the 60 routes of the three shipments fit load
# mix by load mix, and the least costly loads, by brute force and by
# savings.
# Code block 24: all 60 routes, each load mix within 25 tons
v = [1, 1, 2, 2, 3, 3]
rtes = (r for r ∈ multiset_permutations(v, 6)       # the 60 routes
        if all(>(0), rtesegsum(r, ones(3))))
rTD3h(r) = rteTC_vrp(r, sh3, D3, tr3)[1]   # Inf if a load mix is over
@show rte2ldmx([1, 2, 3, 3, 2, 1])         # its one load mix
@show rte2ldmx([1, 2, 1, 3, 2, 3])         # its two load mixes
@show rtesegsum([1, 2, 1, 3, 2, 3], sh3.q)  # on board, by segment
@show count(isfinite(rTD3h(r)) for r ∈ rtes)  # each load mix fits
@show count(maximum(rtesegsum(r, sh3.q)) <= tr3.Kwt for r ∈ rtes)
@show count(sum(sh3.q[unique(r)]) <= tr3.Kwt for r ∈ rtes)  # all fit
TC3ᵒ, r3ᵒ = minimum((rTD3h(r), r) for r ∈ rtes)
@show TC3ᵒ                                 # the cheapest route
r3ᵒ
# Code block 25: two on a route and one alone, all alone, and savings
indep(k) = rTD3h([k, k])                   # shipment k shipped alone
function pairplusone(i, j)                 # i and j on a route, k alone
    k = only(setdiff(1:3, [i, j]))
    rs = (r for r ∈ multiset_permutations([i, i, j, j], 4)
          if all(>(0), rtesegsum(r, ones(3))))
    return minimum(rTD3h(r) for r ∈ rs) + indep(k)
end
@show sum(indep(k) for k in 1:3)           # all three alone
TC3p = [pairplusone(i, j) for (i, j) in [(1, 2), (1, 3), (2, 3)]]
@show TC3p                                 # 1 and 2, 1 and 3, 2 and 3
R3 =[twoopt_rte(r, rTD3h)[1] for r in savings(rTD3h, sh3)]  # savings
@show R3
R3 == [r3ᵒ]                                # the brute force's loads?

## Example 3(c): Heavier shipments
# Determine the least costly loads when the shipments weigh 10, 14 and
# 12 tons.
# Code block 26: shipments of 10, 14 and 12 tons
sh3.q = [10, 14, 12]
@show count(isfinite(rTD3h(r)) for r ∈ rtes)  # the routes that fit
TC3ᵒ, r3ᵒ = minimum((rTD3h(r), r) for r ∈ rtes)
@show TC3ᵒ                                 # the cheapest route
@show r3ᵒ
TC3p = [pairplusone(i, j) for (i, j) in [(1, 2), (1, 3), (2, 3)]]
@show TC3p                                 # 1 and 2, 1 and 3, 2 and 3
R3 = [twoopt_rte(r, rTD3h)[1] for r in savings(rTD3h, sh3)]  # savings
@show R3
sum(rTD3h.(R3)) ≈ TC3p[1]                  # the brute force's cost?
# Code block 27: the loads on a map
# the routes of shipments 1 and 2, and the least costly of them
rs12 = (r for r ∈ multiset_permutations([1, 1, 2, 2], 4)
        if all(>(0), rtesegsum(r, ones(3))))
r12 = argmin(rTD3h, rs12)
fig, ax = makemap(x3, y3; xexpand=0.3)
resize!(fig, 600, 520)
loc12 = rte2loc(r12, sh3)
lines!(ax, x3[loc12], y3[loc12], color=dcc)
legarrows!(ax, x3[loc12], y3[loc12]; color=dcc, onmap=true, at=0.4)
lines!(ax, x3[[5, 6]], y3[[5, 6]], color=redc)  # shipment 3, alone
legarrows!(ax, x3[[5, 6]], y3[[5, 6]]; color=redc, onmap=true)
scatter!(ax, x3, y3)
text!(ax, x3, y3, text=citylabel.(eachindex(City), Ref(sh3));
      align = lalign, offset = loff)  # placed as in Code block 23
text!(ax, 0.98, 0.03; space = :relative, color = ink, fontsize = 13,
      font = :bold, align = (:right, :bottom),  # over the ocean
      text = "1 and 2 on a route, 3 alone:\n" *
             "$(commas(round(TC3p[1], digits = 2))) mi")
fig

## Sec. 2. Time windows
# Code block 28: scanTW, the three scans of a route with time windows
function scanTW(t, u, ℓ, h)  # time-window scans: route time, a, b, c
    n = length(t)
    a = zeros(n); a[1] = ℓ[1]            # forward: the earliest start
    for k in 2:n
        a[k] = max(a[k-1] + u[k-1] + t[k], ℓ[k])  # wait if early
        a[k] + u[k] > h[k] && return Inf, a, a, a  # its window closed
    end
    b = zeros(n); b[n] = a[n]            # reverse: the latest start
    for k in n-1:-1:1
        b[k] = min(b[k+1] - t[k+1] - u[k], h[k] - u[k])
    end
    c = zeros(n); c[1] = b[1]            # forward again: the schedule
    for k in 2:n
        c[k] = max(c[k-1] + u[k-1] + t[k], ℓ[k])  # waits made late
    end
    return a[n] + u[n] - b[1], a, b, c   # earliest finish less start
end

# Sec. 2. Time windows
# Example 4: Route with time windows
## Example 4(a): By hand
# Determine the earliest finish, the latest start and the schedule by
# the three scans.
# The three scans, a frame each; hidden, since Ex. 4(a) is by hand
figscan = let t = [0, 1, 2, 1, 1],    # Ex. 4: DC, 2, 3, 4, DC
    lo = [6, 8, 12, 15, 18], hi = [18, 11, 14, 18, 24]
    _, a, b, c = scanTW(t, zeros(5), lo, hi)
    hr(x) = string(isinteger(x) ? Int(x) : x)
    pair(x, y) = x == y ? hr(y) : hr(x) * " – " * hr(y)  # reach – start
    P = [0.0 0.0; 1.6 1.0; 3.2 0.0; 1.6 -1.0]            # DC, 2, 3, 4
    C = [1.6, 0.0]                                       # the middle
    rn, fs = 0.17, 13                                    # node, font
    fig = Figure(size = (636, 420), figure_padding = (2, 2, 2, 2))
    lbl!(ax, x, y, s, col, al) =
        text!(ax, x, y; text = s, color = col, fontsize = fs, align = al)
    function turn!(ax, dir)  # the scan's direction, round the middle
        θ = dir > 0 ? range(150, -150; length = 60) :   # clockwise,
                      range(30, 330; length = 60)       # or back
        x, y = C[1] .+ 0.36cosd.(θ), C[2] .+ 0.36sind.(θ)
        lines!(ax, x, y; color = bluec, linewidth = 2)
        τ = atan(y[end] - y[end-1], x[end] - x[end-1])
        scatter!(ax, [x[end]], [y[end]]; marker = :rtriangle,
                 markersize = 14, rotation = τ, color = bluec)
    end
    function frame!(f, what, vals, dir)  # route, windows red, scan blue
        ax = Axis(fig[(f - 1) ÷ 2 + 1, (f - 1) % 2 + 1];
                  aspect = DataAspect(), xlabel = what, xlabelsize = 13)
        hidedecorations!(ax; label = false); hidespines!(ax)
        for (l, (i, j)) in enumerate(((1, 2), (2, 3), (3, 4), (4, 1)))
            p, q = P[i, :], P[j, :]              # leg l, into stop l + 1
            v = (q - p) / hypot((q - p)...)
            p, q = p + rn * v, q - rn * v        # node outline to outline
            arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]], [q[2] - p[2]];
                      color = ink, shaftwidth = 1.2, tipwidth = 8,
                      tiplength = 8)
            m = (p + q) / 2
            o = (m - C) / hypot((m - C)...)      # outward
            θ = atan(v[2], v[1])
            θ = abs(θ) > π / 2 ? θ - π * sign(θ) : θ        # upright
            text!(ax, (m + 0.16o)...; text = "$(t[l+1]) h",
                  color = redc, fontsize = fs, rotation = θ,
                  align = (:center, :center))
        end
        dir == 0 || turn!(ax, dir)               # forward or reverse
        w(k) = "[$(lo[k]), $(hi[k])]"            # stop k's window
        lbl!(ax, 1.38, 1.12, w(2), redc, (:right, :bottom))
        lbl!(ax, 3.42, 0.12, w(3), redc, (:left, :bottom))
        lbl!(ax, 1.38, -1.12, w(4), redc, (:right, :top))
        lbl!(ax, -0.1, 0.26, w(1), redc, (:center, :bottom))  # depart
        lbl!(ax, -0.1, -0.26, w(5), redc, (:center, :top))    # return
        at = ((-0.1, 0.58, (:center, :bottom)),  # where each stop's
              (1.82, 1.12, (:left, :bottom)),    # scan value goes
              (3.42, -0.12, (:left, :top)),
              (1.82, -1.12, (:left, :top)),
              (-0.1, -0.58, (:center, :top)))
        for (s, (x, y, al)) in zip(something(vals, String[]), at)
            lbl!(ax, x, y, s, bluec, al)
        end
        poly!(ax, Rect(-rn, -rn, 2rn, 2rn); color = colorant"#f2d9a0",
              strokecolor = ink, strokewidth = 1.5)          # the depot
        for i in 2:4
            poly!(ax, Circle(Point2f(P[i, :]...), rn); color = :white,
                  strokecolor = ink, strokewidth = 1.5)
        end
        text!(ax, P[:, 1], P[:, 2]; text = string.(1:4), color = ink,
              fontsize = fs, align = (:center, :center))
        xlims!(ax, -0.85, 4.85); ylims!(ax, -1.45, 1.45)
        return ax
    end
    fwd(x, k) = pair(x[k-1] + t[k], x[k])        # reached, then start
    rev(x, k) = pair(x[k+1] - t[k+1], x[k])      # reached going back
    frame!(1, "(a) The route and its windows", nothing, 0)
    frame!(2, "(b) Forward: earliest finish $(hr(a[5]))",
           ["a = " * (k == 1 ? hr(a[1]) : fwd(a, k)) for k in 1:5], 1)
    frame!(3, "(c) Reverse: latest start $(hr(b[1]))",
           ["b = " * (k == 5 ? hr(b[5]) : rev(b, k)) for k in 1:5], -1)
    frame!(4, "(d) Forward again: waits made late",
           ["c = " * (k == 1 ? hr(c[1]) : fwd(c, k)) for k in 1:5], 1)
    colgap!(fig.layout, 6); rowgap!(fig.layout, 10)
    fig
end
figscan

## Example 4(b): In Julia
# Determine the same scans with scanTW, and the route's schedule with
# rteTC_vrp.
# Code block 29: the route of Ex. 4, its three scans
t = [0, 1, 2, 1, 1]          # travel to each stop: DC, 2, 3, 4, DC
lo = [6, 8, 12, 15, 18]      # each stop's window opens
hi = [18, 11, 14, 18, 24]    # and closes
TC, a, b, c = scanTW(t, zeros(length(t)), lo, hi)  # no unloading
prt(hcat(a, b, c); cols = ["a: forward", "b: reverse", "c: again"],
    row_title = "Stop")
TC
# Code block 30: the same route by the route cost, its schedule
T5 = zeros(4, 4)
T5[1, 2] = 1
T5[2, 3] = 2
T5[3, 4] = 1
T5[4, 1] = 1
sh5 = DataFrame(b = 1, e = [2, 3, 4], tU = 0.0,
                temin = [8, 12, 15], temax = [11, 14, 18])
tr5 = (b = 1, e = 1, tbmin = 6, tbmax = 18, temin = 18, temax = 24)
TC5, Xflg5, out5 = rteTC_vrp([1, 2, 3, 1, 2, 3], sh5, T5, tr5)
prt(out5)
# Code block 31: every delivery order, one at a time
P6 = DataFrame(order = String[], TC = Float64[], Xflg = Int[])
for p in permutations(1:3)        # deliver to the stops in order p
    TCp, Xflgp = rteTC_vrp([p; p], sh5, T5, tr5)[1:2]
    push!(P6, (join(p, ", "), TCp, Xflgp))
end
prt(P6)

# Example 5: Thirty NC customers with time windows
## Example 5(a): Windows, unloading and capacity
# Determine the routes and schedules that the route cost with the
# windows, unloading times and capacity gives, and whether each is
# within the hours of service.
# Code block 32: windows, unloading and capacity, from the depot
T = D/50 .+ 5/60                  # 50 mph, and 5 min at each stop
sh.tU = sh.q * 30/60              # 30 min a ton to unload
sh.temin = [fill(7, 15); fill(13, 15)]    # daytime, then evening
sh.temax = [fill(17, 15); fill(23, 15)]
tr = (b = 1, e = 1, Kwt = 25, Kcu = 2750)
rTTh(rte) = rteTC_vrp(rte, sh, T, tr)[1]
R6 = [twoopt_rte(r, rTTh)[1] for r in savings(rTTh, sh)]
TT6 = rTTh.(R6)
# Code block 33: each route's schedule (route 1 shown)
TT6, Xflg6, out6 = rteTC_vrp(R6, sh, T, tr)
prt(out6[1])                          # route 1, its times to 0.01 h
# Code block 34: each route's day, from its schedule
prt(DataFrame(Start = [o.Start[1] for o in out6],    # leaves the depot
              Finish = [o.Start[end] for o in out6], # back at the depot
              Drive = [sum(o.Cost) for o in out6],   # 5 min a stop
              Unload = [sum(o.LU) for o in out6],
              Wait = [sum(o.Wait) for o in out6],
              TT = TT6))
# Code block 35: the routes on a map
function twmap(R, TT; lab = nothing)  # depot routes, each its color and
    x, y = X[:, 1], X[:, 2]             # number, hours at the left
    col = rtecol.(eachindex(R))                    # Code block 7
    fig, ax = basemap(x, y)                        # Code block 7
    for (i, r) in enumerate(R)             # each route, depot to depot
        loc = rte2loc(r, sh, tr)
        lines!(ax, x[loc], y[loc]; color = col[i], linewidth = 1.2)
        legarrows!(ax, x[loc], y[loc]; color = col[i], onmap = true,
                   size = 8)
    end
    # the daytime customers filled, the evening ones open
    scatter!(ax, x[2:16], y[2:16]; color = ink, markersize = 6)
    scatter!(ax, x[17:31], y[17:31]; color = :white, strokecolor = ink,
             strokewidth = 1.2, markersize = 6)
    depot!(ax, X)                                  # Code block 7
    fitmap!(fig, ax)
    rtelabels!(ax, R, sh, X, tr, lab)              # Code block 7
    hrs(v) = "$(round(v, digits = 2)) h"
    for (i, h) in enumerate(TT)
        text!(ax, 0.02, 0.03 + 0.065 * (length(TT) - i + 1);
              text = "Route $i: " * hrs(h), space = :relative,
              color = col[i], fontsize = 13, align = (:left, :bottom))
    end
    text!(ax, 0.02, 0.03; text = "Total: " * hrs(sum(TT)),
          space = :relative, color = ink, font = :bold, fontsize = 13,
          align = (:left, :bottom))
    return fig
end
twmap(R6, TT6; lab = ([(:left, :center), (:left, :center),
                       (:right, :center)],
                      [(5, 0), (5, 0), (-5, 0)]))   # clear of lines
# Code block 36: the four routes of a published solution
RM = [[1, 3, 5, 24, 26, 25, 30, 9, 8, 2, 28,
       1, 3, 5, 9, 8, 28, 2, 25, 30, 26, 24],
      [13, 15, 7, 14, 29, 23, 22, 4, 13, 15, 7, 4, 22, 23, 29, 14],
      [21, 17, 27, 12, 6, 20, 19, 12, 6, 20, 19, 27, 17, 21],
      [11, 18, 16, 10, 16, 10, 18, 11]]
TTM = rTTh.(RM)
sum(TTM)

## Example 5(b): Hours of service by a route cost of one's own
# Determine the routes and schedules when, besides the windows,
# unloading and capacity, each route is within the hours of service.
# Code block 37: hours of service, a wrapper that reads the schedule
function rTTh(rte)                 # hours of service (Lecture 3.2)
    TT, _, out = rteTC_vrp(rte, sh, T, tr)
    isinf(TT) && return Inf
    drive = sum(out.Cost)          # time at the wheel
    # out.Cost is the travel time into each stop, and the travel times T
    # of Code block 32 carry the five minutes of positioning at each stop,
    # so the 11 hours of driving include that positioning as well as the
    # time the wheels are turning.
    return drive > 11 || TT > 14 ? Inf : TT   # 11 h in a 14 h day
end
R6h = [twoopt_rte(r, rTTh)[1] for r in savings(rTTh, sh)]
TT6h = rTTh.(R6h)
# Code block 38: the routes within the hours of service, on a map
twmap(R6h, TT6h;                                   # Code block 35
      lab = ([(:left, :center), (:right, :center), (:center, :top),
              (:left, :center)],
             [(5, 0), (-5, 0), (0, -5), (5, 0)]))  # clear of lines

## Sec. 3. Routes to vehicles
# Code block 39: first fit
function firstfit(v, V)
    # Put first object into first bin
    B = [[1]]                               # Array of arrays
    b = [v[1]]                              # Array of scalars

    # Add remaining objects to bins
    for i = 2:length(v)
        idx = findfirst(b .+ v[i] .<= V) # Find first bin object fits into

        if idx !== nothing                  # Found existing bin
            b[idx] += v[i]
            push!(B[idx], i)
        else                                # Create new bin for object
            push!(b, v[i])
            push!(B, [i])
        end
    end

    return B
end
# Code block 40: first-fit decreasing
function ffd(v, V)                     # first fit, largest first
    p = sortperm(v, rev = true)        # the objects, decreasing
    return [p[B] for B in firstfit(v[p], V)]  # their own indices
end

# Sec. 3. Routes to vehicles
# Example 6: Osborn's routes to trucks
## Example 6(a): Routes
# Determine the routes, each within the truck's capacity and the 10
# hours, and each route's time, weight and cube.
# Code block 41: Osborn's customers, their loads, the truck
dfo = CSV.read("data/osborn-detroit.csv", DataFrame)
XYo = hcat(dfo.Longitude, dfo.Latitude)       # row 1 is the DC
To = 1.2dists(XYo, XYo, :mi) / 35             # h, at 35 mph
tro = (b = 1, e = 1, Kwt = 25, Kcu = 2750, maxTC = 10)
sho = DataFrame(b = 1, e = 2:nrow(dfo), q = dfo.Weight[2:end] / 2000,
                s = dfo.Density[2:end])
for i in findall(sho.q .> maxpayld.(eachrow(sho), Ref(tro)))
    qmax = maxpayld(sho[i, :], tro)           # a truckload of it
    for _ in 1:floor(Int, sho.q[i] / qmax)    # split off whole loads
        push!(sho, (b = 1, e = sho.e[i], q = qmax, s = sho.s[i]))
    end
    sho.q[i] = rem(sho.q[i], qmax)            # and keep the rest
end
sho.tU = 5/60 .+ 5sho.q / 60                  # 5 min, + 5 min a ton
prt(sho[sho.e .== sho.e[end], :])             # the load that was split
# Code block 42: the DC and the customers on a map
let cube = dfo.Weight[2:end] ./ dfo.Density[2:end]   # each load, ft³
    fig, ax = basemap(XYo[:, 1], XYo[:, 2]; roads = true)  # Code block 7
    scatter!(ax, XYo[2:end, 1], XYo[2:end, 2]; color = (bluec, 0.6),
             strokecolor = ink, strokewidth = 0.6,
             markersize = 4 .+ cube ./ 160)
    depot!(ax, XYo)                                   # Code block 7
    fitmap!(fig, ax)
end
# Code block 43: savings and 2-opt, each route's time by rteTC_vrp
rTTo(rte) = rteTC_vrp(rte, sho, To, tro)[1]
Ro = [twoopt_rte(r, rTTo)[1] for r in savings(rTTo, sho)]
TTo = rTTo.(Ro)
sum(TTo)
# Code block 44: each route's time, weight and cube
Wto = [sum(sho.q[rte2idx(r)]) for r in Ro]              # t
cuo = 2000sho.q ./ sho.s                                # each load, ft³
Cubeo = [sum(cuo[rte2idx(r)]) for r in Ro]
Custo = [sho.e[r[.!isorigin(r)]] for r in Ro]   # customers, in order
prt(DataFrame(Time = TTo, Wt = Wto, Cube = Cubeo,
              Customers = string.(Custo)))
# Code block 45: the routes on a map
let lab = ([(:left, :center), (:left, :center), (:center, :top),
            (:right, :center), (:left, :top), (:left, :center),
            (:left, :center), (:left, :center), (:left, :bottom),
            (:right, :bottom)],                  # each route's number,
           [(5, 0), (5, 0), (0, -9), (-5, 0), (4, -4), (5, 0), (5, 0),
            (5, 0), (16, 16), (-4, 4)]),         # clear of the lines
    (fig, ax) = vrpmap(Ro, sho, XYo, tro; lab)       # Code block 7
    h = string(round(sum(TTo), digits = 2))          # to two decimals
    h = rpad(h, findfirst('.', h) + 2, '0')
    text!(ax, 0.02, 0.03; space = :relative, color = ink, fontsize = 13,
          font = :bold, align = (:left, :bottom),
          text = "$(length(Ro)) routes: $h h")
    fig
end

## Example 6(c): In Julia
# Determine the same trucks in Julia, and the fewest trucks by the bin
# packing model of Lecture 2.7.
# Code block 46: routes to trucks, by first-fit decreasing
tL = 20/60                       # h to load at the DC, a later route
v, V = TTo .+ tL, 10 + tL        # each route, and a truck's day
LB = ceil(Int, sum(v) / V)       # no fewer trucks than this
trucks = ffd(v, V)               # the routes on each truck
@show trucks
(LB = LB, FFD = length(trucks))
# Code block 47: each truck's day
let fig = Figure(size = (600, 230))
    ax = Axis(fig[1, 1]; xlabel = "Hour of the day", ylabel = "Truck",
              yreversed = true, yticks = 1:length(trucks), xticks = 7:17)
    for (k, B) in enumerate(trucks)   # each truck, its routes in turn
        t = 7.0
        for (j, r) in enumerate(B)
            if j > 1                  # the loading before a later route
                poly!(ax, Rect(t, k - 0.3, tL, 0.6);
                      color = (bluec, 0.12), strokecolor = ink,
                      strokewidth = 0.8)
                t += tL
            end
            poly!(ax, Rect(t, k - 0.3, TTo[r], 0.6); color = (bluec, 0.4),
                  strokecolor = ink, strokewidth = 0.8)
            text!(ax, t + TTo[r] / 2, k; text = string(r), color = ink,
                  fontsize = 13, font = :bold, align = (:center, :center))
            t += TTo[r]
        end
    end
    vlines!(ax, [17]; color = redc, linestyle = :dash)
    xlims!(ax, 6.8, 17.4)
    fig
end
# Code block 48: the bin packing model of Lecture 2.7
function binpack(v, V; tlim = 60.0, gap = 1e-4)
    M = 1:length(v)
    bp = Model(HiGHS.Optimizer)
    set_silent(bp)
    set_time_limit_sec(bp, tlim)           # give up after this long
    set_attribute(bp, "mip_rel_gap", gap)  # or once this close
    @variable(bp, y[M], Bin)
    @variable(bp, x[M, M], Bin)
    @objective(bp, Min, sum(y))
    @constraint(bp, capacity[i ∈ M],       # (a)
                V * y[i] >= sum(v[j] * x[i, j] for j ∈ M))
    @constraint(bp, assignment[j ∈ M],     # (b)
                sum(x[i, j] for i ∈ M) == 1)
    optimize!(bp)
    xᵒ, yᵒ = snapvals(value.(x)), snapvals(value.(y))
    used = findall(==(1.0), yᵒ)
    bins = [findall(==(1.0), xᵒ[i, :]) for i ∈ used]
    res = (bins = bins, used = Int(objective_value(bp)),
           status = termination_status(bp), gap = relative_gap(bp),
           secs = solve_time(bp))
    return res
end
# Code block 49: the fewest trucks, by the bin packing model
packed = binpack(v, V)
@show packed.bins
@show LB                         # the bound
@show length(trucks)             # first-fit decreasing
packed.used                      # the optimum

## Example 7: Acme's timed routes to vehicles
# Acme, Inc., is a company that supplies 45 customers each day with
# cases of widgets from its DC in Morrisville, North Carolina, each
# customer with its own delivery window. Determine its routes within
# those windows, an hour's wait at most and a 10-hour route, and the
# vehicles that can run them, by hand and in Julia.
# Code block 50: Morrisville's customers, cases and windows
dm = CSV.read("data/morrisville-vrptw.csv", DataFrame)
XYm = hcat(dm.Longitude, dm.Latitude)         # row 1 is the DC
Tm = 1.2dists(XYm, XYm, :mi) / 35             # h, at 35 mph
nm = nrow(dm)
shm = DataFrame(b = 1, e = 2:nm, q = dm.Cases[2:end],
                tU = 2dm.Cases[2:end] / 60,   # 2 min a case
                temin = dm.Earliest[2:end], temax = dm.Latest[2:end])
trm = (b = 1, e = 1, Kwt = 75)                # 75 cases a vehicle
prt(first(shm, 5))
# Code block 51: the DC and the customers on a map
let (fig, ax) = basemap(XYm[:, 1], XYm[:, 2];     # Code block 7
                        roads = true)
    hrs = cgrad(:turbo, 10; categorical = true)       # 7 a.m. to 4 p.m.
    sc = scatter!(ax, XYm[2:end, 1], XYm[2:end, 2];
                  color = dm.Earliest[2:end], colormap = hrs,
                  colorrange = (6.5, 16.5), strokecolor = ink,
                  strokewidth = 0.6, markersize = 10)
    depot!(ax, XYm)                                   # Code block 7
    fitmap!(fig, ax)
    Colorbar(fig[1, 2], sc; label = "Window opens (hour)", ticks = 7:16,
             labelsize = 13, ticklabelsize = 12)
    fig
end

# Example 7: Acme's timed routes to vehicles
## Example 7(a): Routes
# Determine the routes within the windows, the hour of waiting and the
# 10 hours.
# Code block 52: rteTC_vrp alone, capacity and windows
rTTb(rte) = rteTC_vrp(rte, shm, Tm, trm)[1]
Rb = [twoopt_rte(r, rTTb)[1] for r in savings(rTTb, shm)]
outb = rteTC_vrp(Rb, shm, Tm, trm)[3]
prt(DataFrame(Time = rTTb.(Rb) .+ 1,                   # with loading
              MaxWait = [maximum(o.Wait) for o in outb]))
# Code block 53: the limits rteTC_vrp does not have, a route cost
function rTTm(rte)
    TT, _, out = rteTC_vrp(rte, shm, Tm, trm)
    isinf(TT) && return Inf
    maximum(out.Wait) > 1 && return Inf   # wait at most an hour
    return TT + 1 > 10 ? Inf : TT + 1     # an hour of loading at the DC
end
Rm = [twoopt_rte(r, rTTm)[1] for r in savings(rTTm, shm)]
TTm = rTTm.(Rm)
sum(TTm)
# Code block 54: each route's span, from its loading to its return
outm = rteTC_vrp(Rm, shm, Tm, trm)[3]
bm = [o.Start[1] - 1 for o in outm]       # loading starts, an hour early
em = [o.Depart[end] for o in outm]        # back at the DC
clock(h) = (m = round(Int, 60h);          # hours as h:mm
            string(m ÷ 60, ":", lpad(m % 60, 2, '0')))
ks = sortperm(bm)                         # by the start of loading
prt(DataFrame(Route = ks, Loads = clock.(bm[ks]),
              Back = clock.(em[ks]),
              Hours = round.(em[ks] .- bm[ks], digits = 2)))
# Code block 55: the routes on a map
let lab = ([(:left, :center), (:right, :top), (:right, :top),
            (:right, :top), (:left, :bottom), (:left, :top),
            (:right, :center), (:left, :center), (:right, :top),
            (:right, :center), (:center, :bottom)],  # route numbers,
           [(5, 0), (-4, -4), (-4, -4), (-4, -4), (4, 4), (4, -4),
            (-5, 0), (5, 0), (-4, -4), (-5, 0), (0, 5)]),  # off the lines
    (fig, ax) = vrpmap(Rm, shm, XYm, trm; lab)       # Code block 7
    h = string(round(sum(TTm), digits = 2))          # to two decimals
    h = rpad(h, findfirst('.', h) + 2, '0')
    text!(ax, 0.98, 0.03; space = :relative, color = ink, fontsize = 13,
          font = :bold, align = (:right, :bottom),
          text = "$(length(Rm)) routes: $h h")
    fig
end

## Example 7(c): In Julia
# Determine the fewest vehicles the routes need in Julia, by a model of
# which route follows which on a vehicle.
# Code block 56: the fewest vehicles, a model of which route follows which
R = 1:length(Rm)
fv = Model(HiGHS.Optimizer)
set_silent(fv)
@variable(fv, x[i ∈ R, j ∈ R; bm[j] > em[i]], Bin)  # j follows i
@objective(fv, Min, length(R) - sum(x))    # routes less the links
@constraint(fv, next[i ∈ R],               # (a) at most one after i
            sum(x[i, j] for j ∈ R if bm[j] > em[i]) <= 1)
@constraint(fv, before[j ∈ R],             # (b) at most one before j
            sum(x[i, j] for i ∈ R if bm[j] > em[i]) <= 1)
optimize!(fv)
nxt = [findfirst(j -> bm[j] > em[i] && value(x[i, j]) > 0.5, R)
       for i ∈ R]                          # the route after each, if any
veh = Vector{Int}[]
for i ∈ sortperm(bm)                       # by the start of loading
    any(==(i), nxt) && continue            # a route before it
    push!(veh, [i])                        # a vehicle's first route
    while !isnothing(nxt[veh[end][end]])   # and the chain after it
        push!(veh[end], nxt[veh[end][end]])
    end
end
@show veh
Int(objective_value(fv))                   # the fewest vehicles
# Code block 57: each vehicle's routes, against the clock
let fig = Figure(size = (600, 330))
    ax = Axis(fig[1, 1]; xlabel = "Hour of the day", ylabel = "Vehicle",
              yreversed = true, yticks = 1:length(veh), xticks = 4:2:20)
    for (k, Vk) in enumerate(veh), r in Vk
        poly!(ax, Rect(bm[r], k - 0.3, 1, 0.6); color = (bluec, 0.12),
              strokecolor = ink, strokewidth = 0.8)  # loading at the DC
        poly!(ax, Rect(bm[r] + 1, k - 0.3, em[r] - bm[r] - 1, 0.6);
              color = (bluec, 0.4), strokecolor = ink, strokewidth = 0.8)
        text!(ax, (bm[r] + 1 + em[r]) / 2, k; text = string(r),
              color = ink, fontsize = 13, font = :bold,
              align = (:center, :center))
    end
    xlims!(ax, 4, 20)
    fig
end

## Sec. 4. Tactical routing
# A route's stem and its tour; hidden, since the diagram computes nothing
figstem = let P = [0.0 0.0; 1.85 0.92; 2.95 1.62;  # the depot, C1-C4
                   3.18 0.30; 2.30 -0.47],
    rn = 0.19                                       # a customer's radius
    fig = Figure(size = (440, 300), figure_padding = 4)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    bw, bh = 0.62, 0.36                             # the depot's box
    # how far from a node's center an arc along u leaves its outline
    out(k, u) = k == 1 ? min(bw/2/abs(u[1]), bh/2/abs(u[2])) : rn
    function arc!(i, j, color)                      # outline to outline
        p, q = P[i, :], P[j, :]
        u = (q .- p) ./ hypot((q .- p)...)
        s, h = p .+ out(i, u) .* u, q .- (out(j, u) + 0.02) .* u
        return arrows2d!(ax, [s[1]], [s[2]], [h[1] - s[1]],
                         [h[2] - s[2]]; color = color, shaftwidth = 1.6,
                         tipwidth = 9, tiplength = 9)
    end
    arc!(1, 2, redc)                                # stem, out
    arc!(5, 1, redc)                                # stem, back
    foreach(k -> arc!(k, k + 1, bluec), 2:4)        # tour
    poly!(ax, Rect(-bw/2, -bh/2, bw, bh); color = colorant"#e6e6e6",
          strokecolor = ink, strokewidth = 1.2)
    text!(ax, 0, 0; text = "Depot", color = ink, fontsize = 13,
          align = (:center, :center))
    for k in 2:5                                    # the customers
        poly!(ax, Circle(Point2f(P[k, 1], P[k, 2]), rn);
              color = colorant"#e8e8f8", strokecolor = ink,
              strokewidth = 1)
        text!(ax, P[k, 1], P[k, 2]; text = "C$(k - 1)", color = ink,
              fontsize = 11, align = (:center, :center))
    end
    θ1 = atan(P[2, 2] - P[1, 2], P[2, 1] - P[1, 1])  # along each stem
    θ2 = atan(P[1, 2] - P[5, 2], P[1, 1] - P[5, 1]) + π
    text!(ax, 0.86, 0.62; text = "STEM", color = ink, fontsize = 12,
          rotation = θ1, align = (:center, :bottom), font = :bold)
    text!(ax, 1.30, -0.36; text = "STEM", color = ink, fontsize = 12,
          rotation = θ2, align = (:center, :top), font = :bold)
    text!(ax, 2.62, 0.78; text = "TOUR", color = ink, fontsize = 12,
          align = (:center, :center), font = :bold)
    xlims!(ax, -0.42, 3.50); ylims!(ax, -0.78, 1.90)
    fig
end
figstem

# Sec. 4. Tactical routing
# Example 8: Delivery estimates
## Example 8(d): In Julia
# Determine the same three estimates in Julia, solving numerically, and
# how they compare with the hand working.
# Code block 58: time feasibility, as a function
κ = 4/(3sqrt(π))                         # stem constant, about 0.752
φ = 0.908                                # tour constant, Lecture 5.1
# vehicle hours that N routes need to serve m customers
tfeas(N, m, a, v, ts) = (κ*(N - 1) + φ*sqrt(m))*sqrt(a)/v + m*ts
# Code block 59: Ex. 8(a), the minimum operating time
N, m, a, v, ts = 3, 100, 1000, 30, 6/60  # vehicles, customers, mi², mph,
                                         # and h at each customer
@show tmin = tfeas(N, m, a, v, ts)/N;    # h a vehicle
# Code block 60: Ex. 8(b), one vehicle's deliveries in 8 hours
using Optim
a, v, ts, tmax = 50, 30, 2/60, 8         # mi², mph, h, h
# the m at which the vehicle hours needed equal those available
m = optimize(m -> abs(tfeas(1, m, a, v, ts) - tmax), 1, 1000).minimizer
@show m                                  # deliveries
@show tfeas(1, 159, a, v, ts)            # h for 159
@show tfeas(1, 160, a, v, ts);           # h for 160
# Code block 61: Ex. 8(c), six trucks' deliveries, and the rest
a, v, ts, tmax = 200, 25, 6/60, 7        # mi², mph, h, h
# the most deliveries N trucks can make, a whole number
mmax(N) = floor(Int, optimize(m -> abs(tfeas(N, m, a, v, ts) - N*tmax),
                              1, 1000).minimizer)
@show mmax(6)
@show 500 - mmax(6)                      # outsourced
@show 500 .- mmax.([7, 8])               # with seven or eight trucks
Nall = optimize(N -> abs(tfeas(N, 500, a, v, ts) - N*tmax),
                1, 20).minimizer
@show Nall;                              # trucks to serve all 500

# Example 9: Minimum number of vehicles
## Example 9(c): In Julia
# Determine the same steps in Julia, and how they compare with the hand
# working.
# Code block 62: Ex. 9, vehicles at one, two and three routes each
m, f, qmax, t1, tmax = 100, 1, 5, 5, 8   # customers, units, units, h, h
rpv = DataFrame(per_vehicle = 1:3)       # routes per vehicle
rpv.t = tmax ./ rpv.per_vehicle          # h for each route
rpv.q = min.(qmax, floor.(Int, rpv.t ./ t1 .* qmax))   # whole units
rpv.N = ceil.(Int, m*f ./ rpv.q)         # routes
rpv.vehicles = ceil.(Int, rpv.N ./ rpv.per_vehicle)
prt(rpv)
@show ceil(Int, m*f*(t1/qmax)/tmax);     # the time bound
# Code block 63: Ex. 9(b), with loading at the depot before each route
tL = 20/60                               # h at the depot, each route
rpv.t = (tmax .- rpv.per_vehicle .* tL) ./ rpv.per_vehicle
rpv.q = min.(qmax, floor.(Int, rpv.t ./ t1 .* qmax))
rpv.N = ceil.(Int, m*f ./ rpv.q)
rpv.vehicles = ceil.(Int, rpv.N ./ rpv.per_vehicle)
prt(rpv)

## Example 10: North Carolina counties on road time
# Determine how many routes a DC at the center of North Carolina needs
# to deliver to each of the other 99 counties on road time, under the
# hours of service of Lecture 3.2, first by estimate and then by
# savings, and how the two compare.
# Code block 64: the counties, and the road time between every pair
using SimpleWeightedGraphs
dfc = filter(r -> (r.STFIP == st2fips(:NC)), uscounty())
a = sum(dfc.ALAND) + sum(dfc.AWATER)             # mi²
Nf, Lf = prune_reindex(faf5nodes(), faf5links()) # Lecture 4.1's network
Nc, Lc = cropnetwork(Nf, Lf, dfc.LON, dfc.LAT)   # a box around the points
Nc, Lc = addconnectors(Nc, Lc, dfc.LON, dfc.LAT; add_nf_nf = false)
con = isequal.(Lc.SOURCE, "CONNECTOR")
# A link's minutes: FAF5's free-flow time t, or, where a link has none,
# 60 d / v at its posted speed v; a connector at 20 mph
mins(t, v, d) = t > 0 ? t : 60d / v
tAB = [c ? 60d / 20 : mins(t, v, d)
       for (c, t, v, d) in zip(con, Lc.AB_TIME, Lc.SPEED, Lc.DIST)]
tBA = [c ? 60d / 20 : mins(t, v, d)
       for (c, t, v, d) in zip(con, Lc.BA_TIME, Lc.SPEED, Lc.DIST)]
fw, bw = Lc.DIR .!= -1, Lc.DIR .!= 1             # each link's directions
gT = SimpleWeightedDiGraph([Lc.SRC[fw]; Lc.DST[bw]],
                           [Lc.DST[fw]; Lc.SRC[bw]],
                           [tAB[fw]; tBA[bw]]; combine = min)
Tmin, PT = shortestpaths(gT, nrow(dfc))          # minutes, and the paths
Tc = Tmin / 60                                   # h
@show maximum(Tc);                               # the longest drive, h
# Code block 65: the DC, at the county nearest the center of the state
wc = dfc.ALAND + dfc.AWATER                      # each county's area
ctr = [sum(wc .* dfc.LON), sum(wc .* dfc.LAT)] / sum(wc)   # weighted
dc = argmin([dgc(ctr, [dfc.LON[i], dfc.LAT[i]]) for i in 1:nrow(dfc)])
dfc.NAME[dc]
# Code block 66: the fastest tour of the counties, and its speed
ncT = TSP(Tc)                                    # Lecture 5.1, road hours
@show ncT.TC                                     # h
@show v = φ * sqrt(nrow(dfc) * a) / ncT.TC;      # mph, over the area
# Code block 67: the routes the estimate needs, before any is built
m, ts = nrow(dfc) - 1, 30 / 60                   # customers, h at each
stem = κ * sqrt(a) / v                           # h out and back
tour = φ * sqrt(m * a) / v                       # h, all m customers
@show (tour - stem) / (11 - stem)                # routes: 11 h driving
@show (tour + m * ts - stem) / (14 - stem);      # routes: 14 h on duty
# Code block 68: routes by savings, under the hours of service
shc = DataFrame(b = dc, e = setdiff(1:nrow(dfc), dc))  # a delivery each
shc.tU .= ts                                     # h unloading at each
trc = (b = dc, e = dc)                           # from the DC and back
function rTTc(rte)                 # hours of service, as Ex. 5(b)
    TT, _, out = rteTC_vrp(rte, shc, Tc, trc)
    isinf(TT) && return Inf
    drive = sum(out.Cost)          # time at the wheel
    return drive > 11 || TT > 14 ? Inf : TT   # 11 h in a 14 h day
end
Rc = savings(rTTc, shc)
@show length(Rc)
@show count(isinf, rTTc.(Rc));                   # routes it cannot run
# Code block 69: the counties set aside, and the routes improved
gone = [rte2idx(r)[1] for r in Rc if isinf(rTTc(r))]   # infeasible alone
println(dfc.NAME[shc.e[gone]])
Rc = [twoopt_rte(r, rTTc)[1] for r in Rc if isfinite(rTTc(r))]
drive = [sum(rteTC_vrp(r, shc, Tc, trc)[3].Cost) for r in Rc]
prt(DataFrame(stops = length.(rte2idx.(Rc)), drive = drive,
              duty = rTTc.(Rc)))
@show length(Rc)
@show sum(rTTc.(Rc));                            # h on duty
# Code block 70: the estimate for the counties served
ms = m - length(gone)                            # customers served
@show (φ * sqrt(ms * a) / v + ms * ts - stem) / (14 - stem);
# Code block 71: the routes on the roads
fig, ax = makemap(dfc.LON, dfc.LAT; xexpand = 0.05)
resize!(fig, 687, 300)
for (k, r) in enumerate(Rc)                # each route along its roads
    loc = rte2loc(r, shc, trc)
    legs = zip(loc[1:end-1], loc[2:end])
    path = reduce(vcat,
                  [tracepath(PT[i], i, j)[1:end-1] for (i, j) in legs])
    push!(path, loc[end])
    lines!(ax, Nc.LON[path], Nc.LAT[path]; color = rtecol(k),
           linewidth = 1.2)                # Code block 7
end
scatter!(ax, dfc.LON, dfc.LAT; color = ink, markersize = 4)
outc = shc.e[gone]                         # the counties set aside
scatter!(ax, dfc.LON[outc], dfc.LAT[outc]; marker = :xcross, color = ink,
         markersize = 10)
scatter!(ax, [dfc.LON[dc]], [dfc.LAT[dc]]; marker = :rect,
         color = colorant"#f2d9a0", strokecolor = ink, strokewidth = 1.2,
         markersize = 11)                  # the DC
rtelabels!(ax, Rc, shc, hcat(dfc.LON, dfc.LAT), trc,   # Code block 7
           ([(:left, :bottom), (:left, :center), (:right, :bottom),
             (:right, :bottom), (:center, :bottom), (:right, :center),
             (:left, :bottom), (:left, :bottom), (:left, :center),
             (:right, :top), (:left, :bottom), (:left, :bottom),
             (:left, :top), (:left, :center)],     # each route's number,
            [(4, 4), (5, 0), (-12, 12), (-4, 4), (0, 5), (-5, 0), (4, 4),
             (4, 4), (5, 0), (-5, -5), (4, 4), (4, 4), (4, -4), (5, 0)]))
text!(ax, 0.98, 0.03; space = :relative, color = ink, fontsize = 13,
      font = :bold, align = (:right, :bottom),   # clear of the borders
      text = "$(length(Rc)) routes, " *
             "$(round(sum(rTTc.(Rc)), digits = 2)) h on duty")
fig
