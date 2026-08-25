# 1-intr-3 — generated from 1-intr-3.qmd by tools/qmd_to_jl.py
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
using CairoMakie, Random
# apparatus.jl ships beside the lectures in the materials
# repository. Find it from the activated project rather
# than from this file, so the script still works from a
# copy under work/.
let p = dirname(Base.active_project())
    include(joinpath(basename(p) == "env" ? dirname(p) : p,
                     "_common", "julia", "apparatus.jl"))
end

## Sec. 6. Level 2: Cycle-time estimation
let
    t₀   = [0.20, 0.50, 0.25, 0.15]  # natural process time (hr)
    MTTF = [40.0, Inf, 100.0, Inf]  # mean time to failure (hr)
    MTTR = [2.0, 0.0, 5.0, 0.0]           # mean time to repair (hr)
    m    = [3, 6, 3, 2]                   # machines per station
    y    = [0.85, 0.90, 0.95, 0.98]       # yield
    c²₀  = [0.25, 0.0, 0.0, 0.50]         # natural process-time SCV
    c²ᵣ  = [1.0, 0.0, 0.0, 0.0]           # repair-time SCV
    mc   = [12, 18, 2, 6]                 # machine cost ($000 each)
    out  = 10.0  # required good units/hr from the last station

    nₛ = length(m)
    A  = [isinf(MTTF[j]) ? 1.0 : MTTF[j] / (MTTF[j] + MTTR[j]) for j in 1:nₛ]
    tₑ = t₀ ./ A
    rₐ = zeros(nₛ); rₐ[nₛ] = out / y[nₛ]  # work back through yield
    for j in nₛ-1:-1:1
        rₐ[j] = rₐ[j+1] / y[j]
    end
    u   = rₐ .* tₑ ./ m
    c²ₑ = c²₀ .+ (1 .+ c²ᵣ) .* A .* (1 .- A) .* MTTR ./ t₀

    c²ₐ = zeros(nₛ); cd2 = zeros(nₛ); CTq = zeros(nₛ); CT = zeros(nₛ)
    c²ₐ[1] = 1.0
    for j in 1:nₛ
        CTq[j] = (c²ₐ[j] + c²ₑ[j]) / 2 *
                 u[j]^(sqrt(2(m[j] + 1)) - 1) / (m[j] * (1 - u[j])) * tₑ[j]
        CT[j]  = CTq[j] + tₑ[j]
        cd2[j] = 1 + (1 - u[j]^2) * (c²ₐ[j] - 1) + u[j]^2 / sqrt(m[j]) * (c²ₑ[j] - 1)
        j < nₛ && (c²ₐ[j+1] = cd2[j])
    end
    WIP = rₐ .* CT
    wsc = m .* mc

    g(x, d) = d == 0 ? string(Int(round(x))) : string(round(x, digits = d))
    lab = ["Arrival SCV \$c_a^2\$", "Natural process SCV \$c_0^2\$",
           "Eff. process SCV \$c_e^2\$", "Departure SCV \$c_d^2\$",
           "Cycle time in queue \$CT_q\$ (hr)", "Cycle time \$CT\$ (hr)",
           "WIP at W/S", "W/S cost (\\\$000)"]
    val = Any[c²ₐ, c²₀, c²ₑ, cd2, CTq, CT, WIP, Float64.(wsc)]
    dig = [3, 2, 3, 3, 3, 3, 2, 0]
    tot = [false, false, false, false, true, true, true, true]
    rows = [[lab[i], g(val[i][1], dig[i]), g(val[i][2], dig[i]),
             g(val[i][3], dig[i]), g(val[i][4], dig[i]),
             tot[i] ? g(sum(val[i]), dig[i]) : ""] for i in eachindex(lab)]
    mdtable([" ", "W/S 1", "W/S 2", "W/S 3", "W/S 4", "Total"], rows;
        align     = [:l, :r, :r, :r, :r, :r],
        colwidths = [40, 12, 12, 12, 12, 12],
        caption   = "Cycle-time and total machine-cost estimation for the four-workstation line, extending @tbl-feasible.",
        label     = "tbl-cycle")
end

# Sec. 6. Level 2: Cycle-time estimation
## Example 5: Pizza delivery time
# The pizza shop whose delivery area was sized in {{< xref 1.1 example-4
# >}} runs $m$ delivery drivers against Poisson demand. How long does a
# customer wait from order to delivery, and how does that depend on the
# number of drivers?
let
    tₑ  = 1/6  # 10-min round trip (4 mi at 24 mph), one pizza at a time
    rₐ  = 20.0  # Poisson orders per hour
    c²ₐ = 1.0; c²ₑ = 1.0
    g(x, d) = string(round(x, digits = d))
    rows = map(4:8) do m
        u   = rₐ * tₑ / m
        ctq = (c²ₐ + c²ₑ)/2 * u^(sqrt(2(m + 1)) - 1) / (m*(1 - u)) * tₑ
        ct  = ctq + tₑ
        [string(m), g(u, 3), g(60ctq, 1), g(60ct, 1)]
    end
    mdtable(["drivers \$m\$", "utilization \$u\$", "queue wait (min)", "delivery time (min)"],
        rows;
        caption = "Average pizza delivery time vs. number of drivers, from @eq-vutm " *
                  "(\$r_a = 20\$/hr Poisson, \$t_e = 10\$ min, \$c_a^2 = c_e^2 = 1\$). " *
                  "The last column is the order-to-door cycle time \$t_{CT}\$.",
        label = "tbl-pizza")
end

# Sec. 7. Level 3: Simulation
## Model: Poisson arrival simulation
# Model: Poisson arrival simulation
simulate(rₐ, n) = [-log(rand()) / rₐ for _ in 1:n]

## Sec. 7. Level 3: Simulation
# Code block 1: arrivals simulated, mean and SCV
using Random
Random.seed!(1)                             # reproducible draws
tₐ  = simulate(5, 100_000)                  # inter-arrival times
μ   = sum(tₐ) / length(tₐ)                  # mean ≈ 1/rₐ = 0.2 hr
c²ₐ = sum((tₐ .- μ).^2) / length(tₐ) / μ^2  # SCV ≈ 1
(μ, c²ₐ)

## Model: Single-server queue simulation
# Model: single-server FIFO queue simulation
function queue(rₐ, tₑ, n)
    ct = zeros(n)                  # cycle time of each job
    wq = 0.0                       # work waiting when a job arrives
    for i in 1:n
        s = -tₑ * log(rand())      # exponential service time
        ct[i] = wq + s             # cycle time = wait + service
        a = -log(rand()) / rₐ      # gap to the next arrival
        wq = max(0.0, wq + s - a)  # Lindley recursion
    end
    return ct
end

## Sec. 7. Level 3: Simulation
# Code block 2: simulated cycle time against the VUT formula
Random.seed!(1)
ct  = queue(8, 0.1, 10_000)    # rₐ = 8/hr, tₑ = 0.1 hr, so u = 0.8
sim = sum(ct) / length(ct)     # simulated mean cycle time
u   = 8 * 0.1
vut = u / (1 - u) * 0.1 + 0.1  # analytic CT (eq-vut, c² = 1)
(sim, vut)
# Code block 3: twenty replications and a confidence interval
Random.seed!(2)
nrep = 20                      # independent replications
njob = 1_000_000               # jobs per replication
reps  = [sum(queue(8, 0.1, njob)) / njob for _ in 1:nrep]
grand = sum(reps) / nrep       # grand mean over the experiment
se    = sqrt(sum((reps .- grand).^2) / (nrep*(nrep - 1)))
ci    = 1.96 * se              # 95% confidence half-width
(grand, ci, vut)               # grand mean, half-width, target 0.5

## Model: Single-server SPT queue simulation
# Model: single-server SPT queue simulation
function queue_spt(rₐ, tₑ, n)
    at = cumsum([-log(rand()) / rₐ for _ in 1:n])  # arrivals
    st = [-tₑ * log(rand()) for _ in 1:n]  # service times
    ct = zeros(n)              # cycle time of each job
    pend = Int[]               # jobs waiting for the server
    t, i = 0.0, 1              # clock, next arrival index
    for _ in 1:n
        while i ≤ n && at[i] ≤ t   # arrivals up to time t
            push!(pend, i); i += 1
        end
        if isempty(pend)           # idle: jump to next arrival
            t = at[i]; push!(pend, i); i += 1
        end
        j = argmin(k -> st[k], pend)   # shortest job next
        filter!(k -> k ≠ j, pend)
        t += st[j]                 # serve job j to completion
        ct[j] = t - at[j]          # cycle time = finish - arrival
    end
    return ct
end

## Sec. 7. Level 3: Simulation
# Code block 4: FIFO against SPT at the same station
Random.seed!(1)
fifo = queue(8, 0.1, 100_000)      # FIFO baseline
spt  = queue_spt(8, 0.1, 100_000)  # same station, SPT
(sum(fifo) / length(fifo), sum(spt) / length(spt))

## Sec. 8. Stationarity
# Barber-shop queue model (M/D/1), shared by @tbl-stationary and
# @fig-transient. One empty-start run of `hrs` hours: Poisson arrivals
# at rate rₐ, one server, deterministic service tₑ, FIFO. simq averages
# the mean cycle time in queue over `m` independent runs.
tₑ = 1 / 6  # 10-min cut ⇒ rₑ = 6/hr, cₑ² = 0 (M/D/1)
function barberq(rₐ, tₑ, hrs)
    t = 0.0; dep = 0.0; wsum = 0.0; n = 0
    while (t += -log(rand()) / rₐ) ≤ hrs  # next Poisson arrival
        wq    = max(0.0, dep - t)  # wait behind the previous departure
        wsum += wq; n += 1
        dep   = t + wq + tₑ  # deterministic service
    end
    return n == 0 ? 0.0 : wsum / n
end
simq(rₐ, tₑ, hrs, m) = sum(barberq(rₐ, tₑ, hrs) for _ in 1:m) / m
nothing
let
    Random.seed!(1)
    f(x) = string(round(x, digits = 4))
    cases = [(5, 1, 8760), (5, 500, 8760), (5, 500, 10), (4, 500, 10), (2, 500, 10)]
    rows  = map(enumerate(cases)) do (i, case)
        rₐ, nruns, hrs = case
        u   = rₐ * tₑ
        est = 0.5 * u / (1 - u) * tₑ  # M/D/1 estimate: (cₐ²+cₑ²)/2 = 0.5
        sim = simq(rₐ, tₑ, hrs, nruns)
        [string(i), string(rₐ), "6", string(nruns), string(hrs), f(u), f(sim), f(est), f(sim / est)]
    end
    mdtable([" ", "\$r_a\$", "\$r_e\$", "nruns", "nhrs", "\$u\$",
             "\$CT_q\$ sim", "\$CT_q\$ est", "sim/est"], rows;
        caption = "Barber-shop cycle time in queue, simulated vs. the steady-state " *
                  "estimate (\$M/D/1\$, \$r_e = 6\$/hr). Over a full year (8,760 hr) " *
                  "the simulation matches the estimate; over a 10-hour day the queue " *
                  "stays in its transient and the average wait falls short.",
        label   = "tbl-stationary")
end

# Sec. 9. Where variability goes in a line
## Example 6: Where should the variable station go?
# Three single-machine stations run in series, each at utilization $u =
# 0.9$ and the same mean process time $t_e = 0.1$ hr, but with
# process-time variabilities $c_e^2 = 0.25$, $1$, and $4$; work enters
# the first at $c_a^2 = 1$. Compare the line's total cycle time when the
# most variable station is run last versus first.
# Code block 5: station order and its effect on cycle time
u  = 0.9  # utilization at each station
tₑ = 0.1  # hr, same mean process time
for order in ([0.25, 1, 4], [4, 1, 0.25])
    CT = let c²ₐ = 1.0, total = 0.0
        for c²ₑ in order
            CTq = (c²ₐ + c²ₑ)/2 * u/(1 - u) * tₑ
            total += CTq + tₑ              # station cycle time
            c²ₐ = (1 - u^2)*c²ₐ + u^2*c²ₑ  # to next (eq-cd)
        end
        total
    end
    @show order, CT
end
