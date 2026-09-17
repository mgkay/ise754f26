# 2-loc-7 — generated from 2-loc-7.qmd by tools/qmd_to_jl.py
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

using CairoMakie, CSV, DataFrames, GeoMakie, HiGHS, JuMP, Logjam,
      Printf, Random
usd(x) = replace(string(round(Int, x)),  # 1301411 -> 1,301,411
                 r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")

## Sec. 1. Introduction to MILP
# Two colors carry the section: red is the relaxation and anything
# fractional, green is integer-feasible and what the solver returns.
relaxed  = RGBf(0.78, 0.16, 0.18)
feasible = RGBf(0.13, 0.45, 0.25)
cutline  = RGBf(0.18, 0.40, 0.70)
lattice  = RGBf(0.22, 0.24, 0.27)

c, A, b = (6.0, 8.0), [2.0 3.0; 2.0 0.0], (11.0, 7.0)

function solve_lp(extra = nothing)
    m = Model(HiGHS.Optimizer); set_silent(m)
    @variable(m, x[1:2] >= 0)
    @objective(m, Max, c[1] * x[1] + c[2] * x[2])
    @constraint(m, [k = 1:2], A[k, 1] * x[1] + A[k, 2] * x[2] <= b[k])
    extra === nothing || extra(m, m[:x])
    optimize!(m)
    ok = termination_status(m) == OPTIMAL
    ok || return (obj = NaN, x = [NaN, NaN])
    return (obj = objective_value(m), x = snapvals(value.(x)))
end

lp  = solve_lp()                           # the relaxation
ilp = solve_lp((m, x) -> set_integer.(x))  # the same problem, restricted
inside(i, j) = all(A[k, 1] * i + A[k, 2] * j <= b[k] for k in 1:2)
lat = vec([(i, j) for i in 0:4, j in 0:4 if inside(i, j)])
verts = [(0.0, 0.0), (3.5, 0.0), (3.5, 4 / 3), (0.0, 11 / 3)]

# Each constraint is a line, drawn out to where it meets the axes, so
# the region is visibly their intersection rather than a shape.
x1int = [b[k] / A[k, 1] for k in 1:2]      # where each meets x₂ = 0
x2int = [A[k, 2] == 0 ? Inf : b[k] / A[k, 2] for k in 1:2]

function region_axis(pos, ttl)
    ax = Axis(pos; title = ttl, xlabel = L"x_1", ylabel = L"x_2",
              xticks = 0:6, yticks = 0:4, aspect = DataAspect(),
              titlesize = 17, xlabelsize = 17, ylabelsize = 17,
              xticklabelsize = 15, yticklabelsize = 15)
    limits!(ax, 0, 6.0, 0, 4.2)            # the origin sits in the corner
    for k in 1:2
        isinf(x2int[k]) ?
            lines!(ax, [x1int[k], x1int[k]], [0, 4.2]; color = lattice,
                   linewidth = 1.2, linestyle = :dash) :
            lines!(ax, [0, x1int[k]], [x2int[k], 0]; color = lattice,
                   linewidth = 1.2, linestyle = :dash)
        scatter!(ax, [Point2f(x1int[k], 0)]; color = lattice,
                 markersize = 8, marker = :utriangle)
    end
    poly!(ax, Point2f.(verts); color = (feasible, 0.10),
          strokecolor = feasible, strokewidth = 1.6)
    scatter!(ax, Point2f.(first.(lat), last.(lat)); color = lattice,
             markersize = 7)
    return ax
end

fig = Figure(size = (620, 430))
ax  = region_axis(fig[1, 1],
                  "LP relaxation and the integer points it holds")
text!(ax, 0.12, x2int[1]; text = L"2x_1 + 3x_2 \leq 11", color = lattice,
      align = (:left, :bottom), fontsize = 15)
text!(ax, x1int[2] + 0.08, 4.05; text = L"2x_1 \leq 7", color = lattice,
      align = (:left, :top), fontsize = 15)
scatter!(ax, [Point2f(lp.x...)]; color = relaxed, markersize = 13)
text!(ax, lp.x[1], lp.x[2]; text = @sprintf("  LP optimum  %.2f", lp.obj),
      align = (:left, :center), color = relaxed, fontsize = 15)
scatter!(ax, [Point2f(ilp.x...)]; color = feasible, markersize = 13,
         marker = :diamond)
text!(ax, ilp.x[1], ilp.x[2];
      text = @sprintf("  integer optimum  %.0f", ilp.obj),
      align = (:left, :center), color = feasible, fontsize = 15)
fig

# Sec. 1. Introduction to MILP
## Model: Linear program
# Model: linear program
using JuMP, HiGHS           # the modeling language, and a solver

m = Model(HiGHS.Optimizer)  # an empty model, and who will solve it
@variable(m, x₁ >= 0)
@variable(m, x₂ >= 0)
@objective(m, Max, 6x₁ + 8x₂)
@constraint(m, 2x₁ + 3x₂ <= 11)
@constraint(m, 2x₁ <= 7)
set_silent(m)               # the solver's own log is not wanted
optimize!(m)
println(termination_status(m))
println("x₁ = ", value(x₁), ", x₂ = ", value(x₂),
        ", obj = ", objective_value(m))

# Example 1: Branch and bound by hand
## Example 1(a): One model, nine nodes
# Determine the optimum by solving the relaxation, then adding one
# constraint at each node and dropping it again when the search moves to
# the sibling branch, stopping when the gap falls below one.
# All nine nodes, re-solved here so neither panel can drift from the
# search above. L and G are the two directions a branch can take.
L, G = :le, :ge
paths = Dict(0 => [], 1 => [(1,L,3)], 2 => [(1,L,3),(2,L,1)],
             3 => [(1,L,3),(2,G,2)], 4 => [(1,L,3),(2,G,2),(1,L,2)],
             5 => [(1,L,3),(2,G,2),(1,L,2),(2,L,2)],
             6 => [(1,L,3),(2,G,2),(1,L,2),(2,G,3)],
             7 => [(1,L,3),(2,G,2),(1,G,3)], 8 => [(1,G,4)])
node(cuts) = solve_lp((mm, x) -> for (v, s, r) in cuts
                          s === :le ? @constraint(mm, x[v] <= r) :
                                      @constraint(mm, x[v] >= r)
                      end)
res = Dict(k => node(v) for (k, v) in paths)

function thirds(v)  # 31.667 -> "31 2/3", for a plain string
    w, f = floor(Int, v + 1e-9), v - floor(v + 1e-9)
    f < 1e-6 && return string(w)
    abs(f - 1/3) < 1e-6 && return "$(w)⅓"
    abs(f - 2/3) < 1e-6 && return "$(w)⅔"
    return string(round(v, digits = 2))
end

function texfrac(v)  # 31.667 -> 31\frac{2}{3}, as the slide
    w, f = floor(Int, v + 1e-9), v - floor(v + 1e-9)
    f < 1e-6 && return string(w)
    abs(f - 1/3) < 1e-6 && return string(w) * raw"\frac{1}{3}"
    abs(f - 2/3) < 1e-6 && return string(w) * raw"\frac{2}{3}"
    return string(round(v, digits = 2))
end

# The nodes are visited in order, so the lower bound at each is the best
# integer solution seen up to and including it, and zero before the first.
integral(r) = !isnan(r.obj) && all(r.x .== round.(r.x))  # snapped above
best(id) = [res[j].obj for j in 0:id if integral(res[j])]
lb = Dict(id => maximum([0.0; best(id)]) for id in 0:8)

# The upper bound a node SHOWS is the one still in force: a node that gets
# branched on shows its own relaxation, and a leaf carries its parent's
# down, because nothing better has been solved when the leaf is reached.
par  = Dict(1=>0, 8=>0, 2=>1, 3=>1, 4=>3, 7=>3, 5=>4, 6=>4)
kids = Set(values(par))
ub   = Dict{Int,Float64}()
for id in 0:8
    ub[id] = id in kids ? res[id].obj : ub[par[id]]
end

gx = Dict(0=>0.0, 1=>-1.35, 8=>1.35, 2=>-2.25, 3=>-0.45, 4=>-1.30,
          7=>0.45, 5=>-2.05, 6=>-0.60)
gy = Dict(0=>4.0, 1=>3.0, 8=>3.0, 2=>2.0, 3=>2.0, 4=>1.0, 7=>1.0,
          5=>0.0, 6=>0.0)
blab = Dict(1=>L"x_1 \leq 3", 8=>L"x_1 \geq 4", 2=>L"x_2 \leq 1",
            3=>L"x_2 \geq 2", 4=>L"x_1 \leq 2", 7=>L"x_1 \geq 3",
            5=>L"x_2 \leq 2", 6=>L"x_2 \geq 3")
side = Dict(0=>:right, 1=>:left, 8=>:right, 2=>:left, 3=>:right,
            4=>:left, 7=>:right, 5=>:left, 6=>:right)
incumb = Set([2, 5, 6])  # where a new best integer solution lands

fig = Figure(size = (840, 650))
ax  = Axis(fig[1, 1]; titlesize = 20,
           title = "The bounds close until the gap is under one")
hidedecorations!(ax); hidespines!(ax)
# Wide enough for node 2's caption, and deep enough for the stacked
# fraction in the gap line, which the axis clips if it is not.
limits!(ax, -3.95, 2.75, -1.40, 4.60)

# Centre to centre, and the white-filled circles are drawn over them
# below: the fill hides the overshoot, so every edge meets its node
# exactly, which trimming a fixed amount in y cannot do on an axis
# whose two units are not the same size.
for (kid, pa) in par
    lines!(ax, [Point2f(gx[pa], gy[pa]), Point2f(gx[kid], gy[kid])];
           color = lattice, linewidth = 1.4)
    text!(ax, (gx[pa] + gx[kid]) / 2 + (gx[kid] < gx[pa] ? -0.10 : 0.10),
          (gy[pa] + gy[kid]) / 2 + 0.06; text = blab[kid], fontsize = 20,
          align = (gx[kid] < gx[pa] ? :right : :left, :bottom),
          color = lattice)
end

for id in 0:8
    out = isnan(res[id].obj)
    col = out ? RGBf(0.55, 0.55, 0.58) : id in incumb ? feasible : relaxed
    scatter!(ax, [Point2f(gx[id], gy[id])]; color = :white,
             strokecolor = col, strokewidth = 2.2, markersize = 34)
    text!(ax, gx[id], gy[id]; text = string(id), color = col,
          align = (:center, :center), fontsize = 19)
    dx = side[id] === :left ? -0.30 : 0.30
    al = side[id] === :left ? :right : :left
    if out  # a fathomed node has no bounds to show
        text!(ax, gx[id] + dx, gy[id]; text = "fathomed,\ninfeasible",
              align = (al, :center), color = col, fontsize = 17)
        continue
    end
    u, l = texfrac(ub[id]), texfrac(lb[id])
    dy = id in incumb ? 0.13 : 0.0
    text!(ax, gx[id] + dx, gy[id] + dy; text = L"UB = %$u, \; LB = %$l",
          align = (al, :center), color = lattice, fontsize = 20)
    id in incumb &&
        text!(ax, gx[id] + dx, gy[id] - 0.22; text = "incumbent",
              align = (al, :center), color = feasible, fontsize = 17)
end
text!(ax, gx[0] + 0.30, gy[0] + 0.30; text = "LP", color = relaxed,
      align = (:left, :center), fontsize = 19, font = :bold)

g6, l6 = texfrac(ub[6]), texfrac(lb[6])
text!(ax, -0.85, -0.70; align = (:right, :top), color = lattice,
      fontsize = 20, text = L"gap = %$g6 - %$l6 < 1 \; \Rightarrow")
text!(ax, -0.78, -0.70; align = (:left, :top), color = feasible,
      fontsize = 19, font = :bold, text = "stop")
fig
off = Dict(0 => (0.10, -0.16), 1 => (0.10, 0.10), 2 => (0.10, -0.14),
           3 => (0.10, 0.10), 4 => (-0.12, 0.12), 5 => (-0.12, -0.16),
           6 => (0.10, 0.10))

fig = Figure(size = (620, 450))
ax  = region_axis(fig[1, 1], "Every node is an LP over a smaller region")
for id in 0:6
    q = res[id].x
    scatter!(ax, [Point2f(q...)]; color = relaxed, markersize = 11)
    text!(ax, q[1] + off[id][1], q[2] + off[id][2];
          text = L"%$id: \; %$(texfrac(res[id].obj))",
          align = (:left, :center), color = relaxed, fontsize = 17)
end
scatter!(ax, [Point2f(ilp.x...)]; color = feasible, markersize = 14,
         marker = :diamond)
fig
# Code block 1: one node's report, printed the same way every time
function prtnode(m, UB, LB, x₁, x₂)
    xᵒ = snapvals(value.([x₁, x₂]))
    println("Obj: ", objective_value(m),
            ", x₁: ", xᵒ[1], ", x₂: ", xᵒ[2])
    println(" UB: ", UB, ", LB: ", LB, ", Gap: ", UB - LB, "\n")
    return nothing
end
# Code block 2: node 0, the relaxation
m = Model(HiGHS.Optimizer)
@variable(m, 0 <= x₁)  # continuous, for now
@variable(m, 0 <= x₂)
@objective(m, Max, 6x₁ + 8x₂)
@constraint(m, 2x₁ + 3x₂ <= 11)
@constraint(m, 2x₁ <= 7)
set_silent(m)
optimize!(m)
println(termination_status(m))
UB, LB = objective_value(m), 0.0
prtnode(m, UB, LB, x₁, x₂)
# Code block 3: node 1, adding x₁ ≤ 3
@constraint(m, c1, x₁ <= 3)
optimize!(m)
println(termination_status(m))
UB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 4: node 2, adding x₂ ≤ 1, the first incumbent
@constraint(m, c2, x₂ <= 1)
optimize!(m)
println(termination_status(m))
LB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 5: node 3, dropping x₂ ≤ 1 and adding x₂ ≥ 2
delete(m, c2)
@constraint(m, c3, x₂ >= 2)
optimize!(m)
println(termination_status(m))
UB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 6: node 4, adding x₁ ≤ 2
@constraint(m, c4, x₁ <= 2)
optimize!(m)
println(termination_status(m))
UB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 7: node 5, adding x₂ ≤ 2, a better incumbent
@constraint(m, c5, x₂ <= 2)
optimize!(m)
println(termination_status(m))
LB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 8: node 6, dropping x₂ ≤ 2 and adding x₂ ≥ 3
delete(m, c5)
@constraint(m, c6, x₂ >= 3)
optimize!(m)
println(termination_status(m))
LB = objective_value(m)
prtnode(m, UB, LB, x₁, x₂)
# Code block 9: node 7, infeasible and therefore fathomed
delete(m, [c4, c6])
@constraint(m, c7, x₁ >= 3)
optimize!(m)
termination_status(m)
# Code block 10: node 8, infeasible, and the tree is now searched
delete(m, [c1, c3, c7])
@constraint(m, c8, x₁ >= 4)
optimize!(m)
termination_status(m)

## Example 1(b): The same problem handed straight to the solver
# Determine the same optimum by declaring the variables integer and
# letting the solver run its own branch and bound.
# Code block 11: the integer program, declared and solved in one step
m = Model(HiGHS.Optimizer)
@variable(m, 0 <= y₁, Int)       # integer variable
@variable(m, 0 <= y₂, Int)
@objective(m, Max, 6y₁ + 8y₂)
@constraint(m, 2y₁ + 3y₂ <= 11)
@constraint(m, 2y₁ <= 7)
set_silent(m)
optimize!(m)
yᵒ = snapvals(value.([y₁, y₂]))  # no near-integers in the answer
println("Obj: ", objective_value(m), ", y₁: ", yᵒ[1], ", y₂: ", yᵒ[2])
# Code block 12: make the solver branch, and show what it does
b = Model(HiGHS.Optimizer)           # the same model again
@variable(b, 0 <= z₁, Int)
@variable(b, 0 <= z₂, Int)
@objective(b, Max, 6z₁ + 8z₂)
@constraint(b, 2z₁ + 3z₂ <= 11)
@constraint(b, 2z₁ <= 7)
set_attribute(b, "presolve", "off")  # no shortcut to the answer
set_attribute(b, "mip_heuristic_effort", 0.0)
optimize!(b)                         # not silent: print the log

## Sec. 1. Introduction to MILP
cut_rhs = 4.0  # x₁ + x₂ ≤ 4, through (1,3) and (3,1)

@assert all(i + j <= cut_rhs + 1e-9 for (i, j) in lat)  # valid
@assert sum(lp.x) > cut_rhs + 1e-9                      # and it cuts

fig = Figure(size = (620, 430))
ax  = region_axis(fig[1, 1],
      "A cut removes the fractional vertex, not an integer point")
lines!(ax, [Point2f(0, cut_rhs), Point2f(cut_rhs, 0)]; color = cutline,
       linewidth = 2, linestyle = :dash)
text!(ax, 4.15, 0.35; text = L"x_1 + x_2 \leq 4", color = cutline,
      fontsize = 16)
scatter!(ax, [Point2f(lp.x...)]; color = relaxed, markersize = 13)
text!(ax, lp.x[1], lp.x[2]; text = "  cut off", align = (:left, :center),
      color = relaxed, fontsize = 15)
fig

# Sec. 2. Discrete facility location as a MILP
## Model: Uncapacitated facility location
# Model: uncapacitated facility location, the strong formulation
function uflmilp(k, C)
    n, m = size(C)
    N, M = 1:n, 1:m
    u = Model(HiGHS.Optimizer)
    set_silent(u)
    @variable(u, y[N], Bin)                  # open a site, or not
    @variable(u, 0 <= x[N, M] <= 1)          # share of EF j served from i
    @objective(u, Min, sum(k[i] * y[i] for i in N) +
                       sum(C[i, j] * x[i, j] for i in N, j in M))
    @constraint(u, coverage[j in M],         # (a)
                sum(x[i, j] for i in N) == 1)
    @constraint(u, linking[i in N, j in M],  # (b)
                y[i] >= x[i, j])
    optimize!(u)
    yᵒ = snapvals(value.(y))
    res = (Y = findall(==(1.0), yᵒ), X = snapvals(value.(x)),
           TC = objective_value(u))
    return res
end

## Example 2: Five I-40 cities as a MILP
# Determine the sites and the total cost for the five cities of lecture
# 2.4, which are Asheville, Statesville, Greensboro, Raleigh and
# Wilmington, at mile markers 50, 150, 220, 295 and 420 along I-40, each
# with unit demand and costing 150, 200, 150, 150 and 200 to establish,
# and determine whether the answer its heuristics reached is the best
# one.
# Code block 13: the five I-40 cities of lecture 2.4, through the model
P = [50 150 220 295 420]'          # mile markers along I-40
r, f = 1, 1                    # rate and flow, both unit here
w = r * f
k = [150, 200, 150, 150, 200]  # fixed cost of a site
C = w * dists(P, P, 1)         # variable cost, site to customer
strg = uflmilp(k, C)
# uflmilp returns X through snapvals, so these are exact 0s and 1s
prt(DataFrame(Site = strg.Y,
              Serves = [string(findall(==(1), strg.X[i, :]))
                        for i in strg.Y]))

## Example 3: Popco's plants to optimality
# Determine the optimal set of bottling plants for the Popco instance of
# lecture 2.6, and determine how much the heuristic used there left on
# the table.
# Code block 14: Popco's cost matrix and fixed cost, from lecture 2.6
DC = DataFrame(CSV.File("data/PopcoData.csv"))
CP = Matrix(DataFrame(CSV.File("data/PopcoCmatrix.csv")))
kP = ([ones(nrow(DC)) DC.DEMAND] \ DC.PROD_COST)[1]  # the intercept
(k = round(kP), sites = size(CP, 1), customers = size(CP, 2))
# Code block 15: the same rung, at 204 sites
popco = uflmilp(fill(kP, size(CP, 1)), CP)
(plants = length(popco.Y), TC = round(popco.TC))
# Code block 16: the optimum against the heuristic, on the same data
yh, TCufl, Wh = ufl(kP, CP)  # the heuristic of lecture 2.6
above = round(100 * (TCufl - popco.TC) / popco.TC, digits = 3)
prt(DataFrame(Case = ["heuristic", "MILP"],
              Plants = [length(yh), length(popco.Y)],
              TC = round.([TCufl, popco.TC]),
              Above = ["$above%", "-"]))

## Model: Capacitated facility location
# Model: capacitated facility location
function cflmilp(k, C, f, K)
    n, m = size(C)
    N, M = 1:n, 1:m
    c = Model(HiGHS.Optimizer)
    set_silent(c)
    @variable(c, y[N], Bin)
    @variable(c, 0 <= x[N, M] <= 1)
    @objective(c, Min, sum(k[i] * y[i] for i in N) +
                       sum(C[i, j] * x[i, j] for i in N, j in M))
    @constraint(c, coverage[j in M],  # (a) coverage
                sum(x[i, j] for i in N) == 1)
    @constraint(c, capacity[i in N],  # (b) capacity
                K[i] * y[i] >= sum(f[j] * x[i, j] for j in M))
    optimize!(c)
    yᵒ = snapvals(value.(y))
    res = (Y = findall(==(1.0), yᵒ), X = snapvals(value.(x)),
           TC = objective_value(c))
    return res
end

## Example 4: Capacitated EMCA
# Determine how many machines EMCA should lease and where to locate them
# with each machine's capacity accounted for, on the instance of lecture
# 2.4: twelve million units a year sold to customers grouped by the
# twenty-eight three-digit ZIP codes of the Carolinas, each unit
# weighing 15 pounds and shipped at \$0.25 per ton-mile, each machine
# leased for \$100,000 per year and able to produce up to two million
# units a year.
# Code block 17: EMCA's customers, as lecture 2.4 sets them up
zips = [
    270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283,
    284, 285, 286, 287, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299]
nc = [
      7,   5,   6,   3,   5,   8,   5,   1,   3,   2,   8,   4,   9,   6,
      1,   2,   3,   3,   4,   3,   3,   2,  11,   5,   7,   2,   4,   2]
ud, uwt = 12e6, 15 / 2000                   # units/yr in total, ton/unit
units = ud .* nc ./ sum(nc)                 # units/yr by ZIP
fz = units .* uwt                           # ton/yr by ZIP
zc = uszcta3()
iz = [findfirst(==(zi), zc.ZCTA3) for zi in zips]
Pz = hcat(zc.LON[iz], zc.LAT[iz])           # ZIP centroids
Cz = (fz .* 0.25)' .* (1.2 .* dists(Pz, Pz, :mi))    # $/yr, circuity 1.2
kz = fill(100_000.0, length(zips))          # $/yr per machine
K = 2e6                                     # units/yr a machine CAN make
mmin = floor(Int, ud / K + 1)  # lecture 1.3's feasible minimum
umax = (ud / K) / mmin                      # the utilization it plans to
Kmach = fill(umax * K * uwt, length(zips))  # ton/yr, effective
(sites = length(zips), mmin = mmin, umax = round(umax, digits = 3))
# Code block 18: the same decision with the capacity in the model
cfl = cflmilp(kz, Cz, fz, Kmach)
cflraw = cflmilp(kz, Cz, fz, fill(K * uwt, length(zips)))  # no ceiling
made = vec(sum(cfl.X .* fz', dims = 2))     # ton/yr at each site
prt(DataFrame(ZIP = zips[cfl.Y], tons = round.(made[cfl.Y]),
              util = round.(made[cfl.Y] ./ (K * uwt),      # of NAMEPLATE
                            digits = 3)))
# Code block 19: four answers to the same question
yu, TCu, Wu = ufl(kz[1], Cz; verbose = false)  # no capacity
su = vec(sum(Wu .* units', dims = 2))[yu]
nm, over, TCh, sh = mmin, true, 0.0, Float64[]
while over                                     # lecture 2.4's sweep
    global nm, over, TCh, sh
    yh, TCp, W = pmedian(nm, Cz; verbose = false)
    sh = vec(sum(W .* units', dims = 2))[yh]
    TCh = TCp + nm * kz[1]
    over = maximum(sh) > K
    over && (nm += 1)
end
busiest(s) = 100 * maximum(s) / K              # % of NAMEPLATE capacity
ans = DataFrame(
    approach = ["floor: units / capacity", "throughput-feasible minimum",
                "UFL, capacity ignored", "sweep on the heuristic",
                "CFL as a MILP"],
    machines = [ceil(Int, ud / K), mmin, length(yu), nm, length(cfl.Y)],
    pct = round.([100.0, 100 * umax, busiest(su), busiest(sh),
                  100 * maximum(made[cfl.Y]) / (K * uwt)], digits = 1),
    TC = round.([NaN, NaN, TCu, TCh, cfl.TC]))
prt(ans)

## Sec. 3. Set covering and set packing
# The instance: where each object sits, and what each subset holds.
Pobj = [(0.0, 1.0), (1.6, 1.0), (3.2, 1.0),      # objects 1, 2, 3
        (0.0, 0.0), (1.6, 0.0), (3.2, 0.0)]      # objects 4, 5, 6
Mi = [[1, 2], [1, 4, 5], [3, 5], [2, 3, 6], [6]]

# Okabe-Ito, which stays distinguishable in every kind of color vision.
setcol = [RGBf(0.00, 0.45, 0.70), RGBf(0.84, 0.37, 0.00),
          RGBf(0.00, 0.62, 0.45), RGBf(0.80, 0.47, 0.65),
          RGBf(0.90, 0.62, 0.00)]
setrad = [0.42, 0.52, 0.42, 0.52, 0.34]          # a little apart, to read
setdir = [(0.0, 1.0), (-1.0, 0.0), (0.0, -1.0),  # where each label sits
          (0.7, 0.7), (1.0, 0.0)]
setgap = [0.24, 0.24, 0.24, 0.24, 0.46]          # M5 clears M4's ring

turn(o, a, b) = (a[1] - o[1]) * (b[2] - o[2]) -
                (a[2] - o[2]) * (b[1] - o[1])

function hull(pts)  # the smallest convex ring around pts
    p, ring = sort(unique(pts)), Point2f[]
    for pass in (p, reverse(p))
        start = length(ring) + 1
        for q in pass
            while length(ring) > start &&
                  turn(ring[end - 1], ring[end], q) <= 0
                pop!(ring)
            end
            push!(ring, q)
        end
        pop!(ring)  # the pass ends where the next one starts
    end
    return ring
end

# A subset is the hull of a circle drawn around each of its members, which
# rounds the corners for free and puts a lone member in a circle.
blob(members, rad) =
    hull([Point2f(Pobj[j][1] + rad * cos(a), Pobj[j][2] + rad * sin(a))
          for j in members for a in range(0, 2pi, length = 64)])

function drawsets(ax, chosen = eachindex(Mi))
    for (i, members) in enumerate(Mi)
        on = i in chosen
        ring = blob(members, setrad[i])
        poly!(ax, ring; color = (setcol[i], on ? 0.13 : 0.0),
              strokecolor = (setcol[i], on ? 1.0 : 0.30),
              strokewidth = on ? 2.4 : 1.2,
              linestyle = on ? :solid : :dash)
        d, g = setdir[i], setgap[i]
        far = ring[argmax([q[1] * d[1] + q[2] * d[2] for q in ring])]
        text!(ax, far[1] + g * d[1], far[2] + g * d[2],
              text = L"M_%$i", color = (setcol[i], on ? 1.0 : 0.45),
              align = (:center, :center), fontsize = 19)
    end
end

function drawobjects(ax, uncovered = Int[])
    for (j, q) in enumerate(Pobj)
        out = j in uncovered
        scatter!(ax, [Point2f(q...)]; color = :white, markersize = 30,
                 strokecolor = out ? relaxed : lattice,
                 strokewidth = out ? 2.4 : 1.6)
        text!(ax, q[1], q[2]; text = string(j), fontsize = 17,
              align = (:center, :center), color = out ? relaxed : lattice)
    end
end

function setaxis(pos)
    ax = Axis(pos)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -1.35, 4.35, -1.05, 2.05)
    return ax
end

fig = Figure(size = (760, 400))
ax  = setaxis(fig[1, 1])
drawsets(ax)
drawobjects(ax)
fig

# Sec. 3. Set covering and set packing
## Model: Set covering
# Model: set covering, given any object-by-subset matrix
function setcover(A)
    M, N = 1:size(A, 1), 1:size(A, 2)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[1:length(N)], Bin)
    @objective(model, Min, sum(x[i] for i in N))
    @constraint(model, coverage[j in M],  # (a)
                sum(A[j, i] * x[i] for i in N) >= 1)
    set_silent(model)
    set_time_limit_sec(model, 60.0)       # solution timeout
    optimize!(model)
    println(solution_summary(model).termination_status)
    return findall(==(1.0), snapvals(value.(x)))
end

## Model: Set packing
# Model: set packing, which is set covering with two characters changed
function setpack(A)
    M, N = 1:size(A, 1), 1:size(A, 2)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[N], Bin)
    @objective(model, Max, sum(x[i] for i in N))
    @constraint(model, disjoint[j in M],  # (a)
                sum(A[j, i] * x[i] for i in N) <= 1)
    set_silent(model)
    optimize!(model)
    return findall(==(1.0), snapvals(value.(x)))
end

## Sec. 3. Set covering and set packing
Apack = zeros(length(Pobj), length(Mi))  # the instance, as a matrix
for i in eachindex(Mi)
    Apack[Mi[i], i] .= 1
end
packed = setpack(Apack)
loose = setdiff(eachindex(Pobj), union(Mi[packed]...))

fig = Figure(size = (760, 400))
ax  = setaxis(fig[1, 1])
drawsets(ax, packed)
drawobjects(ax, loose)
fig

## Example 5: Six objects and five subsets
# Determine the smallest collection of the five subsets whose union is
# all six objects, where the subsets are $M_1 = \{1,2\}$, $M_2 =
# \{1,4,5\}$, $M_3 = \{3,5\}$, $M_4 = \{2,3,6\}$ and $M_5 = \{6\}$, each
# costing the same.
# Code block 20: the five subsets as an object-by-subset matrix
m, n = 6, 5
A = zeros(m, n)       # A = objects x subsets
for i in 1:n
    A[Mi[i], i] .= 1  # Mi lists the members of subset i
end
A
Iᵒ = setcover(A)  # Code block 21: the cheapest cover

## Example 6: Transmitter location
# Determine the minimum number of transmitters needed to cover all of
# North Carolina given that each transmitter can reach up to 100 miles.
# Code block 22: the counties, and the distances between their centers
df = filter(r -> r.STFIP == st2fips(:NC), uscounty())
P = hcat(df.LON, df.LAT)
D = dists(P, P, :mi)
(counties = nrow(df), D = size(D))
# Code block 23: each county as a circle of the same area
a = df.ALAND .+ df.AWATER  # area (sq mi)
r = sqrt.(a ./ pi)         # radius (mi)
prt(DataFrame(County = df.NAME[1:4], Area = round.(a[1:4]),
              Radius = round.(r[1:4], digits = 1)))
# Code block 24: which counties each transmitter reaches, and the cover
A = r[:] .+ D .< 100  # radius broadcasts down the rows
idx = setcover(A)
df.NAME[idx]
fig, ax = makemap(df.LON, df.LAT; xexpand = 0.1)
colors = cgrad(:darktest)[LinRange(0, 1, length(idx))]
for (i, j) in zip(idx, colors)
    scatter!(ax, df.LON[A[:, i]], df.LAT[A[:, i]]; color = j,
             marker = '.', markersize = 24)
end
x, y = df.LON[idx], df.LAT[idx]
scatter!(ax, x, y; color = colors, markersize = 10)
text!(ax, x, y; text = df.NAME[idx], aligntext(x, y)...)
fig

## Example 7: DWT clinics
# Determine the minimum number of clinics at which the analysis
# equipment would need to remain in order to allow specimens from
# clinics without equipment to be delivered within a twenty-five minute
# time window. DWT, Inc., has clinics located throughout the Triangle,
# and each currently does some of its most common laboratory specimen
# analysis using equipment located onsite; the equipment is expensive
# and is not heavily utilized. The file
# [DWTclinics.csv](data/DWTclinics.csv) gives the latitude and longitude
# of each clinic, and nothing else.
# Code block 25: the clinics, and the road distance between them
DWT = DataFrame(CSV.File("data/DWTclinics.csv"))
P = hcat(DWT.LON, DWT.LAT)
D = 1.2 .* dists(P, P, :mi)  # road distance, circuity 1.2
(clinics = nrow(DWT), longest = round(maximum(D), digits = 1))
# Code block 26: which clinics keep the equipment
mph = 30               # in-town driving
reach = mph * 25 / 60  # miles in a 25-minute window
keep = setcover(D .<= reach)
DWT.ID[keep]
fig, ax = makemap(DWT.LON, DWT.LAT; xexpand = 0.25, yexpand = 0.25)
resize!(fig, 640, 470)
scatter!(ax, DWT.LON, DWT.LAT; color = lattice, markersize = 7)
scatter!(ax, DWT.LON[keep], DWT.LAT[keep]; color = :transparent,
         strokecolor = feasible, strokewidth = 2.2, markersize = 17)
ax.title = "$(length(keep)) of $(nrow(DWT)) clinics keep the equipment"
ax.titlesize = 15
fig
# Code block 27: how much the answer turns on the assumption
prt(DataFrame(MPH = [20, 25, 30, 35, 40],
              Reach = round.([m * 25 / 60 for m in [20, 25, 30, 35, 40]],
                             digits = 1),
              Keep = [length(setcover(D .<= m * 25 / 60))
                      for m in [20, 25, 30, 35, 40]]))

# Sec. 4. Bin packing
## Model: Bin packing
# Model: bin packing
function binpack(v, V; tlim = 60.0, gap = 1e-4)
    M = 1:length(v)
    bp = Model(HiGHS.Optimizer)
    set_silent(bp)
    set_time_limit_sec(bp, tlim)           # give up after this long
    set_attribute(bp, "mip_rel_gap", gap)  # or once this close
    @variable(bp, y[M], Bin)
    @variable(bp, x[M, M], Bin)
    @objective(bp, Min, sum(y))
    @constraint(bp, capacity[i in M],      # (a)
                V * y[i] >= sum(v[j] * x[i, j] for j in M))
    @constraint(bp, assignment[j in M],    # (b)
                sum(x[i, j] for i in M) == 1)
    optimize!(bp)
    xᵒ, yᵒ = snapvals(value.(x)), snapvals(value.(y))
    used = findall(==(1.0), yᵒ)
    bins = [findall(==(1.0), xᵒ[i, :]) for i in used]
    res = (bins = bins, used = Int(objective_value(bp)),
           status = termination_status(bp), gap = relative_gap(bp),
           secs = solve_time(bp))
    return res
end

## Sec. 4. Bin packing
# Code block 28: what the model costs as the instance grows
grow = DataFrame(objects = Int[], binaries = Int[], bins = Int[],
                 seconds = Float64[])
for m in (20, 50, 100, 200)
    Random.seed!(9)  # the same objects every build
    r = binpack(rand(1:5, m), 10)
    push!(grow, (m, m^2 + m, r.used, round(r.secs, digits = 2)))
end
prt(grow)
# Code block 29: what a looser gap buys, and what it costs
Random.seed!(9)  # the two hundred objects again
v200 = rand(1:5, 200)
loose = DataFrame(gap = String[], bins = Int[], seconds = Float64[])
for (label, g) in (("exact", 1e-4), ("1%", 0.01),
                   ("2%", 0.02), ("5%", 0.05))
    r = binpack(v200, 10; gap = g)
    push!(loose, (label, r.used, round(r.secs, digits = 2)))
end
prt(loose)

## Example 8: Twenty objects into ten-unit bins
# Determine the fewest bins of capacity ten that hold twenty objects
# whose sizes are whole numbers from one to five, and compare the answer
# with the bound that counting gives.
# Code block 30: the instance, and the bound that costs nothing
Random.seed!(1244)             # the same twenty objects every build
mB, VB = 20, 10
vB = rand(1:5, mB)
lbB = ceil(Int, sum(vB) / VB)  # no packing can use fewer than this
prt(vB')                           # the twenty sizes, one row
(total = sum(vB), bound = lbB)
# Code block 31: the fewest bins that hold them
packed = binpack(vB, VB)
binsB = packed.bins
packed.used
fig = Figure(size = (720, 400))
ax  = Axis(fig[1, 1]; xlabel = "bin", ylabel = "volume used",
           xticks = 1:length(binsB), yticks = 0:2:VB,
           title = @sprintf("%d objects, capacity %d: the bound is %d",
                            mB, VB, lbB))
hidespines!(ax, :t, :r)
for (bi, bin) in enumerate(binsB)
    base = 0.0
    for j in bin
        poly!(ax, Rect2f(bi - 0.33, base, 0.66, vB[j]);
              color = (feasible, 0.16 + 0.10 * (vB[j] % 3)),
              strokecolor = feasible, strokewidth = 1.1)
        text!(ax, bi, base + vB[j] / 2; text = string(vB[j]),
              align = (:center, :center), fontsize = 11, color = lattice)
        base += vB[j]
    end
end
hlines!(ax, [VB]; color = relaxed, linewidth = 1.6, linestyle = :dash)
text!(ax, length(binsB) + 0.40, VB * 0.94; text = "capacity",
      align = (:left, :top), color = relaxed, fontsize = 12)
limits!(ax, 0.3, length(binsB) + 1.4, 0, VB * 1.12)
fig

## Sec. 5. Additional MILP examples
# Code block 32: the roster, and the conflict graph it implies
using Graphs, SimpleWeightedGraphs
L = [[1, 3, 4, 5], [1, 2, 4, 8], [1, 5, 7, 8], [5, 6], [4, 6, 7, 8],
     [5, 6, 7, 8], [1, 5, 6, 8], [1, 2, 4, 6], [3, 4, 5, 6], [1, 3, 5, 6],
     [4, 6, 7, 8], [7, 8], [4, 6, 7, 8], [1, 3, 4, 6], [1, 2, 3, 4],
     [1, 4, 5, 6], [1, 3, 4, 6], [1, 2, 4, 5], [1, 3, 4, 6], [1, 2, 3, 4],
     [6, 7, 8, 9], [7, 8, 9, 10], [7, 8, 9, 11], [5, 7, 8, 9],
     [6, 7, 8, 9], [7, 10], [7, 8, 9, 10], [6, 7, 8, 9],
     [7, 8, 9, 10], [10, 9, 8, 7]]
m = maximum(maximum.(L))  # number of exam areas
g = SimpleWeightedGraph(m)
for k in L                # every pair one student sits is a conflict
    for i = 1:length(k)-1, j = i+1:length(k)
        add_edge!(g, k[i], k[j])
    end
end
(students = length(L), exams = nv(g), conflicts = ne(g))
using GraphMakie
lay = GraphMakie.NetworkLayout.Spring(seed = 11)
fig = Figure(size = (420, 380))
ax = Axis(fig[1, 1]; title = "$(nv(g)) areas, $(ne(g)) conflicts")
graphplot!(ax, g; layout = lay, ilabels = string.(1:nv(g)),
           node_color = fill(RGBf(0.86, 0.88, 0.90), nv(g)),
           node_strokecolor = lattice, node_strokewidth = 1.0,
           node_size = 24, edge_color = (:black, 0.28))
hidedecorations!(ax); hidespines!(ax)
fig

# Sec. 5. Additional MILP examples
## Model: Graph coloring
# Model: minimum graph coloring
function colormin(g)
    model = Model(HiGHS.Optimizer)
    V, K = 1:nv(g), 1:nv(g)
    @variable(model, y[K], Bin )
    @variable(model, X[V,V], Bin )
    @objective(model, Min, sum(y[i] for i ∈ K ))
    @constraint(model, [i ∈ V], sum(X[i,k] for k ∈ K) == 1 )
    @constraint(model, [(i,j) ∈ ((src(e),dst(e)) for e ∈ edges(g)),
                        k ∈ K], X[i,k] + X[j,k] <= 1 )
    @constraint(model, [i ∈ V, k ∈ K], X[i,k] <= y[k] )
    set_silent(model)
    optimize!(model)
    yᵒ, Xᵒ = snapvals(value.(y)), snapvals(value.(X))
    res = (K = [findall(Xᵒ[:, i] .!= 0) for i ∈ findall(yᵒ .> 0)],
           colors = objective_value(model))
    return res
end

## Sec. 5. Additional MILP examples
# Code block 33: the exam schedule the coloring produces
qe = colormin(g)
Kᵒ = qe.K
prt(DataFrame(Day = 1:length(Kᵒ),
              Areas = [join(k, ", ") for k in Kᵒ]))
pal = Makie.wong_colors()[1:length(Kᵒ)]
nc = fill(pal[1], nv(g))
for (d, grp) in enumerate(Kᵒ), v in grp
    nc[v] = pal[d]
end
fig = Figure(size = (420, 380))
ax = Axis(fig[1, 1]; title = "$(length(Kᵒ)) exam days")
graphplot!(ax, g; layout = lay, ilabels = string.(1:nv(g)),
           node_color = nc, node_strokecolor = lattice,
           node_strokewidth = 1.0, node_size = 24,
           edge_color = (:black, 0.28))
hidedecorations!(ax); hidespines!(ax)
fig
# Code block 34: the instance, and the two rules that need no solver
using Combinatorics
tardiness(α, p, d) = sum(max.(0, cumsum(p[α]) .- d[α]))

p = [3, 4, 6, 5, 18, 2, 3, 4, 5]
d = [4, 6, 15, 14, 12, 3, 16, 17, 18]

α_edd, α_spt = sortperm(d), sortperm(p)
prt(DataFrame(rule = ["EDD", "SPT"],
              tardiness = [tardiness(α_edd, p, d),
                           tardiness(α_spt, p, d)],
              sequence = [string(α_edd), string(α_spt)]))

## Model: Single-machine total tardiness
# Model: single-machine total tardiness
function tardymilp(p, d)
    n, M = length(p), sum(p)
    model = Model(HiGHS.Optimizer)
    J, K = 1:n, 1:n
    @variable(model, y[J, K], Bin)
    @variable(model, t[K] >= 0)
    @variable(model, C[J] >= 0)
    @variable(model, T[J] >= 0)
    @objective(model, Min, sum(T[j] for j in J))
    @constraint(model, [j ∈ J], sum(y[j, k] for k ∈ K) == 1)
    @constraint(model, [k ∈ K], sum(y[j, k] for j ∈ J) == 1)
    @constraint(model, t[1] == sum(p[j] * y[j, 1] for j ∈ J))
    @constraint(model, [k ∈ 2:n],
                t[k] == t[k-1] + sum(p[j] * y[j, k] for j ∈ J))
    @constraint(model, [j ∈ J, k ∈ K],
                C[j] >= t[k] - M * (1 - y[j, k]))
    @constraint(model, [j ∈ J], T[j] >= C[j] - d[j])
    set_silent(model)
    optimize!(model)
    yᵒ = snapvals(value.(y))
    res = (α = vcat(findall.(!iszero, eachcol(yᵒ))...),
           TC = objective_value(model))
    return res
end

## Sec. 5. Additional MILP examples
# Code block 35: the sequence the model proves is best
sm = tardymilp(p, d)
αᵗ = sm.α
(tardiness = round(Int, sm.TC), sequence = αᵗ)
fin  = cumsum(p[αᵗ])
strt = fin .- p[αᵗ]
late = max.(0, fin .- d[αᵗ])
fig = Figure(size = (760, 300))
ax  = Axis(fig[1, 1]; xlabel = "time", ylabel = "job",
           yticks = (1:length(αᵗ), string.(αᵗ)))
for (row, j) in enumerate(αᵗ)
    col = late[row] > 0 ? relaxed : feasible
    poly!(ax, Rect2f(strt[row], row - 0.32, p[αᵗ][row], 0.64);
          color = (col, 0.20), strokecolor = col, strokewidth = 1.2)
    scatter!(ax, [d[j]], [row]; marker = :vline, markersize = 16,
             color = lattice)
    late[row] > 0 && text!(ax, fin[row] + 0.6, row;
                           text = "+$(Int(late[row]))",
                           align = (:left, :center),
                           color = col, fontsize = 11)
end
hidespines!(ax, :t, :r)
limits!(ax, -0.5, maximum(fin) + 5, 0.2, length(αᵗ) + 0.8)
fig
