# 2-loc-2 — generated from 2-loc-2.qmd by tools/qmd_to_jl.py
# (do not edit by hand; rerun the generator after editing the .qmd)
# Cells (## title) follow the Julia VS Code extension convention.

## Get class-ready — install packages
# Run this cell once. It installs every package the course uses, at the
# versions pinned in the shared Manifest.toml, by activating the course
# project (the nearest folder above with a Project.toml) and instantiating
# it. Idempotent: packages already present at the right version are skipped.
import Pkg
let dir = @__DIR__
    while !isfile(joinpath(dir, "Project.toml")) && dir != dirname(dir)
        dir = dirname(dir)
    end
    Pkg.activate(dir)
    Pkg.instantiate()
end

## Setup
using Logjam, Optim, DataFrames

# Sec. 2. Procurement and distribution
# Example 1: Plant location with procurement and distribution costs
## Example 1(a): From the bill of material to the monetary weights
# Determine each existing facility's monetary weight, outbound from the
# demands and inbound through the bill of material.
fout = [10, 20, 30]      # ton/yr to the three customers
rout = 1.00              # $/ton-mi outbound
wout = fout .* rout      # customer monetary weights
BOM  = [2.0, 0.5]        # ton raw per ton out: Ashvl, Durham
fin  = BOM .* sum(fout)  # inbound physical flows (ton/yr)
win  = fin ./ 3          # supplier wts; r_in = $1/3 ($0.33)
@show wout fin win;

## Example 1(b): Locating the plant
# Order the facilities along I-40 and apply the median procedure of {{<
# xref 2.1 mdl-minisum1d >}}.
city = ["Asheville", "Statesville", "Winston-Salem",
        "Durham", "Wilmington"]          # west-to-east order
w = [win[1], wout[1], wout[2], win[2], wout[3]]  # $/mi, W to E
W = sum(w)
@show W W/2 cumsum(w)
city[findfirst(>=(W / 2), cumsum(w))]

## Example 1(c): Weight-gaining or weight-losing
# Classify the plant by comparing its inbound and outbound weights,
# physical and monetary.
@show sum(fin) sum(fout) sum(win) sum(wout);

# Sec. 3. The single-facility minisum
## Model: Single-facility minisum
# Model: single-facility minisum
function minisum(w, P, dist)
    x0 = vec(sum(P; dims = 1)) ./ size(P, 1)   # centroid start
    TC(X) = sum(w[i] * dist(X, P[i, :]) for i in axes(P, 1))
    return optimize(TC, x0).minimizer
end

## Example 2
# Determine the minisum location for three facilities of equal weight at
# $(1, 1)$, $(6, 1)$, and $(6, 5)$, under straight-line distance.
# d2 from 2-Loc-2.ipynb cell 3 (straight-line = Logjam.d2)
d2(x1, x2) = length(x1) == length(x2) ?
    sqrt(sum((x1 .- x2).^2)) :
    error("Inputs not same length.")
P = [1.0 1.0; 6.0 1.0; 6.0 5.0]     # three EFs, one per row
w = [1.0, 1.0, 1.0]                 # equal weights
Xᵒ = minisum(w, P, d2)              # the minisum location

## Sec. 3. The single-facility minisum
# From 2-Loc-2.ipynb cells 20–26 (tuples → matrix P)
using CairoMakie
xrng = 0:0.1:7
yrng = 0:0.1:6
Z = [sum(d2([x, y], P[i, :]) for i in axes(P, 1))
     for x in xrng, y in yrng]
fig = Figure(size = (760, 320))
a1, _ = contour(fig[1, 1], xrng, yrng, Z; levels = 18)
scatter!(a1, P[:, 1], P[:, 2]; color = :firebrick)
surface(fig[1, 2], xrng, yrng, Z;
        axis = (type = Axis3, azimuth = pi / 4))
fig
# From 2-Loc-2.ipynb cell 12 (fargplot NM path; tuples → matrix P)
TC(X) = sum(d2(X, P[i, :]) for i in axes(P, 1))
fargplot(f, x, kw) = (scatter!(x...; kw...); f(x))
scatter(P[:, 1], P[:, 2]; color = :firebrick, markersize = 11)
kw = (; color = (:steelblue, 0.6), markersize = 5)
Xᵒ2 = optimize(x -> fargplot(TC, x, kw), [0.0, 0.0]).minimizer
scatter!([Xᵒ2[1]], [Xᵒ2[2]]; color = :red, marker = :star5,
         markersize = 14)
current_figure()

## Sec. 4. Logjam: the course's logistics toolkit
using Pkg
Pkg.add(url="https://github.com/mgkay/Logjam")

## Sec. 5. Computing distances with Logjam
P1 = [0, 0]                 # two points in the plane
P2 = [4, 3]
d1(P1, P2), d2(P1, P2)      # rectilinear, Euclidean
X1 = [0 0]                  # point sets, one row per point
X2 = [4 3]
[dists(X1, X2, p)[1] for p in (1, 2, Inf)]   # l₁, l₂, l∞
Raleigh = [-78.659 35.8219]        # one point, as a row
XY = [-82.336  29.6742             # Gainesville, FL
       44.3667 33.2333             # Baghdad
      -43.2   -22.95]              # Rio de Janeiro
prt(DataFrame(
    City = ["Gainesville, FL", "Baghdad", "Rio de Janeiro"],
    Radians = vec(dists(Raleigh, XY, :rad)),
    Miles = vec(dists(Raleigh, XY, :mi))))
# NC cities over 100k (2-Loc-3 cells 17-18, Logjam gazetteer)
df = filter(r -> r.STFIP == st2fips(:NC) &&
                 r.POP > 100_000, usplace())
select!(df, :NAME, :LON, :LAT, :POP)
prt(df)
ll(nm) = collect(filter(r -> r.NAME == nm,
                        df)[1, [:LON, :LAT]])
xyR = ll("Raleigh")           # (lon, lat) in degrees
dgc(xyR, ll("Charlotte"))     # great-circle miles
pt = collect.(zip(df.LON, df.LAT))   # one [lon,lat] per city
d  = dgc.([xyR], pt)                 # Raleigh to each city
df[argmax(d), :NAME]                 # farthest city
df[sortperm(d)[2:4], :NAME]          # three nearest (skip Raleigh)

# Sec. 5. Computing distances with Logjam
## Example 3
# Locate a single facility to minimize the total population-weighted
# great-circle distance to every place in North Carolina.
# every NC place, population-weighted (2-Loc-3 cells 40-41)
df = filter(r -> r.STFIP == st2fips(:NC), usplace())
select!(df, :NAME, :LON, :LAT, :POP)
pt = collect.(zip(df.LON, df.LAT))       # [lon,lat] per place
TC(xy) = sum(df.POP .* dgc.([xy], pt))   # pop-weighted miles
w = wcentroid(df.LON, df.LAT, df.POP)    # weighted-centroid start
xyᵒ = optimize(TC, [w.LON, w.LAT]).minimizer
d = dgc.([xyᵒ], pt)                      # optimum to each place
df[argmin(d), :NAME], round(minimum(d))  # nearest place, miles
