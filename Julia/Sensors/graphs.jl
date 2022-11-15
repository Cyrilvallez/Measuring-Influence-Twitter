using CausalityTools

include("../Utils/entropy.jl")


# Those will be used in an "enum" fashion for dispatch (they do not hold any
# fields, only their name are used)
abstract type CausalityFunction end
struct SMeasure <: CausalityFunction end



struct InfluenceGraphGenerator 
    causal_function::Function
end


# Default constructor without argument
function InfluenceGraphGenerator()
    return InfluenceGraphGenerator(TE)
end


# Constructor for s_measure
function InfluenceGraphGenerator(::Type{SMeasure}; K::Int = 3, dx::Int = 5, dy::Int = 5, τx::Int = 1, τy::Int = 1)
    # We need the conversion to float because s_measure does not support Int (see NearestNeighbors.jl/src/knn.jl line 31 -> seems to be unwanted behavior)
    func(x, y) = s_measure(float(x), float(y), K=K, dx=dx, dy=dy, τx=τx, τy=τy)
    return InfluenceGraphGenerator(func)
end


"""
Construct the adjacencies matrices (one per partition) from the time series per partition.
"""
function observe(time_series::Vector{Vector{Matrix{Int}}}, ig::InfluenceGraphGenerator)

    N_actions = size(time_series[1][1])[2]

    # Initialize final output
    adjacencies = Vector{Matrix{Matrix{Float64}}}(undef, length(time_series))

    # Iterate on partitions
    for (m, partition) in enumerate(time_series)

        # Initialize adjacency matrix for the partition
        partitionwise_adjacency = Matrix{Matrix{Float64}}(undef, length(partition), length(partition))

        # Iterate 2 times on all actors
        for i = 1:length(partition), j = 1:length(partition)

            # Initialize the transfer entropy matrix between 2 actors (which is an edge in the actor graph)
            edge_matrix = fill(0.0, N_actions, N_actions)

            if i != j
                # Iterate on actions of each actor i and j
                for k = 1:N_actions, l = 1:N_actions
                    # Compute transfer entropy between actor i and j and actions k and l
                    if ig.causal_function == TE
                        tr_en = ig.causal_function(Int.(partition[i][:, k] .> 0), Int.(partition[j][:, l] .> 0))
                    else
                        tr_en = ig.causal_function(partition[i][:, k], partition[j][:, l])
                    end
                    edge_matrix[k, l] = isnan(tr_en) ? 0 : tr_en
                end
            end
            # cast it into the partition-wise adjacency matrix
            partitionwise_adjacency[i,j] = edge_matrix
        end
        # cast it in the total output vector
        adjacencies[m] = partitionwise_adjacency
    end

    return adjacencies
end


