# 2-loc-4 — generated from 2-loc-4.qmd by tools/qmd_to_jl.py
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
using Logjam, DataFrames, Optim

# TODO: port to Logjam -- it has _commasep but does not export it
usd(x) = replace(string(round(Int, x)),
                 r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")

# Sec. 5. ADD and DROP heuristics
## Model: Uncapacitated facility location
logjam_rung(:ufladd, "UFL, ADD construction"; keywords = false)
logjam_rung(:ufldrop, "UFL, DROP construction"; keywords = false)

# Example 1: Warehouses on the I-40 corridor
## Example 1(a): Adding one site at a time, by hand
# Determine the sites ADD opens on the corridor, by hand, and the total
# cost after each pass.
# Code block 1: five cities on the corridor, and the cost of serving each
P = reshape([50, 150, 220, 295, 420], :, 1)   # mile markers along I-40
k = [150, 200, 150, 150, 200]                 # fixed cost at each site
r, f = 1, 1                    # transport rate, annual flow
w = r * f                      # monetary weight
C = w * dists(P, P, 1)         # cost to serve each city from each site
# Code block 2: the first site to add
N = 1:size(C, 1)
prt(DataFrame(site = N, k = k, cYj = vec(sum(C, dims = 2)),
              TC = k .+ vec(sum(C, dims = 2))))
# Code block 3: the second site to add, given site 3
y = [3]
add = setdiff(N, y)
TC2 = [sum(k[vcat(y, i)]) + sum(minimum(C[vcat(y, i), :], dims = 1))
       for i in add]
prt(DataFrame(site = add, TC = TC2))
# Code block 4: no third site reduces the total, so stop
y = vcat(y, 1)
add = setdiff(N, y)
TC3 = [sum(k[vcat(y, i)]) + sum(minimum(C[vcat(y, i), :], dims = 1))
       for i in add]
prt(DataFrame(site = add, TC = TC3))

## Example 1(b): The same steps as a procedure
# Determine the same answer by running ufladd, and confirm it against
# the hand calculation.
# Code block 5: ADD run on the corridor
y, TC, _ = ufladd(k, C)   # _ is the allocation, unused here
y, TC

## Example 1(c): Dropping one site at a time
# Determine the sites DROP leaves open on the same corridor, by hand,
# and whether it reaches ADD's answer.
# Code block 6: all five open, then the cheapest site to close
y = collect(N)
TCall = sum(k[y]) + sum(minimum(C[y, :], dims = 1))
drop = [sum(k[setdiff(y, i)]) +
        sum(minimum(C[setdiff(y, i), :], dims = 1)) for i in y]
prt(DataFrame(site = y, TC = drop))
# Code block 7: close site 2, then look again
y = setdiff(y, 2)
drop = [sum(k[setdiff(y, i)]) +
        sum(minimum(C[setdiff(y, i), :], dims = 1)) for i in y]
prt(DataFrame(site = y, TC = drop))
# Code block 8: DROP run on the corridor
y, TC, _ = ufldrop(k, C)   # _ is the allocation, unused here
y, TC

# Sec. 6. EXCHG and HYBRID heuristics
## Model: Uncapacitated facility location
logjam_rung(:uflxchg, "UFL, EXCHG improvement")
logjam_rung(:ufladd, "UFL, modified ADD construction")

## Sec. 6. EXCHG and HYBRID heuristics
# Code block 9: warm-starting ADD, and capping the count
ye, TCe, _ = ufladd(k, C; y = [5])   # extend a network open at site 5
yp, TCp, _ = ufladd(k, C; p = 3)     # or stop once three sites are open
(ye, TCe), (yp, TCp)

## Model: Uncapacitated facility location
logjam_rung(:ufldrop, "UFL, modified DROP construction")
logjam_rung(:ufl, "UFL, hybrid algorithm")

# Example 2: Exchanging and combining all three
## Example 2(a): Exchanging one site at a time, by hand
# Determine whether swapping one open site for one closed site improves
# on either construction's answer.
# Code block 10: every swap of one open site for one closed site
fTC(y) = sum(k[y]) + sum(minimum(C[y, :], dims = 1))
y = [3, 1]
closed = setdiff(N, y)
sw = DataFrame(close = repeat(y, inner = length(closed)),
               open = repeat(closed, outer = length(y)))
sw.TC = [fTC(vcat(setdiff(y, c), o)) for (c, o) in zip(sw.close, sw.open)]
prt(sw)
# Code block 11: EXCHG run on the corridor, starting from ADD's answer
yadd, TCadd, _ = ufladd(k, C)
yx, TCx, _ = uflxchg(k, C, yadd)   # third return is the allocation
yx, TCx

## Example 2(b): The three procedures combined
# Determine what the three procedures reach run together, and which of
# them finds it.
# Code block 12: the hybrid on the corridor
yh, TCh, _ = ufl(k, C)   # _ is the allocation, unused here
yh, TCh

# Sec. 7. p-median facility location
## Model: p-median location
logjam_rung(:pmedian, "p-median location")

## Sec. 7. p-median facility location
# Code block 20: the p-median of the corridor at p = 2
p = 2
yp, TCp, _ = pmedian(p, C)   # _ is the allocation, unused here
yp, TCp

# Example 3: How many machines to lease and where
## Example 3(a): What the UFL opens, capacity ignored
# Determine how many machines uncapacitated facility location opens and
# where, using every ZIP centroid as both a customer and a candidate
# site.
# Code block 13: EMCA's customers
zip = [
    270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283,
    284, 285, 286, 287, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299]
nc = [
      7,   5,   6,   3,   5,   8,   5,   1,   3,   2,   8,   4,   9,   6,
      1,   2,   3,   3,   4,   3,   3,   2,  11,   5,   7,   2,   4,   2]
ud, uwt = 12e6, 15 / 2000            # units/yr in total, ton/unit
units = ud .* nc ./ sum(nc)          # units/yr by ZIP
fz = units .* uwt                    # ton/yr by ZIP
z = uszcta3()
idx = [findfirst(==(zi), z.ZCTA3) for zi in zip]
Pz = hcat(z.LON[idx], z.LAT[idx])         # ZIP centroids
# Code block 14: the cost of serving each ZIP from each candidate site
rton = 0.25                          # $/ton-mi, given
g = 1.2                              # road circuity, lecture 2.2
D = g .* dists(Pz, Pz, :mi)
Cz = (fz .* rton)' .* D              # $/yr to serve j from i
kz = 100_000.0                       # $/yr per machine
# units/yr a machine can make; ';' keeps the echo off, and it only works
# as the cell's LAST character, so the comment cannot trail the statement
K = 2e6;
# Code block 15: how many machines, and where
yz, TCz, Wz = ufl(kz, Cz)
prt(DataFrame(ZIP = zip[yz],
              city = lonlat2loc(Pz[yz, :],
                                filter(r -> r.ISCUS, usplace())).NAME,
              tons = round.(vec(sum(Wz .* fz', dims = 2))[yz])))

## Example 3(b): Whether that answer is feasible
# Determine whether the machines the UFL opened are within their
# capacity, and the smallest number of machines throughput feasibility
# allows.
# Code block 16: what each of the six machines is asked to make
served = vec(sum(Wz .* units', dims = 2))[yz]
prt(DataFrame(ZIP = zip[yz], units = round.(Int, served),
              pct_of_K = round.(100 .* served ./ K, digits = 1)))
# Code block 17: the feasible minimum, and its p-median
te = 1 / K                           # yr/unit, effective process time
mmin = floor(Int, ud * te + 1)       # lecture 1.3, feasible minimum
y7, TC7, W7 = pmedian(mmin, Cz)
TCmin = TC7 + mmin * kz              # transport plus fixed cost
s7 = vec(sum(W7 .* units', dims = 2))[y7]
prt(DataFrame(machines = mmin, total = usd(TCmin),
              max_pct = round(100 * maximum(s7) / K, digits = 1)))

## Example 3(c): How many machines capacity requires
# Determine the number of machines at which no machine is over its
# capacity, and what that feasibility costs against the
# throughput-feasible minimum.
# Code block 18: raise the machine count until none is over capacity
res = DataFrame(machines = Int[], transport = Int[],
                total = Int[], max_pct = Float64[])
nm, over = mmin, true       # nm, not p: p is the p-median's
while over
    y, TCp, W = pmedian(nm, Cz)
    s = vec(sum(W .* units', dims = 2))[y]
    pct = 100 * maximum(s) / K
    push!(res, (nm, round(Int, TCp), round(Int, TCp + nm * kz),
                round(pct, digits = 1)))
    over = pct > 100
    nm += 1
end
prt(res)   # Code block 19: the experiment's whole history

## Example 4: Discrete retail warehouses
# Determine the best nine locations for retail warehouses serving the
# continental United States in proportion to population, restricting
# them to population centroids, and compare the result with the
# continuous answer of the previous lecture.
# Code block 21: every US population centroid, customer and site
zr = filter!(r -> r.ISCUS == true && r.POP > 0, uszcta3())
select!(zr, :ZCTA3, :LAT, :LON, :POP)

Pr = hcat(zr.LON, zr.LAT)
wr = zr.POP

Dr = dists(Pr, Pr, :mi)
Cr = wr[:]' .* Dr
# Code block 22: nine warehouses, restricted to the centroids
# ';' suppresses the echo: the third return is the 882-column allocation
# matrix, and printing it runs 372 characters off the page.
yr, TCr = pmedian(9, Cr);
# Code block 23: naming each site by the large city nearest it
cities = filter!(r -> r.ISCUS == true && r.POP > 100_000, usplace())
prt(select(lonlat2loc(Pr[yr, :], cities), :NAME, :ST, :dist))
# Code block 24: three solves of one problem, and their totals
using Random, Printf
tc(X) = sum(wr .* vec(minimum(dists(X, Pr, :mi), dims = 1)))
bn(x) = @sprintf("%.2f", x / 1e9)   # billions, always two places

Random.seed!(4161)
Xa, = ala(randX(Pr, 9), float(wr), Pr; nruns = 3)  # random multi-start
Xs, = ala(float(Pr[yr, :]), float(wr), Pr)         # from the p-median

TCa, TCs = tc(Xa), tc(Xs)
prt(DataFrame(start = ["restricted to centroids", "random multi-start",
                       "started at the p-median"],
              people_miles = bn.([TCr, TCa, TCs])))

# Sec. 8. Estimating NF fixed cost
## Model: Least-squares line
# Model: least-squares line
ŷ(α, x) = α[1] .+ α[2] .* x
function lsq(x, y)
    loss(α) = sum((y .- ŷ(α, x)) .^ 2)
    return optimize(loss, [0.0, 1.0]).minimizer
end

## Example 5: SP3D's fixed cost
# SP3D, Inc., has been operating four hub facilities in Buffalo, NY,
# Pittsburgh, PA, Cleveland, OH and Detroit, MI that utilize additive
# manufacturing to create molds that are shipped to customers. The
# customers are traditional manufacturers who do not have additive
# manufacturing expertise in-house. Determine the fixed cost to use in a
# UFL for SP3D's hubs, from the annual output and total annual
# production cost of each hub in @tbl-sp3d.
# Code block 25: the four hubs
hub = ["Buffalo", "Pittsburgh", "Cleveland", "Detroit"]
f   = [19271, 69238, 63030, 62117]              # molds/yr
tpc = [408485, 1047639, 730795, 519401]         # $/yr, production only
# Code block 26: the fit for SP3D's four hubs
k, cp = lsq(f, tpc)
@show k cp
fit = ŷ([k, cp], f)
res = tpc .- fit
df = DataFrame(hub = hub, molds = f, actual = tpc,
               fitted = round.(Int, fit), residual = round.(Int, res))
push!(df, ("total", sum(f), sum(tpc),
           round(Int, sum(fit)), round(Int, sum(res))))
prt(df)

## Sec. 8. Estimating NF fixed cost
# Code block 27: the same hubs under L1 loss, and both fits drawn
using CairoMakie
function lad(x, y)                  # L1: absolute, not squared
    loss(α) = sum(abs.(y .- ŷ(α, x)))
    return optimize(loss, [0.0, 1.0]).minimizer
end
k₁, cp₁ = lad(f, tpc)
@show k₁ cp₁

fs = [0, maximum(f) * 1.05]
fig = Figure(size = (620, 380))
ax = Axis(fig[1, 1], xlabel = "production rate, molds/yr",
          ylabel = "production cost, \$/yr")
scatter!(ax, f, tpc; color = :grey25, markersize = 11)
lines!(ax, fs, ŷ([k, cp], fs); color = :steelblue4, label = "L2")
lines!(ax, fs, ŷ([k₁, cp₁], fs); color = :firebrick, label = "L1")
axislegend(ax; position = :lt)
fig
# Code block 28: the same table under L1, where the totals disagree
fit₁ = ŷ([k₁, cp₁], f)
res₁ = tpc .- fit₁
df₁ = DataFrame(hub = hub, molds = f, actual = tpc,
                fitted = round.(Int, fit₁), residual = round.(Int, res₁))
push!(df₁, ("total", sum(f), sum(tpc),
            round(Int, sum(fit₁)), round(Int, sum(res₁))))
prt(df₁)
