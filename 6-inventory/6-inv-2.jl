# 6-inv-2 — generated from 6-inv-2.qmd by tools/qmd_to_jl.py
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
using CairoMakie, DataFrames, Random, Statistics
# Two device pixels per figure unit, as in lectures 3.2 to 6.1, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)

## Sec. 2. Base stock
# Code block 1: base stock's control logic as a flowchart
bluec = colorant"#1f6fb5"               # a determined series, as in 6.1
grayc = colorant"#7f7f7f"               # a neutral step
boc = colorant"#6a3d9a"                 # backorders
# Every symbol in the font of the lecture's equations: italic for a
# letter, upright for its digits and operators
mi = Makie.MathTeXEngine.texfont(:italic)
mr = Makie.MathTeXEngine.texfont(:math)
it(s) = rich(s; font = mi)              # a symbol, in italics
up(s) = rich(s; font = mr)              # digits and operators
sub(b, k) = rich(it(b), subscript(up(k)))   # a symbol, its subscript
function rrect(x, y, w, h, r)           # a rounded box's outline
    c = ((x + w/2 - r, y + h/2 - r, 0), (x - w/2 + r, y + h/2 - r, 90),
         (x - w/2 + r, y - h/2 + r, 180), (x + w/2 - r, y - h/2 + r, 270))
    pts = [Point2f(cx + r*cosd(a), cy + r*sind(a))
           for (cx, cy, a0) in c for a in range(a0, a0 + 90; length = 7)]
    return pts
end
function label!(ax, x, y, s; color = :black, bold = false)
    ls = s isa Vector ? s : [s]         # one line, or several
    for (i, l) in enumerate(ls)
        text!(ax, x, y + 0.21*(length(ls) + 1 - 2i); text = l, color,
              fontsize = 13, align = (:center, :center),
              font = bold ? :bold : :regular)
    end
    return nothing
end
function step!(ax, x, y, s; w = 3.0, h = 1.0, c = bluec)  # an action
    poly!(ax, rrect(x, y, w, h, 0.15); color = :white, strokecolor = c,
          strokewidth = 2)
    return label!(ax, x, y, s)
end
function event!(ax, x, y, s; w = 3.6, h = 0.7)  # an event
    poly!(ax, rrect(x, y, w, h, h/2); color = bluec)
    return label!(ax, x, y, s; color = :white, bold = true)
end
function pause!(ax, x, y, s; w = 3.6, h = 0.7)  # a resting state
    poly!(ax, rrect(x, y, w, h, min(h/2, 0.35)); color = (grayc, 0.15),
          strokecolor = grayc, strokewidth = 2)
    return label!(ax, x, y, s)
end
function ask!(ax, x, y, s; w = 3.4, h = 1.5, c = grayc)  # a decision
    poly!(ax, Point2f[(x - w/2, y), (x, y + h/2), (x + w/2, y),
                      (x, y - h/2)];
          color = :white, strokecolor = c, strokewidth = 2)
    return label!(ax, x, y, s)
end
function flow!(ax, pts...; c = grayc, s = "", at = 1,
               al = (:left, :bottom), off = (8, 3), tip = true)
    xs, ys = [p[1] for p in pts], [p[2] for p in pts]  # a path, an arrow
    n = tip ? length(pts) - 1 : length(pts)
    n > 1 && lines!(ax, xs[1:n], ys[1:n]; color = c, linewidth = 2)
    tip && arrows2d!(ax, [xs[end-1]], [ys[end-1]],
                     [xs[end] - xs[end-1]], [ys[end] - ys[end-1]];
                     color = c, shaftwidth = 2, tipwidth = 10,
                     tiplength = 10)
    isempty(s) && return nothing        # a label beside the path, if any
    text!(ax, pts[at][1], pts[at][2]; text = s, color = c, fontsize = 13,
          align = al, offset = off)
    return nothing
end
function chart(x1, y0, y1)              # a blank canvas, 40 px a unit
    fig = Figure(size = (round(Int, 40x1), round(Int, 40(y1 - y0))),
                 figure_padding = 2)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)
    limits!(ax, 0, x1, y0, y1)
    return fig, ax
end
fig, ax = chart(15.6, 1.65, 9.8)
xl, xr, xo = 2.7, 11.0, 7.0             # demand, replacement, stockout
flow!(ax, (5.4, 8.99), (5.4, 8.7), (xl, 8.7), (xl, 8.35))
flow!(ax, (10.2, 8.99), (10.2, 8.7), (xr, 8.7), (xr, 8.35))
pause!(ax, 7.8, 9.35, rich("Start: ", it("q"), up(" = "),
                           sub("q", "max"), " on hand, ", it("b"),
                           up(" = 0"), " backorders"); w = 7.2, h = 0.72)
flow!(ax, (xl, 7.65), (xl, 7.3))        # a demand arrives
flow!(ax, (xl, 5.8), (xl, 5.45); s = "yes", at = 2)
flow!(ax, (xl, 4.45), (xl, 3.9))
flow!(ax, (xl, 3.1), (xl, 2.45))
flow!(ax, (xl + 1.7, 6.55), (xo, 6.55), (xo, 5.45); s = "no")
flow!(ax, (xo + 0.9, 4.45), (xo + 0.9, 2.1), (xl + 2.2, 2.1);
      c = bluec, s = "lost sales", al = (:left, :top), off = (6, -3))
flow!(ax, (xo - 0.9, 4.45), (xo - 0.9, 3.5), (xl + 1.95, 3.5);
      c = boc, s = "backorders", al = (:right, :top), off = (-6, -3))
event!(ax, xl, 8.0, "A demand arrives"; w = 3.7)
ask!(ax, xl, 6.55, ["On hand?", L"q > 0"])
step!(ax, xl, 4.95, ["Sell a unit", L"q - 1"])
step!(ax, xl, 3.5, "Order a replacement"; w = 3.9, h = 0.8)
pause!(ax, xl, 2.1, "Wait for the next event"; w = 4.4)
step!(ax, xo, 4.95, ["Out of stock: a lost sale,",
                     rich("or a backorder, ", it("b"), up(" + 1"))];
      w = 4.4, c = grayc)
flow!(ax, (xr, 7.65), (xr, 7.3))        # a replacement arrives
flow!(ax, (xr, 5.8), (xr, 5.45); c = boc, s = "yes", at = 2)
flow!(ax, (xr + 1.7, 6.55), (14.0, 6.55), (14.0, 5.45); s = "no")
flow!(ax, (xr, 4.45), (xr, 3.85))
flow!(ax, (14.0, 4.45), (14.0, 3.5), (xr + 2.2, 3.5))
event!(ax, xr, 8.0, "A replacement arrives"; w = 4.4)
ask!(ax, xr, 6.55, ["Waiting?", L"b > 0"]; c = boc)
step!(ax, xr, 4.95, ["Fill a backorder", L"b - 1"]; w = 3.1, c = boc)
step!(ax, 14.0, 4.95, ["Put on hand", L"q + 1"]; w = 2.6)
pause!(ax, xr, 3.5, "Wait for the next event"; w = 4.4)
fig
# Code block 2: the simulation loop around its event calendar
fig, ax = chart(15.6, 1.2, 9.85)
xm, xc = 4.3, 13.6                      # main column, the calendar
flow!(ax, (xm, 8.825), (xm, 8.35))
flow!(ax, (xm, 7.05), (xm, 6.65))
flow!(ax, (xm + 1.4, 6.05), (7.7, 6.05); s = "yes")
flow!(ax, (xm, 5.45), (xm, 5.05); s = "no", at = 2)
flow!(ax, (xm, 3.55), (xm, 2.95); s = "demand", at = 2)
flow!(ax, (xm + 1.8, 4.3), (7.9, 4.3); s = "arrival")
flow!(ax, (xm - 3.3, 2.25), (0.3, 2.25); tip = false)  # back to the top
flow!(ax, (9.6, 3.8), (9.6, 1.35), (0.3, 1.35), (0.3, 7.7), (1.1, 7.7))
flow!(ax, (xm + 3.3, 2.25), (xc, 2.25), (xc, 4.25); c = bluec,
      s = "new events in", at = 2, al = (:right, :bottom), off = (-8, 3))
flow!(ax, (xc - 1.65, 7.7), (xm + 3.2, 7.7); c = bluec,
      s = "earliest out", al = (:right, :bottom), off = (-8, 3))
pause!(ax, xm, 9.3, [rich("Start: clock ", it("t"), up(" = 0"), ", ",
                          it("q"), up(" = "), sub("q", "max"),
                          " on hand,"),
                     rich("the first demand in the calendar ", it("E"))];
       w = 7.6, h = 0.95)
step!(ax, xm, 7.7, [rich("Take the earliest event out of ", it("E")),
                    rich("add ", it("q"), up(" × "), "(its time ",
                         up("−"), " ", it("t"), ") to ", it("A")),
                    rich("clock ", it("t"), " to its time")];
      w = 6.4, h = 1.3)
ask!(ax, xm, 6.05, L"t > T\,?"; w = 2.8, h = 1.2)
stop = L"\pi_0 = n_{\mathrm{out}} / n_{\mathrm{d}}, \; \bar{q} = A / T"
step!(ax, 9.6, 6.05, ["Stop", stop]; w = 3.8, c = grayc)
ask!(ax, xm, 4.3, ["Demand or", "arrival?"]; w = 3.6, h = 1.5)
step!(ax, xm, 2.25, [rich(sub("n", "d"), up(" + 1"),
                          ", the next demand into ", it("E"), ","),
                     "then the control logic for a demand,",
                     rich("a stockout adding 1 to ", sub("n", "out"))];
      w = 6.6, h = 1.4)
step!(ax, 9.6, 4.3, ["Control logic", "for an arrival"]; w = 3.4)
poly!(ax, rrect(xc, 6.1, 3.3, 3.7, 0.15); color = (bluec, 0.08),
      strokecolor = bluec, strokewidth = 2)   # the calendar
text!(ax, xc, 7.65; text = rich("Event calendar ", it("E")),
      fontsize = 13, font = :bold, color = bluec,
      align = (:center, :center))
for (i, (k, s)) in enumerate([("1", "demand"), ("2", "arrival"),
                              ("3", "arrival"), ("4", "arrival")])
    y = 7.65 - 0.62i
    lines!(ax, [xc - 1.45, xc + 1.45], [y + 0.31, y + 0.31];
           color = bluec, linewidth = 1)
    text!(ax, xc, y; text = rich(sub("t", k), "   ", s), fontsize = 13,
          align = (:center, :center))
end
text!(ax, xc, 4.55; text = "earliest first", fontsize = 13,
      color = bluec, align = (:center, :center))
fig

# Sec. 2. Base stock
## Model: Base stock with backorders
# Model: base stock with lost sales or backorders, by simulation
# Event by event: fraction out of stock per demand, average on hand,
# and fraction of the time with none on hand
schedule!(E, t, evt) =          # put an event into E, in time order
    insert!(E, searchsortedfirst(E, (t, evt)), (t, evt))

function base_stock(qmax, sch, t_stop; backorder = false)
# sch[1] gives the time of the next demand and sch[2] the time a
# replacement arrives, so any demand and any lead time are a change to the
# schedule alone, never to the simulation.
    E = [(0.0, :demand)]          # event calendar (time, kind)
    q, b = qmax, 0                # state: units on hand, backorders
    t₀, A, A0 = 0.0, 0.0, 0.0     # clock, area under q(t), time at 0
    nd, nout = 0, 0               # demands, and those out of stock
    while !isempty(E)
        t, evt = popfirst!(E)     # the earliest event, out of E
        A += q*(min(t, t_stop) - t₀)  # units on hand × time since last
        A0 += (q == 0)*(min(t, t_stop) - t₀)  # time with none
        # The time with none on hand is summed the way the area is, so
        # none is the fraction of the time with none on hand, the clock's
        # stockout probability of @tbl-who-looks, beside $\pi_0$, the
        # customers'.
        t > t_stop && break       # stop the simulation at T = t_stop
        t₀ = t                    # the clock to the event's time
        if evt == :demand
            nd += 1
            schedule!(E, sch[1](t), :demand)
            if q > 0              # a sale, and its replacement ordered
                q -= 1
                schedule!(E, sch[2](t), :arrival)
            else                  # out of stock
                nout += 1
                if backorder
                # With backorders, a demand that finds none on hand waits
                # and its replacement is ordered at once, and the next
                # replacement to arrive fills it instead of going on hand;
                # with lost sales nothing is ordered. Either way the
                # demand is counted out of stock, so $\pi_0$ is the
                # fraction backordered or the fraction lost.
                    b += 1
                    schedule!(E, sch[2](t), :arrival)
                end               # otherwise a lost sale
            end
        elseif b > 0              # a replacement fills a backorder
            b -= 1
        else                      # a replacement goes on hand
            q += 1
        end
    end
    # per demand, over time, and over the time with none on hand
    return (π₀ = nout/nd, q̄ = A/t_stop, none = A0/t_stop)
end

# Example 1: Base stock by simulation
## Example 1(a): One level
# Simulate the policy at $q_{\max} = 3$ with lost sales and with
# backorders, and measure the fraction out of stock and the average on
# hand of each.
# Code block 3: the item's data and the two schedulers
using Logjam                      # for prt, a labeled table
using Random
ra = 6                            # units/period, demand arrival rate
te = 1/8                          # period, lead time
p = 6                             # $/unit, unit price
c = 3                             # $/unit, unit cost
h = 0.3                           # 1/period, inventory carrying rate
g = 4                             # 1/period, delay discount factor
Random.seed!(1234)                # reproducible draws
demand(t) = t - log(rand())/ra    # time of the next demand
arrival(t) = t + te               # time a replacement arrives
sch = [demand, arrival]
# Code block 4: the first events, and the calendar after each
function base_stock_log(qmax, sch, t_stop)  # base_stock, recorded
    E = [(0.0, :demand)]          # event calendar (time, kind)
    q, o = qmax, 0                # units on hand, units on order
    rec = []                      # (time, kind, lost, q, o, calendar)
    while !isempty(E)
        t, evt = popfirst!(E)     # the earliest event, out of E
        t > t_stop && break       # stop the simulation at t_stop
        lost = false              # a demand that finds none on hand
        if evt == :demand
            schedule!(E, sch[1](t), :demand)
            if q > 0              # a sale, and its replacement ordered
                q, o = q - 1, o + 1
                schedule!(E, sch[2](t), :arrival)
            else                  # a lost sale
                lost = true
            end
        else                      # a replacement arrives
            q, o = q + 1, o - 1
        end
        push!(rec, (; t, evt, lost, q, o, E = copy(E)))
    end
    return rec
end
t3(t) = rpad(round(t, digits = 3), 5, "0")   # a time to 3 decimals
cal(E) = join([(k == :demand ? "d " : "a ") * t3(t) for (t, k) in E],
              ", ")                         # the calendar, earliest first
Random.seed!(1234)                # the draws of Code block 3
rec = base_stock_log(3, sch, 0.6) # every event up to time 0.6
kind = [r.lost ? "demand, lost" : string(r.evt) for r in rec]
prt(DataFrame(time = t3.(getfield.(rec, :t)), event = kind,
              q = getfield.(rec, :q), o = getfield.(rec, :o),
              calendar = cal.(getfield.(rec, :E))))
# Code block 5: the simulation at q_max = 3, both models
t_stop = 100_000.0                # periods simulated, T
Random.seed!(1234)                # the draws of Code block 3, anew
pi0sim, qbarsim, nonesim = base_stock(3, sch, t_stop)
TPsim = (p - c)*(1 - pi0sim)*ra - c*h*qbarsim
Random.seed!(1234)                # the same demands, now backordered
pi0bo, qbarbo, nonebo = base_stock(3, sch, t_stop; backorder = true)
TPbosim = (p - c)*(1 - pi0bo*g*te)*ra - c*h*qbarbo
prt(DataFrame(stockout = ["lost sale", "backorder"],
              pi0 = [pi0sim, pi0bo], none = [nonesim, nonebo],
              qbar = [qbarsim, qbarbo], TP = [TPsim, TPbosim]))
# Code block 6: units on hand and on order add up to q_max
onorder = (1 - pi0sim)*ra*te    # units, throughput × lead time
qbarsim + onorder               # units
# Code block 7: units on hand and on order over one period
givc = colorant"#d21f26"          # a given series, as in 6.1
ordc = colorant"#e08a1e"          # units on order
Random.seed!(1234)                # the draws of Code block 3
rec = base_stock_log(3, sch, 3.0) # Code block 4's recorder
ts = [getfield.(rec, :t); 3.0]    # event times, held to time 3
qs = [getfield.(rec, :q); rec[end].q]   # units on hand
os = [getfield.(rec, :o); rec[end].o]   # units on order
lost = [r.t for r in rec if r.lost]     # times of lost sales
fig = Figure(size = (600, 330))
ax = Axis(fig[2, 1]; xlabel = "Time (periods)", ylabel = "Units",
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13, yticks = 0:3)
h_ord = stairs!(ax, ts, os; step = :post, color = ordc, linewidth = 2.5)
h_on = stairs!(ax, ts, qs; step = :post, color = bluec, linewidth = 2.5)
h_max = hlines!(ax, [3]; color = givc, linestyle = :dash, linewidth = 2)
h_lost = scatter!(ax, lost, zeros(length(lost)); marker = :xcross,
                  color = :black, markersize = 14)
xlims!(ax, 2, 3)
ylims!(ax, -0.25, 3.25)
Legend(fig[1, 1], [h_on, h_ord, h_max, h_lost],
       ["On hand", "On order", "Maximum level, 3", "Lost sale"];
       orientation = :horizontal, framevisible = false, labelsize = 13,
       padding = (0, 0, 0, 0))
fig

## Example 1(b): Every level and the best
# Determine the best maximum inventory level of each model by
# simulation.
# Code block 8: the best level by simulation, on one stream of demands
UBqmax = 2round(Int, ra)        # units, the upper bound on q_max
qmax = 0:UBqmax                 # units, maximum levels tried
function simTP(q; leadtime = r -> te,   # simulated TP at level q
               demand = (t, r) -> t - log(rand(r))/ra,
               backorder = false)
    rng1 = Xoshiro(1234)            # same demands at each level
    # Xoshiro(1234) creates a random number generator of its own, a stream
    # of random numbers started from the seed 1234, apart from the one
    # Random.seed! starts. Each call starts both streams from the same
    # seeds, so every level sees the same customers and the same lead
    # times, and a difference between two levels is the policy's, not the
    # draw's.
    rng2 = Xoshiro(5678)            # and the same lead times
    sch = [t -> demand(t, rng1), t -> t + leadtime(rng2)]
    π₀, q̄ = base_stock(q, sch, t_stop; backorder)
    lost = backorder ? π₀*g*te : π₀     # share of profit lost on demand
    return (p - c)*(1 - lost)*ra - c*h*q̄
end
TPᵒsim, qmaxᵒsim = maximum((simTP(q), q) for q in qmax)
TPᵒbosim, qmaxᵒbosim = maximum((simTP(q; backorder = true), q)
                               for q in qmax)

# Example 2: Demand during a lead time
## Example 2(b): In code
# Compute the same probabilities in Julia and compare them with Ex.
# 2(a).
# Code block 9: F(k; μ), the probability of k or fewer, Poisson mean μ
function poissoncdf(k, μ)
    pj = exp(-μ)                  # Pr(D_L = 0)
    F = pj                        # F(0; μ)
    for j in 1:k
        pj *= μ/j                 # Pr(D_L = j), from Pr(D_L = j - 1)
        F += pj                   # F(j; μ), from F(j - 1; μ)
    end
    return F
end
# Code block 10: demand during a lead time
ra = 6                          # units/period, demand arrival rate
te = 1/8                        # period, lead time
μ = ra*te                       # units, mean demand during a lead time
k = 0:3                         # demands during a lead time

pk = exp(-μ) .* μ.^k ./ factorial.(k)  # Pr(D_L = k)
F = poissoncdf.(k, μ)                  # F(k; μ)
prt([pk F]; rows = k, cols = ["pk", "F"], row_title = "k",
    fracdig = 5, allfrac = 5)
# Code block 11: Pr(D_L = k) and F(k; μ) for up to six demands
cdfc = colorant"#1e8a3c"                 # a cumulative probability
kk = 0:6                                 # demands during a lead time
pk = exp(-μ) .* μ.^kk ./ factorial.(kk)  # Pr(D_L = k)
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = L"\text{Demands during a lead time, } k",
          ylabel = "Probability", xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13, xticks = kk)
barplot!(ax, kk, pk; color = bluec, label = L"\Pr(D_L = k)")
scatterlines!(ax, kk, poissoncdf.(kk, μ); color = cdfc,
              markersize = 8, label = L"F(k;\,\mu)")
lbl = string.(round.(pk[1:4], digits = 3))
text!(ax, kk[1:3], pk[1:3]; text = lbl[1:3], color = :white,
      align = (:center, :top), offset = (0, -4), fontsize = 13)
text!(ax, kk[4], pk[4]; text = lbl[4], align = (:center, :bottom),
      offset = (0, 3), fontsize = 13)
ylims!(ax, 0, 1.12)
axislegend(ax; position = :rc, labelsize = 13)
fig

## Sec. 2. Base stock
# Code block 12: the units on hand, unit by unit and outcome by outcome
qm = 3                          # units, the maximum level of Ex. 3(a)
ds = 0:qm-1                     # demands during a lead time, below qm
pd = [exp(-μ)*μ^d/factorial(d) for d in ds]  # Pr(D_L = d)
pd = [pd; 1 - sum(pd)]          # and Pr(D_L ≥ qm), the last column
x0 = [0; cumsum(pd)]            # each column's left edge
Fj = poissoncdf.(0:qm-1, μ)     # Pr(unit j on hand) = F(j - 1)
units = ["Unit 1, sold first"; ["Unit $j" for j in 2:qm-1];
         "Unit $qm, sold last"]
fig = Figure(size = (620, 330))
ax = Axis(fig[1, 1]; yreversed = true, xlabelsize = 15,
          xlabel = L"\text{Demand during a lead time, } D_L",
          xticks = ((x0[1:end-1] .+ x0[2:end])./2,
                    [string.(ds); "$(qm)+"]),
          yticks = (1:qm, units), xticklabelsize = 13,
          yticklabelsize = 13, xgridvisible = false,
          ygridvisible = false, xticksvisible = false,
          yticksvisible = false)
hidespines!(ax)
for j in 1:qm, d in 0:qm        # unit j is on hand when D_L ≤ j - 1
    on = d ≤ j - 1
    poly!(ax, Rect(x0[d+1], j - 0.42, pd[d+1], 0.84);
          color = on ? (bluec, 0.35) : :white,
          strokecolor = on ? bluec : (grayc, 0.6), strokewidth = 1)
end
xr = 1.40                       # the right edge of the addition
for j in 1:qm                   # each row's shaded length, F(j - 1)
    Fs = round(Fj[j], digits = 4)
    op = j == 1 ? "" : "+\\;"
    text!(ax, xr, j; text = L"%$op F(%$(j-1)) = %$Fs",
          align = (:right, :center), fontsize = 13)
    lines!(ax, [1.01, 1.09], [j, j]; color = grayc, linestyle = :dot)
end
inkc = colorant"#252525"        # the rule under the addition
lines!(ax, [1.10, xr], fill(qm + 0.5, 2); color = inkc, linewidth = 1)
qb = round(sum(Fj), digits = 4) # the shaded area, the rows added up
text!(ax, xr, qm + 0.82; align = (:right, :center), fontsize = 13,
      color = bluec, text = L"\text{sum} = \bar{q}(%$qm) = %$qb")
pq = round(pd[end], digits = 4) # none on hand, the last row's end
text!(ax, 1, qm + 0.6; align = (:right, :center), fontsize = 13,
      text = L"\Pr(D_L \geq %$qm) = %$pq")
xlims!(ax, 0, 1.42)
ylims!(ax, qm + 1.05, 0.5)
fig
# Code block 13: units on hand with a demand exactly every 1/6 period
evenly(t) = t + 1/ra              # the next demand, 1/6 period later
reg = base_stock_log(1, [evenly, arrival], 1.0)   # demands, no draws
tr = [getfield.(reg, :t); 1.0]    # event times, held to time 1
qr = [getfield.(reg, :q); reg[end].q]   # units on hand
sales = [r.t for r in reg if r.evt == :demand]  # every demand a sale
none = [(tr[i], tr[i+1]) for i in 1:length(qr)-1 if qr[i] == 0]
fr = base_stock(1, [evenly, arrival], t_stop)   # over T = t_stop
pn = round(Int, 100fr.none)       # %, of the time with none on hand
pc = round(Int, 100fr.π₀)         # %, of the demands that find none
fig = Figure(size = (600, 270))
ax = Axis(fig[2, 1]; xlabel = "Time (periods)", ylabel = "Units",
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13, yticks = 0:1)
h_none = vspan!(ax, first.(none), last.(none); color = (grayc, 0.25))
h_on = stairs!(ax, tr, qr; step = :post, color = bluec, linewidth = 2.5)
h_dem = scatter!(ax, sales, fill(-0.12, length(sales));
                 marker = :utriangle, color = givc, markersize = 12)
xlims!(ax, -0.03, 1.03)
ylims!(ax, -0.3, 1.25)
Legend(fig[1, 1], [h_on, h_none, h_dem],
       ["On hand", "None on hand, $pn% of the time",
        "Demand, $pc% find none"];
       orientation = :horizontal, framevisible = false, labelsize = 13,
       padding = (0, 0, 0, 0))
fig

## Model: Base stock with backorders
# Model: base stock with lost sales, Poisson demand, constant lead time
# Fraction out of stock, average on hand, total profit, best level
pi0(qmax, μ) = qmax == 0 ? 1.0 : 1 - poissoncdf(qmax - 1, μ)
# With $q_{\max} = 0$ nothing is ever on hand, so every demand is out of
# stock and $\pi_0 = 1$, set directly since $F(-1; \mu)$ is not defined.
qbar(qmax, μ) = sum(poissoncdf(k, μ) for k in 0:qmax-1; init = 0.0)
TP(qmax; h = h, ra = ra, μ = μ) =
# The carrying rate, arrival rate and mean demand during a lead time are
# keyword arguments, each the example's value unless another is given, as
# Ex. 8 gives another arrival rate.
    (p - c)*(1 - pi0(qmax, μ))*ra - c*h*qbar(qmax, μ)
maxTP(qmaxs; h = h, ra = ra, μ = μ) =
# Each level is tried in turn and the one with the largest total profit is
# kept, the brute force of Lecture 6.1's one-time model ({{< xref 6.1
# mdl-safety1 >}}).
    maximum((TP(q; h, ra, μ), q) for q in qmaxs)
# Model: base stock with backorders, Poisson demand, constant lead time
# Total profit with the delay discount on the fraction backordered
TPbo(qmax; g = g) =
# pi0 and qbar are those of @mdl-basestock's implementation for Poisson
# demand, exact here, since every stockout is backordered. The delay
# discount factor is a keyword argument, the example's unless another is
# given, as Ex. 3(c) gives others.
    (p - c)*(1 - pi0(qmax, μ)*g*te)*ra - c*h*qbar(qmax, μ)

# Example 3: Base stock with Poisson demand
## Example 3(b): Every level and the best
# Determine the total profit of each maximum level from 0 to the upper
# bound of @eq-qmax-ub with lost sales and with backorders, and the
# level that maximizes each.
# Code block 14: total profit at each maximum level, both models
p = 6                           # $/unit, unit price
c = 3                           # $/unit, unit cost
h = 0.3                         # 1/period, inventory carrying rate
g = 4                           # 1/period, delay discount factor
UBqmax = 2round(Int, ra)        # units, the upper bound on q_max
qmax = 0:UBqmax                 # units, maximum levels tried
prt(hcat(poissoncdf.(qmax, μ), pi0.(qmax, μ), qbar.(qmax, μ),
         TP.(qmax), TPbo.(qmax));
    rows = qmax, cols = ["F", "pi0", "qbar", "TP", "TPbo"],
    row_title = "qmax", fracdig = 5, allfrac = 5)
# Code block 15: the best levels, and their shares of perfect prediction
TPᵒ, qmaxᵒ = maxTP(qmax)                          # lost sales
TPboᵒ, qmaxboᵒ = maximum((TPbo(q), q) for q in qmax)  # backorders
TPub = (p - c)*ra               # $/period, all demand sold, none held
TPᵒ/TPub, TPboᵒ/TPub
# Code block 16: total profit, lost profit and carrying cost against q_max
optc = colorant"#b23a48"                # an optimum, as in Lecture 6.1
tpbc = colorant"#e08a1e"                # total profit with backorders
dcc = colorant"#1e8a3c"                 # carrying cost
LP(q) = (p - c)*pi0(q, μ)*ra            # $/period, lost profit
CC(q) = c*h*qbar(q, μ)                  # $/period, carrying cost
fig = Figure(size = (600, 390))
ax = Axis(fig[1, 1]; xlabel = "Maximum inventory level (units)",
          ylabel = "\$ per period", xlabelsize = 15, ylabelsize = 15,
          xticklabelsize = 13, yticklabelsize = 13)
scatterlines!(ax, qmax, TPbo.(qmax); color = tpbc, marker = :diamond,
              label = "Total profit, backorders")
scatterlines!(ax, qmax, TP.(qmax); color = bluec,
              label = "Total profit, lost sales")
scatterlines!(ax, qmax, LP.(qmax); color = grayc, marker = :utriangle,
              linestyle = :dash, label = "Lost profit")
scatterlines!(ax, qmax, CC.(qmax); color = dcc, marker = :rect,
              linestyle = :dash, label = "Carrying cost")
scatter!(ax, [qmaxᵒ, qmaxboᵒ], [TPᵒ, TPboᵒ]; color = optc,
         markersize = 16, strokecolor = :white, strokewidth = 1.5)
Legend(fig[2, 1], ax; orientation = :horizontal, nbanks = 2,
       labelsize = 13, framevisible = false)   # below, clear of the lines
fig

## Example 3(c): A cheaper backorder
# Determine how small the delay discount factor, and with it the cost of
# a backorder, can get before the best level with backorders falls from
# 3 to 2.
# Code block 17: the delay discount at which the best level falls to 2
dTP = (p - c)*ra*te*(pi0(2, μ) - pi0(3, μ))  # $/period per unit of g
dCC = c*h*(qbar(3, μ) - qbar(2, μ))          # $/period, carrying a 3rd
gstar = dCC/dTP                              # 1/period
(maximum((TPbo(q; g = 2.8), q) for q in qmax),
 maximum((TPbo(q; g = 3.0), q) for q in qmax))

## Sec. 2. Base stock
# Code block 18: the bootstrap, a draw from the data with replacement
function bootstrap(x)              # a sampler for the data x
    n = length(x)                  # items in the data
    return r -> x[rand(r, 1:n)]    # one item, each equally likely
    # The sampler takes a stream of random numbers r and draws one item:
    # rand(r, 1:n) picks a position from 1 to $n$, every one equally
    # likely, and nothing is taken out of x, so the item drawn is in
    # effect put back and can be drawn again. Taking a stream r, as the
    # lead time of simTP does (Code block 8), is what lets it plug into
    # the simulation as it is.
end
# Code block 19: the bootstrap on the bakery's 13 days
using Statistics
d = [237, 214, 161, 146, 331, 159, 423, 332, 139, 327, 152, 98,
     116]                         # loaves/day, Lecture 6.1's 13 days
day = bootstrap(d)                # a day's loaves, drawn from the 13
rng = Xoshiro(1234)               # its own stream of random numbers
many = [day(rng) for _ in 1:100_000]                # 100,000 days drawn
share = [count(==(dᵢ), many) for dᵢ in d]/length(many)
# ==(dᵢ) is a function that tests whether its argument equals day $i$'s
# loaves, dᵢ, and count counts the draws for which it is true; divided by
# the number of draws, each count is that day's share of them.
prt([d fill(1/13, 13) share; NaN mean(d) mean(many)]; fracdig = 4,
    rows = [string.(1:13); "Average loaves"], row_title = "Day",
    cols = ["Loaves", "Share of the 13", "Share of the draws"])

# Example 4: Lee's new recipe
## Example 4(a): The best base stock level
# Determine the best base stock level, simulated on the 13 days
# bootstrapped, and whether the new recipe earns more than the old.
# Code block 20: Lee's days bootstrapped into a schedule of demands
N = 2_000                         # days simulated
rng = Xoshiro(1234)               # its own stream of random numbers
n = [day(rng) for _ in 1:N + 1]   # each day's demand, one of the 13
T = sort!([k + rand(rng) for k in 0:N for _ in 1:n[k + 1]])
# Day $k$, counted from 0, runs from time $k$ to $k + 1$, and each of its
# n[k + 1] demands is put at k + rand(rng), a time drawn at random within
# it; sort! puts the demands of all the days in time order.
lee(t) = T[searchsortedlast(T, t) + 1]   # next demand after t
# searchsortedlast(T, t) is the position in T of the last demand at or
# before time t, so the next demand is the one after it. lee is the first
# of base_stock's two schedulers, sch[1], in place of Code block 3's
# demand.
# Code block 21: the best level, by base_stock on Lee's days
pL, cL = 5, 1                     # $/loaf, price and cost (Lecture 6.1)
xh, th = 0.1, 1                   # price lost, a tenth in a day
hL = xh/th                        # 1/day, carrying rate, obsolescence
lead = 1                          # day, to produce a loaf
rL = mean(d)                      # loaves/day, demand arrival rate
function TPlee(S, sch)            # $/day, total profit at level S
    π₀, q̄ = base_stock(S, sch, N) # Model 1's simulation, as it stands
    return (pL - cL)*(1 - π₀)*rL - pL*hL*q̄  # carrying cost on price
end
Slev = 0:10:2round(Int, rL)       # loaves, the levels tried
TPrec = [TPlee(S, [lee, t -> t + lead]) for S in Slev]
TPᵒrec, Sᵒrec = maximum(zip(TPrec, Slev))
q61 = 331                         # loaves a morning, 6.1 Ex. 6(c)
TPold = mean(pL*min(q61, x) - cL*q61 for x in n[1:N])  # $/day
(S = Sᵒrec, TP = round(TPᵒrec, digits = 2),
 TP_old = round(TPold, digits = 2))

## Example 4(b): Assuming Poisson demand
# Determine the level a Poisson of the same mean would choose, and its
# actual total profit on Lee's days.
# Code block 22: the same search with Poisson demand of the same mean
function TPleeP(S)                # $/day at level S, Poisson demand
    r = Xoshiro(1234)             # the same demands at every level
    return TPlee(S, [t -> t - log(rand(r))/rL, t -> t + lead])
end
TPrecP = [TPleeP(S) for S in Slev]            # $/day, Poisson demand
TPᵒrecP, SᵒrecP = maximum(zip(TPrecP, Slev))
TPP = TPrec[findfirst(==(SᵒrecP), Slev)]      # $/day, on Lee's days
(S = SᵒrecP, predicted = round(TPᵒrecP, digits = 2),
 actual = round(TPP, digits = 2))
# Code block 23: total profit against the level, Poisson and Lee's days
lumpc = colorant"#e08a1e"               # Lee's days, bootstrapped
fig = Figure(size = (600, 330))
ax = Axis(fig[1, 1]; xlabel = "Base stock level (loaves)",
          ylabel = "Total profit (\$ per day)", xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13)
hlines!(ax, [TPold]; color = :gray50, linestyle = :dot, linewidth = 1.5,
        label = "Old recipe")
lines!(ax, Slev, TPrecP; color = bluec, linewidth = 2,
       label = "Poisson demand")
lines!(ax, Slev, TPrec; color = lumpc, linewidth = 2,
       label = "Lee's days, bootstrapped")
scatter!(ax, [SᵒrecP, Sᵒrec], [TPᵒrecP, TPᵒrec]; color = optc,
         markersize = 13)
scatter!(ax, [SᵒrecP], [TPP]; color = :white, strokecolor = optc,
         strokewidth = 2, markersize = 13)
lines!(ax, [SᵒrecP, SᵒrecP], [TPP, TPᵒrecP]; color = optc,
       linestyle = :dash)
text!(ax, SᵒrecP, TPᵒrecP; text = "\$$(round(TPᵒrecP, digits = 2))",
      align = (:right, :bottom), offset = (-6, 4), fontsize = 13,
      color = bluec)
text!(ax, Sᵒrec, TPᵒrec; text = "\$$(round(TPᵒrec, digits = 2))",
      align = (:left, :top), offset = (8, -6), fontsize = 13,
      color = lumpc)
text!(ax, SᵒrecP, TPP; text = "\$$(rpad(round(TPP, digits = 2), 6, "0"))",
      align = (:left, :top), offset = (8, -4), fontsize = 13,
      color = optc)
xlims!(ax, 145, 445)
ylims!(ax, 540, 900)
axislegend(ax; position = :rb, labelsize = 13)
fig

# Example 5: Bootstrapped lead times and demand
## Example 5(a): Uncertain lead time
# Determine the best level when each replacement's lead time is
# uncertain, with the same mean of 1/8 period: drawn from the record of
# 12 transit times of Lecture 6.1 ({{< xref 6.1 example-7 >}}), $$19,
# 17, 20, 35, 18, 16, 18, 28, 19, 17, 31, 14$$ days, scaled to that
# mean, or drawn from an exponential distribution.
# Code block 24: the best level with each lead time, both models
x = [19, 17, 20, 35, 18, 16, 18, 28, 19, 17, 31, 14]  # days, 6.1 Ex. 7
cases = ["constant" => r -> te,
# Each case is a Pair, written =>, of its name and its lead time. The lead
# time is a function written with ->, read "maps to", which Lecture 1.2
# (Sec. 1.7) calls an anonymous function, defined without a name: r -> te
# takes the case's stream of random numbers, r, and returns its lead time,
# here always $t_e$. The search takes each function back out of its pair
# as leadtime, and first.(cases) the names for the table.
         "record, scaled" => bootstrap(te*x/mean(x)),
         # Each lead time is one of 6.1's 12 transit times, drawn with
         # replacement and scaled so that their mean is $t_e$, the record
         # scaled first and then handed to bootstrap: only the record's
         # variability carries over, not its days.
         "exponential" => r -> -te*log(rand(r))]
best = [maximum((simTP(q; leadtime), q) for q in qmax)
        for (_, leadtime) in cases]                     # lost sales
bestbo = [maximum((simTP(q; leadtime, backorder = true), q) for q in qmax)
          for (_, leadtime) in cases]                   # backorders
prt(DataFrame(lead_time = first.(cases), qmax = last.(best),
              TP = first.(best), qmax_bo = last.(bestbo),
              TP_bo = first.(bestbo)))

## Example 5(b): Demand as lumpy as the bakery's
# Determine the best level when the demand is as lumpy as the bakery's
# of Lecture 6.1 ({{< xref 6.1 example-6 >}}), its 13 days bootstrapped:
# each period's demand is one of the 13 days, drawn with replacement and
# scaled to the mean of 6 units a period.
# Code block 25: each period's demand, one of the bakery's 13 days
P = ceil(Int, t_stop) + 1         # periods simulated
dI = round.(Int, ra*d/mean(d))    # units/period, the days at a mean of 6
period = bootstrap(dI)            # a period's demand, one of the days
rng = Xoshiro(1234)               # its own stream of random numbers
n = [period(rng) for _ in 1:P]    # each period's demand
# period(rng) draws one of the 13 days for each of the $P$ periods, with
# replacement, by Code block 18's bootstrap: this line is the bootstrap.
# The days are first scaled by ra/mean(d) and rounded, so that each is a
# whole number of units and together they average $r_a$.
T = sort!([k + rand(rng) for k in 0:P-1 for _ in 1:n[k + 1]])
# Period $k$, counted from 0, runs from time $k$ to $k + 1$, and each of
# its n[k + 1] units is demanded at k + rand(rng), a time drawn at random
# within it; sort! puts the demands of all the periods in time order.
next_demand(t, r) = T[searchsortedlast(T, t) + 1]
# searchsortedlast(T, t) is the position in T of the last demand at or
# before time t, so the next demand is the one after it. simTP passes
# next_demand a stream of random numbers r, as it does the Poisson demand
# of Code block 8, but none is needed: the demands were all drawn in
# advance, in T, so every level sees the same ones.
# Code block 26: total profit at each level, Poisson and bakery demand
TPpois = [simTP(q) for q in qmax]                        # $/period
TPbake = [simTP(q; demand = next_demand) for q in qmax]  # $/period
TPᵒbake, qmaxᵒbake = maximum(zip(TPbake, qmax))
prt([TPpois TPbake]; rows = qmax, cols = ["Poisson", "bakery"],
    row_title = "qmax")
# Code block 27: the fraction lost, the time with none and the average
# on hand at q_max = 3
schb = [t -> next_demand(t, nothing), t -> t + te]  # no stream needed
pi0bake, qbarbake, nonebake = base_stock(3, schb, t_stop)
(pi0 = pi0bake, none = nonebake, qbar = qbarbake)
# Code block 28: total profit against q_max, Poisson and bakery demand
lumpc = colorant"#e08a1e"               # demand as lumpy as the bakery's
fig = Figure(size = (600, 320))
ax = Axis(fig[1, 1]; xlabel = "Maximum inventory level (units)",
          ylabel = "Total profit (\$ per period)", xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13,
          xticks = qmax)
scatterlines!(ax, qmax, TPpois; color = bluec, markersize = 8,
              label = "Poisson demand")
scatterlines!(ax, qmax, TPbake; color = lumpc, markersize = 8,
              label = "Bakery's demand, bootstrapped")
scatter!(ax, [qmaxᵒsim, qmaxᵒbake], [TPᵒsim, TPᵒbake]; color = optc,
         markersize = 13)
text!(ax, qmaxᵒsim, TPᵒsim; text = "\$$(round(TPᵒsim, digits = 2))",
      align = (:center, :bottom), offset = (0, 8), fontsize = 13,
      color = bluec)
text!(ax, qmaxᵒbake, TPᵒbake;
      text = "\$$(rpad(round(TPᵒbake, digits = 2), 5, "0"))",
      align = (:left, :top), offset = (4, -8), fontsize = 13,
      color = lumpc)
ylims!(ax, -0.5, 18)
axislegend(ax; position = :rb, labelsize = 13)
fig
# Code block 29: the bakery's demand against a Poisson of the same mean
m = mean(d)                     # loaves/day, mean demand
s = std(d)                      # loaves/day, standard deviation
sP = sqrt(m)                    # loaves/day, a Poisson's std. deviation
m6, s6 = mean(dI), std(dI)      # units/period, the days at a mean of 6
sP6 = sqrt(m6)                  # units/period, a Poisson's std. deviation
prt([m s sP s^2/m; m6 s6 sP6 s6^2/m6]; rows = ["loaves", "units"],
    row_title = "scale",
    cols = ["mean", "std", "Poisson std", "var/mean"])
# Code block 30: the bakery's demand against a Poisson of the same mean
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = "Day", ylabel = "Units",
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13, xticks = 1:13)
band!(ax, [0.5, 13.5], fill(m6 - 2sP6, 2), fill(m6 + 2sP6, 2);
      color = (bluec, 0.25), label = "Poisson, mean ± 2 std. dev.")
hlines!(ax, [m6]; color = bluec, linewidth = 1.5, label = "Mean")
scatterlines!(ax, 1:13, dI; color = givc, markersize = 8,
              label = "Demand")
ylims!(ax, 0, 16)
axislegend(ax; position = :lt, labelsize = 13, orientation = :horizontal)
fig

## Sec. 3. Reorder point
# Code block 31: the reorder point's control logic as a flowchart
qmn, qo_ = sub("q", "min"), sub("q", "o")   # the order point and quantity
fig, ax = chart(15.6, -0.1, 9.8)
xl, xr, xo = 2.7, 11.4, 7.0             # demand, order, stockout
flow!(ax, (5.4, 8.99), (5.4, 8.7), (xl, 8.7), (xl, 8.35))
flow!(ax, (10.8, 8.99), (10.8, 8.7), (xr, 8.7), (xr, 8.35))
pause!(ax, 8.1, 9.35, rich("Start: ", it("q"), up(" = "), qmn, up(" + "),
                           qo_, " on hand and position, ", it("b"),
                           up(" = 0")); w = 7.6, h = 0.72)
flow!(ax, (xl, 7.65), (xl, 7.3))        # a demand arrives
flow!(ax, (xl, 5.8), (xl, 5.45); s = "yes", at = 2)
flow!(ax, (xl, 4.45), (xl, 4.05))
flow!(ax, (xl, 2.55), (xl, 2.2); s = "yes", at = 2)
flow!(ax, (xl, 1.2), (xl, 0.7))
flow!(ax, (xl + 1.7, 3.3), (5.3, 3.3), (5.3, 0.35), (xl + 2.2, 0.35);
      s = "no")
flow!(ax, (xl + 1.7, 6.55), (xo, 6.55), (xo, 5.675); s = "no")
flow!(ax, (xo + 1.0, 4.225), (xo + 1.0, 0.35), (5.3, 0.35); c = bluec,
      s = "lost sales", al = (:left, :top), off = (6, -3), tip = false)
flow!(ax, (xo - 1.2, 4.225), (xo - 1.2, 3.95), (xl + 0.7, 3.95),
      (xl + 0.7, 3.74); c = boc, s = "backorders", al = (:left, :top),
      off = (6, -3))
event!(ax, xl, 8.0, "A demand arrives"; w = 3.7)
ask!(ax, xl, 6.55, ["On hand?", L"q > 0"])
step!(ax, xl, 4.95, ["Sell a unit", rich(it("q"), up(" − 1"),
                                         ", position ", up("− 1"))];
      w = 3.6)
ask!(ax, xl, 3.3, ["Position", rich("at ", qmn, "?")])
step!(ax, xl, 1.7, ["Order", rich(qo_, " units, position ", up("+ "),
                                  qo_)]; w = 3.6)
pause!(ax, xl, 0.35, "Wait for the next event"; w = 4.4)
step!(ax, xo, 4.95, ["Out of stock: a lost sale,",
                     rich("or a backorder: ", it("b"), up(" + 1"), ","),
                     rich("position ", up("− 1"))];
      w = 4.4, h = 1.45, c = grayc)
flow!(ax, (xr, 7.65), (xr, 7.3))        # an order arrives
flow!(ax, (xr, 5.8), (xr, 5.45); c = boc, s = "yes", at = 2)
flow!(ax, (xr + 1.7, 6.55), (14.4, 6.55), (14.4, 5.45); s = "no")
flow!(ax, (xr, 4.45), (xr, 3.65))
flow!(ax, (14.4, 4.45), (14.4, 3.3), (xr + 2.2, 3.3))
event!(ax, xr, 8.0, rich("An order of ", qo_, " arrives"); w = 4.4)
ask!(ax, xr, 6.55, ["Waiting?", L"b > 0"]; c = boc)
step!(ax, xr, 4.95, [rich("Fill up to ", qo_, " of them,"),
                     "the rest on hand"]; w = 3.4, c = boc)
step!(ax, 14.4, 4.95, ["Put on hand", rich(it("q"), up(" + "), qo_)];
      w = 2.3)
pause!(ax, xr, 3.3, "Wait for the next event"; w = 4.4)
fig

# Sec. 3. Reorder point
## Model: Reorder point with backorders
# Model: reorder point with lost sales or backorders, by simulation
# Event by event: fraction out of stock per demand, average on hand
function reorder_point(qo, qmin, sch, t_stop; backorder = false)
    E = [(0.0, :demand)]          # event calendar (time, kind)
    q = qmin + qo                 # state: units on hand, at the maximum
    pos, b = q, 0                 # inventory position, backorders
    t₀, A = 0.0, 0.0              # clock, area under q(t)
    nd, nout = 0, 0               # demands, and those out of stock
    while !isempty(E)
        t, evt = popfirst!(E)     # the earliest event, out of E
        A += q*(min(t, t_stop) - t₀)  # units on hand × time since last
        t > t_stop && break       # stop the simulation at T = t_stop
        t₀ = t                    # the clock to the event's time
        if evt == :demand
            nd += 1
            schedule!(E, sch[1](t), :demand)
            if q > 0              # a sale
            # A demand that finds a unit on hand is a sale; one that finds
            # none is a backorder, with backorders, or otherwise a lost
            # sale, which goes on to the next event and leaves the
            # position as it was. A sale and a backorder each lower the
            # position by one, as in @fig-rp-logic.
                q -= 1
            elseif backorder      # out of stock: a backorder waits
                nout += 1
                b += 1
            else                  # out of stock: a lost sale
                nout += 1
                continue          # the position is left as it was
            end
            pos -= 1              # a sale or a backorder lowers it
            if pos == qmin        # the position falls to the order point
                pos += qo
                schedule!(E, sch[2](t), :arrival)
            end
        else                      # an order of q_o arrives
            f = min(b, qo)        # the backorders it fills
            b -= f
            q += qo - f           # the rest goes on hand
        end
    end
    return (π₀ = nout/nd, q̄ = A/t_stop)  # per demand, over time
end

# Example 6: Reorder point by simulation
## Example 6(b): One policy
# Simulate the policy of ordering $q_o = 5$ units whenever the inventory
# position falls to $q_{\min} = 2$, with lost sales and with backorders,
# and measure its fraction out of stock and total profit.
# Code block 32: the simulation at q_o = 5, q_min = 2, both models
co = 2                            # $/order, fixed cost per order
Random.seed!(1234)                # the draws of Code block 3, anew
pi0sim, qbarsim = reorder_point(5, 2, sch, t_stop)
rosim = (1 - pi0sim)*ra/5         # orders/period
TPsim = (p - c)*(1 - pi0sim)*ra - c*h*qbarsim - co*rosim
Random.seed!(1234)                # the same demands, now backordered
pi0rpbo, qbarrpbo = reorder_point(5, 2, sch, t_stop; backorder = true)
TPrpbosim = (p - c)*(1 - pi0rpbo*g*te)*ra - c*h*qbarrpbo - co*ra/5
prt(DataFrame(stockout = ["lost sale", "backorder"],
              pi0 = [pi0sim, pi0rpbo], qbar = [qbarsim, qbarrpbo],
              TP = [TPsim, TPrpbosim]))
# Code block 33: units on hand and the inventory position, four periods
# reorder_point, recording (time, on hand, position)
function reorder_point_path(qo, qmin, sch, t_stop)
    E = [(0.0, :demand)]          # event calendar (time, kind)
    q = pos = qmin + qo           # units on hand, and the position
    path = [(0.0, q, pos)]
    while !isempty(E)
        t, evt = popfirst!(E)     # the earliest event, out of E
        t > t_stop && break       # stop the simulation at t_stop
        if evt == :demand
            schedule!(E, sch[1](t), :demand)
            if q > 0              # a sale lowers on hand and position
                q, pos = q - 1, pos - 1
                if pos == qmin    # the position falls to the order point
                    pos += qo
                    schedule!(E, sch[2](t), :arrival)
                end
            end
        else                      # an order of q_o arrives
            q += qo
        end
        push!(path, (t, q, pos))
    end
    return path
end
Random.seed!(1234)                # the draws of Code block 32
path = reorder_point_path(5, 2, sch, 4.0)
ts = first.(path)                 # event times
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = "Time (periods)", ylabel = "Units",
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13, yticks = 0:7)
band!(ax, [0, 4], [2.5, 2.5], [7.5, 7.5]; color = (grayc, 0.15))
stairs!(ax, ts, getindex.(path, 3); step = :post, color = grayc,
        linewidth = 2, label = "Inventory position")
stairs!(ax, ts, getindex.(path, 2); step = :post, color = bluec,
        linewidth = 2, label = "On hand")
hlines!(ax, [2]; color = givc, linestyle = :dash,
        label = L"\text{Order point } q_{\min}")
xlims!(ax, 0, 4)
ylims!(ax, -0.3, 9.5)
axislegend(ax; position = :lt, labelsize = 13, orientation = :horizontal)
fig

## Example 6(c): Every policy and the best
# Determine the policy of each model that maximizes total profit by
# simulation, over the order quantities from 1 to Ex. 6(a)'s bound and
# the order points from 0 to one less than the upper bound of
# @eq-qmax-ub.
# Code block 34: the best policy by simulation, on one stream of demands
qomax = ceil(Int, 2sqrt(2ra*co/(c*h)))   # units, Ex. 6(a)'s bound
qos, qmins = 1:qomax, 0:UBqmax-1  # order quantities and points tried
function simTPrp(qo, qmin; backorder = false)  # simulated TP of a policy
    Random.seed!(1234)            # the same demands for every policy
    sch = [t -> t - log(rand())/ra, t -> t + te]
    π₀, q̄ = reorder_point(qo, qmin, sch, t_stop; backorder)
    backorder || return (p - c)*(1 - π₀)*ra - c*h*q̄ - co*(1 - π₀)*ra/qo
    return (p - c)*(1 - π₀*g*te)*ra - c*h*q̄ - co*ra/qo
end
TPᵒrpsim, qoᵒsim, qminᵒsim =
    maximum((simTPrp(qo, qmin), qo, qmin) for qo in qos, qmin in qmins)
TPᵒrpbosim, qoᵒbosim, qminᵒbosim =
    maximum((simTPrp(qo, qmin; backorder = true), qo, qmin)
            for qo in qos, qmin in qmins)

## Model: Reorder point with backorders
# Model: reorder point with lost sales, Poisson demand, constant lead time
# Fraction lost and average on hand, averaged over the q_o levels
pi0rp(qo, qmin, μ) = sum(pi0(qmin + j, μ) for j in 1:qo)/qo
# Base stock's measure at each level $q_{\min} + j$ the position passes
# through, averaged over the $q_o$ levels, @eq-rp-pi0; @eq-rp-qbar
# likewise.
qbarrp(qo, qmin, μ) = sum(qbar(qmin + j, μ) for j in 1:qo)/qo
ro(qo, qmin) = (1 - pi0rp(qo, qmin, μ))*ra/qo
TPrp(qo, qmin; co = co) = (p - c)*(1 - pi0rp(qo, qmin, μ))*ra -
    c*h*qbarrp(qo, qmin, μ) - co*ro(qo, qmin)
maxTPrp(qos, qmins) =
# Every pair of an order quantity and an order point is tried in turn, and
# the one with the largest total profit is kept.
    maximum((TPrp(qo, qmin), qo, qmin) for qo in qos, qmin in qmins)
# Model: reorder point with backorders, Poisson demand, constant lead time
# Total profit with the delay discount on the fraction backordered
TPrpbo(qo, qmin; co = co) =
# pi0rp and qbarrp are those of @mdl-reorder's implementation for Poisson
# demand, exact here, since every stockout is backordered. Every demand is
# sold in the end, so orders are placed at $r_a / q_o$ a period.
    (p - c)*(1 - pi0rp(qo, qmin, μ)*g*te)*ra -
    c*h*qbarrp(qo, qmin, μ) - co*ra/qo

# Example 7: Reorder point with Poisson demand
## Example 7(b): Every policy and the best
# Determine the total profit of every order quantity from 1 to
# $q_{o,\max}$ and order point from 0 to one less than the upper bound
# of @eq-qmax-ub with lost sales, and the policy that maximizes it with
# lost sales and with backorders.
# Code block 35: the fixed cost per order and the largest q_o to try
co = 2                          # $/order, fixed cost per order
qomax = ceil(Int, 2sqrt(2ra*co/(c*h)))   # units, β = 2 times the EOQ
# Code block 36: total profit of every policy
qos, qmins = 1:qomax, 0:UBqmax-1  # order quantities and points tried
TPgrid = [TPrp(qo, qmin) for qmin in qmins, qo in qos]
prt(TPgrid; rows = qmins, cols = qos, row_title = "qmin")  # q_o across
# Code block 37: the best policy, lost sales and backorders
TPᵒrp, qoᵒ, qminᵒ = maxTPrp(qos, qmins)              # lost sales
TPᵒrpbo, qoᵒbo, qminᵒbo =                            # backorders
    maximum((TPrpbo(qo, qmin), qo, qmin) for qo in qos, qmin in qmins)
(qoᵒsim, qminᵒsim) == (qoᵒ, qminᵒ),       # the best policies of Ex. 6(c)
(qoᵒbosim, qminᵒbosim) == (qoᵒbo, qminᵒbo)
# Code block 38: total profit against q_o for each q_min
fig = Figure(size = (600, 340))
ax = Axis(fig[1, 1]; xlabel = "Order quantity (units)",
          ylabel = "Total profit (\$ per period)", xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13,
          xticks = qos)
pal = cgrad(:Blues, length(qmins) + 2;
            categorical = true)[3:end]  # one step a q_min, light to dark
for (i, qmin) in enumerate(qmins)
    scatterlines!(ax, qos, TPgrid[i, :]; label = L"q_{\min} = %$qmin",
                  color = pal[i], markersize = 6)
end
scatter!(ax, [qoᵒ], [TPᵒrp]; color = optc, markersize = 13)
Legend(fig[1, 2], ax; labelsize = 13, framevisible = false)
fig

## Example 7(c): Base stock as a landmark
# Check that each model with $q_o = 1$ and no fixed cost per order is
# base stock with the same stockout.
# Code block 39: q_o = 1 and c_o = 0 is base stock at q_max = q_min + 1
lostsales = [TPrp(1, qmin; co = 0) for qmin in 0:5] ≈
            [TP(qmin + 1) for qmin in 0:5]
backorders = [TPrpbo(1, qmin; co = 0) for qmin in 0:5] ≈
             [TPbo(qmin + 1) for qmin in 0:5]
lostsales, backorders

## Sec. 4. Multi-echelon inventory
# Code block 40: four levels of a supply chain
shipc = colorant"#d21f26"               # shipments of product
infoc = colorant"#0f9ad6"               # demands and orders
nodec = colorant"#2e8b57"               # stocking locations
namec = colorant"#7a1f7a"               # who is at each place
evtc = colorant"#4f8f2a"                # what each arrow carries
lane!(ax, a, b, color) =                # an arrow from a to b, as [x, y]
    arrows2d!(ax, [a[1]], [a[2]], [b[1] - a[1]], [b[2] - a[2]];
              color, shaftwidth = 2, tipwidth = 10, tiplength = 11)
note!(ax, x, y, s; al = (:center, :top), size = 13) =
    text!(ax, x, y; text = s, color = evtc, fontsize = size, align = al)
# The four roles, upstream at the left, drawn over x0 to 15 across and
# y0 to y1 up; returns the figure, its axis and where things are
function chain(x0, y0, y1)
    rn, lo, y = 0.5, 0.24, 2.0          # node radius, lane offset, center
    xs = [3.0, 5.9, 8.8, 11.7]          # node centers
    yo, ys = y + lo, y - lo             # orders above, shipments below
    rim = sqrt(rn^2 - lo^2)             # where a lane meets a node's edge
    cx = 12.95                          # where the customers are
    w = 600                             # pixels across
    h = round(Int, w*(y1 - y0)/(15 - x0))
    fig = Figure(size = (w + 20, h + 20), figure_padding = 10)
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)
    limits!(ax, x0, 15, y0, y1)
    for i in 1:3                        # role i + 1 orders from role i
        lane!(ax, [xs[i+1] - rim, yo], [xs[i] + rim, yo], infoc)
        lane!(ax, [xs[i] + rim, ys], [xs[i+1] - rim, ys], shipc)
    end
    lane!(ax, [cx - 0.1, yo], [xs[4] + rim, yo], infoc)   # demand
    lane!(ax, [xs[4] + rim, ys], [cx - 0.1, ys], shipc)
    who = ["Factory", "Distributor", "Wholesaler", "Retailer"]
    for (x, s) in zip(xs, who)
        poly!(ax, Circle(Point2f(x, y), rn); color = :white,
              strokecolor = nodec, strokewidth = 2.5)
        text!(ax, x, y + rn + 0.08; text = s, color = namec,
              fontsize = 15, font = :bold, align = (:center, :bottom))
    end
    text!(ax, cx, y; text = "Customers", color = namec, fontsize = 15,
          font = :bold, align = (:left, :center))
    return fig, ax, (; xs, y, rn, yo, ys, rim, cx)
end
fig, ax, g = chain(1.9, 0.55, 3.1)
for x in g.xs[1:3]
    note!(ax, x, g.y - g.rn - 0.08, "stockout:\nbackorder")
end
note!(ax, g.xs[4], g.y - g.rn - 0.08,
      "stockout: lost\nsale or backorder")
xm = (g.xs[1] + g.xs[2])/2              # between factory and distributor
note!(ax, xm, g.yo + 0.07, "orders"; al = (:center, :bottom))
note!(ax, xm, g.ys - 0.07, "shipments")
fig
# Code block 41: the two-echelon supply chain
shipc = colorant"#d21f26"               # shipments of product
infoc = colorant"#0f9ad6"               # demands and orders
nodec = colorant"#2e8b57"               # stocking locations
namec = colorant"#7a1f7a"               # who is at each end
evtc = colorant"#4f8f2a"                # what each arrow carries
rn = 0.42                               # node radius, data units
# Centers of the DC and the two retailers, and the chain's two ends
dc, r1, r2 = [4.0, 2.0], [7.6, 3.3], [7.6, 0.7]
sup, cus1, cus2 = [1.3, 2.0], [10.1, 3.3], [10.1, 0.7]
fig = Figure(size = (620, 220))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax)
hidespines!(ax)
limits!(ax, -0.9, 12.3, 0.05, 4.25)
function arrow!(a, b, color; off = 0.0)    # a to b, moved off sideways
    u = (b .- a) ./ sqrt(sum(abs2, b .- a))
    n = [-u[2], u[1]]                       # unit normal, to the left
    a, b = a .+ off .* n, b .+ off .* n
    return arrows2d!(ax, [a[1]], [a[2]], [b[1] - a[1]], [b[2] - a[2]];
                     color, shaftwidth = 2, tipwidth = 10,
                     tiplength = 11)
end
rim(p, q) = p .+ rn .* (q .- p) ./ sqrt(sum(abs2, q .- p))  # p's edge
arrow!(sup, rim(dc, sup), shipc)
for r in (r1, r2)
    arrow!(rim(dc, r), rim(r, dc), shipc; off = -0.11)
    arrow!(rim(r, dc), rim(dc, r), infoc; off = -0.11)
end
lines!(ax, [sup[1], 4.3], [1.25, 1.25]; color = shipc, linewidth = 2)
arrow!([4.3, 1.25], rim(r2, [4.3, 1.25]), shipc)
arrow!(cus1 .- [0.15, 0], rim(r1, cus1), infoc)
arrow!(cus2 .- [0.15, 0], rim(r2, cus2), infoc)
for (p, s) in ((dc, "DC"), (r1, "1"), (r2, "2"))
    poly!(ax, Circle(Point2f(p...), rn); color = :white,
          strokecolor = nodec, strokewidth = 2.5)
    text!(ax, p...; text = s, color = namec, fontsize = 16,
          font = :bold, align = (:center, :center))
end
name!(x, y, s, al) = text!(ax, x, y; text = s, color = namec,
                           fontsize = 16, font = :bold, align = al)
name!(sup[1] - 0.1, sup[2], "Supplier", (:right, :center))
name!(cus1[1] + 0.05, cus1[2], "Customer", (:left, :center))
name!(cus2[1] + 0.05, cus2[2], "Customer", (:left, :center))
name!(r1[1], r1[2] + 0.5, "Retailer", (:center, :bottom))
θ = atan(r1[2] - dc[2], r1[1] - dc[1])  # slope of the DC-retailer lines
evt!(x, y, s; rot = 0.0, al = (:center, :bottom)) =
    text!(ax, x, y; text = s, color = evtc, fontsize = 13,
          rotation = rot, align = al)
evt!(2.55, 2.15, "sup2dc_ship")
evt!(5.67, 2.81, "ret2dc_order"; rot = θ)
evt!(5.95, 2.42, "dc2ret_ship"; rot = θ, al = (:center, :top))
evt!(2.6, 1.15, "sup2dc2ret_ship"; al = (:center, :top))
evt!(8.9, 3.38, "demand")
fig

# Sec. 4. Multi-echelon inventory
# Example 8: Risk pooling
## Example 8(b): One central warehouse
# Determine the maximum level that maximizes the central warehouse's
# total profit, and its total profit and average inventory at that
# level.
# Code block 42: one central warehouse, the nine regions' demand pooled
rapool = 9ra                      # units/period, pooled arrival rate
μpool = rapool*te                 # units, mean demand in a lead time
UBpool = 2round(Int, rapool)      # units, the upper bound on q_max
TPpool, qmaxpool = maxTP(0:UBpool; ra = rapool, μ = μpool)
qbarpool = qbar(qmaxpool, μpool)  # units, average on hand at the best
(TP = TPpool, qmax = qmaxpool, qbar = qbarpool)
# Code block 43: the central warehouse's total profit against q_max
qpool = 0:20                      # units, the levels around the best
TPnine = round(9TPᵒ, digits = 2)  # $/period, Ex. 8(a)'s total
fig = Figure(size = (600, 320))
ax = Axis(fig[1, 1]; xlabel = "Maximum inventory level (units)",
          ylabel = "Total profit (\$ per period)", xlabelsize = 15,
          ylabelsize = 15, xticklabelsize = 13, yticklabelsize = 13)
scatterlines!(ax, qpool, TP.(qpool; ra = rapool, μ = μpool);
              color = bluec, label = "One central warehouse")
hlines!(ax, [9TPᵒ]; color = grayc, linestyle = :dash,
        label = "Nine regional warehouses, \$$TPnine")
scatter!(ax, [qmaxpool], [TPpool]; color = optc, markersize = 13)
text!(ax, qmaxpool, TPpool; text = "\$$(round(TPpool, digits = 2))",
      align = (:center, :bottom), offset = (0, 8), fontsize = 13)
ylims!(ax, -5, 180)
axislegend(ax; position = :rb, labelsize = 13)
fig

## Example 8(d): Comparison in code
# Compute the comparison of Ex. 8(a) to 7(c), and compare it with the
# values by hand.
# Code block 44: nine regional warehouses against one central warehouse
TP9 = 9TPᵒ                        # $/period, nine times Ex. 3's best
qbar9 = 9qbar(qmaxᵒ, μ)           # units, nine times its average on hand
prt(DataFrame(warehouses = ["nine regional", "one central"],
              qmax = [qmaxᵒ, qmaxpool],
              pi0 = [pi0(qmaxᵒ, μ), pi0(qmaxpool, μpool)],
              qbar = [qbar9, qbarpool], TP = [TP9, TPpool]))
# Code block 45: less inventory and more profit, as fractions
(less_inventory = 1 - qbarpool/qbar9, more_profit = TPpool/TP9 - 1)

# Example 9: Bullwhip from batching
## Example 9(b): Units ordered by simulation
# Simulate the warehouse with lost sales for 100,000 periods, and
# determine the mean, variance and squared coefficient of variation of
# the units demanded and of the units ordered each period.
# Code block 46: the SCV of a series, and units per period from times
scv(x) = var(x)/mean(x)^2       # squared coefficient of variation
function perperiod(t, P)        # units in each of periods 1 to P
    n = zeros(Int, P)
    for tᵢ in t                 # a unit at time tᵢ is in period ⌊tᵢ⌋ + 1
        n[floor(Int, tᵢ) + 1] += 1
    end
    return n
end
# Code block 47: the times of demands, sales and units ordered
function demand_and_orders(qo, qmin, sch, t_stop)
    E = [(0.0, :demand)]          # event calendar (time, kind)
    q = qmin + qo                 # state: units on hand, at the maximum
    pos = q                       # inventory position: on hand + on order
    tdem, tsold, tplaced = Float64[], Float64[], Float64[]
    while !isempty(E)
        t, evt = popfirst!(E)     # the earliest event, out of E
        t > t_stop && break       # stop the simulation at t_stop
        if evt == :demand
            push!(tdem, t)
            schedule!(E, sch[1](t), :demand)
            if q > 0              # a sale lowers on hand and position
                q -= 1
                pos -= 1
                push!(tsold, t)
                if pos == qmin    # q_o units ordered from the factory
                    pos += qo
                    append!(tplaced, fill(t, qo))
                    schedule!(E, sch[2](t), :arrival)
                end
            end
        else                      # an order of q_o arrives
            q += qo
        end
    end
    return tdem, tsold, tplaced
end
# Code block 48: units demanded and ordered at q_o = 5, q_min = 2
Random.seed!(1234)                   # the draws of Code block 3
tdem, tsold, tplaced = demand_and_orders(5, 2, [demand, arrival], t_stop)
P = floor(Int, t_stop)               # periods simulated
n = perperiod.([tdem, tplaced], P)   # units demanded, ordered, by period
prt([mean.(n) var.(n) scv.(n) scv.(diff.([tdem, tplaced]))];
    rows = ["demanded", "ordered"], row_title = "units",
    cols = ["mean", "var", "scv", "scv_between"], fracdig = 3)
# Code block 49: units demanded and ordered in the first 40 periods
per = 1:40                        # periods drawn
vd, vo = round.(var.(n), digits = 2)
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = "Period", ylabel = "Units",
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13)
scatterlines!(ax, per, n[1][per]; color = givc, markersize = 6,
              label = "Demanded, variance $vd")
scatterlines!(ax, per, n[2][per]; color = bluec, markersize = 6,
              label = "Ordered, variance $vo")
ylims!(ax, -0.5, maximum(n[2][per]) + 6)
axislegend(ax; position = :lt, labelsize = 13, orientation = :horizontal)
fig

## Example 9(c): Base stock as a landmark
# Check that with one unit ordered at a time, the warehouse passes the
# units it sells to the factory unchanged.
# Code block 50: q_o = 1, base stock, orders exactly the units sold
Random.seed!(1234)                # the draws of Code block 3
_, tsold1, tplaced1 = demand_and_orders(1, 2, [demand, arrival], t_stop)
tplaced1 == tsold1                # the same units, at the same times

# Sec. 5. Beer game
## Example 10: Beer game under two policies
# A retailer, a wholesaler, a distributor, and a factory play the beer
# game of @tbl-beer-rules for 20 weeks, while customer demand steps from
# 4 units a week to 8 in week 5. Determine the orders each role places
# when every role follows base stock at the position the game starts it
# in, and when every role follows a reorder point that orders batches of
# $q_o = 12$ units whenever its position is at or below $q_{\min} = 24$
# units.
# Code block 51: the beer game at the start
# One panel of the chain, drawn the same here and in Code block 55: role k
# at xs[k], upstream at the left, over 0 to w across in px pixels
bp = (; xs = [2.4, 4.8, 7.2, 9.6], y = 1.0, rn = 0.48, lo = 0.26,
      w = 12.45, px = 632)
ppu = bp.px/bp.w                        # pixels per unit, every panel
function num!(ax, x, y, new, old; c = namec)  # old struck, beside new
    wn, wo = 0.18length(new), 0.15length(old)  # widths, data units
    xn = new == old ? x : x + (wo + 0.08)/2  # the pair centered on x
    if new != old
        xo = xn - (wn + wo)/2 - 0.08
        text!(ax, xo, y; text = old, color = grayc, fontsize = 13,
              align = (:center, :center))
        poly!(ax, Rect2f(xo - wo/2, y - 0.015, wo, 0.03); color = grayc)
    end
    text!(ax, xn, y; text = new, color = c, fontsize = 15, font = :bold,
          align = (:center, :center))
    return nothing
end
box!(ax, x, y, v, c) =                  # one week of a delay
    (scatter!(ax, [x], [y]; marker = :rect, markersize = 32,
              color = :white, strokecolor = c, strokewidth = 1.2);
     text!(ax, x, y; text = string(v), color = c, fontsize = 13,
           align = (:center, :center)))
function beer_axis(pos, lo, hi)         # a panel's axis, lo to hi up
    ax = Axis(pos; aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)
    limits!(ax, 0, bp.w, lo, hi)
    return ax
end
# held: each role's (new, old), factory first; ords and ships: each lane's
# boxes, left then right; prod: production, the next to arrive first
function beer_panel!(ax, held, ords, ships, prod, dem; label = "",
                     names = false)
    (; xs, y, rn, lo) = bp
    yo, ys, rim = y + lo, y - lo, sqrt(rn^2 - lo^2)
    cx = xs[4] + rim + 0.75             # where the customers are
    for k in 1:3                        # role 5 - k supplies role 4 - k
        lane!(ax, [xs[k+1] - rim, yo], [xs[k] + rim, yo], infoc)
        lane!(ax, [xs[k] + rim, ys], [xs[k+1] - rim, ys], shipc)
        m = (xs[k] + xs[k+1])/2
        for j in 1:2                    # the left box, then the right
            box!(ax, m + 0.24(2j - 3), yo, ords[k][j], infoc)
            box!(ax, m + 0.24(2j - 3), ys, ships[k][j], shipc)
        end
    end
    lane!(ax, [cx - 0.1, yo], [xs[4] + rim, yo], infoc)  # demand
    lane!(ax, [xs[4] + rim, ys], [cx - 0.1, ys], shipc)
    lane!(ax, [xs[1] - 2.25, ys], [xs[1] - rim, ys], shipc)  # brewed
    for (j, v) in enumerate(prod)
        box!(ax, xs[1] - 0.9 - 0.48(j - 1), ys, v, shipc)
    end
    for k in 1:4
        poly!(ax, Circle(Point2f(xs[k], y), rn); color = :white,
              strokecolor = nodec, strokewidth = 2)
        num!(ax, xs[k], y, held[k]...)
    end
    num!(ax, cx + 0.45, yo, dem...; c = infoc)  # customer demand
    text!(ax, xs[1] - 2.35, y + 0.42; text = label, fontsize = 15,
          font = :bold, align = (:left, :center))
    names || return nothing
    who = ["Factory", "Distributor", "Wholesaler", "Retailer"]
    for (x, s) in zip(xs, who)
        text!(ax, x, y + rn + 0.06; text = s, color = namec,
              fontsize = 15, font = :bold, align = (:center, :bottom))
    end
    text!(ax, cx + 0.05, y + rn + 0.06; text = "Customers", color = namec,
          fontsize = 15, font = :bold, align = (:left, :bottom))
    return nothing
end
fig = Figure(size = (bp.px + 8, round(Int, ppu*1.73) + 8),
             figure_padding = 4)
ax = beer_axis(fig[1, 1], 0.2, 1.93)
four = fill((4, 4), 3)                  # each lane's two weeks, 4 units
beer_panel!(ax, fill(("12", "12"), 4), four, four, fill(4, 3), ("4", "4");
            names = true)
x1, ys, yo = bp.xs[1], bp.y - bp.lo, bp.y + bp.lo
lane!(ax, [x1 - 0.4, yo], [x1 - 2.25, yo], infoc)  # to brew
text!(ax, x1 - 2.35, bp.y + bp.rn + 0.06; text = "Brewery", color = namec,
      fontsize = 15, font = :bold, align = (:left, :bottom))
note!(ax, x1 - 1.38, ys - 0.24, "3 weeks"; size = 13)
note!(ax, bp.xs[4] + 1.6, ys - 0.2, "8 from week 5"; size = 13)
fig

# Example 10: Beer game under two policies
## Example 10(b): Base stock in simulation
# Simulate the 20 weeks with every role following base stock, and
# determine the orders each role places.
# Code block 52: the beer game, one week at a time
function beergame(order, d; tord = 2, tship = 2, tprod = 3, I0 = 12,
                  q0 = 4, chold = 0.50, cback = 1.00)
    T, n = length(d), 4                   # weeks, roles
    # shipments on their way to each role and orders on their way from
    # each role to its supplier, one slot a week, q0 in each at the start
    inship = [fill(q0, i < n ? tship : tprod) for i in 1:n]
    inord = [fill(q0, tord) for i in 1:n-1]
    onhand, backlog = fill(I0, n), zeros(Int, n)
    # by week and role: units received, orders arrived, units shipped,
    # on hand, backlogged, the position, units ordered, and the cost
    R, A, X, I, B, P, Q = (zeros(Int, T, n) for _ in 1:7)
    C = zeros(T, n)
    for t in 1:T
        for i in 1:n                      # 1. receive a shipment
            R[t, i] = popfirst!(inship[i])
            push!(inship[i], 0)
            onhand[i] += R[t, i]
        end
        A[t, 1] = d[t]                    # 2. an order arrives
        for i in 2:n
            A[t, i] = popfirst!(inord[i-1])
            push!(inord[i-1], 0)
        end
        for i in 1:n                      # 3. ship what can be shipped
            due = A[t, i] + backlog[i]
            X[t, i] = min(onhand[i], due)
            onhand[i] -= X[t, i]
            backlog[i] = due - X[t, i]
            if i > 1                      # on its way to role i - 1
                inship[i-1][end] = X[t, i]
            end
        end
        I[t, :] = onhand                  # 4. record, and the cost
        B[t, :] = backlog
        C[t, :] = chold*onhand + cback*backlog
        for i in 1:n                      # 5. place an order
            onorder = sum(inship[i]) +
            # A role's units on order are those on their way to it and,
            # for all but the factory, its orders still on their way to
            # the supplier and the units its supplier has backlogged for
            # it; the position is Sec. 4's, on hand plus on order, less
            # what the role itself owes.
                (i < n ? sum(inord[i]) + backlog[i+1] : 0)
            P[t, i] = onhand[i] + onorder - backlog[i]
            Q[t, i] = order(i, t, A[t, i], P[t, i])
            if i < n
                inord[i][end] = Q[t, i]
            else                          # a production request
                inship[n][end] = Q[t, i]
            end
        end
    end
    return (; R, A, X, I, B, P, Q, C)
end
# Code block 53: customer demand, the roles and the two policies
weekly(T; d1 = 4, d2 = 8, tstep = 5) = [t < tstep ? d1 : d2 for t in 1:T]
roles = ["Retailer", "Wholesaler", "Distributor", "Factory"]
basestock_policy(i, t, a, p) = a        # order what was ordered
reorder_policy(qmin, qo) = (i, t, a, p) ->
    p ≤ qmin ? qo*(fld(qmin - p, qo) + 1) : 0
    # Whole batches of $q_o$ until the position $p$ is above $q_{\min}$,
    # fld(qmin - p, qo) + 1 of them, since one week's orders can take the
    # position more than one batch below it.
# Code block 54: base stock, 20 weeks
dw = weekly(20)                   # units/week, customer demand
bs = beergame(basestock_policy, dw)
bs.P[1, :] + bs.Q[1, :]           # each role's position, after ordering
# Code block 55: the chain at the end of each week, base stock
wv(M, t, i) = t ≥ 1 ? M[t, i] : 4       # a week's value, 4 before
held(g, t, i) = t ≥ 1 && g.B[t, i] > 0 ? "−$(g.B[t, i])" :
                string(t ≥ 1 ? g.I[t, i] : 12)  # on hand, or −backlog
function beer_week!(ax, g, t, d; names = false)  # g, Code block 52's
    beer_panel!(ax,
        [(held(g, t, 5 - k), held(g, t - 1, 5 - k)) for k in 1:4],
        [(wv(g.Q, t - 1, 4 - k), wv(g.Q, t, 4 - k)) for k in 1:3],
        [(wv(g.X, t, 5 - k), wv(g.X, t - 1, 5 - k)) for k in 1:3],
        [wv(g.Q, s, 4) for s in t-2:t],  # 3 weeks of production
        (string(d[t]), string(d[max(t - 1, 1)]));
        label = "Week $t", names)
    return nothing
end
function beer_weeks(g, weeks, d)    # one panel a week, top to bottom
    his = [r == 1 ? 1.93 : 1.6 for r in eachindex(weeks)]  # panel tops
    hs = round.(Int, ppu .* (his .- 0.47))   # panel heights, pixels
    fig = Figure(size = (bp.px + 8, sum(hs) + 12(length(weeks) - 1) + 8),
                 figure_padding = 4)
    for (r, t) in enumerate(weeks)
        ax = beer_axis(fig[r, 1], 0.47, his[r])
        beer_week!(ax, g, t, d; names = r == 1)
        rowsize!(fig.layout, r, Fixed(hs[r]))
    end
    rowgap!(fig.layout, 12)
    return fig
end
beer_weeks(bs, 4:8, dw)
# Code block 56: the retailer's record, the first 10 weeks
wks = 1:10                        # weeks
retailer = hcat(bs.R[wks, 1], bs.A[wks, 1], bs.X[wks, 1], bs.I[wks, 1],
                bs.B[wks, 1], bs.C[wks, 1], bs.Q[wks, 1])   # role 1
prt(retailer; rows = wks, row_title = "Week",
    cols = ["Received", "Order arrived", "Shipped", "On hand", "Backlog",
            "Cost", "Ordered"])
# Code block 57: orders received and placed by each role, base stock
function orders_by_role(g)        # g, a game Code block 52 returns
    fig = Figure(size = (600, 460))
    wk = 1:size(g.Q, 1)           # weeks
    for i in 1:4
        ax = Axis(fig[i, 1]; ylabel = roles[i], ylabelsize = 15,
                  xticklabelsize = 13, yticklabelsize = 13,
                  xticks = 2:2:20, yticks = 0:4:12)
        stairs!(ax, wk, g.A[:, i]; step = :center, color = givc,
                linestyle = :dash, linewidth = 2,
                label = "Orders received")
        stairs!(ax, wk, g.Q[:, i]; step = :center, color = bluec,
                linewidth = 2, label = "Orders placed")
        vr = round(var(g.A[:, i]), digits = 2)
        vp = round(var(g.Q[:, i]), digits = 2)
        text!(ax, 20.4, 16.5; text = "variance $vr received, $vp placed",
              align = (:right, :top), fontsize = 13)
        ylims!(ax, -1, 17)
        if i == 1
            Legend(fig[0, 1], ax; orientation = :horizontal,
                   labelsize = 13, framevisible = false)
        end
        if i < 4
            hidexdecorations!(ax; grid = false)
        else
            ax.xlabel = "Week"
            ax.xlabelsize = 15
        end
    end
    rowgap!(fig.layout, 6)
    return fig
end
orders_by_role(bs)
# Code block 58: base stock passes each order up, 2 weeks a role
lag(i, t) = t > 2(i - 1) ? dw[t - 2(i - 1)] : 4   # 4 before the game
all(bs.Q[t, i] == lag(i, t) for i in 1:4, t in 1:20)

## Example 10(c): Reorder point in simulation
# Simulate the 20 weeks with every role following the reorder point,
# determine the orders each role places, and compare their variance with
# the variance of the orders it receives.
# Code block 59: the reorder point, q_min = 24 and q_o = 12, 20 weeks
rp = beergame(reorder_policy(24, 12), dw)
Vbs = [var.(eachcol(bs.A)) var.(eachcol(bs.Q))]  # received, placed
Vrp = [var.(eachcol(rp.A)) var.(eachcol(rp.Q))]  # received, placed
prt([Vbs Vrp]; rows = roles, row_title = "role",
    cols = ["bs_received", "bs_placed", "rp_received", "rp_placed"])
# Code block 60: orders received and placed by each role, reorder point
orders_by_role(rp)
# Code block 61: the chain at the end of each week, reorder point
beer_weeks(rp, 4:8, dw)
# Code block 62: units in the chain at the end, a Balance check
wk = length(dw)                   # the last week
transit = sum(rp.X[wk-1:wk, 2:4]) # shipped in the last 2 weeks
making = sum(rp.Q[wk-2:wk, 4])    # requested in the last 3 weeks
start = 4*12 + 3*2*4 + 3*4        # on hand, in transit, in production
sum(rp.I[wk, :]) + transit + making ==
    start + sum(rp.Q[:, 4]) - sum(rp.X[:, 1])
