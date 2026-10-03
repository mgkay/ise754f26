# 3-tran-3 — generated from 3-tran-3.qmd by tools/qmd_to_jl.py
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

using CairoMakie, DataFrames, Logjam, Optim, Printf
# Two device pixels per figure unit, so the raster figures are sharp
# at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Thousands separator, so a computed figure can be interpolated into
# a result box instead of hand-typed.
commafmt(n) = replace(string(n),
    r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")  # 1357 -> "1,357"
# Dollars: two decimals, the separator on the whole dollars only.
function usd(x)                            # 4441.7314 -> "4,441.73"
    whole, cents = split(@sprintf("%.2f", x), ".")
    return commafmt(whole) * "." * cents
end

# Sec. 1. Periodic shipments
# Example 1: Periodic truck shipment from Raleigh to Gainesville
## Example 1(a): Full truckloads per year
# Continuing with the example, and assuming a constant annual demand for
# the product of 20 tons, determine the number of full truckloads per
# year, and account for why this number should not be rounded to an
# integer value.
# Code block 1: full truckloads per year
# From Example 1 of Lecture 3.2:
uwt = 40                           # lb
ucu = 9                            # ft^3
@show s = uwt/ucu                  # lb/ft^3
Kwt = 25                           # ton
Kcu = 2750                         # ft^3
@show qmax = maxpayld(s; Kwt = Kwt, Kcu = Kcu)  # ton

# New:
f = 20                             # ton/yr
q = qmax                           # ton (FTL => q = qmax)
@show n = f/q                      # TL/yr

## Example 1(b): Shipment interval
# Determine the shipment interval, and how many days there are between
# shipments.
# Code block 2: shipment interval
@show t = q/f                      # yr/TL
@show 365.25/n                     # day/TL, days between truckloads

# Sec. 2. Full-truckload charge
# Example 1: Periodic truck shipment from Raleigh to Gainesville
## Example 1(c): Annual FTL transport cost
# Determine the annual full-truckload transport cost.
# Code block 3: FTL rate and annual FTL transport cost
d = 532                            # mi, Google Maps road distance
ppiTL = 131.0                      # TL PPI for Jan 2018
@show rTL = 2.00ppiTL/102.7        # $/mi
@show rFTL = rTL/qmax              # $/ton-mi
@show TC_FTL = n * rTL * d         # $/yr

## Example 1(d): FTL cost with a three-month interval
# Determine the cost if the shipments were to be made at least every
# three months.
# Code block 4: FTL cost with a three-month interval
@show tmax = 3/12                  # yr/TL
@show nmin = 1/tmax                # TL/yr
@show q = f/max(n, nmin)           # ton
@show TC′_FTL = max(n, nmin) * rTL * d   # $/yr

## Example 1: Periodic truck shipment from Raleigh to Gainesville
ppiLTL = 177.4                     # LTL PPI for Jan 2018, as in 3.2
cTLh(q)  = charge_tl(q, s, d; r = rTL, Kwt = Kwt,
                     Kcu = Kcu, ppi = ppiTL)
cLTLh(q) = charge_ltl(q, s, d; ppi = ppiLTL)
c0(q)    = min(cTLh(q), cLTLh(q))  # independent charge, the upper bound
cFTL(q)  = rFTL*q*d                # allocated full-truckload, the lower

# The TL/LTL indifference point, searched only up to the LTL
# estimate's cube bound of 650 ft^3.
qLTLmax = 650s/2000
qI = optimize(q -> abs(cTLh(q) - cLTLh(q)), 0.075, qLTLmax).minimizer
MC_LTL = mincharge_ltl(d; ppi = ppiLTL)

# A split horizontal axis: the first 1.5 tons take 45% of the width,
# the rest out to two and a half truckloads the other 55%, linear
# inside each piece.
QSPLIT, QEND = 1.5, 2.5qmax
u(q) = q <= QSPLIT ? 0.45q/QSPLIT :
       0.45 + 0.55(q - QSPLIT)/(QEND - QSPLIT)

blue   = RGBf(0.13, 0.35, 0.60)
purple = RGBf(0.58, 0.20, 0.72)
red    = RGBf(0.85, 0.10, 0.10)
olive  = RGBf(0.40, 0.48, 0.20)

fig = Figure(size = (687, 480))
ax = Axis(fig[1, 1];
          xlabel = "Shipment size (ton)",
          ylabel = "Transport charge (\$)",
          title = "Transport charge for a shipment",
          titlesize = 17, xlabelsize = 16, ylabelsize = 16,
          xticklabelsize = 14, yticklabelsize = 14)
vlines!(ax, [u(QSPLIT)]; color = (:black, 0.45), linewidth = 1.2,
        linestyle = :dashdot)
qs = range(1/2000, QEND; length = 4000)
lines!(ax, u.(qs), cFTL.(qs); color = purple, linewidth = 2.6)
# Dotted: LTL past the indifference point, and the one-truckload
# charge short of it.
qL = range(qI, qLTLmax; length = 200)
lines!(ax, u.(qL), cLTLh.(qL); color = blue, linewidth = 1.6,
       linestyle = :dot)
lines!(ax, [0, u(qI)], [rTL*d, rTL*d]; color = blue, linewidth = 1.6,
       linestyle = :dot)
lines!(ax, u.(qs), c0.(qs); color = blue, linewidth = 2.6)

# Both axes start at zero, so the origin sits in the corner. The limits
# and ticks come before the labels, because a label set along a curve
# takes the curve's angle as drawn, and that depends on both.
xlims!(ax, 0, 1)
ylims!(ax, 0, 1.1*3rTL*d)
ax.xticks = (u.([150/2000, qI, qmax, 2qmax]),
             ["150/2000", @sprintf("%.4f", qI),
              @sprintf("%.2f", qmax), @sprintf("%.2f", 2qmax)])
# The LTL minimum charge (MC) is named on its own tick: the floor it
# labels is too short for a label inside the plot to clear the curve.
ax.yticks = ([MC_LTL, rTL*d, 2rTL*d, 3rTL*d],
             ["MC " * @sprintf("%.2f", MC_LTL);
              string.(round.(Int, (1:3) .* rTL*d))])

# The angle of a curve on the page, measured in pixels between two of
# its points, so that a label rotated to it runs parallel to the curve.
function page_angle(c, q1, q2)
    p1 = Makie.project(ax.scene, :data, :pixel, Point3f(u(q1), c(q1), 0))
    p2 = Makie.project(ax.scene, :data, :pixel, Point3f(u(q2), c(q2), 0))
    return atan(p2[2] - p1[2], p2[1] - p1[1])
end

text!(ax, u(0.4), cLTLh(0.4); text = "Independent", color = red,
      font = :bold, fontsize = 15,
      rotation = page_angle(cLTLh, 0.35, 0.45),
      align = (:center, :bottom), offset = (-8, 6))
text!(ax, u(0.95), 650; text = "Allocated\ntruckload", color = red,
      font = :bold, fontsize = 15, align = (:center, :center))
text!(ax, u(9.0), cFTL(9.0); text = "Allocated full-truckload",
      color = red, font = :bold, fontsize = 15,
      rotation = page_angle(cFTL, 8.0, 10.0),
      align = (:center, :top), offset = (6, -8))
# The split is a change of scale, not data, so it is named where it is
# drawn rather than left for the caption to explain.
text!(ax, u(QSPLIT), 1.1*3rTL*d; text = "scale changes at 1.5 ton",
      color = (:black, 0.6), fontsize = 12, rotation = pi/2,
      align = (:right, :bottom), offset = (-3, -6))
text!(ax, u(1.25), cLTLh(1.25); text = "LTL", color = olive,
      font = :bold, fontsize = 14, align = (:right, :bottom),
      offset = (-6, 0))
for (k, qk) in zip(1:3, [0.5qmax, 1.5qmax, 2.25qmax])
    text!(ax, u(qk), k*rTL*d; text = "$k TL", color = olive,
          font = :bold, fontsize = 14, align = (:center, :bottom),
          offset = (0, 4))
end
fig
blue = RGBf(0.13, 0.35, 0.60)
red  = RGBf(0.85, 0.10, 0.10)
ink  = RGBf(0.15, 0.15, 0.15)      # the time axis and the labels
tc, τ = 1.0, 0.5                   # cycle and transit time, schematic
XEND = 4tc + τ + 0.3               # three shipments, room for the arrow

fig = Figure(size = (687, 520))
axs = [Axis(fig[k, 1]) for k in 1:3]
for (k, axk) in enumerate(axs)
    # t0, not s: a name assigned in a top-level loop is the global one,
    # and s is the product's density.
    t0 = (k - 1)*tc                # one cycle after the last shipment
    hidedecorations!(axk); hidespines!(axk)
    # the time axis, with an arrowhead
    lines!(axk, [0, XEND - 0.08], [0, 0]; color = ink, linewidth = 2.5)
    scatter!(axk, [XEND - 0.08], [0]; marker = :rtriangle,
             markersize = 16, color = ink)
    # origin: builds from 0 to q while it is produced
    lines!(axk, [t0, t0 + tc], [0, 1]; color = blue, linewidth = 2.6)
    # destination: drawn down from q to 0 while it is consumed
    lines!(axk, [t0 + tc + τ, t0 + 2tc + τ], [1, 0]; color = blue,
           linewidth = 2.6)
    # the average at each end, q/2
    lines!(axk, [t0, t0 + tc], [0.5, 0.5]; color = red, linewidth = 2,
           linestyle = :dash)
    lines!(axk, [t0 + tc + τ, t0 + 2tc + τ], [0.5, 0.5]; color = red,
           linewidth = 2, linestyle = :dash)
    xlims!(axk, -0.35, XEND)
    ylims!(axk, k == 1 ? -0.45 : -0.08, k == 1 ? 1.35 : 1.15)
end
# The first row carries the labels.
ax1 = axs[1]
for (x, a) in ((0.0, :right), (2tc + τ, :left))
    dx = a == :right ? -6 : 6
    text!(ax1, x, 0; text = "0", align = (a, :bottom), fontsize = 15,
          offset = (dx, 2))
    text!(ax1, x, 0.5; text = L"\frac{q}{2}", align = (a, :center),
          fontsize = 17, offset = (dx, 0))
end
# The peak labels sit above the peaks, clear of the lines rising and
# falling into them.
text!(ax1, tc, 1; text = L"q", align = (:center, :bottom), fontsize = 17,
      offset = (0, 12))
text!(ax1, tc + τ, 1; text = L"q", align = (:center, :bottom),
      fontsize = 17, offset = (0, 12))
bracket!(ax1, tc, 1.02, tc + τ, 1.02; text = "In-transit",
         orientation = :down, fontsize = 15, color = ink,
         textcolor = ink)
text!(ax1, tc/2, -0.08; text = "Origin", align = (:center, :top),
      fontsize = 16)
text!(ax1, tc + τ + tc/2, -0.08; text = "Destination",
      align = (:center, :top), fontsize = 16)
# The first row's range is taller, for its labels, so it gets a taller
# row in proportion and every row draws q at the same height.
rowsize!(fig.layout, 1, Auto((1.35 + 0.45)/(1.15 + 0.08)))
rowgap!(fig.layout, 4)
fig
# One regime: how the origin builds a shipment, how the destination
# uses it, and the average (dashed) at each end.
function regime!(axr, prod, cons)
    hidedecorations!(axr); hidespines!(axr)
    lines!(axr, [0, 1.02], [0, 0]; color = ink, linewidth = 2.5)
    scatter!(axr, [1.02], [0]; marker = :rtriangle, markersize = 14,
             color = ink)
    if prod == :constant           # builds steadily over the cycle
        lines!(axr, [0, 0.4], [0, 1]; color = blue, linewidth = 2.6)
        lines!(axr, [0, 0.4], [0.5, 0.5]; color = red, linewidth = 2,
               linestyle = :dash)
        text!(axr, 0, 0.5; text = L"\frac{q}{2}",
              align = (:right, :center), fontsize = 16, offset = (-4, 0))
    else                           # made in one short batch before pickup
        lines!(axr, [0, 0.35], [0.015, 0.015]; color = red,
               linewidth = 2, linestyle = :dash)
        lines!(axr, [0.35, 0.4], [0, 1]; color = blue, linewidth = 2.6)
        text!(axr, 0, 0.015; text = L"\approx 0",
              align = (:right, :bottom), fontsize = 16, offset = (-2, 2))
    end
    if cons == :constant           # drawn down steadily over the cycle
        lines!(axr, [0.56, 0.96], [1, 0]; color = blue, linewidth = 2.6)
        lines!(axr, [0.56, 0.96], [0.5, 0.5]; color = red, linewidth = 2,
               linestyle = :dash)
        text!(axr, 0.96, 0.5; text = L"\frac{q}{2}",
              align = (:left, :center), fontsize = 16, offset = (4, 0))
    else                           # used as soon as it arrives
        lines!(axr, [0.56, 0.61], [1, 0]; color = blue, linewidth = 2.6)
        lines!(axr, [0.61, 0.96], [0.015, 0.015]; color = red,
               linewidth = 2, linestyle = :dash)
        text!(axr, 0.96, 0.015; text = L"\approx 0",
              align = (:left, :bottom), fontsize = 16, offset = (2, 2))
    end
    text!(axr, 0.2, -0.06; text = "$(titlecase(string(prod))) production",
          align = (:center, :top), fontsize = 14)
    text!(axr, 0.78, -0.06;
          text = cons == :constant ? "Constant consumption" :
                                     "Immediate consumption",
          align = (:center, :top), fontsize = 14)
    xlims!(axr, -0.14, 1.12); ylims!(axr, -0.3, 1.05)
    return axr
end

fig = Figure(size = (687, 470))
cases = [(:constant, :constant,
          L"\alpha = \frac{1}{2} + \frac{1}{2} = 1"),
         (:constant, :immediate,
          L"\alpha = \frac{1}{2} + 0 = \frac{1}{2}"),
         (:batch, :constant,
          L"\alpha = 0 + \frac{1}{2} = \frac{1}{2}"),
         (:batch, :immediate, L"\alpha = 0 + 0 = 0")]
for (i, (p, c, lab)) in enumerate(cases)
    regime!(Axis(fig[fld1(i, 2), mod1(i, 2)]; title = lab,
                 titlesize = 17), p, c)
end
fig

# Sec. 3. Inventory cost
# Example 1: Periodic truck shipment from Raleigh to Gainesville
## Example 1(e): Cycle inventory cost at FTL
# Give a reasonable estimate for the total annual cycle inventory cost
# at the FTL shipment size $q_{\max}$, with $v = \$25{,}000$/ton, $h =
# 0.3~\text{yr}^{-1}$, and $\alpha = 1$.
# Code block 5: cycle inventory cost at FTL
α = 1
v = 25000                          # $/ton
h = 0.3                            # 1/yr
@show IC_FTL = α*v*h*qmax          # $/yr

## Example 1(f): Total logistics cost at FTL
# Combine the transport and inventory costs to obtain the annual total
# logistics cost (TLC) for full-truckload TL shipments.
# Code block 6: total logistics cost at FTL
@show TC_FTL                       # $/yr
@show IC_FTL                       # $/yr
@show TLC_FTL = TC_FTL + IC_FTL    # $/yr

# Sec. 4. Optimal shipment size
# Example 1: Periodic truck shipment from Raleigh to Gainesville
## Example 1(g): Optimal TL shipment size
# Allowing shipment sizes less than a full truckload, determine the TL
# shipment size $q_{TL}^{}$ that minimizes the annual TLC for TL
# service, and the resulting $TLC_{TL}^{}$.
# Code block 7: optimal TL shipment size
@show qᵒTL = sqrt((f*rTL*d)/(α*v*h))   # ton
@show TCᵒ_TL = (f/qᵒTL)*rTL*d          # $/yr
@show ICᵒ_TL = α*v*h*qᵒTL              # $/yr
@show TLCᵒ_TL = TCᵒ_TL + ICᵒ_TL        # $/yr

## Example 1(h): Allocated FTL
# Including the minimum-charge and maximum-payload restrictions,
# determine the TLC if a shipment of size $q_{TL}^{*}$ could be made as
# an allocated full-truckload (sharing the truck across many shipments).
# Code block 8: TLC as an allocated full truckload
@show TLC_AllocFTL = f*rTL/qmax*d + α*v*h*qᵒTL   # $/yr

## Example 1(i): Optimal LTL shipment size
# Determine the LTL shipment size $q_{LTL}^{*}$ that minimizes the
# annual TLC for LTL service.
# Code block 9: optimal LTL shipment size
ppiLTL = 177.4                     # LTL PPI for Jan 2018

TLC_LTLh(q) = (f/q) * rate_ltl(q, s, d; ppi=ppiLTL) * q * d +
              α*v*h*q

@show LB = 150/2000                # ton (lower bound on q)
@show UB = min(5, 650*s/2000)      # ton (upper bound on q)
@show qᵒLTL = optimize(TLC_LTLh, LB, UB).minimizer   # ton

## Example 1(j): Service choice
# Given the optimal TL and LTL shipment sizes, determine which service
# minimizes annual TLC.
# Code block 10: TL or LTL at $25,000 per ton
rLTL = rate_ltl(qᵒLTL, s, d; ppi=ppiLTL)
@show rLTL                          # $/ton-mi
@show cLTL     = rLTL * qᵒLTL * d   # $
@show TCᵒ_LTL  = (f/qᵒLTL) * cLTL   # $/yr
@show ICᵒ_LTL  = α*v*h*qᵒLTL        # $/yr
@show TLCᵒ_LTL = TCᵒ_LTL + ICᵒ_LTL  # $/yr

@show TLCᵒ_TL
TLCᵒ_TL > TLCᵒ_LTL ?
    println("LTL selected") : println("TL selected");
# The curves the slides draw, for a product worth v $/ton.
TC_TL(q)  = (f/q)*charge_tl(q, s, d; r = rTL, Kwt = Kwt, Kcu = Kcu,
                            ppi = ppiTL)
TC_LTL(q) = (f/q)*charge_ltl(q, s, d; ppi = ppiLTL)
IC(q, v)  = α*v*h*q
qopt_TL(v)  = sqrt((f*rTL*d)/(α*v*h))
qopt_LTL(v) = optimize(q -> TC_LTL(q) + IC(q, v), LB, UB).minimizer

cred, cblue = RGBf(0.85, 0.10, 0.10), RGBf(0.13, 0.35, 0.60)
cgreen = RGBf(0.10, 0.62, 0.20)

function costcurves!(ax, v)
    qT, qL = qopt_TL(v), qopt_LTL(v)
    rT = range(0.75qL, 1.5qT; length = 400)       # TL curves
    rL = range(0.5qL, 0.99UB; length = 400)
    rI = range(0.5qL, 1.5qT; length = 2)
    TLC_TL(q)  = TC_TL(q) + IC(q, v)
    TLC_LTL(q) = TC_LTL(q) + IC(q, v)
    lines!(ax, rT, TLC_TL; color = cred, linewidth = 2.2)
    lines!(ax, rL, TLC_LTL; color = cred, linewidth = 2.2)
    lines!(ax, rT, TC_TL; color = cblue, linewidth = 2.2)
    lines!(ax, rL, TC_LTL; color = cblue, linewidth = 2.2)
    lines!(ax, rI, q -> IC(q, v); color = cgreen, linewidth = 2.2)
    yT, yL = TLC_TL(qT), TLC_LTL(qL)
    scatter!(ax, [qL, qT], [yL, yT]; color = ink, markersize = 11)
    ax.xticks = ([qL, qT], [@sprintf("%.2f", qL), @sprintf("%.2f", qT)])
    ys = sort([yL, yT])
    ax.yticks = (ys, [commafmt(round(Int, y)) for y in ys])
    # Labels a fixed fraction of the way across the axis.
    x0, x1 = 0.5qL, 1.5qT
    at(p) = x0 + p*(x1 - x0)
    top = max(1.25max(yL, yT), 1.12TLC_LTL(0.99UB))
    lab!(x, y, t, al, o) = text!(ax, x, y; text = t, align = al,
                                 fontsize = 15, color = ink, offset = o)
    # TLC_TL leaves the top of the axis on the left, so its label goes
    # where the curve comes back into view.
    xs = range(at(0.12), x1; length = 400)
    xT = xs[something(findfirst(q -> TLC_TL(q) <= 0.9top, xs), 1)]
    lab!(xT, TLC_TL(xT), L"TLC_{TL}", (:left, :bottom), (6, 2))
    lab!(0.99UB, TLC_LTL(0.99UB), L"TLC_{LTL}", (:right, :bottom), (0, 6))
    lab!(at(0.32), TC_TL(at(0.32)), L"TC_{TL}", (:left, :bottom), (6, 2))
    lab!(at(0.18), TC_LTL(at(0.18)), L"TC_{LTL}", (:right, :top),
         (-2, -6))
    lab!(at(0.35), IC(at(0.35), v), L"IC", (:left, :top), (6, -4))
    xlims!(ax, x0, x1)
    ylims!(ax, IC(x0, v), top)
    return ax
end

fig = Figure(size = (687, 460))
ax = Axis(fig[1, 1]; xlabel = "Shipment size (ton)",
          ylabel = "\$ per year", xlabelsize = 16, ylabelsize = 16,
          xticklabelsize = 14, yticklabelsize = 14)
costcurves!(ax, 25_000)
fig

## Example 1: Periodic truck shipment from Raleigh to Gainesville
# c0, the independent charge of Sec. 2.3's figure, takes the cheaper
# service at every size, so minimizing TLC with it directly faces both
# services' minima at once.
lnTLC0(q, v) = log((f/q)*c0(q) + IC(q, v))

function lnpanel(vi, qhi)
    fig = Figure(size = (340, 380))
    axv = Axis(fig[1, 1]; xlabel = "Shipment size (ton)",
               ylabel = L"\ln TLC_0(q)", xlabelsize = 15,
               ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13)
    qs = range(LB, qhi; length = 1500)
    lines!(axv, qs, q -> lnTLC0(q, vi); color = cblue, linewidth = 2)
    qT, qL = qopt_TL(vi), qopt_LTL(vi)
    scatter!(axv, [qL, qT], [lnTLC0(qL, vi), lnTLC0(qT, vi)];
             color = ink, markersize = 10)
    xlims!(axv, LB, qhi)
    return fig
end
lnpanel(25_000, qmax)
lnpanel(85_000, 1.8qopt_TL(85_000))

## Example 1(k): Service choice at higher product value
# If the unit value of the product rises to $v = \$85{,}000$/ton,
# re-determine the optimal shipment sizes and which service is selected.
# Code block 11: TL or LTL at $85,000 per ton
v = 85000                                           # was 25000

@show qᵒTL    = sqrt((f*rTL*d)/(α*v*h))             # ton
@show TCᵒ_TL  = (f/qᵒTL)*rTL*d                      # $/yr
@show ICᵒ_TL  = α*v*h*qᵒTL                          # $/yr
@show TLCᵒ_TL = TCᵒ_TL + ICᵒ_TL                     # $/yr

@show qᵒLTL = optimize(TLC_LTLh, LB, UB).minimizer  # ton
rLTL = rate_ltl(qᵒLTL, s, d; ppi=ppiLTL)
@show rLTL                                          # $/ton-mi
@show cLTL     = rLTL * qᵒLTL * d                   # $
@show TCᵒ_LTL  = (f/qᵒLTL) * cLTL                   # $/yr
@show ICᵒ_LTL  = α*v*h*qᵒLTL                        # $/yr
@show TLCᵒ_LTL = TCᵒ_LTL + ICᵒ_LTL                  # $/yr
TLCᵒ_TL > TLCᵒ_LTL ?
    println("LTL selected") : println("TL selected");
fig = Figure(size = (687, 420))
for (i, vi) in enumerate((25_000, 85_000))
    axv = Axis(fig[1, i]; xlabel = "Shipment size (ton)",
               ylabel = i == 1 ? "\$ per year" : "",
               title = "($('a' + i - 1)) \$$(commafmt(vi)) per ton",
               titlesize = 16, xlabelsize = 15, ylabelsize = 15,
               xticklabelsize = 13, yticklabelsize = 13)
    costcurves!(axv, vi)
end
fig

## Model: Minimum-TLC shipment size
logjam_rung(:minTLC, "minimum-TLC shipment size")

## Example 1: Periodic truck shipment from Raleigh to Gainesville
# Code block 12: Ex. 1(k) again, with the function
tr = (r = rTL, Kwt = Kwt, Kcu = Kcu, ppi = ppiTL)
sh = DataFrame(f = f, s = s, a = α, v = v, h = h, d = d)
res = minTLC(first(sh), tr, ppiLTL)
@show res.qᵒ                       # ton
@show res.TLCᵒ                     # $/yr
@show res.isLTL                    # LTL selected?

# Sec. 5. Aggregate periodic shipment
# Example 1: Periodic truck shipment from Raleigh to Gainesville
## Example 1(l): A second product
# On Jan 10, 2018, determine the optimal independent shipment size and
# TLC for a second product, 80 ton/yr of Class 60 material worth
# \$5,000/ton, shipped point-to-point from Raleigh to Gainesville, as
# before.
# Code block 13: a second product
push!(sh, first(sh))                     # duplicate the row
sh[2, [:f, :s, :v]] = [80, 32.16, 5000]  # patch the second product
sh.qmax = [maxpayld(row, tr) for row in eachrow(sh)]
transform!(sh, AsTable(:) =>
    ByRow(row -> minTLC(row, tr, ppiLTL)) => AsTable)
prt(sh)

## Example 1(m): Aggregate shipment
# Determine the annual TLC if the two products are always shipped
# together on the same truck, and compare to the sum of their
# independent TLCs.
# Code block 14: the aggregate shipment
@show fagg = sum(sh.f)                   # ton/yr
@show sagg = fagg/sum(sh.f ./ sh.s)      # lb/ft^3
@show vagg = sum(sh.f .* sh.v)/fagg      # $/ton

ash = aggshmt(sh[:, [:f, :s, :a, :v, :h, :d]])   # the same, by Logjam
@show qmax_agg = maxpayld(ash, tr)       # ton
resa = minTLC(ash, tr)                   # TL only
@show TLC_indep = sum(sh.TLCᵒ)           # $/yr, shipped separately
@show TLC_agg = resa.TLCᵒ                # $/yr, shipped together
# Code block 15: the two products and their aggregate, as a table
tdays(q, f) = 365.25q/f            # interval between shipments, days
fmt(x, dg) = x === missing ? "" : @sprintf("%.*f", dg, x)
cm(x) = x === missing ? "" : commafmt(round(Int, x))
rows = [("1", sh.f[1], sh.s[1], sh.v[1], sh.qmax[1], sh.TLCᵒ[1],
         sh.qᵒ[1]),
        ("2", sh.f[2], sh.s[2], sh.v[2], sh.qmax[2], sh.TLCᵒ[2],
         sh.qᵒ[2]),
        ("1 + 2", missing, missing, missing, missing, TLC_indep, missing),
        ("Aggregate", ash.f, ash.s, ash.v, qmax_agg, TLC_agg, resa.qᵒ)]
println("| | \$f\$ | \$s\$ | \$v\$ | \$q_{\\max}\$ | \$TLC\$ | ",
        "\$q^{*}\$ | \$t\$ |")
println("|:--|--:|--:|--:|--:|--:|--:|--:|")
for (lab, f_, s_, v_, qm, tlc, q_) in rows
    t_ = (q_ === missing) ? missing : tdays(q_, f_)
    println("| ", lab, " | ", cm(f_), " | ", fmt(s_, 2), " | ", cm(v_),
            " | ", fmt(qm, 2), " | ", tlc === missing ? "" : usd(tlc),
            " | ", fmt(q_, 2), " | ", fmt(t_, 2), " |")
end
println("\n: The two products shipped separately and as one aggregate: ",
        "\$f\$ in ton/yr, \$s\$ in lb/ft^3^, \$v\$ in \\\$/ton, ",
        "\$q_{\\max}\$ and \$q^{*}\$ in ton, \$TLC\$ in \\\$/yr, and ",
        "the interval \$t\$ in days. ",
        "{#tbl-shipment-economics .dense .fit}\n")

## Example 2: Interval-constrained full truckload
# On average, 200 tons of components are shipped 750 miles from a
# fabrication plant to an assembly plant each year. The components are
# produced and consumed at a constant rate throughout the year.
# Currently, full truckloads of the material are shipped. Determine the
# impact on total annual logistics costs if TL shipments were made every
# two weeks. The revenue per loaded truck-mile is \$2.00; a truck's
# cubic and weight capacities are 3,000 ft^3^ and 24 tons, respectively;
# each ton of the material is valued at \$5,000 and has a density of 10
# lb per ft^3^; the material loses 30% of its value after 18 months; and
# in-transit inventory costs can be ignored.
# Code block 16: TLC of full truckloads
d2 = 750                           # mi
s2 = 10                            # lb/ft^3
Kwt2, Kcu2 = 24, 3000              # ton, ft^3
r2 = 2                             # $/mi
f2 = 200                           # ton/yr
v2 = 5000                          # $/ton
@show hobs2 = 0.3/1.5              # 1/yr: 30% of value lost in 1.5 yr
@show h2 = 0.11 + hobs2            # 1/yr: interest + warehousing 0.11
a2 = 1                             # constant production and consumption
@show qmax2 = maxpayld(s2; Kwt = Kwt2, Kcu = Kcu2)      # ton
@show cFTL2 = charge_tl(qmax2, s2, d2; r = r2,
                        Kwt = Kwt2, Kcu = Kcu2)         # $
@show TLC_FTL2 = totlogcost(qmax2, cFTL2, f2, a2, v2, h2)  # $/yr
# Code block 17: TLC of two-week shipments
@show nFTL2 = f2/qmax2             # TL/yr
@show tmax2 = 2*7/365.25           # yr/TL
@show nmin2 = 1/tmax2              # TL/yr
@show q2wk = f2/max(nFTL2, nmin2)  # ton
@show c2wk = charge_tl(q2wk, s2, d2; r = r2,
                       Kwt = Kwt2, Kcu = Kcu2)          # $
@show TLC_2wk = totlogcost(q2wk, c2wk, f2, a2, v2, h2)   # $/yr
@show ΔTLC = TLC_2wk - TLC_FTL2    # $/yr
