# 4-net-3 — generated from 4-net-3.qmd by tools/qmd_to_jl.py
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
using CairoMakie, DataFrames, JuMP, HiGHS, Logjam, Statistics
# Two device pixels per figure unit, as in lectures 3.2 to 4.2, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Presentation plumbing for the prose, as in Lectures 4.1 and 4.2: a
# number with thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

## Sec. 1. Production-inventory planning
# Code block 1: drawing the time-expanded network of a production plan
# Stage i is row i and period j column j; each arc runs from node outline
# to node outline, and each label is a symbol in black with its value in
# red, as on the slide the figure is redrawn from; given a plan's
# production X and inventory Y, their values replace the capacities and
# the inventory symbols, in blue
ink, datac = colorant"#252525", colorant"#d21f26"
flowc = colorant"#1f5fa8"                         # a plan's flows
# Every symbol in the font of the lecture's equations, New Computer
# Modern: italic for the letter, upright for its digits and operators
mi = Makie.MathTeXEngine.texfont(:italic)
mr = Makie.MathTeXEngine.texfont(:math)
it(s) = rich(s; font = mi)                        # a symbol, in italics
up(s; kw...) = rich(s; font = mr, kw...)          # digits, operators
mth(s) = rich([isletter(c) ? it(string(c)) : up(string(c))
               for c in s]...)                    # a mixed term
sym(b, sub, sup = nothing) = sup === nothing ?    # b with subscript sub
    rich(it(b), subscript(up(sub))) :             #   and superscript sup
    rich(it(b), subsup(up(sub), mth(sup)))
num(v) = (r = round(v, digits = 2); isinteger(r) ? Int(r) : r)
val(v; c = datac) = up(" = $(num(v))"; color = c)      # a value
function drawpinet(cᵖ, u, cⁱ, d, y⁰, yᵗ⁺¹; X = nothing, Y = nothing,
                   unit = "month", w = 680, h = 500, r = 0.17, ls = 16,
                   dx = 2.3, dy = 2.0, g = 0.07)    # g: label to its arc
    m, t = length(cᵖ), length(d)
    fig = Figure(size = (w, h))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    P(i, j) = ((j - 1) * dx, -(i - 1) * dy)       # stage i, period j
    arc(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]],
                          [q[2] - p[2]]; color = ink, shaftwidth = 1.3,
                          tipwidth = 8, tiplength = 8)
    lbl(p, s; al = (:left, :center), rot = 0.0, off = (0, 0)) =
        text!(ax, p[1], p[2]; text = s, color = ink, fontsize = ls,
              align = al, rotation = rot, offset = off)
    ℓ, ℓs = 1.0, 1.5                              # end arcs, supply arcs
    for j in 1:t
        x0, y0 = P(1, j)                          # supply into stage 1
        arc((x0, y0 + ℓs), (x0, y0 + r))
        for i in 1:m                              # production, stage i
            xa, ya = i == 1 ? (x0, y0 + ℓs) : P(i - 1, j) .- (0, r)
            ym = (ya + P(i, j)[2] + r) / 2
            lbl((xa + 0.1, ym + 0.2),
                rich(sym("c", "$i", "p"), val(cᵖ[i])))
            lbl((xa + 0.1, ym - 0.2), X === nothing ?
                rich(sym("x", "$i,$j"), up(" ≤ "), sym("u", "$i,$j"),
                     val(u[i, j])) :
                rich(sym("x", "$i,$j"), val(X[i, j]; c = flowc)))
            i > 1 && arc((xa, ya), P(i, j) .+ (0, r))
        end
        xm, ym = P(m, j)                          # demand out of stage m
        arc((xm, ym - r), (xm, ym - ℓ))
        lbl((xm, ym - ℓ - 0.22), rich(sym("d", "$j"), val(d[j]));
            al = (:center, :center))
    end
    for i in 1:m                                  # inventory arcs
        xa, ya = P(i, 1) .- (ℓ + 0.4, 0)          # initial
        xb = P(i, 1)[1] - r
        arc((xa, ya), (xb, ya))
        lbl(((xa + xb) / 2, ya + g),
            rich(sym("y", "$i,1"), up(" = "), sym("y", "$i", "0"));
            al = (:center, :bottom))
        lbl(((xa + xb) / 2, ya - g), val(y⁰[i]); al = (:center, :top))
        for j in 1:t-1
            p, q = P(i, j) .+ (r, 0), P(i, j + 1) .- (r, 0)
            arc(p, q)
            lbl(((p[1] + q[1]) / 2, p[2] + g),        # cost, just above
                rich(sym("c", "$i", "i"), val(cⁱ[i]));
                al = (:center, :bottom))
            # flow, below; a y alone has no tall glyph, so it is raised by
            # about half its font size, which puts its top as close to its
            # arc as the tops of the values below the other arcs
            lbl(((p[1] + q[1]) / 2, p[2] - g), Y === nothing ?
                sym("y", "$i,$(j+1)") :
                rich(sym("y", "$i,$(j+1)"), val(Y[i, j+1]; c = flowc));
                al = (:center, :top),
                off = Y === nothing ? (0, 0.52ls) : (0, 0))
        end
        p = P(i, t) .+ (r, 0)                     # final
        q = p .+ (ℓ + 0.4 - r, 0)
        arc(p, q)
        lbl(((p[1] + q[1]) / 2, p[2] + g),
            rich(sym("y", "$i,$(t+1)"), up(" = "), sym("y", "$i", "t+1"));
            al = (:center, :bottom))
        lbl(((p[1] + q[1]) / 2, p[2] - g), val(yᵗ⁺¹[i]);
            al = (:center, :top))
    end
    for i in 1:m, j in 1:t                        # nodes, over the arcs
        poly!(ax, Circle(Point2f(P(i, j)...), r); color = :white,
              strokecolor = ink, strokewidth = 1.8)
    end
    xc = (t - 1) * dx / 2                         # what the arcs are
    lbl((xc, ℓs + 0.15), "Supply"; al = (:center, :bottom))
    yb = -(m - 1) * dy - ℓ - 0.55
    lbl((xc, yb), "Demand"; al = (:center, :top))
    for j in 1:t
        lbl((P(1, j)[1], yb - 0.4), "$j"; al = (:center, :top))
    end
    lbl((xc, yb - 0.75), "Period ($(unit))"; al = (:center, :top))
    xl = -(ℓ + 0.4) - 0.25
    lbl((xl, -(m - 1) * dy / 2), "Initial inventory";
        al = (:center, :bottom), rot = π / 2)
    xr = (t - 1) * dx + ℓ + 0.4 + 0.25
    lbl((xr, -(m - 1) * dy / 2), "Final inventory"; al = (:center, :top),
        rot = π / 2)
    for i in 1:m
        lbl((xl - 0.55, P(i, 1)[2]), "$i"; al = (:center, :center))
    end
    lbl((xl - 0.85, -(m - 1) * dy / 2), "Stage"; al = (:center, :bottom),
        rot = π / 2)
    return fig
end

drawpinet([200, 800], [50 0 50; 60 0 0], [5, 25], [20, 10, 15], [0, 0],
          [35, 0])

# Sec. 2. Capacity determined outside the model
## Model: Production-inventory planning
# Model: production-inventory planning
using JuMP, HiGHS, Logjam
function prodinv(cᵖ, cⁱ, d, u, LBʸ, UBʸ)
    m, t = length(cᵖ), length(d)
    model = Model(HiGHS.Optimizer)
    @variable(model, 0 ≤ x[i=1:m, j=1:t] ≤ u[i,j])              # (c)
    @variable(model, LBʸ[i,j] ≤ y[i=1:m, j=1:t+1] ≤ UBʸ[i,j])
    # Rows (d) and (e) are bounds on y: its lower bound LBʸ and upper
    # bound UBʸ are the same initial inventory in period 1 and the same
    # final inventory in period $t + 1$, which fixes both, and between
    # them zero and the storage capacity.
    @objective(model, Min,
        sum(cᵖ[i]*x[i,j] for i=1:m, j=1:t) +
        sum(cⁱ[i]*y[i,j] for i=1:m, j=2:t+1))
    @constraint(model, flowbal[i=1:m-1, j=1:t],                 # (a)
        -x[i,j] + x[i+1,j] - y[i,j] + y[i,j+1] == 0)
    @constraint(model, laststage[j=1:t],                        # (b)
        -x[m,j] - y[m,j] + y[m,j+1] == -d[j])

    set_silent(model)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)),
                y = snapvals(value.(y)))
    end
    error(termination_status(model))
end

## Model: Greedy as-late-as-possible procedure
# Model: greedy as-late-as-possible procedure
function latestplan(d, u, y⁰, yᵗ⁺¹)
    m, t = size(u)
    x, r = zeros(m, t), Float64.(d)       # the last stage's requirement
    for i in m:-1:1
        s = Float64(y⁰[i])
        for j in 1:t                       # initial inventory first
            use = min(s, r[j])
            r[j] -= use
            s -= use
        end
        c = yᵗ⁺¹[i] - s                    # final inventory still to make
        c < 0 && return nothing
        for j in t:-1:1                    # as late as possible
            x[i, j] = min(u[i, j], r[j] + c)
            c = r[j] + c - x[i, j]         # left to an earlier period
        end
        c > 0 && return nothing
        r = x[i, :]                        # what stage i - 1 must supply
    end
    y = [y⁰ zeros(m, t)]                   # inventory, by flow balance
    for j in 1:t, i in 1:m
        y[i, j+1] = y[i, j] + x[i, j] - (i < m ? x[i+1, j] : d[j])
    end
    return (x = x, y = y)
end

# Example 1: Two stages with unavailable capacity
## Example 1(b): In Julia
# Determine the plan and its cost with @mdl-prodinv.
# Code block 2: Ex. 1's data
u = [50  0 50;                # capacity of stage i in period j (ton)
     60  0  0];
d = [20, 10, 15]              # demand in period j (ton)
cᵖ = [200, 800]               # production cost in stage i ($/ton)
h = 0.3/12                    # monthly inventory carrying rate (1/month)
@show cⁱ = cumsum(cᵖ)*h       # inventory cost for stage i ($/ton)
y⁰ = [0, 0]                   # initial inventory of stage i (ton)
yᵗ⁺¹ = [35, 0]                # final inventory of stage i (ton)
m = length(cᵖ)                # number of production stages = 2
t = length(d)                 # number of periods of production = 3
LBʸ = [y⁰ zeros(m, t-1) yᵗ⁺¹] # same LB and UB to fix inventory level
UBʸ = [y⁰ fill(Inf, m, t-1) yᵗ⁺¹];
# Code block 3: Ex. 1 solved with prodinv, and as late as possible
TCᵒ, xᵒ, yᵒ = prodinv(cᵖ, cⁱ, d, u, LBʸ, UBʸ)
# prodinv returns a named tuple, (TC = …, x = …, y = …), and assigning it
# to three names unpacks its fields in order, so TCᵒ, xᵒ and yᵒ hold the
# total cost, the production and the inventory.
@show TCᵒ
xˡ, yˡ = latestplan(d, u, y⁰, yᵗ⁺¹)
# @mdl-latest finds the plan a second way, without a solver, and its cost
# should match TCᵒ: two routes to one number, a validation, the
# Triangulate check of Lecture 1.2.
@show sum(cᵖ .* xˡ) + sum(cⁱ .* yˡ[:, 2:end]);   # its cost
# Code block 4: the optimal flows of Ex. 1 on its network
drawpinet(cᵖ, u, cⁱ, d, y⁰, yᵗ⁺¹; X = xᵒ, Y = yᵒ)
[xᵒ; d']                      # Code block 5: production, then demand
yᵒ                            # Code block 6: inventory

## Sec. 2. Capacity determined outside the model
# Code block 7: list2incid and mcnf, as implemented in Lecture 4.2
using SparseArrays
list2incid(i, j, n) = sparse([i; j], [1:length(i); 1:length(i)],
                             [ones(length(i)); -ones(length(j))],
                             n, length(i))

function mcnf(A, c, s; u = fill(Inf, size(A, 2)), l = zeros(size(A, 2)))
    V, E = 1:size(A, 1), 1:size(A, 2)
    model = Model(HiGHS.Optimizer)
    @variable(model, l[k] ≤ x[k ∈ E] ≤ u[k])                  # (b)
    @objective(model, Min, sum(c[k] * x[k] for k ∈ E))
    @constraint(model, supply[i ∈ V; s[i] > 0],
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
# Code block 8: Ex. 1's time-expanded network as an arc list, solved
# Node 1 supplies stage 1; node nd(i, j) is stage i in period j; then a
# node per stage for its initial inventory, and one for its final
nd(i, j) = 1 + (j - 1)*m + i
B(i) = 1 + m*t + i
F(i) = 1 + m*t + m + i
n = 1 + m*t + 2m
I, J, c, ub, lb = Int[], Int[], Float64[], Float64[], Float64[]
arc!(a, b, cc, uu, ll = 0.0) = (push!(I, a); push!(J, b); push!(c, cc);
                                push!(ub, uu); push!(lb, ll))
                                # Each call appends one arc to the list:
                                # start node, end node, cost, upper bound
                                # and lower bound (0 unless given). Giving
                                # the initial and final inventory arcs the
                                # same lower and upper bound fixes their
                                # flow, as LBʸ and UBʸ do in
                                # @mdl-prodinv's implementation.
for j in 1:t, i in 1:m                        # production
    arc!(i == 1 ? 1 : nd(i - 1, j), nd(i, j), cᵖ[i], u[i, j])
end
for i in 1:m
    arc!(B(i), nd(i, 1), 0.0, y⁰[i], y⁰[i])          # initial inventory
    for j in 1:t-1
        arc!(nd(i, j), nd(i, j + 1), cⁱ[i], Inf)      # inventory
    end
    arc!(nd(i, t), F(i), cⁱ[i], yᵗ⁺¹[i], yᵗ⁺¹[i])     # final inventory
end
s = zeros(n)                                  # net supplies
s[1] = sum(d) + sum(yᵗ⁺¹)                     # enough for any plan
for i in 1:m
    s[B(i)], s[F(i)] = y⁰[i], -yᵗ⁺¹[i]
end
for j in 1:t
    s[nd(m, j)] = -d[j]
end
@show length(I)                               # arcs
@show n                                       # nodes
TCᵐ, xᵐ = mcnf(list2incid(I, J, n), c, s; u = ub, l = lb)
@show TCᵐ
reshape(xᵐ[1:m*t], m, t) == xᵒ                # the plan of Ex. 1(b)

## Example 2: One missing flow
# Determine the missing value of flow c in the network of
# @fig-missing-flows(a).
# Code block 9: Ex. 2's network as given, and its missing flow found
# frame! draws the flows N on the network, each marked by what it is in
# N₀, the network as given: given red, unknown black and named, found blue
# and named; a node in hl is circled in blue. A flow is named by its array
# and indices: (:X, i, j) production, (:Y, i, j) inventory, (:d, j) demand
function frame!(ax, N, N₀, name; hl = [], r = 0.16, ls = 12)
    m, t = size(N.X)
    hidedecorations!(ax); hidespines!(ax)
    P(i, j) = ((j - 1) * 1.7, -(i - 1) * 1.6)     # stage i, period j
    arc(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]],
                          [q[2] - p[2]]; color = ink, shaftwidth = 1.0,
                          tipwidth = 6, tiplength = 6)
    function lab(k)                               # a flow's label, color
        v, v₀ = N[k[1]][k[2:end]...], N₀[k[1]][k[2:end]...]
        ismissing(v₀) || return string(v₀), datac
        s = rich(it(name[k]), up(ismissing(v) ? " = ?" : " = $v"))
        return s, ismissing(v) ? ink : flowc
    end
    tx(p, k, al) = ((s, c) = lab(k); text!(ax, p[1], p[2]; text = s,
                    color = c, fontsize = ls, align = al))
    for j in 1:t                                  # production and demand
        x0, y0 = P(1, j)
        arc((x0, y0 + 0.9), (x0, y0 + r))
        tx((x0 + 0.08, y0 + 0.5), (:X, 1, j), (:left, :center))
        for i in 2:m
            p, q = P(i - 1, j), P(i, j)
            arc(p .- (0, r), q .+ (0, r))
            tx((p[1] + 0.08, (p[2] + q[2]) / 2), (:X, i, j),
               (:left, :center))
        end
        xm, ym = P(m, j)
        arc((xm, ym - r), (xm, ym - 0.7))
        tx((xm, ym - 0.8), (:d, j), (:center, :top))
    end
    for i in 1:m                                  # inventory
        p = P(i, 1) .- (0.75, 0)
        arc(p, P(i, 1) .- (r, 0))
        tx(p .- (0.08, 0), (:Y, i, 1), (:right, :center))
        for j in 1:t-1
            p, q = P(i, j) .+ (r, 0), P(i, j + 1) .- (r, 0)
            arc(p, q)
            tx(((p[1] + q[1]) / 2, p[2] + 0.12), (:Y, i, j + 1),
               (:center, :bottom))
        end
        q = P(i, t) .+ (0.75, 0)
        arc(P(i, t) .+ (r, 0), q)
        tx(q .+ (0.08, 0), (:Y, i, t + 1), (:left, :center))
    end
    for i in 1:m, j in 1:t                        # nodes, over the arcs
        h = (i, j) in hl
        poly!(ax, Circle(Point2f(P(i, j)...), r); color = :white,
              strokecolor = h ? flowc : ink, strokewidth = h ? 2.6 : 1.4)
    end
    xlims!(ax, -1.45, 5.3); ylims!(ax, -2.85, 1.0)
    return ax
end

X = [9 0 19; 19 0 12]                 # production at stage i in period j
d = [7, 12, 8]                        # demand in period j
Y = [10 0       0 7;                  # inventory at stage i into period
     0  missing 0 4]                  #   j, missing where unknown
Yᵒ = copy(Y)
Yᵒ[2, 2] = Y[2, 1] + X[2, 1] - d[1]   # flow balance at stage 2, month 1
N₀ = (X = X, Y = Y, d = d)
N = (X = X, Y = Yᵒ, d = d)
fig = Figure(size = (680, 260))
for (k, (Nk, hl, title)) in enumerate([(N₀, [], "(a) As given"),
        (N, [(2, 1)], "(b) Balance at stage 2, month 1")])
    ax = Axis(fig[1, k]; aspect = DataAspect(), title = title,
              titlesize = 14, titlefont = :regular)
    frame!(ax, Nk, N₀, Dict((:Y, 2, 2) => "c"); hl = hl, ls = 15)
end
colgap!(fig.layout, 8)
fig
# Code block 10: missing flows found node by node by flow balance
# At node (i, j), inventory in plus production equals what goes on, to
# stage i + 1 or to demand, plus inventory out; a node with one unknown
# flow determines it, and each step records the node and the flow found
function fillflows(X, Y, d)
    m, t = size(X)
    N = (X = copy(X), Y = copy(Y), d = copy(d))
    v(k) = N[k[1]][k[2:end]...]
    # A flow is named by its array and its indices, (:Y, 2, 2) for
    # $y_{2,2}$, (:X, 1, 3) for $x_{1,3}$ and (:d, 1) for $d_1$, and v(k)
    # reads the flow named k.
    steps = Tuple[]
    while any(A -> any(ismissing, A), N)
        n = length(steps)
        # n counts the steps before a pass. If a pass finds nothing, the
        # rest cannot be found by flow balance alone, and the error says
        # so.
        for i in 1:m, j in 1:t
            F = [(+1, (:Y, i, j)), (+1, (:X, i, j)),           # in
                 (-1, i < m ? (:X, i + 1, j) : (:d, j)),       # on
                 (-1, (:Y, i, j + 1))]                         # out
            u = [f for f in F if ismissing(v(f[2]))]
            length(u) == 1 || continue
            s, k = u[1]
            # The unknown flow's sign s is $+1$ if it comes into the node
            # and $-1$ if it goes out. Flow balance, what comes in less
            # what goes out equal to zero, gives the flow as $-s$ times
            # the signed sum of the node's other three.
            N[k[1]][k[2:end]...] =
                -s * sum(s′ * v(k′) for (s′, k′) in F if k′ != k)
            push!(steps, (i, j, k))
        end
        length(steps) > n || error("flow balance cannot find the rest")
    end
    return N, steps
end

X = [9 0 19; 19 0 12]                 # production at stage i in period j
d = [7, 12, 8]                        # demand in period j
Y = [10 0       0 7;                  # inventory at stage i into period
     0  missing 0 4]                  #   j, missing where unknown
N, steps = fillflows(X, Y, d)
@show steps
N.Y[2, 2]

## Example 3: Unknowns of several kinds
# Determine the missing values $p$, $q$, $r$ and $s$ in the network of
# @fig-missing-kinds(a): a production flow, an inventory flow, a final
# inventory and a demand.
# Code block 11: Ex. 3's missing data found by fillflows, a frame a step
X = [40 0 30; missing 20 22]          # production at stage i in period j
d = [20, missing, 17]                 # demand in period j
Y = [10 25 missing missing;           # inventory at stage i into period
     6  11 7       12]                #   j, missing where unknown
N₀ = (X = X, Y = Y, d = d)
N, steps = fillflows(X, Y, d)
name = Dict((:X, 2, 1) => "p", (:Y, 1, 3) => "q", (:Y, 1, 4) => "r",
            (:d, 2) => "s")
done = [s[1:2] for s in steps]        # the nodes balanced, in order
left = [(i, j) for i in 1:2 for j in 1:3 if (i, j) ∉ done]
fig = Figure(size = (680, 680))
Nk = (X = copy(X), Y = copy(Y), d = copy(d))   # the data known so far
for k in 0:length(steps) + 1
    if k == 0
        hl, title = [], "(a) As given"
    elseif k <= length(steps)
        i, j, f = steps[k]
        Nk[f[1]][f[2:end]...] = N[f[1]][f[2:end]...]
        hl, title = [(i, j)], "($('a' + k)) Balance at stage $i, month $j"
    else                                      # the nodes left over check
        hl, title = left, "($('a' + k)) Check: the nodes left over"
    end
    ax = Axis(fig[k ÷ 2 + 1, k % 2 + 1]; aspect = DataAspect(),
              title = title, titlesize = 13, titlefont = :regular)
    frame!(ax, Nk, N₀, name; hl = hl, ls = 14)
end
colgap!(fig.layout, 8); rowgap!(fig.layout, 4)
fig

## Example 4: Scheduled maintenance
# A single product is produced in a two-stage production process. Stage
# one has a capacity to produce 40 tons of the product per month, and
# there is a cost of \$200 for each ton of product produced. For stage
# two, capacity is 80 tons per month, and there is a cost of \$800 per
# ton. Due to scheduled maintenance, no capacity will be available
# during month five for stage 1 and during months three and five for
# stage 2. Demand for the next six months is estimated to be 25, 15, 10,
# 50, 25, and 15 tons per month. Currently, five tons of material is in
# storage at stage 1 and 25 tons at stage 2; at the end of the planning
# period, ten tons of material should be in storage at stage 1 and 15 at
# stage 2. Up to 30 tons of material per month can be stored at each
# stage. Assuming that the inventory costs are \$12 and \$46 per
# ton-month, determine the production plan that minimizes total costs
# over the planning horizon and what the total production costs will be,
# and what the total inventory costs will be.
# Code block 12: Ex. 4's data
u = [40 40 40 40 0 40;          # capacity of each stage (ton)
     80 80  0 80 0 80]
d = [25, 15, 10, 50, 25, 15]    # demand in each period (ton)
# variable production cost for each stage ($/ton)
cᵖ = [200, 800]
cⁱ = [12, 46]                   # inventory cost for each stage ($/ton)
y⁰ = [5, 25]                    # initial inventory of each stage (ton)
yᵗ⁺¹ = [10, 15]                 # final inventory of each stage (ton)
m = length(cᵖ)                  # number of production stages
t = length(d)                   # number of periods of production
# same LB and UB to fix initial and final inventory levels
LBʸ = [y⁰ zeros(m, t-1) yᵗ⁺¹]
UBʸ = [y⁰ fill(30, m, t-1) yᵗ⁺¹];  # max inventory storage level
# Code block 13: Ex. 4 solved with prodinv, and as late as possible
TCᵒ, xᵒ, yᵒ = prodinv(cᵖ, cⁱ, d, u, LBʸ, UBʸ)
@show TCᵒ
xˡ, yˡ = latestplan(d, u, y⁰, yᵗ⁺¹)
TCˡ = sum(cᵖ .* xˡ) + sum(cⁱ .* yˡ[:, 2:end])   # its cost
@show TCˡ
@show maximum(yˡ[:, 2:t])          # the most it holds at a stage
UBⁿ = [y⁰ fill(Inf, m, t-1) yᵗ⁺¹]  # no storage limit
@show prodinv(cᵖ, cⁱ, d, u, LBʸ, UBⁿ).TC;
[xᵒ; d']                      # Code block 14: production, then demand
yᵒ                            # Code block 15: inventory
TCᵖ, TCⁱ = sum(cᵖ.*xᵒ), sum(cⁱ.*yᵒ)   # Code block 16: component costs
TCᵖ + TCⁱ, TCᵒ                # Code block 17: their sum, and the total
TCⁱ = sum(cⁱ.*yᵒ[:,2:end])    # Code block 18: inventory from period 2
TCᵖ + TCⁱ, TCᵒ                # Code block 19: the sum, and the total

# Sec. 3. Capacity determined inside the model
## Model: Production-inventory with setups
# Model: production-inventory planning with setup costs
function prodinv_setup(cᵖ, cˢ, cⁱ, d, u, z̄, LBʸ, UBʸ)
    m, t = size(z̄)
    # The stages and periods are read from the most setups, z̄[i, j], a
    # matrix laid out like the capacities u[i, j] of @mdl-prodinv's
    # implementation; the capacity per setup u is now a vector, one value
    # for each stage.
    model = Model(HiGHS.Optimizer)
    @variable(model, x[i=1:m, j=1:t] ≥ 0)
    @variable(model, 0 ≤ z[i=1:m, j=1:t] ≤ z̄[i,j], Int)
    @variable(model, LBʸ[i,j] ≤ y[i=1:m, j=1:t+1] ≤ UBʸ[i,j])
    @objective(model, Min,
        sum(cᵖ[i]*x[i,j] + cˢ[i]*z[i,j] for i=1:m, j=1:t) +
        sum(cⁱ[i]*y[i,j] for i=1:m, j=2:t+1))
    @constraint(model, flowbal[i=1:m-1, j=1:t],                 # (a)
        -x[i,j] + x[i+1,j] - y[i,j] + y[i,j+1] == 0)
    @constraint(model, laststage[j=1:t],                        # (b)
        -x[m,j] - y[m,j] + y[m,j+1] == -d[j])
    @constraint(model, capacity[i=1:m, j=1:t],                  # (c)
        x[i,j] ≤ u[i]*z[i,j])

    set_silent(model)
    optimize!(model)
    if termination_status(model) == JuMP.OPTIMAL
        return (TC = objective_value(model), x = snapvals(value.(x)),
                y = snapvals(value.(y)), z = Int.(snapvals(value.(z))))
    end
    error(termination_status(model))
end

# Example 5: Setup costs in manufacturing
## Example 5(a): Optimal plan
# Determine the plan and its cost with @mdl-prodinv-setup.
# Code block 20: Ex. 5's data
u = [40, 80]                    # capacity of each stage (ton)
d = [25, 15, 10, 50, 25, 15]    # demand in each period (ton)
# variable production cost for each stage ($/ton)
cᵖ = [200, 800]
cˢ = [6000, 18000]              # setup cost for each stage ($/month)
h = 0.4/12                    # monthly inventory carrying rate (1/month)
# inventory cost for each stage ($/ton)
@show cⁱ = cumsum(cᵖ + cˢ./u)*h
y⁰ = [5, 25]                    # initial inventory of each stage (ton)
yᵗ⁺¹ = [10, 15]                 # final inventory of each stage (ton)
m = length(u)                   # number of production stages
t = length(d)                   # number of periods of production
# same LB and UB to fix initial and final inventory levels
LBʸ = [y⁰ zeros(m, t-1) yᵗ⁺¹]
UBʸ = [y⁰ fill(30, m, t-1) yᵗ⁺¹];  # max inventory storage level
# Code block 21: Ex. 5 solved with prodinv_setup
z̄ = ones(Int, m, t)                 # one setup a month at most
TCᵒ, xᵒ, yᵒ, zᵒ = prodinv_setup(cᵖ, cˢ, cⁱ, d, u, z̄, LBʸ, UBʸ)
@show TCᵒ;
[xᵒ; d']                      # Code block 22: production, then demand
yᵒ                            # Code block 23: inventory
zᵒ                            # Code block 24: setups
# Code block 25: the cost components, inventory from period 2
TCᵖ, TCⁱ, TCˢ = sum(cᵖ.*xᵒ), sum(cⁱ.*yᵒ[:,2:end]), sum(cˢ.*zᵒ)
TCᵖ + TCⁱ + TCˢ, TCᵒ          # Code block 26: their sum, and the total

## Example 5(b): Cost of a given plan by hand
# Using some different data as noted below (otherwise, use the data
# given in Ex. 5) and only a three-month planning horizon, determine the
# total variable production, inventory, and setup cost over the horizon.
# The forecasted demand is 22, 3, and 33 tons per month. The product
# loses five percent of its value after one month. Each month, 20, 4, 40
# and 25, 0, 37 tons, respectively, are produced at each stage.
# Currently, five tons of material is in storage at stage one and none
# at stage two; at the end of the planning period, seven tons of
# material should be in storage at stage one and four at stage two.
# Code block 27: Ex. 5(b)'s plan, costed
X = [20 4 40; 25 0 37]              # production at stage i in month j
db = [22, 3, 33]                    # demand in month j
Y = zeros(2, 4)                     # inventory, by flow balance
Y[:, 1] = [5, 0]
for j in 1:3
    Y[1, j+1] = Y[1, j] + X[1, j] - X[2, j]
    Y[2, j+1] = Y[2, j] + X[2, j] - db[j]
end
@assert Y[:, 4] == [7, 4]           # the final inventories required
cⁱb = cumsum(cᵖ + cˢ./u)*0.05       # monthly carrying rate 0.05
Z = X .> 0                          # a setup wherever there is production
VPC, IC, SC = sum(cᵖ.*X), sum(cⁱb.*Y[:, 2:end]), sum(cˢ.*Z)
@assert all((VPC, IC, SC) .≈ (62400, 673.75, 54000))  # published
@show VPC
@show IC
@show SC;

## Example 6: Truckload as a setup cost
# The product of {{< xref 3.3 example-1 >}}, 20 tons a year of 40-lb,
# 9-ft³ cartons valued at \$25,000 a ton and carried at 0.3 \$/\$-yr, is
# shipped by truckload 532 miles from Raleigh (27606) to Gainesville
# (32606) at January 2018 rates. Plan its shipments week by week over a
# year as @mdl-prodinv-setup, with a demand of 20/52 tons a week at
# Gainesville and no inventory at either end of the year: (a) determine
# the plan; and (b) determine it again at a value of \$85,000 a ton.
# Code block 28: Lecture 3.3's Ex. 1, and one truck's charge
uwt, ucu = 40, 9                    # lb and ft^3 per carton
s = uwt/ucu                         # density (lb/ft^3)
Kwt, Kcu = 25, 2750                 # trailer limits (ton, ft^3)
@show qmax = maxpayld(s; Kwt = Kwt, Kcu = Kcu)   # ton
f = 20                              # ton/yr
d = 532                             # mi, Raleigh to Gainesville
ppiTL, ppiLTL = 131.0, 177.4        # PPIs for Jan 2018
rTL = 2.00ppiTL/102.7               # $/mi
cTL = charge_tl(qmax, s, d; r = rTL, Kwt = Kwt, Kcu = Kcu,
                ppi = ppiTL)        # $/truck
@show cTL;

# Example 6: Truckload as a setup cost
## Example 6(a): Weekly plan
# Determine the weekly plan for the year.
# Code block 29: the year planned week by week, at product value v
using Statistics
function weekly(v)
    weeks, h = 52, 0.3              # weeks in the year; carrying rate
    dw = fill(f/weeks, weeks)       # demand at Gainesville (ton/week)
    cᵖ = [v, 0.0]                   # plant; truck ($/ton)
    cˢ = [0.0, cTL]                 # setup costs ($/setup)
    u = [f, qmax]                   # capacity per setup (ton)
    z̄ = [ones(Int, 1, weeks);       # most setups in a week: the plant,
         fill(10, 1, weeks)]        #   and trucks, more than ever needed
    cⁱ = h/weeks .* [v, v + cTL/qmax]   # inventory cost ($/ton-week)
    LBʸ = zeros(2, weeks + 1)           # no inventory at either end
    UBʸ = [zeros(2) fill(Inf, 2, weeks - 1) zeros(2)]
    return prodinv_setup(cᵖ, cˢ, cⁱ, dw, u, z̄, LBʸ, UBʸ)
end
r25 = weekly(25000)
tl25 = findall(>(0), r25.z[2, :])              # weeks a truck is sent
@show length(tl25)
@show mean(r25.x[2, tl25])                     # tons per truck
mean(diff(tl25))                               # weeks between trucks
# Code block 30: Lecture 3.3's minTLC on the same shipment
tr = (r = rTL, Kwt = Kwt, Kcu = Kcu, ppi = ppiTL)
res25 = minTLC((f = f, s = s, a = 1/2, v = 25000, h = 0.3, d = d), tr,
               ppiLTL)
@show res25.qᵒ                      # ton
@show 52res25.qᵒ/f                  # weeks between shipments
res25.isLTL

## Example 6(b): More valuable product
# Determine the plan again at a value of \$85,000 a ton, as in {{< xref
# 3.3 example-1-k >}}.
# Code block 31: the plan and minTLC at a value of $85,000 a ton
r85 = weekly(85000)
tl85 = findall(>(0), r85.z[2, :])
@show length(tl85)
@show mean(r85.x[2, tl85])
@show mean(diff(tl85))
res85 = minTLC((f = f, s = s, a = 1/2, v = 85000, h = 0.3, d = d), tr,
               ppiLTL)
@show res85.qᵒ
52res85.qᵒ/f

## Sec. 4. Forecasting demand
# Code block 32: orders on hand consuming the forecast
let
    F = [0.85, 1.10, 0.80, 0.95, 1.00, 0.70, 0.95, 1.20, 1.05, 0.80]
    n, fence = length(F), 2            # periods ahead, demand time fence
    ordc, fcc = colorant"#1f5fa8", colorant"#b9cde5"
    grey = colorant"#bdbdbd"
    s = [max(0.0, 1 - (ℓ - 1)/6)^1.4 for ℓ in 1:n]  # share usually booked
    b = s .* F                         # orders on hand
    b[4] = 1.18                        # booked beyond its forecast
    fig = Figure(size = (680, 350))
    ax = Axis(fig[1, 1]; xlabel = "Periods ahead", ylabel = "Demand",
              xticks = 1:n)
    hideydecorations!(ax; label = false)
    for ℓ in 1:n
        poly!(ax, Rect2f(ℓ - 0.4, 0, 0.8, b[ℓ]); color = ordc)
        if b[ℓ] < F[ℓ] && ℓ <= fence   # forecast set aside
            poly!(ax, Rect2f(ℓ - 0.4, b[ℓ], 0.8, F[ℓ] - b[ℓ]);
                  color = :white, strokecolor = grey, strokewidth = 1)
        elseif b[ℓ] < F[ℓ]             # forecast not yet booked
            poly!(ax, Rect2f(ℓ - 0.4, b[ℓ], 0.8, F[ℓ] - b[ℓ]);
                  color = fcc)
        elseif b[ℓ] > F[ℓ]             # the forecast, below the orders
            lines!(ax, [ℓ - 0.4, ℓ + 0.4], [F[ℓ], F[ℓ]]; color = :white,
                   linestyle = :dash, linewidth = 1.6)
        end
    end
    text!(ax, 4, F[4] + 0.03; text = "forecast", fontsize = 11,
          color = :white, align = (:center, :bottom))
    text!(ax, 4, b[4] + 0.04; fontsize = 11, align = (:center, :bottom),
          text = "orders exceed\nthe forecast:\nplan on the orders")
    vlines!(ax, [fence + 0.5]; color = ink, linestyle = :dash,
            linewidth = 1.2)
    text!(ax, fence + 0.6, 1.85; text = "demand time fence",
          fontsize = 12, align = (:left, :bottom))
    text!(ax, (fence + 1)/2, 1.38; text = "orders only", fontsize = 12,
          align = (:center, :bottom))
    text!(ax, 7.6, 1.38; text = "the larger of\nforecast and orders",
          fontsize = 12, align = (:center, :bottom))
    arrows2d!(ax, [9.6], [0.42], [-5.8], [0]; color = ink,
              shaftwidth = 1.2, tipwidth = 8, tiplength = 8)
    text!(ax, 7.0, 0.46; fontsize = 11, align = (:center, :bottom),
          text = "as a period comes closer, orders replace its forecast")
    elem = [PolyElement(color = ordc), PolyElement(color = fcc),
            PolyElement(color = :white, strokecolor = grey,
                        strokewidth = 1)]
    Legend(fig[2, 1], elem,
           ["Orders on hand", "Forecast", "Forecast set aside"];
           orientation = :horizontal, framevisible = false,
           labelsize = 12)
    xlims!(ax, 0.4, n + 0.6); ylims!(ax, 0, 2.05); hidespines!(ax, :t, :r)
    fig
end

## Sec. 5. Planning horizon
# Code block 33: rolling plans ahead of an outage, with a lead time
let
    T, δ = 12, 2                       # periods, lead time
    cap, o = 0.7, 9:10                 # capacity, periods of the outage
    d = [0.50, 0.33, 0.46, 0.37, 0.47, 0.41,
         0.42, 0.41, 0.41, 0.42, 0.43, 0.44]  # demand
    planc, ordc = colorant"#b9cde5", colorant"#1f5fa8"
    idlec, invc = colorant"#9ccf9c", colorant"#e08a1e"
    grey = colorant"#bdbdbd"
    nb, sp = 0, 0.0                    # count back from the outage
    while sp < sum(d[o])
        nb += 1
        sp += cap - d[o[1] - nb]
    end
    b0 = o[1] - nb                     # first period of the build-ahead
    a0 = b0 - δ                        # its materials are ordered
    H = δ + nb + length(o)
    rows = T - H + 1                   # plans whose window fits
    fig = Figure(size = (680, 640))
    # (a) a plan made in each period: its first δ periods already
    # ordered, the period δ ahead ordered now, the rest planned
    ax1 = Axis(fig[1, 1]; xticks = 1:T, ylabel = "Plan made in period",
               yticks = 1:rows, yreversed = true, titlesize = 13,
               titlefont = :regular,
               title = rich("(a) Rolling: plan ",
                   it("H"), up(" = $H"), " periods ahead; ",
                   "order for the period a lead time away"))
    hidespines!(ax1, :t, :r)
    vspan!(ax1, [b0 - 0.5], [o[1] - 0.5]; color = (idlec, 0.35))
    vspan!(ax1, [o[1] - 0.5], [o[end] + 0.5]; color = (datac, 0.18))
    for k in 1:rows
        J = k:min(k + H - 1, T)
        for j in J
            if j < k + δ               # already ordered
                poly!(ax1, Rect2f(j - 0.43, k - 0.30, 0.86, 0.60);
                      color = :white, strokecolor = ordc,
                      strokewidth = 1.2)
            else
                poly!(ax1, Rect2f(j - 0.45, k - 0.32, 0.9, 0.64);
                      color = j == k + δ ? ordc : planc,
                      strokecolor = :white)
            end
        end
        # inventory carried in at the window's start, out at its end
        scatter!(ax1, [k - 0.5], [k]; marker = :rtriangle,
                 markersize = 9, color = invc)
        last(J) == k + H - 1 &&
            scatter!(ax1, [last(J) + 0.5], [k]; marker = :rtriangle,
                     markersize = 9, color = invc)
    end
    poly!(ax1, Rect2f(a0 - 0.5, a0 - 0.42, H, 0.84);
          color = :transparent, strokecolor = ink, strokewidth = 1.4)
    text!(ax1, 0.6, a0 + 1.6; fontsize = 11, align = (:left, :center),
          text = "the outlined plan, made\nin period $a0, " *
                 "orders for\nperiod $b0, the first of the\n" *
                 "build-ahead, so it has\nto see past the outage")
    xlims!(ax1, 0.4, T + 0.6); ylims!(ax1, rows + 0.6, 0.4)
    elem = [PolyElement(color = :white, strokecolor = ordc,
                        strokewidth = 1.2),
            PolyElement(color = ordc), PolyElement(color = planc),
            MarkerElement(marker = :rtriangle, color = invc,
                          markersize = 9)]
    Legend(fig[2, 1], elem,
           ["Already ordered", "Ordered now", "Planned, not yet ordered",
            "Inventory carried in at the start and out at the end"];
           orientation = :horizontal, nbanks = 2, framevisible = false,
           labelsize = 12)
    # (b) the horizon of the outlined plan: from its order to the end
    # of the outage, each period's materials ordered δ periods ahead
    ax2 = Axis(fig[3, 1]; xlabel = "Period", xticks = 1:T,
               titlesize = 13, titlefont = :regular,
               title = "(b) How long: from the first build-ahead " *
                       "order to the end of the outage")
    hideydecorations!(ax2); hidespines!(ax2, :t, :r, :l)
    for j in 1:T
        if b0 <= j < o[1]              # idle capacity builds inventory
            poly!(ax2, Rect2f(j - 0.45, d[j], 0.9, cap - d[j]);
                  color = idlec)
        end
        poly!(ax2, Rect2f(j - 0.45, 0, 0.9, d[j]);
              color = j in o ? datac : grey)
    end
    lines!(ax2, [0.5, o[1] - 0.5, o[1] - 0.5, o[end] + 0.5,
                 o[end] + 0.5, T + 0.5], [cap, cap, 0, 0, cap, cap];
           color = ink, linewidth = 1.5)
    for k in a0:(o[1] - 1 - δ)         # one order a period, δ ahead
        xs = range(k, k + δ; length = 40)
        lines!(ax2, xs, cap + 0.04 .+ 0.13 .* sin.(π .* (xs .- k) ./ δ);
               color = ordc, linewidth = 1.4)
        scatter!(ax2, [k], [cap + 0.04]; markersize = 5, color = ordc)
        scatter!(ax2, [k + δ], [cap + 0.04]; marker = :dtriangle,
                 markersize = 8, color = ordc)
    end
    text!(ax2, a0 + δ/2, cap + 0.19; text = it("δ"),
          fontsize = 13, color = ordc, align = (:center, :bottom))
    text!(ax2, a0 - 0.6, cap + 0.21; fontsize = 11, color = ordc,
          align = (:right, :center),
          text = "one order each\nperiod, a lead\ntime ahead")
    text!(ax2, T + 0.4, cap + 0.02; text = "capacity", fontsize = 12,
          align = (:right, :bottom))
    text!(ax2, 0.6, 0.05; text = "demand", fontsize = 12,
          align = (:left, :bottom))
    text!(ax2, (b0 + o[1] - 1)/2, cap - 0.03; fontsize = 11,
          align = (:center, :top),
          text = "idle capacity\nbuilds inventory")
    text!(ax2, (o[1] + o[end])/2, d[o[end]] + 0.03; text = "outage",
          fontsize = 12, color = datac, align = (:center, :bottom))
    bracket!(ax2, a0 - 0.45, cap + 0.33, o[end] + 0.45, cap + 0.33;
             text = rich(it("H"), up(" ≥ "), it("δ"), up(" + "),
                         "build-ahead", up(" + "), "outage"),
             fontsize = 12, style = :square, color = ink,
             textcolor = ink, textoffset = 18)
    xlims!(ax2, 0.4, T + 0.6); ylims!(ax2, 0, 1.4)
    linkxaxes!(ax1, ax2)
    rowsize!(fig.layout, 1, Relative(0.5))
    fig
end
# Code block 34: the logistics software stack
let
    boxc, edgec = colorant"#dff2da", colorant"#3a8a4f"
    # name, what it is, centre (x, y); every box 6.65 wide and 2.5 high
    B = [("Data", "csv, Excel, etc.", (4.0, -1.3)),
         ("Report", "GUI, web, etc.", (11.3, -1.3)),
         ("Scripting", "Python, Matlab, Julia", (7.62, -5.92)),
         ("User Library", "in script language", (16.15, -5.92)),
         ("MIP Solver", "Gurobi, Cplex, etc.", (4.0, -10.55)),
         ("Standard Library", "in compiled C, Java", (11.3, -10.55))]
    w, h, rr = 6.65, 2.5, 0.9                     # width, height, corner
    function rbox(c)                              # a rounded box outline
        x0, y0 = c[1] - w/2 + rr, c[2] - h/2 + rr
        x1, y1 = c[1] + w/2 - rr, c[2] + h/2 - rr
        arc(xc, yc, a) = [Point2f(xc + rr*cos(θ), yc + rr*sin(θ))
                          for θ in range(a, a + π/2; length = 12)]
        cs = [(x1, y0, -π/2), (x1, y1, 0), (x0, y1, π/2), (x0, y0, π)]
        return reduce(vcat, [arc(k...) for k in cs])  # corner by corner
    end
    fig = Figure(size = (680, 430))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    # what commercial software packages, dashed
    lines!(ax, [0.05, 19.95, 19.95, 0.05, 0.05],
           [-3.65, -3.65, -12.35, -12.35, -3.65];
           color = ink, linestyle = :dash, linewidth = 1.5)
    text!(ax, 17.45, -9.55;
          text = "Commercial\nSoftware\n(LLamasoft, etc.)",
          align = (:center, :center), justification = :center,
          fontsize = 15, color = ink)
    # each arrow from box edge to box edge; the last three run both ways
    for (p, q, both) in [((4.0, -2.55), (6.15, -4.67), false),   # data in
                         ((9.25, -4.67), (11.25, -2.55), false), # report
                         ((10.945, -5.92), (12.825, -5.92), true),
                         ((6.1, -7.17), (4.1, -9.3), true),
                         ((9.3, -7.17), (11.25, -9.3), true)]
        for (a, b) in (both ? [(p, q), (q, p)] : [(p, q)])
            arrows2d!(ax, [a[1]], [a[2]], [b[1] - a[1]], [b[2] - a[2]];
                      color = datac, shaftwidth = 2.2, tipwidth = 11,
                      tiplength = 11)
        end
    end
    for (name, what, c) in B                      # boxes, over the arrows
        poly!(ax, rbox(c); color = boxc, strokecolor = edgec,
              strokewidth = 2)
        text!(ax, c[1], c[2] + 0.45; text = name, fontsize = 17,
              font = :bold, color = ink, align = (:center, :center))
        text!(ax, c[1], c[2] - 0.55; text = "($what)", fontsize = 14,
              color = ink, align = (:center, :center))
    end
    xlims!(ax, -0.2, 20.2); ylims!(ax, -12.6, 0.0)
    fig
end

# Sec. 5. Planning horizon
# Example 7: Horizon of the month-1 plan
## Example 7(b): In Julia
# Determine the plan over all six months.
# Code block 35: the six-month plan
u6 = [50  0 50  0  0 50;          # capacity of stage i in period j (ton)
      60  0  0 60 60 60]
d6 = [20, 10, 15, 20, 15, 25]       # demand in period j (ton)
cᵖ = [200, 800]                     # production cost in stage i ($/ton)
cⁱ = cumsum(cᵖ)*0.3/12              # inventory cost for stage i ($/ton)
LBʸ = zeros(2, 7)                   # no inventory at the start or end
UBʸ = [zeros(2) fill(Inf, 2, 5) zeros(2)]
TC6, x6, y6 = prodinv(cᵖ, cⁱ, d6, u6, LBʸ, UBʸ)
@show TC6
prt(y6; rows = ["1", "2"], cols = string.(1:7),
    row_title = "Stage")              # inventory into each month
# Code block 36: the plan made in month 1, over horizons of 1 to 6 months
x₁ = zeros(2, 6)                    # month-1 production, horizon H
for H in 1:6
    LBʸ = zeros(2, H + 1)           # no inventory at the start or end
    UBʸ = [zeros(2) fill(Inf, 2, H - 1) zeros(2)]
    x₁[:, H] = prodinv(cᵖ, cⁱ, d6[1:H], u6[:, 1:H], LBʸ, UBʸ).x[:, 1]
end
prt(x₁; rows = ["1", "2"], cols = ["H = $H" for H in 1:6],
    row_title = "Stage")              # month 1's production, by H
