# 3-tran-2 — generated from 3-tran-2.qmd by tools/qmd_to_jl.py
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

using CairoMakie, CSV, DataFrames, Dates, Logjam, Optim, Printf
# Two device pixels per figure unit. The figures are raster PNGs at the
# column's own width, so at 1:1 they are soft beside the MATLAB originals
# he compared them with (instructor, 2026-09-23). Display size is
# unchanged; only the sampling is finer.
CairoMakie.activate!(px_per_unit = 2)
# Thousands separator, so a computed figure can be interpolated into a result
# box instead of hand-typed. Presentation plumbing rather than course content,
# so it sits here rather than in a numbered block.
commafmt(n) = replace(string(n),
    r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")  # 1357 -> "1,357"
usd(x) = commafmt(round(x; digits=2))

## Sec. 2. Design constants
# Colour carries one distinction only: red is the truck, whether it is
# loaded or not. Loaded and empty are told apart by the line style and by
# the L and U labels, the way the slide tells them apart.
truck = RGBf(0.80, 0.11, 0.11)
dist  = RGBf(0.08, 0.10, 0.16)
fillc = RGBf(0.78, 0.92, 0.78)
edgec = RGBf(0.25, 0.55, 0.30)
ink   = RGBf(0.10, 0.12, 0.14)

# EQUAL SCALE ON BOTH AXES IS WHAT MAKES THE GEOMETRY WORK, and leaving it
# out is what put white gaps between the arrows and the nodes: a node is a
# marker sized in PIXELS, so trimming a lane by a radius in DATA units is
# only right when one data unit is the same number of pixels each way.
# DataAspect fixes the ratio; the limits below are chosen to match the
# figure's own so nothing is padded to achieve it.
XLO, XHI, YLO, YHI = -0.10, 5.55, 0.22, 1.36
WIDTH = 687
PXU = WIDTH / (XHI - XLO)          # pixels per data unit, both axes

# (x, y, marker size in px). The free ends of the inbound and outbound
# lanes are not nodes at all, so they have no marker and no radius.
GSO = (0.60, 0.52, 18)
RDU = (1.45, 1.05, 26)
GNV = (3.95, 1.05, 26)
JAX = (4.80, 0.52, 18)
inb = (0.00, 0.97, 0)
out = (5.40, 0.97, 0)

rad(nd) = nd[3] / 2 / PXU          # node radius in data units
HEAD = 12                          # arrowhead marker size, px

# A lane ENDS ON the node outline. `dy` displaces the whole lane
# sideways, which shortens the chord it cuts from a circular node,
# so the trim is the half-chord sqrt(r^2 - h^2) and not r: that is
# the gap on the two
# Raleigh-to-Gainesville edges. The arrowhead is then pulled back by half
# its own height so its TIP lands on the outline rather than inside it.
function lane!(ax, a, b, style; dy = 0.0, lab = "", side = -1)
    L = hypot(b[1] - a[1], b[2] - a[2])
    ux, uy = (b[1] - a[1]) / L, (b[2] - a[2]) / L
    trim(nd) = (r = rad(nd); h = abs(dy * ux);
                r <= h ? 0.0 : sqrt(r^2 - h^2))
    ta, tb = trim(a), trim(b)
    x1, y1 = a[1] + ta*ux, a[2] + ta*uy + dy
    x2, y2 = b[1] - tb*ux, b[2] - tb*uy + dy
    lines!(ax, [x1, x2], [y1, y2]; color = truck, linewidth = 2.0,
           linestyle = style)
    back = HEAD / 2 / PXU
    scatter!(ax, [x2 - back*ux], [y2 - back*uy]; color = truck,
             marker = :utriangle, markersize = HEAD,
             rotation = atan(uy, ux) - pi/2)
    if lab != ""
        # Perpendicular to the lane, so a label can never sit on its own
        # arrow however the lane is angled.
        px, py = -uy, ux
        off = 15 / PXU
        text!(ax, (x1 + x2)/2 + side*px*off, (y1 + y2)/2 + side*py*off;
              text = lab, color = truck, fontsize = 17,
              align = (:center, :center))
    end
end

fig = Figure(size = (WIDTH, round(Int, (YHI - YLO) * PXU)))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
limits!(ax, XLO, XHI, YLO, YHI)

lane!(ax, inb, GSO, :solid; lab = "L", side = -1)   # arrives loaded
lane!(ax, GSO, RDU, :dash;  lab = "U", side = -1)   # repositions empty
lane!(ax, RDU, GNV, :solid; dy = -0.035, lab = "L", side = -1)
lane!(ax, GNV, JAX, :dash;  lab = "U", side =  1)   # repositions empty
lane!(ax, JAX, out, :solid; lab = "L", side = -1)   # away loaded again

# The distance is a fact about the lane rather than a movement of the
# truck, so it is black and unarrowed, above the leg it measures. Same
# half-chord trim, so it meets both nodes as the red lane does.
let dy = 0.035, h = sqrt(rad(RDU)^2 - dy^2)
    lines!(ax, [RDU[1] + h, GNV[1] - h], fill(RDU[2] + dy, 2);
           color = dist, linewidth = 1.6)
end
text!(ax, 2.70, RDU[2] + 0.06; text = "532 mi", color = dist,
      align = (:center, :bottom), fontsize = 14)

for (nd, nm, above) in [(GSO, "Greensboro", false),
                        (RDU, "Raleigh", true),
                        (GNV, "Gainesville", true),
                        (JAX, "Jacksonville", false)]
    scatter!(ax, [nd[1]], [nd[2]]; color = fillc, markersize = nd[3],
             strokecolor = edgec, strokewidth = 1.8)
    text!(ax, nd[1], nd[2] + (above ? 1 : -1) * (rad(nd) + 0.045);
          text = nm, color = ink,
          align = (:center, above ? :bottom : :top), fontsize = 15)
end
fig
# Code block 1: the bottom-up TL cost per mile in 2004
defl = 100/132                     # PPI TL 2004 / PPI TL 2018

prime, over, infl = 0.0475, 0.0200, 0.0270
nom = prime + over                 # nominal interest rate
i   = nom - infl                   # real rate, the cost of capital

N     = 754_000/103_945            # avg mi to replacement / mi per yr
IV    = 175_000*defl               # new tractor-trailer, deflated to 2004
svpct = 0.20
SV    = svpct*IV
IVeff = IV - SV*(1 + i)^(-N)
K     = IVeff * (i / (1 - (1 + i)^(-N)))

mi   = 103_945                     # mi/yr
mpg  = 4.5                         # mi/gal
gal  = 1.78                        # $/gal
fpm  = gal/mpg                     # $/mi
fuel = fpm * mi                    # $/yr
tri  = 0.34 * 2.18 * mi * defl     # $0.34/mi in 1988, up then back
wage = defl * 45_330/(1 - 0.30)    # mean wage, grossed up for benefits
OC   = fuel + tri + wage
cpm  = (OC + K)/mi                 # $/mi, what the table reports

pct(x) = @sprintf("%.2f%%", 100x)
amt(x) = commafmt(round(Int, x))
num(x, d) = @sprintf("%.*f", d, x)

rows = [("**Interest rate**", "", ""),
        ("Prime rate[^cost-prime]", "", pct(prime)),
        ("Increase over prime", "", pct(over)),
        ("Nominal interest rate", "", pct(nom)),
        ("Current inflation rate[^cost-infl]", "", pct(infl)),
        ("Real interest rate", raw"$i$", pct(i)),
        ("**Lease**", "", ""),
        ("Economic life (yr)[^cost-life]", raw"$N$", num(N, 2)),
        (raw"Investment cost (\$)[^cost-iv]", raw"$IV$", amt(IV)),
        ("Salvage percentage", "", pct(svpct)),
        (raw"Salvage value (\$)", raw"$SV$", amt(SV)),
        (raw"Effective investment cost (\$)",
         raw"$IV^{\text{eff}}$", amt(IVeff)),
        (raw"Capital recovery cost (\$/yr)", raw"$K$", amt(K)),
        ("**Costing**", "", ""),
        ("Annual mileage (mi)[^cost-miles]", raw"$q$", amt(mi)),
        ("Fuel efficiency (mi/gal)[^cost-tsw]", "", num(mpg, 1)),
        (raw"Fuel cost per gallon (\$/gal)[^cost-eia]", "", num(gal, 3)),
        (raw"Fuel cost (\$/mi)", "", num(fpm, 4)),
        (raw"Annual fuel cost (\$/yr)", "", amt(fuel)),
        (raw"Tire, repair, insurance (\$/yr)[^cost-tri]", "", amt(tri)),
        (raw"Driver salary with benefits (\$/yr)[^cost-oes]",
         "", amt(wage)),
        (raw"Operating cost (\$/yr)", raw"$OC$", amt(OC)),
        (raw"Operating cost per mile (\$/mi)", "", num(OC/mi, 2)),
        (raw"Annual investment cost (\$/yr)", "", amt(K)),
        (raw"Investment cost per mile (\$/mi)", "", num(K/mi, 2)),
        (raw"**Total annual cost (\$/yr)**", "",
         "**" * amt(OC + K) * "**"),
        (raw"**Cost per mile (\$/mi)**", raw"$AC$",
         "**" * num(cpm, 2) * "**")]

# A group heading sits flush left; everything under it is indented one
# step, which is the shape the spreadsheet has and what makes a
# 27-row table readable as three blocks rather than as one long list.
label(a) = startswith(a, "**") ? "[" * a * "]{.tgroup}" :
                                 "[" * a * "]{.tindent}"

println("| Item | | 2004 |")
println("|:--|:--:|--:|")
for (a, b, c) in rows
    println("| ", label(a), " | ", b, " | ", c, " |")
end
println("\n: The bottom-up estimate of TL cost per mile in 2004. ",
        "{#tbl-tl-cost-2004 .fit}\n")

# Sec. 3. Truckload shipments
# Example 1: Truck shipment from Raleigh to Gainesville
## Example 1(a): Maximum payload
# Assuming that the product is to be shipped P2P TL, determine the
# maximum payload for each trailer used for the shipment.
# Code block 2: density and maximum payload
uwt = 40                           # lb/unit
ucu = 9                            # ft^3/unit
@show s = uwt/ucu                  # lb/ft^3
Kwt = 25                           # ton
Kcu = 2750                         # ft^3
@show qmax = min(Kwt, s*Kcu/2000)  # ton
# = maxpayld(s; Kwt=Kwt, Kcu=Kcu)

## Example 1(b): Number of truckloads
# On Jan 10, 2018, 300 cartons of the product were shipped. Determine
# how many truckloads were required for this shipment.
# Code block 3: shipment size and truckload count
udTL = 300                       # cartons
@show qTL = udTL*(uwt/2000)      # ton
@show nTL = ceil(Int, qTL/qmax)  # truckloads

## Example 1(c): Estimated TL transport charge
# Before contacting the carrier to negotiate, and using the January 2018
# PPI, determine the estimated TL transport charge for this shipment.
# Code block 4: the TL rate and charge at the Jan 2018 index
d = 532                               # mi, Google Maps road distance
ppiTL = 131.0                         # TL PPI for Jan 2018
@show rTL = 2.00ppiTL/102.7           # $/mi
@show cTL = charge_tl(qTL, s, d; r = rTL, Kwt = Kwt,
                      Kcu = Kcu, ppi = ppiTL)  # $

# Sec. 4. Less-than-truckload shipments
# Example 1: Truck shipment from Raleigh to Gainesville
## Example 1(d): Estimated LTL transport charge
# Using the January 2018 PPI LTL rate estimate, determine the transport
# charge to ship 15 cartons LTL.
# Code block 5: the LTL rate estimate and charge
udLTL = 15                                # cartons
@show qLTL = udLTL*(uwt/2000)             # ton
ppiLTL = 177.4                            # LTL PPI for Jan 2018

@show rLTL = rate_ltl(qLTL, s, d; ppi = ppiLTL)    # $/ton-mi
@show cLTL = charge_ltl(qLTL, s, d; ppi = ppiLTL)  # $

## Example 1(e): The shipment size at which the charges are equal
# Determine the shipment size at which the TL and LTL charges are equal.
# Code block 6: the TL/LTL break-even shipment size
cTLh(q)  = charge_tl(q, s, d; r = rTL, Kwt = Kwt,
                     Kcu = Kcu, ppi = ppiTL)
cLTLh(q) = charge_ltl(q, s, d; ppi = ppiLTL)

# The search stops at the rate estimate's own upper bound rather
# than at qmax. Sec. 4.1 gives it as 2000q/s <= 650 ft^3, which for
# this load is 1.44 ton, and `rate_ltl` returns Inf above it rather
# than extrapolating -- so a search over the whole trailer would be
# optimising a constant.
qLTLmax = 650s/2000
gap(q) = abs(cTLh(q) - cLTLh(q))     # zero where the two are equal
@show qI = optimize(gap, 0.075, qLTLmax).minimizer
@show cTLh(qI), cLTLh(qI)  # equal at the crossing
# `charge_tl` and `charge_ltl` ALREADY floor at their minimum
# charges, which are Sec. 4.3's subject, so the independent charge
# is the smaller of the two rather than the smaller of two maxima.
c0h(q) = min(cTLh(q), cLTLh(q))

# From ONE POUND rather than from zero, which is what the example
# asks for. At exactly zero `ceil(0/qmax)` is zero trucks, so the
# TL charge is zero and the curve would drop to the axis; a pound
# in, the left end is the LTL minimum charge.
qs = range(1/2000, 2qI; length = 1200)
fig = Figure(size = (687, 400))
ax = Axis(fig[1, 1];
          xlabel = "Shipment size (ton)",
          ylabel = "Transport charge (\$)",
          title = "Indifference point between TL and LTL",
          titlesize = 17, xlabelsize = 16, ylabelsize = 16,
          xticklabelsize = 14, yticklabelsize = 14)
lines!(ax, qs, c0h.(qs);
       color = RGBf(0.13, 0.35, 0.60), linewidth = 2.2)
# An OPEN circle, as the MATLAB draws it: `plot(qI, c0h(qI), 'ro')`.
# A filled marker of the same colour as the curve is what made the
# point hard to see.
scatter!(ax, [qI], [cTLh(qI)]; color = :white,
         markersize = 13, strokewidth = 2.2,
         strokecolor = RGBf(0.78, 0.16, 0.18))
text!(ax, qI, cTLh(qI); text = "  qI = $(round(qI, digits=4)) ton",
      align = (:left, :top), fontsize = 14,
      color = RGBf(0.78, 0.16, 0.18))
# Both axes start AT zero, so the origin sits in the corner.
# Makie pads by default, which lifts the zero off it and makes
# the two axes look as though they do not meet.
xlims!(ax, 0, 2qI)
# The top is a round number so the tick set lands INSIDE the
# limits and the zero is drawn: with a ragged top Makie drops
# the end ticks, and the one it dropped was the y-axis zero.
ylims!(ax, 0, 1500)
# The zero sits on the corner, as it does on the slide.
ax.xticks = 0:0.5:1.5
ax.yticks = 0:500:1500
fig
# Class and average density, read off the class-density table.
classes = [("Class 300", 2.49), ("Class 100", 9.72),
           ("Class 85", 12.72), ("Class 60", 32.16)]
# The estimate's upper bound is the SMALLER of its weight bound
# and its cube bound, and for a light class the cube one binds
# first: Class 300 stops at 0.81 ton, not at 5.
qtop(sk) = min(5.0, 650sk/2000)

fig = Figure(size = (687, 520))
for (k, (nm, sk)) in enumerate(classes)
    row, col = fldmod1(k, 2)
    ax = Axis(fig[row, col];
              xlabel = "Shipment size (ton)",
              ylabel = "Rate (\$/ton-mi)",
              title = "$nm  ($sk lb/ft³)",
              titlesize = 15, xlabelsize = 14, ylabelsize = 14,
              xticklabelsize = 13, yticklabelsize = 13)
    qmk = min(Kwt, sk*Kcu/2000)          # this class's maximum payload
    rateTL(q)  = ceil(q/qmk) * rTL / q   # $/ton-mi, from the charge
    rateL(q)   = rate_ltl(q, sk, d; ppi = ppiLTL)

    qs = range(0.1, Kwt; length = 3000)
    lines!(ax, qs, rateTL.(qs); color = RGBf(0.13, 0.45, 0.25),
           linewidth = 2.0, label = "TL")
    ql = range(0.1, qtop(sk); length = 1200)
    lines!(ax, ql, rateL.(ql); color = RGBf(0.78, 0.16, 0.18),
           linewidth = 2.0, linestyle = :dashdot, label = "LTL")

    # The equal-rate size, found as qI was: a bounded 1-D search.
    qe = optimize(q -> abs(rateTL(q) - rateL(q)),
                  0.1, qtop(sk)).minimizer
    scatter!(ax, [qe], [rateL(qe)]; color = RGBf(0.20, 0.30, 0.75),
             markersize = 11)
    text!(ax, qe, rateL(qe); text = "  $(round(qe, digits = 1)) ton",
          align = (:left, :bottom), fontsize = 13,
          color = RGBf(0.20, 0.30, 0.75))
    xlims!(ax, 0, Kwt)
    # EACH PANEL GETS ITS OWN y LIMIT. The chapter fixes one scale
    # across all four because its rates are on the 2004 index; on
    # this lecture's January-2018 index the LTL rate for Class 300
    # runs clean off a shared scale and takes its crossing with it,
    # which is a panel that shows nothing.
    ylims!(ax, 0, 2.2 * rateL(qe))
    k == 1 && axislegend(ax; position = :rt, labelsize = 13)
end
fig

## Example 1: Truck shipment from Raleigh to Gainesville
# Code block 7: the three roots of f(x) = x - x^3, found by bracketing
f(x) = x - x^3
g(x) = f(x)^2                            # non-negative, zero at each root
@show optimize(g, -2.0, -0.5).minimizer  # near -1
@show optimize(g, -0.5,  0.5).minimizer  # near  0
@show optimize(g,  0.5,  2.0).minimizer  # near +1

## Example 1(f): TL and LTL minimum charges
# Determine the TL and LTL minimum charges, and account for why neither
# depends on the size of the shipment while only the LTL charge depends
# on its distance.
# Code block 8: the two minimum charges
@show MC_TL  = mincharge_tl(; ppi = ppiTL)      # $
@show MC_LTL = mincharge_ltl(d; ppi = ppiLTL)   # $

## Example 1(g): The independent transport charge
# Determine the independent transport charge over the range of shipment
# sizes from one pound to one and a fifth truckloads, and identify the
# two points at which the governing term changes.
# The two charges already carry their minimum charges, so the
# independent charge is the smaller of them.
c0(q) = min(cTLh(q), cLTLh(q))

# From ONE POUND, which is what the statement asks for and what
# makes the flat left end the LTL minimum charge the result box
# prints. At exactly zero the TL charge is zero trucks.
qs = range(1/2000, 1.2qmax; length = 2400)

# A SPLIT HORIZONTAL AXIS, because on a linear one the whole LTL
# branch is the first 11% of the width and reads as a straight
# line. `u` gives the first ton half the axis and the remaining
# 6.3 tons the other half, so the break-even lands at 40% of the
# width with its curvature intact.
#
# LINEAR INSIDE EACH PIECE, which is the point. c_LTL grows about
# as q^0.85 and is concave; against sqrt(q) that becomes u^1.7 and
# reads as CONVEX. Every smooth transform that expands the low end
# is itself concave, so every one of them bends the curve the
# wrong way. A split scale preserves the shape it separates.
const QSPLIT = 1.0                      # ton, where the axis breaks
u(q) = q <= QSPLIT ? 0.5q/QSPLIT :
       0.5 + 0.5(q - QSPLIT)/(1.2qmax - QSPLIT)

fig = Figure(size = (687, 430))
ax = Axis(fig[1, 1];
          xlabel = "Shipment size (ton)",
          ylabel = "Transport charge (\$)",
          title = "Independent charge: Class 200, 27606 to 32606",
          titlesize = 17, xlabelsize = 16, ylabelsize = 16,
          xticklabelsize = 14, yticklabelsize = 14)
# The seam, drawn faintly so the change of scale is visible
# rather than something the reader has to infer from the ticks.
vlines!(ax, [0.5]; color = (:black, 0.28), linewidth = 1,
        linestyle = :dash)
lines!(ax, u.(qs), c0.(qs);
       color = RGBf(0.13, 0.35, 0.60), linewidth = 2.2)
# Open circles, the MATLAB's own markers: red at the break-even,
# cyan at one truckload.
scatter!(ax, [u(qI)], [c0(qI)]; color = :white, markersize = 13,
         strokewidth = 2.2, strokecolor = RGBf(0.78, 0.16, 0.18))
text!(ax, u(qI), c0(qI); text = "  qI = $(round(qI, digits=3)) ton",
      align = (:left, :bottom), fontsize = 14,
      color = RGBf(0.78, 0.16, 0.18))
scatter!(ax, [u(qmax)], [c0(qmax)]; color = :white, markersize = 13,
         strokewidth = 2.2, strokecolor = RGBf(0.10, 0.55, 0.65))
text!(ax, u(qmax), c0(qmax);
      text = "qmax = $(round(qmax, digits=3)) ton  ",
      align = (:right, :bottom), fontsize = 14,
      color = RGBf(0.10, 0.55, 0.65))
# Both axes start AT zero, so the origin sits in the corner. Makie pads by
# default, which lifts the zero off it (instructor, 2026-09-22).
xlims!(ax, 0, 1)
ylims!(ax, 0, 1.08 * c0(1.2qmax))
# A tick AT zero, so the zero is ON the corner rather than the
# first tick inboard of it: Makie picks its own round numbers
# and skips the endpoint.
# The ticks carry the REAL shipment sizes, placed where the
# split scale puts them, so the axis reads in tons throughout.
xt = [0, 0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7]
lbl(x) = isinteger(x) ? string(Int(x)) : string(x)
ax.xticks = (u.(xt), lbl.(xt))
ax.yticks = 0:1000:3000
fig

# Sec. 5. Freight class and LTL tariffs
# Example 1: Truck shipment from Raleigh to Gainesville
## Example 1(h): Freight class
# Determine the most likely freight class for this LTL shipment.
# Code block 9: freight class from load density
@show s  # lb/ft^3, from code block 2
# Class 200 spans 4 <= s < 5 in the class-density table

## Example 1(i): The undiscounted tariff charge
# Using the same LTL shipment, determine the transport cost found using
# the undiscounted CzarLite tariff, and the weight break between the
# rate breaks at 0.25 and 0.5 tons.
# Code block 10: reading a charge out of the tariff
OD200 = [138.78, 127.69, 99.92, 81.89, 64.47, 47.19, 23.40, 23.40, 23.40]
qB    = [0.25, 0.5, 1, 2.5, 5, 10, 15, 20, Inf]  # ton
MC    = 95.23                                    # $
disc  = 0

@show i    = findfirst(>(qLTL), qB)              # rate break
@show ci   = OD200[i]*20*qLTL                    # $, this break
@show cip1 = OD200[i+1]*20*qB[i]                 # $, next break
@show c_tar = (1 - disc)*max(MC, min(ci, cip1))  # $
# Code block 11: the weight break
@show qW = OD200[i+1]/OD200[i] * qB[i]  # ton

# Sec. 6. Estimate against quote
# Example 1: Truck shipment from Raleigh to Gainesville
## Example 1(j): What the carrier's quote form asks for
# Determine the shipment weight, the carton dimensions and the number
# and height of pallets that an online one-time LTL rate quote requires
# for the same 15-carton shipment.
# Code block 12: the dimensions a spot quote asks for
@show wt = 2000qLTL                 # lb, shipment weight
@show cuin = ucu*12^3               # in^3 per carton -- 24 x 24 x 27
lcart, wcart, hcart = 24, 24, 27    # in, from cuin
@show npall = ceil(Int, udLTL / ((48÷lcart)*(48÷wcart)*2))  # 48x48 pallet
@show hgt = 2*hcart + 5             # in, 5 in. for the empty pallet

## Example 2: Raleigh to Detroit
# Determine the difference in the transport charge to ship 14 cartons of
# a product LTL from Raleigh to Detroit using the undiscounted tariff as
# compared to using the LTL rate estimation formula with a PPI of 184.6.
# Each carton weighs 126 pounds and occupies four cubic feet.
# Code block 13: a higher-density load on a longer lane
uwt2, ucu2, ud2 = 126, 4, 14         # lb, ft^3, cartons
@show s2 = uwt2/ucu2                 # lb/ft^3 -- Class 60
@show q2 = ud2*uwt2/2000             # ton
d2, ppi2 = 691, 184.6                # mi, LTL PPI
MC2 = 95.71                          # $, Ral-Det lane minimum

@show qmax2 = maxpayld(s2; Kwt = Kwt, Kcu = Kcu)  # ton, weighs out
# Code block 14: the tariff charge against the estimate
ODi, ODip1 = 37.11, 30.04  # Ral-Det Class 60 row
@show i2 = findfirst(>(q2), qB)
@show c_tar2 = max(MC2, min(ODi*20*q2, ODip1*20*qB[i2]))
@show c_est2 = charge_ltl(q2, s2, d2; ppi = ppi2)
@show difference = abs(c_tar2 - c_est2)
