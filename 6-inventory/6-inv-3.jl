# 6-inv-3 — generated from 6-inv-3.qmd by tools/qmd_to_jl.py
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
# Two device pixels per figure unit, as in lectures 3.2 to 6.2, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Presentation plumbing for the prose, as in Lecture 6.1: a number with
# thousands separators
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end

## Sec. 1. Buffers and production systems
# Code block 1: a production system and its rates
bluec = colorant"#1f6fb5"               # the system and its flows
grayc = colorant"#7f7f7f"               # the bracket over the resources
fs = 17                                 # every label, as body text
fm = 21                                 # the rates, a size larger
function flow!(ax, x0, y0, x1, y1)      # a straight arrow from (x0, y0)
    arrows2d!(ax, [x0], [y0], [x1 - x0], [y1 - y0]; color = bluec,
              shaftwidth = 3.5, tipwidth = 16, tiplength = 16)
    return nothing
end
# Drawn compact, on the proportions of Lecture 1.3's figure, so that the
# labels and rate symbols are large against the drawing
fig = Figure(size = (520, 252), figure_padding = 2)
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax)
hidespines!(ax)
limits!(ax, 0, 930, 0, 450)
poly!(ax, Rect(325, 95, 300, 227); color = :white, strokecolor = bluec,
      strokewidth = 3)                  # the production system
text!(ax, 475, 245; text = "Production\nSystem",
      align = (:center, :center), fontsize = 18, font = :bold)
text!(ax, 475, 140; text = L"(r_e)", align = (:center, :center),
      fontsize = fm)
inputs = ["Fixed Assets", "Labor", "Raw Materials"]
for (y, s) in zip([285, 210, 135], inputs)
    flow!(ax, 30, y, 325, y)            # the resources, in
    text!(ax, 172, y; text = s, align = (:center, :bottom),
          offset = (0, 4), fontsize = fs)
end
text!(ax, 172, 135; text = L"(r_a)", align = (:center, :top),
      offset = (0, -4), fontsize = fm)
lines!(ax, [30, 30, 315, 315], [345, 362, 362, 345]; color = grayc,
       linewidth = 1.5)                 # the bracket over the resources
text!(ax, 172, 362; text = "Resources", align = (:center, :bottom),
      offset = (0, 4), fontsize = fs, font = :bold)
flow!(ax, 625, 272, 905, 272)           # finished goods or services, out
text!(ax, 762, 272; text = "Finished Goods\nor Services",
      align = (:center, :bottom), offset = (0, 4), fontsize = fs)
text!(ax, 762, 272; text = L"(r_d)", align = (:center, :top),
      offset = (0, -4), fontsize = fm)
flow!(ax, 905, 145, 625, 145)           # demand, offered from the right
text!(ax, 762, 145; text = "Demand", align = (:center, :bottom),
      offset = (0, 4), fontsize = fs)
text!(ax, 762, 145; text = L"(r_f)", align = (:center, :top),
      offset = (0, -4), fontsize = fm)
flow!(ax, 475, 95, 475, 20)             # scrap, out the bottom
text!(ax, 475, 55; text = "Scrap", align = (:left, :center),
      offset = (10, 0), fontsize = fs)
fig

# Sec. 2. Service system design
# Example 1: Delay discount factor
## Example 1(b): In code
# Compute the same factors in Julia and compare them with part (a)'s.
# Code block 2: price and delay discount factors of Ex. 1
using Logjam                    # for prt, a labeled table
p = 100                         # $/unit, unit price
c = 60                          # $/unit, unit cost
xg = 0.8                        # share of the price lost over tg
tg = [1, 15/60]                 # yr and hr, the two delays
gp = xg ./ tg                   # 1/yr and 1/hr, price discount factor
g = p*xg ./ ((p - c) .* tg)     # 1/yr and 1/hr, delay discount factor
prt([tg gp g]; rows = ["low (yr)", "high (hr)"],
    cols = ["tg", "g'", "g"], row_title = "discount")

## Sec. 2. Service system design
# Code block 3: Poisson arrival process
using Random                        # for randexp, exponential draws
function poissarr(lmb, n = 1)
    # lmb = n-element vector of arrival rates, where lmb[i] is the rate
    #       for time period i
    #   n = number of periods, if scalar lmb
    #   t = vector of variates, where t[j] between [(i-1), i) correspond
    #       to period i arrivals
    if n > 1 && length(lmb) > 1
        error("\"n\" > 1 only for scalar \"lmb\".")
    end
    lmax = maximum(lmb)             # the peak rate
    t = cumsum(randexp(ceil(Int, n*1.25*length(lmb)*lmax))/lmax)
    # A quarter more interarrival times are drawn than the day's expected
    # number of arrivals at the peak rate, so one draw usually covers the
    # day; the loop after it adds a quarter more only when it does not.
    done = false
    while !done
        if t[end] > n*length(lmb)
            done = true
            t = t[t .< n*length(lmb)]
        else                        # extend by a quarter as many
            more = ceil(Int, n*0.25*length(lmb)*lmax)
            t = [t; t[end] .+ cumsum(randexp(more)/lmax)]
        end
    end
    if !isempty(t) && length(lmb) > 1   # Thin if nonhomogeneous
        rnd = rand(length(t))
        for i in 1:length(lmb)
            t[(i - 1 .<= t .< i) .& (rnd .> lmb[i]/lmax)] .= NaN
            # An arrival in period $i$ is set to NaN, to be dropped,
            # unless its uniform draw is at most $r_a\mkern-1.5mu(i)/\max
            # r_a$, so the arrivals kept in period $i$ are a Poisson
            # process at that period's own rate.
        end
        t = t[.!isnan.(t)]
    end
    return t
end
# Code block 4: an m-server FIFO queue
function qfifo(a, s, m = 1)
    # a = n-element vector of arrival times (cumsum of interarrival times)
    # s = scalar, constant service time
    # m = number of identical servers
    # d = n-element vector of departure times
    n = length(a)
    d = zeros(n)
    # Time when m servers are first available
    server = a[1:min(m, n)]
    # Each of the $m$ servers is first free at one of the first $m$
    # arrival times, so the first $m$ customers start service as they
    # arrive.
    for i in 1:n
        # Select earliest available server
        timeavail, availserver = findmin(server)
        if timeavail > a[i]
            d[i] = server[availserver] + s    # Wait for server
        else
            d[i] = a[i] + s                   # Immediate service
        end
        server[availserver] = d[i]  # When server next available
    end
    return d
end
# Code block 5: the time in queue simulated over many days
using Statistics                    # for mean
function ctqsim(ra, te, m; nruns = 10_000, seed = 1)
    Random.seed!(seed)              # random draws, seeded to repeat
    CTq = zeros(nruns)              # hr, mean time in queue of each day
    for i in 1:nruns
        a = poissarr(ra)            # hr, the day's arrival times
        d = qfifo(a, te, m)         # hr, departure times
        CTq[i] = mean(d - a .- te)  # hr, time in queue
    end
    return mean(CTq)                # hr, mean time in queue over the days
end
# Code block 6: a small day hour by hour, against capacity
ra = [5, 7, 20, 30, 4, 10, 15, 5]   # per hr, arrival rate in hour t
re = 15                         # per hr, capacity
redc = colorant"#d21f26"        # given: the customers arriving
bluec = colorant"#1f6fb5"       # determined: the customers carried in
grayc = colorant"#7f7f7f"       # the capacity
n = length(ra)                  # hours open
qx = zeros(n)                   # customers, excess of each hour
for t in 1:n
    qx[t] = max(0, ra[t] + (t > 1 ? qx[t-1] : 0) - re)
end
cin = [0; qx[1:n-1]]            # carried in from the hour before
hrs = 1:n
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = "Hour", ylabel = "Customers", xticks = hrs,
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13)
barplot!(ax, [hrs; hrs], [cin; ra]; stack = [fill(1, n); fill(2, n)],
         color = [fill(bluec, n); fill(redc, n)], gap = 0.25)
hlines!(ax, re; color = grayc, linestyle = :dash, linewidth = 1.5)
text!(ax, 0.55, re; text = "capacity", align = (:left, :top),
      offset = (0, -3), fontsize = 13, color = grayc)
axislegend(ax, [PolyElement(color = redc), PolyElement(color = bluec)],
           ["arriving", "carried in"]; position = :lt,
           framevisible = false, labelsize = 13)
xlims!(ax, 0.4, n + 0.6)
ylims!(ax, 0, 40)
fig

# Example 2: Barbershop
## Example 2(a): Five barbers
# Determine the time in queue of five barbers by the recursion, by hand
# and in code, and by simulation, and their total profit by @eq-srv-tp.
# Code block 7: the barbershop's data
ra = [5, 7, 20, 32, 6, 15, 45, 12]   # per hr, arrival rate in hour t
@show te = 20/60                # hr, time of a haircut
p = 30                          # $/haircut, price
c = 0                           # $/haircut, operating cost
w = 20                          # $/hr, a barber's wage
@show k = w*te                  # $/unit, cost of a unit of capacity
xg = 0.2                        # share of the price lost over tg
tg = 0.5                        # hr, delay
@show g = p*xg/((p - c)*tg)     # 1/hr, delay discount factor
@show rd = sum(ra)/length(ra);  # per hr, departure rate, the day's mean
# Model: service system design, the number of servers
function TPsrv(m, CT = ctqsim(ra, te, m) + te)
# The cycle time is the day's time in queue simulated by ctqsim, plus a
# haircut, unless another estimate is given.
    return (p - c)*(1 - g*CT)*rd - k*m/te
    # Capacity is $r_e = m / t_e$, so the capital cost is $k \, m / t_e =
    # w \, m$, the barbers' wages.
end
# Code block 8: five barbers, by the recursion and by simulation
# Queue time of excess demand makes up the majority of the queue time
# for terminating non-stationary arrival processes.
function ctexcess(ra, re)
    n = length(ra)                  # periods with arrivals
    qx = zeros(n + 1)               # excess demand not served in period t
    for t in 1:n
        qx[t] = max(0, ra[t] + (t > 1 ? qx[t-1] : 0) - re)
    end
    nx = ceil(Int, qx[n]/re)        # periods to finish qx(n) after n
    qx[n+1] = (nx - 1)*(qx[n] - nx*re/2)   # queueing while they finish
    return sum(qx)/sum(ra)          # hr, time in queue
end
m = 5                                   # barbers
@show CTqrec = ctexcess(ra, m/te)       # hr, by the recursion
@show CTqsim = ctqsim(ra, te, m)        # hr, by simulation
@show TP5rec = TPsrv(m, CTqrec + te)    # $/hr, with the recursion's
@show TP5 = TPsrv(m, CTqsim + te);      # $/hr, with the simulated

## Example 2(b): Number of barbers
# Determine the total profit of five to twelve barbers by @mdl-srv, each
# one's cycle time simulated, and the number that maximizes it.
# Code block 9: five to twelve barbers, and the best
ms = 5:12                                        # barbers
CTsim = [ctqsim(ra, te, m) for m in ms] .+ te    # hr, by simulation
CTrec = [ctexcess(ra, m/te) for m in ms] .+ te   # hr, by the recursion
TPsim = TPsrv.(ms, CTsim)                        # $/hr, total profit
TPrec = TPsrv.(ms, CTrec)                        # $/hr, by the recursion
prt([CTsim TPsim CTrec TPrec]; rows = ms, row_title = "m", fracdig = 4,
    cols = ["CT sim", "TP sim", "CT rec", "TP rec"])
TPᵒ, iᵒ = findmax(TPsim)                         # $/hr, the best profit
@show mᵒ = ms[iᵒ]                                # barbers, the best
@show mrec = ms[argmax(TPrec)]                   # barbers, by recursion
@show TPUB = (p - c - k)*rd;                     # $/hr, the upper bound
# Code block 10: total profit against the number of barbers
bluec = colorant"#1f6fb5"       # a determined series
fig = Figure(size = (600, 300))
ax = Axis(fig[1, 1]; xlabel = L"\text{Number of barbers, } m",
          ylabel = L"TP \text{ (\$/hr)}", xticks = ms,
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13)
scatterlines!(ax, ms, TPsim; color = bluec, markersize = 10,
              linewidth = 2)
lbl = "\$" .* string.(round.(Int, TPsim))
# each label on the side of its point that the lines leave clear
als = [(:left, :center); (:right, :center); fill((:center, :bottom), 6)]
offs = [(8, 0); (-8, 0); fill((0, 8), 6)]
for i in eachindex(ms)
    text!(ax, ms[i], TPsim[i]; text = lbl[i], align = als[i],
          offset = offs[i], fontsize = 13)
end
text!(ax, mᵒ, TPᵒ; text = "best", align = (:center, :top),
      offset = (0, -8), fontsize = 13, color = bluec)
ylims!(ax, 80, 280)
fig

## Sec. 3. Make-to-order design
# Code block 11: the cycle time of m machines
function tct(m; ra = ra, te = te, ca2 = ca2, ce2 = ce2)
    u = ra*te/m                 # utilization
    u < 1 || error("utilization $u: $m machine(s) cannot keep up")
    # @eq-ct needs a steady state, which needs $u < 1$; below $m_{\min}$
    # of @eq-mmin the estimate is meaningless, so the function refuses it
    # rather than return a number.
    CTq = ((ca2 + ce2)/2)*(u^(sqrt(2(m + 1)) - 1)/(m*(1 - u)))*te
    return CTq + te             # hr, cycle time in queue and in process
end

# Sec. 3. Make-to-order design
# Example 3: Machines for make-to-order producer
## Example 3(a): Two machines and the best number
# Determine the total profit with two machines at $y = 1$ by @mdl-mto,
# and the number of machines that maximizes it.
# Code block 12: the make-to-order producer's data
p = 30                          # $/unit, unit price
c = 20                          # $/unit, unit operating cost
k = 1                           # $/unit, unit capital cost
tg = 0.5                        # hr, delay
xg = 0.2                        # share of the price lost over tg
@show g = p*xg/((p - c)*tg)     # 1/hr, delay discount factor
y = 1                           # yield
rd = 10                         # units/hr, departure rate of good units
@show ra = rd/y                 # units/hr, arrival rate of work
ca2 = 1                         # arrival SCV
@show t0 = 10/60                # hr, natural process time
c02 = 0                         # natural process SCV
A = 1                           # availability, the machines never fail
@show te = t0/A                 # hr, effective process time
@show ce2 = c02;                # effective process SCV, with A = 1
# Lecture 1.3's effective process SCV with failures, {{< xref 1.3 eq-ce
# >}}, is $c_e^2 = c_0^2 + (1 + c_r^2)\,A(1 - A)\,\text{MTTR}/t_0$; with
# an availability of 1 its failure term is zero, and $c_e^2 = c_0^2$.
# Model: make-to-order design, the number of machines by search
# Total profit with m machines at yield y, and the best m
TPmto(m; y = y, g = g, k = k) =
# tct is Code block 11's, its utilization at the arrival rate of work,
# $r_a = r_d / y$, while the producer is paid only for the good units,
# $r_d$. The yield, the delay discount factor and the unit capital cost
# are keyword arguments, each the example's unless another is given.
    (p - c)*(1 - g*tct(m; ra = rd/y))*rd - k*m/te
function maxTPmto(; y = y, g = g, k = k)
    m = floor(Int, rd/y*te + 1) # m_min, at the arrival rate of work
    best = (TPmto(m; y, g, k), m)
    while TPmto(m + 1; y, g, k) > best[1]
        m += 1
        best = (TPmto(m; y, g, k), m)
    end
    return best
end
# Code block 13: two machines, one quantity at a time, and the best
m = 2                           # machines
@show mmin = floor(Int, ra*te + 1)   # minimum number of machines
@show u = ra*te/m               # utilization
@show CT = tct(m)               # hr, cycle time at the workstation
@show CTq = CT - te             # hr, cycle time in queue
@show WIPq = ra*CTq             # units, work in process in queue
@show WIP = ra*CT               # units, work in process at the station
@show WIP - WIPq                # units, work in process on the machines
@show re = m/te                 # units/hr, capacity
@show TP = TPmto(m)             # $/hr, total profit
TPᵒ, mᵒ = maxTPmto();           # $/hr and machines, the best
@show TPᵒ
@show mᵒ;

## Example 3(b): Lower yields
# Determine the utilization and the best number of machines at yields of
# 0.9, 0.8, and 0.7.
# Code block 14: the best number of machines as the yield falls
ys = [1, 0.9, 0.8, 0.7]         # yield
ras = rd ./ ys                  # units/hr, arrival rate of work
mmins = floor.(Int, ras*te .+ 1)   # minimum number of machines
u3 = ras*te/3                   # utilization of three machines
bests = [maxTPmto(y = yi) for yi in ys]   # ($/hr, machines), the best
prt([ras mmins u3 last.(bests) first.(bests)]; rows = ys,
    row_title = "y", cols = ["ra", "m_min", "u, m = 3", "m*", "TP*"])

## Example 3(c): One fast machine
# Determine which of the two designs of custom fixtures to use, and its
# optimal capacity and total profit, by @eq-g, @eq-restar, @eq-mm1 and
# @mdl-mto.
# Code block 15: the custom fixtures' two designs by the closed form
rd = 12                         # units/hr, demand, Poisson
p = 100                         # $/unit, average sales price
tg = 1                          # hr, delay
xg = 0.1                        # share of the price lost over tg
cman = 50                       # $/unit, manual, unit operating cost
kman = 2                        # $/unit, manual, unit capacity cost
cauto = 45                      # $/unit, automated, unit operating cost
kauto = 8                       # $/unit, automated, unit capacity cost

@show gman = p*xg/((p - cman)*tg)                    # 1/hr
@show reman = rd + sqrt((p - cman)*gman*rd/kman)     # units/hr
@show CTman = 1/(reman - rd)                         # hr
@show TPman = (p - cman)*(1 - gman*CTman)*rd - kman*reman
@show gauto = p*xg/((p - cauto)*tg)                  # 1/hr
@show reauto = rd + sqrt((p - cauto)*gauto*rd/kauto) # units/hr
@show CTauto = 1/(reauto - rd)                       # hr
@show TPauto = (p - cauto)*(1 - gauto*CTauto)*rd - kauto*reauto;

## Sec. 4. Make-to-stock design
# Code block 16: F(j; μ), the probability of j or fewer, Poisson mean μ
function poissoncdf(j, μ)
    pℓ = exp(-μ)                  # Pr(D_L = 0)
    F = pℓ                        # F(0; μ)
    for ℓ in 1:j
        pℓ *= μ/ℓ                 # Pr(D_L = ℓ), from Pr(D_L = ℓ - 1)
        F += pℓ                   # F(ℓ; μ), from F(ℓ - 1; μ)
    end
    return F
end

# Sec. 4. Make-to-stock design
## Model: Make-to-stock design
# Model: make-to-stock design, machines and maximum FGI by search
# Fraction out of stock, average FGI, total profit, and the best design
pi0(qmax, μ) = qmax == 0 ? 1.0 : 1 - poissoncdf(qmax - 1, μ)
# pi0 and qbar are Lecture 6.2's, exact here, since every stockout is
# backordered. With $q_{\max} = 0$ nothing is held and every demand waits,
# so $\pi_0 = 1$ is set directly, $F(-1; \mu)$ not being defined.
qbar(qmax, μ) = sum(poissoncdf(j, μ) for j in 0:qmax-1; init = 0.0)
function TPmts(m, qmax; g = g, h = h, k = k)
# The lead time is the cycle time of tct, Code block 11, with $m$
# machines, whose capacity $m / t_e$ is charged at $k$, and the finished
# goods are carried at $k + c$. The delay discount factor, the carrying
# rate and the unit capital cost are keyword arguments, each the example's
# unless another is given.
    t = tct(m)                  # hr, cycle time, the lead time
    μ = ra*t                    # units, mean demand during a lead time
    sales = (p - c)*(1 - pi0(qmax, μ)*g*t)*rd   # $/hr, on sales
    carry = (k + c)*h*qbar(qmax, μ)             # $/hr, carrying FGI
    return sales - carry - k*m/te               # $/hr, total profit
end
function maxTPmts(; g = g, h = h, k = k,
# Each level from 0 to $2 r_a$, the upper bound of Lecture 6.2 ({{< xref
# 6.2 eq-qmax-ub >}}), is tried in turn at each number of machines, and
# machines are added while the best total profit still rises.
                  qmaxs = 0:2round(Int, ra))
    bestat(m) = maximum((TPmts(m, q; g, h, k), m, q)
    # maximum compares the tuples by their first entry, the total profit,
    # so bestat(m) returns the best level at $m$ machines together with
    # its total profit and $m$.
                        for q in qmaxs)
    m = floor(Int, ra*te + 1)   # m_min, the fewest machines
    best = bestat(m)            # ($/hr, machines, maximum FGI)
    while bestat(m + 1)[1] > best[1]
        m += 1
        best = bestat(m)
    end
    return best
end

# Example 4: Cost of a unit of capacity
## Example 4(b): In code
# Compute the same costs in Julia and compare them with part (a)'s.
# Code block 17: unit capital and operating cost of Ex. 4
i = 0.04                        # cost of capital
N = 5                           # yr, economic life
F = 10_000                      # units/yr, annual demand
IV = 59_000                     # $, investment cost
H = 2000                        # hr/yr, annual operating hours
u = 0.95                        # estimated utilization
OC = 500_000                    # $/yr, operating cost

@show SV = 0.25*IV                      # $, salvage value
@show IVeff = IV - SV*(1 + i)^(-N)      # $, effective investment cost
@show K = IVeff*(i/(1 - (1 + i)^(-N)))  # $/yr, capital recovery cost
@show rd = F/H                          # units/hr, known departure rate
@show re = rd/u                         # units/hr, estimated capacity
@show k = (K/H)/re                      # $/unit, unit capital cost
@show c = OC/F;                         # $/unit, unit operating cost

# Example 5: Stock level for one-machine producer
## Example 5(b): In code
# Determine the same values with the implementation of @mdl-mts, and
# compare them with part (a)'s.
# Code block 18: Ex. 5's data
p = 30                          # $/unit, unit price
c = 20                          # $/unit, unit operating cost
k = 1                           # $/unit, unit capital cost
tg = 0.5                        # hr, delay
xg = 0.2                        # share of the price lost over tg
@show g = p*xg/((p - c)*tg)     # 1/hr, delay discount factor
th = 8                          # hr, obsolescence time
xh = 0.8                        # share of the value lost over th
@show h = xh/th                 # 1/hr, inventory carrying rate
y = 1                           # yield
rd = 3                          # units/hr, departure rate
@show ra = rd/y                 # units/hr, arrival rate of work
ca2 = 1                         # arrival SCV
@show t0 = 10/60                # hr, natural process time
c02 = 0                         # natural process SCV
A = 1                           # availability, no failures
@show te = t0/A                 # hr, effective process time
@show ce2 = c02;                # effective process SCV, with A = 1
# Code block 19: Ex. 5 with one machine, every level from 0 to 3
m = 1                           # machines
@show t = tct(m)                # hr, cycle time, the lead time
@show μ = ra*t                  # units, mean demand during a lead time
@show poissoncdf(0, μ)          # F(0; μ)
@show poissoncdf(1, μ)          # F(1; μ)
@show poissoncdf(2, μ)          # F(2; μ)
qs = 0:3                        # maximum FGI
TPs = TPmts.(m, qs)             # $/hr, total profit at each level
prt([pi0.(qs, μ) qbar.(qs, μ) TPs]; rows = qs, row_title = "qmax",
    cols = ["pi0", "qbar", "TP"], fracdig = 4)
@show TPmto(m)                  # $/hr, make-to-order, no FGI
@show (p - c - k)*rd;           # $/hr, the upper bound on TP

# Example 6: Machines and stock level for make-to-stock producer
## Example 6(a): The published design
# Determine the probability out of stock, the average inventory, the
# total profit, and the upper bound of two machines with $q_{\max} = 6$,
# by @mdl-mts.
# Code block 20: Ex. 6's data
p = 30                          # $/unit, unit price
c = 20                          # $/unit, unit operating cost
k = 1                           # $/unit, unit capital cost
tg = 0.5                        # hr, delay
xg = 0.2                        # share of the price lost over tg
@show g = p*xg/((p - c)*tg)     # 1/hr, delay discount factor
th = 8                          # hr, obsolescence time
xh = 0.8                        # share of the value lost over th
@show h = xh/th                 # 1/hr, inventory carrying rate
y = 1                           # yield
rd = 10                         # units/hr, departure rate
@show ra = rd/y                 # units/hr, arrival rate of work
ca2 = 1                         # arrival SCV
@show t0 = 10/60                # hr, natural process time
c02 = 0                         # natural process SCV
A = 1                           # availability, the machines never fail
@show te = t0/A                 # hr, effective process time
@show ce2 = c02                 # effective process SCV, with A = 1
m = 2                           # machines
qmax = 6                        # maximum FGI
# Code block 21: the published design, two machines and 6 units
@show mmin = floor(Int, ra*te + 1)   # minimum number of machines
@show re = m/te                 # units/hr, capacity
@show u = ra*te/m               # utilization
@show CT = tct(m)               # hr, cycle time at the workstation
@show CTq = CT - te             # hr, cycle time in queue
@show μ = ra*CT                 # units, mean demand during a lead time
@show π0 = pi0(qmax, μ)         # probability out of FGI
@show q̄ = qbar(qmax, μ)         # units, average FGI
@show TP = TPmts(m, qmax)       # $/hr, total profit
@show TPUB = (p - c - k)*rd;    # $/hr, upper bound on TP

## Example 6(b): The best design
# Determine the number of machines and the maximum inventory that
# maximize total profit, from the minimum number of machines and from no
# inventory, and check the best against the upper bound.
# Code block 22: every number of machines and maximum level, and the best
ms = 2:5                        # machines, from m_min
qmaxs = 0:2round(Int, ra)       # maximum FGI, 0 to the bound 2 r_a
bestq = [maximum((TPmts(m, q), q) for q in qmaxs) for m in ms]
prt([first.(bestq) last.(bestq)]; rows = ms, row_title = "m",
    cols = ["TP*", "qmax*"])
TPᵒ, mᵒ, qᵒ = maxTPmts();       # $/hr, machines, and maximum FGI
@show TPᵒ
@show mᵒ
@show qᵒ;
# Code block 23: total profit against the maximum FGI, by machines
bluec = colorant"#1f6fb5"       # determined: total profit
redc = colorant"#d21f26"        # given: the published design
qq = 0:14                       # maximum FGI drawn
alphas = [1.0, 0.75, 0.55, 0.4] # the darker the fewer machines
fig = Figure(size = (600, 320))
ax = Axis(fig[1, 1]; xlabel = L"\text{Maximum FGI, } q_{\max}",
          ylabel = L"TP \text{ (\$/hr)}", xticks = 0:2:14,
          xlabelsize = 15, ylabelsize = 15, xticklabelsize = 13,
          yticklabelsize = 13)
for (i, mi) in enumerate(ms)
    tps = [TPmts(mi, q) for q in qq]
    lines!(ax, qq, tps; color = (bluec, alphas[i]), linewidth = 2)
    text!(ax, qq[end], tps[end]; text = L"m = %$(mi)",
          align = (:left, :center), offset = (5, 0), fontsize = 13,
          color = (bluec, min(1, alphas[i] + 0.2)))  # a shade darker
end
scatter!(ax, [qᵒ], [TPᵒ]; color = bluec, markersize = 11)
text!(ax, qᵒ, TPᵒ; text = "best, \$" * string(round(TPᵒ, digits = 2)),
      align = (:left, :bottom), offset = (6, 4), fontsize = 13,
      color = bluec)
scatter!(ax, [qmax], [TP]; color = redc, markersize = 11)
text!(ax, qmax, TP;
      text = "published, \$" * string(round(TP, digits = 2)),
      align = (:right, :bottom), offset = (-6, 4), fontsize = 13,
      color = redc)
xlims!(ax, -0.5, 16.5)
ylims!(ax, 40, 82)
fig

## Example 6(c): Doubled and halved costs
# Determine the best design with the delay discount factor doubled and
# halved, the carrying rate doubled and halved, and the unit capital
# cost doubled.
# Code block 24: the best design as g, h and k move
labels = ["as given", "g doubled", "g halved", "h doubled", "h halved",
          "k doubled"]
best = [maxTPmts(), maxTPmts(g = 2g), maxTPmts(g = g/2),
        maxTPmts(h = 2h), maxTPmts(h = h/2),
        maxTPmts(k = 2k)]       # ($/hr, machines, maximum FGI) of each
ks = [k, k, k, k, k, 2k]        # $/unit, unit capital cost of each
TPUBs = (p - c .- ks)*rd        # $/hr, upper bound of each
prt([getindex.(best, 2) getindex.(best, 3) getindex.(best, 1) TPUBs];
    rows = labels, cols = ["m*", "qmax*", "TP*", "TP_UB"])
