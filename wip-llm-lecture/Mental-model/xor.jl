# XOR from scratch in base Julia — no packages, nothing hidden.
# XOR outputs 1 when the two inputs differ, 0 when they agree.
# A single layer CANNOT separate these four points; one hidden layer can.
# That gap is the entire reason "deep" learning exists.

σ(z) = 1 / (1 + exp(-z))             # the squashing nonlinearity  (type: \sigma + Tab)

X = [0.0 0 1 1;                      # 2x4 : each column is one input pair
     0   1 0 1]
Y = [0.0 1 1 0]                      # 1x4 : the XOR answers

W1 = randn(3, 2);  b1 = zeros(3, 1)  # hidden layer: 3 neurons
W2 = randn(1, 3);  b2 = zeros(1, 1)  # output layer: 1 neuron
lr = 1.0                             # learning rate

for epoch in 1:20_000
    # forward pass: project, squash, project, squash
    a1 = σ.(W1 * X  .+ b1)                       # 3x4 hidden activations
    a2 = σ.(W2 * a1 .+ b2)                       # 1x4 outputs

    # backward pass: the chain rule, written out by hand
    d2 = (a2 .- Y) .* a2 .* (1 .- a2)            # how wrong the output is
    d1 = (W2' * d2) .* a1 .* (1 .- a1)           # push that error back a layer

    # gradient-descent step: nudge every weight against its gradient (in place)
    W2 .-= lr .* (d2 * a1');  b2 .-= lr .* sum(d2)
    W1 .-= lr .* (d1 * X');   b1 .-= lr .* sum(d1, dims = 2)
end

println(round.(σ.(W2 * σ.(W1 * X .+ b1) .+ b2), digits = 2))   # ≈ [0.0 1.0 1.0 0.0]
