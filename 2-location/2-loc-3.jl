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
## Model: Distance-based allocation
# Model: distance-based allocation
function allocate(D, w)
    n, m = size(D)
    α = [argmin(c) for c in eachcol(D)]
    W = sparse(α, 1:m, w, n, m)
    return α, sum(W .* D)
end

## Sec. 1. Allocation
# Code block 1: the same allocation by the model
w = [2, 4, 6, 8]                  # truckloads per week
D = [ 10  20  30  40              # DC 1 to each customer
      45  35  25  15 ]            # DC 2 to each customer
α, TD = allocate(D, w)

# Example 2: Charlotte and Raleigh DCs
## Example 2(a): Two DCs, at Charlotte and Raleigh
# Determine the population-weighted total distance when each city is
# served by the nearer of the two DCs.
# Code block 2: the Carolinas' larger cities
df = filter(r -> r.STFIP == st2fips(:NC) &&
                 r.POP > 100_000, usplace())
select!(df, :NAME, :LON, :LAT, :POP)
P = hcat(df.LON, df.LAT)          # one row per city
w = df.POP
prt(df)
# Code block 3: two candidate DC sites
name2lonlat(nm) = collect(filter(r -> r.NAME == nm,
                                 df)[1, [:LON, :LAT]])
X = vcat(name2lonlat("Charlotte")', name2lonlat("Raleigh")')
D = dists(X, P, :mi)
α, TC2 = allocate(D, w)

## Example 2(b): Adding Greensboro
# Determine the reduction in that total from opening a third DC at
# Greensboro.
# Code block 4: adding a third DC
X = vcat(X, name2lonlat("Greensboro")')
D = dists(X, P, :mi)
α, TC3 = allocate(D, w)
# Code block 5: comparing two and three DCs
prt(DataFrame(
    DCs = ["Charlotte, Raleigh",
           "Charlotte, Raleigh, Greensboro"],
    PersonMiles = [TC2, TC3],
    Reduction = ["", string(round(
        100 * (TC2 - TC3) / TC2, digits = 1), "%")]))

# Sec. 3. Co-locating operations
## Model: Multifacility majority theorem
function majority(W, V)
    W = float(copy(W))
    V = float(V == V' ? copy(V) : V + V')  # count each once
    group = [[i] for i in axes(W, 1)]
    at = zeros(Int, size(W, 1))
    live, done = collect(axes(W, 1)), false
    while !done
        done = true
        for i in live
            γ = sum(W[i, :]) + sum(V[i, :])
            k, j = argmax(V[i, :]), argmax(W[i, :])
            if V[i, k] > 0 && V[i, k] >= γ / 2     # co-locate
                W[i, :] .+= W[k, :]
                V[i, :] .+= V[k, :]
                V[:, i] .+= V[:, k]
                V[i, i] = 0
                W[k, :] .= 0; V[k, :] .= 0; V[:, k] .= 0
                append!(group[i], group[k]); empty!(group[k])
                gone = k
            elseif W[i, j] > 0 && W[i, j] >= γ / 2  # place
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

## Example 4: Locating a production chain
# Determine which of heat treat, pressing and finishing must share a
# site, and where each of the three operations belongs, given drop forge
# fixed at Nagoya and painting fixed at Detroit.
# Code block 6: the procedure's own answer
W7 = [4 0; 0 0; 0 4]
V7 = [0 3 0; 3 0 5; 0 5 0]
at7, groups7 = majority(W7, V7)
prt(DataFrame(operation = ["heat treat", "pressing", "finishing"],
              site = ["Nagoya", "Detroit"][at7]))

# Sec. 5. Integrated vs alternating
## Example 5: Two facilities along I-40
# Determine the two mile markers along I-40 that minimize the total
# weighted distance to the seven cities of @tbl-corridor, and show the
# shape of the objective the search has to work with.
# Code block 7: seven towns along I-40
P = [50 150 190 220 270 295 420]'   # I-40 mile markers
m = size(P, 1)
w = collect(1:m)                    # relative demand at each
X = [100 300]'                      # one pair of NF sites
n = size(X, 1)
prt(dists(X, P, 1); rows = ["NF $i" for i in 1:n], cols = vec(P))
TCint(X) = allocate(dists(reshape(X, :, 1), P, 1), w)[2]  # Code block 8
# Code block 9: the objective over the corridor
using CairoMakie
xrng = 0:500
Z = [TCint([x1, x2]) for x1 in xrng, x2 in xrng]
contour(xrng, xrng, Z; levels = 100,
        axis = (xlabel = "NF 1 mile marker",
                ylabel = "NF 2 mile marker"))
# Code block 10: two starts, two local optima
Xᵒ¹ = optimize(TCint, [0.0, 200.0]).minimizer
Xᵒ² = optimize(TCint, [200.0, 500.0]).minimizer
prt(DataFrame(start = ["[0, 200]", "[200, 500]"],
              NF1 = round.([Xᵒ¹[1], Xᵒ²[1]]; digits = 1),
              NF2 = round.([Xᵒ¹[2], Xᵒ²[2]]; digits = 1),
              TC = round.([TCint(Xᵒ¹), TCint(Xᵒ²)]; digits = 1)))

## Sec. 6. ALA procedure
# Code block 11: locate in one dimension, the median of Lecture 2.1
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

# Sec. 6. ALA procedure
## Model: Location–allocation problem
logjam_rung(:ala, "Location–allocation, alternating algorithm")

## Sec. 6. ALA procedure
# Code block 12: the same two starts through ala
Xᵃ, TCᵃ, = ala([0.0; 200.0;;], float(w), float(P); dist = 1)
Xᵇ, TCᵇ, = ala([200.0; 500.0;;], float(w), float(P); dist = 1)
prt(DataFrame(start = ["0, 200", "200, 500"],
              NFs = [join(round.(Int, vec(Xᵃ)), ", "),
                     join(round.(Int, vec(Xᵇ)), ", ")],
              TC = round.([TCᵃ, TCᵇ])))
# Integrated against alternating, measured rather than recalled. Derived from
# 2-location/source/measure_int_vs_alt.jl, which is the fuller study; the two
# formulations here are written from the SAME `allocate` and the SAME `Optim`
# call, so what is compared is the formulation and not the implementation. The
# numbers this cell produces are the ones the paragraph below quotes.
using Random
dfb = filter(r -> r.STFIP in st2fips.([:NC, :SC]) && r.POP > 10_000, usplace())
Pb, wb = hcat(dfb.LON, dfb.LAT), float(dfb.POP)

TCintb(x) = allocate(dists(reshape(x, :, 2), Pb, :mi), wb)[2]

function TCaltb(X₀)
    X, best = copy(X₀), Inf
    while true
        α, TC = allocate(dists(X, Pb, :mi), wb)
        TC < best - 1e-9 || return best
        best = TC
        for i in axes(X, 1)
            j = findall(==(i), α)
            isempty(j) && continue
            g(x) = allocate(dists(reshape(x, 1, :), Pb[j, :], :mi), wb[j])[2]
            X[i, :] = optimize(g, X[i, :]).minimizer
        end
    end
end

nstarts = 20
bench = DataFrame(n = Int[], ratio = Float64[], gap = Float64[],
                  intwins = Int[], altwins = Int[])
for n in (2, 3, 5, 9)
    Random.seed!(8345)
    S = [randX(Pb, n) for _ in 1:nstarts]
    TCintb(vec(S[1])); TCaltb(S[1])                      # warm the compiler
    ti = @elapsed vi = [optimize(TCintb, vec(X)).minimum for X in S]
    ta = @elapsed va = [TCaltb(X) for X in S]
    bi, ba = minimum(vi), minimum(va)
    push!(bench, (n, ta / ti, 100abs(bi - ba) / min(bi, ba),
                  count(vi .< va .- 1e-6), count(va .< vi .- 1e-6)))
end
small = filter(r -> r.n <= 3, bench)

# Sec. 7. Large-scale examples
## Example 7: Service centers for the Carolinas
# Determine the two locations that minimize the total
# population-weighted distance to every city over 10,000 people in North
# and South Carolina, and the territory each one serves.
# Code block 13: the Carolinas' cities and their weights
using GeoMakie, Random
df = filter(r -> r.STFIP in st2fips.([:NC, :SC]) && r.POP > 10_000,
            usplace())
select!(df, :NAME, :ST, :LAT, :LON, :POP)
P = hcat(df.LON, df.LAT)
w = float(df.POP)
nef = size(P, 1)
# Code block 14: two service centers by multistart
Random.seed!(8345)
Xᵒ, TCᵒ, W = ala(randX(P, 2), w, P; nruns = 5)
prt(lonlat2loc(Xᵒ, df))
# Code block 15: mapping the centers and their allocations
Lx, Ly = alloclines(W, Xᵒ, P)
fig, ax = makemap(df.LON, df.LAT; xexpand = 0.1)
for i in eachindex(Lx)
    lines!(ax, Lx[i], Ly[i]; linewidth = 0.5)
end
scatter!(ax, Xᵒ[:, 1], Xᵒ[:, 2]; marker = :dtriangle,
         markersize = 12, color = :black)
text!(ax, Xᵒ[:, 1], Xᵒ[:, 2]; text = lonlat2loc(Xᵒ, df).NAME,
      fontsize = 12, aligntext(Xᵒ[:, 1], Xᵒ[:, 2])...)
fig
# Code block 16: the allocation for a given pair
function alloc36(X)
    D = dists(X, P, :mi)
    α, = allocate(D, w)
    α[1:3] .= 1
    α[4:6] .= 2
    Wc = sparse(α, 1:nef, w, size(X, 1), nef)
    return Wc, sum(Wc .* D)
end
Random.seed!(8345)
Xᶜ, TCᶜ, = ala(randX(P, 2), w, P; alloc = alloc36, nruns = 5)
prt(lonlat2loc(Xᶜ, df))

## Example 8: Reproducing the warehouse table
# Determine the best locations for one, two, three and nine retail
# warehouses serving the continental United States in proportion to
# population, and compare them with @tbl-retail.
# Code block 17: every US population centroid
z = filter(r -> r.ISCUS && r.POP > 0, uszcta3())
select!(z, :ZCTA3, :LAT, :LON, :POP)
Pz = hcat(z.LON, z.LAT)
wz = float(z.POP)
nz = size(Pz, 1)
# Code block 18: cities for naming the answer
cities = filter(r -> r.ISCUS && r.POP > 100_000, usplace())
Random.seed!(4161)
TC1(X) = sum(wz .* dists(reshape(X, 1, 2), Pz, :mi)')
X1 = optimize(TC1, vec(randX(Pz, 1))).minimizer
prt(lonlat2loc(reshape(X1, 1, 2), cities))
# Code block 19: one to ten warehouses
named(X) = select(lonlat2loc(X, cities), :NAME, :ST, :dist)

Xw = Dict{Int,Matrix{Float64}}()
for nw in (2, 3, 9)
    Random.seed!(4161)
    Xw[nw], = ala(randX(Pz, nw), wz, Pz; nruns = 3)
    prt(named(Xw[nw]); title = "$nw warehouses")
end
# Code block 20: the nine-warehouse allocation
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
