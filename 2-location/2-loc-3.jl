# 2-loc-3 — generated from 2-loc-3.qmd by tools/qmd_to_jl.py
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
using Logjam, DataFrames, SparseArrays, Optim

# Sec. 1. Allocation
## Model: Allocation to fixed distribution centers
# Model: allocation to fixed distribution centers
function allocate(D, w)
    n, m = size(D)
    α = [argmin(c) for c in eachcol(D)]
    W = sparse(α, 1:m, w, n, m)
    return α, sum(W .* D)
end

## Example 1. Two distribution centers, four customers
# Determine the allocation and the total weekly distance for two DCs
# serving four customers with weights $w = (2, 4, 6, 8)$.
# Code block 1: two DCs and four customers, by hand
w = [2, 4, 6, 8]                  # truckloads per week
D = [ 10  20  30  40              # DC 1 to each customer
      45  35  25  15 ]            # DC 2 to each customer
α = [argmin(c) for c in eachcol(D)]
TD = sum(w[j] * D[α[j], j] for j in 1:length(w))  # Code block 2: the cost

## Sec. 1. Allocation
α, TD = allocate(D, w)  # Code block 3: the same by the model

## Example 2. Two distribution centers for North Carolina
# Determine the population-weighted total distance when the North
# Carolina cities above one hundred thousand people are each served by
# the nearer of two distribution centers at Charlotte and Raleigh, and
# determine the reduction from adding a third at Greensboro.
# Code block 4: the Carolinas' larger cities
df = filter(r -> r.STFIP == st2fips(:NC) &&
                 r.POP > 100_000, usplace())
select!(df, :NAME, :LON, :LAT, :POP)
P = hcat(df.LON, df.LAT)          # one row per city
w = df.POP
prt(df)
# Code block 5: two candidate DC sites
ll(nm) = collect(filter(r -> r.NAME == nm,
                        df)[1, [:LON, :LAT]])
X = vcat(ll("Charlotte")', ll("Raleigh")')
D = dists(X, P, :mi)
α = [argmin(c) for c in eachcol(D)]
n, m = size(D)
TC2 = sum(sparse(α, 1:m, w, n, m) .* D)

# Example 2. Two distribution centers for North Carolina
## Part b. Adding Greensboro
# Code block 6: adding a third DC
X = vcat(X, ll("Greensboro")')
D = dists(X, P, :mi)
α = [argmin(c) for c in eachcol(D)]
n, m = size(D)
TC3 = sum(sparse(α, 1:m, w, n, m) .* D)
# Code block 7: comparing two and three DCs
prt(DataFrame(
    DCs = ["Charlotte, Raleigh",
           "Charlotte, Raleigh, Greensboro"],
    PersonMiles = [TC2, TC3],
    Reduction = ["", string(round(
        100 * (TC2 - TC3) / TC2, digits = 1), "%")]))

# Sec. 3. Co-locating operations
## Model: The majority theorem for several new facilities
function majority(W, V)
    W = float(copy(W))
    V = float(V == V' ? copy(V) : V + V')  # count each once
    group = [[i] for i in axes(W, 1)]
    at = zeros(Int, size(W, 1))
    live, done = collect(axes(W, 1)), false
    while !done
        done = true
        for i in live
            Σ = sum(W[i, :]) + sum(V[i, :])
            k, j = argmax(V[i, :]), argmax(W[i, :])
            if V[i, k] > 0 && V[i, k] >= Σ / 2     # co-locate
                W[i, :] .+= W[k, :]
                V[i, :] .+= V[k, :]
                V[:, i] .+= V[:, k]
                V[i, i] = 0
                W[k, :] .= 0; V[k, :] .= 0; V[:, k] .= 0
                append!(group[i], group[k]); empty!(group[k])
                gone = k
            elseif W[i, j] > 0 && W[i, j] >= Σ / 2  # place
                for r in live      # a placed NF becomes an EF
                    r == i && continue
                    W[r, j] += V[r, i]
                    V[r, i] = V[i, r] = 0
                end
                at[group[i]] .= j
                gone = i
            else
                continue
            end
            filter!(!=(gone), live); done = false; break
        end
    end
    return at, filter(!isempty, group)
end

## Example 3. What the theorem can and cannot settle
# Determine the locations, if any, that the majority theorem settles for
# two new facilities serving three existing ones, under three different
# sets of interaction weights.
# Code block 8: the majority check, row by row
W = [2 1 0
     4 0 5]
rowcheck(V) = DataFrame(
    Σ = [sum(W[i, :]) + sum(V[i, :]) for i in 1:2],
    half = [(sum(W[i, :]) + sum(V[i, :])) / 2 for i in 1:2],
    largest = [maximum([W[i, :]; V[i, :]]) for i in 1:2])
prt(rowcheck([0 2; 2 0]))
prt(rowcheck([0 0.5; 0.5 0]))  # Code block 9: with v = 0.5
prt(rowcheck([0 4; 4 0]))  # Code block 10: with v = 4
# Code block 11: the two facilities folded together
Wr = vec(sum(W, dims = 1))         # NF1 and NF2 folded together
(reduced = Wr, Σ = sum(Wr), half = sum(Wr) / 2)
# Code block 12: all three cases by the procedure
vs = [2, 0.5, 4]
prt(DataFrame(
    v = vs,
    placed_at = [string(majority(W, [0 v; v 0])[1]) for v in vs],
    groups = [string(majority(W, [0 v; v 0])[2]) for v in vs]))

## Example 4. Locating a production chain
# Determine which of heat treat, pressing and finishing must share a
# site, and where each of the three operations belongs, given drop forge
# fixed at Nagoya and painting fixed at Detroit.
# Code block 13: the production chain's weights
W7 = [4 0; 0 0; 0 4]
V7 = [0 3 0; 3 0 5; 0 5 0]
prt(DataFrame(
    NF = ["heat treat", "pressing", "finishing"],
    Σ = [sum(W7[i, :]) + sum(V7[i, :]) for i in 1:3],
    half = [(sum(W7[i, :]) + sum(V7[i, :])) / 2 for i in 1:3],
    largest = [maximum([W7[i, :]; V7[i, :]]) for i in 1:3]))
# Code block 14: after folding finishing into pressing
W2 = [4 0; 0 4]                    # finishing folded into pressing
V2 = [0 3; 3 0]
prt(DataFrame(
    NF = ["heat treat", "pressing + finishing"],
    Σ = [sum(W2[i, :]) + sum(V2[i, :]) for i in 1:2],
    half = [(sum(W2[i, :]) + sum(V2[i, :])) / 2 for i in 1:2],
    largest = [maximum([W2[i, :]; V2[i, :]]) for i in 1:2]))
# Code block 15: the procedure's own answer
at7, groups7 = majority(W7, V7)
prt(DataFrame(operation = ["heat treat", "pressing", "finishing"],
              site = ["Nagoya", "Detroit"][at7]))

# Sec. 5. Two formulations
## Example 5. Two facilities along I-40
# Determine the two mile markers along I-40 that minimize the total
# weighted distance to seven cities on the corridor, and show the shape
# of the objective the search has to work with.
# Code block 16: seven towns along I-40
P = [50 150 190 220 270 295 420]'   # I-40 mile markers
m = size(P, 1)
w = collect(1:m)                    # relative demand at each
X = [100 300]'                      # one pair of NF sites
n = size(X, 1)
prt(dists(X, P, 1); rows = ["NF $i" for i in 1:n], cols = vec(P))
TCint(X) = allocate(dists(reshape(X, :, 1), P, 1), w)[2]  # Code block 17
# Code block 18: the objective over the corridor
using CairoMakie
xrng = 0:500
Z = [TCint([x1, x2]) for x1 in xrng, x2 in xrng]
contour(xrng, xrng, Z; levels = 100,
        axis = (xlabel = "NF 1 mile marker",
                ylabel = "NF 2 mile marker"))
# Code block 19: two starts, two local optima
Xᵒ¹ = optimize(TCint, [0.0, 200.0]).minimizer
Xᵒ² = optimize(TCint, [200.0, 500.0]).minimizer
prt(DataFrame(start = ["[0, 200]", "[200, 500]"],
              NF1 = round.([Xᵒ¹[1], Xᵒ²[1]]; digits = 1),
              NF2 = round.([Xᵒ¹[2], Xᵒ²[2]]; digits = 1),
              TC = round.([TCint(Xᵒ¹), TCint(Xᵒ²)]; digits = 1)))

## Sec. 6. ALA procedure
# Code block 20: locate in one dimension, the median of Lecture 2.1
median1(p, wt) = p[findfirst(≥(sum(wt) / 2), cumsum(wt))]

function alatrace(X₀)
    X, tr = copy(X₀), DataFrame()
    while true
        α, TC = allocate(dists(reshape(X, :, 1), P, 1), w)
        Xⁿ = [median1(vec(P)[α .== i], w[α .== i])
              for i in eachindex(X)]
        push!(tr, (at = join(X, ", "), TC = TC,
                   move = join(Xⁿ, ", ")))
        Xⁿ == X && return tr
        X = Xⁿ
    end
end

prt(alatrace([0, 200]); title = "from markers 0 and 200")
prt(alatrace([200, 500]); title = "from markers 200 and 500")
# Code block 21: the same two starts through ala
Xᵃ, TCᵃ, = ala([0.0; 200.0;;], float(w), float(P); dist = 1)
Xᵇ, TCᵇ, = ala([200.0; 500.0;;], float(w), float(P); dist = 1)
prt(DataFrame(start = ["0, 200", "200, 500"],
              NFs = [join(round.(Int, vec(Xᵃ)), ", "),
                     join(round.(Int, vec(Xᵇ)), ", ")],
              TC = round.([TCᵃ, TCᵇ])))

# Sec. 7. Scale
## Example 7. Service centers for North and South Carolina
# Determine the two locations that minimize the total
# population-weighted distance to every city over 10,000 people in North
# and South Carolina, and the territory each one serves.
# Code block 22: the Carolinas' cities and their weights
using GeoMakie, Random
df = filter(r -> r.STFIP in st2fips.([:NC, :SC]) && r.POP > 10_000,
            usplace())
select!(df, :NAME, :ST, :LAT, :LON, :POP)
P = hcat(df.LON, df.LAT)
w = float(df.POP)
nef = size(P, 1)
# Code block 23: two service centers by multistart
Random.seed!(8345)
Xᵒ, TCᵒ, W = ala(randX(P, 2), w, P; nruns = 5)
prt(lonlat2loc(Xᵒ, df))
# Code block 24: mapping the centers and their allocations
Lx, Ly = alloclines(W, Xᵒ, P)
fig, ax = makemap(df.LON, df.LAT; xexpand = 0.1)
for i in eachindex(Lx)
    lines!(ax, Lx[i], Ly[i]; linewidth = 0.5)
end
scatter!(ax, Xᵒ[:, 1], Xᵒ[:, 2]; marker = :dtriangle,
         markersize = 12, color = :black)
fig
# Code block 25: the allocation for a given pair
function alloc36(X)
    D = dists(X, P, :mi)
    α = [argmin(c) for c in eachcol(D)]
    α[1:3] .= 1
    α[4:6] .= 2
    Wc = sparse(α, 1:nef, w, size(X, 1), nef)
    return Wc, sum(Wc .* D)
end
Random.seed!(8345)
Xᶜ, TCᶜ, = ala(randX(P, 2), w, P; alloc = alloc36, nruns = 5)
prt(lonlat2loc(Xᶜ, df))

## Example 8. Reproducing the warehouse table
# Determine the best locations for one, two, three and nine retail
# warehouses serving the continental United States in proportion to
# population, and compare them with @tbl-retail.
# Code block 26: every US population centroid
z = filter(r -> r.ISCUS && r.POP > 0, uszcta3())
select!(z, :ZCTA3, :LAT, :LON, :POP)
Pz = hcat(z.LON, z.LAT)
wz = float(z.POP)
nz = size(Pz, 1)
# Code block 27: cities for naming the answer
cities = filter(r -> r.ISCUS && r.POP > 100_000, usplace())
Random.seed!(4161)
TC1(X) = sum(wz .* dists(reshape(X, 1, 2), Pz, :mi)')
X1 = optimize(TC1, vec(randX(Pz, 1))).minimizer
prt(lonlat2loc(reshape(X1, 1, 2), cities))
# Code block 28: one to ten warehouses
named(X) = select(lonlat2loc(X, cities), :NAME, :ST, :dist)

Xw = Dict{Int,Matrix{Float64}}()
for nw in (2, 3, 9)
    Random.seed!(4161)
    Xw[nw], = ala(randX(Pz, nw), wz, Pz; nruns = 3)
    prt(named(Xw[nw]); title = "$nw warehouses")
end
# Code block 29: the nine-warehouse allocation
X9 = Xw[9]
W9 = sparse([argmin(c) for c in eachcol(dists(X9, Pz, :mi))],
            1:nz, wz, size(X9, 1), nz)
Lx9, Ly9 = alloclines(W9, X9, Pz)
fig9, ax9 = makemap(region = :CUS)
for i in eachindex(Lx9)
    lines!(ax9, Lx9[i], Ly9[i]; linewidth = 0.2)
end
scatter!(ax9, X9[:, 1], X9[:, 2]; marker = :dtriangle,
         markersize = 10, color = :black)
fig9
