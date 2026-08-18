# 1-intr-2 — generated from 1-intr-2.qmd by tools/qmd_to_jl.py
# (do not edit by hand; rerun the generator after editing the .qmd)
# Cells (## title) follow the Julia VS Code extension convention.

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

## Sec. 1. Julia
tₑ = 2.0          # t\_e Tab: subscript (assigned, silent)
σ² = 16.0         # \sigma Tab, \^2 Tab (also silent)
@show c² = σ² / tₑ^2   # define and inspect in one line
7 ÷ 2             # \div Tab: last line shows on its own
a = [1, 2, 3]          # a 3-element vector
A = [1 2 3 4; 5 6 7 8] # a 2x4 matrix; ; ends a row
a = [1:5;]           # collect the range 1..5 into a vector
a = [1:2:5;]         # start 1, step 2: [1, 3, 5]
a = ones(5)          # five 1.0s (Float64 by default)
a = zeros(5)         # five 0.0s
a = [i^2 + i + 1 for i in 0:5]   # an array comprehension
a = [10:15;]
@show a[3]         # single element
@show a[[2, 4]]    # several elements, by an index array
@show a[end];      # the last element
A = [1 2 3 4; 5 6 7 8]
@show A[1, 2]      # row 1, column 2
@show A[:, 1]      # all of column 1
@show A[1, :];     # all of row 1
a = [10:15;]
@show a[2:end]      # drop the first element
@show a[1:end-1]    # drop the last element
@show reverse(a);   # the elements in reverse order
a = [1, 2, 3, 4]
@show 2 .+ a       # add 2 to each element (the dot broadcasts)
@show 2 * a        # scalar times array needs no dot
@show 2a;          # the * is optional for a number times a name
a = [1:5;]
@show sum(a)           # add all elements
@show cumsum(a);       # running total
A = [1 3 4; 5 7 8]
@show sum(A, dims = 1)   # sum down each column
@show sum(A, dims = 2);  # sum across each row
a = [4, 0, -2, 7, 0]
@show a .> 0                    # which elements are positive
@show (a .>= 0) .& (a .<= 4)    # in the range [0, 4]
@show any(a .> 0);              # is any element positive
a = [5, 0, -1, 9, 0]
@show a[a .> 0]            # keep the positive elements
@show findall(a .> 0);     # the positions of the positive elements
a = [5, 0, -1, 9, 0]
@show sort(a)         # the values in order
@show sortperm(a)     # the indices that sort them
@show argmin(a);      # the position of the smallest

# Sec. 1. Julia
## Example 1: Selecting the heavy shipments
# Five shipments have the weights below. Compute the line-haul charge at
# \$50 per ton by broadcasting, then select the shipments heavier than
# 10 ton.
wt = [12, 5, 18, 7, 9]
@show charge = 50 .* wt    # $/shipment at $50/ton
@show heavy = wt[wt .> 10]; # shipments over 10 ton

## Sec. 1. Julia
t = (6, 1, 4)      # a 3-tuple
@show t[2]         # access the second element
@show typeof(t);
function fun1(a)
    b = 3a + 1
    if b % 2 == 0      # is b even
        c = b / 2
    else
        c = (b - 1) / 2
    end
    return c           # the value handed back
end
@show fun1(5);
f(a) = 3a + 1      # a one-line function
@show f(8);
isheavy(w) = w > 10          # a one-line test: is w over 10?
filter(isheavy, [12, 5, 18]) # keep those over 10 -> [12, 18]
filter(w -> w > 10, [12, 5, 18])   # the same test, no name

## Example 2: Solving and verifying a 3x3 system
# Solve the system below for $\boldsymbol{x}$ with the \ operator, then
# verify the solution by checking that $\mathbf{A}\,\boldsymbol{x}$
# returns $\mathbf{b}$.
A = [2 -1 3; 1 0 1; 4 1 8]
b = [6, 3, 17]
x = A \ b          # left division solves A*x = b
A * x              # verify: should return b

## Example 3: A small shipment table
# Assemble a three-row table of shipments, each with an origin, a
# destination, and a weight, then read back the weight column.
using DataFrames   # load the package, then build the table
ship = DataFrame(
    origin = ["RDU", "RDU", "GSO"],
    dest   = ["ATL", "MIA", "ATL"],
    ton    = [12, 5, 18])
ship.ton           # read the weight column

## Sec. 1. Julia
using CairoMakie                     # load the plotting backend
f(x) = x - x^3                       # the curve to draw
xrng = -2:0.01:2          # x-values, fine steps
lines(xrng, f;
# lines draws f over the range xrng; the axis = (...) keyword sets
# the title and axis labels inside the same call, so the separate
# Figure and Axis objects that fuller plots use are not needed yet.
    axis = (title  = "f(x) = x - x³",
            xlabel = "x",
            ylabel = "f(x)"))

# Sec. 2. Large Language Models
## Example 4: A token as a point in space
# Represent a few words as points in a small space, then measure how
# related two of them are using only their coordinates.
vocab = ["truck", "freight", "shipment", "cat"]

# E: one column per token, each a point in 2-D meaning space
E = [0.9  0.8  0.85  -0.7
     0.1  0.2  0.05   0.9]

emb(w) = E[:, findfirst(==(w), vocab)]   # token -> vector

cosine(a, b) = (a'b) / (sqrt(a'a) * sqrt(b'b))
@show cosine(emb("truck"), emb("freight"))   # related
@show cosine(emb("truck"), emb("cat"));       # unrelated

## Sec. 2. Large Language Models
softmax(Z) = exp.(Z) ./ sum(exp.(Z), dims = 1)
@show softmax([2.0, 1.0, 0.0]);   # ~ [0.66, 0.24, 0.09]

## Example 5: Predicting the next token by gradient descent
# Place a few tokens as points in a two-dimensional space, give a tiny
# corpus in which the current token determines the next, and train a
# single layer by gradient descent until it predicts the next token
# correctly.
vocab = ["van", "rig", "parcel", "pallet",
         "depot", "yard", "dock", "go", "wait"]

id(w) = findfirst(==(w), vocab)      # token -> column

# corpus: each context token -> the next token
ctx = ["van", "rig", "parcel", "pallet", "depot", "yard", "dock"]
nxt = ["go", "go", "go", "go", "wait", "wait", "wait"]

V = length(vocab);  N = length(ctx)
cols = id.(ctx)                      # context columns of E
Y = zeros(V, N)                      # one-hot targets
for j in 1:N
    Y[id(nxt[j]), j] = 1
end

# E: a 2-D embedding per token, learned from scratch
E = 0.4 .* randn(2, V)
W = zeros(V, 2);  b = zeros(V, 1);  lr = 0.5

for epoch in 1:4000
    X  = E[:, cols]                  # current embeddings
    P  = softmax(W * X .+ b)         # next-token probs
    dZ = P .- Y                      # cross-entropy gradient
    dX = W' * dZ                     # error back to embeddings
    W .-= lr .* (dZ * X')            # readout weights
    b .-= lr .* sum(dZ, dims = 2)    # readout biases
    E[:, cols] .-= lr .* dX          # move the embeddings too
end

pred(c) = vocab[argmax(W * E[:, id(c)] .+ vec(b))]
@show pred.(ctx);                    # all seven correct

## Example 6: A hidden layer learns the harder corpus
# Place the four cargo tokens as points by their two sizes, give the
# corpus in which the next token depends on whether the sizes match, and
# train a network with a small hidden layer by gradient descent until
# its predictions match the corpus, using nothing but base Julia.
σ(z) = 1 / (1 + exp(-z))             # squashing nonlinearity

# four cargo tokens as fixed points: vehicle
# size in row 1, load size in row 2
#      van   rig  parcel pallet
E = [-1.0   1.0   0.0    0.0
      0.0   0.0  -1.0    1.0]
veh  = [1, 2, 1, 2]      # van rig van rig
load = [3, 4, 4, 3]      # parcel pallet pallet parcel
X = E[:, veh] .+ E[:, load]   # summed: the XOR corners
# Y: row 1 = P(go) for a match, row 2 = P(wait)
Y = [1.0  1   0   0
     0    0   1   1]

W1 = randn(3, 2);  b1 = zeros(3, 1)   # hidden (3 units)
W2 = randn(2, 3);  b2 = zeros(2, 1)   # output (2 tokens)
lr = 1.0

for epoch in 1:20_000
    a1 = σ.(W1 * X .+ b1)             # hidden activations
    P  = softmax(W2 * a1 .+ b2)       # next-token probs
    d2 = P .- Y                       # cross-entropy gradient
    d1 = (W2' * d2) .* a1 .* (1 .- a1)
    W2 .-= lr .* (d2 * a1'); b2 .-= lr .* sum(d2, dims = 2)
    W1 .-= lr .* (d1 * X');  b1 .-= lr .* sum(d1, dims = 2)
end

P = softmax(W2 * σ.(W1 * X .+ b1) .+ b2)
@show round.(P, digits = 2);

## Example 7: Attention resolves a reference by content
# Give a token a query, score it against the earlier tokens by content,
# and blend them into a new vector for that token, using nothing but
# base Julia.
q = [2.0, 0.2]                   # the query "it" forms

rig    = [1.0,  0.0]             # the same cross points
parcel = [0.0, -1.0]             # from Section 2.4

s = [rig' * q, parcel' * q]      # match each by content
w = softmax(s)                   # weights, positive, sum to 1
it = w[1] .* rig .+ w[2] .* parcel   # blend into a new vector
@show round.(w, digits = 2);     # most weight on the rig
