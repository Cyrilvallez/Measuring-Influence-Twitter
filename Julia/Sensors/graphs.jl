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

!!! In most situations, defining a function using eval inside another function causes problems of world age (see 
https://docs.julialang.org/en/v1/manual/methods/#Redefining-Methods & https://discourse.julialang.org/t/world-age-problem-explanation/9714/4).
In our case, because the `eval` function is called inside a wrapper function, and the wrapper itself is returned, the eval function is never actually evaluated before  
we return the InfluenceGraphGenerator. Thus if the Generator was defined in global scope, then the world age is incremented and there are no issues.
However, to avoid situations potentially causing problems if InfluenceGraphGenerator are defined inside functions, we used `Base.invokelatest` in the
wrapper function definition (see function `_surrogate_wrapper`). This ensures that the method defined using `eval` is always correctly interpreted
by Julia. However, this sometimes decreases performance. If performance is critical, one should remove `Base.invokelatest` in `_surrogate_wrapper` and make sure
that all InfluenceGraphGenerator are defined in global scope (i.e. not inside functions etc).
"""
function parse_string(s::AbstractString)
    anonymous_function = eval(Meta.parse(s))
    return anonymous_function
end



"""
Constructor using the custom version of transfer entropy, possibly with surrogates.
"""
function InfluenceGraphGenerator(::Type{SimpleTE}; surrogate::Union{Surrogate, Nothing} = RandomShuffle(), Nsurro::Int = 100,
    limit::String = "x -> maximum(x)", threshold::Real = 0.04)

    func(x, y) = TE(Int.(x .> 0), Int.(y .> 0))

    if !(isnothing(surrogate) || Nsurro <= 0)
        limit_func = parse_string(limit)
        measure = _surrogate_wrapper(func, threshold, >, limit_func, surrogate, Nsurro)
    else
        measure = func
    end

    params = OrderedDict("function" => "SimpleTE", "surrogate" => string(surrogate), "Nsurro" => Nsurro, "limit" => limit, "threshold" => threshold)
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
    limit::String = "x -> minimum(x)/4", threshold::Real = 0.001, B::Int = 10, d::Int = 5, τ::Int = 1)

    func(x, y) = pvalue(jdd(OneSampleTTest, x, y, B=B, D=d, τ=τ, μ0=0.0), tail=:right)

    if !(isnothing(surrogate) || Nsurro <= 0)
        # Make use of surrogates
        limit_func = parse_string(limit)
        measure = _surrogate_wrapper(func, threshold, <, limit_func, surrogate, Nsurro)
    else
        # If the p-value is inferior than threshold, we reject the null hypothesis that the mean is 0, and we accept that as influence (encoded with a 1)
        measure = (x,y) -> func(x,y) < threshold ? 1 : 0
        # measure = func
    end

    params = OrderedDict("function" => "JointDistanceDistribution", "surrogate" => string(surrogate), "Nsurro" => Nsurro, "limit" => limit, "threshold" => threshold,
    "threshold" => threshold, "B" => B, "d" => d, "tau" => τ)

    return InfluenceGraphGenerator(measure, params)
end


"""
Full transfer entropy from CausalityTools.
"""
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
    for (m, partition) in enumerate(time_series)
        partitionwise_adjacency = SingleInfluenceGraph(undef, length(partition), length(partition))
        for i = 1:length(partition), j = 1:length(partition)
            # Fill with -1s (that is how we encore unreachable values, i.e when the time series are empty)
            edge_matrix = fill(-1.0, N_actions, N_actions)
            @inbounds partitionwise_adjacency[i,j] = edge_matrix
        end
        @inbounds adjacencies[m] = partitionwise_adjacency
    end


    # Iterate on partitions
    for (m, partition) in enumerate(time_series)

        # Iterate 2 times on all actors
        for i = 1:length(partition), j = 1:length(partition)

            if i != j

                # Iterate on actions of each actor i and j
                for k = 1:N_actions 
                    @inbounds time_serie_1 = @view partition[i][:, k]
                    if iszero(time_serie_1)
                        continue
                    else
                        for l = 1:N_actions
                            @inbounds time_serie_2 = @view partition[j][:, l]
                            if iszero(time_serie_2)
                                continue
                            else
                                # Compute causality between actor i and j and actions k and l
                                causality_measure = ig.causal_function(time_serie_1, time_serie_2)
                            end
                            @inbounds adjacencies[m][i,j][k, l] = isnan(causality_measure) ? 0. : causality_measure
                        end
                    end
                end
                
            end

        end
        
    end

    return adjacencies
end





"""
Wrapper for surrogate testing.
"""
function _surrogate_wrapper(measure::Function, threshold::Real, comparator::Function, limit::Function, surrogate::Surrogate, Nsurro::Int)

    if (comparator != <) && (comparator != >)
        throw(ArgumentError("This comparator function is not allowed."))
    end

    function wrapper(x, y)
        causality_value = measure(x, y)
        # If comparison pass, we check the same measure with surrogates
        if comparator(causality_value, threshold)
            generator = surrogenerator(x, surrogate)
            surro_values = Vector(undef, Nsurro)
            for i = 1:Nsurro
                surro_values[i] = measure(generator(), y)
            end

            # This is accepted since it is significantly different than for the surrogates
            # if comparator(causality_value, limit(surro_values))
            if comparator(causality_value, Base.invokelatest(limit, surro_values))
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