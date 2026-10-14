# 4-net-2 — generated from 4-net-2.qmd by tools/qmd_to_jl.py
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

using CairoMakie, DataFrames, Graphs, Logjam, SimpleWeightedGraphs
using JuMP, HiGHS
# Two device pixels per figure unit, as in lectures 3.2 to 4.1, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Presentation plumbing for the prose, as in Lecture 4.1: a number with
# thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

## Sec. 1. OpenStreetMap
# Code block 1: Raleigh's streets in a bounding box, from OpenStreetMap
# osm_roads needs LightOSM and NearestNeighbors loaded, even when, as
# here, it reads the copy of the box's streets already saved in data/
using LightOSM, NearestNeighbors
bbox = (-78.70, -78.605, 35.75, 35.82)    # lon min, max, lat min, max
dfN, dfL = osm_roads(bbox; cache_dir = "data")
# With cache_dir, osm_roads reads the bounding box's streets from that
# folder if they are saved there, and downloads and saves it only if not;
# the copy read here was saved on 2026-10-12.
@show nrow(dfN)
@show nrow(dfL);
# Code block 2: a county's box, from the Census block groups in it
co = only(filter(r -> r.ST == :NC && r.NAME == "Wake", uscounty()))
B = filter(r -> r.STFIP == co.STFIP && r.COFIP == co.COFIP,
           uscenblkgrp())                 # Wake's block groups
mpd = dgc((0, 0), (0, 1))                 # miles in a degree of latitude
rad = sqrt.(B.ALAND ./ π)                 # radius as a disk, mi
# A block group is a point, its center of population, with its land area
# ALAND in square miles, so the box around the points alone falls short of
# the county's edge. Taking each as a disk of its land area, of radius
# $\sqrt{\text{ALAND}/\pi}$, and widening the box by that radius around
# each point reaches the edge. A degree of latitude is mpd miles, the
# great circle distance of Lecture 2.2 between two points one degree apart
# on a meridian, and a degree of longitude is shorter by the cosine of the
# latitude.
dlon = rad ./ (mpd .* cosd.(B.LAT))       # that radius in degrees of lon
dlat = rad ./ mpd                         # and of lat
bbW = (minimum(B.LON .- dlon), maximum(B.LON .+ dlon),
       minimum(B.LAT .- dlat), maximum(B.LAT .+ dlat))
wide = (bbW[2] - bbW[1]) * mpd * cosd((bbW[3] + bbW[4]) / 2)
high = (bbW[4] - bbW[3]) * mpd
@show nrow(B)
@show round.(bbW, digits = 3)
@show round(Int, wide)                    # mi
@show round(Int, high);                   # mi
# Code block 3: the bounding box's links by functional class
cls = ["Interstate", "Other freeway", "Principal arterial",
       "Minor arterial", "Major collector", "Minor collector", "Local"]
S = combine(groupby(dfL, :FCLASS, sort = true), nrow => :Links,
            :DIST => sum => :Miles,
            :SPEED => (v -> join(sort(unique(v)), ", ")) => :mph)
insertcols!(S, 2, :Class => cls[S.FCLASS])
S.Miles = round.(S.Miles, digits = 1)
prt(S)
# Code block 4: residential streets, one-way links and link length
using Statistics
arcs = Set(zip(dfL.SRC, dfL.DST))       # a one-way link has no reverse
oneway = count(((s, d),) -> (d, s) ∉ arcs, zip(dfL.SRC, dfL.DST))
pctlocal = round(100 * count(==(7), dfL.FCLASS) / nrow(dfL), digits = 1)
pctoneway = round(100 * oneway / nrow(dfL), digits = 1)
medft = round(Int, 5280 * median(dfL.DIST))
@show pctlocal                # % of the links on local streets
@show pctoneway               # % of the links one-way
@show medft                   # median link length, ft
@show all(==(1), dfL.DIR);    # every link has DIR 1
# DIR is the direction column of Lecture 4.1's links: 0 for a two-way
# road, which can be traveled from SRC to DST and back, 1 for a one-way
# link traveled from SRC to DST, and -1 for one traveled the other way.
# osm_roads gives a two-way street one link in each direction, so every
# link has DIR 1, which this line confirms (true); a one-way street is
# then simply a link with no reverse, which is how oneway counts them
# above.
# Code block 5: the two buildings of Ex. 1, and four coarser queries
bldg = ["Fitts-Woolard Hall", "D. H. Hill Library"]
qry = ["915 Partners Way, Raleigh, NC 27606",     # the two buildings
       "2 Broughton Dr, Raleigh, NC 27695",
       "Raleigh, NC", "27695", "Raliegh, NC", "Raleigh"]
loc = loc2lonlat(qry; cache_dir = "data")
# Given a vector of queries, loc2lonlat returns a table with a row for
# each: the query (INPUT), the LON and LAT found, the tier the answer came
# from (GC_SOURCE), its uncertainty in miles (GC_UNCERT) and its status
# (GC_STATUS). The table is printed without LON and LAT, which would make
# it wider than the page, and the two buildings' are shown below it. Only
# an answer at the ADDRESS tier is saved, in data/geocode_cache.csv, so
# the two addresses are read from the copy saved in data/; the other four
# are answered from Logjam's Census tables, and none of the six needs the
# Internet.
prt(select(loc, Not(:LON, :LAT)))       # how each query was answered
x = Float64.(loc.LON[1:2])     # the two buildings, for Ex. 1, as
y = Float64.(loc.LAT[1:2])     # numbers (the column holds a missing)
@show x
@show y;

# Sec. 1. OpenStreetMap
## Example 1: Fitts-Woolard to D. H. Hill Library
# Determine the shortest route by distance and the fastest route by time
# from Fitts-Woolard Hall, on NC State's Centennial Campus, to D. H.
# Hill Library, on its main campus, and back, on the OpenStreetMap
# streets of Raleigh, and the streets each route follows.
# Code block 6: the streets around the two buildings, as two graphs
using Graphs, SimpleWeightedGraphs
Nc, Lc = cropnetwork(dfN, dfL, x, y; xexpand = 1.5,
# The network of the bounding box is cropped to the area around the two
# buildings before they are connected to it, since addconnectors takes
# about 25 s on the whole bounding box and about half a second on the
# crop, with the same answer; xexpand = 1.5 widens the buildings' box by
# 1.5 times its width on each side, and yexpand by 1.5 times its height,
# the smallest crop that still gives the whole bounding box's answer.
                     yexpand = 1.5)
Nc, Lc = addconnectors(Nc, Lc, x, y; add_nf_nf = false)
con = isequal.(Lc.SOURCE, "CONNECTOR")
tmin = [c ? 60d / 20 : 60d / v                   # minutes, a connector
        for (c, d, v) in zip(con, Lc.DIST, Lc.SPEED)]   # 20 mph
        # c ? a : b is a when c is true and b otherwise. A connector has
        # no speed of its own (addconnectors leaves its SPEED missing), so
        # it is timed at 20 mph, and a street at its class's speed; 60d /
        # v is the minutes to go d miles at v mph.
fw, bw = Lc.DIR .!= -1, Lc.DIR .!= 1
# As in Lecture 4.1, Code block 45, each link gives an arc in each
# direction it can be traveled. On OpenStreetMap every street link has DIR
# 1 (Code block 4), so fw is every link and bw only the connectors, whose
# DIR is 0 because they run both ways; of two arcs between the same nodes,
# the quicker is kept (combine = min).
I, J = [Lc.SRC[fw]; Lc.DST[bw]], [Lc.DST[fw]; Lc.SRC[bw]]
gD = SimpleWeightedDiGraph(I, J, [Lc.DIST[fw]; Lc.DIST[bw]];
                           combine = min)                 # miles
gT = SimpleWeightedDiGraph(I, J, [tmin[fw]; tmin[bw]];
                           combine = min)                 # minutes
D, PD = shortestpaths(gD, 2)      # the buildings are nodes 1 and 2
T, PT = shortestpaths(gT, 2)
@show nrow(Nc)
@show nrow(Lc);
# Code block 7: each route's miles and minutes, out and back
Wd, Wt = weights(gD), weights(gT)
R = DataFrame(Trip = String[], Route = String[], mi = Float64[],
              min = Float64[])
paths = Vector{Int}[]
for (i, j, trip) in ((1, 2, "Out"), (2, 1, "Back")),
    (route, P) in (("Shortest", PD), ("Fastest", PT))
    p = tracepath(P[i], i, j)
    push!(paths, p)
    push!(R, (trip, route, sum(segcost(p, Wd)), sum(segcost(p, Wt))))
end
R.mi, R.min = round.(R.mi, digits = 3), round.(R.min, digits = 2)
prt(R)
# Code block 8: the streets each route follows
# The streets along path p, numbered in order, each with its first and
# last step: step t is the link from p[t] to p[t+1], traveled either
# way; a link with no name, such as a connector, is passed over
function streets(p, L)
    k = Dict(zip(zip(L.SRC, L.DST), 1:nrow(L)))   # link of (SRC, DST)
    lk(u, v) = get(k, (u, v), get(k, (v, u), 0))  # either direction
    nm = [L.NAME[lk(u, v)] for (u, v) in zip(p, p[2:end])]
    t = findall(!ismissing, nm)                 # the steps with a name
    a = [i for i in eachindex(t) if i == 1 || nm[t[i]] != nm[t[i-1]]]
    b = [a[2:end] .- 1; length(t)]              # each run's first, last
    return DataFrame(Seg = eachindex(a), Street = nm[t[a]],
                     Steps = string.(t[a], "-", t[b]))
end
for (r, p) in zip(eachrow(R), paths)
    println(r.Trip, ", ", lowercase(r.Route), ":")
    prt(streets(p, Lc))
end
# Code block 9: the two routes out, on the streets around them
using GeoMakie                           # makemap draws with it
supc  = colorant"#d21f26"                # shortest route
dcc   = colorant"#1e8a3c"                # fastest route
bluec = colorant"#1f6fb5"                # the two buildings
ink   = colorant"#252525"
# The streets of a set of links as a graph x2ln can draw (Lecture 4.1)
street(k) = SimpleWeightedGraph(Lc.SRC[k], Lc.DST[k], Lc.DIST[k];
                                combine = min)
lo = street(.!con .& (Lc.FCLASS .>= 6))  # local and minor collector
hi = street(.!con .& (Lc.FCLASS .<= 5))  # the other classes
pS, pF = paths[1], paths[2]              # out: shortest, fastest
zm = unique([pS; pF])                    # zoomed to the two routes
fig, ax = makemap(Nc.LON[zm], Nc.LAT[zm]; doRoadbkgd = false,
                  xexpand = 0.5, yexpand = 0.05)
resize!(fig, 687, 560)
# Both street layers faint: a muted base under the routes and names
lines!(ax, x2ln(lo, Nc.LON), x2ln(lo, Nc.LAT); color = (ink, 0.12),
       linewidth = 0.6)
lines!(ax, x2ln(hi, Nc.LON), x2ln(hi, Nc.LAT); color = (ink, 0.3),
       linewidth = 1.2)
lS = lines!(ax, Nc.LON[pS], Nc.LAT[pS]; color = (supc, 0.85),
            linewidth = 3.5)
lF = lines!(ax, Nc.LON[pF], Nc.LAT[pF]; color = (dcc, 0.85),
            linewidth = 3.5)
scatter!(ax, x, y; color = bluec, markersize = 14,
         strokecolor = :white, strokewidth = 1)
# The library's name on two lines, clear of the fastest route
text!(ax, x, y; text = replace.(bldg, "Hill " => "Hill\n"),
      fontsize = 14, color = bluec, font = :bold,
      align = [(:left, :top), (:right, :top)],
      offset = [(8, -6), (-8, -6)])
# Name street nm along its direction, at fraction f of its extent in
# the box xl, yl, gap px off it; side -1 puts the name below the street
using LinearAlgebra
function namestreet!(ax, N, L, nm, xl, yl; f = 0.5, side = 1, gap = 5)
    k = findall(r -> isequal(r.NAME, nm) &&
                     xl[1] < N.LON[r.SRC] < xl[2] &&
                     yl[1] < N.LAT[r.SRC] < yl[2], eachrow(L))
    isempty(k) && return nothing
    lon, lat = N.LON[L.SRC[k]], N.LAT[L.SRC[k]]
    u = [lon .* cosd(mean(lat)) lat]     # a degree of longitude is short
    u = u .- mean(u, dims = 1)
    v = eigen(Symmetric(u' * u)).vectors[:, 2]   # the street's direction
    v[1] < 0 && (v = -v)
    i = sortperm(u * v)[clamp(round(Int, f * length(k)), 1, length(k))]
    θ = atan(v[2], v[1])
    text!(ax, lon[i], lat[i]; text = nm, fontsize = 12, color = ink,
          rotation = θ, align = (:center, side > 0 ? :bottom : :top),
          offset = gap * side .* (-sin(θ), cos(θ)))
    return nothing
end
xl, yl = extrema(Nc.LON[zm]), extrema(Nc.LAT[zm])
xl = xl .+ (-0.3, 0.3) .* (xl[2] - xl[1])  # the streets beside them too
for (nm, f, side) in (("Hillsborough Street", 0.35, 1),
                      ("Western Boulevard", 0.55, 1),
                      ("Avent Ferry Road", 0.8, -1),
                      ("Pullen Road", 0.4, -1),
                      ("Varsity Drive", 0.5, -1))
    namestreet!(ax, Nc, Lc, nm, xl, yl; f, side)
end
axislegend(ax, [lS, lF], ["Shortest", "Fastest"]; position = :rb,
           labelsize = 13)
fig
# Code block 10: a landmark, OSRM's routes on the same OpenStreetMap data
using HTTP, JSON3
a, b = loc[1, :], loc[2, :]                 # the two buildings
for (s, t) in ((a, b), (b, a))               # out, then back
    url = "https://router.project-osrm.org/route/v1/driving/" *
          "$(s.LON),$(s.LAT);$(t.LON),$(t.LAT)" *
          "?alternatives=true&overview=false"
    r = JSON3.read(HTTP.get(url).body)          # the router's answer
    println(DataFrame(DIST = [rt.distance for rt in r.routes] ./ 1609.344,
                      TIME = [rt.duration for rt in r.routes] ./ 60))
end

## Sec. 2. Linear assignment problem
# Code block 11: a network of two groups, suppliers 1-3 and DCs 4-5
supc = colorant"#d21f26"                 # suppliers
dcc  = colorant"#1e8a3c"                 # DCs
ink  = colorant"#252525"
r    = 0.24                              # node radius, data units
XY   = [0.0 2.0; 0.0 1.0; 0.0 0.0; 2.4 1.6; 2.4 0.4]  # node positions

# One arc from node i to node j, outline to outline: kind :one (an arrow),
# :two (a two-way arc, no arrowhead) or :absent (dashed); off shifts it
# sideways, for a pair of parallel arcs
function arc!(ax, i, j, lab; kind = :one, off = 0.0, lpos = 0.5,
              lside = 1)
    p, q = XY[i, :], XY[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    nrm = [-u[2], u[1]]                  # unit normal
    s = asin(clamp(off / r, -1, 1))      # where a shifted arc meets
    t = p .+ r * cos(s) .* u .+ off .* nrm   # the circle
    h = q .- (r * cos(s) + 0.015) .* u .+ off .* nrm
    if kind == :absent
        lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = ink, linewidth = 1,
               linestyle = :dash)
    elseif kind == :two
        lines!(ax, [t[1], h[1] + 0.015u[1]], [t[2], h[2] + 0.015u[2]];
               color = ink, linewidth = 1.5)
    else
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = ink, shaftwidth = 1.5, tipwidth = 9,
                  tiplength = 9)
    end
    if !isempty(lab)
        m = t .+ lpos .* (h .- t)
        text!(ax, m[1], m[2]; text = lab, color = ink, fontsize = 14,
              align = (:center, :center),
              offset = (12lside * nrm[1], 12lside * nrm[2]))
    end
    return nothing
end

function twogroup(arcs; w = 340, h = 300)
    fig = Figure(size = (w, h))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    for (i, j, lab, kw) in arcs
        arc!(ax, i, j, lab; kw...)
    end
    for k in 1:size(XY, 1)               # the nodes, over the arcs
        x, y = XY[k, :]
        c = k <= 3 ? supc : dcc
        poly!(ax, Circle(Point2f(x, y), r); color = :white,
              strokecolor = c, strokewidth = 1.8)
        text!(ax, x, y; text = string(k), color = c, fontsize = 15,
              align = (:center, :center))
    end
    xlims!(ax, -0.4, 2.8); ylims!(ax, -0.4, 2.4)
    return fig
end

twogroup([(1, 4, "6", (lpos = 0.25,)),
          (1, 5, "10", (lpos = 0.2, lside = -1)),
          (2, 4, "0", (lpos = 0.3,)),
          (2, 5, "13", (lpos = 0.3, lside = -1)),
          (3, 4, "9", (lpos = 0.2,)),
          (3, 5, "16", (lpos = 0.3, lside = -1))])

# Sec. 2. Linear assignment problem
## Model: Linear assignment
# Model: linear assignment
using JuMP, HiGHS
function LAP(c)
    S, D = 1:size(c, 1), 1:size(c, 2)
    if length(S) < length(D)                     # assumption (c)
    # error stops the function there, with its message, and nothing after
    # it runs: a call of LAP on a matrix with fewer rows (supply nodes)
    # than columns (demand nodes) ends at this line, as in Ex. 2(c),
    # before any model is built.
        error("fewer supply nodes than demand nodes")
    end
    model = Model(HiGHS.Optimizer)
    @variable(model, 0 ≤ x[S, D])
    @objective(model, Min, sum(c[i, j] * x[i, j] for i ∈ S, j ∈ D))
    @constraint(model, supply[i ∈ S], sum(x[i, j] for j ∈ D) ≤ 1)  # (a)
    @constraint(model, demand[j ∈ D], sum(x[i, j] for i ∈ S) == 1) # (b)

    set_silent(model)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
    # Only an optimal solution is returned; any other status stops with an
    # error naming it, such as INFEASIBLE. snapvals, as in Lecture 2.7,
    # sets a value close to an integer to that integer, so an assignment
    # of 0.9999999997 reads as 1.
        return (TC = objective_value(model), x = snapvals(value.(x)))
    end
    error(termination_status(model))
end

## Example 2: Unter's passenger-to-car assignment
# Unter, a ride-hailing service, has three cars available and three
# passengers wanting a ride, the distance of each car from each
# passenger given by the distance matrix $$ D = \begin{bmatrix} 4 & 8 &
# 5 \\ 2 & 1 & 9 \\ 6 & 3 & 7 \end{bmatrix}, $$ one row for each car and
# one column for each passenger. Determine the assignment of cars to
# passengers, first by the greedy procedure and then as @mdl-assignment,
# and compare their total distances.
# Code block 12: Unter's cars and passengers as a bipartite network
let D = [4 8 5; 2 1 9; 6 3 7], r = 0.2       # distances, node radius
    supc, demc = colorant"#d21f26", colorant"#1e8a3c"
    ink = colorant"#252525"
    XYc = [(0.0, 2.0), (0.0, 1.0), (0.0, 0.0)]   # cars
    XYp = [(2.4, 2.0), (2.4, 1.0), (2.4, 0.0)]   # passengers
    # Each distance near its car, on the side of its arc inside that
    # car's fan (1 above it, -1 below), so it reads with its own arc
    sd = [1 1 1; 1 1 -1; -1 -1 -1]
    fig = Figure(size = (400, 330))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    for (i, p) in enumerate(XYc), (j, q) in enumerate(XYp)
        u = (q .- p) ./ hypot((q .- p)...)
        t, h = p .+ r .* u, q .- (r + 0.015) .* u
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = ink, shaftwidth = 1.2, tipwidth = 8,
                  tiplength = 8)
        m = t .+ 0.18 .* (h .- t) .+ 0.1 * sd[i, j] .* (-u[2], u[1])
        text!(ax, m[1], m[2]; text = string(D[i, j]), color = ink,
              fontsize = 13, align = (:center, :center))
    end
    for (k, (x, y)) in enumerate([XYc; XYp])  # the nodes, over the arcs
        c = k <= 3 ? supc : demc
        poly!(ax, Circle(Point2f(x, y), r); color = :white,
              strokecolor = c, strokewidth = 1.8)
        text!(ax, x, y; text = string((k - 1) % 3 + 1), color = c,
              fontsize = 15, align = (:center, :center))
    end
    text!(ax, [0.0, 2.4], [2.42, 2.42]; text = ["cars", "passengers"],
          color = [supc, demc], fontsize = 14, align = (:center, :bottom))
    xlims!(ax, -0.5, 2.9); ylims!(ax, -0.35, 2.7)
    fig
end

# Example 2: Unter's passenger-to-car assignment
## Example 2(a): Greedy step by step
# Assign the cars to the passengers by repeatedly making the assignment
# of least distance among those still possible.
D = [4 8 5; 2 1 9; 6 3 7]  # Code block 13: car-to-passenger distances
# Code block 14: find closest passenger
idx = argmin(D)
# argmin returns a Cartesian index, the row and the column together rather
# than a single number, here (2, 2): idx[1] is the row, idx[2] the column,
# and D[idx], in the next block, the value there.
D[idx]                        # Code block 15: its distance
# Code block 16: assign large value so that assignment not made again
D[idx[1],:] .= maximum(D)+1
# .= gives every element of row idx[1] the maximum, 9, plus one: 10.
D[:,idx[2]] .= maximum(D)+1
# The column gets 11, not 10, because the line before has already changed
# D, and its maximum is now 10: every step changes D itself.
D
idx = argmin(D)               # Code block 17: find next closest passenger
D[idx]                        # Code block 18: its distance
# Code block 19: assign large values again
D[idx[1],:] .= maximum(D)+1
D[:,idx[2]] .= maximum(D)+1
D
idx = argmin(D)               # Code block 20: the last passenger
D[idx]                        # Code block 21: its distance
TC = 1 + 4 + 7                # Code block 22: final cost of assignment

## Example 2(b): Greedy as a function
# Make the greedy procedure a function, and use it to see what happens
# when the numbers of cars and passengers differ.
# Code block 23: the greedy procedure as a function
# Need to re-define matrix since it was changed above
D = [4 8 5; 2 1 9; 6 3 7]

function greedyassignment(C)
    C = copy(C)       # Copy-by-value instead of default copy-by-reference
    X = zeros(size(C))
    # Large value so that assignment not made again
    BigM = maximum(C) + 1
    # Computed once, before the loop, where Code blocks 16 and 19 took the
    # maximum again at each step; Big M is the name math programming gives
    # a value larger than any in the problem.
    for i = 1:size(C,2)
        idx = argmin(C)
        X[idx] = 1
        C[idx[1],:] .= BigM
        C[:,idx[2]] .= BigM
    end
    return X
end

X = greedyassignment(D)
TC = sum(D.*X)                # Code block 24: total cost
# Code block 25: not feasible to have one car serve multiple passengers
greedyassignment(D[1:2,:])
# Code block 26: feasible to have extra car not assigned
greedyassignment(D[:,1:2])

## Example 2(c): As a linear program
# Solve the assignment as @mdl-assignment, and solve it again with fewer
# cars than passengers, and with fewer passengers than cars.
# Code block 27: Unter's assignment as a linear program
TCᵒ, Xᵒ = LAP(D)
@show TCᵒ; Int.(Xᵒ)
# Code block 28: not feasible, one car short
try
# try runs LAP, and when it stops with an error, catch prints the error's
# message and the script runs on; without it, the companion script would
# stop at this line.
    LAP(D[1:2,:])
catch e
    showerror(stdout, e)
end
# Code block 29: feasible, extra car not assigned
TC₂, X₂ = LAP(D[:,1:2])
@show TC₂; Int.(X₂)

## Example 3: Uber on Raleigh's streets
# Twelve drivers and ten passengers wanting a ride are spread across the
# OpenStreetMap streets of Raleigh of Ex. 1. Assign the drivers to the
# passengers, by the greedy procedure and as @mdl-assignment, so that
# the total driving time to the pickups is least, and determine, by
# Little's Law, how many drivers are on the way to a pickup at any time
# when 20 requests arrive an hour.
# Code block 30: synthetic driver and passenger creation
using Random
nd, np = 12, 10                         # drivers, passengers
bg = filter(r -> bbox[1] <= r.LON <= bbox[2] &&
                 bbox[3] <= r.LAT <= bbox[4], uscenblkgrp())
sort!(bg, [:TRFIP, :BGFIP])             # a fixed order for the draw
Random.seed!(754)                       # change it for another draw
k = randperm(nrow(bg))[1:nd+np]         # distinct block groups
# randperm(n) is the numbers 1 to n in a random order, so its first nd +
# np are that many different block groups, drawn without replacement: no
# two drivers or passengers share a center.
U = DataFrame(ROLE = [fill("driver", nd); fill("passenger", np)],
              ID = [string.("D", 1:nd); string.("P", 1:np)],
              LON = bg.LON[k], LAT = bg.LAT[k])
prt(U)
# Code block 31: driving minutes from each driver to each passenger
drv = findall(==("driver"), U.ROLE)      # rows of U: 12 drivers
pas = findall(==("passenger"), U.ROLE)   # and 10 passengers
NU, LU = cropnetwork(dfN, dfL, U.LON, U.LAT; xexpand = 0.1,
                     yexpand = 0.1)
NU, LU = addconnectors(NU, LU, U.LON, U.LAT; add_nf_nf = false)
cU = isequal.(LU.SOURCE, "CONNECTOR")
tU = [c ? 60d / 20 : 60d / v             # minutes, as in Code block 6
      for (c, d, v) in zip(cU, LU.DIST, LU.SPEED)]
fw, bw = LU.DIR .!= -1, LU.DIR .!= 1
gU = SimpleWeightedDiGraph([LU.SRC[fw]; LU.DST[bw]],
                           [LU.DST[fw]; LU.SRC[bw]],
                           [tU[fw]; tU[bw]]; combine = min)
TU, PU = shortestpaths(gU, nrow(U))      # among all 22 points
C = TU[drv, pas]                         # driver i to passenger j
round.(C, digits = 1)
# Code block 32: greedy against the linear program, in minutes
X = greedyassignment(C)
TC = sum(C .* X)
TCᵒ, Xᵒ = LAP(C)
@show round(TC, digits = 2)
@show round(TCᵒ, digits = 2)
# The passengers the two assign differently, and their drivers
d = findall(j -> X[:, j] != Xᵒ[:, j], 1:length(pas))
car(Z, j) = findfirst(==(1), Z[:, j])    # the driver Z gives passenger j
prt(DataFrame("Passenger" => U.ID[pas[d]],
              "Greedy" => [U.ID[drv[car(X, j)]] for j in d],
              "Greedy min" => [round(C[car(X, j), j], digits = 2)
                               for j in d],
              "LP" => [U.ID[drv[car(Xᵒ, j)]] for j in d],
              "LP min" => [round(C[car(Xᵒ, j), j], digits = 2)
                           for j in d]))
# Code block 33: Little's Law, drivers busy at TH requests an hour
TH = 20                      # requests per hour (an estimate; change it)
CT = TC / length(pas)        # average pickup minutes, greedy
CTᵒ = TCᵒ / length(pas)      # and by the linear program
nU = nrow(U)                 # the 22 drawn points
ride = sum(TU[1:nU, 1:nU]) / (nU * (nU - 1))  # minutes between two, avg
# CT in minutes; WIP = TH*CT/60 drivers on the way to a pickup; and with
# a ride, TH*(CT + ride)/60 drivers busy, of the 12
@show round(ride, digits = 2)
ct = [CT, CTᵒ]
prt(DataFrame("Assignment" => ["Greedy", "LP"],
              "CT" => round.(ct, digits = 2),
              "WIP" => round.(TH .* ct ./ 60, digits = 2),
              "Busy" => round.(TH .* (ct .+ ride) ./ 60, digits = 2)))
# Code block 34: the assignment on the streets
orc = colorant"#e08214"                  # greedy, where it differs
streetU(k) = SimpleWeightedGraph(LU.SRC[k], LU.DST[k], LU.DIST[k];
                                 combine = min)
lo = streetU(.!cU .& (LU.FCLASS .>= 6))  # as in Code block 9
hi = streetU(.!cU .& (LU.FCLASS .<= 5))
route(i, j) = tracepath(PU[drv[i]], drv[i], pas[j])  # driver i to j
rts = [[route(car(Xᵒ, j), j) for j in 1:length(pas)]; # LP, then
       [route(car(X, j), j) for j in d]]              # greedy's
z = unique(vcat(rts...))                   # zoomed to every route drawn
fig, ax = makemap(NU.LON[z], NU.LAT[z]; doRoadbkgd = false,
                  xexpand = 0.03, yexpand = 0.03)
resize!(fig, 687, 620)
lines!(ax, x2ln(lo, NU.LON), x2ln(lo, NU.LAT); color = (ink, 0.12),
       linewidth = 0.5)
lines!(ax, x2ln(hi, NU.LON), x2ln(hi, NU.LAT); color = (ink, 0.3),
       linewidth = 1)
np = length(pas)
for p in rts[1:np]                          # the linear program's routes
    lines!(ax, NU.LON[p], NU.LAT[p]; color = (dcc, 0.85), linewidth = 3)
end
for p in rts[np+1:end]                      # greedy's, where they differ
    lines!(ax, NU.LON[p], NU.LAT[p]; color = (orc, 0.9), linewidth = 2.5,
           linestyle = :dash)
end
xl, yl = extrema(NU.LON[z]), extrema(NU.LAT[z])
for (nm, f, side) in (("Hillsborough Street", 0.8, -1),
                      ("Glenwood Avenue", 0.45, 1),
                      ("Wade Avenue", 0.5, 1),
                      ("Western Boulevard", 0.85, -1))
    namestreet!(ax, NU, LU, nm, xl, yl; f, side)   # Code block 9's
end
# Two places: NC State, below its two buildings of Ex. 1, clear of the
# routes, and downtown, at the State Capitol (1 E Edenton St, as
# loc2lonlat finds it)
text!(ax, [mean(x), -78.6391], [mean(y), 35.7804];
      text = ["NC State", "Downtown"], fontsize = 14, font = :bold,
      color = (ink, 0.6), align = (:center, :center),
      offset = [(-20, -50), (0, 0)])
sD = scatter!(ax, U.LON[drv], U.LAT[drv]; marker = :rect, color = bluec,
              markersize = 13, strokecolor = :white, strokewidth = 1)
sP = scatter!(ax, U.LON[pas], U.LAT[pas]; color = supc, markersize = 13,
              strokecolor = :white, strokewidth = 1)
# Each ID above right of its point, unless a route leaves that way
pl = Dict("D1" => ((:right, :bottom), (-6, 4)),
          "D3" => ((:right, :center), (-9, 0)),
          "P2" => ((:right, :center), (-9, 0)),
          "P4" => ((:right, :center), (-9, 0)),
          "P5" => ((:left, :top), (6, -4)),
          "D4" => ((:center, :bottom), (0, 9)),
          "P8" => ((:center, :bottom), (0, 9)),
          "P9" => ((:center, :bottom), (0, 9)))
ap = [get(pl, id, ((:left, :bottom), (6, 4))) for id in U.ID]
text!(ax, U.LON, U.LAT; text = U.ID, fontsize = 11, color = ink,
      align = first.(ap), offset = last.(ap))
lL = LineElement(color = dcc, linewidth = 3)
lG = LineElement(color = orc, linewidth = 2.5, linestyle = :dash)
axislegend(ax, [sD, sP, lL, lG], ["Driver", "Passenger", "LP",
           "Greedy, where it differs"]; position = :rt, labelsize = 12)
fig

# Sec. 3. Transportation problem
## Model: Transportation
# Model: transportation
function trans(c, s, d)
    S, D = 1:length(s), 1:length(d)
    if sum(s) < sum(d)                           # assumption (b)
    # As in LAP, the model's assumption is checked before the linear
    # program is built: assumption (b) of @mdl-transportation, that total
    # supply is at least total demand. When it fails, error stops the
    # function with its message, as in Ex. 4(c), rather than leaving the
    # solver to report the case as infeasible.
        error("total supply is less than total demand")
    end
    model = Model(HiGHS.Optimizer)
    @variable(model, 0 ≤ x[S,D])
    @objective(model, Min, sum(c[i,j]*x[i,j] for i ∈ S, j ∈ D))
    @constraint(model, supply[i ∈ S], sum(x[i,j] for j ∈ D) ≤ s[i])  # (a)
    @constraint(model, demand[j ∈ D], sum(x[i,j] for i ∈ S) == d[j]) # (b)

    set_silent(model)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)))
    end
    error(termination_status(model))
end

## Example 4: Transportation with excess supply
# Supply nodes 1 to 3 of @fig-trans-network ship to demand nodes 4 to 7
# at the costs per unit of @tbl-trans-tableau. Determine the shipments
# that meet every demand at least total cost, first by the greedy
# procedure and then as @mdl-transportation, and determine what happens
# when the total supply is less than the total demand.
# Code block 35: the transportation network
supc, demc = colorant"#d21f26", colorant"#1e8a3c"
ink = colorant"#252525"
r = 0.2                                  # node radius, data units
XYs = [(0.0, 2.2), (0.0, 1.1), (0.0, 0.0)]
XYd = [(2.4, 2.4), (2.4, 1.6), (2.4, 0.8), (2.4, 0.0)]
sup, dem = [55, 50, 40], [45, 20, 30, 30]
cst = [8 6 10 9; 9 12 13 7; 14 9 16 5]  # the tableau's costs per unit
# Each cost near its arc's tail: the fraction of the way along it, and
# the side of it (1 to the left of the arc's direction) clear of others
at = [0.12 0.12 0.15 0.12; 0.12 0.12 0.15 0.12; 0.21 0.15 0.12 0.12]
sd = [1 1 1 -1; 1 -1 -1 -1; -1 -1 -1 -1]

fig = Figure(size = (440, 366))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
# Every arc, outline to outline, and its cost
for (a, p) in enumerate(XYs), (b, q) in enumerate(XYd)
    u = (q .- p) ./ hypot((q .- p)...)
    t, h = p .+ r .* u, q .- (r + 0.015) .* u
    arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
              color = ink, shaftwidth = 1.2, tipwidth = 8, tiplength = 8)
    m = t .+ at[a, b] .* (h .- t) .+ 0.08 * sd[a, b] .* (-u[2], u[1])
    text!(ax, m[1], m[2]; text = string(cst[a, b]), color = ink,
          fontsize = 10, align = (:center, :center))
end
for (k, (x, y)) in enumerate([XYs; XYd])  # the nodes, over the arcs
    c = k <= 3 ? supc : demc
    poly!(ax, Circle(Point2f(x, y), r); color = :white,
          strokecolor = c, strokewidth = 1.8)
    text!(ax, x, y; text = string(k), color = c, fontsize = 15,
          align = (:center, :center))
    amt, dx = k <= 3 ? (sup[k], -0.45) : (dem[k - 3], 0.45)
    text!(ax, x + dx, y; text = string(amt), color = c, fontsize = 14,
          align = (:center, :center))
end
xlims!(ax, -0.8, 3.2); ylims!(ax, -0.4, 2.8)
fig

# Example 4: Transportation with excess supply
## Example 4(a): Greedy by hand
# Ship from the supply nodes to the demand nodes by repeatedly making
# the shipment of least cost per unit still possible, as much as it can
# carry, and determine the total cost.
# Code block 36: the costs, demands and supplies of the tableau
C = [8 6 10 9; 9 12 13 7; 14 9 16 5]
d = [45, 20, 30, 30]
s = [55, 50, 40]
@show sum(s)
@show sum(d)
sum(s) - sum(d)
# Code block 37: the greedy procedure for the transportation problem
function gtrans(C, s, d)
    steps = DataFrame(From = Int[], To = Int[], Cost = eltype(C)[],
                      Units = eltype(s)[])
    s, d = float(copy(s)), float(copy(d))
    # Copies, as greedyassignment copies C in Code block 23: the loop uses
    # up s and d, and the caller's are left as they were for Code block
    # 40, which solves the same s and d next.
    F = zeros(size(C))
    TC = 0.0
    while any(s .> 0) && any(d .> 0)
        idxs, idxd = findall(s .> 0), findall(d .> 0)
        k = argmin(C[idxs, idxd])         # least cost still available
        i, j = idxs[k[1]], idxd[k[2]]
        # The least cost is sought only among the rows with supply left
        # and the columns with demand left, so k is a position in that
        # smaller matrix, and idxs[k[1]] and idxd[k[2]] turn it back into
        # a row and a column of C.
        f = min(s[i], d[j])               # as much as it can carry
        F[i, j] = f
        TC += C[i, j] * f
        s[i] -= f
        d[j] -= f
        push!(steps, (i, length(s) + j, C[i, j], f))
    end
    return F, TC, steps
end

Fg, TCg, steps = gtrans(C, s, d)
prt(steps)
TCg                           # Code block 38: total cost of greedy
# Code block 39: the steps of greedy, each frame from its row of steps
# The supply and demand left after steps 1 to k, and the units shipped
function replay(C, s, d, steps, k)
    m = size(C, 1)
    F, sl, dl = zeros(Int, size(C)), copy(s), copy(d)
    for t in 1:k                          # steps 1 to k, replayed
        a, b, f = steps.From[t], steps.To[t] - m, steps.Units[t]
        F[a, b] += f
        sl[a] -= f
        dl[b] -= f
    end
    return F, sl, dl
end
# Value v at (x, y), struck through: the value before the step. The
# stroke is a thin filled band rather than a line, because the figure
# label check counts any line across a label as a defect, and here
# crossing the label is the point
function struck!(ax, x, y, v, c)
    text!(ax, x, y; text = string(v), color = (c, 0.55), fontsize = 12,
          align = (:center, :center))
    w, h = 0.1 * length(string(v)) + 0.06, 0.018   # half width, thickness
    band = Point2f[(x - w, y - 0.1 - h), (x + w, y + 0.1 - h),
                   (x + w, y + 0.1 + h), (x - w, y - 0.1 + h)]
    poly!(ax, band; color = c)
    return nothing
end
# The tableau after step k (k = 0, as it starts): the costs, the units
# shipped, the supply and demand left, what is used up shaded, step k's
# cell in blue and the supply and demand it changed struck through
function greedystep!(ax, C, s, d, steps, k)
    m, n = size(C)
    F, sl, dl = replay(C, s, d, steps, k)
    _, sp, dp = replay(C, s, d, steps, max(k - 1, 0))   # before step k
    ak, bk = k == 0 ? (0, 0) : (steps.From[k], steps.To[k] - m)
    for a in 1:m, b in 1:n                # cell (a,b) from (b-1, m-a)
        here = (a, b) == (ak, bk)
        used = sl[a] == 0 || dl[b] == 0
        fc = here ? (bluec, 0.18) : used ? (ink, 0.1) : (:white, 0.0)
        poly!(ax, Rect2f(b - 1, m - a, 1, 1); color = fc)
        text!(ax, b - 0.1, m - a + 0.9; text = string(C[a, b]),
              color = used && !here ? (ink, 0.55) : ink, fontsize = 11,
              align = (:right, :top))
        F[a, b] > 0 || continue
        text!(ax, b - 0.55, m - a + 0.35; text = string(F[a, b]),
              color = here ? bluec : ink, fontsize = 13, font = :bold,
              align = (:center, :center))
    end
    linesegments!(ax, [Point2f(x, y) for x in 0:n for y in (0, m)];
                  color = ink, linewidth = 0.8)
    linesegments!(ax, [Point2f(x, y) for y in 0:m for x in (0, n)];
                  color = ink, linewidth = 0.8)
    k == 0 || poly!(ax, Rect2f(bk - 1, m - ak, 1, 1); strokewidth = 2,
                    color = (:white, 0.0), strokecolor = bluec)
    for a in 1:m                          # supply nodes and supply left
        text!(ax, -0.35, m - a + 0.5; text = string(a), color = supc,
              fontsize = 13, align = (:center, :center))
        y = m - a + 0.5
        if a == ak                        # struck, and the new value
            struck!(ax, n + 0.4, y, sp[a], supc)
            text!(ax, n + 1.05, y; text = string(sl[a]), color = supc,
                  fontsize = 12, font = :bold, align = (:center, :center))
        else
            text!(ax, n + 0.4, y; text = string(sl[a]), color = supc,
                  fontsize = 12, align = (:center, :center))
        end
    end
    for b in 1:n                          # demand nodes and demand left
        text!(ax, b - 0.5, m + 0.35; text = string(m + b), color = demc,
              fontsize = 13, align = (:center, :center))
        if b == bk                        # struck, the new value below
            struck!(ax, b - 0.5, -0.35, dp[b], demc)
            text!(ax, b - 0.5, -0.85; text = string(dl[b]), color = demc,
                  fontsize = 12, font = :bold, align = (:center, :center))
        else
            text!(ax, b - 0.5, -0.35; text = string(dl[b]), color = demc,
                  fontsize = 12, align = (:center, :center))
        end
    end
    xlims!(ax, -0.7, n + 1.45); ylims!(ax, -1.15, m + 0.7)
    return nothing
end

fig = Figure(size = (687, 470))
for k in 0:nrow(steps)                    # the start, then each step
    title = k == 0 ? "Start: the costs, supply and demand" :
            "Step $k: $(steps.Cost[k]) from $(steps.From[k]) to " *
            "$(steps.To[k]), $(steps.Units[k]) units"
    axk = Axis(fig[k ÷ 3 + 1, k % 3 + 1]; aspect = DataAspect(), title,
               titlesize = 12, titlefont = :regular)
    hidedecorations!(axk); hidespines!(axk)
    greedystep!(axk, C, s, d, steps, k)
end
# Below the frames: each step's cost times its units, and their sum
Label(fig[3, 1:3], "Total cost:  " *
      join(["$(st.Cost) × $(st.Units)" for st in eachrow(steps)], " + ") *
      " = " * commas(Int(TCg)); fontsize = 13, color = ink)
colgap!(fig.layout, 6); rowgap!(fig.layout, 4)
fig

## Example 4(b): As a linear program
# Determine the shipments of least total cost as @mdl-transportation,
# and compare its total cost with greedy's.
# Code block 40: the tableau solved as a linear program
TCᵒ, Xᵒ = trans(C, s, d)
@show TCᵒ; Xᵒ
# Code block 41: shipments, with supply and demand totals
M = [Xᵒ sum(Xᵒ, dims=2) s; sum(Xᵒ, dims=1) NaN NaN; d' NaN NaN]
prt(M; rows = ["1", "2", "3", "Shipped", "Demand"],
# prt labels a matrix's rows and columns with rows and cols, and its
# corner with row_title; a NaN prints as a blank, for the corner cells
# that hold no total.
    cols = ["4", "5", "6", "7", "Shipped", "Supply"], row_title = "Node")
# Code block 42: every demand at its cheapest arc, supply unlimited
LB = sum(minimum(C, dims = 1)' .* d)

## Example 4(c): Too little supply
# Determine what the linear program returns when node 1's supply falls
# from 55 to 25.
# Code block 43: node 1's supply cut to 25
s = [25, 50, 40]
@show sum(s) - sum(d)
try
    trans(C, s, d)
catch e
    showerror(stdout, e)
end

# Example 5: Capacitated allocation
## Example 5(a): Uncapacitated as in Lecture 2.3
# Allocate each city to its nearer DC, and determine the population each
# DC serves.
# Code block 44: the NC cities over 100,000, and the two DCs
df = filter(r -> r.STFIP == st2fips(:NC) && r.POP > 100_000, usplace())
select!(df, :NAME, :LAT, :LON, :POP)
P = hcat(df.LON, df.LAT)          # one row per city
w = df.POP
name2lonlat(nm) = collect(filter(r -> r.NAME == nm, df)[1, [:LON, :LAT]])
X = vcat(name2lonlat("Charlotte")', name2lonlat("Raleigh")')
D = dists(X, P, :mi)              # 2 x m great circle distances
prt(df)
# Code block 45: each city to its nearer DC, uncapacitated
using SparseArrays
n, m = size(D)
alloc(X) = sparse([argmin(c) for c in eachcol(dists(X, P, :mi))],
                  1:m, w, n, m)
W = alloc(X)'
@show sum(W' .* D)                # person-mi, as in Lecture 2.3
sum(W, dims=1)                    # people served by each DC

## Example 5(b): Each DC at 1.5 million
# Allocate the cities' populations to the two DCs, each limited to 1.5
# million, as @mdl-transportation, and compare with greedy.
# Code block 46: capacity constrained, as a transportation problem
s = [1_500_000, 1_500_000]
d = w
alloc(X) = trans(dists(X, P, :mi), s, d)
TCc, Wc = alloc(X)
@show TCc
@show TCc - sum(W' .* D)          # what the capacity costs
prt(DataFrame(NAME = df.NAME, POP = w,
              Charlotte = Wc[1, :], Raleigh = Wc[2, :]))
# Code block 47: the capacitated allocation, mapped
sp = [k for k in 1:m if count(>(0), Wc[:, k]) > 1]   # the split city
fig, ax = makemap(df.LON, df.LAT; xexpand = 0.2)
resize!(fig, 687, 500)
for (k, col) in ((1, dcc), (2, supc))                 # Charlotte, Raleigh
    Lx, Ly = alloclines(Wc[k:k, :], X[k:k, :], P)
    for i in eachindex(Lx)
        lines!(ax, Lx[i], Ly[i]; color = col, linewidth = 1)
    end
end
scatter!(ax, P[:, 1], P[:, 2]; color = ink, markersize = 6)
scatter!(ax, X[:, 1], X[:, 2]; marker = :dtriangle, markersize = 14,
         color = ink)
lx, ly = [X[:, 1]; P[sp, 1]], [X[:, 2]; P[sp, 2]]
text!(ax, lx, ly; text = ["Charlotte"; "Raleigh"; df.NAME[sp]],
      fontsize = 12,              # each clear of its lines and the border
      align = [(:right, :bottom), (:left, :center), (:center, :bottom)],
      offset = [(-6, 4), (9, 0), (0, 5)])
fig
# Code block 48: the same allocation by the greedy procedure of Ex. 4
Fg5, TCg5, _ = gtrans(D, s, d)
@show TCg5
@show TCg5 - TCc                  # what greedy costs over the optimum
splitg = df.NAME[[k for k in 1:m if count(>(0), Fg5[:, k]) > 1]]
prt(DataFrame(NAME = df.NAME, POP = w,
              Charlotte = Fg5[1, :], Raleigh = Fg5[2, :]))
# Code block 49: the cost as each DC's capacity moves
caps = [1_450_000, 1_500_000, 1_600_000]
prt(DataFrame(Capacity = caps,
              PersonMiles = [trans(D, [c, c], d).TC for c in caps]))

## Sec. 4. Minimum cost network flow
# Code block 50: drawing a network with its net supplies
# Nodes at XY; arc k from I[k] to J[k] labeled lab[k] in size ls, at
# fraction at[k] along it, on side side[k], the arc shifted sideways by
# off[k] (for parallel arcs); net supply s[i] beside node i, away from
# its arcs
function drawnet(XY, I, J, lab, s; off = zeros(length(I)), r = 0.17,
                 w = 380, h = 260, lim = nothing,
                 at = fill(0.5, length(I)),
                 side = [o >= 0 ? 1 : -1 for o in off], ls = 13)
    fig = Figure(size = (w, h))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    for k in eachindex(I)
        p, q = XY[I[k]], XY[J[k]]
        u = (q .- p) ./ hypot((q .- p)...)
        nrm = (-u[2], u[1])
        t = p .+ r .* u .+ off[k] .* nrm
        hd = q .- (r + 0.015) .* u .+ off[k] .* nrm
        arrows2d!(ax, [t[1]], [t[2]], [hd[1] - t[1]], [hd[2] - t[2]];
                  color = ink, shaftwidth = 1.3, tipwidth = 8,
                  tiplength = 8)
        m = t .+ at[k] .* (hd .- t) .+ 0.01ls * side[k] .* nrm
        text!(ax, m[1], m[2]; text = lab[k], color = ink, fontsize = ls,
              align = (:center, :center))
    end
    for (i, (x, y)) in enumerate(XY)          # the nodes, over the arcs
        c = s[i] > 0 ? supc : s[i] < 0 ? demc : ink
        poly!(ax, Circle(Point2f(x, y), r); color = :white,
              strokecolor = c, strokewidth = 1.8)
        text!(ax, x, y; text = string(i), color = c, fontsize = 14,
              align = (:center, :center))
        s[i] == 0 && continue
        a = sum(collect(XY[j] .- (x, y)) ./ hypot((XY[j] .- (x, y))...)
                for j in [J[I .== i]; I[J .== i]])  # toward its arcs
        a = a ./ hypot(a...)
        text!(ax, x - (r + 0.16) * a[1], y - (r + 0.16) * a[2];
              text = replace(string(s[i]), "-" => "−"),  # minus sign
              color = c, fontsize = 13, align = (:center, :center))
    end
    lim === nothing || (xlims!(ax, lim[1]...); ylims!(ax, lim[2]...))
    return fig
end

XY5 = [(0.0, 1.0), (1.2, 1.8), (1.2, 0.2), (2.4, 1.8), (2.4, 0.2)]
drawnet(XY5, [1, 1, 2, 2, 3, 4], [2, 3, 4, 5, 5, 5],
        string.([2, 3, 4, 5, 1, 3]), [6, 2, 0, 0, -8];
        lim = ((-0.4, 2.8), (-0.2, 2.3)))

# Sec. 4. Minimum cost network flow
## Model: Minimum cost network flow
# Model: minimum cost network flow
# Incidence matrix from an arc list: arc k from i[k] to j[k], +1 where it
# starts and -1 where it ends, one column per arc in the list's order
list2incid(i, j, n) = sparse([i; j], [1:length(i); 1:length(i)],
# sparse(I, J, V, n, m), as in Lecture 2.3, puts V[k] at row I[k] and
# column J[k] of an $n \times m$ matrix: here the rows are the arcs' start
# nodes and then their end nodes, the columns the arc numbers twice, and
# the values $+1$ and then $-1$. Built from the arc list itself, every arc
# keeps its own column in the order listed, including the parallel arcs of
# Ex. 6(d), which a graph built from the same list would merge.
                             [ones(length(i)); -ones(length(j))],
                             n, length(i))

function mcnf(A, c, s; u = fill(Inf, size(A, 2)), l = zeros(size(A, 2)))
    V, E = 1:size(A, 1), 1:size(A, 2)
    model = Model(HiGHS.Optimizer)
    @variable(model, l[k] ≤ x[k ∈ E] ≤ u[k])                  # (b)
    # Row (b) is written as bounds on the variables rather than as
    # constraints: each x[k] lies between its own l[k] and u[k], and an
    # upper bound of Inf is no bound at all.
    @objective(model, Min, sum(c[k] * x[k] for k ∈ E))
    @constraint(model, supply[i ∈ V; s[i] > 0],
    # The condition after the semicolon keeps only the nodes that meet it:
    # one row (a) for each supply node here, and one for every other node
    # in the balance rows below.
                sum(A[i, k] * x[k] for k ∈ E) ≤ s[i])               # (a)
    @constraint(model, balance[i ∈ V; s[i] ≤ 0],
                sum(A[i, k] * x[k] for k ∈ E) == s[i])              # (a)

    set_silent(model)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)))
    end
    error(termination_status(model))
end

## Sec. 4. Minimum cost network flow
# Code block 51: the five-node network's arcs, costs and net supplies
i = [1, 1, 2, 2, 3, 4]
j = [2, 3, 4, 5, 5, 5]
c = [2, 3, 4, 5, 1, 3]
s = [6, 2, 0, 0, -8]
A = list2incid(i, j, length(s))
Matrix([c' 0; A s])

# Example 6: Small networks as flows
## Example 6(a): Ex. 4's transportation problem
# Solve Ex. 4's transportation problem as a minimum cost network flow,
# and compare the total cost with Ex. 4(b)'s.
# Code block 52: Ex. 4's tableau as an arc list, solved as a network flow
C = [8 6 10 9; 9 12 13 7; 14 9 16 5]
m, n = size(C)
i = repeat(1:m, n)                # supply node of each arc
j = m .+ repeat(1:n, inner = m)   # demand node of each arc
# vec(C) lists C column by column, so the arcs are listed the same way:
# supply nodes 1, 2, 3, 1, 2, 3, ... and demand nodes 4, 4, 4, 5, 5, 5,
# ..., numbered after the supply nodes. Listed this way, reshape(xᵒ, m, n)
# returns the flows in the tableau's layout.
c = vec(C)                        # cost of each arc, column by column
s = [55, 50, 40, -45, -20, -30, -30]
A = list2incid(i, j, m + n)
TCᵒ, xᵒ = mcnf(A, c, s)
@show TCᵒ; reshape(xᵒ, m, n)

## Example 6(b): Shortest path
# Determine the shortest path from node 1 to node 6 of Lecture 4.1's
# six-node network, its arcs directed ({{< xref 4.1
# fig-six-node-directed >}}, repeated here as @fig-six-node-mcnf with
# what makes it a flow), as a minimum cost network flow, and then the
# shortest such path that uses the arc from node 2 to node 3.
# Code block 53: Lecture 4.1's six-node network, directed, as a flow
i = [1, 1, 2, 2, 3, 3, 4, 4, 5]
j = [2, 3, 3, 4, 4, 5, 5, 6, 6]
c = [4, 2, 1, 5, 8, 10, 2, 6, 3]
s = [1, 0, 0, 0, 0, -1]
A = list2incid(i, j, length(s))
Matrix([c' 0; A s])
# Code block 54: Ex. 6(b)'s network as a flow, drawn with Code block 50
# The nodes where Lecture 4.1 draws them, and each cost on the side of
# its arc where Lecture 4.1 puts the arc's length
XY6 = [(0.0, 0.0), (1.0, 0.58), (1.0, -0.58), (2.0, 0.58),
       (2.0, -0.58), (3.0, 0.0)]
fig = drawnet(XY6, i, j, string.(c), s; w = 440, h = 200,
              lim = ((-0.6, 3.6), (-0.8, 0.8)),
              side = [1, -1, -1, 1, 1, 1, -1, 1, -1])
# The lower bound on arc (2,3), on the side of it clear of its cost
text!(content(fig[1, 1]), 1.07, 0.24; text = L"l = 1", color = ink,
      fontsize = 13, align = (:left, :center))
fig
# Code block 55: the shortest path as a minimum cost network flow
TCᵒwoBnds, xᵒwoBnds = mcnf(A, c, s)
@show TCᵒwoBnds; xᵒwoBnds'
# Code block 56: a lower bound of 1 on arc (2,3)
idx = findfirst(==((2, 3)), collect(zip(i, j)))   # Arc (2,3)'s index
l = zeros(length(i))
l[idx] = 1
u = fill(Inf, length(i))
[u l]
# Code block 57: the shortest path through arc (2,3)
TCᵒ, xᵒ = mcnf(A, c, s; u = u, l = l)
@show TCᵒ
@show TCᵒwoBnds
prt([xᵒwoBnds xᵒ]; rows = string.("(", i, ",", j, ")"),
    cols = ["No bound", "Through (2,3)"], row_title = "Arc")

## Example 6(c): Arc bounds
# Solve the network of @fig-five-node, then solve it again with an upper
# bound of 3 on arcs (2,4) and (3,5), an upper bound of 9 on arc (2,5),
# and a lower bound of 1 on arc (4,5), and compare the two total costs.
# Code block 58: the arc list, with its bounds, as a string
using DataFrames, CSV

arclist_str = """
i,j,c,u,l
1,2,2,,
1,3,3,,
2,5,5,9,
2,4,4,3,
3,5,1,3,
4,5,3,,1
"""
println(arclist_str)
arclist_str
# Code block 59: the string read into a DataFrame
df = CSV.read(IOBuffer(arclist_str), DataFrame)
# IOBuffer makes the string read like a file, so CSV.read parses it into a
# DataFrame as it would a .csv file on disk.
prt(string.(df))
# Each empty field of the string is read as missing, which Code block 60
# fills. prt cannot yet print a missing in a table of numbers, so string.
# turns every entry into text first; df itself keeps its numbers.
# Code block 60: the default bounds filled in
df.u = coalesce.(df.u, Inf) # Replace missing values in 'u' with infinity
df.l = coalesce.(df.l, 0)   # Replace missing values in 'l' with zero
prt(df)
# Code block 61: the network without its bounds, and with them
s = [6, 2, 0, 0, -8]
A = list2incid(df.i, df.j, length(s))
TCᵒwoBnds, xᵒwoBnds = mcnf(A, df.c, s)
TCᵒ, xᵒ = mcnf(A, df.c, s; u = df.u, l = df.l)
@show TCᵒ
@show TCᵒwoBnds
df.xᵒ, df.xᵒwoBnds = xᵒ, xᵒwoBnds
prt(df)

## Example 6(d): A capacitated mode
# In the multigraph of {{< xref 4.1 fig-multigraph >}}, nodes 1, 2 and 3
# supply 30, 10 and 20 units, and nodes 4 and 5 demand 40 and 20. The
# cheaper of the two modes between nodes 1 and 4, at a cost of 6 per
# unit, can carry at most 20 units; the other, at 18, is uncapacitated.
# Determine the least-cost flows, with and without the capacity.
# Code block 62: Lecture 4.1's multigraph, from its arc list, as a flow
i = [1, 4, 1, 4, 1, 2, 2, 3, 3]     # two-way arcs 1-4 listed both ways
j = [4, 1, 4, 1, 5, 4, 5, 5, 5]
c = [6, 6, 18, 18, 10, 0, 13, 16, 3]
s = [30, 10, 20, -40, -20]
u = [20, Inf, Inf, Inf, Inf, Inf, Inf, Inf, Inf]   # cheap mode 1 -> 4
A = list2incid(i, j, length(s))
TCᵒwoBnds, xᵒwoBnds = mcnf(A, c, s)
TCᵒ, xᵒ = mcnf(A, c, s; u = u)
@show TCᵒ
@show TCᵒwoBnds
prt([i j c u xᵒwoBnds xᵒ]; row_title = "Arc",
    cols = ["From", "To", "Cost", "Capacity", "Uncapped", "Capped"])

## Example 7: Three-level network
# Two plants, which can supply 65 and 80 units, ship to the three supply
# nodes of Ex. 4, now DCs that only pass flow through, at costs per unit
# of 4, 6 and 5 from the first plant to the three DCs and 3, 8 and 2
# from the second; the DCs ship to Ex. 4's demand nodes at its costs.
# Determine the least-cost flows through the network, and compare the
# result with the transportation problem the network reduces to.
# Code block 63: two plants, three DCs and four customers, as a flow
C12 = [4 6 5; 3 8 2]                     # plant to DC
C23 = [8 6 10 9; 9 12 13 7; 14 9 16 5]   # DC to customer, Ex. 4's C
p, m, n = size(C12, 1), size(C12, 2), size(C23, 2)
i = [repeat(1:p, m); p .+ repeat(1:m, n)]
j = [p .+ repeat(1:m, inner = p); p + m .+ repeat(1:n, inner = m)]
c = [vec(C12); vec(C23)]
s = [65, 80, 0, 0, 0, -45, -20, -30, -30]
A = list2incid(i, j, p + m + n)
TCᵒ, xᵒ = mcnf(A, c, s)
@show TCᵒ
F12 = reshape(xᵒ[1:p*m], p, m)           # plant to DC
F23 = reshape(xᵒ[p*m+1:end], m, n)       # DC to customer
prt(F12; rows = string.(1:p), cols = string.(p+1:p+m),
    row_title = "Plant")
prt(F23; rows = string.(p+1:p+m), cols = string.(p+m+1:p+m+n),
    row_title = "DC")
# Code block 64: the three-level network, drawn with Code block 50
XY3 = [(0.0, 1.8), (0.0, 0.6), (1.3, 2.4), (1.3, 1.2), (1.3, 0.0),
       (2.6, 2.7), (2.6, 1.8), (2.6, 0.9), (2.6, 0.0)]
# Each cost near its arc's tail, on the side clear of the other arcs
drawnet(XY3, i, j, string.(c), s; w = 520, h = 410, ls = 10,
        lim = ((-0.5, 3.1), (-0.4, 3.1)), at = fill(0.16, length(i)),
        side = [fill(1, 10); -1; -1; 1; fill(-1, 5)])
# Code block 65: the cheapest two-leg costs, as a transportation problem
C13 = [minimum(C12[a, k] + C23[k, b] for k in 1:m) for a in 1:p, b in 1:n]
TC13, X13 = trans(C13, s[1:p], -s[p+m+1:end])
@show TC13; C13
