# 2-loc-5 — generated from 2-loc-5.qmd by tools/qmd_to_jl.py
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

using Logjam, DataFrames, Optim, CSV, CairoMakie, GeoMakie

## Sec. 1. Actual and population-inferred demand
# Demand CLASS is the hue. Both are chosen to read against the state
# borders at dot size; a dark hue does not.
actual = colorant"#0f9aa8"               # actual demand
inferred = colorant"#c4342b"             # population-inferred demand

# `makemap`'s road layer is the FAF5 INTERSTATE skeleton: the right
# background for a national map, too sparse for a metropolitan one, where
# `plotroads!` draws the full network. The boundary is a DISTANCE, about
# 150 miles across. Logjam's own thresholds are in degrees of latitude --
# 30 to draw roads at all, tiers at 20 and 10 -- and the finest is near
# 690 miles, far too coarse to make this call: North Carolina is 489
# miles across and does not want the dense network.
const CLOSE = 150.0                      # miles

function extent(lon, lat)            # larger of NS and EW, in miles
    x0, x1 = extrema(lon); y0, y1 = extrema(lat)
    xm, ym = (x0 + x1) / 2, (y0 + y1) / 2
    return max(dgc([xm, y0], [xm, y1]), dgc([x0, ym], [x1, ym]))
end

function dotmap(lon, lat, title; color = inferred, dot = 4.0,
                w = 700, h = 400, region = nothing)
    close = extent(lon, lat) <= CLOSE
    fig, ax = isnothing(region) ?
        makemap(lon, lat; xexpand = 0.02, yexpand = 0.02,
                doRoadbkgd = !close) :
        makemap(; region = region)
    if close
        # Same hue as makemap's own roads, so the two layers look alike.
        for (k, v) in plotroads!(ax, faf5nodes(), faf5links())
            v.color = (:steelblue,
                       startswith(String(k), "casing") ? 0.12 : 0.45)
        end
    end
    scatter!(ax, lon, lat; markersize = dot, color = color)
    ax.title = title
    ax.titlesize = 15
    resize!(fig, w, h)
    return fig
end

cus(df) = filter(r -> r.ISCUS && r.POP > 0, df)
p10 = filter(r -> r.POP >= 10_000, cus(usplace()))
dotmap(p10.LON, p10.LAT, "$(nrow(p10)) cities with 10K+ population";
       dot = 2.6, region = :CUS)
# HIDDEN, and the reason is the data rather than the code. The foundry plant
# list is purchased and is not public, so a student cannot run this even
# though the drawing is the same `dotmap` call as @fig-cities10k, whose code
# IS shown. Code that cannot be run is not an example.
fzip = CSV.read("source/_data-foundry-zips.csv", DataFrame).ZCTA5
z5all = uszcta5()
fnd = filter(r -> r.ISCUS,
             z5all[filter(!isnothing,
                          [findfirst(==(z), z5all.ZCTA5)
                           for z in unique(fzip)]), :])
dotmap(fnd.LON, fnd.LAT, "$(nrow(fnd)) U.S. foundries";
       color = actual, region = :CUS)

## Sec. 2. U.S. statistical geography
# Code block 1: two cities against the metropolitan areas they name
pl, cs = usplace(), uscsa()
pop(df, s) = maximum(filter(r -> occursin(s, r.NAME), df).POP)
prt(DataFrame(place = ["Atlanta", "Jacksonville"],
              city = [pop(pl, "Atlanta"), pop(pl, "Jacksonville")],
              metro = [pop(cs, "Atlanta"), pop(cs, "Jacksonville")]))

## Sec. 3. Choosing a resolution
# Code block 2: how many demand points each source yields
OFF = [2, 15, 60, 66, 69, 72, 78]  # non-continental state FIPS
cus(df) = "ISCUS" in names(df) ? filter(r -> r.ISCUS, df) :
                                 filter(r -> !(r.STFIP in OFF), df)
src = [("places", usplace()), ("3-digit ZCTA", uszcta3()),
       ("county", uscounty()), ("5-digit ZCTA", uszcta5()),
       ("census tract", uscentract()), ("block group", uscenblkgrp())]
prt(DataFrame(source = first.(src),
              continental = [nrow(cus(d)) for (_, d) in src]))
p50 = filter(r -> r.POP >= 50_000, cus(usplace()))
dotmap(p50.LON, p50.LAT, "$(nrow(p50)) cities with 50K+ population";
       region = :CUS)
z3 = filter(r -> r.ISCUS && r.POP > 0, uszcta3())
dotmap(z3.LON, z3.LAT, "$(nrow(z3)) 3-digit ZIP codes"; region = :CUS)
znc = filter(r -> 27_000 <= r.ZCTA5 <= 28_999, uszcta5())
dotmap(znc.LON, znc.LAT,
       "$(nrow(znc)) 5-digit ZIP codes in North Carolina"; h = 340)
csa5 = filter(r -> startswith(r.NAME, "Ral"), uscsa())
cbsa5 = filter(r -> !ismissing(r.CSA) && r.CSA in csa5.CSA, uscbsa())
co5 = filter(r -> !ismissing(r.CBSA) && r.CBSA in cbsa5.CBSA, uscounty())
bg5 = filter(r -> r.STFIP in co5.STFIP && r.COFIP in co5.COFIP,
             uscenblkgrp())
dotmap(bg5.LON, bg5.LAT, "$(nrow(bg5)) block groups, Raleigh CSA";
       dot = 3.4, w = 560, h = 500)

# Sec. 3. Choosing a resolution
# Example 1: Demand points for North Carolina
## Example 1(a): What each source yields
# Determine the number of demand points each of the six census sources
# provides for North Carolina.
# Code block 3: five sources, one state
NC = st2fips(:NC)
bystate(df) = filter(r -> r.STFIP == NC, df)
byzcta(df, k, lo, hi) = filter(r -> lo <= r[k] <= hi, df)
nc = [("places", nrow(bystate(usplace()))),
      ("3-digit ZCTA", nrow(byzcta(uszcta3(), :ZCTA3, 270, 289))),
      ("county", nrow(bystate(uscounty()))),
      ("5-digit ZCTA", nrow(byzcta(uszcta5(), :ZCTA5, 27000, 28999))),
      ("census tract", nrow(bystate(uscentract()))),
      ("block group", nrow(bystate(uscenblkgrp())))]
prt(DataFrame(source = first.(nc), points = last.(nc)))

## Example 1(b): The optimum at the finest resolution
# Determine the population-weighted minisum location for North Carolina
# using every census block group as a demand point.
# Code block 4: minisum over every North Carolina block group
bg = filter(r -> r.STFIP == NC, uscenblkgrp())
pt = eachrow(hcat(bg.LON, bg.LAT))
TC(xy) = sum(bg.POP .* dgc.([xy], pt))
w = wcentroid(bg.LON, bg.LAT, bg.POP)
xᵒ = optimize(TC, [w.LON, w.LAT]).minimizer
# Code block 5: how many points, how many people, and where
prt(DataFrame(points = nrow(bg), population = sum(bg.POP),
              nearest = lonlat2loc(xᵒ, usplace()).desc))
# Presentation only: thousands separators for numbers quoted inline. Logjam's
# own `_commasep` is private, so a lecture cannot reach it (change request 8).
com(n) = replace(string(n), r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")

## Sec. 3. Choosing a resolution
# Presentation only: @tbl-sources collates the counts computed in code
# blocks 2 and 3, separating thousands the way prt does. The CSA column
# reuses co5 and bg5 from @fig-res-blkgrp. Only county, tract and block
# group nest in a county, so only those three can be cut to a CSA: the
# ZCTA tables carry no geographic key at all, and only 1,280 of
# usplace's 31,617 rows carry a CBSA code, the principal cities
# (measured 2026-09-08).
com(n) = replace(string(n), r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")
usn, ncn = [nrow(cus(d)) for (_, d) in src], last.(nc)
tr5 = filter(r -> r.STFIP in co5.STFIP && r.COFIP in co5.COFIP,
             uscentract())
csan = ["n/a", "n/a", com(nrow(co5)), "n/a",
        com(nrow(tr5)), com(nrow(bg5))]

## Sec. 4. Aggregating demand points
# Code block 6: the aggregate reproduces the total, the median does not
mi = [50, 150, 190, 220, 270, 295, 420]   # I-40 mile markers, lecture 2.1
wi = 1:7                                  # illustrative weights
x0 = 0                                    # any reference point will do
xc = sum(wi .* mi) / sum(wi)              # the weighted centroid
half = sum(wi) / 2
xm = mi[findfirst(c -> c >= half, cumsum(wi))]           # the median
prt(DataFrame(measured_from = ["all seven", "the centroid", "the median"],
              at = round.([x0, xc, xm], digits = 2),
              total = round.(Int, [sum(wi .* abs.(mi .- x0)),
                                   sum(wi) * abs(xc - x0),
                                   sum(wi) * abs(xm - x0)])))
# Roles, per the course palette: weights are the input (red), positions
# locate the figure (ink), and the aggregate is the answer (maroon).
wc = colorant"#d21f26"; ink = colorant"#252525"; agg = colorant"#b23a48"

"""A number line from `lo` to `hi`, arrowed at both ends."""
function numberline(lo, hi; height = 210, width = 700, fs = 15)
    fig = Figure(size = (width, height))
    ax = Axis(fig[1, 1]); hidedecorations!(ax); hidespines!(ax)
    pad = 0.09 * (hi - lo)
    xlims!(ax, lo - pad, hi + pad); ylims!(ax, -1.02, 0.62)
    lines!(ax, [lo - pad, hi + pad], [0, 0]; color = ink,
           linewidth = 1.6)
    for (xt, m) in ((lo - pad, :ltriangle), (hi + pad, :rtriangle))
        scatter!(ax, [xt], [0]; marker = m, markersize = 11, color = ink)
    end
    return fig, ax, fs
end

"""Tick at `x`: its symbol above, stacked labels below."""
function tick!(ax, x, above, below...;
               fs = 15, color = ink, mark = nothing)
    lines!(ax, [x, x], [-0.11, 0.11]; color = ink, linewidth = 1.4)
    text!(ax, x, 0.30; text = above, fontsize = fs, color = color,
          align = (:center, :bottom))
    if mark !== nothing
        scatter!(ax, [x], [0]; marker = :circle, markersize = 19,
                 color = :white, strokecolor = wc, strokewidth = 1.6)
        text!(ax, x, 0.0; text = mark, fontsize = fs - 3, color = wc,
              align = (:center, :center))
    end
    # Row 2 is the weight and takes the accent; a coordinate never does.
    for (k, s) in enumerate(below)
        text!(ax, x, -0.20 - 0.30 * (k - 1); text = s, fontsize = fs,
              color = k == 2 ? (color === ink ? wc : color) : ink,
              align = (:center, :top))
    end
end

x1, w1, x2, w2 = 10, 1, 40, 2
xagg = (x1 * w1 + x2 * w2) / (w1 + w2)
fig, ax, fs = numberline(0, 40)
tick!(ax, 0, L"x", "0"; fs = fs)
tick!(ax, x1, L"x_1", "$x1", L"w_1 = 1", "Durham"; fs = fs, mark = "1")
tick!(ax, x2, L"x_2", "$x2", L"w_2 = 2", "Raleigh"; fs = fs, mark = "2")
tick!(ax, xagg, L"x_\mathrm{agg}", "$(Int(xagg))", L"w_\mathrm{agg} = 3";
      fs = fs, color = agg)
fig

# Sec. 4. Aggregating demand points
## Example 2: Building a two-digit ZCTA demand set
# Determine an aggregate demand set for the continental United States at
# two-digit ZIP resolution, by grouping the three-digit ZCTAs and
# computing the weight, location and extent of each group.
# Code block 7: group the three-digit ZCTAs by their first two digits
z = filter(r -> r.ISCUS, uszcta3())
# `÷` is integer division, the floor of the quotient: 274 ÷ 10 = 27.
# Dividing by 10 and dropping the remainder is what removes the last
# digit, leaving the two-digit prefix that names the group.
z.ZCTA2 = z.ZCTA3 .÷ 10
# `groupby` splits one frame into one per distinct key, the operation
# SQL spells GROUP BY. Sec. 7 takes up the split-apply-combine idiom
# it belongs to.
g = groupby(z, :ZCTA2)
# Code block 8: weight, location and extent of every group
z2 = combine(g,
    [:LON, :LAT, :POP] => ((x, y, w) -> wcentroid(x, y, w).LON) => :LON,
    [:LON, :LAT, :POP] => ((x, y, w) -> wcentroid(x, y, w).LAT) => :LAT,
    :POP => sum => :POP, :ALAND => sum => :ALAND)
prt(first(z2, 5))
# Code block 9: what the aggregation cost, and what it preserved
prt(DataFrame(level = ["3-digit", "2-digit"],
              points = [nrow(z), nrow(z2)],
              population = [sum(z.POP), sum(z2.POP)],
              area = round.([sum(z.ALAND), sum(z2.ALAND)])))

## Sec. 5. Average distance within a region
# The source gives the weights and the left-to-right order but not the
# coordinates, and states the centroid is 25. These positions are the ones
# that reproduce it; the centroid below is computed, never asserted.
xe = [10, 14, 21, 26, 30, 40]
we = [1, 3, 1, 2, 4, 2]
lbl = ["1", "3", "4", "5", "6", "2"]
num = ["10", "", "", "", "", "40"]
xc = sum(xe .* we) / sum(we)
@assert xc == 25 && sum(we) == 13

fig, ax, fs = numberline(0, 40)
tick!(ax, 0, L"x", "0"; fs = fs)
for (x, w, s, n) in zip(xe, we, lbl, num)
    tick!(ax, x, L"x_%$s", n, L"w_%$s = %$w"; fs = fs, mark = s)
end
fig
regc = colorant"#f2d64b"                 # the region itself
dc = colorant"#d21f26"; rc = colorant"#2f7cb0"    # the two distances
xb, xt = extrema(xe)                     # the extent the points occupied
r = (xt - xb) / 2                        # radius: half the segment
xin = 20                                 # a facility inside the region
# Uniform demand: the centroid is the midpoint of the extent.
@assert r == 15 && xc == (xb + xt) / 2

"""An arrow from `x0` to `x1` at height `y`, labelled above its middle."""
function span!(ax, x0, x1, y, lab, col; fs = 15)
    lines!(ax, [x0, x1], [y, y]; color = col, linewidth = 2.0)
    scatter!(ax, [x1], [y]; color = col, markersize = 12,
             marker = x1 > x0 ? :rtriangle : :ltriangle)
    text!(ax, (x0 + x1) / 2, y + 0.05; text = lab, fontsize = fs,
          color = col, align = (:center, :bottom))
    return nothing
end

"""Below the line: the coordinate, then the symbol under it."""
function foot!(ax, x, num, sym; fs = 15, color = ink, extra = nothing)
    lines!(ax, [x, x], [-0.11, 0.11]; color = ink, linewidth = 1.4)
    text!(ax, x, -0.20; text = num, fontsize = fs, color = ink,
          align = (:center, :top))
    text!(ax, x, -0.52; text = sym, fontsize = fs, color = color,
          align = (:center, :top))
    extra === nothing || text!(ax, x, -0.84; text = extra,
                               fontsize = fs, color = color,
                               align = (:center, :top))
    return nothing
end

fig, ax, fs = numberline(0, 40; height = 250)
ylims!(ax, -1.30, 0.95)
poly!(ax, Point2f[(xb, 0.06), (xt, 0.06), (xt, 0.34), (xb, 0.34)];
      color = regc, strokecolor = ink, strokewidth = 1.2)
text!(ax, (xb + xt) / 2, 0.20; text = "Line segment region",
      fontsize = fs, color = ink, align = (:center, :center))
span!(ax, xc, xin, 0.58, L"d", dc; fs = fs)
span!(ax, xc, xt, 0.58, L"r", rc; fs = fs)
# Both spans start at the centroid. A tick at the shared origin keeps the
# two readable when colour alone is not.
lines!(ax, [xc, xc], [0.51, 0.65]; color = ink, linewidth = 1.4)
foot!(ax, 0, "0", L"x_\mathrm{out}"; fs = fs)
foot!(ax, xb, "$xb", L"x_\mathrm{begin}"; fs = fs)
foot!(ax, xin, "$xin", L"x_\mathrm{in}"; fs = fs)
foot!(ax, xc, "$(Int(xc))", L"x_\mathrm{agg} = x_\mathrm{centroid}";
      fs = fs, color = agg, extra = L"w_\mathrm{agg} = 13")
foot!(ax, xt, "$xt", L"x_\mathrm{end}"; fs = fs)
fig
θ = range(0, 2π; length = 400)
fig = Figure(size = (300, 300))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
lines!(ax, cos.(θ), sin.(θ); color = ink, linewidth = 1.6)
scatter!(ax, [0], [0]; color = ink, markersize = 7)
span2!(x, y, lab, col) = begin
    lines!(ax, [0, x], [0, y]; color = col, linewidth = 2.4)
    scatter!(ax, [x], [y]; color = col, markersize = 13,
             marker = :utriangle, rotation = atan(y, x) - π / 2)
    # Label sits OFF its line, offset along the perpendicular, so no
    # glyph crosses the segment it names.
    n = 15 / hypot(x, y)
    text!(ax, x / 2, y / 2; text = lab, fontsize = 24, color = col,
          align = (:center, :center), offset = (-y * n, x * n))
end
span2!(1.0, 0.0, L"r", rc)                    # centroid to the edge
span2!(0.52, 0.62, L"d", dc)                  # centroid to a facility
text!(ax, -0.55, 0.62; text = L"a", fontsize = 26, color = ink)
fig
using Random
# Uniform on the disk needs sqrt on the radius; sampling the radius
# uniformly would crowd the center and bias the picture toward it.
Random.seed!(754)
np = 500
ρ, φ = sqrt.(rand(np)), 2π .* rand(np)
px, py = ρ .* cos.(φ), ρ .* sin.(φ)

inc = colorant"#2b4a8a"; outc = colorant"#2fae4f"   # inside / outside
fig = Figure(size = (320, 448))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
scatter!(ax, px, py; color = dc, markersize = 3)
lines!(ax, cos.(θ), sin.(θ); color = ink, linewidth = 1.6)
scatter!(ax, [0], [0]; color = ink, markersize = 7)
lines!(ax, [0, 0], [0, -1]; color = inc, linewidth = 4,
       linestyle = (:dot, :dense))
lines!(ax, [0, 0], [-1, -2.1]; color = outc, linewidth = 4,
       linestyle = (:dot, :dense))
text!(ax, 0.18, -0.5; text = L"d < r", fontsize = 22, color = inc,
      align = (:left, :center))
text!(ax, 0.18, -1.55; text = L"d > r", fontsize = 22, color = outc,
      align = (:left, :center))
text!(ax, -0.55, 0.62; text = L"a", fontsize = 26, color = ink,
      align = (:center, :center))
fig
# Code block 10: draw points uniformly over the unit disk by rejection
using Statistics
Random.seed!(82734)
XY = rand(50_000, 2) .* 2 .- 1                    # the square
XY = XY[vec(sum(abs2, XY; dims = 2)) .< 1, :]     # keep the disk
size(XY, 1)                                       # how many survived
# Code block 11: one observation per facility position
dd = collect(range(0, 1; length = 56))
da = [mean(dists([x 0], XY, 2)) for x in dd]
prt(DataFrame(d = round.(dd[1:4], digits = 4),
              d_agg = round.(da[1:4], digits = 4)))
da[1] = 2/3   # Code block 12: the one point that needs no fitting
# Code block 13: fit the interior, measure the exterior excess
rmse(p) = sqrt(sum(abs2, da .- (2/3 .+ p[1] .* dd .+
                                p[2] .* dd .^ 2)) / length(dd))
p = Optim.minimizer(optimize(rmse, [0.5, 0.5], NelderMead()))
excess = mean(dists([1 0], XY, 2)) - 1
prt(DataFrame(linear = round(p[1], digits = 4),
              quadratic = round(p[2], digits = 4),
              exterior_excess = round(excess, digits = 4),
              rmse = round(rmse(p), digits = 5)))
# Code block 14: price the rounding rather than assume it
prt(DataFrame(coefficients = ["least squares", "as fractions"],
              linear = [round(p[1], digits = 4), 1/48],
              quadratic = [round(p[2], digits = 4), 9/20],
              excess = [round(excess, digits = 4), 3/23],
              rmse = round.([rmse(p), rmse([1/48, 9/20])], digits = 5)))

# Sec. 6. Aggregate demand in a location model
## Example 4: Locating with and without the area adjustment
# Determine how the solution to an uncapacitated facility location
# problem over North Carolina's three-digit ZIP codes changes when the
# area adjustment is applied.
# Code block 15: North Carolina at three-digit ZIP resolution
z = filter(r -> 270 <= r.ZCTA3 <= 289 && r.POP > 0, uszcta3())
P, f = hcat(z.LON, z.LAT), float(z.POP)
F = repeat(f', length(f), 1)
rate, g = 1 / 10_000, 1.2     # $/person-mi, circuity factor
# One cost per site ($/yr), so ufl takes a scalar, not a vector
k = 7000;
# Code block 16: UFL with no area adjustment
D = dists(P, P, :mi) .* g
y, TC0, _ = ufl(k, rate .* D .* F; verbose = false)  # y = sites
y, TC0                    # the assignment itself returns all three
# Code block 17: the same problem, with the area adjustment
Da = dgca(P, P, z.ALAND) .* g
ya, TCa, _ = ufl(k, rate .* Da .* F; verbose = false)
ya, TCa
# Code block 18: what changed
prt(DataFrame(model = ["unadjusted", "area-adjusted"],
              sites = [length(y), length(ya)],
              total = round.(Int, [TC0, TCa]),
              opened = [join(sort(z.ZCTA3[y]), " "),
                        join(sort(z.ZCTA3[ya]), " ")]))

## Example 5: EMCA's machines, on aggregate demand
# Determine how many machines EMCA should lease and where, when its
# demand points are recognized as aggregates rather than as customers.
# Code block 19: EMCA's demand set, as lecture 2.4 built it
zip = [
    270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283,
    284, 285, 286, 287, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299]
ncust = [
      7,   5,   6,   3,   5,   8,   5,   1,   3,   2,   8,   4,   9,   6,
      1,   2,   3,   3,   4,   3,   3,   2,  11,   5,   7,   2,   4,   2]
ud, uwt = 12e6, 15 / 2000              # units/yr in total, ton/unit
fz = ud .* ncust ./ sum(ncust) .* uwt  # ton/yr by ZIP
zc = uszcta3()
iz = [findfirst(==(zi), zc.ZCTA3) for zi in zip]
Pz = hcat(zc.LON[iz], zc.LAT[iz])      # ZIP centroids
# Code block 20: the distance the unadjusted model was giving away
az = zc.ALAND[iz]               # mi^2 of land in each ZIP
Dz = 1.2 .* dists(Pz, Pz, :mi)  # circuity 1.2, as in lecture 2.4
Dza = 1.2 .* dgca(Pz, Pz, az)
own = [Dza[i, i] for i in eachindex(zip)]
prt(DataFrame(min_mi = round(minimum(own), digits = 1),
              mean_mi = round(sum(own) / length(own), digits = 1),
              max_mi = round(maximum(own), digits = 1)))
# Code block 21: the same lease decision, both ways
rton, kz = 0.25, 100_000.0  # $/ton-mi and $/yr, both given
sol(DD) = ufl(kz, (fz .* rton)' .* DD; verbose = false)
yz, TCz, _ = sol(Dz)
yza, TCza, _ = sol(Dza)
prt(DataFrame(model = ["unadjusted", "area-adjusted"],
              machines = [length(yz), length(yza)],
              total = round.(Int, [TCz, TCza]),
              opened = [join(sort(zip[yz]), " "),
                        join(sort(zip[yza]), " ")]))

# Sec. 8. Joining other data to a demand set
# Example 6: Per-capita income across the Raleigh CSA
## Example 6(a): Drilling from the CSA to its tracts
# Determine the census tracts belonging to the Raleigh CSA, by
# descending the statistical-area hierarchy of Sec. 2.
# Code block 22: find the Raleigh CSA
csa = filter(r -> startswith(r.NAME, "Ral"), uscsa())
prt(csa[!, [:CSA, :NAME]])
# Code block 23: CSA to CBSA to county to census tract
cbsa = filter(r -> !ismissing(r.CSA) && r.CSA in csa.CSA, uscbsa())
co = filter(r -> !ismissing(r.CBSA) && r.CBSA in cbsa.CBSA, uscounty())
tr = filter(r -> r.STFIP in co.STFIP && r.COFIP in co.COFIP,
            uscentract());
# Code block 24: how many units at each level
prt(DataFrame(level = ["CSA", "CBSA", "county", "tract"],
              units = nrow.([csa, cbsa, co, tr]),
              population = sum.([csa.POP, cbsa.POP, co.POP, tr.POP])))

## Example 6(b): Reading and cleaning the income file
# Determine a table of per-capita income by census tract from the
# published American Community Survey file, in a state fit to join.
# Code block 25: the ACS per-capita income file
inc = DataFrame(CSV.File("data/ACSDT5Y2022.B19301-Data.csv", skipto = 3))
inc.GEO_ID = replace.(inc.GEO_ID, r"1400000US" => "")
rename!(inc, names(inc)[3] => :INCOME)
prt(first(inc[!, [:GEO_ID, :INCOME]], 3))
# Code block 26: the values that are not numbers
bad = filter(r -> tryparse(Int, r.INCOME) === nothing, inc)
prt(DataFrame(value = unique(bad.INCOME),
              rows = [count(==(v), bad.INCOME)
                      for v in unique(bad.INCOME)]))
# Code block 27: keep the rows that parse, then parse them
inc = filter(r -> tryparse(Int, r.INCOME) !== nothing, inc)
inc.INCOME = parse.(Int, inc.INCOME)

## Example 6(c): Joining, and what does not match
# Determine the joined demand set, and account for every tract the join
# fails to reach.
# Code block 28: build the join key, then join on it
tr.GEO_ID = string.(tr.STFIP, pad = 2) .* string.(tr.COFIP, pad = 3) .*
            string.(tr.TRFIP, pad = 6)
trinc = leftjoin(tr, inc[!, [:GEO_ID, :INCOME]], on = :GEO_ID);
# Code block 29: the tracts the join did not reach
nomatch = filter(r -> ismissing(r.INCOME), trinc)
prt(nomatch[!, [:GEO_ID, :POP, :ALAND]])
# Code block 30: the finished demand set
trinc = dropmissing(trinc, :INCOME)
prt(DataFrame(tracts = nrow(trinc), population = sum(trinc.POP),
              income_lo = minimum(trinc.INCOME),
              income_hi = maximum(trinc.INCOME)))

## Example 6(d): What the new weight buys
# Determine how the single-facility minisum optimum for the CSA moves
# when demand is weighted by total income rather than by population.
# Code block 31: population weight against total-income weight
ptr = eachrow(hcat(trinc.LON, trinc.LAT))
opt(w) = optimize(xy -> sum(w .* dgc.([xy], ptr)),
                  [wcentroid(trinc.LON, trinc.LAT, w).LON,
                   wcentroid(trinc.LON, trinc.LAT, w).LAT]).minimizer
xpop = opt(float.(trinc.POP))
xinc = opt(float.(trinc.POP) .* trinc.INCOME)
# Code block 32: where each weighting lands
prt(DataFrame(weight = ["population", "total income"],
              nearest = [lonlat2loc(xpop, usplace()).desc,
                         lonlat2loc(xinc, usplace()).desc]))
