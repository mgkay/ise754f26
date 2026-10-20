# 4-net-1 — generated from 4-net-1.qmd by tools/qmd_to_jl.py
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

using CairoMakie, DataFrames, Graphs, Logjam, SimpleWeightedGraphs
# Two device pixels per figure unit, as in lectures 3.2 to 3.4, so the
# raster figures are sharp at the column's own width.
CairoMakie.activate!(px_per_unit = 2)
# Every package a later cell loads, and the colors the figures share, loaded
# and defined here as well, so a cell added at the end of the script runs
# after this Setup cell alone
using CSV, GeoMakie, HiGHS, HTTP, JSON3, JuMP
supc  = colorant"#d21f26"               # as in Code block 2
dcc   = colorant"#1e8a3c"
ink   = colorant"#252525"
redc  = colorant"#d21f26"               # as in Code block 13
bluec = colorant"#1f6fb5"               # as in Code block 33
# Presentation plumbing for the prose: a number with thousands separators,
# and minutes as hours and minutes
function commas(x)
    s = string(x)
    k = something(findfirst('.', s), lastindex(s) + 1)
    return replace(s[1:k-1], r"(?<=\d)(?=(\d{3})+$)" => ",") * s[k:end]
end
hm(x) = (m = round(Int, x); "$(m ÷ 60) h $(m % 60) min")

## Sec. 1. Network representations
# Code block 1: the three-node digraph, drawn from its arc list
XY3 = [0.0 0.0; 2.0 0.0; 1.0 1.5]       # node positions
r3  = 0.22                              # node radius, data units
c3  = vec(sum(XY3, dims = 1)) ./ 3      # the centroid, to place labels
fig = Figure(size = (300, 250))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for (i, j, w) in zip([1, 3, 3], [2, 1, 2], [1, 3, 2])
    p, q = XY3[i, :], XY3[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    t, h = p .+ r3 .* u, q .- (r3 + 0.015) .* u   # outline to outline
    arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
              color = colorant"#252525", shaftwidth = 1.5, tipwidth = 9,
              tiplength = 9)
    m = (p .+ q) ./ 2
    m = m .+ 0.2 .* (m .- c3) ./ hypot((m .- c3)...)   # outside the arc
    text!(ax, m[1], m[2]; text = string(w), fontsize = 14,
          align = (:center, :center), color = colorant"#252525")
end
for k in 1:3
    poly!(ax, Circle(Point2f(XY3[k, 1], XY3[k, 2]), r3); color = :white,
          strokecolor = colorant"#252525", strokewidth = 1.8)
    text!(ax, XY3[k, 1], XY3[k, 2]; text = string(k), fontsize = 15,
          align = (:center, :center), color = colorant"#252525")
end
xlims!(ax, -0.4, 2.4); ylims!(ax, -0.45, 1.85)
fig
# Code block 2: a network of two groups, suppliers 1-3 and DCs 4-5
supc = colorant"#d21f26"                 # suppliers
dcc  = colorant"#1e8a3c"                 # DCs
ink  = colorant"#252525"
r    = 0.24                              # node radius, data units
XY   = [0.0 2.0; 0.0 1.0; 0.0 0.0; 2.4 1.6; 2.4 0.4]  # node positions

# One arc from node i to node j, outline to outline: kind :one (an arrow),
# :two (a two-way arc, no arrowhead) or :absent (dashed); off shifts it
# sideways, for a pair of parallel arcs
function arc!(ax, i, j, lab; kind = :one, off = 0.0, lpos = 0.5,
              lside = 1)
    p, q = XY[i, :], XY[j, :]
    u = (q .- p) ./ hypot((q .- p)...)
    nrm = [-u[2], u[1]]                  # unit normal
    s = asin(clamp(off / r, -1, 1))      # where a shifted arc meets
    t = p .+ r * cos(s) .* u .+ off .* nrm   # the circle
    h = q .- (r * cos(s) + 0.015) .* u .+ off .* nrm
    if kind == :absent
        lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = ink, linewidth = 1,
               linestyle = :dash)
    elseif kind == :two
        lines!(ax, [t[1], h[1] + 0.015u[1]], [t[2], h[2] + 0.015u[2]];
               color = ink, linewidth = 1.5)
    else
        arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                  color = ink, shaftwidth = 1.5, tipwidth = 9,
                  tiplength = 9)
    end
    if !isempty(lab)
        m = t .+ lpos .* (h .- t)
        text!(ax, m[1], m[2]; text = lab, color = ink, fontsize = 14,
              align = (:center, :center),
              offset = (12lside * nrm[1], 12lside * nrm[2]))
    end
    return nothing
end

function twogroup(arcs; w = 340, h = 300)
    fig = Figure(size = (w, h))
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    for (i, j, lab, kw) in arcs
        arc!(ax, i, j, lab; kw...)
    end
    for k in 1:size(XY, 1)               # the nodes, over the arcs
        x, y = XY[k, :]
        c = k <= 3 ? supc : dcc
        poly!(ax, Circle(Point2f(x, y), r); color = :white,
              strokecolor = c, strokewidth = 1.8)
        text!(ax, x, y; text = string(k), color = c, fontsize = 15,
              align = (:center, :center))
    end
    xlims!(ax, -0.4, 2.8); ylims!(ax, -0.4, 2.4)
    return fig
end

twogroup([(1, 4, "6", (lpos = 0.25,)),
          (1, 5, "10", (lpos = 0.2, lside = -1)),
          (2, 4, "0", (lpos = 0.3,)),
          (2, 5, "13", (lpos = 0.3, lside = -1)),
          (3, 4, "9", (lpos = 0.2,)),
          (3, 5, "16", (lpos = 0.3, lside = -1))])
# Code block 3: the weighted adjacency matrix of the digraph
W = [0. 0. 0. 6. 10.
     0. 0. 0. 0. 13.
     0. 0. 0. 9. 16.
     0. 0. 0. 0. 0.
     0. 0. 0. 0. 0.]
# Code block 4: a digraph from the adjacency matrix
using Graphs, SimpleWeightedGraphs
g = SimpleWeightedDiGraph(W)      # Create digraph from adjacency matrix
println.(edges(g));
# Code block 5: a digraph from its arc list
i = [1, 1, 2, 2, 3, 3]             # source node of each arc
j = [4, 5, 4, 5, 4, 5]             # destination node of each arc
w = [6., 10., 0., 13., 9., 16.]    # weight of each arc
g = SimpleWeightedDiGraph(i, j, w) # Create digraph using arc lists
println.(edges(g));
# Code block 6: the adjacency matrix, a view of the digraph
@show has_edge(g, 2, 4)            # Arc 2 => 4 is in the digraph
Matrix(adjacency_matrix(g))
# Since the adjacency matrix is stored as a sparse matrix, convert it to a
# regular (dense) matrix for display purposes.
# Code block 7: the bipartite graph, drawn with Code block 2's twogroup
twogroup([(1, 4, "6", (kind = :two,)),
          (1, 5, "10", (lpos = 0.2, lside = -1)),
          (2, 4, "0", (lpos = 0.3,)),
          (2, 5, "13", (lpos = 0.3, lside = -1)),
          (3, 4, "", (kind = :absent,)),
          (3, 5, "16", (off = 0.06,)), (5, 3, "3", (off = 0.06,))])
# Code block 8: the bipartite graph, a digraph from its arc list
i = [4, 5, 1, 2, 1, 2, 3]          # arc 1-4 listed both ways
j = [1, 3, 4, 4, 5, 5, 5]
w = [6., 3., 6., 0., 10., 13., 16.]
g = SimpleWeightedDiGraph(i, j, w)
println.(edges(g));
# Code block 9: the arcs of Code block 5, undirected
g = SimpleWeightedGraph([1, 1, 2, 2, 3, 3], [4, 5, 4, 5, 4, 5],
                        [6., 10., 0., 13., 9., 16.])   # Create graph
Matrix(adjacency_matrix(g))   # Both directions represented for each arc
# Code block 10: the multigraph, drawn with Code block 2's twogroup
twogroup([(1, 4, "6", (kind = :two, off = 0.06)),
          (1, 4, "18", (kind = :two, off = -0.06, lside = -1)),
          (1, 5, "10", (lpos = 0.2, lside = -1)),
          (2, 4, "0", (lpos = 0.3,)),
          (2, 5, "13", (lpos = 0.3, lside = -1)),
          (3, 4, "", (kind = :absent,)),
          (3, 5, "16", (off = 0.06,)),
          (3, 5, "3", (off = -0.06, lside = -1))])
# Code block 11: the multigraph, from its arc list
i = [1, 4, 1, 4, 1, 2, 2, 3, 3]     # two-way arcs 1-4 listed both ways
j = [4, 1, 4, 1, 5, 4, 5, 5, 5]
w = [6., 6., 18., 18., 10., 0., 13., 16., 3.]
Matrix(weights(SimpleWeightedDiGraph(i, j, w)))   # parallel arcs summed
# Code block 12: keep the shorter of each pair of parallel arcs
Matrix(weights(SimpleWeightedDiGraph(i, j, w; combine = min)))

# Sec. 2. Dijkstra's procedure
## Model: Shortest path
# Model: shortest path, by Dijkstra's procedure
function dijkstra(W, s)
    n = size(W, 1)                      # Number of nodes
    d = fill(Inf, n)                    # Distance from s
    # The distance to each node from s, infinite until the node is
    # reached. Infinity sometimes causes trouble in code, and the sum of
    # all the arc lengths plus one then serves as infinity just as well.
    pred = zeros(Int, n)                # Predecessor of each node
    S = falses(n)                       # Labeled nodes: none yet
    d[s] = 0.0                          # Distance from s to s = 0
    while count(S) < n
        # Find the unlabeled node at the minimum distance (SLOW step!)
        i = 0
        for j in 1:n
            if !S[j] && (i == 0 || d[j] < d[i])
            # i == 0 means that no unlabeled node has been found yet in
            # this pass, so the first one met becomes the candidate, and
            # each later one replaces it only if its distance is smaller.
                i = j
            end
        end
        S[i] = true                     # Label node i
        # Update each node that an arc from i reaches more cheaply
        for j in 1:n
            if d[i] + W[i, j] < d[j]
                d[j] = d[i] + W[i, j]
                pred[j] = i
            end
        end
    end
    return (d = d, pred = pred)
end

## Example 1: Six-node network
# Determine the shortest path from node 1 to node 6 in the network of
# @fig-six-node, by hand, then in Julia, and then with its arcs
# directed.
# Code block 13: the six-node network
redc  = colorant"#d21f26"               # labels and labeled nodes
P6    = [0.0 0.0; 1.0 0.58; 1.0 -0.58; 2.0 0.58; 2.0 -0.58; 3.0 0.0]
A6    = [1 2 4; 1 3 2; 2 3 1; 2 4 5; 3 4 8; 3 5 10; 4 5 2; 4 6 6; 5 6 3]
r6    = 0.15                            # node radius, data units
side  = [1, -1, -1, 1, 1, 1, -1, 1, -1] # side of each arc for its length
under = [true, false, true, false, true, true]  # label below the node?

# The network on ax: node k labeled labels[k], the nodes in done circled
# in red, the arcs of path drawn in red, arrows if directed
function net6!(ax; labels = fill("", size(P6, 1)), done = Int[],
               path = Int[], directed = false, fs = 13)
    onpath(i, j) = any(k -> (path[k], path[k+1]) == (i, j) ||
                       (!directed && (path[k], path[k+1]) == (j, i)),
                       1:length(path)-1)
    for (k, (i, j, w)) in enumerate(eachrow(A6))
        p, q = P6[i, :], P6[j, :]
        u = (q .- p) ./ hypot((q .- p)...)
        t, h = p .+ r6 .* u, q .- r6 .* u    # outline to outline
        c, lw = onpath(i, j) ? (redc, 3.0) : (ink, 1.2)
        if directed
            arrows2d!(ax, [t[1]], [t[2]], [h[1] - t[1]], [h[2] - t[2]];
                      color = c, shaftwidth = lw, tipwidth = 9,
                      tiplength = 9)
        else
            lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = c,
                   linewidth = lw)
        end
        m = (p .+ q) ./ 2 .+ 0.11 * side[k] .* [-u[2], u[1]]
        text!(ax, m[1], m[2]; text = string(w), color = ink,
              fontsize = fs, align = (:center, :center))
    end
    for k in 1:size(P6, 1)
        x, y = P6[k, :]
        poly!(ax, Circle(Point2f(x, y), r6); color = :white,
              strokecolor = k in done ? redc : ink,
              strokewidth = k in done ? 2.5 : 1.2)
        text!(ax, x, y; text = string(k), color = ink, fontsize = fs,
              align = (:center, :center))
        isempty(labels[k]) && continue
        dy = under[k] ? -(r6 + 0.1) : r6 + 0.1
        text!(ax, x, y + dy; text = labels[k], color = redc,
              fontsize = fs, font = :bold, align = (:center, :center))
    end
    xlims!(ax, -0.35, 3.35); ylims!(ax, -0.95, 0.95)
    return nothing
end

fig = Figure(size = (420, 240))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
net6!(ax)
text!(ax, [-0.25, 3.25], [0.0, 0.0]; text = [L"s", L"t"], color = redc,
      fontsize = 17, align = (:center, :center))
fig

# Example 1: Six-node network
## Example 1(a): By hand
# Determine the shortest path from node 1 to node 6, and its length, by
# labeling the nodes one at a time.
# Code block 14: the loop of dijkstra, keeping the labels after each step
function dijkstra_steps(W, s)
    n = size(W, 1)
    d = fill(Inf, n); pred = zeros(Int, n); S = falses(n); d[s] = 0.0
    steps = []
    while count(S) < n
        i = 0
        for j in 1:n
            if !S[j] && (i == 0 || d[j] < d[i])
                i = j
            end
        end
        S[i] = true
        for j in 1:n
            if d[i] + W[i, j] < d[j]
                d[j] = d[i] + W[i, j]
                pred[j] = i
            end
        end
        push!(steps, (i = i, d = copy(d), pred = copy(pred)))
    end
    return steps
end

n6 = size(P6, 1)                        # number of nodes
W6 = fill(Inf, n6, n6)                  # arc lengths, both directions
for (i, j, w) in eachrow(A6)
    W6[i, j] = W6[j, i] = w
end
steps = dijkstra_steps(W6, 1)
lbl(d, p) = isinf(d) ? "∞" : string(round(Int, d), ",", p)
p6 = [6]                                # the path, traced back from 6
while p6[1] != 1
    pushfirst!(p6, steps[end].pred[p6[1]])
end

fig = Figure(size = (687, 620))
for (k, st) in enumerate(steps)
    axk = Axis(fig[(k - 1) ÷ 2 + 1, (k - 1) % 2 + 1];
               aspect = DataAspect(),
               title = "Step $k: label node $(st.i)",
               titlesize = 13, titlefont = :regular)
    hidedecorations!(axk); hidespines!(axk)
    net6!(axk; labels = [lbl(st.d[v], st.pred[v]) for v in 1:n6],
          done = [s.i for s in steps[1:k]],
          path = k == length(steps) ? p6 : Int[], fs = 12)
end
colgap!(fig.layout, 6); rowgap!(fig.layout, 4)
fig
# Code block 15: the labels after each step, node by node
println("| Step | Labeled | ",
# The block prints a Markdown table, one println for each row, and the
# page renders what it prints as a table, since the cell's output is
# marked asis.
        join(["Node $v" for v in 1:n6], " | "), " |")
println("|:-:|:-:|", repeat(":-:|", n6))
for (k, st) in enumerate(steps)
    c = [lbl(st.d[v], st.pred[v]) for v in 1:n6]
    c[st.i] = "**" * c[st.i] * "**"
    # The label of the node labeled at this step is wrapped in **,
    # Markdown's bold.
    println("| ", k, " | ", st.i, " | ", join(c, " | "), " |")
end
println("\n: Labels (distance, predecessor) after each step of ",
# A line that opens with a colon after a table is the table's caption in
# Markdown, and the {#tbl-...} at its end gives the table its number and
# the anchor the text refers to.
        "Dijkstra's procedure from node 1, the node labeled at that ",
        "step in bold. {#tbl-dijkstra-steps .fit}\n")

## Example 1(b): In Julia
# Determine the same path with the dijkstra_shortest_paths function of
# Graphs.jl and with the implementation of @mdl-shortest-path, and
# determine whether both agree with Ex. 1(a).
# Code block 16: the six-node network, from its arc list
i = [1, 1, 2, 2, 3, 3, 4, 4, 5]     # Index of starting node of each arc
j = [2, 3, 3, 4, 4, 5, 5, 6, 6]     # Index of ending node of each arc
# Weight (e.g., cost, distance, time) of each arc
w = [4, 2, 1, 5, 8, 10, 2, 6, 3]

g = SimpleWeightedGraph(i, j, w)    # Create undirected network
ds = dijkstra_shortest_paths(g, 1);  # Code block 17: from node 1 to all
ds.dists      # Code block 18: distance from node 1 to all nodes
ds.parents    # Code block 19: node predecessors (also called parents)
p = enumerate_paths(ds, 6)    # Code block 20: path from node 1 to node 6
ds.dists[6]   # Code block 21: distance from node 1 to 6
W = Array(float(adjacency_matrix(g)))   # Code block 22: adjacency matrix
# Code block 23: non-arcs to Inf
W = [has_edge(g, i, j) ? W[i, j] : Inf
# A 0 in the adjacency matrix means no arc, which the implementation would
# read as an arc that costs nothing, so each pair with no arc gets Inf and
# is never selected. has_edge keeps a real arc of length 0 as it is, such
# as the arc 2 => 4 of Code blocks 4 to 6.
     for i in 1:nv(g), j in 1:nv(g)]
d, pred = dijkstra(W, 1)   # Code block 24: the implementation, from 1
ds.dists, ds.parents  # Code block 25: using dijkstra_shortest_paths(g, 1)

## Example 1(c): Directed arcs
# Determine the shortest path from node 1 to node 6 when each arc can be
# traveled only from its starting node to its ending node.
# Code block 26: the same arcs, now directed
i = [1, 1, 2, 2, 3, 3, 4, 4, 5]
j = [2, 3, 3, 4, 4, 5, 5, 6, 6]
w = [4, 2, 1, 5, 8, 10, 2, 6, 3]

g = SimpleWeightedDiGraph(i, j, w)
# Code block 27: the shortest path from node 1 to node 6, directed
ds = dijkstra_shortest_paths(g, 1)
p = enumerate_paths(ds, 6)
println("Min cost path: ", p, ", Cost: ", ds.dists[6])
# Code block 28: the directed network and its shortest path
fig = Figure(size = (420, 240))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
net6!(ax; directed = true, path = p)
fig

## Sec. 3. Other shortest-path procedures
# Code block 29: the complexities, for the Interstate network
n = 862                    # Number of nodes in Interstate road network
m = 1223                   # Number of arcs
@show n^4                  # LP for shortest path using ellipsoid
@show n^2                  # Dijkstra using linear search for minimum
@show m*log(n)             # Dijkstra using Fibonacci heap for minimum
@show (n^4)/(m*log(n))     # Ratio LP to Fibonacci
@show (n^2)/(m*log(n));    # Ratio linear search to Fibonacci
# Code block 30: Dijkstra against A*, Raleigh to Dallas
using GeoMakie
N, L = prune_reindex(faf5nodes(), faf5links())
nN = nrow(N)
# Both directions of each link, one-way links honored, and of two parallel
# links the shorter kept (Sec. 4 explains both)
fw, bw = L.DIR .!= -1, L.DIR .!= 1
gr = SimpleWeightedDiGraph([L.SRC[fw]; L.DST[bw]], [L.DST[fw]; L.SRC[bw]],
                           [L.DIST[fw]; L.DIST[bw]]; combine = min)

ral = loc2lonlat("Raleigh"; state = :NC)
dal = loc2lonlat("Dallas"; state = :TX)
LL = [N.LON N.LAT]
closest(c) = argmin(dgc.(eachrow(LL), Ref([c.LON, c.LAT])))
s, t = closest(ral), closest(dal)

dsr = dijkstra_shortest_paths(gr, s)
dRD = dsr.dists[t]                      # Raleigh to Dallas, mi
h = dgc.(eachrow(LL), Ref(LL[t, :]))    # great circle to Dallas, mi
dijk = findall(<(dRD), dsr.dists)       # labeled by Dijkstra
astar = findall(v -> dsr.dists[v] + h[v] < dRD, 1:nN)   # by A*

fig, ax = makemap(N.LON[dijk], N.LAT[dijk])
resize!(fig, 687, 430)
scatter!(ax, N.LON[dijk], N.LAT[dijk]; color = (dcc, 0.6),
         markersize = 1.5)
scatter!(ax, N.LON[astar], N.LAT[astar]; color = (supc, 0.8),
         markersize = 2)
scatter!(ax, [ral.LON, dal.LON], [ral.LAT, dal.LAT]; color = ink,
         strokecolor = :white, strokewidth = 1, markersize = 10)
fig

## Sec. 4. Road networks
# Code block 31: the Interstate network, from its two CSV files
using CSV
dfN = DataFrame(CSV.File("data/interstate_nodes.csv"))
dfL = DataFrame(CSV.File("data/interstate_links.csv"))
nrow(dfN), nrow(dfL), maximum(dfN.IDX)
# Code block 32: a schematic of I-40 around Raleigh, thinned
XY0 = [1.33 -6.70; 1.27 -7.89; 1.67 -7.28; 2.97 -7.78; 4.05 -7.27;
       4.45 -6.68; 4.83 -7.91; 5.53 -6.62; 5.62 -7.66; 6.41 -7.47;
       6.59 -6.79; 7.07 -7.86]               # where each node is drawn
A0 = [1 3 5; 2 3 5; 3 4 20; 4 5 15; 5 6 10; 6 8 15; 8 9 15; 5 7 15;
      7 9 10; 9 10 10; 10 11 5; 10 12 5]     # arc list: i, j, cost
N0 = DataFrame(IDX = 1:size(XY0, 1), X = XY0[:, 1], Y = XY0[:, 2])
L0 = DataFrame(SRC = A0[:, 1], DST = A0[:, 2], DIST = A0[:, 3])
tN0, tL0 = thin(N0, L0)
prt(tL0)
# Code block 33: the schematic, before and after thinning
bluec  = colorant"#1f6fb5"              # the nodes
rd, rk = 0.07, 0.15                     # node dot and ring radii
side0  = [0, 0, -1, -1, 1, 1, 1, -1, -1, -1, 0, 0]  # side of each label

# The two ends of the segment from the outline of the circle of radius
# rp at p to the outline of the circle of radius rq at q
function rim(p, q, rp, rq)
    u = (q .- p) ./ hypot((q .- p)...)
    return p .+ rp .* u, q .- rq .* u
end

fig = Figure(size = (620, 230))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
for (k, (i, j, w)) in enumerate(eachrow(A0))     # the network
    p, q = XY0[i, :], XY0[j, :]
    t, h = rim(p, q, rd, rd)
    lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = ink, linewidth = 1.2)
    side0[k] == 0 && continue                    # the spurs go unlabeled
    u = (q .- p) ./ hypot((q .- p)...)
    m = (p .+ q) ./ 2 .+ 0.17 * side0[k] .* [-u[2], u[1]]
    text!(ax, m[1], m[2]; text = string(w), color = ink, fontsize = 13,
          align = (:center, :center))
end
for (i, j) in zip(tL0.SRC, tL0.DST)              # what thinning leaves
    t, h = rim(XY0[i, :], XY0[j, :], rk, rk)
    lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = (supc, 0.85),
           linewidth = 2.5)
end
kept = Set([tL0.SRC; tL0.DST])
for k in 1:nrow(N0)
    c = Point2f(XY0[k, 1], XY0[k, 2])
    poly!(ax, Circle(c, rd); color = bluec)
    k in kept && poly!(ax, Circle(c, rk); color = :transparent,
                       strokecolor = supc, strokewidth = 2.5)
end
text!(ax, 3.9, -7.5; text = string(maximum(tL0.DIST)), color = supc,
      fontsize = 15, font = :bold, align = (:center, :center))
fig
# Code block 34: the Interstates around Raleigh, before and after thinning
RRal = [-79.2618 35.2497; -78.1964 36.1762]  # the rectangle: lon, lat
# The nodes inside the rectangle, and the links between them
rN, rL = cropnetwork(dfN, dfL, RRal[:, 1], RRal[:, 2];
                     xexpand = 0, yexpand = 0)
trN, trL = thin(rN, rL)

fig, ax = makemap(rN.LON, rN.LAT; doRoadbkgd = false, xexpand = 0.05,
                  yexpand = 0.05)
resize!(fig, 400, 420)
gR = SimpleWeightedGraph(rL.SRC, rL.DST, rL.DIST)
lines!(ax, x2ln(gR, rN.LON), x2ln(gR, rN.LAT); color = supc,
       linewidth = 1)
scatter!(ax, rN.LON, rN.LAT; color = :transparent, strokecolor = supc,
         strokewidth = 1, markersize = 5)
for (i, j) in zip(trL.SRC, trL.DST)
    lines!(ax, rN.LON[[i, j]], rN.LAT[[i, j]]; color = (dcc, 0.8),
           linewidth = 4)
end
scatter!(ax, rN.LON[trN.IDX], rN.LAT[trN.IDX]; color = ink,
         markersize = 6)
# The data carries no road names, so the routes are labeled by hand
labs = [("I-85", -78.755, 36.07, (:left, :center)),
        ("I-40", -79.02, 35.905, (:right, :center)),
        ("I-540", -78.68, 35.94, (:center, :bottom)),
        ("I-440", -78.69, 35.735, (:center, :top)),
        ("I-40", -78.53, 35.58, (:left, :center)),
        ("I-95", -78.32, 35.46, (:center, :top)),
        ("Raleigh", -78.70, 35.665, (:center, :top)),
        ("Durham", -78.89, 36.052, (:center, :bottom))]
for (t, x, y, a) in labs
    text!(ax, x, y; text = t, fontsize = 12, color = ink, align = a)
end
fig
# Code block 35: thin the Interstate network, then reindex its nodes
tN, tL = thin(dfN, dfL)
@show nrow(tN), nrow(tL), maximum(tN.IDX)
tN, tL = prune_reindex(tN, tL)
@show nrow(tN), nrow(tL), maximum(tN.IDX);
# Code block 36: the Interstate network, before and after thinning
function imap(N, L, c)
    g = SimpleWeightedGraph(L.SRC, L.DST, L.DIST)
    fig, ax = makemap(N.LON, N.LAT; doRoadbkgd = false,
                      xexpand = 0.02, yexpand = 0.02)
    resize!(fig, 340, 240)
    ax.title = string(commas(nrow(N)), " nodes, ",
                      commas(nrow(L)), " links")
    ax.titlesize, ax.titlefont = 13, :regular
    lines!(ax, x2ln(g, N.LON), x2ln(g, N.LAT); color = c,
           linewidth = 0.6)
    return fig
end
imap(prune_reindex(dfN, dfL)..., supc)   # indices from 1, for x2ln
imap(tN, tL, ink)                    # Code block 37: the thinned network
# Code block 38: seven cities near Greensboro, pruned two ways
gso = loc2lonlat("Greensboro"; state = :NC)
C7 = filter(r -> r.POP > 30_000 &&
             dgc([gso.LON, gso.LAT], [r.LON, r.LAT]) < 50, usplace())
sort!(C7, [:ST, :NAME])                  # nodes 1 to 7
# Sorting by state and name fixes the order of the cities, so the node
# numbers in the arc list A7 refer to the right cities.
# Arc list: neighboring cities, each cost about 1.2 x great circle (mi)
A7 = [1 2 31; 1 3 25; 1 4 36; 1 7 42; 2 4 64; 2 5 100; 2 7 60;
      3 4 14; 3 6 29; 3 7 49; 4 5 43; 4 6 21; 5 6 39; 6 7 69]
N7 = DataFrame(IDX = 1:nrow(C7), LON = C7.LON, LAT = C7.LAT)
L7 = DataFrame(SRC = A7[:, 1], DST = A7[:, 2], DIST = A7[:, 3])
println(join(string.(1:4, " ", C7.NAME[1:4]), ", "))
println(join(string.(5:7, " ", C7.NAME[5:7]), ", "))

aN, aL = prune_reindex(N7, filter(r -> r.DIST < 35, L7))   # arcs < 35
R7 = [-80.6085 35.5897; -79.6971 36.2184]  # a rectangle: lon, lat
cN, cL = cropnetwork(N7, L7, R7[:, 1], R7[:, 2];
                     xexpand = 0, yexpand = 0)  # nodes inside it
                     # cropnetwork widens the rectangle by default, by an
                     # expansion factor of 0.1 on each axis; a factor of 0
                     # keeps exactly the rectangle.
prt(aL)
prt(cL)
# Code block 39: the seven-city network and its two subgraphs, drawn
# Lon and lat drawn to scale at 36 degrees north
xy(lon, lat) = [lon * cosd(36), lat]

# The network on ax: nodes as numbered circles, each arc from outline to
# outline and labeled with its cost, on side s (1 or -1) and fraction f
# of the way along it, as given for an arc (i, j) in lab
function citynet!(ax, N, L; r = 0.034, fs = 12, labels = true,
                  lab = Dict())
    for (i, j, w) in zip(L.SRC, L.DST, L.DIST)
        p, q = xy(N.LON[i], N.LAT[i]), xy(N.LON[j], N.LAT[j])
        u = (q .- p) ./ hypot((q .- p)...)
        t, h = p .+ r .* u, q .- r .* u
        lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = ink, linewidth = 1)
        labels || continue
        s, f = get(lab, (i, j), (1, 0.5))
        m = p .+ f .* (q .- p) .+ 0.045s .* [-u[2], u[1]]
        text!(ax, m[1], m[2]; text = string(w), color = ink,
              fontsize = fs, align = (:center, :center))
    end
    for k in 1:nrow(N)
        x, y = xy(N.LON[k], N.LAT[k])
        poly!(ax, Circle(Point2f(x, y), r); color = :white,
              strokecolor = bluec, strokewidth = 1.5)
        text!(ax, x, y; text = string(k), color = bluec,
              fontsize = fs - 1, align = (:center, :center))
    end
end

# A subgraph moved dx and dy (in drawn units) to its place in the figure
shift(N, dx, dy) = DataFrame(IDX = N.IDX, LON = N.LON .+ dx / cosd(36),
                             LAT = N.LAT .+ dy)

fig = Figure(size = (687, 580))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
citynet!(ax, N7, L7; lab = Dict((1, 3) => (-1, 0.5), (3, 4) => (-1, 0.62),
                                (3, 6) => (-1, 0.5), (2, 5) => (-1, 0.5),
                                (4, 5) => (-1, 0.5), (1, 4) => (1, 0.3)))
(x0, y0), (x1, y1) = xy(R7[1, 1], R7[1, 2]), xy(R7[2, 1], R7[2, 2])
lines!(ax, [x0, x1, x1, x0, x0], [y0, y0, y1, y1, y0]; color = supc,
       linestyle = :dash, linewidth = 1.8)
text!(ax, xy(-80.50, 36.62)...; text = "(a) Network", fontsize = 14,
      align = (:left, :center))

# Each subgraph is derived from (a), so an arrow runs from (a) to each
dyb, dxc = -0.85, 1.55                  # where the two subgraphs are put
arrow!(p, q) = arrows2d!(ax, [p[1]], [p[2]], [q[1] - p[1]], [q[2] - p[2]];
                         color = (ink, 0.7), shaftwidth = 1.5,
                         tipwidth = 11, tiplength = 11)
arrow!(xy(-79.55, 35.76), xy(-79.55, 35.47))     # (a) to (b), down
arrow!(xy(-78.96, 36.15), xy(-78.49, 36.15))     # (a) to (c), right

a2 = shift(aN, 0.0, dyb)                 # (b) arcs < 35, below
x5, y5 = xy(a2.LON[5], a2.LAT[5])
scatter!(ax, [x5], [y5]; marker = :star5, markersize = 36,
         color = (supc, 0.85))           # the renumbered node
citynet!(ax, a2, aL; lab = Dict((1, 3) => (-1, 0.5), (3, 4) => (-1, 0.62),
                                (3, 5) => (-1, 0.5)))
text!(ax, xy(-79.55, 35.39)...; text = "(b) Arcs < 35", fontsize = 14,
      align = (:center, :center))

c3 = shift(cN, dxc, 0.2)                 # (c) nodes in the rectangle
citynet!(ax, c3, cL; lab = Dict((1, 2) => (1, 0.5)))
text!(ax, xy(-80.16 + dxc / cosd(36), 36.45)...;
      text = "(c) Nodes in rectangle", fontsize = 14,
      align = (:center, :center))
fig
# Code block 40: six new nodes, connected to the seven-city network
x1 = [-79.990, -80.308, -79.629, -79.899, -79.554, -79.143]  # lon
y1 = [35.921, 35.736, 35.894, 36.206, 36.232, 36.321]        # lat
n1 = length(x1)
N8, L8 = addconnectors(N7, L7, x1, y1)
isc = isequal.(L8.SOURCE, "CONNECTOR")       # the connectors
# A road link has no SOURCE value, and == with a missing value gives
# missing rather than false; isequal gives false, so the result can be
# used to select rows.
nnx = count(isc .& (L8.DST .> n1))           # new node to existing
nnn = count(isc .& (L8.DST .<= n1))          # new node to new node
prt(sort(L8[isc .& (L8.SRC .== 1), 1:3], :DST))  # those of new node 1
# Code block 41: the connectors, drawn with Code block 39's citynet!
fig = Figure(size = (687, 560))
ax = Axis(fig[1, 1]; aspect = DataAspect())
hidedecorations!(ax); hidespines!(ax)
P8 = [N8.LON .* cosd(36) N8.LAT]          # every node, drawn as xy() does
rn = 0.02                                 # a new node's radius
hs = Any[]
for (i, j) in zip(L8.SRC[isc], L8.DST[isc])   # the connectors, first
    p, q = P8[i, :], P8[j, :]
    newnew = j <= n1
    u = (q .- p) ./ hypot((q .- p)...)
    t = p .+ rn .* u                      # outline to outline
    h = q .- (newnew ? rn : 0.034) .* u
    push!(hs, lines!(ax, [t[1], h[1]], [t[2], h[2]];
                     color = newnew ? bluec : supc,
                     linestyle = newnew ? :dashdot : :dash,
                     linewidth = 1.8))
end
citynet!(ax, N7, L7; labels = false, fs = 14)  # the cities, over them
for k in 1:n1                             # the new nodes, filled
    poly!(ax, Circle(Point2f(P8[k, 1], P8[k, 2]), rn); color = bluec,
          strokecolor = :white, strokewidth = 1)
end
k1 = findfirst(>(n1), L8.DST[isc])        # a connector of each kind
k2 = findfirst(<=(n1), L8.DST[isc])
sc = MarkerElement(color = bluec, marker = :circle, markersize = 14)
axislegend(ax, [hs[k1], hs[k2], sc],
           ["New to existing node", "New to new node", "New node"];
           position = :lt, labelsize = 14)
fig
# Code block 42: the Delaunay triangulation and another triangulation
# Each triangulation as its triangles, three cities to a row
T7 = [1 2 4; 1 2 7; 1 3 4; 1 3 7; 2 4 5; 3 4 6; 3 6 7; 4 5 6]  # Delaunay
Tf = [1 2 3; 1 2 7; 1 3 7; 2 3 6; 2 4 6; 2 4 5; 3 6 7; 4 5 6]  # 2 flipped
P7 = [xy(N7.LON[k], N7.LAT[k]) for k in 1:nrow(N7)]   # drawn positions

# The smallest angle of any triangle of T, in degrees
function minangle(T)
    a = Inf
    for t in eachrow(T), m in 1:3
        p, q, r = P7[t[m]], P7[t[mod1(m + 1, 3)]], P7[t[mod1(m + 2, 3)]]
        u, v = q .- p, r .- p
        a = min(a, acosd(sum(u .* v) / (hypot(u...) * hypot(v...))))
    end
    return a
end

# The arcs of a triangulation, from its triangles
arcs(T) = unique([minmax(t[a], t[b]) for t in eachrow(T)
                  for (a, b) in ((1, 2), (2, 3), (1, 3))])

fig = Figure(size = (687, 330))
for (k, (T, nm)) in enumerate([(T7, "Delaunay"), (Tf, "Another")])
    red = k == 2 ? [(2, 3), (2, 6)] : Tuple{Int, Int}[]   # replacements
    A = setdiff(arcs(T), red)
    a = round(minangle(T), digits = 1)
    ax = Axis(fig[1, k]; aspect = DataAspect(), titlesize = 14,
              titlefont = :regular,
              title = string(nm, ": smallest angle ", a, "°"))
    hidedecorations!(ax); hidespines!(ax)
    citynet!(ax, N7, DataFrame(SRC = first.(A), DST = last.(A), DIST = 0);
             labels = false, fs = 13)
    for (i, j) in red                       # outline to outline, in red
        u = (P7[j] .- P7[i]) ./ hypot((P7[j] .- P7[i])...)
        t, h = P7[i] .+ 0.034 .* u, P7[j] .- 0.034 .* u
        lines!(ax, [t[1], h[1]], [t[2], h[2]]; color = supc,
               linewidth = 2.5)
    end
end
fig
# Code block 43: the FAF5 road network
N, L = prune_reindex(faf5nodes(), faf5links())   # nodes numbered from 1
@show nrow(N), nrow(L)
# A link's direction: 1 one-way SRC to DST, -1 one-way DST to SRC, 0 both
@show count(==(1), L.DIR)
@show count(==(-1), L.DIR)
@show count(==(0), L.DIR)
nodepair = minmax.(L.SRC, L.DST)        # the two nodes each link joins
nshare = length(nodepair) - length(unique(nodepair))   # a pair repeated
# Code block 44: the roads of Wake County, pruned and reindexed
# FAF5's county code includes the state's: 37 and 183 make 37183
NW, LW = prune_reindex(N, filter(r -> r.STFIP == 37 &&
                                      r.COFIP == 37183, L))
nrow(NW), nrow(LW)
# Code block 45: two points connected, and the shortest path between them
XY2 = [-78.75864529722959 35.74329140697632;
       -78.70352644371913 35.866083946889844]
NW2, LW2 = addconnectors(NW, LW, XY2[:, 1], XY2[:, 2];
                         add_nf_nf = false)
                         # A connector between two new nodes is only an
                         # estimate, 1.3 times their great circle
                         # distance, so when the road distance between
                         # them is what is wanted, the connectors are
                         # added with add_nf_nf = false, which joins the
                         # new nodes to the network alone.
fw, bw = LW2.DIR .!= -1, LW2.DIR .!= 1    # arcs each way
# A graph holds one arc for each pair of nodes and direction, so the graph
# of a road network is built by two rules: each link gives an arc in each
# direction it can be traveled (fw marks the links that can be traveled
# from SRC to DST, and bw those that can be traveled back), and of two
# arcs joining the same nodes in the same direction, the shorter is kept,
# the rule for parallel arcs in Sec. 1, which combine = min applies. Built
# from the arc list, a link of zero length stays an arc.
gW = SimpleWeightedDiGraph([LW2.SRC[fw]; LW2.DST[bw]],
                           [LW2.DST[fw]; LW2.SRC[bw]],
                           [LW2.DIST[fw]; LW2.DIST[bw]]; combine = min)
D, P = shortestpaths(gW, 2)        # between the two new nodes
# shortestpaths(g, k) runs Dijkstra's procedure from each of the first k
# nodes and returns the distances between them and the predecessors; here
# the first 2 nodes are the two new points, since addconnectors numbers
# the new nodes first.
pW = tracepath(P[1], 1, 2)         # the path from node 1 to node 2
D
# Code block 46: Wake County's roads, the two points and their path
gw = SimpleWeightedGraph(LW.SRC, LW.DST, LW.DIST; combine = min)
cn = LW2.DST[isequal.(LW2.SOURCE, "CONNECTOR")]   # the road nodes joined
# The map zoomed to the two points, their connectors and their path
zm = unique([pW; cn])
fig, ax = makemap(NW2.LON[zm], NW2.LAT[zm]; doRoadbkgd = false,
                  xexpand = 0.9, yexpand = 0.12)
resize!(fig, 500, 520)
lines!(ax, x2ln(gw, NW.LON), x2ln(gw, NW.LAT); color = (ink, 0.6),
       linewidth = 0.8)
# The connectors, dashed: virtual roads that stand for streets not in FAF5
for r in eachrow(LW2[isequal.(LW2.SOURCE, "CONNECTOR"), :])
    lines!(ax, [XY2[r.SRC, 1], NW2.LON[r.DST]],
           [XY2[r.SRC, 2], NW2.LAT[r.DST]];
           color = bluec, linestyle = :dash, linewidth = 1.5)
end
# The path: solid along roads, dashed along its two connectors
lines!(ax, NW2.LON[pW[2:end-1]], NW2.LAT[pW[2:end-1]];
       color = (supc, 0.8), linewidth = 3)
for s in (pW[1:2], pW[end-1:end])
    lines!(ax, NW2.LON[s], NW2.LAT[s]; color = (supc, 0.8), linewidth = 3,
           linestyle = :dash)
end
scatter!(ax, NW2.LON[cn], NW2.LAT[cn]; color = supc, markersize = 9)
scatter!(ax, XY2[:, 1], XY2[:, 2]; color = bluec, markersize = 14,
         strokecolor = :white, strokewidth = 1)
text!(ax, XY2[:, 1], XY2[:, 2]; text = ["1", "2"], fontsize = 15,
      color = bluec, font = :bold,
      align = [(:left, :center), (:left, :bottom)],
      offset = [(9, 0), (7, 5)])
fig

# Sec. 4. Road networks
## Example 2: Road distances between 100K NC cities
# Determine the road distances between the ten North Carolina cities of
# over 100,000 people, those of Lecture 2.2, Sec. 6, and compare the
# distance from Cary to Charlotte with its estimate from the great
# circle distance.
# Code block 47: the NC cities over 100K, from the Logjam gazetteer
df = filter(r -> (r.STFIP == st2fips(:NC)) && (r.POP > 100_000),
            usplace())
select!(df, :NAME, :LAT, :LON, :POP)
prt(df)
# Code block 48: their road distances, a 10 x 10 matrix
n = nrow(df)
Nc, Lc = cropnetwork(N, L, df.LON, df.LAT)     # a box around the cities
Nc, Lc = addconnectors(Nc, Lc, df.LON, df.LAT; add_nf_nf = false)
fw, bw = Lc.DIR .!= -1, Lc.DIR .!= 1           # as in Code block 45
g = SimpleWeightedDiGraph([Lc.SRC[fw]; Lc.DST[bw]],
                          [Lc.DST[fw]; Lc.SRC[bw]],
                          [Lc.DIST[fw]; Lc.DIST[bw]]; combine = min)
D, P = shortestpaths(g, n)                     # from each city to each
round.(D, digits = 1)
# Code block 49: Cary to Charlotte, by road and by great circle x 1.2
@show D[1, 2]
@show dgc([df.LON[1], df.LAT[1]], [df.LON[2], df.LAT[2]]) * 1.2
# Is every road distance at least its great circle distance?
G = [dgc([df.LON[i], df.LAT[i]], [df.LON[j], df.LAT[j]])
     for i in 1:n, j in 1:n]
@show all(D .>= G);
# Code block 50: the cities, their road network, and Cary to Charlotte
gL = SimpleWeightedGraph(Lc.SRC, Lc.DST, Lc.DIST; combine = min)
p12 = tracepath(P[1], 1, 2)              # Cary to Charlotte
fig, ax = makemap(Nc.LON, Nc.LAT; doRoadbkgd = false, xexpand = 0.06,
                  yexpand = 0.03)
resize!(fig, 687, 400)
lines!(ax, x2ln(gL, Nc.LON), x2ln(gL, Nc.LAT); color = (ink, 0.3),
       linewidth = 0.5)
lines!(ax, Nc.LON[p12], Nc.LAT[p12]; color = (supc, 0.85), linewidth = 3)
scatter!(ax, df.LON, df.LAT; color = bluec, markersize = 10)
# aligntext's label placement, moved for the labels the route would cross
al = aligntext(df.LON, df.LAT; offsetamt = 6)
A, O = copy(al[1].second), copy(al[2].second)
fix = Dict("Cary" => ((:center, :top), (0, -7)),
           "Concord" => ((:left, :top), (6, -6)),
           "Charlotte" => ((:left, :top), (6, -6)),
           "Wilmington" => ((:right, :top), (-6, -6)))
for (k, nm) in enumerate(df.NAME)
    haskey(fix, nm) && ((A[k], O[k]) = fix[nm])
end
text!(ax, df.LON, df.LAT; text = df.NAME, fontsize = 12, align = A,
      offset = O)
fig

## Sec. 5. Travel time
# Code block 51: travel times between the cities of Ex. 2, in minutes
con = isequal.(Lc.SOURCE, "CONNECTOR")
# A link's minutes: FAF5's free-flow time t, or, where a link has none,
# 60 d / v at its posted speed v; a connector at 20 mph
mins(t, v, d) = t > 0 ? t : 60d / v
tAB = [c ? 60d / 20 : mins(t, v, d)
       for (c, t, v, d) in zip(con, Lc.AB_TIME, Lc.SPEED, Lc.DIST)]
tBA = [c ? 60d / 20 : mins(t, v, d)
       for (c, t, v, d) in zip(con, Lc.BA_TIME, Lc.SPEED, Lc.DIST)]
fw, bw = Lc.DIR .!= -1, Lc.DIR .!= 1           # as in Code block 45
gT = SimpleWeightedDiGraph([Lc.SRC[fw]; Lc.DST[bw]],
                           [Lc.DST[fw]; Lc.SRC[bw]],
                           [tAB[fw]; tBA[bw]]; combine = min)
T, PT = shortestpaths(gT, n)                   # minutes
# Only the times from city to city are wanted, so Dijkstra's procedure is
# run from each of the $n$ cities, the first $n$ nodes, and only the first
# $n$ entries of each result are kept, the $n$ by $n$ matrix T.
round.(T)
# Code block 52: each route measured the other way, along its path
Wd, Wt = weights(g), weights(gT)     # miles and minutes, arc by arc
# segcost gives the weight of each link along a path
DT = [i == j ? 0.0 : sum(segcost(tracepath(PT[i], i, j), Wd))
# The path of the shortest travel time route from city i to city j is
# taken from the predecessors PT by tracepath, and the distances of its
# links are added along it, for every pair of cities, to give the distance
# of each shortest travel time route.
      for i in 1:n, j in 1:n]        # miles on each fastest route
TD = [i == j ? 0.0 : sum(segcost(tracepath(P[i], i, j), Wt))
      for i in 1:n, j in 1:n]        # minutes on each shortest route
ir = findfirst(==("Raleigh"), df.NAME)
prt(DataFrame("From" => df.NAME[[1, ir]], "To" => df.NAME[2],
              "Shortest, mi" => round.(D[[1, ir], 2], digits = 1),
              "its min" => round.(TD[[1, ir], 2]),
              "Fastest, min" => round.(T[[1, ir], 2]),
              "its mi" => round.(DT[[1, ir], 2], digits = 1)))

# Sec. 5. Travel time
## Example 3: High Point to Goldsboro
# Determine the shortest route and the fastest route by road from High
# Point to Goldsboro, and the distance and travel time of each, taking
# FAF5's free-flow times on its links and 20 mph on the connectors.
# Code block 53: High Point to Goldsboro, shortest and fastest
hp = loc2lonlat("High Point"; state = :NC)
gb = loc2lonlat("Goldsboro"; state = :NC)
X, Y = [hp.LON, gb.LON], [hp.LAT, gb.LAT]
N3, L3 = cropnetwork(N, L, X, Y; xexpand = 0.2, yexpand = 0.5)
N3, L3 = addconnectors(N3, L3, X, Y; add_nf_nf = false)
c3 = isequal.(L3.SOURCE, "CONNECTOR")
t3AB = [c ? 60d / 20 : mins(t, v, d)       # minutes, as in Code block 51
        for (c, t, v, d) in zip(c3, L3.AB_TIME, L3.SPEED, L3.DIST)]
t3BA = [c ? 60d / 20 : mins(t, v, d)
        for (c, t, v, d) in zip(c3, L3.BA_TIME, L3.SPEED, L3.DIST)]
fw, bw = L3.DIR .!= -1, L3.DIR .!= 1
I3, J3 = [L3.SRC[fw]; L3.DST[bw]], [L3.DST[fw]; L3.SRC[bw]]
g3 = SimpleWeightedDiGraph(I3, J3, [L3.DIST[fw]; L3.DIST[bw]];
                           combine = min)                  # miles
g3T = SimpleWeightedDiGraph(I3, J3, [t3AB[fw]; t3BA[bw]];
                            combine = min)                 # minutes
pD = tracepath(dijkstra_shortest_paths(g3, 1).parents, 1, 2)   # shortest
pF = tracepath(dijkstra_shortest_paths(g3T, 1).parents, 1, 2)  # fastest
miD = sum.(segcost.([pD, pF], Ref(weights(g3))))   # miles of each
minT = sum.(segcost.([pD, pF], Ref(weights(g3T))))  # minutes of each
# hm, defined with the page's setup, writes minutes as hours and minutes
prt(DataFrame("Route" => ["Shortest", "Fastest"],
              "mi" => round.(miD, digits = 1), "Time" => hm.(minT)))
# Code block 54: the two routes, High Point to Goldsboro
g3u = SimpleWeightedGraph(L3.SRC, L3.DST, L3.DIST; combine = min)
fig, ax = makemap(N3.LON, N3.LAT; doRoadbkgd = false, xexpand = 0.02,
                  yexpand = 0.04)
resize!(fig, 687, 360)
lines!(ax, x2ln(g3u, N3.LON), x2ln(g3u, N3.LAT); color = (ink, 0.3),
       linewidth = 0.5)
lD = lines!(ax, N3.LON[pD], N3.LAT[pD]; color = (supc, 0.85),
            linewidth = 3)
lF = lines!(ax, N3.LON[pF], N3.LAT[pF]; color = (dcc, 0.85),
            linewidth = 3)
scatter!(ax, X, Y; color = bluec, markersize = 11)
text!(ax, X, Y; text = ["High Point", "Goldsboro"], fontsize = 12,
      align = [(:right, :bottom), (:right, :top)],
      offset = [(-6, 6), (-8, -4)])
axislegend(ax, [lD, lF], ["Shortest", "Fastest"]; position = :rt,
           labelsize = 12)
fig
# Code block 55: a landmark, OSRM's routes on OpenStreetMap data
using HTTP, JSON3
a = loc2lonlat("High Point"; state = :NC)          # its LON and LAT
b = loc2lonlat("Goldsboro"; state = :NC)
url = "https://router.project-osrm.org/route/v1/driving/" *
      "$(a.LON),$(a.LAT);$(b.LON),$(b.LAT)" *
      "?alternatives=true&overview=false"
r = JSON3.read(HTTP.get(url).body)           # the router's answer
osrm = DataFrame(DIST = [rt.distance for rt in r.routes] ./ 1609.344,
                 TIME = [rt.duration for rt in r.routes] ./ 60)
                 # OSRM returns each route's distance in meters and its
                 # duration in seconds, so dividing by 1,609.344 m to the
                 # mile and 60 s to the minute gives miles and minutes.

## Model: Transshipment terminals
# Model: transshipment terminals, set covering with a linehaul condition
using JuMP, HiGHS
function terminals(T, tmax)
    N = 1:size(T, 1)
    model = Model(HiGHS.Optimizer)
    @variable(model, x[i ∈ N], Bin)
    @objective(model, Min, sum(x[i] for i ∈ N))
    @constraint(model, coverage[j ∈ N],      # (a)
                sum(x[i] for i ∈ N if T[i, j] ≤ tmax / 2) ≥ 1)
    @constraint(model, linehaul[i ∈ N],      # (b)
                x[i] ≤ sum(x[k] for k ∈ setdiff(N, [i])
                                if T[i, k] ≤ tmax))
    set_silent(model)
    optimize!(model)
    return findall(==(1.0), snapvals(value.(x)))
end

## Example 4: Transshipment terminals
# A national less-than-truckload (LTL) carrier would like to know what
# would be the minimum number of transshipment terminals needed to cover
# the continental U.S. and their locations. All of their existing local
# pickup and delivery terminals are located near the intersection of two
# or more Interstate highways. Since hours-of-service (HOS) requirements
# limit a driver to eleven hours of driving per day (not including
# loading/unloading time), they would like each of their local terminals
# to be within five and a half hours travel time of a transshipment
# terminal (so that one driver can complete one roundtrip in a day) and,
# for linehaul operations between the transshipment terminals, they
# would like for all of the transshipment terminals to be within eleven
# hours of each other.
# Code block 56: the Interstate intersections
iN, iL = tN, tL                 # the thinned network of Code block 35
while true                      # remove the ends until none is left
    deg = [count(==(k), [iL.SRC; iL.DST]) for k in 1:nrow(iN)]
    all(>(1), deg) && break     # no node of degree 1 is left
    global iN, iL = prune_reindex(iN, filter(r -> deg[r.SRC] > 1 &&
    # A while loop has a scope of its own, so a variable assigned inside
    # it is local to the loop unless it is declared otherwise. global
    # makes this line update the iN and iL defined above the loop, so that
    # each pass starts from the network the last pass left. Without it, in
    # a script run as a file, such as the companion .jl, Julia would warn
    # that the assignment is ambiguous, treat iN and iL as new variables
    # local to the loop, and stop with an error at the loop's first line,
    # which reads iN before the loop has given it a value. Typed at the
    # REPL, the loop would update them without the keyword, which does no
    # harm there.
                                                deg[r.DST] > 1, iL))
end
iN, iL = prune_reindex(thin(iN, iL)...)   # remove new degree-2 nodes
nrow(iN)
# Code block 57: travel times, then the terminals for an 11-hour day
gI = SimpleWeightedGraph(iL.SRC, iL.DST, iL.DIST ./ 60; combine = min)
T, _ = shortestpaths(gI, weights(gI), nv(gI))  # hours, all pairs
# The last argument is how many of the first nodes Dijkstra's procedure is
# run from, and nv(gI), the number of nodes, runs it from every node, so T
# holds the hours between every pair of intersections.
idx = terminals(T, 11)
length(idx)
# Code block 58: checking constraints (a) and (b) on the terminals
toterm = [minimum(T[i, j] for i in idx) for j in 1:nv(gI)]
near = [minimum(T[a, b] for b in idx if b != a) for a in idx]
round(maximum(toterm), digits = 2), round(maximum(near), digits = 2)
# Code block 59: the network and its terminals
fig, ax = makemap(iN.LON, iN.LAT; doRoadbkgd = false, xexpand = 0.02,
                  yexpand = 0.02)
resize!(fig, 687, 430)
lines!(ax, x2ln(gI, iN.LON), x2ln(gI, iN.LAT); color = ink,
       linewidth = 0.6)
scatter!(ax, iN.LON[idx], iN.LAT[idx]; color = :transparent,
         strokecolor = supc, strokewidth = 2, markersize = 14)
fig
