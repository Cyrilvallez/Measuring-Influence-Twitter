using PlotlyJS
include("cascade.jl")

a = [0.1 0.2;0.05 0.2]
b = [0.8 0.2;0.6 0.1]
c = [0.1 0.2;0.2 0]
d = [0.9 0.2;0.6 0.7]
e = [0 0;0 0]

A = Matrix{Matrix}(undef, 3, 3)

A[1,1] = e
A[1,2] = b
A[1,3] = d
A[2,1] = e
A[2,2] = e
A[2,3] = b
A[3,1] = e
A[3,2] = b
A[3,3] = e


f = [1.2 0.3 0.; 0.7 0.3 0.3; 0. 0.6 0.]
g = [0.3 0.3 0.3; 0.2 0.9 0.8; 0.3 0.9 0.]
h = zeros(3,3)

B = Matrix{Matrix}(undef, 4, 4)

for i in 1:size(B,1), j in 1:size(B,2)
    B[i,j] = h
end

B[1, 4] = f
B[2,1] = g
B[3,4] = f
B[4,1] = g

cuttoff = 0.5
icg = InfluenceCascadeGenerator(cuttoff, false)

cascades_A = observe(A, icg)
cascades_B = observe(B, icg)

a = cascades_A[1]
b = cascades_B[1]
c = cascades_B[2]

plot(plot_cascade_sankey(a, ["1", "2"])...)
plot(plot_cascade_sankey(b, ["1", "2", "3"])...)
plot(plot_cascade_sankey(c, ["1", "2", "3"])...)

