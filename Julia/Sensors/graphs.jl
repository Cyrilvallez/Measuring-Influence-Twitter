using CausalityTools, DataStructures
using StatsBase: maximum, minimum, quantile
import Random
import Base: ==

include("../Utils/entropy.jl")

# Convenient type aliases
const SingleInfluenceGraph = Matrix{Matrix{Float64}}
const InfluenceGraphs = Vector{SingleInfluenceGraph}


# Those will be used in an "enum" fashion for dispatch (they do not hold any
# fields, only their name are used)
abstract type CausalityFunction end
struct SimpleTE <: CausalityFunction end
struct SMeasure <: CausalityFunction end
struct JointDistanceDistribution <: CausalityFunction end
struct TransferEntropy <: CausalityFunction end


struct InfluenceGraphGenerator 
    causal_function::Function
    # Dump some parameters so we can have access to them later
    parameters::OrderedDict
end


# The presence of the dict in InfluenceGraphGenerator force us to redefine equality (the default provided
# does not work anymore as Dict are mutable and a === b is false for mutable)
function ==(a::InfluenceGraphGenerator, b::InfluenceGraphGenerator)
    return a.causal_function == b.causal_function && a.parameters == b.parameters
end


"""
Parse a string and return corresponding expression. Useful for being able to pass anonymous functions
as string (just surround the anonymous function with quotes) for later logging (otherwise once the anonymous function
is created there are no ways of getting back the litteral expression it executes).
"""
function parse_string(s::AbstractString)
    expression = eval(Meta.parse(s))
    return expression
end



"""
Constructor using the custom version of transfer entropy, possibly with surrogates.
"""
function InfluenceGraphGenerator(::Type{SimpleTE}; surrogate::Union{Surrogate, Nothing} = RandomShuffle(), Nsurro::Int = 100,
    limit::String = "x -> maximum(x)", threshold::Real = 0.04, seed::Int = 1234)

    func(x, y) = TE(Int.(x .> 0), Int.(y .> 0))

    if !(isnothing(surrogate) || Nsurro <= 0)
        limit_func = parse_string(limit)
        measure = _surrogate_wrapper(func, threshold, >, limit_func, surrogate, Nsurro, seed)
    else
        measure = func
    end

    params = OrderedDict("function" => "SimpleTE", "surrogate" => string(surrogate), "Nsurro" => Nsurro, "limit" => limit, "threshold" => threshold, "seed" => seed)
    return InfluenceGraphGenerator(measure, params)
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
    func(x, y) = s_measure(x, y, K=K, dx=dx, dy=dy, τx=τx, τy=τy)
    params = OrderedDict("function" => "SMeasure", "K" => K, "dx" => dx, "dy" => dy, "tau_x" => τx, "tau_y" => τy)
    return InfluenceGraphGenerator(func, params)
end


"""
Constructor for joint distance distribution.
Note : the distances will be computed using Euclidean distance.

## Arguments

- B::Int = 10 is the number of segments in which to cut the interval [0, 1]
- d::Int = 5 is the dimension for the embedding of the time series
- τ::Int = 1 is the time delay for the embedding of the time series

"""
function InfluenceGraphGenerator(::Type{JointDistanceDistribution}; surrogate::Union{Surrogate, Nothing} = RandomShuffle(), Nsurro::Int = 100, 
    limit::String = "x -> minimum(x)/4", threshold::Real = 0.01, seed::Int = 1234, B::Int = 10, d::Int = 5, τ::Int = 1)

    func(x, y) = pvalue(jdd(OneSampleTTest, x, y, B=B, D=d, τ=τ, μ0=0.0), tail=:right)

    if !(isnothing(surrogate) || Nsurro <= 0)
        # Make use of surrogates
        limit_func = parse_string(limit)
        measure = _surrogate_wrapper(func, threshold, <, limit_func, surrogate, Nsurro, seed)
    else
        # If the p-value is inferior than threshold, we reject the null hypothesis that the mean is 0, and we accept that as influence (encoded with a 1)
        measure = (x,y) -> func(x,y) < threshold ? 1 : 0
        # measure = func
    end

    params = OrderedDict("function" => "JointDistanceDistribution", "surrogate" => string(surrogate), "Nsurro" => Nsurro, "limit" => limit, "threshold" => threshold,
    "seed" => seed, "threshold" => threshold, "B" => B, "d" => d, "tau" => τ)

    return InfluenceGraphGenerator(measure, params)
end


function InfluenceGraphGenerator(::Type{TransferEntropy}; estimator = Kraskov(k=3))
    func(x, y) = transferentropy(x, y, estimator)
    params = OrderedDict("function" => "TransferEntropy", "estimator" => string(estimator))
    return InfluenceGraphGenerator(func, params)
end



"""
Construct the adjacencies matrices (one per partition) from the time series per partition.

"""
function observe(time_series::Vector{Vector{Matrix{Float64}}}, ig::InfluenceGraphGenerator)

    N_actions = size(time_series[1][1])[2]

    # Initialize final output
    adjacencies = InfluenceGraphs(undef, length(time_series))

    # Iterate on partitions
    for (m, partition) in enumerate(time_series)

        # Initialize adjacency matrix for the partition
        partitionwise_adjacency = SingleInfluenceGraph(undef, length(partition), length(partition))

        # Iterate 2 times on all actors
        for i = 1:length(partition), j = 1:length(partition)

            # Initialize the transfer entropy matrix between 2 actors (which is an edge in the actor graph)
            edge_matrix = fill(-1.0, N_actions, N_actions)

            if i != j
                # Iterate on actions of each actor i and j
                for k = 1:N_actions, l = 1:N_actions
                    time_serie_1 = partition[i][:, k]
                    time_serie_2 = partition[j][:, l]
                    # If this is the case (at least one time serie is all 0), then there cannot be any influence between the two -> we encode it with -1
                    if iszero(time_serie_1) || iszero(time_serie_2)
                        causality_measure = -1.0
                    # Compute causality between actor i and j and actions k and l
                    else
                        causality_measure = ig.causal_function(time_serie_1, time_serie_2)
                    end
                    edge_matrix[k, l] = isnan(causality_measure) ? 0. : causality_measure
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






function _surrogate_wrapper(measure::Function, threshold::Real, comparator::Function, limit::Function, surrogate::Surrogate, Nsurro::Int, seed::Int = 1234)

    if (comparator != <) && (comparator != >)
        throw(ArgumentError("This comparator function is not allowed."))
    end

    function wrapper(x, y)
        causality_value = measure(x, y)
        # If comparison pass, we check the same measure with surrogates
        if comparator(causality_value, threshold)
            generator = surrogenerator(x, surrogate, Random.Xoshiro(seed))
            surro_values = Vector(undef, Nsurro)
            for i = 1:Nsurro
                surro_values[i] = measure(generator(), y)
            end

            # This is accepted since it is significantly different than for the surrogates
            if comparator(causality_value, limit(surro_values))
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