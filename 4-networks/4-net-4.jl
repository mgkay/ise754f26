# 4-net-4 — generated from 4-net-4.qmd by tools/qmd_to_jl.py
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
using CairoMakie, JuMP, HiGHS, Logjam, SparseArrays
# Two device pixels per figure unit, as in lectures 3.2 to 4.3, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Presentation plumbing for the prose, as in Lectures 4.1 to 4.3: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end
# Dollars with two decimals, for a total such as 270,112.50
function usd(x)
    c = round(Int, 100x)
    return commas(div(c, 100)) * "." * lpad(rem(c, 100), 2, '0')
end

## Sec. 1. Multiple products
# Code block 1: two products' networks, coupled (a) and linked (b)
# Product k's stage i in period j is at P(k, i, j); each arc runs from
# node outline to node outline, and the nodes are drawn over the arcs
ink, datac = colorant"#252525", colorant"#d21f26"
# Each symbol in the font of the lecture's equations, in black, and each
# given value in red, as in Lecture 4.3's network figure; everything
# else in black but the circles and their connectors
mi = Makie.MathTeXEngine.texfont(:italic)
mr = Makie.MathTeXEngine.texfont(:math)
it(s) = rich(s; font = mi)                        # a symbol, in italics
up(s; kw...) = rich(s; font = mr, kw...)          # digits, operators
sym(b, sub, sup = nothing) = sup === nothing ?    # b with subscript sub
    rich(it(b), subscript(up(sub))) :            #   and superscript sup
    rich(it(b), subsup(up(sub), it(sup)))
val(v; op = " = ") = rich(up(op), up("$v"; color = datac))   # a value
# A connector from a circle to its constraint: a curve from p to q,
# drawn toward the control point c
function connector!(ax, p, c, q)
    pts = [Point2f((1 - u)^2 .* p .+ 2u * (1 - u) .* c .+ u^2 .* q)
           for u in range(0, 1; length = 60)]
    return lines!(ax, pts; color = datac, linewidth = 1.6)
end
function twonets!(ax; panel = :coupling, r = 0.16, dx = 1.5, dy = 1.25,
                  gap = 2.9, ls = 15)
    hidedecorations!(ax); hidespines!(ax)
    P(k, i, j) = ((k - 1) * (dx + gap) + (j - 1) * dx, -(i - 1) * dy)
    arc(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]],
                          [q[2] - p[2]]; color = ink, shaftwidth = 1.2,
                          tipwidth = 7, tiplength = 7)
    lbl(p, s; al = (:left, :center), c = ink, fs = ls) =
        text!(ax, p[1], p[2]; text = s, color = c, fontsize = fs,
              align = al)
    circ = Dict{Int,Tuple{Float64,Float64}}()    # each product's circle
    for k in 1:2
        for j in 1:2
            x0, y0 = P(k, 1, j)
            arc((x0, y0 + 1.0), (x0, y0 + r))        # supply into stage 1
            for i in 2:3                             # production arcs
                arc(P(k, i - 1, j) .- (0, r), P(k, i, j) .+ (0, r))
            end
            xm, ym = P(k, 3, j)                      # demand from stage 3
            arc((xm, ym - r), (xm, ym - 0.7))
            lbl((xm, ym - 0.78), sym("d", "$j,$k"); al = (:center, :top))
        end
        for i in 1:3                             # inventory arcs
            arc(P(k, i, 1) .- (1.3, 0), P(k, i, 1) .- (r, 0))
            arc(P(k, i, 1) .+ (r, 0), P(k, i, 2) .- (r, 0))
            arc(P(k, i, 2) .+ (r, 0), P(k, i, 2) .+ (0.75, 0))
            y0 = (k == 2 && i == 3) ? 5 : 0          # initial inventory
            lbl(P(k, i, 1) .- (0.73, -0.10),
                rich(sym("y", "$i,1,$k"), val(y0));
                al = (:center, :bottom), fs = ls - 1)
        end
        for i in 1:3, j in 1:2                   # nodes, over the arcs
            poly!(ax, Circle(Point2f(P(k, i, j)...), r); color = :white,
                  strokecolor = ink, strokewidth = 1.5)
        end
        lbl(P(k, 1, 1) .+ (dx / 2, 1.3), "Product $k";
            al = (:center, :bottom))
        lbl(P(k, 1, 1) .+ (dx / 2, 0.10),        # above the arc, so the
            rich(sym("y", "1,2,$k"), up(" ≤ "), up("20"; color = datac));
            al = (:center, :bottom), fs = ls - 1) #   connector clears it
        xc, yc = P(k, 2, 2) .+ (0, (dy - 2r) / 2 + r - 0.02)  # x_{2,2,k}
        poly!(ax, Circle(Point2f(xc, yc), 0.17); color = :transparent,
              strokecolor = datac, strokewidth = 1.6, linestyle = :dash)
        circ[k] = (xc, yc)
    end
    lbl(P(1, 1, 1) .+ (0.08, 0.98), rich(sym("c", "1,1", "p"), val(120)))
    lbl(P(1, 1, 1) .+ (0.08, 0.66),
        rich(sym("x", "1,1,1"), up(" ≤ "), up("26"; color = datac)))
    for i in 2:3                                 # stages with no cost
        lbl(P(1, i, 1) .+ (0.08, (dy - 2r) / 2 + r),
            rich(sym("c", "$i,1", "p"), val(0)))
    end
    xr = P(2, 1, 2)[1] + 1.15                    # the constraints
    (c1x, c1y), (c2x, c2y) = circ[1], circ[2]
    # Product 1's connector passes above product 2's circle, below the
    # arc from its stage 1; product 2's leaves its circle to the right
    if panel == :coupling
        ye = -0.35
        lbl((xr + 1.7, ye + 0.36), "Couples each network";
            al = (:center, :bottom), fs = ls - 1)
        lbl((xr, ye), L"x_{2,2,1} + x_{2,2,2} \;\le\; u_{2,2}";
            fs = ls + 2)
        lbl((xr + 0.95, ye - 0.8), "Continuous\nvariables";
            al = (:center, :top), fs = ls - 1)
        lbl((xr + 2.75, ye - 0.8), "Shared\ncapacity";
            al = (:center, :top), fs = ls - 1)
        connector!(ax, (c1x + 0.15, c1y + 0.08), (4.3, -0.05),
                   (xr - 0.08, ye))
        connector!(ax, (c2x + 0.12, c2y - 0.12), (xr + 0.8, -1.05),
                   (xr + 1.2, ye - 0.26))
    else
        y1, y2, y3 = -0.35, -1.0, -2.05
        lbl((xr, y1), L"x_{2,2,1} \;\le\; u_{2,1}\, z_{2,2,1}";
            fs = ls + 2)
        lbl((xr, y2), L"x_{2,2,2} \;\le\; u_{2,2}\, z_{2,2,2}";
            fs = ls + 2)
        lbl((xr + 1.3, y3 + 0.36), "Links each network";
            al = (:center, :bottom), fs = ls - 1)
        lbl((xr, y3), L"z_{2,2,1} + z_{2,2,2} \;\le\; 1"; fs = ls + 2)
        lbl((xr + 0.8, y3 - 0.42), "Binary\nvariables";
            al = (:center, :top), fs = ls - 1)
        lbl((xr + 2.3, y3 - 0.42), "At most\none";
            al = (:center, :top), fs = ls - 1)
        connector!(ax, (c1x + 0.15, c1y + 0.08), (4.3, -0.05),
                   (xr - 0.08, y1))
        connector!(ax, (c2x + 0.15, c2y - 0.08), (xr - 0.55, y2),
                   (xr - 0.08, y2))
    end
    xlims!(ax, -1.55, xr + 3.75); ylims!(ax, -3.75, 1.72)
    return ax
end
fig = Figure(size = (687, 720))
for (n, (panel, caption)) in enumerate(
        [(:coupling, "(a) Coupled: combined use of a capacity"),
         (:linking, "(b) Linked: exclusive use of a capacity")])
    ax = Axis(fig[2n - 1, 1]; aspect = DataAspect())
    twonets!(ax; panel = panel)
    Label(fig[2n, 1], caption; fontsize = 14, tellwidth = false)
    rowsize!(fig.layout, 2n, Fixed(22))          # the caption below it
end
rowgap!(fig.layout, 4)
fig

# Sec. 2. Coupling constraints
## Model: Coupled products with setups
# Model: coupled products with setups
using JuMP, HiGHS, Logjam
function prodinv_coupled(cᵖ, cˢ, cⁱ, d, UBˣ, u, z̄, LBʸ, UBʸ)
    m, g = size(cᵖ)
    t = size(d, 1)
    model = Model(HiGHS.Optimizer)
    @variable(model, 0 ≤ x[i=1:m, j=1:t, k=1:g] ≤ UBˣ[i,k])
    # Row (c) is the upper bound UBˣ on x, a product's own capacity at a
    # stage, as Lecture 4.3's capacity was a bound; rows (d) and (e) are
    # the bounds LBʸ and UBʸ on y, as there.
    @variable(model, LBʸ[i,j,k] ≤ y[i=1:m, j=1:t+1, k=1:g] ≤ UBʸ[i,j,k])
    @variable(model, 0 ≤ z[i=1:m, j=1:t] ≤ z̄[i,j], Int)
    @objective(model, Min,
        sum(cᵖ[i,k]*x[i,j,k] for i=1:m, j=1:t, k=1:g) +
        sum(cˢ[i]*z[i,j] for i=1:m, j=1:t) +
        sum(cⁱ[i,k]*y[i,j,k] for i=1:m, j=2:t+1, k=1:g))
    @constraint(model, flowbal[i=1:m-1, j=1:t, k=1:g],              # (a)
        -x[i,j,k] + x[i+1,j,k] - y[i,j,k] + y[i,j+1,k] == 0)
    @constraint(model, laststage[j=1:t, k=1:g],                     # (b)
        -x[m,j,k] - y[m,j,k] + y[m,j+1,k] == -d[j,k])
    @constraint(model, coupling[i=1:m, j=1:t; isfinite(u[i])],
    # The condition after the semicolon keeps only the stages with a
    # finite capacity per setup: a stage that shares no capacity has no
    # row (f).
        sum(x[i,j,k] for k=1:g) ≤ u[i]*z[i,j])                      # (f)

    set_silent(model)
    set_attribute(model, "mip_rel_gap", 0.0)
    # HiGHS stops by default once its solution is within 0.01% of the best
    # possible, which can leave a cost a few dollars above the optimum; a
    # gap of 0 asks it to prove the optimum.
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)),
                y = snapvals(value.(y)), z = Int.(snapvals(value.(z))))
    end
    error(termination_status(model))
end

## Example 1: Extraction and staging
# A facility that extracts two different raw materials for
# pharmaceuticals is at a location that requires the extracted material
# to be sent over rough terrain in a truck to a staging station where it
# is then loaded onto a tractor trailer for transport to its final
# destination. A 10-week rolling horizon is used for planning extraction
# and transportation. The materials’ forecasted demand, in tons, is
# given in @tbl-ex1-demand: | Week | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
# 10 | Total | |:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:| |
# Material 1 | 13 | 15 | 21 | 14 | 12 | 11 | 45 | 25 | 48 | 14 | 218 | |
# Material 2 | 11 | 9 | 17 | 15 | 18 | 11 | 6 | 7 | 15 | 20 | 129 | :
# Ex. 1's forecast demand for each material in each week, and its total
# over the ten weeks (ton). {#tbl-ex1-demand .dense .fit} The facility
# can extract up to 26 and 15 tons per week of each material,
# respectively, at a cost of \$120 and \$200 per ton. The annual
# inventory carrying rate is 0.15. The facility can store up to 20 tons
# of each material on site, and unlimited amounts of material can be
# stored at the staging station and the final destination. Currently,
# five tons of the second material is in inventory at the final
# destination and this same amount should be in inventory at the end of
# the planning period. It costs \$200 for a truck to make the roundtrip
# from the facility to the staging station, and it costs \$800 for each
# truckload transported from the station to the final destination. Each
# truck and tractor trailer can carry up to 10 and 25 tons of material,
# respectively, and each load can contain both types of material.
# Determine the amount of each material that should be extracted and
# when it should be transported in order to minimize total costs over
# the planning horizon.
# Code block 2: Ex. 1's two materials through its three stages
red(s) = up(s; color = datac)               # a given value, as in Fig. 1
function ex1net!(ax; r = 0.2, dx = 4.2, dy = 2.2, ls = 15)
    hidedecorations!(ax); hidespines!(ax)
    P(k, i) = ((i - 1) * dx, -(k - 1) * dy)  # material k at stage i
    arc(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]],
                          [q[2] - p[2]]; color = ink, shaftwidth = 1.2,
                          tipwidth = 7, tiplength = 7)
    lbl(p, s; al = (:center, :center), fs = ls) =
        text!(ax, p[1], p[2]; text = s, color = ink, fontsize = fs,
              align = al)
    for (i, s) in enumerate(["Extraction", "Staging station",
                             "Final destination"])
        lbl(P(1, i) .+ (0, 0.95), s; al = (:center, :bottom))
    end
    for (k, cap, cost) in ((1, 26, 120), (2, 15, 200))
        lbl(P(k, 1) .- (2.75, 0), "Material $k"; al = (:right, :center))
        arc(P(k, 1) .- (2.55, 0), P(k, 1) .- (r, 0))     # extraction
        lbl(P(k, 1) .- (1.35, -0.14),
            rich(up("≤ "), red("$cap"), up(" ton/week"));
            al = (:center, :bottom), fs = ls - 2)
        lbl(P(k, 1) .- (1.35, -0.51), rich(red("\$$cost"), up("/ton"));
            al = (:center, :bottom), fs = ls - 2)
        lbl(P(k, 1) .+ (-0.15, -r - 0.12),               # stored on site
            rich(up("store ≤ "), red("20"), up(" ton"));
            al = (:center, :top), fs = ls - 2)
        for i in 2:3                                     # truck, trailer
            arc(P(k, i - 1) .+ (r, 0), P(k, i) .- (r, 0))
        end
        arc(P(k, 3) .+ (r, 0), P(k, 3) .+ (1.25, 0))     # demand
        lbl(P(k, 3) .+ (1.35, 0), "demand"; al = (:left, :center),
            fs = ls - 2)
        for i in 1:3
            poly!(ax, Circle(Point2f(P(k, i)...), r); color = :white,
                  strokecolor = ink, strokewidth = 1.5)
        end
    end
    lbl(P(2, 3) .+ (0.6, r + 0.12),                      # at the end too
        rich(red("5"), up(" ton at start and end"));
        al = (:center, :bottom), fs = ls - 2)
    # The truck and the trailer: a box across both materials' arcs, the
    # capacity they share inside it, the cost of a trip below it
    for (i, what, cap, cost, per) in
            ((2, "Truck", 10, "\$200", " a round trip"),
             (3, "Trailer", 25, "\$800", " a load"))
        xm = (P(1, i - 1)[1] + P(1, i)[1]) / 2
        y1, y2 = P(1, i)[2] + 0.38, P(2, i)[2] - 0.38
        w = 2.0
        poly!(ax, Rect(xm - w/2, y2, w, y1 - y2); color = :transparent,
              strokecolor = datac, strokewidth = 1.6)
        lbl((xm, y1 + 0.1), what; al = (:center, :bottom), fs = ls - 1)
        ym = (P(1, i)[2] + P(2, i)[2]) / 2
        lbl((xm, ym + 0.2), rich(up("≤ "), red("$cap"), up(" ton"));
            fs = ls - 2)
        lbl((xm, ym - 0.2), "both materials"; fs = ls - 3)
        lbl((xm, y2 - 0.1), rich(red(cost), up(per));
            al = (:center, :top), fs = ls - 2)
    end
    xlims!(ax, -4.6, 2dx + 2.6); ylims!(ax, -dy - 0.85, 1.45)
    return ax
end
fig = Figure(size = (687, 300))
ex1net!(Axis(fig[1, 1]; aspect = DataAspect()))
fig

# Example 1: Extraction and staging
## Example 1(a): Ten-week plan
# Determine the ten-week plan and its cost with @mdl-prodinv-coupled,
# after a lower bound on the cost and the most setups in a week by hand.
# Code block 3: Ex. 1's data
d = [13 15 21 14 12 11 45 25 48 14      # demand in week j for material k
     11  9 17 15 18 11  6  7 15 20]'    #   (ton)
t = size(d, 1)                          # number of weeks
cᵖ = [120 200; 0 0; 0 0]                # extract, truck, trailer ($/ton)
UBˣ = [26 15; Inf Inf; Inf Inf]         # extraction capacity (ton/week)
cˢ = [0, 200, 800]                      # cost per truck, per trailer ($)
u = [Inf, 10, 25]                       # per truck, per trailer (ton)
m, g = size(cᵖ)                         # stages, materials
h = 0.15/52                             # weekly carrying rate (1/week)
cⁱ = cumsum(cᵖ .+ cˢ./u, dims = 1)*h    # inventory cost ($/ton-week)
y⁰ = [0 0; 0 0; 0 5]                    # initial inventory (ton)
yᵗ⁺¹ = [0 0; 0 0; 0 5]                  # final inventory (ton)
uʸ = [20 20; Inf Inf; Inf Inf]          # storage capacity (ton)
LBʸ = [reshape(y⁰, m, 1, g) zeros(m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)]
UBʸ = hcat(reshape(y⁰, m, 1, g), repeat(reshape(uʸ, m, 1, g), 1, t-1),
           reshape(yᵗ⁺¹, m, 1, g));
# Code block 4: a lower bound on the cost, and the most setups
ship = sum(d) - sum(y⁰) + sum(yᵗ⁺¹)            # tons to ship
@show min_loads = ceil.(Int, ship ./ u[2:3])   # fewest trucks, trailers
max_loads = min_loads                          # the most in any one week
z̄ = [zeros(Int, 1, t); repeat(max_loads, 1, t)] # none to extract
LB = sum(cᵖ[1, :] .* vec(sum(d, dims = 1))) + sum(cˢ[2:3] .* min_loads)
# Code block 5: Ex. 1 solved with prodinv_coupled
TCᵒ, xᵒ, yᵒ, zᵒ = prodinv_coupled(cᵖ, cˢ, cⁱ, d, UBˣ, u, z̄, LBʸ, UBʸ)
@show TCᵒ
TCᵖ = sum(reshape(cᵖ, m, 1, g) .* xᵒ)            # production
TCⁱ = sum(reshape(cⁱ, m, 1, g) .* yᵒ[:, 2:end, :])  # inventory
TCˢ = sum(cˢ .* zᵒ)                               # trucks and trailers
@show TCᵖ
@show TCⁱ
@show TCˢ
prt([zᵒ[2:3, :]; d'];
    rows = ["Trucks", "Trailers", "Demand 1", "Demand 2"],
    cols = string.(1:t), row_title = "Week")

## Example 1(b): Cost of a given plan by hand
# Using some different data (as noted below, otherwise use the data
# given in Ex. 1) and only a three-week planning horizon, determine the
# total production, inventory, and transport cost over the horizon. The
# forecasted demand for both materials is 20, 10, 45 and 12, 25, 5 tons,
# respectively. It costs \$600 and \$400 to extract each ton of material
# at the facility, and the annual inventory carrying rate is 0.5. The
# facility can extract up to 30 and 20 tons per week of each material,
# respectively. Currently, 20 tons of the second material is in
# inventory at the final destination. A different amount of material can
# be in inventory at the end of the planning period. For each material,
# each period, 30, 30, 30 and 16, 17, 17 tons, respectively, are
# produced; 30, 10, 50 and 0, 20, 30 tons are transported to the staging
# station; and 22, 8, 60 and 0, 17, 33 tons are transported to the final
# destination.
# Ex. 1(b)'s plan on each material's network: each item's network, stage
# i a row and period j a column, the plan's flows, the demand and the
# inventory at the start in red, and in blue the inventory each node
# carries out, what came in less what went on; given the capacity cap of
# each shared vehicle, the items' tons on it in each period and the loads
# that carry them, below the networks
flowc = colorant"#1f5fa8"                        # a value determined
blue(s) = up(s; color = flowc)
function plannets(X, d, y⁰; nodes, arcs = nothing, item = "Material",
                  period = "Week", cap = nothing, vehicles = nothing,
                  dx = 2.3, dy = 1.0, r = 0.15, ls = 14, w = 640)
    m, t, g = size(X)
    Y = zeros(m, t + 1, g)                       # inventory into period j
    Y[:, 1, :] = y⁰
    for k in 1:g, j in 1:t, i in 1:m             # flow balance
        on = i < m ? X[i+1, j, k] : d[j, k]
        Y[i, j+1, k] = Y[i, j, k] + X[i, j, k] - on
    end
    ℓs, ℓd, ℓi = 0.55, 0.45, 0.75                # supply, demand, end arcs
    H = 2dy + ℓs + ℓd + 1.65                     # a network's height
    xl = -ℓi - 0.55                              # the names, right-aligned
    yc = -g * H + ℓs + 0.1                       # the loads, if any
    x0, x1 = xl - 1.2, (t - 1) * dx + ℓi + 1.25
    y0 = cap === nothing ? -(g - 1) * H - 2dy - ℓd - r - 0.85 : yc - 2.25
    y1 = ℓs + 0.55
    fig = Figure(size = (w, round(Int, w * (y1 - y0) / (x1 - x0))),
                 figure_padding = 4)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    P(k, i, j) = ((j - 1) * dx, -(k - 1) * H - (i - 1) * dy)
    arc(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]],
                          [q[2] - p[2]]; color = ink, shaftwidth = 1.1,
                          tipwidth = 6.5, tiplength = 6.5)
    tx(p, s, al; fs = ls) = text!(ax, p[1], p[2]; text = s, color = ink,
                                  fontsize = fs, align = al)
    function head(y)                             # each period, above
        for j in 1:t
            tx(((j - 1) * dx, y), "$period $j", (:center, :bottom);
               fs = ls - 1)
        end
    end
    under(y, s) = tx(((t - 1) * dx / 2, y), s, (:center, :top))  # caption
    v(n) = string(round(Int, n))
    for k in 1:g
        xk, yk = P(k, 1, 1)
        head(yk + ℓs + 0.22)
        under(yk - 2dy - r - ℓd - 0.42, "($('a' + k - 1)) $item $k")
        for i in 1:m
            tx((xl, P(k, i, 1)[2]), nodes[i], (:right, :center))
        end
        if arcs !== nothing                      # what each arc carries
            for (s, y) in zip(arcs, (yk + ℓs / 2 + r / 2, yk - dy / 2,
                                     yk - 1.5dy, yk - 2dy - ℓd / 2 - r / 2))
                tx((xl, y), s, (:right, :center); fs = ls - 2)
            end
        end
        for j in 1:t                             # the plan's flows
            x, y = P(k, 1, j)
            arc((x, y + ℓs + r), (x, y + r))
            tx((x + 0.08, y + ℓs / 2 + r / 2), red(v(X[1, j, k])),
               (:left, :center))
            for i in 2:m
                p, q = P(k, i - 1, j), P(k, i, j)
                arc(p .- (0, r), q .+ (0, r))
                tx((p[1] + 0.08, (p[2] + q[2]) / 2), red(v(X[i, j, k])),
                   (:left, :center))
            end
            x, y = P(k, m, j)                    # demand
            arc((x, y - r), (x, y - r - ℓd))
            tx((x, y - r - ℓd - 0.05), red(v(d[j, k])), (:center, :top))
        end
        for i in 1:m                             # inventory
            x, y = P(k, i, 1)
            arc((x - ℓi, y), (x - r, y))
            tx((x - ℓi - 0.08, y), red(v(Y[i, 1, k])), (:right, :center))
            for j in 1:t-1
                p, q = P(k, i, j) .+ (r, 0), P(k, i, j + 1) .- (r, 0)
                arc(p, q)
                tx(((p[1] + q[1]) / 2, y - 0.07), blue(v(Y[i, j+1, k])),
                   (:center, :top))
            end
            x, y = P(k, i, t)
            arc((x + r, y), (x + ℓi, y))
            tx((x + ℓi + 0.08, y), blue(v(Y[i, t+1, k])), (:left, :center))
        end
        for i in 1:m, j in 1:t                   # nodes, over the arcs
            poly!(ax, Circle(Point2f(P(k, i, j)...), r); color = :white,
                  strokecolor = ink, strokewidth = 1.4)
        end
    end
    if cap !== nothing                           # stage n + 1's vehicles
        head(yc + 0.22)
        under(yc - 1.85, "($('a' + g)) Loads")
        for (n, s) in enumerate(vehicles)
            y = yc - 0.2 - (n - 1) * 0.95
            tx((xl, y - 0.2), titlecase(s), (:right, :center))
            z = 0
            for j in 1:t
                x = (j - 1) * dx
                tons = sum(X[n+1, j, :])
                zj = ceil(Int, tons / cap[n])
                z += zj
                add = [k == 1 ? red(v(X[n+1, j, k])) :
                       rich(up(" + "), red(v(X[n+1, j, k]))) for k in 1:g]
                tx((x, y), rich(add..., up(" = "), blue(v(tons))),
                   (:center, :center))
                ld = rich(up("⌈"), blue(v(tons)), up("/"), red(v(cap[n])),
                          up("⌉ = "), blue("$zj"))
                tx((x, y - 0.4), ld, (:center, :center))
            end
            tx(((t - 1) * dx + ℓi + 0.08, y - 0.2), rich(blue("$z"), " $s"),
               (:left, :center))
        end
    end
    xlims!(ax, x0, x1); ylims!(ax, y0, y1)
    return fig
end
plannets(cat([30 30 30; 30 10 50; 22 8 60],     # x[i,j,k]: stage i,
             [16 17 17; 0 20 30; 0 17 33];      #   week j, material k
             dims = 3),
         [20 12; 10 25; 45 5],                  # demand d[j,k] (ton)
         [0 0; 0 0; 0 20];                      # inventory at the start
         nodes = ["Site", "Station", "Destination"],
         arcs = ["extract", "truck", "trailer", "demand"],
         cap = u[2:3], vehicles = ["trucks", "trailers"])

## Example 1(c): Costs of the plan with code
# Compute part (b)'s three costs from the plan with code, and check them
# against the answers published with the problem.
# Code block 6: Ex. 1(b)'s plan, costed
X = cat([30 30 30; 30 10 50; 22 8 60],   # x[i,j,k]: stage i, week j,
        [16 17 17; 0 20 30; 0 17 33];    #   material k (ton)
        dims = 3)
Db = [20 12; 10 25; 45 5]                # demand in week j for material k
Y = zeros(3, 4, 2)                       # inventory, by flow balance
Y[3, 1, 2] = 20
for k in 1:2, j in 1:3
    for i in 1:2
        Y[i, j+1, k] = Y[i, j, k] + X[i, j, k] - X[i+1, j, k]
    end
    Y[3, j+1, k] = Y[3, j, k] + X[3, j, k] - Db[j, k]
end
loads = ceil.(Int, dropdims(sum(X, dims = 3), dims = 3)[2:3, :] ./ u[2:3])
cᵖb = [600 400; 0 0; 0 0]
cⁱb = cumsum(cᵖb .+ cˢ./u, dims = 1)*0.5/52
PC = sum(reshape(cᵖb, 3, 1, 2) .* X)
IC = sum(reshape(cⁱb, 3, 1, 2) .* Y[:, 2:end, :])
TrC = sum(cˢ[2:3] .* loads)
@assert (PC, round(IC, digits = 2), TrC) == (74000, 609.38, 7600)
# @assert stops the script with an error unless the expression after it is
# true. A run that gets past this line has confirmed that the three costs
# computed from the plan, the inventory cost rounded to the cent, are the
# answers published with the problem, \$74,000, \$609.38 and \$7,600.
@show PC
@show IC
@show TrC
prt(loads; rows = ["Trucks", "Trailers"], cols = string.(1:3),
    row_title = "Week")                  # loads in each week

# Sec. 3. Linking constraints
## Model: Exclusive shared resources
# Model: exclusive shared resources
function prodinv_excl(cᵖ, cⁱ, d, u, LBʸ, UBʸ)
    m, g = size(u)
    t = size(d, 1)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[i=1:m, j=1:t, k=1:g] ≥ 0)
    @variable(model, LBʸ[i,j,k] ≤ y[i=1:m, j=1:t+1, k=1:g] ≤ UBʸ[i,j,k])
    @variable(model, z[i=1:m, j=1:t, k=1:g], Bin)
    @objective(model, Min,
        sum(cᵖ[i,k]*x[i,j,k] for i=1:m, j=1:t, k=1:g) +
        sum(cⁱ[i,k]*y[i,j,k] for i=1:m, j=2:t+1, k=1:g))
    @constraint(model, flowbal[i=1:m-1, j=1:t, k=1:g],              # (a)
        -x[i,j,k] + x[i+1,j,k] - y[i,j,k] + y[i,j+1,k] == 0)
    @constraint(model, laststage[j=1:t, k=1:g],                     # (b)
        -x[m,j,k] - y[m,j,k] + y[m,j+1,k] == -d[j,k])
    @constraint(model, capacity[i=1:m, j=1:t, k=1:g],               # (c)
        x[i,j,k] ≤ u[i,k]*z[i,j,k])
    @constraint(model, linking[i=1:m, j=1:t],                       # (f)
        sum(z[i,j,k] for k=1:g) ≤ 1)

    set_silent(model)
    set_attribute(model, "mip_rel_gap", 0.0)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)),
                y = snapvals(value.(y)), z = Int.(snapvals(value.(z))))
    end
    error(termination_status(model))
end

## Example 2: Plant shared by two products
# A plant can use a three-stage process to produce two products. A
# 13-week rolling horizon is used for planning production. The products’
# forecasted demand, in tons, is given in @tbl-ex2-demand: | Week | 1 |
# 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | Total |
# |:--|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:| |
# Product 1 | 6 | 40 | 33 | 24 | 29 | 24 | 16 | 13 | 14 | 17 | 18 | 43 |
# 25 | 302 | | Product 2 | 17 | 14 | 17 | 4 | 7 | 10 | 12 | 18 | 13 | 23
# | 8 | 17 | 3 | 163 | : Ex. 2's forecast demand in each period, each
# product, and its total over the 13 weeks (ton). {#tbl-ex2-demand
# .dense .fit} The plant can produce up to 60, 55, and 50 and 50, 45,
# and 35 tons per week for each stage of each product, respectively; has
# production costs of \$12, \$75, and \$35 and \$20, \$130, and \$60 per
# ton for each stage of each product, respectively. The annual inventory
# carrying rate is 0.3. The first two weeks' demand for the second
# product is being held as finished product inventory. The final
# inventory for all stages of both products is zero. Determine the
# amount of each product that should be produced to minimize total costs
# over the planning horizon.
# Code block 7: Ex. 2's data, and the bounds on inventory
# demand in each period, each product (ton)
d = [6 40 33 24 29 24 16 13 14 17 18 43 25
    17 14 17  4  7 10 12 18 13 23  8 17  3]'
t = size(d, 1)                        # number of periods
# capacity of each stage for each product (ton)
u = [60 50; 55 45; 50 35]
m = size(u, 1)                        # number of production stages
g = size(u, 2)                        # number of products
# production cost for each stage, each product ($/ton)
cᵖ = [12 20; 75 130; 35 60]
# weekly inventory carrying rate (1/wk)
@show h = 0.3/(365.25/7)
# inventory cost for each stage, each product ($/ton)
cⁱ = cumsum(cᵖ, dims=1)*h
# initial inventory of each stage, each product (ton)
@show y⁰ = [0 0; 0 0; 0 sum(d[[1 2], 2])]
# final inventory of each stage for each product (ton)
yᵗ⁺¹ = zeros(m, g)
# convert y⁰ and yᵗ⁺¹ from 2D (m x g) to 3D (m x t x g)
LBʸ = [reshape(y⁰, m, 1, g) zeros(m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)]
UBʸ = [reshape(y⁰, m, 1, g) fill(Inf, m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)];
# Code block 8: Ex. 2 solved with prodinv_excl
TCᵒ, xᵒ, yᵒ, zᵒ = prodinv_excl(cᵖ, cⁱ, d, u, LBʸ, UBʸ)
@show TCᵒ;
# Code block 9: the plan for each product
stages = string.("Stage ", 1:m)                 # the rows of each table
for k in 1:g
    println()                                   # a blank line above each
    prt([xᵒ[:,:,k]; d[:,k]']; rows = [stages; "Demand"],
        cols = string.(1:t), row_title = "Week",
        title = "Product $k: production level and demand")
    println()
    prt(yᵒ[:,:,k]; rows = stages, cols = string.(1:t+1),
        row_title = "Week", title = "Product $k: inventory level")
    println()
    prt(zᵒ[:,:,k]; rows = stages, cols = string.(1:t),
        row_title = "Week", title = "Product $k: set up")
end
# Code block 10: the constraint matrix by blocks, a block per product
# Product k's block spans x in [(k-1)W, kW] and y in [-kH, -(k-1)H];
# its columns are x, y, (v,) z at xc, yc, vc, zc, its rows top down
ink, boxc = colorant"#252525", colorant"#8c8c8c"
dashc = colorant"#969696"
mi = Makie.MathTeXEngine.texfont(:italic)
mr = Makie.MathTeXEngine.texfont(:math)
mb = Makie.MathTeXEngine.texfont(:bold)
it(s) = rich(s; font = mi)                        # a symbol, in italics
up(s) = rich(s; font = mr)                        # digits, operators
csym(p) = rich(it("c"), superscript(it(p)))       # c with superscript p
zsub(k) = rich(it("z"), subscript(up(k)))         # z with subscript k
function blocks!(ax; switch = false, W = 7.0, ls = 13, ms = 15)
    hidedecorations!(ax); hidespines!(ax)
    xc, yc, vc, zc = 1.15, 2.6, 3.65, 5.45        # column centres
    fb, cap, sw = (-0.10, -1.05), (-1.15, -1.95), (-2.05, -2.85)
    H = switch ? 2.95 : 2.05                      # block height
    L = 0.62                                      # linking-row height
    rect(x0, x1, y0, y1; c = boxc, w = 1.0) =
        poly!(ax, Rect(x0, y1, x1 - x0, y0 - y1); color = :transparent,
              strokecolor = c, strokewidth = w)
    dashed(x0, x1, y0, y1) =
        lines!(ax, [x0, x1, x1, x0, x0], [y0, y0, y1, y1, y0];
               color = dashc, linewidth = 1.2, linestyle = :dash)
    lbl(x, y, s; fs = ms, al = (:center, :center), rot = 0.0) =
        text!(ax, x, y; text = s, fontsize = fs, color = ink, align = al,
              rotation = rot)
    top(b) = b[1] - 0.27                          # a box's two lines:
    bot(b) = b[2] + 0.29                          #   name over variables
    dashed(W, 2W, 0, -H); lbl(1.5W, -0.5H, up("0"); fs = ms + 2)
    dashed(0, W, -H, -2H); lbl(0.5W, -1.5H, up("0"); fs = ms + 2)
    for k in 1:2
        ox, oy = (k - 1) * W, -(k - 1) * H        # the block's corner
        rect(ox, ox + W, oy, oy - H; c = ink, w = 1.6)
        lbl(ox + xc, 0.36, csym("p")); lbl(ox + yc, 0.36, csym("i"))
        switch && lbl(ox + vc, 0.36, csym("w"))   # the objective's
        lbl(ox + zc, 0.36, rich("0"; font = mb))  #   coefficients
        lbl(ox - 0.32, oy - H / 2, "Product $k"; fs = ls + 1,
            rot = π / 2)
        b = oy .+ fb                              # rows (a) and (b)
        rect(ox + 0.10, ox + 3.60, b...)
        lbl(ox + 1.85, top(b), "Flow balance (a), (b)"; fs = ls)
        lbl(ox + xc, bot(b), it("x")); lbl(ox + yc, bot(b), it("y"))
        b = oy .+ cap                             # row (c)
        rect(ox + 0.10, ox + 2.20, b...)
        lbl(ox + xc, top(b), "Capacity (c)"; fs = ls)
        lbl(ox + xc, bot(b), it("x"))
        rect(ox + zc - 0.40, ox + zc + 0.40, b...)
        lbl(ox + zc, top(b), rich(up("−"), it("u")))
        lbl(ox + zc, bot(b), it("z"))
        lbl(ox + zc + 0.55, sum(b) / 2, up("≤ 0"); al = (:left, :center))
        if switch                                 # row (g)
            b = oy .+ sw
            rect(ox + 2.40, ox + 4.90, b...)
            lbl(ox + vc, top(b), "Switchover (g)"; fs = ls)
            lbl(ox + vc, bot(b), it("v"))
            rect(ox + zc - 0.40, ox + zc + 0.40, b...)
            lbl(ox + zc, top(b), up("1")); lbl(ox + zc, bot(b), it("z"))
            lbl(ox + zc + 0.55, sum(b) / 2, up("≤ 0");
                al = (:left, :center))
        end
    end
    ly0, ly1 = -2H, -2H - L                       # row (f), across both,
    poly!(ax, Rect(0, ly1, 2W, L); color = :white, strokecolor = datac,
          strokewidth = 1.6)                      #   outlined in red
    ym = (ly0 + ly1) / 2
    lbl(0.15, ym, "Linking (f)"; fs = ls, al = (:left, :center))
    lbl(zc, ym, zsub("1")); lbl(W, ym, up("+"))
    lbl(2W - zc, ym, zsub("2"))
    lbl(2W + 0.12, ym, up("≤ 1"); al = (:left, :center))
    limits!(ax, -0.70, 2W + 0.95, ly1 - 0.12, 0.72)
    return nothing
end
fig = Figure(size = (680, 252), figure_padding = 4)
blocks!(Axis(fig[1, 1]; aspect = DataAspect()))
fig
size(cᵖ), size(xᵒ)   # Code block 11: cᵖ to reshape to (3, 1, 2) for xᵒ
# Code block 12: the production and inventory costs
# Reshaped cᵖ broadcast for multiplication with xᵒ
TCᵖ = sum((reshape(cᵖ,m,1,g).*xᵒ)[:])
TCⁱ = sum((reshape(cⁱ,m,1,g).*yᵒ[:,2:end,:])[:])  # First period excluded
TCᵖ, TCⁱ
TCᵖ + TCⁱ, TCᵒ   # Code block 13: their sum, and the total
# Code block 14: Ex. 2 without linking, each product on its own
TCⁿ = prodinv_coupled(cᵖ, zeros(m), cⁱ, d, u, fill(Inf, m),
                      zeros(Int, m, t), LBʸ, UBʸ).TC
TCⁿ, TCᵒ

# Sec. 4. Switchover costs
## Model: Switchover costs
# Model: switchover costs
function prodinv_switch(cᵖ, cʷ, cⁱ, d, u, z⁰, LBʸ, UBʸ)
    m, g = size(u)
    t = size(d, 1)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[i=1:m, j=1:t, k=1:g] ≥ 0)
    @variable(model, LBʸ[i,j,k] ≤ y[i=1:m, j=1:t+1, k=1:g] ≤ UBʸ[i,j,k])
    @variable(model, z[i=1:m, j=1:t, k=1:g], Bin)
    @variable(model, v[i=1:m, j=1:t, k=1:g], Bin)
    @objective(model, Min,
        sum(cᵖ[i,k]*x[i,j,k] for i=1:m, j=1:t, k=1:g) +
        sum(cⁱ[i,k]*y[i,j,k] for i=1:m, j=2:t+1, k=1:g) +
        sum(cʷ[i,k]*v[i,j,k] for i=1:m, j=1:t, k=1:g))
    @constraint(model, flowbal[i=1:m-1, j=1:t, k=1:g],              # (a)
        -x[i,j,k] + x[i+1,j,k] - y[i,j,k] + y[i,j+1,k] == 0)
    @constraint(model, laststage[j=1:t, k=1:g],                     # (b)
        -x[m,j,k] - y[m,j,k] + y[m,j+1,k] == -d[j,k])
    @constraint(model, capacity[i=1:m, j=1:t, k=1:g],               # (c)
        x[i,j,k] ≤ u[i,k]*z[i,j,k])
    @constraint(model, linking[i=1:m, j=1:t],                       # (f)
        sum(z[i,j,k] for k=1:g) ≤ 1)
    @constraint(model, switchfirst[i=1:m, k=1:g],                   # (g)
        -v[i,1,k] + z[i,1,k] ≤ z⁰[i,k])
        # In period 1 there is no period before, so row (g) compares the
        # setup with z⁰, the setup the stage has before the horizon
        # starts.
    @constraint(model, switchover[i=1:m, j=2:t, k=1:g],             # (g)
        -v[i,j,k] + z[i,j,k] - z[i,j-1,k] ≤ 0)

    set_silent(model)
    set_attribute(model, "mip_rel_gap", 0.0)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)),
                y = snapvals(value.(y)), z = Int.(snapvals(value.(z))),
                v = Int.(snapvals(value.(v))))
    end
    error(termination_status(model))
end

## Sec. 4. Switchover costs
# Code block 15: the truth table of row (g)
# columns: vⱼ, zⱼ, zⱼ₋₁, the row's left side, and whether it is ≤ 0
T = [0 0 0; 0 0 1; 0 1 0; 0 1 1; 1 0 0; 1 0 1; 1 1 0; 1 1 1]
TT(f) = hcat(T, [f(row...) for row in eachrow(T)],
# hcat sets the three matrices side by side: the eight combinations, the
# row's left side for each, and whether it is at most zero. Written inside
# [ ] over two lines, the line break would start a new row instead.
             [f(row...) .<= 0 for row in eachrow(T)])
TT((vⱼ, zⱼ, zⱼ₋₁) -> -vⱼ + zⱼ - zⱼ₋₁)

## Example 3: Shared plant with switchovers
# The problem is the same as Ex. 2, except that there is a switchover
# cost associated with switching the production of one of the products
# on a resource to the other product. There is no switchover cost in
# subsequent periods if the same product continues to be produced on the
# same resource. The costs per switchover for each stage of each product
# are \$400, \$90, and \$50, and \$600, \$110, and \$70, respectively.
# The plant is currently set up to produce each stage of the first
# product. Determine the amount of each product that should be produced
# to minimize total costs over the planning horizon.
# Code block 16: Ex. 3's data, the bounds and the initial setup
# demand in each period, each product (ton)
d = [6 40 33 24 29 24 16 13 14 17 18 43 25
    17 14 17  4  7 10 12 18 13 23  8 17  3]'
t = size(d, 1)                        # number of periods
# capacity of each stage for each product (ton)
u = [60 50; 55 45; 50 35]
m = size(u, 1)                        # number of production stages
g = size(u, 2)                        # number of products
# production cost for each stage, each product ($/ton)
cᵖ = [12 20; 75 130; 35 60]
# weekly inventory carrying rate (1/wk)
@show h = 0.3/(365.25/7)
# inventory cost for each stage, each product ($/ton)
cⁱ = cumsum(cᵖ, dims=1)*h
# switchover cost for each stage for each product ($)
cʷ = [400 600; 90 110; 50 70]
# initial inventory of each stage, each product (ton)
@show y⁰ = [0 0; 0 0; 0 sum(d[[1 2], 2])]
# final inventory of each stage for each product (ton)
yᵗ⁺¹ = zeros(m, g)
# initial set up at each stage for each product
z⁰ = [1 0; 1 0; 1 0]
# convert y⁰ and yᵗ⁺¹ from 2D (m x g) to 3D (m x t x g)
LBʸ = [reshape(y⁰, m, 1, g) zeros(m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)]
UBʸ = [reshape(y⁰, m, 1, g) fill(Inf, m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)];
# Code block 17: Ex. 3 solved with prodinv_switch
TCᵒ, xᵒ, yᵒ, zᵒ, vᵒ = prodinv_switch(cᵖ, cʷ, cⁱ, d, u, z⁰, LBʸ, UBʸ)
@show TCᵒ;
# Code block 18: the plan for each product
for k in 1:g
    println()                                   # a blank line above each
    prt([xᵒ[:,:,k]; d[:,k]']; rows = [stages; "Demand"],
        cols = string.(1:t), row_title = "Week",
        title = "Product $k: production level and demand")
    println()
    prt(yᵒ[:,:,k]; rows = stages, cols = string.(1:t+1),
        row_title = "Week", title = "Product $k: inventory level")
    println()
    prt(zᵒ[:,:,k]; rows = stages, cols = string.(1:t),
        row_title = "Week", title = "Product $k: set up")
    println()
    prt(vᵒ[:,:,k]; rows = stages, cols = string.(1:t),
        row_title = "Week", title = "Product $k: switchovers")
end
# Code block 19: switchovers at each stage
vec(sum(vᵒ, dims = (2, 3)))
# Summing over dimensions 2 and 3, the periods and the products, leaves
# one count for each stage; vec turns the $3 \times 1 \times 1$ array that
# remains into a vector.
# Code block 20: what each stage is set up for, Ex. 2 and Ex. 3
pc = [colorant"#cfe3f5", colorant"#f8dcc2"]    # product 1, product 2
function setups!(ax, x, z, title)
    hidedecorations!(ax); hidespines!(ax)
    m, t, g = size(x)
    for i in 1:m, j in 1:t                    # stage i in week j
        k = findfirst(==(1), z[i, j, :])      # product set up for
        poly!(ax, Rect(j - 1, -i, 1, 1); strokecolor = :white,
              color = isnothing(k) ? :white : pc[k], strokewidth = 2)
        s = sum(x[i, j, :])                   # tons made
        s > 0 && text!(ax, j - 0.5, -i + 0.5; text = "$(round(Int, s))",
                       align = (:center, :center), fontsize = 12,
                       color = ink)
    end
    for i in 1:m
        text!(ax, -0.15, -i + 0.5; text = "Stage $i", fontsize = 13,
              align = (:right, :center), color = ink)
    end
    for j in 1:t
        text!(ax, j - 0.5, 0.1; text = "$j", fontsize = 11,
              align = (:center, :bottom), color = ink)
    end
    text!(ax, t / 2, 0.75; text = title, fontsize = 14,
          align = (:center, :bottom), color = ink)
    xlims!(ax, -1.6, t + 0.1); ylims!(ax, -m - 0.1, 1.45)
    return ax
end
r2 = prodinv_excl(cᵖ, cⁱ, d, u, LBʸ, UBʸ)     # Ex. 2's plan, again
fig = Figure(size = (687, 330), figure_padding = 4)
setups!(Axis(fig[1, 1]; aspect = DataAspect()), r2.x, r2.z,
        "(a) Ex. 2: no switchover cost")
setups!(Axis(fig[2, 1]; aspect = DataAspect()), xᵒ, zᵒ,
        "(b) Ex. 3: with switchover costs")
Legend(fig[3, 1], [PolyElement(color = c) for c in pc],
       ["Set up for product 1", "Set up for product 2"];
       orientation = :horizontal, framevisible = false, labelsize = 12)
rowgap!(fig.layout, 2)
fig
# Code block 21: Ex. 3's constraint matrix by blocks
fig = Figure(size = (680, 330), figure_padding = 4)
blocks!(Axis(fig[1, 1]; aspect = DataAspect()); switch = true)
fig
# Code block 22: the three costs, their sum, and the total
# Reshaped cᵖ broadcast for multiplication with xᵒ
@show TCᵖ = sum((reshape(cᵖ,m,1,g).*xᵒ)[:])
# First period excluded
@show TCⁱ = sum((reshape(cⁱ,m,1,g).*yᵒ[:,2:end,:])[:])
@show TCʷ = sum((reshape(cʷ,m,1,g).*vᵒ)[:])
@show TCᵖ + TCⁱ + TCʷ
@show TCᵒ;
# Code block 23: switchover costs at zero, against Ex. 2
TC0 = prodinv_switch(cᵖ, zeros(m, g), cⁱ, d, u, z⁰, LBʸ, UBʸ).TC
TC2 = prodinv_excl(cᵖ, cⁱ, d, u, LBʸ, UBʸ).TC
# Ex. 3's TCᵒ replaced Ex. 2's, so Ex. 2 is solved again for the
# comparison; .TC takes the one field of the named tuple that is wanted.
TC0, TC2
# Code block 24: the statement's $60 at stage 3 for product 2
cʷ60 = [400 600; 90 110; 50 60]
r60 = prodinv_switch(cᵖ, cʷ60, cⁱ, d, u, z⁰, LBʸ, UBʸ)
@show r60.TC
@show round(TCᵒ - r60.TC, digits = 2)
@show r60.x == xᵒ;

# Example 4: Switchovers in a given plan
## Example 4(a): Switchovers by hand
# Determine the switchovers at each stage, and their cost, from the
# setup indicators.
# Ex. 4's setups and the switchovers they make: each stage's setup in each
# month, the start first, the product's number in it, on white with no
# fill (LREG-04); row (g) at least cost makes a switchover where a stage
# is set up for a product it was not set up for the month before, outlined
# in blue with its cost, each stage's total at the right
function switchfig(z, z⁰, cʷ; w = 640, ls = 14)
    m, t, g = size(z)
    Z = cat(reshape(z⁰, m, 1, g), z; dims = 2)  # column 1 is the start
    V = max.(Z[:, 2:end, :] - Z[:, 1:end-1, :], 0)   # row (g)
    fig = Figure(size = (w, round(Int, w * (m + 1.1) / (t + 4.6))),
                 figure_padding = 4)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    tx(x, y, s; fs = ls, al = (:center, :center), c = ink) =
        text!(ax, x, y; text = s, fontsize = fs, align = al, color = c)
    for i in 1:m, c in 0:t                       # stage i, month c
        y = -i
        k = findfirst(==(1), Z[i, c+1, :])       # product set up for
        sw = c > 0 && k !== nothing && V[i, c, k] == 1
        poly!(ax, Rect(c + 0.06, y + 0.06, 0.88, 0.88); color = :white,
              strokecolor = sw ? flowc : ink, strokewidth = sw ? 2.5 : 0.8)
        k === nothing && continue
        tx(c + 0.5, y + (sw ? 0.64 : 0.5), "$k"; c = datac)   # given
        sw && text!(ax, c + 0.5, y + 0.3;
                    text = rich("\$", commas(cʷ[i, k]); color = flowc),
                    fontsize = ls - 2, align = (:center, :center))
    end
    for i in 1:m
        tx(-0.15, -i + 0.5, "Stage $i"; al = (:right, :center))
        cost = sum(V[i, j, k] * cʷ[i, k] for j in 1:t, k in 1:g)
        text!(ax, t + 1.2, -i + 0.5; text = rich("\$", commas(cost);
              color = flowc), fontsize = ls, align = (:left, :center))
    end
    tx(0.5, 0.15, "Start"; fs = ls - 1, al = (:center, :bottom))
    for c in 1:t
        tx(c + 0.5, 0.15, "$c"; fs = ls - 1, al = (:center, :bottom))
    end
    tx((t + 2) / 2, 0.6, "Month"; fs = ls - 1, al = (:center, :bottom))
    tx(t + 1.2, 0.15, "Cost"; fs = ls - 1, al = (:left, :bottom))
    xlims!(ax, -1.6, t + 3.0); ylims!(ax, -m - 0.05, 1.0)
    return fig
end
switchfig(cat([1 0 0 1 1 1; 1 1 0 1 1 0; 1 1 0 1 1 0],     # z[i,j,1]
              [0 1 1 0 0 0; 0 0 1 0 0 1; 0 0 1 0 0 1];     # z[i,j,2]
              dims = 3),
          [1 0; 1 0; 1 0],                                 # z⁰ at the start
          [2800 3200; 800 600; 400 300])                   # cʷ ($)

## Example 4(b): Cost of the plan by hand
# Determine the plan's production, inventory and switchover costs, and
# its total cost, by hand.
plannets(cat([45 0 0 20 40 0; 20 25 0 20 40 0; 20 25 0 20 40 0],
             [0 20 35 0 0 0; 0 0 40 0 0 15; 0 0 40 0 0 15]; dims = 3),
         [20 10; 10 15; 15 25; 20 10; 15 5; 25 15],   # demand d[j,k]
         [0 0; 0 0; 0 25];                            # at the start
         nodes = string.("Stage ", 1:3), item = "Product",
         period = "Month", dx = 1.35)

## Example 4(c): Plan solved with the model
# Determine the plan that minimizes the total cost, and that cost, with
# the implementation of @mdl-prodinv-switch.
# Code block 25: Ex. 4's data
# capacity of each stage for each product (ton)
u = [50 35; 60 45; 70 55]
d = [20 10 15 20 15 25
     10 15 25 10  5 15]'              # demand (ton)
t = size(d, 1)                        # number of periods
m = size(u, 1)                        # number of production stages
g = size(u, 2)                        # number of products
cᵖ = [100 200; 800 1200; 400 800]     # production cost ($/ton)
cⁱ = cumsum(cᵖ, dims=1)*0.3/12        # inventory cost ($/ton-month)
cʷ = [2800 3200; 800 600; 400 300]    # switchover cost ($)
y⁰ = [0 0; 0 0; 0 25]                 # initial inventory (ton)
yᵗ⁺¹ = zeros(m, g)                    # final inventory (ton)
# initial set up at each stage for each product
z⁰ = [1 0; 1 0; 1 0]
LBʸ = [reshape(y⁰, m, 1, g) zeros(m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)]
UBʸ = [reshape(y⁰, m, 1, g) fill(Inf, m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)];
# Code block 26: Ex. 4 solved with prodinv_switch
r4 = prodinv_switch(cᵖ, cʷ, cⁱ, d, u, z⁰, LBʸ, UBʸ)
@show r4.TC
@show sum(r4.v);

## Example 4(d): Plan given against the model's
# Compare the plan given and its cost, found by hand in parts (a) and
# (b), with the model's plan and cost from part (c).
# Code block 27: the plan given against the model's
X = cat([45 0 0 20 40 0; 20 25 0 20 40 0; 20 25 0 20 40 0],
        [0 20 35 0 0 0; 0 0 40 0 0 15; 0 0 40 0 0 15]; dims = 3)
@assert round(r4.TC, digits = 2) == 270112.50
# @assert stops the script with an error unless the expression after it is
# true. A run that gets past this line has confirmed that the model's
# total cost, rounded to the cent, is the \$270,112.50 found by hand in
# part (b).
r4.x == X

# Example 5: Twenty-six-week plan and its reports
## Example 5(a): The plan
# Determine the plan that minimizes total cost over the 26 weeks, and
# check it.
# Code block 28: Ex. 5's data, the bounds and the initial setup
# demand in each period, each product (ton): weeks 1-13, then 14-26
d = hcat([26, 20, 20, 23, 41, 10, 27, 14, 26, 27, 14, 23, 14,
          13, 27, 31, 32, 51, 22, 13, 16, 17, 28, 36, 27, 30],
         [ 4,  7, 24, 19, 13, 12,  9, 12,  5, 39,  7, 11, 22,
          11,  8, 14, 11, 14,  9,  9,  4,  5,  6, 18, 22, 23])
t = size(d, 1)                        # number of periods
# capacity of each stage for each product (ton)
u = [60 50; 55 45; 50 35]
m = size(u, 1)                        # number of production stages
g = size(u, 2)                        # number of products
# production cost for each stage, each product ($/ton)
cᵖ = [12 20; 75 130; 35 60]
# weekly inventory carrying rate (1/wk)
@show h = 0.3/(365.25/7)
# inventory cost for each stage, each product ($/ton)
cⁱ = cumsum(cᵖ, dims=1)*h
# switchover cost for each stage for each product ($)
cʷ = [400 600; 90 110; 50 70]
# initial inventory of each stage, each product (ton)
@show y⁰ = [0 0; 0 0; 0 sum(d[[1 2], 2])]
# final inventory of each stage for each product (ton)
yᵗ⁺¹ = zeros(m, g)
# initial set up at each stage for each product
z⁰ = [1 0; 1 0; 1 0]
# convert y⁰ and yᵗ⁺¹ from 2D (m x g) to 3D (m x t x g)
LBʸ = [reshape(y⁰, m, 1, g) zeros(m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)]
UBʸ = [reshape(y⁰, m, 1, g) fill(Inf, m, t-1, g) reshape(yᵗ⁺¹, m, 1, g)];
# Code block 29: Ex. 5 solved with prodinv_switch, and timed
secs = @elapsed r5 = prodinv_switch(cᵖ, cʷ, cⁱ, d, u, z⁰, LBʸ, UBʸ)
@show r5.TC
@show round(Int, secs);
# Code block 30: the production, inventory and switchover costs
# Reshaped cᵖ broadcast for multiplication with r5.x
@show TCᵖ = sum((reshape(cᵖ,m,1,g).*r5.x)[:])
# First period excluded
@show TCⁱ = sum((reshape(cⁱ,m,1,g).*r5.y[:,2:end,:])[:])
@show TCʷ = sum((reshape(cʷ,m,1,g).*r5.v)[:]);
# Code block 31: their sum, and the published total
@assert round(r5.TC, digits = 2) == 149745.64
# @assert stops the script with an error unless the expression after it is
# true. A run that gets past this line has confirmed that the solver's
# total cost, rounded to the cent, is the \$149,745.64 of the problem's
# published solution.
@show TCᵖ + TCⁱ + TCʷ
@show r5.TC;

## Example 5(b): A report for each stage
# Report the plan to the person running each stage: what the stage makes
# of each product in each week.
# Code block 32: a report for the person running each stage
using DataFrames
report(df) = HTML("<div class=\"report\">" * sprint(io -> show(io,
# sprint runs the function it is given on a string buffer and returns what
# was written to it, so sprint(io -> show(io, ...)) turns what show prints
# into a string; HTML hands that string to the page as HTML (HyperText
# Markup Language, what a web page is written in), inside a <div> whose
# class, report, gives the table the lecture's table style.
    MIME("text/html"), df; eltypes = false, summary = false,
    # MIME("text/html") asks show for the DataFrame's HTML form, the table
    # a web page displays, and the three keywords set to false leave out
    # the row of column types, the line giving its size, such as "26×3
    # DataFrame", and the row numbers.
    show_row_number = false)) * "</div>")
for i in 1:m
    display(report(DataFrame("Week" => 1:t,
    # display puts each stage's table on the page. Without it nothing in
    # the loop would appear, since only the last value of a cell is shown,
    # and the value of a for loop is nothing.
        "Product 1" => round.(Int, r5.x[i, :, 1]),
        "Product 2" => round.(Int, r5.x[i, :, 2]))))
end

## Example 5(c): A report for each product
# Report the plan to each product's product manager: its demand, what is
# finished each week and the finished inventory on hand.
# Code block 33: a report for each product's product manager
for k in 1:g
    display(report(DataFrame("Week" => 1:t, "Demand" => d[:, k],
        "Finished" => round.(Int, r5.x[m, :, k]),
        "In stock" => round.(Int, r5.y[m, 2:end, k]))))
end
