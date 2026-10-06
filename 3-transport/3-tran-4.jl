# 3-tran-4 — generated from 3-tran-4.qmd by tools/qmd_to_jl.py
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
using CairoMakie, DataFrames, Logjam, Optim, Printf
# Two device pixels per figure unit, as in lectures 3.2 and 3.3, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Thousands separator, so a computed figure can be interpolated into a
# result box instead of hand-typed.
commafmt(n) = replace(string(n),
    r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")  # 1357 -> "1,357"
# Dollars: two decimals, the separator on the whole dollars only.
function usd(x)                            # 4441.7314 -> "4,441.73"
    whole, cents = split(@sprintf("%.2f", x), ".")
    return commafmt(whole) * "." * cents
end

# Sec. 1. Full-truckload location
# Example 1: DC location along I-40
## Example 1(a): From full truckloads to the monetary weights
# Determine each facility's monetary weight, inbound from the suppliers'
# full truckloads and outbound from the customers' shares of the
# aggregate product.
# Code block 1: the suppliers, the DC and the customers of Ex. 1
nm   = ["Asheville", "Statesville", "Winston-Salem", "Durham",
        "Wilmington"]
supc = colorant"#d21f26"                 # the suppliers
dcc  = colorant"#1e8a3c"                 # the DC
cusc = colorant"#1f77c4"                 # the customers
ink  = colorant"#252525"
# A box with rounded corners, centered at (x, y), half-width a and
# half-height b
function roundbox(x, y, a, b; c = 0.08)
    arc(cx, cy, t0) = [Point2f(cx + c*cos(t), cy + c*sin(t))
                       for t in range(t0, t0 + pi/2; length = 8)]
    pts = Point2f[arc(x + a - c, y + b - c, 0);
                  arc(x - a + c, y + b - c, pi/2);
                  arc(x - a + c, y - b + c, pi);
                  arc(x + a - c, y - b + c, 3pi/2)]
    return pts
end
XY  = [(0.0, 1.3), (0.0, 0.3), (3.0, 0.8),
       (6.0, 1.6), (6.0, 0.8), (6.0, 0.0)]   # suppliers, DC, customers
lab = [nm[1:2]; "DC"; nm[3:5]]
col = [supc, supc, dcc, cusc, cusc, cusc]
arcs = [(1, 3, "A, 100 ton/yr", :bottom), (2, 3, "B, 380 ton/yr", :top),
        (3, 4, "AB, 20%", :bottom), (3, 5, "AB, 30%", :bottom),
        (3, 6, "AB, 50%", :top)]
a, b = 0.68, 0.22                        # box half-width, half-height
# Where a ray from a box's center along direction u leaves the box
edge(u) = min(a/max(abs(u[1]), 1e-9), b/max(abs(u[2]), 1e-9))

fig = Figure(size = (687, 215))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for (i, j, s, va) in arcs                # each arc runs edge to edge
    p, q = XY[i], XY[j]
    u = (q .- p) ./ hypot((q .- p)...)
    t, h = p .+ edge(u) .* u, q .- (edge(u) + 0.015) .* u
    arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
              color = ink, shaftwidth = 1.6, tipwidth = 9, tiplength = 9)
    m = (t .+ h) ./ 2
    text!(ax, m[1], m[2]; text = s, color = ink, fontsize = 13,
          rotation = atan(u[2], u[1]), align = (:center, va),
          offset = (0, va == :bottom ? 3 : -3))
end
for (i, (x, y)) in enumerate(XY)
    poly!(ax, roundbox(x, y, a, b); color = :white, strokecolor = col[i],
          strokewidth = 1.8)
    text!(ax, x, y; text = lab[i], color = ink, fontsize = 14,
          align = (:center, :center))
end
xlims!(ax, -0.8, 6.8); ylims!(ax, -0.35, 1.95)
fig
# Code block 2: the products, the customers and their maximum payloads
tr = (r = 2, Kwt = 25, Kcu = 2750)
uwt = [30, 120]                    # lb per carton, A and B
ucu = [10, 4]                      # ft^3 per carton
shS = DataFrame(f = [100, 380], s = uwt./ucu)    # the two suppliers
pct = [20, 30, 50]/100             # each customer's share of demand
sh = vcat(shS, DataFrame(f = sum(shS.f)*pct,
                         s = sum(shS.f)./sum(shS.f./shS.s)))
sh.qmax = [maxpayld(row, tr) for row in eachrow(sh)]
prt(sh)
# Code block 3: FTL truckloads and monetary weights
n = sh.f./sh.qmax                  # TL/yr
w = n*tr.r                         # $/mi-yr
prt(hcat(sh, DataFrame(n = n, w = w)))
# Code block 4: the monetary weights, computed beside their nodes
fmt(x) = x == round(x) ? string(Int(round(x))) :
         rstrip(rstrip(@sprintf("%.4f", x), '0'), '.')
f2(x) = @sprintf("%.2f", x)
frac(a, b) = "\\frac{$a}{$b}"
fagg, sagg, qagg = sum(shS.f), sh.s[3], sh.qmax[3]
# The canvas is laid out in pixels, so a font size is the size on the page
wpx, hpx, fsz, rn = 687, 553, 16, 15
xs, xdc, xc = 290, 380, 470              # node columns: in, DC, out
xL, xR = xs - rn - 12, xc + rn + 12      # where the two text columns end
dy = 36                                  # one row of equations
ydc = 200
ys = ydc .+ [112, -112]                  # suppliers 1 and 2
yc = ydc .+ [124, 0, -124]               # customers 3, 4 and 5
yagg = [528, 483, 430]                   # the aggregate, over the DC

fig = Figure(size = (wpx, hpx), figure_padding = 0)
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
# Each equation is set in math, as an L"..." string would be
eq!(x, y, s, h) = text!(ax, x, y; text = Makie.LaTeXString("\$$s\$"),
                        color = ink, fontsize = fsz, align = (h, :center))
function rows!(x, y, h, rs)              # a block of rows centered on y
    for (k, s) in enumerate(rs)
        eq!(x, y + dy*((length(rs) + 1)/2 - k), s, h)
    end
    return nothing
end
eq!(12, yagg[1], "r = \\\$$(tr.r)/\\mathrm{TL‑mi}", :left)
for (y, e) in zip(yagg, [                # the aggregate, over the DC
    "f_{agg} = $(fmt(shS.f[1])) + $(fmt(shS.f[2])) = $(fmt(fagg))",
    "s_{agg} = " * frac(fmt(fagg), frac(fmt(shS.f[1]), fmt(shS.s[1])) *
        " + " * frac(fmt(shS.f[2]), fmt(shS.s[2]))) * " = $(fmt(sagg))",
    "q_{\\max} = \\min\\left\\{$(tr.Kwt), " *
        "$(frac("$(fmt(sagg))($(tr.Kcu))", 2000))\\right\\} = " *
        "$(fmt(qagg))"])
    eq!(xdc, y, e, :center)
end
for k in 1:2                             # the input side, left of 1 and 2
    s, q = fmt(sh.s[k]), fmt(sh.qmax[k])
    rows!(xL, ys[k], :right, [
        "s_$k = $(frac(uwt[k], ucu[k])) = $s",
        "q_{\\max} = \\min\\left\\{$(tr.Kwt), " *
            "$(frac("$s($(tr.Kcu))", 2000))\\right\\} = $q",
        "f_$k = $(fmt(sh.f[k])), \\; n_$k = $(frac(fmt(sh.f[k]), q)) = " *
            "$(f2(n[k]))",
        "w_$k = $(f2(n[k]))($(tr.r)) = $(f2(w[k]))"])
end
for k in 1:3                             # the output side, right of 3-5
    i = k + 2
    rows!(xR, yc[k], :left, [
        "f_$i = $(f2(pct[k]))f_{agg} = $(fmt(sh.f[i]))",
        "n_$i = $(frac(fmt(sh.f[i]), fmt(qagg))) = $(f2(n[i]))",
        "w_$i = $(f2(n[i]))($(tr.r)) = $(f2(w[i]))"])
end
function flow!(p, q)                     # an arc touches both circles
    u = (q .- p) ./ hypot((q .- p)...)
    t, h = p .+ rn .* u, q .- (rn + 1) .* u
    arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
              color = ink, shaftwidth = 1.5, tipwidth = 9, tiplength = 9)
    return nothing
end
for k in 1:2; flow!((xs, ys[k]), (xdc, ydc)); end
for k in 1:3; flow!((xdc, ydc), (xc, yc[k])); end
function node!(x, y, s, c)
    poly!(ax, Circle(Point2f(x, y), rn); color = :white, strokecolor = c,
          strokewidth = 1.5)
    text!(ax, x, y; text = s, color = c, fontsize = 14,
          align = (:center, :center))
    return nothing
end
node!(xs, ys[1], "1", supc); node!(xs, ys[2], "2", supc)
node!(xdc, ydc, "DC", dcc)
for k in 1:3; node!(xc, yc[k], string(k + 2), cusc); end
xlims!(ax, 0, wpx); ylims!(ax, 0, hpx)
fig

## Example 1(b): Locating the DC
# Order the facilities along I-40 and apply the median procedure of {{<
# xref 2.1 mdl-minisum1d >}}.
# Code block 5: the minimum-TC location
using Statistics

P = [50 150 190 270 420]'          # I-40 mile markers
xᵒ = optimize(x -> sum(w .* d1.(x, P)), [mean(P)]).minimizer[1]
@show xᵒ                           # I-40 mile marker
@show TCᵒ = sum(w .* d1.(xᵒ, P))   # $/yr
# Code block 6: the weighted median, swept from both ends
role = [:supplier, :supplier, :customer, :customer, :customer]
function weightline(w, nm, role)
    wc  = colorant"#d21f26"             # the weights
    chk = colorant"#1e8a3c"             # the running checks
    opt = colorant"#b23a48"             # the median
    m = length(w); W = sum(w); half = W/2
    j = findfirst(>=(half), cumsum(w))  # the weighted median
    x = collect(1.0:m)                  # only the order matters
    issup = role .== :supplier
    fig = Figure(size = (687, 205))
    ax = Axis(fig[1, 1])
    hidedecorations!(ax); hidespines!(ax)
    lines!(ax, [0.55, m + 0.45], [0, 0]; color = ink, linewidth = 2.5)
    scatter!(ax, x[issup], zeros(count(issup)); marker = :circle,
             markersize = 14, color = supc)
    scatter!(ax, x[.!issup], zeros(count(.!issup)); marker = :rect,
             markersize = 13, color = cusc)
    for i in 1:m
        text!(ax, x[i], 0.0; text = nm[i], color = ink, font = :bold,
              fontsize = 14, align = (:center, :bottom), offset = (0, 34))
        text!(ax, x[i], 0.0; text = string(role[i]),
              color = issup[i] ? supc : cusc, fontsize = 13,
              align = (:center, :bottom), offset = (0, 14))
        text!(ax, x[i], 0.0; text = f2(w[i]), color = wc,
              fontsize = 14, align = (:center, :top), offset = (0, -12))
    end
    # The running total from each end, until it reaches half the total
    h = f2(half)
    check(c) = "$(f2(c)) $(c < half ? "<" : ">") $h"
    for (row, idx) in enumerate((1:j, m:-1:j))
        c = 0.0
        for i in idx
            c += w[i]
            text!(ax, x[i], 0.0; text = check(c), color = chk,
                  fontsize = 13, align = (:center, :top),
                  offset = (0, -36 - 20*(row - 1)))
        end
    end
    text!(ax, x[j], 0.0; text = "*", color = opt, fontsize = 26,
          align = (:center, :top), offset = (0, -76))
    text!(ax, x[j], 0.0; text = "optimum (median)", color = opt,
          fontsize = 13, align = (:center, :top), offset = (0, -100))
    text!(ax, 0.5, 0.0; text = L"w_i\;(\$/\mathrm{mi‑yr}):", color = wc,
          fontsize = 13, align = (:right, :top), offset = (0, -12))
    text!(ax, 0.5, 0.0; text = L"\sum w_i \geq W/2:", color = chk,
          fontsize = 13, align = (:right, :top), offset = (0, -46))
    text!(ax, m + 0.45, 0.0; text = "W = $(f2(W)),  W/2 = $h",
          color = ink, fontsize = 13, align = (:right, :top),
          offset = (0, -100))
    xlims!(ax, -0.9, m + 0.5); ylims!(ax, -1.08, 0.5)
    return fig
end
weightline(w, nm, role)

## Example 1(c): Weight-gaining or weight-losing
# Classify the DC by comparing its inbound and outbound weights,
# physical and monetary.
# Code block 7: tons, truckloads and weights in and out of the DC
idxin, idxout = 1:2, 3:5           # suppliers in, customers out
@show sum(sh.f[idxin]), sum(sh.f[idxout])   # ton/yr
@show sum(n[idxin]), sum(n[idxout])         # TL/yr
@show sum(w[idxin]), sum(w[idxout])         # $/mi-yr

## Example 1(d): Monthly outbound shipments
# Determine the location of the DC that minimizes the total transport
# cost when every customer receives at least one shipment a month.
# Code block 8: the monthly floor on outbound shipments
tmax = 1/12                        # yr/TL
nmin = 1/tmax                      # TL/yr
n′ = [n[idxin]; max.(n[idxout], nmin)]     # TL/yr
w′ = n′*tr.r                       # $/mi-yr
prt(hcat(sh, DataFrame(n′ = n′, w′ = w′)))
xᵒ′ = optimize(x -> sum(w′ .* d1.(x, P)), [mean(P)]).minimizer[1]
@show xᵒ′                          # I-40 mile marker
# Increase in number of shipments:
@show sum(n)                       # TL/yr
@show sum(n′)
@show sum(n′) - sum(n)
@show TCᵒ′ = sum(w′ .* d1.(xᵒ′, P))        # $/yr
weightline(w′, nm, role)   # Code block 9: the search with the floor

# Sec. 2. Transshipment
## Example 1: DC location along I-40
# Code block 10: direct and transshipment networks
# Each arc: from, to, its products, where along it the label sits, and
# whether the label sits above or below it.
function network!(ax, XY, nm, arcs)
    acol, bcol = colorant"#d21f26", colorant"#1e8a3c"  # product A, B
    rn = 0.17                          # node radius, in data units
    for (i, j, lab, s, va) in arcs
        p, q = XY[i], XY[j]
        u = (q .- p) ./ hypot((q .- p)...)
        # Each arc starts on one circle and ends on the other
        a, b = p .+ rn .* u, q .- (rn + 0.015) .* u
        arrows2d!(ax, [a[1]], [a[2]], [b[1] - a[1]], [b[2] - a[2]];
                  color = ink, shaftwidth = 1.5, tipwidth = 9,
                  tiplength = 9)
        m = p .+ s .* (q .- p)
        txt = [rich(string(c); color = c == 'A' ? acol : bcol)
               for c in lab]
        text!(ax, m[1], m[2]; text = rich(txt...), fontsize = 15,
              font = :bold, align = (:center, va),
              offset = (0, va == :bottom ? 4 : -4))
    end
    # Circles drawn in data units, so the radius the arcs stop at is the
    # radius drawn; a marker sized in pixels never matches it
    for (x, y) in XY
        poly!(ax, Circle(Point2f(x, y), rn); color = :white,
              strokecolor = colorant"#1f77c4", strokewidth = 1.5)
    end
    text!(ax, first.(XY), last.(XY); text = nm, fontsize = 14,
          color = ink, align = (:center, :center))
    return ax
end

fig = Figure(size = (687, 210))
for (c, title) in enumerate(["Direct", "Transshipment"])
    ax = Axis(fig[1, c]; title = title, titlefont = :regular,
              titlesize = 15, aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    if c == 1
        network!(ax, [(0.0, 1.0), (0.0, 0.0), (2.4, 1.0), (2.4, 0.0)],
                 ["1", "2", "3", "4"],
                 [(1, 3, "A", 0.5, :bottom), (1, 4, "A", 0.3, :bottom),
                  (2, 3, "B", 0.3, :bottom), (2, 4, "B", 0.5, :top)])
    else
        network!(ax, [(0.0, 1.0), (0.0, 0.0), (1.2, 0.5), (2.4, 1.0),
                      (2.4, 0.0)],
                 ["1", "2", "DC", "3", "4"],
                 [(1, 3, "AA", 0.5, :bottom), (2, 3, "BB", 0.5, :top),
                  (3, 4, "AB", 0.5, :bottom), (3, 5, "AB", 0.5, :top)])
    end
    text!(ax, -0.35, 0.5; text = "Suppliers", rotation = pi/2,
          fontsize = 13, color = ink, align = (:center, :center))
    text!(ax, 2.75, 0.5; text = "Customers", rotation = pi/2,
          fontsize = 13, color = ink, align = (:center, :center))
    xlims!(ax, -0.5, 2.9); ylims!(ax, -0.25, 1.3)
end
fig
# Code block 11: the inventory profile at the DC
T = 27                                      # periods shown
tS = ([2, 9, 16, 23], [1, 6, 11, 16, 21, 26])  # arrivals of A, of B
qS = (3, 2)                                 # q*_A and q*_B
tC = ([3, 10, 17, 24], [4, 8, 12, 16, 20, 24])  # to customers 3, 4
# The level after each event, and its average over the T periods
function profile(ts, q, tc, T)
    ev = sort(unique([0; ts; reduce(vcat, tc); T]))
    lev = [q*count(<=(t), ts) - sum(count(<=(t), c) for c in tc)
           for t in ev]
    avg = sum(lev[1:end-1] .* diff(ev))/T
    return ev, lev, avg
end
prof = [profile(tS[k], qS[k], tC, T) for k in 1:2]

fig = Figure(size = (687, 360))
blue = colorant"#1f77c4"; grn = colorant"#1e8a3c"; red = colorant"#d21f26"
for k in 1:2
    ev, lev, avg = prof[k]
    ax = Axis(fig[k, 1]; ylabel = "Supplier $k", yticks = 0:qS[k]+1,
              ylabelsize = 13, yticklabelsize = 12, ylabelrotation = 0,
              xgridvisible = false)
    hidexdecorations!(ax); hidespines!(ax, :t, :r)
    stairs!(ax, ev, lev; step = :post, color = blue, linewidth = 2)
    hlines!(ax, [qS[k]/2]; color = red, linestyle = :dot, linewidth = 1.5)
    scatter!(ax, tS[k], zeros(length(tS[k])); marker = :xcross,
             color = grn, markersize = 13)
    xlims!(ax, 0, T); ylims!(ax, -0.3, maximum(lev) + 0.4)
    a = @sprintf("%.2f", avg)
    p = k == 1 ? L"%$a \approx q_A^*/2" : L"%$a \approx q_B^*/2"
    Label(fig[k, 2], p; fontsize = 15, color = ink, halign = :left)
end
for (c, ts) in enumerate(tC)
    ax = Axis(fig[2 + c, 1]; ylabel = "Customer $(c + 2)",
              ylabelsize = 13, ylabelrotation = 0, xgridvisible = false)
    hideydecorations!(ax, label = false); hidespines!(ax, :t, :r, :l)
    if c == 1
        hidexdecorations!(ax); hidespines!(ax, :b)
    else
        ax.xlabel = "time"; ax.xlabelsize = 13; ax.xticklabelsize = 12
    end
    hlines!(ax, [0]; color = ink, linewidth = 1)
    scatter!(ax, ts, zeros(length(ts)); marker = :xcross, color = red,
             markersize = 13)
    xlims!(ax, 0, T); ylims!(ax, -0.6, 0.6)
end
rowsize!(fig.layout, 1, Relative(0.34))
rowsize!(fig.layout, 2, Relative(0.26))
fig

## Model: Uncoordinated transshipment
# Model: uncoordinated transshipment
# Independent transport charge: TL, or the cheaper of TL and LTL when an
# LTL PPI is given; zero when the distance is zero (no truck is needed)
function c0(q, sh, tr, ppi = nothing)
    isapprox(sh.d, 0, atol = 1e-4) && return 0.0
    c = charge_tl(q, sh, tr)
    return ppi === nothing ? c : min(c, charge_ltl(q, sh; ppi = ppi))
end

# The minimum-TLC size of every shipment on its own
function tlc_uc(sh, tr, ppi = nothing)
    q = [isapprox(r.d, 0, atol = 1e-4) ? 0.0 : minTLC(r, tr, ppi).qᵒ
         for r in eachrow(sh)]
    TLC = sum(totlogcost(q[i], c0(q[i], r, tr, ppi), r)
              for (i, r) in enumerate(eachrow(sh)))
    return (TLC = TLC, q = q)
end

## Model: Perfect cross-docking
# Model: perfect cross-docking
# One interval t for every shipment, q = f t; c0 from uncoordinated
# transshipment
function tlc_xd(sh, tr, tmin, tmax, ppi = nothing)
    TLC(t) = sum(r -> totlogcost(r.f*t, c0(r.f*t, r, tr, ppi), r),
                 eachrow(sh))
    t = optimize(TLC, tmin, tmax).minimizer    # (b) below; (a), (c) above
    return (TLC = TLC(t), t = t, q = sh.f*t)
end

# Example 1: DC location along I-40
## Example 1(e): Uncoordinated inventory at Statesville
# Continuing with Ex. 1, all transport is TL (no LTL). Each carton of A
# is valued at \$300, and each carton of B is valued at \$450; the
# suppliers have batch production, and the customers constant
# consumption. Transshipments at the DC use either uncoordinated
# inventory (UC) or perfect cross-docking (XD). Determine the total
# logistics cost of uncoordinated inventory with the DC at Statesville,
# where Ex. 1(b) located it.
# Code block 12: values, inventory fractions and the carrier's PPI
tr = (r = 2, Kwt = 25, Kcu = 2750, ppi = 102.7)  # MC = $45, Lecture 3.2
uval = [300, 450]                  # $ per carton, A and B
shS.v = uval./(uwt/2000)           # $/ton
αS = 0                             # batch production
shS.a .= αS + 0.5                  # uncoordinated DC
shC = DataFrame(f = sum(shS.f)*pct,
                s = sum(shS.f)./sum(shS.f./shS.s),
                v = sum(shS.f.*shS.v)/sum(shS.f))
shC.a .= 0.5                       # constant consumption
sh = vcat(shS, shC)
sh.h .= 0.3                        # 1/yr, a default carrying rate
prt(sh)
# Code block 13: shipments with their distances from a DC at x
shd(x) = hcat(sh, DataFrame(d = [d1.(x, P[idxin]); d1.(x, P[idxout])]))
prt(shd(0))
# Code block 14: uncoordinated TLC with the DC at Statesville
TLCh(x) = tlc_uc(shd(x), tr).TLC
xᵒ = 150                           # Statesville
@show TLC_UC = TLCh(xᵒ)            # $/yr
shUC = shd(xᵒ)
shUC.qmax = [maxpayld(r, tr) for r in eachrow(shUC)]
shUC.qᵒ = tlc_uc(shUC, tr).q
shUC.TLCᵒ = [totlogcost(r.qᵒ, c0(r.qᵒ, r, tr), r)
             for r in eachrow(shUC)]
prt(shUC)

## Example 1(f): Perfect cross-docking at Statesville
# Determine the total logistics cost of perfect cross-docking with the
# DC at Statesville, and the common shipment interval that minimizes it.
# Code block 15: perfect cross-docking with the DC at Statesville
shXD = shUC[:, Not([:qᵒ, :TLCᵒ])]
shXD[idxin, :a] .= αS               # outbound α is unchanged
tmax = minimum(shXD.qmax./shXD.f)   # yr, every shipment in one truck
xd = tlc_xd(shXD, tr, 1/365.25, tmax)
@show xd.t, 365.25xd.t              # yr, days
shXD.qXD = xd.q
shXD.TLC_XD = [totlogcost(r.qXD, c0(r.qXD, r, tr), r)
               for r in eachrow(shXD)]
@show xd.TLC                        # $/yr

## Example 1(g): Bounds on the total logistics cost
# Determine the allocated full-truckload total logistics cost at the
# cross-docked shipment sizes, as a lower bound on what the DC at
# Statesville should cost.
# Code block 16: allocated full-truckload TLC at the cross-docked sizes
shXD.TLC_AFTL = [r.f*tr.r*r.d/r.qmax + r.a*r.v*r.h*r.qXD
                 for r in eachrow(shXD)]
@show sum(shXD.TLC_AFTL)           # $/yr
# Code block 17: the three costs, shipment by shipment
f2(x) = @sprintf("%.2f", x)
lab = [nm[1:2] .* " in"; nm[3:5] .* " out"]
println("| Shipment | \$f\$ | \$d\$ | \$q_{\\max}\$ | \$q^{*}\$ | UC | ",
        "\$q_{XD}\$ | XD | Allocated FTL |")
println("|:--|--:|--:|--:|--:|--:|--:|--:|--:|")
for i in 1:nrow(shUC)
    println("| ", lab[i], " | ", round(Int, shUC.f[i]), " | ",
            round(Int, shUC.d[i]), " | ", f2(shUC.qmax[i]), " | ",
            f2(shUC.qᵒ[i]), " | ", usd(shUC.TLCᵒ[i]), " | ",
            f2(shXD.qXD[i]), " | ", usd(shXD.TLC_XD[i]), " | ",
            usd(shXD.TLC_AFTL[i]), " |")
end
println("| [Total]{style=\"display:block;text-align:right\"} | | | | | ",
        usd(TLC_UC), " | | ", usd(xd.TLC), " | ",
        usd(sum(shXD.TLC_AFTL)), " |")
println("\n: Ex. 1 with the DC at Statesville, shipment by shipment: ",
        "\$f\$ in ton/yr, \$d\$ in mi, sizes in ton, and the ",
        "uncoordinated (UC), cross-docked (XD) and allocated ",
        "full-truckload ({{< xref 3.3 eq-tlc-alloc >}}) total ",
        "logistics costs in \\\$/yr. {#tbl-statesville .dense .fit}\n")

## Example 2: Direct shipment and a DC in Memphis
# Suppliers in Rochester, Orlando and San Antonio ship 3 different
# products  to 4 customers in Portland, Tucson, Denver and Milwaukee,
# @fig-memphis. Determine the total logistics cost of three ways to ship
# them, and compare them: direct shipments, uncoordinated inventory at
# an existing DC in Memphis, and cross-docking at the DC in Memphis.
# Code block 18: supplier, DC and customer locations
# The suppliers
Scity = ["Rochester", "Orlando", "San Antonio"]
Sst = [:NY, :FL, :TX]
S = [loc2lonlat(c; state = st) for (c, st) in zip(Scity, Sst)]
SXY = [getindex.(S, :LON) getindex.(S, :LAT)]

# The customers
Ccity = ["Portland", "Tucson", "Denver", "Milwaukee"]
Cst = [:OR, :AZ, :CO, :WI]
C = [loc2lonlat(c; state = st) for (c, st) in zip(Ccity, Cst)]
CXY = [getindex.(C, :LON) getindex.(C, :LAT)]

# The DC
DCcity = "Memphis"
DC = loc2lonlat(DCcity; state = :TN)
DCXY = [DC.LON DC.LAT]
# Code block 19: the suppliers, the DC and the customers
using GeoMakie

XY = vcat(SXY, DCXY, CXY)
fig, ax = makemap(XY[:, 1], XY[:, 2]; xexpand = 0.25, yexpand = 0.25)
resize!(fig, 687, 400)
h1 = scatter!(ax, SXY[:, 1], SXY[:, 2]; color = supc, markersize = 13)
h2 = scatter!(ax, DCXY[:, 1], DCXY[:, 2]; marker = :utriangle,
              color = ink, markersize = 17)
h3 = scatter!(ax, CXY[:, 1], CXY[:, 2]; marker = :rect, color = cusc,
              markersize = 13)
text!(ax, XY[:, 1], XY[:, 2]; text = [Scity; DCcity; Ccity],
      fontsize = 14, color = ink,
      aligntext(XY[:, 1], XY[:, 2]; offsetamt = 6)...)
axislegend(ax, [h1, h2, h3], ["Suppliers", "DC", "Customers"];
           position = :lb, labelsize = 13)
fig
# Code block 20: three products supplied to four customers
ppiTL = 131.0                      # TL PPI for Jan 2018, as in 3.2
ppiLTL = 177.4                     # LTL PPI for Jan 2018, as in 3.2
tr2 = (r = 2ppiTL/102.7, Kwt = 25, Kcu = 2750, ppi = ppiTL)
fS2 = [500, 75, 300]               # demand (ton/yr)
pct2 = [20, 35, 25, 20]/100        # customer demand percentage
sS2 = [32, 3, 12]                  # density (lb/ft^3)
v2 = [50_000, 25_000, 10_000]      # product cost (in $/ton)
αS = 0                             # batch production at suppliers
αC = 0.5                           # constant consumption at customers

# Example 2: Direct shipment and a DC in Memphis
## Example 2(a): Direct shipments
# Determine the total logistics cost when each supplier ships its
# product directly to each customer, TL or LTL, whichever costs less.
# Code block 21: direct shipments, every supplier to every customer
# One shipment per supplier and customer: flow, density, value, distance
F2 = fS2 * pct2'                   # (3 x 1) * (1 x 4) = (3 x 4) matrix
S2 = repeat(sS2, 1, size(CXY, 1))
V2 = repeat(v2, 1, size(CXY, 1))
D2 = dists(SXY, CXY, :mi) * 1.2    # circuity factor, Lecture 2.2, Sec. 7

# Each shipment at its minimum-TLC size, TL or LTL
shD = DataFrame(f = F2[:], s = S2[:], a = αS + αC, v = V2[:], h = 0.3,
                d = D2[:])
shD.qmax = [maxpayld(r, tr2) for r in eachrow(shD)]
transform!(shD, AsTable(:) => ByRow(r -> minTLC(r, tr2, ppiLTL)) =>
                AsTable)
shD.t = 365.25shD.qᵒ./shD.f        # days, the shipment interval q/f
prt(shD[:, Not(:h)])

# The comparison of the three ways to ship, row by row
out = DataFrame(Method = "Direct shipments", TLC = sum(shD.TLCᵒ),
                tavg = mean(shD.t), LTL = sum(shD.isLTL))
prt(out)

## Example 2(b): Uncoordinated inventory at Memphis
# Determine the total logistics cost when the shipments use a DC located
# at Memphis, TN, with no coordination.
# Code block 22: uncoordinated inventory at a DC in Memphis
# Inbound: each supplier's product to the DC
shS2 = DataFrame(f = fS2, s = sS2, a = αS + 0.5, v = v2)

# Outbound: the aggregate product to each customer
shC2 = DataFrame(f = sum(shS2.f)*pct2,
                 s = sum(shS2.f)./sum(shS2.f./shS2.s),
                 a = αC,
                 v = sum(shS2.f.*shS2.v)/sum(shS2.f))

# Every shipment through the DC at its minimum-TLC size
sh2 = vcat(shS2, shC2)
sh2.h .= 0.3
sh2.d = dists(DCXY, [SXY; CXY], :mi)[:] * 1.2
sh2.qmax = [maxpayld(r, tr2) for r in eachrow(sh2)]
transform!(sh2, AsTable(:) => ByRow(r -> minTLC(r, tr2, ppiLTL)) =>
                AsTable)
sh2.t = 365.25sh2.qᵒ./sh2.f        # days
prt(sh2[:, Not(:h)])

# Added to the comparison
push!(out, ("Uncoordinated at DC", sum(sh2.TLCᵒ), mean(sh2.t),
            sum(sh2.isLTL)))
prt(out)

## Example 2(c): Perfect cross-docking at Memphis
# Determine the total logistics cost when the shipments use a DC located
# at Memphis, TN, with perfect cross-docking.
# Code block 23: perfect cross-docking at the DC in Memphis
idxin2 = 1:length(fS2)             # the three inbound shipments
shXD2 = sh2[:, Not([:qᵒ, :TLCᵒ, :isLTL, :t])]
shXD2[idxin2, :a] .= αS            # outbound α is unchanged
tmax2 = minimum(shXD2.qmax./shXD2.f)  # yr, every shipment in one truck
xd2 = tlc_xd(shXD2, tr2, 1/365.25, tmax2, ppiLTL)
shXD2.qXD = xd2.q
shXD2.TLC_XD = [totlogcost(r.qXD, c0(r.qXD, r, tr2, ppiLTL), r)
                for r in eachrow(shXD2)]
prt(shXD2[:, Not(:h)])
nLTL = count(r -> c0(r.qXD, r, tr2, ppiLTL) < charge_tl(r.qXD, r, tr2),
             eachrow(shXD2))
push!(out, ("Cross-docking at DC", xd2.TLC, 365.25xd2.t, nLTL))
prt(out)

# Sec. 3. Location with total logistics cost
# Example 3: DC location on total logistics cost
## Example 3(a): DC on I-40
# Determine where the DC of Ex. 1 should be located to minimize TLC with
# uncoordinated inventory, and compare the cost of shipping every
# shipment as a full truckload.
# Code block 24: TLC of TL and of FTL shipments along I-40
qm = [maxpayld(r, tr) for r in eachrow(sh)]   # FTL: every shipment qmax
TLCftl(x) = sum(totlogcost(qm[i], c0(qm[i], r, tr), r)
                for (i, r) in enumerate(eachrow(shd(x))))
xs = 0:0.5:450
fig = Figure(size = (687, 300))
ax = Axis(fig[1, 1]; xlabel = "I-40 mile marker", ylabel = "TLC (\$/yr)",
          ytickformat = v -> commafmt.(round.(Int, v)),
          xlabelsize = 14, ylabelsize = 14)
vlines!(ax, P[:]; color = (ink, 0.35), linestyle = :dash)
lines!(ax, xs, TLCh.(xs); color = cusc, linewidth = 2, label = "TL")
lines!(ax, xs, TLCftl.(xs); color = supc, linewidth = 2, label = "FTL")
scatter!(ax, [150], [TLCh(150)]; color = colorant"#b23a48",
         markersize = 12)
axislegend(ax; position = :rc, labelsize = 13)
fig
# Code block 25: the optimizer against the plot
xˣ = optimize(TLCh, [mean(P)]).minimizer[1]
@show TLCh(xˣ), xˣ                 # $/yr, I-40 mile marker
xᵒ = 150
@show TLCh(xᵒ), xᵒ                 # $/yr, I-40 mile marker
@show TLCftl(xᵒ)/TLCh(xᵒ)          # FTL against TL at Statesville

## Example 3(b): DC for the network of Ex. 2
# Determine the optimal DC location in Ex. 2 for uncoordinated
# inventory, and for perfect cross-docking together with its common
# shipment interval, starting each search from the location that full
# truckloads would choose.
# Code block 26: a starting location from the FTL approximation
w2 = sh2.f./sh2.qmax               # TL/yr, the weights (equal rates)
XY2 = [SXY; CXY]
DCftl = optimize(x -> sum(w2 .* dists(x', XY2, :mi)[:]),
                 vec(mean(XY2, dims = 1))).minimizer
big = filter(r -> r.POP > 50_000, usplace())   # places to name it by
lonlat2loc(DCftl, big).desc
# Code block 27: optimal DC location, uncoordinated inventory
sh2d(xy) = (s = copy(sh2); s.d = dists(xy', XY2, :mi)[:]*1.2; s)
TLC5h(xy) = tlc_uc(sh2d(xy), tr2, ppiLTL).TLC
uc5 = optimize(TLC5h, DCftl)
@show uc5.minimizer                # (LON, LAT)
@show uc5.minimum                  # $/yr
lonlat2loc(uc5.minimizer, big).desc
# Code block 28: optimal DC location and interval, cross-docking
sh2xd(xy) = (s = copy(shXD2); s.d = dists(xy', XY2, :mi)[:]*1.2; s)
TLC6h(xy) = tlc_xd(sh2xd(xy), tr2, 1/365.25, tmax2, ppiLTL).TLC
xd6 = optimize(TLC6h, DCftl)
@show xd6.minimizer                # (LON, LAT)
@show xd6.minimum                  # $/yr
t6 = tlc_xd(sh2xd(xd6.minimizer), tr2, 1/365.25, tmax2, ppiLTL).t
@show 365.25t6                     # days
lonlat2loc(xd6.minimizer, big).desc

## Example 4: Number of regional DCs for Lowe's
# Determine the number of regional DCs that minimizes the total
# logistics cost of Lowe's network, and how much more its actual number
# would cost.
# Code block 29: Lowe's stores, suppliers and demand
using Random, SparseArrays
z3 = filter(r -> r.ISCUS && r.POP > 100_000, uszcta3())  # 3-digit ZIPs
CXY3 = Matrix(z3[:, [:LON, :LAT]])  # a store at each 3-digit ZIP
SXY3 = CXY3                         # and a supplier at each
COGS = 44.04e9                      # 2017 cost of goods sold ($/yr)
v3 = 7000                           # average LTL value ($/ton)
f3 = COGS/v3                        # annual demand (ton/yr)
s3 = 10                             # average density, class 100 (lb/ft^3)
a3 = 0.5                            # batch, uncoordinated DC, const. use
h3 = 0.3                            # average carrying rate (1/yr)
# TL carrier at the Jan 2018 PPI of Code block 20
tr3 = (r = 2ppiTL/102.7, Kwt = 25, Kcu = 2750, ppi = ppiTL)
qmax3 = maxpayld(s3; Kwt = tr3.Kwt, Kcu = tr3.Kcu)  # FTL everywhere
fC3 = f3*(z3.POP/sum(z3.POP))       # demand proportional to population
fS3 = fill(f3/size(SXY3, 1), size(SXY3, 1))  # equal allocation of supply
@show nrow(z3), f3, qmax3           # ZIPs, ton/yr, ton
# Code block 30: TLC for 1 to 20 DCs, by ALA from five starts each
DCh(XY) = dists(XY, CXY3, :mi)*1.2  # DC to store
function FC(XY)                     # each store's demand from nearest DC
    i = [argmin(c) for c in eachcol(DCh(XY))]
    return sparse(i, 1:length(fC3), fC3, size(XY, 1), length(fC3))
end
# every supplier serves every DC, in proportion to its demand
FS(XY) = (vec(sum(FC(XY), dims = 2))/sum(fC3)) * fS3'
W(XY) = [FS(XY) FC(XY)]*(tr3.r/qmax3)  # w = f r_FTL
TCh(XY) = sum(W(XY) .* [dists(SXY3, XY, :mi)'*1.2 DCh(XY)])
alloc_h(XY) = (W(XY), TCh(XY))
ICh(XY) = a3*v3*h3*qmax3*(length(FS(XY)) + length(fC3))
P3 = [SXY3; CXY3]
Random.seed!(9348567)
res3 = DataFrame(n = Int[], TC = Float64[], IC = Float64[],
                 TLC = Float64[])
for n in 1:20
    X, TC, _ = ala(randX(CXY3, n), ones(size(P3, 1)), P3;
                   alloc = alloc_h, nruns = 5)
    push!(res3, (n, TC, ICh(X), TC + ICh(X)))
end
nᵒ = argmin(res3.TLC)
@show nᵒ, res3.TLC[15]/res3.TLC[nᵒ] - 1   # DCs, extra TLC of 15
# Code block 31: TLC, TC and IC against the number of DCs
fig = Figure(size = (687, 300))
ax = Axis(fig[1, 1]; xlabel = "Number of DCs", ylabel = "\$ million/yr",
          xticks = 1:20, xlabelsize = 14, ylabelsize = 14)
lines!(ax, res3.n, res3.TLC/1e6; color = ink, linewidth = 2,
       label = "TLC")
lines!(ax, res3.n, res3.TC/1e6; color = cusc, linewidth = 2, label = "TC")
lines!(ax, res3.n, res3.IC/1e6; color = supc, linewidth = 2, label = "IC")
scatter!(ax, [nᵒ], [res3.TLC[nᵒ]/1e6]; color = colorant"#b23a48",
         markersize = 13)
axislegend(ax; position = :rc, labelsize = 13)
fig

## Sec. 4. Warehousing
# Code block 32: what replacing one material handler is worth
wage, rate, life = 45_432, 0.017, 5   # A ($/yr), i (1/yr), n (yr)
Pmax = wage*(1 - (1 + rate)^-life)/(1 - (1 + rate)^-1)   # P ($)
