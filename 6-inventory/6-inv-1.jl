# 6-inv-1 — generated from 6-inv-1.qmd by tools/qmd_to_jl.py
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
using CairoMakie, DataFrames, Logjam, Optim, Random, Statistics
# Two device pixels per figure unit, as in lectures 3.2 to 5.3, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Presentation plumbing for the prose, as in Lectures 4.1 to 5.3: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

# Sec. 2. Working stock
## Example 1: Inventory turns
# Inventory turnover is a measure of the number of times inventory is
# sold. The value of inventory for a firm at the beginning of the year
# was \$10.2 million and \$12.4 million at the end of the year, and its
# annual cost of goods sold (COGS) was \$226 million. Determine its
# inventory turnover during the year.
# Code block 1: inventory turns by Little's Law
@show WIP = (10.2 + 12.4)/2   # average inventory ($ million)
TH = 226                      # annual cost of goods sold ($ million/yr)
@show CT = WIP/TH             # cycle time (yr)
@show turns = 1/CT            # turns per year

# Example 2: In-transit inventory and suppliers
## Example 2(a): In-transit inventory cost
# Currently, a factory in Los Angeles imports 12 containers per year
# from a supplier in Shanghai, each CL (container load) has 15 tons of
# raw material. Each ton of RM costs \$7,000 and loses 10% of its value
# after three months. Each container spends 21 days in transit, and its
# transport cost is \$2,620. Determine the annual in-transit inventory
# cost for RM.
# Code block 2: annual in-transit inventory cost, international supplier
q = 15                        # ton/CL, shipment size
n = 12                        # CL/yr, shipment frequency
@show t = 21/365.25           # yr, transit time (CT)
@show TH = n*q                # ton/yr, annual throughput
@show qI = n*q*t              # ton, average inventory in transit (WIP)
@show n*t                     # share of a year a container is in transit
xh = 0.1                      # value lost over the period
th = 0.25                     # yr, period of value loss
@show hobs = xh/th            # 1/yr, obsolescence rate
hint = 0.05                   # 1/yr, interest
hwh = 0.06                    # 1/yr, warehousing
@show h = hint + hwh + hobs   # 1/yr, total annual carrying rate
v = 7000                      # $/ton, value per ton
@show ICw = v*h*qI            # $/yr, annual in-transit inventory cost

## Example 2(b): Supplier selection
# Continuing Ex. 2(a), a domestic supplier has been identified with a
# cost of \$9,000 per ton. 12 truckloads (TLs) per year, each containing
# 15 tons of RM, would be shipped 200 miles in one day. TL revenue per
# loaded mile is \$2. Determine whether the domestic supplier should be
# used.
# Code block 3: total logistics cost of each supplier
# international, from Shanghai: n, q, h, v and ICw as in Code block 2
cCL = 2620                    # $/CL, transport cost per container
TC1 = n*cCL                   # $/yr, transport cost
PC1 = n*v*q                   # $/yr, purchase cost
TLC1 = TC1 + ICw + PC1        # $/yr, total logistics cost
# domestic, by truckload
rTL = 2                       # $/mi, TL revenue per loaded mile
dTL = 200                     # mi, distance
@show cTL = rTL*dTL           # $/TL, truckload charge
t2 = 1/365.25                 # yr, transit time
@show qI2 = n*q*t2            # ton, average inventory in transit
@show n*t2                    # share of the year a truck is in transit
v2 = 9000                     # $/ton, value per ton
ICw2 = v2*h*qI2               # $/yr, in-transit inventory cost
TC2 = n*cTL                   # $/yr, transport cost
PC2 = n*v2*q                  # $/yr, purchase cost
TLC2 = TC2 + ICw2 + PC2       # $/yr, total logistics cost
# the two suppliers' costs, side by side
prt(DataFrame(supplier = ["international", "domestic"], TC = [TC1, TC2],
              ICw = round.([ICw, ICw2], digits = 2), PC = [PC1, PC2],
              TLC = round.([TLC1, TLC2], digits = 2)))

# Example 3: Dwell at a DC and through a plan
## Example 3(a): Dwell at the Memphis DC
# In {{< xref 3.4 example-2-b >}}, with no coordination at the
# distribution center (DC) in Memphis, the DC holds on average half of
# each of its three inbound shipments, 6.647, 2.0625 and 8.25 tons, and
# 875 tons pass through it each year. Determine the average time a ton
# spends at the DC.
# Code block 4: mean dwell at the Memphis DC, Lecture 3.4's Ex. 2(b)
@show WIPdc = 6.647 + 2.0625 + 8.25   # ton, half of each inbound shipment
THdc = 875                            # ton/yr, throughput of the DC
@show CTyr = WIPdc/THdc               # yr, mean dwell
@show CTdc = CTyr*365.25              # days, mean dwell

## Example 3(b): Cycle time of a production plan
# The plan of {{< xref 4.3 example-1 >}} delivers 20, 10 and 15 tons in
# its three months, and carries 25 tons of inventory at stage 2 between
# months 1 and 2 and 15 tons between months 2 and 3. Determine the
# average time a ton spends in the plan, from stage 1 to delivery.
# Code block 5: cycle time of Lecture 4.3's Ex. 1 plan
y = [25, 15]                    # ton, carried after months 1 and 2
d = [20, 10, 15]                # ton, delivered in months 1 to 3
@show WIPplan = sum(y)          # ton-months, the plan's WIP
@show THplan = sum(d)           # ton, delivered over the three months
@show CTplan = WIPplan/THplan   # months, stage 1 to delivery

# Sec. 3. Economic stock
## Model: Economic order quantity
# Model: economic order quantity
eoq(f, co, v, h) = sqrt(2*f*co/(v*h))

# Example 4: EOQ for setup costs
## Example 4(a): EOQ by hand
# Determine the number of parts to produce per run by hand, from
# @eq-tlc-eoq and @eq-eoq.
qᵒ = eoq(100_000, 250, 100, 0.3)   # parts/run, the hand result

## Example 4(b): EOQ in code and by brute force
# Determine the number of parts per run with the implementation of
# @mdl-eoq and by a brute-force search of @eq-tlc-eoq over every whole
# number of parts, and compare both with Ex. 4(a).
# Code block 6: EOQ for setup costs
f = 100_000             # units/yr, annual demand
co = 250                # $/run, setup cost
v = 100                 # $/part, value of a finished part
h = 0.3                 # 1/yr, carrying rate
qᵒ = eoq(f, co, v, h)   # parts/run
# Code block 7: brute-force search for the minimum-TLC run size
TLCbf, qbf = minimum((totlogcost(q, co, f, 1/2, v, h), q)
# totlogcost is the Logjam function of Lecture 3.3 for the total logistics
# cost of a shipment size; with its $\alpha$ set at one half it is
# @eq-tlc-eoq. Each run size is paired with its cost, and minimum compares
# the pairs by cost first, so it returns the least cost together with its
# run size, as Code block 4 of Lecture 5.2 does for routes.
                     for q ∈ 1:f)

# Sec. 4. One-time safety stock
## Example 5: Pre-fill level of a test tank
# A testing center has a device that is able to use ultrasonic waves
# transmitted within a special solution to detect defects in parts like
# aircraft engines. The part is placed in a tank that, in order to
# operate correctly, is filled with just enough solution to submerge the
# part; the solution is then drained from the tank and disposed of since
# it can become contaminated during testing. Currently, test results are
# being delayed because it is time-consuming to fill the tank with the
# solution. In order to speed up testing, a suggestion has been made to
# consider pre-filling the tank and then either adding or draining the
# solution as needed to submerge a part. The following demand data is
# available regarding the cubic volume of solution that was needed to
# test recent parts:$$237, 214, 161, 146, 331, 159, 423, 332, 139, 327,
# 152, 98, 116$$ Determine the cubic volume of solution that should be
# pre-filled in the tank to minimize the time required to submerge the
# part, given that the tank can be filled or drained at the same rate.
# Code block 8: the pre-fill demand data and its histogram
d = [237, 214, 161, 146, 331, 159, 423, 332, 139, 327, 152, 98, 116]
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = "Demand (cubic volume)", ylabel = "Count",
          xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13)
bluec = colorant"#1f6fb5"                # data, as in Lectures 4.1 to 5.3
hist!(ax, d; bins = 0:50:450, color = bluec, strokecolor = :white,
      strokewidth = 1)
fig

# Example 5: Pre-fill level of a test tank
## Example 5(a): Pre-fill level by hand
# Determine the pre-fill level by hand, as the median of the demands.
qmed = median(d)   # the hand result

## Example 5(b): Pre-fill level in code
# Determine the pre-fill level in code by the median procedure of
# Lecture 2.1, and the level that minimizes the total time numerically,
# and compare both with Ex. 5(a).
# Code block 9: pre-fill level by the median procedure, then numerically
# the median procedure of Lecture 2.1, as Lecture 2.2 coded it
ds = sort(d)                                # demands in order
w = ones(Int, length(ds))                   # each part an EF, weight one
@show W = sum(w)
@show j = findfirst(>=(W / 2), cumsum(w))   # first running total >= W/2
@show qmed = ds[j]

# the total time over the 13 parts, minimized
using Optim
ft(q, di) = abs(di - q)                  # time for a single part
fTT(q, d) = sum(ft(q, di) for di in d)   # total time
# brute force first: each whole-number level, one at a time
TTmin, qmin = minimum((fTT(q, d), q) for q ∈ 0:maximum(d))
@show qmin
qᵒ = optimize(q -> fTT(q, d), 0, maximum(d)).minimizer
@show round(qᵒ, digits = 2)
@show round(fTT(qᵒ, d), digits = 2);
# Code block 10: total time against the pre-fill level
fig = Figure(size = (600, 320))
ax = Axis(fig[1, 1]; xlabel = "Pre-fill level", ylabel = "Total time",
          xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13)
optc = colorant"#b23a48"                 # an optimum, as in Lecture 2.2
lines!(ax, 0:maximum(d), q -> fTT(q, d); color = bluec, linewidth = 2)
scatter!(ax, [qᵒ], [fTT(qᵒ, d)]; color = optc, markersize = 13)
fig

## Example 5(c): Extreme outlier
# Determine the pre-fill level if the demand of 423 had instead been
# 1,423.
# Code block 11: the pre-fill level with an extreme outlier
d2 = copy(d)             # a copy: d2 = d would only point to d, and
d2[d2 .== 423] .= 1423   # a change to d2 would also change d
qᵒ2 = optimize(q -> fTT(q, d2), 0, maximum(d2)).minimizer
@show round(qᵒ2, digits = 2)
@show round(fTT(qᵒ2, d2), digits = 2);
# Code block 12: the median of each data set
using Statistics
@show median(d)
@show median(d2);

## Model: One-time safety stock
# Model: one-time safety stock
# One demand's cost (c_over, c_under given), total, and best quantity
fc(q, di) = c_over*max(q - di, 0) + c_under*max(di - q, 0)
fC(q, d) = sum(fc(q, di) for di in d)
mincost(d) = minimum((fC(q, d), q) for q ∈ 0:maximum(d))
# Each whole number from 0 to the largest demand is tried in turn, and the
# one with the least total cost is kept. No quantity above the largest
# demand can do better than that demand, since each unit above it is a
# unit over with no demand to meet.

## Example 5(d): Filling twice as slow as draining
# Determine the pre-fill level if the drain rate is twice the fill rate,
# for the demands with and without the outlier.
# Code block 13: pre-fill level when filling takes twice as long
c_over, c_under = 1, 2    # time per unit drained and per unit filled
Cᵒ, qᵒ = mincost(d)       # with the demands as given
C2ᵒ, q2ᵒ = mincost(d2)    # with the outlier
qᵒ, q2ᵒ

# Example 6: Lee Pharm's bakery
## Example 6(a): Stationarity of the demand
# Determine whether the 13 days of demand can be taken as stationary.
# Code block 14: a helper that plots a series as observed and in two
# random permutations, used on the bakery's demand
using Random

function plotperms(x, ylabel, caption_a; seed = 2523)
# An argument after the semicolon is a keyword argument, and one given a
# value, as seed is, is optional: a call that leaves it out gets 2523, and
# plotperms(d, "Demand", "day by day"; seed = 1) draws two other
# permutations.
    # settings: change these to adapt the plot
    figsize = (600, 560)              # width and height, pixels
    color = bluec                     # color of the line
    arrowc = :gray40                  # color of the arrows from (a)
    sizes = (xlabelsize = 15, ylabelsize = 15,
    # A named tuple holds the four font sizes, so that all four are
    # changed in one place; sizes... in the call to Axis passes each of
    # them as a keyword argument of the same name.
             xticklabelsize = 13, yticklabelsize = 13)
    captions = (caption_a, "a random permutation", "a random permutation")

    # the plot: one panel per order, each captioned below
    N = length(x)                     # number of values in the series
    Random.seed!(seed)                # the same permutations every run
    orders = (1:N, randperm(N), randperm(N))
    # The first order, 1:N, is the series as observed. randperm(N) is a
    # random reordering of the numbers 1 to N, so indexing the series by
    # it, as x[orders[k]] does in the call to lines!, permutes the series.
    fig = Figure(size = figsize)
    axs = [Axis(fig[2k - 1, 1]; ylabel, xticks = 1:N, sizes...)
    # A keyword written alone, as ylabel is here and color is in the call
    # to lines!, passes the variable of that name as the keyword argument
    # of the same name, so the axis label is the function's second
    # argument.
           for k in 1:3]
    for k in 1:3
        lines!(axs[k], 1:N, x[orders[k]]; color, linewidth = 2)
        Label(fig[2k, 1], "($('a' + k - 1)) $(captions[k])";
        # Panel k sits in row 2k - 1 of the figure's grid and its caption
        # in row 2k, below it; 'a' + k - 1 is the letter a, b or c.
              fontsize = 15, tellwidth = false)
    end

    # an arrow from (a) to each panel derived from it, at their right
    colsize!(fig.layout, 1, Relative(0.92))
    vp = [ax.scene.viewport[] for ax in axs]
    # Once the panels are laid out, viewport gives each one's place on the
    # figure, in pixels from its lower left corner, so the arrows are
    # drawn on the figure itself, fig.scene, rather than in a panel: a
    # line from the right of (a) down to the middle of (c), with an
    # arrowhead into (b) and into (c), the two panels derived from (a).
    # colsize! keeps the panels to 92% of the width, leaving room for the
    # arrows.
    xr = vp[1].origin[1] + vp[1].widths[1]         # panels' right edge
    ym = [v.origin[2] + v.widths[2]/2 for v in vp] # their middles
    lines!(fig.scene, [xr + 4, xr + 22, xr + 22], [ym[1], ym[1], ym[3]];
           color = arrowc, linewidth = 1.5)
    arrows2d!(fig.scene, fill(xr + 22, 2), ym[2:3], [-18, -18], [0, 0];
              color = arrowc)
    return fig
end

d = [237, 214, 161, 146, 331, 159, 423, 332, 139, 327, 152, 98, 116]
plotperms(d, "Demand", "day by day")

## Example 6(b): Baseline and upper bound
# Determine the total profit of baking 216 loaves each day, and an upper
# bound on total profit.
# Code block 15: baseline and upper bound on total profit
p = 5                                # $/loaf, unit price
c = 1                                # $/loaf, unit cost
c_over = c                           # $/loaf over: baked and not sold
c_under = p - c                      # $/loaf under: the profit lost
fΠ(q, d) = (p - c)*sum(d) - fC(q, d) # total profit: bound less cost
Πᴮᴸ = fΠ(216, d)                     # baseline: 216 loaves every day
Πᵁᴮ = (p - c)*sum(d)                 # upper bound: perfect prediction
@show Πᴮᴸ
@show Πᵁᴮ
@show Πᴮᴸ/Πᵁᴮ;

## Example 6(c): Maximum total profit
# Determine the number of loaves to bake each day that maximizes total
# profit, by brute force, and check it with a numerical optimizer.
# Code block 16: loaves that maximize total profit, by brute force
Cᵒ, qᵒ = mincost(d) # least total cost, and its loaves
Πᵒ = fΠ(qᵒ, d)      # their total profit
@show qᵒ
@show Πᵒ
@show Πᵒ/Πᵁᴮ        # share of the upper bound
@show Πᵒ/Πᴮᴸ;       # against the baseline
# Code block 17: the same with a numerical optimizer
qᵒOptim = optimize(q -> -fΠ(q, d), 0, 500).minimizer
@show round(qᵒOptim, digits = 2)
@show round(fΠ(qᵒOptim, d), digits = 2);
# Code block 18: total profit against the loaves baked each day
fig = Figure(size = (600, 320))
ax = Axis(fig[1, 1]; xlabel = "Loaves baked each day",
          ylabel = "Total profit (\$)", xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13)
lines!(ax, 0:500, q -> fΠ(q, d); color = bluec, linewidth = 2)
scatter!(ax, [qᵒ], [Πᵒ]; color = optc, markersize = 13)
fig

## Example 6(d): Mean, median and safety stock
# Determine the total profit of baking the mean and the median demand
# each day, and the safety stock of the maximum-profit number of loaves.
# Code block 19: total profit of baking the mean or the median demand
@show mean(d)
@show fΠ(mean(d), d)
@show median(d)
@show fΠ(median(d), d);
qSS = qᵒ - mean(d)   # the safety stock of Ex. 6(c)'s size

## Model: One-time safety stock by regression
# Model: one-time safety stock by regression
# Total cost, the production rule, and the best rule
fC(q::AbstractVector, d) = sum(fc.(q, d))
# q::AbstractVector makes this a second method of fC, which Julia uses
# only when q is a vector, one quantity for each demand; when q is a
# single number it still uses the method of @mdl-safety1. The dot in
# fc.(q, d) applies fc to each demand in turn, with its own quantity, and
# sum adds their costs.
fq̂(a, x...) = a[1] .+ sum(a[j + 1]*x[j] for j in 1:length(x))
# x... in a definition gathers every argument after a, however many there
# are, into one tuple named x, so x[j] is independent variable $j$ and
# length(x) is $m$: fq̂(a, o) has $m = 1$ and fq̂(a, o, v) has $m = 2$.
# Each x[j] is a vector over the days, so the sum is too, and the dot in
# .+ adds the intercept to each of its elements, giving one size for each
# day; given single numbers, as in fq̂(a, 120, 45), the rule gives one
# size.
mincost(d, x...) = optimize(a -> fC(fq̂(a, x...), d),
# x... in a call does the reverse of x... in a definition: it spreads the
# tuple back out into separate arguments, so fq̂(a, x...) is fq̂(a, o)
# when mincost was called as mincost(d, o). optimize minimizes, so the
# total cost is handed to it as it is, where the total profit of Code
# block 17 had to be negated.
                            [0; ones(length(x))]).minimizer
                            # Given a starting vector rather than an
                            # interval, as Code block 17 gave it, optimize
                            # searches over all the elements of a
                            # together. [0; ones(length(x))] starts the
                            # intercept at 0 and each of the $m$
                            # coefficients at 1, which for the orders
                            # alone is the rule of baking just the orders,
                            # and .minimizer is the a at which the search
                            # ends.

## Example 6(f): Loaves from the morning's orders
# Determine the linear rule on each morning's orders that maximizes
# total profit, and compare its total profit with those of the rules
# fitted by least squares and by least absolute deviation.
# Code block 20: the morning's orders and their correlation with demand
o = [121, 143, 63, 80, 198, 52, 160, 162, 85, 106, 129, 141, 106]
@show cor(o, d)
dcc = colorant"#1e8a3c"                  # as in Lectures 4.1 to 5.3
fig = Figure(size = (600, 640))
ax1 = Axis(fig[1, 1]; xlabel = "Day", ylabel = "Loaves",
           xticks = 1:length(d), xlabelsize = 15, ylabelsize = 15,
           xticklabelsize = 13, yticklabelsize = 13)
Label(fig[2, 1], "(a) day by day"; fontsize = 15,
      tellwidth = false)                    # caption, below its panel
lines!(ax1, 1:length(o), o; color = dcc, linewidth = 2,
       label = "Orders")
lines!(ax1, 1:length(d), d; color = bluec, linewidth = 2,
       label = "Demand")
axislegend(ax1; position = :lt, labelsize = 13)
ax2 = Axis(fig[3, 1]; xlabel = "Orders by the morning",
           ylabel = "Demand",
           title = "correlation $(round(cor(o, d), digits = 2))",
           titlesize = 15, titlefont = :regular, xlabelsize = 15,
           ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13)
Label(fig[4, 1], "(b) demand against orders"; fontsize = 15,
      tellwidth = false)                    # caption, below its panel
scatter!(ax2, o, d; color = bluec, markersize = 10)
fig
# Code block 21: total profit of baking just the morning's orders
fΠ(o, d)
# Code block 22: the rule on orders that maximizes total profit
aΠᵒ = mincost(d, o)
@show aΠᵒ
@show fΠ(fq̂(aΠᵒ, o), d)
@show fΠ(fq̂(aΠᵒ, o), d)/Πᵁᴮ      # share of the upper bound
@show fΠ(fq̂(aΠᵒ, o), d)/Πᴮᴸ;     # against the baseline
# Code block 23: rules by least squares and by least absolute deviation
aL2 = [ones(length(o)) o] \ d                       # least squares
aL1 = optimize(a -> sum(abs.(d .- fq̂(a, o))), [0., 1.]).minimizer
@show fΠ(fq̂(aL2, o), d)
@show fΠ(fq̂(aL1, o), d);
# Code block 24: demand against orders, with the three fitted rules
fig = Figure(size = (600, 380))
ax = Axis(fig[1, 1]; xlabel = "Orders by the morning",
          ylabel = "Demand", xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13)
scatter!(ax, o, d; color = bluec, markersize = 10)
x = [0, maximum(o)]
dcc = colorant"#1e8a3c"                  # as in Lectures 4.1 to 5.3
orc = colorant"#e08214"                  # as in Lecture 4.2
Πlab(a) = "\$$(commas(round(Int, fΠ(fq̂(a, o), d))))"   # its total profit
lines!(ax, x, fq̂(aΠᵒ, x); color = optc, linewidth = 2,
       label = "Maximum profit, $(Πlab(aΠᵒ))")
lines!(ax, x, fq̂(aL2, x); color = dcc, linewidth = 2, linestyle = :dash,
       label = "Least squares, $(Πlab(aL2))")
lines!(ax, x, fq̂(aL1, x); color = orc, linewidth = 2, linestyle = :dot,
       label = "Least absolute deviation, $(Πlab(aL1))")
axislegend(ax; position = :lt, labelsize = 13)
fig
# Code block 25: loaves to bake on day 14, with 120 orders
fq̂(aΠᵒ, 120)

## Example 6(g): Adding the website's visitors
# Determine the rule on each morning's orders and the past day's website
# visitors that maximizes total profit, and the loaves it bakes on day
# 14, with 120 orders and 45 visitors.
# Code block 26: the website's unique visitors and their correlation
v = [69, 72, 56, 72, 82, 80, 72, 64, 50, 65, 49, 51, 66]
@show cor(v, d)
fig = Figure(size = (600, 340))
ax = Axis(fig[1, 1]; xlabel = "Unique visitors over the past day",
          ylabel = "Demand",
          title = "correlation $(round(cor(v, d), digits = 2))",
          titlesize = 15, titlefont = :regular, xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13)
scatter!(ax, v, d; color = bluec, markersize = 10)
fig
# Code block 27: the rule on orders and visitors that maximizes profit
aΠᴹᵒ = mincost(d, o, v)
@show aΠᴹᵒ
@show fΠ(fq̂(aΠᴹᵒ, o, v), d);
# Code block 28: loaves to bake on day 14, with 120 orders, 45 visitors
fq̂(aΠᴹᵒ, 120, 45)

## Sec. 4. One-time safety stock
# Code block 29: total profit of each procedure
procs = ["Baseline, 216 loaves", "Mean demand", "Median demand",
         "Maximum profit", "Orders alone", "Orders, least squares",
         "Orders, least absolute deviation", "Orders, maximum profit",
         "Orders and visitors, maximum profit", "Perfect prediction"]
uses = ["past demand", "demand", "demand", "demand", "orders",
        "orders", "orders", "orders", "orders, visitors",
        "actual demand"]
fits = ["rounded mean", "squared error", "absolute error",
        "profit", "–", "squared error", "absolute error", "profit",
        "profit", "–"]
Πs = [Πᴮᴸ, fΠ(mean(d), d), fΠ(median(d), d), Πᵒ, fΠ(o, d),
      fΠ(fq̂(aL2, o), d), fΠ(fq̂(aL1, o), d), fΠ(fq̂(aΠᵒ, o), d),
      fΠ(fq̂(aΠᴹᵒ, o, v), d), Πᵁᴮ]
prt(DataFrame(procedure = procs, data = uses, fit = fits,
              profit = round.(Πs, digits = 2),
              share = round.(Πs ./ Πᵁᴮ, digits = 3)))
# Code block 30: the maximum-profit size with a unit cost of $2
c = 2                       # $/loaf, the nudged unit cost
c_over, c_under = c, p - c  # $/loaf over and under, now 2 and 3
Cᵒc2, qᵒc2 = mincost(d)
c = 1                       # $/loaf, the bakery's unit cost again
c_over, c_under = c, p - c  # $/loaf over and under, 1 and 4 again
qᵒc2

# Example 7: One-time construction delivery
## Example 7(a): Stationarity of the transit times
# Determine whether the 12 transit times can be taken as stationary.
# Code block 31: the transit times, as shipped and randomly permuted
transit = [19, 17, 20, 35, 18, 16, 18, 28, 19, 17, 31, 14]   # days
plotperms(transit, "Days in transit", "shipment by shipment")

## Example 7(c): Shipping time and supplier in code
# Determine in code how far ahead of the day of use the container should
# be sent, the total logistics cost of the delivery from each supplier,
# and which supplier should be used.
# Code block 32: how far ahead to send the container
q = 15                             # ton, one container load
v = 7000                           # $/ton, Shanghai supplier's price
h = 0.51                           # 1/yr, carrying rate
cdem = 250                         # $/day, demurrage, no free time
c_over = v*h*q/365.25 + cdem       # $/day over: a day early
c_under = 3000                     # $/day under: penalty, a day late
N = length(transit)                # shipments in the record
Cᵒ, taᵒ = mincost(transit)
@show taᵒ                          # days, sent this far ahead of use
@show round(Cᵒ/N, digits = 2);     # $, early or late, per delivery
# Code block 33: total logistics cost of the delivery, each supplier
cCL, cTL = 2620, 400               # $, container and truckload charges
v2 = 7500                          # $/ton, domestic supplier's price
ICwi = v*h*q*mean(transit)/365.25  # $, in transit, international
ICwd = v2*h*q*1/365.25             # $, in transit, domestic: one day
ELi = Cᵒ/N                         # $, early or late, international
TLCi = cCL + ICwi + ELi + v*q      # $, total, international
TLCd = cTL + ICwd + v2*q           # $, total, domestic: never late
prt(DataFrame(supplier = ["international", "domestic"], TC = [cCL, cTL],
              ICw = round.([ICwi, ICwd], digits = 2),
              early_late = round.([ELi, 0], digits = 2),
              PC = [v*q, v2*q], TLC = round.([TLCi, TLCd], digits = 2)))
# Code block 34: each shipment's working and safety stock, sent taᵒ ahead
orc = colorant"#e08214"                  # as in Lecture 4.2
latec = colorant"#c4342b"                # as in Lecture 2.5
arrive = min.(transit, taᵒ)              # in transit until arrival or use

fig = Figure(size = (600, 500))
ax = Axis(fig[1, 1]; xlabel = "Days after the container is sent",
          ylabel = "Shipment of the record", yticks = 1:N,
          yreversed = true, xticks = 0:7:35, xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13,
          ygridvisible = false)
# in transit up to the day of use, then at the site, or late
barplot!(ax, 1:N, arrive; direction = :x, width = 0.7, gap = 0,
         color = bluec, label = "in transit: working stock")
barplot!(ax, 1:N, fill(taᵒ, N); fillto = arrive, direction = :x,
         width = 0.7, gap = 0, color = orc,
         label = "at the site: safety stock")
barplot!(ax, 1:N, max.(transit, taᵒ); fillto = taᵒ, direction = :x,
         width = 0.7, gap = 0, color = latec, label = "late")
vlines!(ax, [taᵒ]; color = :gray30, linestyle = :dash, linewidth = 2)
text!(ax, taᵒ, 0.3; text = "day of use", align = (:right, :bottom),
      offset = (-4, 0), color = :gray30, fontsize = 14)
Legend(fig[2, 1], ax; orientation = :horizontal, framevisible = false,
       labelsize = 13)
xlims!(ax, 0, 36)
ylims!(ax, N + 0.6, -0.4)
fig
