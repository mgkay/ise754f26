# 3-tran-3 — generated from 3-tran-3.qmd by tools/qmd_to_jl.py
# (do not edit by hand; rerun the generator after editing the .qmd)
# Cells (## title) follow the Julia VS Code extension convention.

## Get class-ready — install packages
# Run this cell once. It installs every package the course uses, at the
# versions pinned in the shared Manifest.toml, by activating the course
# project (the nearest folder above with a Project.toml) and instantiating
# it. Idempotent: packages already present at the right version are skipped.
import Pkg
let dir = @__DIR__
    while !isfile(joinpath(dir, "Project.toml")) && dir != dirname(dir)
        dir = dirname(dir)
    end
    Pkg.activate(dir)
    Pkg.instantiate()
end

## Setup
using Logjam, Optim, DataFrames

# Sec. 1. Periodic truck shipments
# Example 1: Periodic shipment of cartons
## Example 1(a): Average shipment frequency
# At the full-truckload shipment size $q = q_{\max}$, determine the
# average number of truckloads per year required to meet annual demand.
# Carryover from Transport 1-2
uwt  = 40          # lb (unit weight)
ucu  = 9           # ft^3 (unit cube)
@show s = uwt/ucu  # lb/ft^3
Kwt  = 25          # ton
Kcu  = 2750        # ft^3
@show qmax = min(Kwt, s*Kcu/2000)
# = Logjam.maxpayld(s; Kwt=Kwt, Kcu=Kcu)

# New for Transport 3
f = 20             # ton/yr (annual demand)
q = qmax           # full truckload => q = qmax
@show n = f/q      # TL/yr

## Example 1(b): Shipment interval
# Determine the time between consecutive shipments and the corresponding
# number of days.
@show t = q/f                   # yr/TL
@show days_btw_TLs = 365.25/n;  # day/TL

# Sec. 2. Full and constrained truckloads
# Example 1: Periodic shipment of cartons
## Example 1(c): Annual full-truckload transport cost
# With distance $d = 532$ mi and $PPI_\text{TL}^\text{Jan 2018} =
# 131.0$, determine the annual FTL transport cost. Then determine what
# the cost becomes if a service agreement requires shipments at least
# every three months.
d     = 532                      # Google Maps road distance, mi
ppiTL = 131.0                    # TL PPI for Jan 2018
@show rTL    = 2.00*ppiTL/102.7  # $/mi
@show rFTL   = rTL/qmax          # $/ton-mi
@show TC_FTL = n * rTL * d;      # $/yr
@show tmax    = 3/12                     # yr/TL
@show nmin    = 1/tmax                   # TL/yr
@show q′      = f/max(n, nmin)           # ton
@show TC_3mo  = max(n, nmin) * rTL * d;  # $/yr

# Sec. 4. Total logistics costs
# Example 1: Periodic shipment of cartons
## Example 1(d): Cycle inventory cost at FTL
# Give a reasonable estimate for the total annual cycle inventory cost
# at the FTL shipment size $q_{\max}$, with $v = \$25{,}000$/ton, $h =
# 0.3~\text{yr}^{-1}$, and $\alpha = 1$.
α = 1
v = 25000                   # $/ton
h = 0.3                     # 1/yr
@show IC_FTL = α*v*h*qmax;  # $/yr

## Example 1(e): Total logistics cost at FTL
# Combine the transport and inventory costs to obtain the annual total
# logistics cost (TLC) for full-truckload TL shipments.
@show TC_FTL IC_FTL
@show TLC_FTL = TC_FTL + IC_FTL;

## Example 1(f): Optimal TL shipment size
# Allowing shipment sizes less than a full truckload, determine the TL
# shipment size $q^\star_\text{TL}$ that minimises the annual TLC for TL
# service, and the resulting $TLC^\star_\text{TL}$.
@show qᵒTL    = sqrt((f*rTL*d)/(α*v*h))  # ton
@show TCᵒ_TL  = (f/qᵒTL)*rTL*d           # $/yr
@show ICᵒ_TL  = α*v*h*qᵒTL               # $/yr
@show TLCᵒ_TL = TCᵒ_TL + ICᵒ_TL;         # $/yr

## Example 1(g): Allocated FTL
# Including the minimum-charge and maximum-payload restrictions,
# determine the TLC if a shipment of size $q^\star_\text{TL}$ could be
# made as an allocated full-truckload (sharing the truck across many
# shipments).
@show TLC_AllocFTL = f*rTL/qmax*d + α*v*h*qᵒTL;  # $/yr

## Example 1(h): Optimal LTL shipment size
# Determine the LTL shipment size $q^\star_\text{LTL}$ that minimises
# the annual TLC for LTL service.
ppiLTL = 177.4

TLC_LTLh(q) = (f/q) * rate_ltl(q, s, d; ppi=ppiLTL) * q * d +
              α*v*h*q

@show LB = 150/2000  # ton (lower bound on q)
@show UB = min(5, 650*s/2000)  # ton (upper bound on q)
@show qᵒLTL = optimize(TLC_LTLh, LB, UB).minimizer;  # ton

## Example 1(i): Service choice
# Given the optimal TL and LTL shipment sizes, determine which service
# minimises annual TLC.
rLTL = rate_ltl(qᵒLTL, s, d; ppi=ppiLTL)
@show rLTL                          # $/ton-mi
@show cLTL     = rLTL * qᵒLTL * d   # $
@show TCᵒ_LTL  = (f/qᵒLTL) * cLTL   # $/yr
@show ICᵒ_LTL  = α*v*h*qᵒLTL        # $/yr
@show TLCᵒ_LTL = TCᵒ_LTL + ICᵒ_LTL  # $/yr

@show TLCᵒ_TL
TLCᵒ_TL > TLCᵒ_LTL ?
    println("LTL selected") : println("TL selected");

## Example 1(j): Service choice at higher product value
# If the unit value of the product rises to $v = \$85{,}000$/ton,
# re-determine the optimal shipment sizes and which service is selected.
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

## Example 1: Periodic shipment of cartons
tr = (r = rTL, Kwt = 25, Kcu = 2750, ppi = ppiTL)
# :a matches Logjam; math is αvh
sh = DataFrame(f=f, s=s, a=α, v=v, h=h, d=d);

## Example 1(k): A second product
# On Jan 10, 2018, determine the optimal independent shipment size and
# TLC for a second product, 80 tons/yr of Class-60 material worth
# \$5,000/ton, shipped on the same Raleigh-to-Gainesville lane.
push!(sh, first(sh))                     # duplicate the row
sh[2, [:f, :s, :v]] = [80, 32.16, 5000]  # patch the second product
sh.qmax = [maxpayld(row, tr) for row in eachrow(sh)]
transform!(sh, AsTable(:) =>
    ByRow(row -> minTLC(row, tr, ppiLTL)) => AsTable)
prt(sh)

# Sec. 5. Aggregate periodic shipment
# Example 1: Periodic shipment of cartons
## Example 1(l): Aggregate shipment
# Determine the annual TLC if the two products are always shipped
# together on the same truck, and compare to the sum of their
# independent TLCs.
ash = combine(sh,
    :f => sum => :f,
    [:f, :s] => ((f, s) -> sum(f)/sum(f ./ s)) => :s,
    [:f, :a] => ((f, a) -> sum(f .* a) / sum(f)) => :a,
    [:f, :v] => ((f, v) -> sum(f .* v) / sum(f)) => :v,
    [:f, :h] => ((f, h) -> sum(f .* h) / sum(f)) => :h,
    :d => first => :d)

ash.qmax = [maxpayld(row, tr) for row in eachrow(ash)]
transform!(ash, AsTable(:) =>
    ByRow(row -> minTLC(row, tr)) => AsTable)

@show TLC_indep = sum(sh.TLCᵒ)  # $/yr
@show TLC_agg   = ash.TLCᵒ[1];  # $/yr

# Sec. 6. Locating a facility with full truckloads
# Example 2: Locating a production plant
## Example 2(a): Full-truckload location
# With every shipment a full truckload, determine the city (population
# at least 50,000) in which to locate the plant.
Kwt, Kcu = 25, 2750  # truck weight (ton) & cube (ft³) caps

# Finished product, 175 lb & 38.2 ft³ per unit; FTL to customers
sFG = 175/38.2                                           # lb/ft³
@show qmaxFG = maxpayld(sFG; Kwt=Kwt, Kcu=Kcu)           # ton/TL
custZIP = [87301, 88101, 73099, 72118, 55408, 15010]
ud      = [2600, 2200, 700, 700, 600, 700]               # units/yr
wout = (ud .* 175 ./ 2000) ./ qmaxFG  # TL/yr per customer

# Raw materials: full truckloads in from each supplier
supName = ["Richmond", "Canton", "Malden", "Tyler"]
supST   = [:CA, :OH, :MA, :TX]
nin, nout = length(supName), length(custZIP)  # suppliers, customers
wt  = [8, 14, 4, 29]                                     # lb/unit
cu  = [2.7, 1.3, 2.7, 3.6]                               # ft³/unit
BOM = [4, 1, 1, 1]  # raw units per finished unit
qmaxRaw = maxpayld.(wt ./ cu; Kwt=Kwt, Kcu=Kcu)          # ton/TL
fin = (BOM .* sum(ud)) .* wt ./ 2000  # ton/yr from suppliers
win = fin ./ qmaxRaw  # TL/yr from each supplier

# Geolocate the ten endpoints (loc2lonlat); weight w ∝ truckloads
locs = vcat([loc2lonlat(supName[i]; state=supST[i]) for i in 1:nin],
            [loc2lonlat(string(z)) for z in custZIP])
XY = hcat([r.LON for r in locs], [r.LAT for r in locs])  # n×2
w  = vcat(win, wout)
role = [fill("supplier", nin); fill("customer", nout)]
flows = DataFrame(place = vcat(supName, string.(custZIP)),
                  role = role,
                  qmax = vcat(qmaxRaw, fill(qmaxFG, nout)),
                  nFTL = w)
prt(flows; title="full truckloads to/from the plant (TL/yr)")

# Minisum over wᵢ·dgc, then snap to a city of pop ≥ 50,000
x0 = vec(sum(XY, dims=1)) ./ size(XY, 1)  # centroid (any dim)
sumwd(p, w) = sum(w[i]*dgc(p, XY[i, :])
                  for i in 1:size(XY, 1))
                  # sum(expr for i in ...) is a generator handed
                  # straight to sum: each weighted distance
                  # $w_i\,d_\text{gc}(p, XY_i)$ is produced lazily
                  # and accumulated, with no intermediate array
                  # allocated. It is the idiomatic Julia spelling of
                  # $\sum_i w_i d_i$.
locate(w) = lonlat2loc(
    Optim.minimizer(optimize(p -> sumwd(p, w), x0)),
    filter(r -> r.POP >= 50_000 && r.ISCUS, usplace()))
plant = locate(w)
@show (plant.NAME, plant.ST);

## Example 2(b): Effect of biweekly delivery
# Determine how the optimal location and the annual transport cost
# change if every customer delivery must be made at least once every two
# weeks. Use a January 2018 TL PPI of 131.0.
# Customer deliveries at least biweekly: floor OUTBOUND only
nmin = 365.25/14                  # min TL/yr at a 2-week interval
flows.n = [r == "customer" ? max(nf, nmin) : nf
           for (r, nf) in zip(flows.role, flows.nFTL)]
prt(flows; title="biweekly floor on customers (nFTL → n)")

plant2 = locate(flows.n)  # re-optimize with constrained weights
@show (plant2.NAME, plant2.ST)
rA = loc2lonlat(plant.NAME;  state=plant.ST)
rB = loc2lonlat(plant2.NAME; state=plant2.ST)
A = [rA.LON, rA.LAT]; B = [rB.LON, rB.LAT]
@show move_mi = dgc(A, B)

rTL = 2*131.0/102.7               # $/mi (Jan 2018 TL PPI)
TC(c, w) = rTL * sum(w[i]*1.2*dgc(c, XY[i, :])
                     for i in 1:size(XY, 1))
@show TC_ftl = TC(A, flows.nFTL)  # FTL
@show TC_con = TC(B, flows.n)     # biweekly
@show cost_impact = TC_con - TC_ftl
@show reloc_saving = TC(A, flows.n) - TC_con;
