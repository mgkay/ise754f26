# intro_examples.jl -- the parameters and results of Lecture 1.1's worked examples.
#
# ONE PROVENANCE PER NUMBER (instructor, 2026-08-16): "every number reported should have
# a single provenance." Lecture 1.1 computes these and reports them; Lecture 1.2 Sec. 3.2
# reports several of them again, when it runs the nine checks on 1.1's examples. Written
# twice they are two numbers that happen to agree today, and a change to any parameter --
# the population, the demand bracket, the trailer cube, the commuting times -- would leave
# 1.2 quietly stating what 1.1 no longer says.
#
# So they are defined once, here, and both lectures `include` this file. Drift is then
# structurally impossible rather than something a checker has to notice.
#
# WHY THIS FILE AND NOT A CHECK. tools/lint_lecture.py PROSE-09 already enforces the rule
# inside a `.result-box`, and was deliberately narrowed on 2026-08-01 because "distinguishing
# an input from a result outside the result-box would need the Julia to be executed". True
# within one lecture. It does not cover a value COMPUTED IN ANOTHER LECTURE, which is never
# a problem input for the lecture quoting it -- that case is decidable and is now checked
# (PROSE-10), but a check reports drift after the fact whereas a shared definition prevents
# it.
#
# Included with `include("../_common/julia/intro_examples.jl")` from a lecture's hidden
# setup chunk. Stdlib only apart from Statistics, which 1.1 already loads.

using Statistics

# Thousands separator, so a lecture quoting these can print them the way 1.1 does.
# 1.1 defines the same one-liner in its own setup chunk and is left alone; this is a
# formatter, not data, so a duplicate cannot make two lectures disagree about a value.
commafmt(n) = replace(string(n),
    r"(?<=[0-9])(?=([0-9]{3})+$)" => ",")   # 300000000 -> "300,000,000"

# --- Ex. 1: How many McDonald's restaurants in the U.S.? ----------------------------
mcd_LB = 1; mcd_UB = 350            # per-capita demand bracket (order/person-yr)
mcd_f = sqrt(mcd_LB * mcd_UB)       # geometric-mean per-capita demand
mcd_q = 300_000_000                 # U.S. population
mcd_H = 16; mcd_r = 1               # store hours/day, orders/store-min
mcd_annual = mcd_q * mcd_f
mcd_daily = mcd_annual / 365
mcd_perstore = mcd_H * 60 * mcd_r
mcd_stores = mcd_daily / mcd_perstore
mcd_actual = 14_267                 # actual U.S. count, 2013 (Statista)
mcd_pctbelow = 100 * (mcd_stores - mcd_actual) / mcd_stores
mcd_dir = mcd_actual < mcd_stores ? "below" : "above"

# The checks Lecture 1.2 runs on this example, derived from the same parameters so the
# accepted case and the rejected ones cannot drift apart.
mcd_perpersonday = mcd_f / 365           # orders per person per day; hard ceiling is 1
mcd_peopleperorder = 1 / mcd_perpersonday
mcd_f_arith = (mcd_LB + mcd_UB) / 2      # the arithmetic-mean slip
mcd_stores_arith = (mcd_q * mcd_f_arith / 365) / mcd_perstore
mcd_arith_perpersonday = mcd_f_arith / 365
mcd_arith_factor = mcd_stores_arith / mcd_actual

# --- Ex. 2: Truckloads per week --------------------------------------------------------
tl_Vtl = 3000                       # cube per truckload (ft^3/TL)
tl_lanelo = 1; tl_lanehi = 10       # lanes operating at once
tl_ratelo = 10; tl_ratehi = 60      # orders per lane-hour
tl_vsmall = (2*2*2)/12^3            # small parcel: 2-in cube (ft^3)
tl_vbig = 4*5*10                    # bulky load (ft^3)
tl_H = 15                           # operating hours per day
tl_vorder = sqrt(tl_vsmall*tl_vbig) # geom-mean order cube
tl_nlane = sqrt(tl_lanelo*tl_lanehi)
tl_rorder = sqrt(tl_ratelo*tl_ratehi)
tl_ordersday = tl_nlane*tl_rorder*tl_H
tl_cubeday = tl_vorder*tl_ordersday
tl_tlday = tl_cubeday/tl_Vtl
tl_daysbtw = 1/tl_tlday
tl_tlweek = 7*tl_tlday

# The checks Lecture 1.2 runs on this example.
tl_tlweek_nudge = 7 * (tl_vorder * tl_nlane * sqrt(2tl_ratelo * 2tl_ratehi) * tl_H) / tl_Vtl
tl_lm_ordersday = tl_lanelo * tl_ratelo * tl_H     # steered to the low corner
tl_lm_cubeday = tl_lm_ordersday * tl_vorder
tl_lm_tlweek = 7 * tl_lm_cubeday / tl_Vtl
tl_orders_per_tl = tl_Vtl / tl_vorder              # the re-associated route
tl_orders_week = tl_ordersday * 7
tl_tlweek_realt = tl_orders_week / tl_orders_per_tl

# --- Ex. 3: Commuting ------------------------------------------------------------------
com_t = [40, 40, 45, 75, 90]        # one-way travel times (min)
com_mean = mean(com_t)
com_median = median(com_t)
com_mode = argmax(x -> count(==(x), com_t), unique(com_t))
com_days = 20                       # commuting days per month
com_monthly = com_days * com_mean * 2 / 60   # round-trip hr/mo
fuel_α = 0.275; fuel_β = 5.16e-4; fuel_d = 30  # fuel-model inputs

# --- Ex. 4: Average delivery distance --------------------------------------------------
# 1.1 derives these in display math rather than code, and that derivation is the
# provenance; the values are recorded here so 1.2 can quote them without retyping.
pz_R = 3                            # delivery radius (mi)
pz_LB = 1                           # one-way distance cannot be 0
pz_oneway_guess = sqrt(pz_LB * pz_R)
pz_round_guess = 2 * pz_oneway_guess
pz_oneway_exact = 2 * pz_R / 3      # mean one-way distance over a uniform disk
pz_round_exact = 2 * pz_oneway_exact

nothing
