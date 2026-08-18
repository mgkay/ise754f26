# 1-intr-2-workspace.jl — the short tour pictured in Figure 1 of
# Lecture 1.2 (§1.1). Open it in VS Code, run "Julia: Start REPL", then
# run each `##` cell -- click inside it, then press Alt+Enter -- to see
# the cell-by-cell workflow the figure shows.
# The packages load once the lecture's "## Get class-ready" cell (§1.9)
# has installed them.

## A first DataFrame
using DataFrames
ship = DataFrame(
    origin = ["RDU", "RDU", "GSO"],
    ton    = [12, 5, 18])
ship.ton

## A first plot
using CairoMakie
f(x) = x - x^3
xrng = -2:0.01:2
lines(xrng, f)
