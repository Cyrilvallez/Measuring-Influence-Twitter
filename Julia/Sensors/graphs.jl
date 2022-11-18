using CausalityTools
using StatsBase: minimum

include("../Utils/entropy.jl")

#TODO : This is possible to optimize causality measures needing embeddings, as in the current state
# we are computing the same embeddings again and again for each actors and actions instead of precomputing them
# i.e, we loop 2 times actors and actions and recompute the embeddings each time instead of looping one time for the embeddings, 
# and then looping 2 times using the precomputed embeddingds


# Those will be used in an "enum" fashion for dispatch (they do not hold any
# fields, only their name are used)
abstract type CausalityFunction end
struct SMeasure <: CausalityFunction end
struct JointDistanceDistribution <: CausalityFunction end
struct TransferEntropy <: CausalityFunction end


function _surrogate_wrapper(measure::Function, threshold::Real, surrogate::Surrogate, Nsurro::Int)

    function wrapper(x, y)
        causality_value = measure(x, y)
        # If it is lower, we check the same measure with surrogates
        if causality_value < threshold
            generator = surrogenerator(x, surrogate)
            surro_values = Vector(undef, Nsurro)
            for i = 1:Nsurro
                surro_values[i] = measure(generator(), y)
            end
            limit = minimum(surro_values)/4

            # This is accepted since it is significantly lower than for the surrogates
            if causality_value < limit
                return 1
            # This is not accepted in comparison to the surrogates
            else
                return 0
            end
        # In this case no need to check with the surrogates
        else
            return 0
        end
    end

    return wrapper

end


struct InfluenceGraphGenerator 
    causal_function::Function
end


"""
Default constructor using the custom version of transfer entropy.

"""
function InfluenceGraphGenerator()
    func(x, y) = TE(Int.(x .> 0), Int.(y .> 0))
    return InfluenceGraphGenerator(func)
end


"""
Constructor for s measure.
Note : the distances will be computed using Euclidean distance.

## Arguments

- K::Int = 3 is the number of nearest neighbors to consider for each embedded vector
- dx::Int = 5 and dy::Int = 5 are the dimensions for the embedding of the time series (they can be different)
- τx::Int = 1 and τy::Int = 1 are the time delays for the embedding of the time series (they can be different)

"""
function InfluenceGraphGenerator(::Type{SMeasure}; K::Int = 3, dx::Int = 5, dy::Int = 5, τx::Int = 1, τy::Int = 1)
    # We need the conversion to float because s_measure does not support Int (see NearestNeighbors.jl/src/knn.jl line 31 -> seems to be unwanted behavior)
    func(x, y) = s_measure(float(x), float(y), K=K, dx=dx, dy=dy, τx=τx, τy=τy)
    return InfluenceGraphGenerator(func)
end


"""
Constructor for joint distance distribution.
Note : the distances will be computed using Euclidean distance.

## Arguments

- B::Int = 10 is the number of segments in which to cut the interval [0, 1]
- d::Int = 5 is the dimension for the embedding of the time series
- τ::Int = 1 is the time delay for the embedding of the time series

"""
function InfluenceGraphGenerator(::Type{JointDistanceDistribution}; surrogate::Union{Surrogate, Nothing} = RandomShuffle(), Nsurro::Int = 30,
     alpha::Real = 0.001, B::Int = 10, d::Int = 5, τ::Int = 1)

     # If the p-value is inferior than α, we reject the null hypothesis that the mean is 0, and we accept that as influence (encoded with a 1)
    func(x, y) = pvalue(jdd(OneSampleTTest, x, y, B=B, D=d, τ=τ, μ0=0.0), tail=:right)

    if !isnothing(surrogate)
        measure = _surrogate_wrapper(func, alpha, surrogate, Nsurro)
    else
        measure = func
    end

    return InfluenceGraphGenerator(measure)
end


function InfluenceGraphGenerator(::Type{TransferEntropy}; estimator = Kraskov(k=3))
    func(x, y) = transferentropy(float(x), float(y), estimator)
    return InfluenceGraphGenerator(func)
end



"""
Construct the adjacencies matrices (one per partition) from the time series per partition.

"""
function observe(time_series::Vector{Vector{Matrix{Float64}}}, ig::InfluenceGraphGenerator)

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
                    time_serie_1 = partition[i][:, k]
                    time_serie_2 = partition[j][:, l]
                    # If this is the case (at least one time serie is all 0), then there cannot be any influence between the two
                    if iszero(time_serie_1) || iszero(time_serie_2)
                        causality_measure = 0.0
                    # Compute causality between actor i and j and actions k and l
                    else
                        causality_measure = ig.causal_function(time_serie_1, time_serie_2)
                    end
                    edge_matrix[k, l] = isnan(causality_measure) ? 0.0 : causality_measure
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

