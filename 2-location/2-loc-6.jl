# 2-loc-6 — generated from 2-loc-6.qmd by tools/qmd_to_jl.py
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
using Logjam, DataFrames, Optim, CSV, CairoMakie, GeoMakie

## Sec. 1. What makes network design hard
# The network half of lecture 2.2's weighted-flow figure, at the same
# geometry and in the same palette: node color means what kind of
# facility a circle is, and nothing else is colored.
supc = colorant"#1f6fc4"          # suppliers
nfc  = colorant"#1e8a3c"          # the new facility
cusc = colorant"#d21f26"          # customers
ink  = colorant"#252525"
rn   = 0.42                       # node radius, data units

y1, y2 = 3.55, 1.45               # suppliers
y3, y4, y5 = 4.05, 2.50, 0.95     # customers
ynf = 2.50
xsup, xnf, xcus = 11.1, 13.0, 14.9

fig = Figure(size = (520, 300); backgroundcolor = :white)
ax = Axis(fig[1, 1]; backgroundcolor = :white, aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
limits!(ax, xsup - 1.0, xcus + 1.0, 0.3, 4.7)

# Each arrow runs edge to edge, so the star reads as connected.
function flow!(p, q)
    d = q .- p
    u = d ./ sqrt(sum(abs2, d))
    a, b = p .+ u .* rn, q .- u .* rn
    arrows2d!(ax, [a[1]], [a[2]], [b[1] - a[1]], [b[2] - a[2]];
              color = ink, shaftwidth = 2, tipwidth = 10, tiplength = 11)
end

for p in ([xsup, y1], [xsup, y2])
    flow!(p, [xnf, ynf])
end
for q in ([xcus, y3], [xcus, y4], [xcus, y5])
    flow!([xnf, ynf], q)
end

function node!(x, y, label, color; fs = 17)
    poly!(ax, Circle(Point2f(x, y), rn);
          color = :white, strokecolor = color, strokewidth = 2.5)
    text!(ax, x, y; text = label, color = color, fontsize = fs,
          align = (:center, :center))
end

node!(xsup, y1, "1", supc); node!(xsup, y2, "2", supc)
node!(xnf, ynf, "NF", nfc; fs = 14)
node!(xcus, y3, "3", cusc); node!(xcus, y4, "4", cusc)
node!(xcus, y5, "5", cusc)
fig

## Sec. 2. Bottom-up vs. top-down analysis
# One framed panel per analysis, the items and arrows inside it, set the
# way the slide sets them: italic symbols with real subscripts.
ink   = colorant"#191d22"
given = colorant"#0f9aa8"       # what is known at the outset
made  = colorant"#c4342b"       # what the analysis produces

sym(b, s) = rich(rich(b; font = :italic), subscript(s))

lbl!(ax, x, y, s, col) = text!(ax, x, y; text = s, color = col,
    align = (:center, :center), fontsize = 19)

arw!(ax, x1, y1, x2, y2) = arrows2d!(ax, [x1], [y1], [x2 - x1], [y2 - y1];
    shaftwidth = 1.6, tipwidth = 9, tiplength = 10, color = ink)

fig = Figure(size = (660, 210))
for (col, ttl) in [(1, "Bottom-up"), (2, "Top-down")]
    ax = Axis(fig[1, col]; title = ttl, titlesize = 16,
              aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, 0, 10, -2.0, 2.0)
    poly!(ax, Rect2f(0.4, -1.55, 9.2, 3.1); color = :transparent,
          strokecolor = ink, strokewidth = 1.0)
    if col == 1
        lbl!(ax, 1.7, 0.0, rich("r"; font = :italic), given)
        lbl!(ax, 7.2, 0.95, sym("TC", "NEW1"), made)
        lbl!(ax, 7.2, -0.95, sym("TC", "NEW2"), made)
        arw!(ax, 2.5, 0.22, 5.7, 0.82)
        arw!(ax, 2.5, -0.22, 5.7, -0.82)
    else
        lbl!(ax, 2.0, 0.0, sym("TC", "OLD"), given)
        lbl!(ax, 5.0, 0.0, sym("r", "nom"), made)
        lbl!(ax, 8.1, 0.0, sym("TC", "NEW"), made)
        arw!(ax, 3.1, 0.0, 4.0, 0.0)
        arw!(ax, 6.0, 0.0, 7.0, 0.0)
    end
end
fig

# Sec. 2. Bottom-up vs. top-down analysis
# Example 1: One firm evaluated two ways
## Example 1(a): The rate is given (bottom-up)
# Determine the optimum, the cost at Cary, and the difference between
# them, for three customers receiving 40, 25 and 35 truckloads a year at
# \$2.00 per loaded mile.
# Code block 1: three cities, road against great-circle
Detroit     = [-83.1022, 42.3830]   # (lon, lat), degrees
Gainesville = [-82.3492, 29.6807]
Memphis     = [-89.9666, 35.1090]

gc = [dgc(Detroit, Gainesville),    # great circle, mi
      dgc(Detroit, Memphis),
      dgc(Gainesville, Memphis)]

road = [1024.2, 710.8, 632.8]       # road network, mi

g = road ./ gc

ḡ = sum(g) / length(g)              # the region's factor
# Code block 2: truckload weights and the annual cost
P = permutedims(hcat(Detroit, Gainesville, Memphis))  # lon/lat, blk 1
wTL = [40.0, 25.0, 35.0]           # truckloads per year
rate = 2.00                        # $ per loaded mile

TCyr(xy) = rate * ḡ *
    sum(wTL[i] * dgc(xy, P[i, :]) for i in 1:3)
# Code block 3: the optimum site
c0 = wcentroid(P[:, 1], P[:, 2], wTL)
xᵒ = Optim.minimizer(optimize(TCyr, [c0.LON, c0.LAT]))
lonlat2loc(xᵒ, usplace()).desc
# Code block 4: what an alternative site would cost
Cary = [-78.8190, 35.7814]
Δ = TCyr(Cary) - TCyr(xᵒ)
prt(DataFrame(
    Site = ["optimum", "Cary, NC", "increase"],
    Cost = round.([TCyr(xᵒ), TCyr(Cary), Δ], digits = 0)))

## Example 1(b): The rate is backed out (top-down)
# Determine the same increase for the same firm, given not the rate but
# what the firm spent last year, and determine what the two answers have
# in common.
# Code block 5: what the firm knows, and the rate it implies
tonperTL = 10.0                    # ton per truckload
f = wTL .* tonperTL                # ton/yr to each customer
TC₀ = TCyr(Cary)                   # $/yr spent from Cary last year

TD₀ = sum(f[i] * dgc(Cary, P[i, :]) for i in eachindex(f))
rnom = TC₀ / TD₀                   # $/ton-mi
# Code block 6: the optimum, priced at the nominal rate
TCnom(xy) = rnom * sum(f[i] * dgc(xy, P[i, :]) for i in eachindex(f))
xᵒn = Optim.minimizer(optimize(TCnom, [c0.LON, c0.LAT]))
Δn = TCnom(Cary) - TCnom(xᵒn)
prt(DataFrame(
    Site = ["optimum", "Cary, NC", "increase"],
    Cost = round.([TCnom(xᵒn), TCnom(Cary), Δn], digits = 0)))
# Code block 7: three checks on the top-down answer
prt(DataFrame(
    Check = ["Landmark: Cary re-priced equals what was spent",
             "Triangulate: the optimum is the same site",
             "Units: r_nom is \$/ton-mi"],
    Result = [round(TCnom(Cary) - TC₀, digits = 6),
              round(maximum(abs.(xᵒ .- xᵒn)), digits = 6),
              round(rnom, digits = 6)]))

## Example 2: Kudde's U.S. plants
# Determine the number and location of plants Kudde should build, given
# a transport rate of \$2.5523 per ton-mile and a production cost
# subject to economies of scale.
# Code block 8: from the statement to demand, by ZIP code
ubox = 24                       # pillows per box
uwt  = 35 / ubox                # lb per pillow
udem = 1 / 100                  # pillows per person per year
rton = 2.5523                   # $/ton-mi, given
g    = 1.2                      # circuity

z = filter(r -> r.ISCUS && r.POP > 0, uszcta3())
P = hcat(z.LON, z.LAT)
f = float.(z.POP) .* (udem * uwt / 2000)     # ton/yr
(points = nrow(z), tons = round(sum(f), digits = 1))
# Code block 9: the variable cost of serving every ZIP from every site
D = g .* dgca(P, P, z.ALAND)
C = rton .* (f' .* D)
size(C)
# Code block 10: the scale curve, linearized over a demand range
f0   = 1e6 * uwt / 2000         # ton: what one million pillows weigh
TPC0 = 2e6                      # $/yr to produce that million
β    = 0.85                     # scale exponent, from the statement
TPC(x) = TPC0 .* (x ./ f0) .^ β

function fitk(fmax, fmin)
    x = collect(range(fmin, fmax; length = 2000))
    y = TPC(x)
    p = optimize(p -> sum((y .- (p[1] .+ p[2] .* x)) .^ 2), [0.0, 1.0])
    return Optim.minimizer(p)[1]   # the intercept is the fixed cost
end
# Code block 11: alternate between the fixed cost and the UFL
function alternate(C, f)
    tr = DataFrame(iter = Int[], fmax = Float64[], k = Float64[],
                   plants = Int[], TC = Float64[])
    fmin, fmax = minimum(f), sum(f)
    best = (TC = Inf, y = Int[], k = NaN)
    for i in 1:12
        k = fitk(fmax, fmin)
        y, TC, W = ufl(fill(k, size(C, 1)), C; verbose = false)
        push!(tr, (i, fmax, k, length(y), TC))
        TC < best.TC || break
        best = (TC = TC, y = y, k = k)
        fmax = maximum(W * f)   # the largest demand any plant now sees
    end
    return tr, best
end

tr, best = alternate(C, f)
prt(tr)
# Code block 12: where the plants go
prt(DataFrame(Plant = 1:length(best.y),
              Site = [lonlat2loc(P[i, :], usplace()).desc
                      for i in best.y]))

# Sec. 3. Popco Bottling Company
## Example 3: Popco's 42 bottling plants
# Determine the number and location of bottling plants that minimize
# Popco's production and distribution cost, and the change against the
# 42 it operates.
# Code block 13: the 42 plants, as the company keeps them
DC = DataFrame(CSV.File("data/PopcoData.csv"))
rename!(DC, :DEMAND => :fDC, :PROD_COST => :TPC, :DIST_COST => :TDC)
nDC = nrow(DC)
prt(first(DC, 3))
# Two colors carry the whole of Sec. 3: red is what Popco has.
incumbent = colorant"#c4342b"      # what Popco has today
chosen    = colorant"#1a7a3e"      # what the analysis recommends

function popcomap(; w = 640, h = 470)
    fig, ax = makemap(DC.LON, DC.LAT; xexpand = 0.04, yexpand = 0.04)
    resize!(fig, w, h)
    return fig, ax
end

fig, ax = popcomap()
scatter!(ax, DC.LON, DC.LAT; markersize = 10, color = :transparent,
         strokecolor = incumbent, strokewidth = 1.5)
ax.title = "$nDC bottling plants"
ax.titlesize = 15
fig
# Code block 14: regress production cost on output, keep the intercept
ŷ(p, x) = p[1] .+ p[2] .* x
loss(p) = sum((DC.TPC .- ŷ(p, DC.fDC)) .^ 2)
k, cp = Optim.minimizer(optimize(loss, [0.0, 1.0]))
(k = round(k), cp = round(cp, digits = 2))
# The fit is neutral: the data and the intercept carry the color.
fitline = colorant"#4d565f"        # the least-squares fit
fig = Figure(size = (640, 400))
ax = Axis(fig[1, 1]; xlabel = "Annual production (ton/yr)",
          ylabel = "Production and procurement cost (\$/yr)",
          title = "The intercept is the fixed cost", titlesize = 15)
scatter!(ax, DC.fDC, DC.TPC; markersize = 9, color = incumbent)
xs = [0.0, maximum(DC.fDC)]
lines!(ax, xs, ŷ([k, cp], xs); color = fitline, linewidth = 1.8)
scatter!(ax, [0.0], [k]; markersize = 13, color = chosen)
text!(ax, 0.0, k; text = "  k", align = (:left, :bottom),
      fontsize = 16, color = chosen)
# The intercept IS what this figure exists to show, so the axis starts at
# zero: with Makie's default padding the y-axis sits left of x = 0 and k
# floats inside the plot instead of sitting on the axis.
xlims!(ax, 0, 1.02 * maximum(DC.fDC))
ylims!(ax, 0, 1.05 * maximum(DC.TPC))
fig
# Code block 15: allocate ZIP codes to plants, within range
z3 = filter(r -> r.ISCUS && r.POP > 0, uszcta3())
XDC = hcat(DC.LON, DC.LAT)
Dpz = dists(XDC, hcat(z3.LON, z3.LAT), :mi)
z3.IDX = [(i = argmin(@view Dpz[:, j]);
           Dpz[i, j] * 1.2 <= 200 ? i : 0) for j in 1:nrow(z3)]
nall = nrow(z3)
zout = filter(r -> r.IDX == 0, z3)   # beyond every plant's range
filter!(r -> r.IDX != 0, z3)
(candidates = nall, served = nrow(z3), unreachable = nrow(zout))
# A cross rather than a fainter dot: out of range is a rejection, not
# a weaker version of being served. Red stays what Popco has, here as
# in the first map, so the ZIP codes take the neutral and the marker
# shape carries the in-range/out-of-range distinction on its own.
served = colorant"#4d565f"         # a plant reaches these
beyond = colorant"#a9b0b6"         # no plant reaches these
fig, ax = popcomap()
scatter!(ax, zout.LON, zout.LAT; marker = :xcross, markersize = 6,
         color = beyond)
scatter!(ax, z3.LON, z3.LAT; markersize = 4.5, color = served)
scatter!(ax, DC.LON, DC.LAT; markersize = 10, color = :transparent,
         strokecolor = incumbent, strokewidth = 1.5)
ax.title = "$(nrow(z3)) of $nall ZIP codes are within range"
ax.titlesize = 14
fig
# Code block 16: population-proportional demand, and the Balance check
z3 = transform(groupby(z3, :IDX), :POP => sum => :DCPOP)
DC.IDX = 1:nDC
z3 = leftjoin(z3, DC[!, [:IDX, :fDC]], on = :IDX)
z3.f = z3.fDC .* z3.POP ./ z3.DCPOP
(tons_at_plants = sum(DC.fDC), tons_at_zips = sum(z3.f),
 difference = sum(z3.f) - sum(DC.fDC))
# Code block 17: back out the rate, and re-price the incumbent network
XZ = hcat(z3.LON, z3.LAT)
dsv = [dgca(XDC[z3.IDX[j]:z3.IDX[j], :], XZ[j:j, :], [z3.ALAND[j]])[1]
       for j in 1:nrow(z3)]
tonmi = sum(z3.f .* dsv)
rnomP = sum(DC.TDC) / tonmi
(rnom = round(rnomP, digits = 4), spent = sum(DC.TDC),
 repriced = round(rnomP * tonmi))
# Code block 18: candidate sites are ZIP centroids plus incumbent plants
NF = vcat(XZ, XDC)
CP = rnomP .* (z3.f' .* dgca(NF, XZ, z3.ALAND))
size(CP)
# Code block 19: solve, and read the result against what Popco has
y, TC, W = ufl(k, CP)
TDCnew = TC - k * length(y)
TCorig = k * nDC + sum(DC.TDC)
prt(DataFrame(Case = ["existing", "recommended"],
              Plants = [nDC, length(y)],
              TDC = round.([sum(DC.TDC), TDCnew]),
              TC = round.([TCorig, TC])))
# Code block 20: Bounds, against the network Popco already runs
inc = nrow(z3) .+ (1:nDC)        # the incumbents, as candidate sites
TCceil = k * nDC + sum(minimum(CP[inc, :], dims = 1))
prt(DataFrame(Case = ["ceiling: keep all $nDC", "recommended"],
              TC = round.([TCceil, TC])))
# Code block 21: Nudge, on the one parameter the answer turns on
nopen(kmul) = length(first(ufl(kmul * k, CP; verbose = false)))
prt(DataFrame(Fixed_cost = ["k/2", "k", "2k"],
              Plants = [nopen(0.5), nopen(1.0), nopen(2.0)]))
# Code block 22: what kind of site each recommendation is
kept = count(i -> i > nrow(z3), y)
prt(DataFrame(
    Kind = ["an incumbent plant location", "a new site"],
    Sites = [kept, length(y) - kept]))
# Same red and green rings as the first map, so the two read together.
fig, ax = popcomap()
scatter!(ax, DC.LON, DC.LAT; markersize = 8, color = incumbent)
scatter!(ax, NF[y, 1], NF[y, 2]; markersize = 12, color = :transparent,
         strokecolor = chosen, strokewidth = 1.7)
ax.title = "$nDC existing plants, $(length(y)) recommended sites"
ax.titlesize = 15
fig

## Sec. 3. Popco Bottling Company
# Code block 23: what each site would have to produce
load = W * z3.f                       # ton/yr allocated to each open site
kept = [i for i in y if i > nrow(z3)]
prt(DataFrame(
    Network = ["existing, $nDC plants",
               "recommended, $(length(y)) sites"],
    Mean = round.([sum(DC.fDC) / nDC, sum(load[y]) / length(y)]),
    Largest = round.([maximum(DC.fDC), maximum(load[y])])))
# Code block 24: how much each kept plant would grow
prt(DataFrame(
    Plant = [i - nrow(z3) for i in kept],
    Now = round.([DC.fDC[i - nrow(z3)] for i in kept]),
    Planned = round.([load[i] for i in kept]),
    Ratio = round.([load[i] / DC.fDC[i - nrow(z3)] for i in kept],
                   digits = 2)))

# Sec. 4. Two plants on one road
## Example 4: Two plants on one road
# Determine the change in total cost from closing both of a firm's
# plants and opening a single plant at zone 2.
# Code block 25: the instance, read off one road
pos = (A = 0.0, Z1 = 30.0, Z2 = 90.0, Z3 = 160.0, B = 200.0, Z4 = 420.0)
zone, plant = [:Z1, :Z2, :Z3, :Z4], [:A, :B]

output = [300.0, 200.0]                    # ton/yr produced at A and B
prodcost = [460_000.0, 340_000.0]       # $/yr production + procurement
distcost = [162_000.0, 80_000.0]        # $/yr outbound distribution
popn = [120_000.0, 80_000.0, 100_000.0, 60_000.0]    # people
area = [1_200.0, 900.0, 1_500.0, 800.0]              # mi^2

d(i, j) = abs(pos[i] - pos[j])
Dpz = [d(p, z) for p in plant, z in zone]
prt(DataFrame(Plant = string.(plant), Z1 = Dpz[:, 1], Z2 = Dpz[:, 2],
              Z3 = Dpz[:, 3], Z4 = Dpz[:, 4]))
# Code block 26: the fixed cost, from two points
cp = (prodcost[1] - prodcost[2]) / (output[1] - output[2])
k = prodcost[2] - cp * output[2]
(cp = cp, k = k)
# Code block 27: the market, and what falls outside it
nearest = [argmin(@view Dpz[:, j]) for j in eachindex(zone)]
served = [Dpz[nearest[j], j] <= 200 for j in eachindex(zone)]
prt(DataFrame(Zone = string.(zone), Plant = string.(plant[nearest]),
              Miles = [Dpz[nearest[j], j] for j in eachindex(zone)],
              Served = [s ? "yes" : "no" for s in served]))
# Code block 28: population-proportional demand
f = zeros(length(zone))
for i in eachindex(plant)
    mkt = findall(j -> served[j] && nearest[j] == i, eachindex(zone))
    f[mkt] .= output[i] .* popn[mkt] ./ sum(popn[mkt])
end
(tons_at_plants = sum(output), tons_at_zones = sum(f))
# Code block 29: the nominal rate
floorz = (2 / 3) .* sqrt.(area ./ π)
da(dist, j) = max(dist, floorz[j])
tonmi = sum(f[j] * da(Dpz[nearest[j], j], j)
            for j in eachindex(zone) if served[j])
rnom = sum(distcost) / tonmi
(ton_miles = tonmi, spent = sum(distcost), rnom = rnom)
# Code block 30: closing both plants for one at zone 2
Dzz = [d(a, b) for a in zone, b in zone]
served_idx = findall(served)
TCnew = k + rnom * sum(f[j] * da(Dzz[2, j], j) for j in served_idx)
TCorig = length(plant) * k + sum(distcost)
prt(DataFrame(Case = ["two plants, as today", "one plant at zone 2"],
              TC = round.([TCorig, TCnew])))
# Four rows on one shared mile axis. The road is one-dimensional, so
# no map is needed and none is used: Makie primitives on a common x.
# Red is what the firm has and green what the analysis picks, the same as
# every other figure in this lecture.
zonec = colorant"#4d565f"          # a zone inside the screen
outc  = colorant"#a9b0b6"          # a zone the screen drops
XMAX  = 520                        # the reach labels sit past Z4

roadfig = Figure(size = (660, 470))
titles = ["the road", "allocation, and the 200-mile screen",
          "tonnage given to each zone", "one site in place of two"]
axs = [Axis(roadfig[r, 1]; title = titles[r], titlesize = 13,
            titlealign = :left) for r in 1:4]
for (r, ax) in enumerate(axs)
    hideydecorations!(ax)
    hidespines!(ax)
    if r == 4
        ax.xlabel = "miles along the road"
        ax.xlabelsize = 13
    else
        hidexdecorations!(ax; grid = false)
    end
    xlims!(ax, -22, XMAX)   # room for the mile-0 and reach labels
    lines!(ax, [0, XMAX], [0, 0]; color = (:black, 0.2), linewidth = 1)
end

function tag!(ax, x, y, s, c; al = (:center, :bottom))
    text!(ax, x, y; text = s, color = c, fontsize = 12, align = al)
end

# Row 1: where everything is, and nothing else.
for p in plant
    scatter!(axs[1], [pos[p]], [0]; markersize = 13, color = incumbent)
    tag!(axs[1], pos[p], 0.15, "$p ($(Int(pos[p])))", incumbent)
end
for z in zone
    scatter!(axs[1], [pos[z]], [0]; markersize = 9, color = :transparent,
             strokecolor = zonec, strokewidth = 1.5)
    tag!(axs[1], pos[z], -0.55, "$z ($(Int(pos[z])))", zonec)
end
ylims!(axs[1], -1.0, 1.0)

# Row 2: the screen is a reach, so it is drawn as one. The bands sit
# at their own heights: drawn together they overlap from 0 to 200 and
# read as one bar, which hides the only thing the row is for.
for (i, p) in enumerate(plant)
    y = -0.55 - 0.45 * (i - 1)
    lo, hi = pos[p] - 200, pos[p] + 200
    lines!(axs[2], [max(lo, 0), hi], [y, y]; color = (incumbent, 0.30),
           linewidth = 8)
    lines!(axs[2], [hi, hi], [y - 0.14, y + 0.14]; color = incumbent,
           linewidth = 1.5)
    tag!(axs[2], hi + 6, y - 0.1, "$p reaches $(Int(hi))", incumbent;
         al = (:left, :bottom))
    scatter!(axs[2], [pos[p]], [0]; markersize = 13, color = incumbent)
end
for (j, z) in enumerate(zone)
    c = served[j] ? zonec : outc
    scatter!(axs[2], [pos[z]], [0]; markersize = 9, color = c,
             marker = served[j] ? :circle : :xcross)
    # Alternating heights: at 30 and 90 miles the labels collide.
    near = plant[nearest[j]]
    tag!(axs[2], pos[z], isodd(j) ? 0.16 : 0.46,
         served[j] ? "$z: $(Int(Dpz[nearest[j], j])) mi to $near" :
                     "$z: dropped", c)
end
ylims!(axs[2], -1.5, 1.25)

# Row 3: a bar per zone, so the split reads as a quantity.
for (j, z) in enumerate(zone)
    served[j] || continue
    lines!(axs[3], [pos[z], pos[z]], [0, f[j]];
           color = zonec, linewidth = 8)
    tag!(axs[3], pos[z], f[j] + 10, "$(Int(round(f[j]))) ton", zonec)
end
ylims!(axs[3], -25, 275)

# Row 4: the candidate, and what it would have to reach.
zc = pos[zone[2]]
for p in plant
    scatter!(axs[4], [pos[p]], [0]; markersize = 13, color = :transparent,
             strokecolor = (incumbent, 0.45), strokewidth = 1.5)
end
scatter!(axs[4], [zc], [0]; markersize = 15, color = chosen)
tag!(axs[4], zc, 0.18, "one plant at $(zone[2])", chosen)
reach = 0
for (j, z) in enumerate(zone)
    (served[j] && j != 2) || continue
    reach += 1
    y = -0.4 - 0.35 * (reach - 1)      # one line each, so none merge
    lines!(axs[4], [zc, pos[z]], [y, y];
           color = (chosen, 0.5), linewidth = 2)
    # Left-aligned at the far end, so the label runs away from the
    # site marker rather than across it.
    tag!(axs[4], min(zc, pos[z]) + 4, y + 0.05,
         "to $z, $(Int(abs(zc - pos[z]))) mi", chosen;
         al = (:left, :bottom))
end
ylims!(axs[4], -1.4, 1.0)
roadfig
