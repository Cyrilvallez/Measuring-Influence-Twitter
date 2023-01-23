module Metrics

using DataFrames, Graphs, SimpleWeightedGraphs

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Helpers: make_simplifier
using ..Sensors: InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades

export edge_types, graph_by_majority_vote, betweenness_centralities, indegree_centralities, outdegree_centralities


function edge_types(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real) 

    # Actions and partitions are represented in the order they appear in sort(unique(df)) in the adjacency matrix
    actions = sort(unique(df.action))
    partitions = sort(unique(df.partition))

    # Small hack to rename the case when there are no partitions
    if partitions == ["Full dataset"]
        partitions = ["Control"]
    end

    N_actions = length(actions)
    N_partitions = length(partitions)

    edge_types = [string(n1, " to ", n2) for n1 in actions for n2 in actions]

    edge_number = Matrix{Int}(undef, N_partitions, N_actions^2)
    reachable_edge_number = Matrix{Int}(undef, N_partitions, N_actions^2)

    for (k, adjacency) in enumerate(influence_graphs)
        linear_index = 0
        for i = 1:N_actions, j = 1:N_actions
            linear_index += 1
            is_edge = x -> (x[i, j] > cuttoff)
            is_reachable = x -> (x[i, j] != -1)
            edge_number[k, linear_index] = sum(is_edge.(adjacency))
            reachable_edge_number[k, linear_index] = sum(is_reachable.(adjacency))
        end
    end

    # Compute the proportion of each edges
    edge_proportion = edge_number ./ sum(edge_number, dims=2)

    # Normalize by reachable edges
    edge_number_normalized = edge_number ./ reachable_edge_number

    # Reshape everything into a dictionary
    partition = vcat([[partitions[i] for k = 1:N_actions^2] for i = 1:N_partitions]...)
    edges = repeat(edge_types, N_partitions)
    # Reshape the adjoint to reshape row wise
    count = reshape(edge_number', :)
    count_normalized = reshape(edge_number_normalized', :)
    proportion = reshape(edge_proportion', :)
    data = Dict("partition" => partition, "edge_type" => edges, "count" => count, "count_normalized" => count_normalized, "proportion" => proportion)

    return data

end



function edge_types(graph_list::Vector{InfluenceGraphs}, df::DataFrame, cuttoff::Real)

    data = [edge_types(graph_list[i], df, cuttoff) for i = 1:length(graph_list)]
    return combine_dict(data)

end


function edge_types(graph_lists::Vector{Vector{InfluenceGraphs}}, dfs::Vector{DataFrame}, cuttoffs::Vector{<:Real}) 

    data = [edge_types(graph_lists[i], dfs[i], cuttoffs[i]) for i = 1:length(graph_lists)]
    return combine_dict(data)

end



"""
Compute a graph from several different, using majority vote to allocate edges.
"""
function graph_by_majority_vote(graph_list::Vector{InfluenceGraphs}; vote::Union{Int, Nothing} = nothing)

    if isnothing(vote)
        vote = length(graph_list) ÷ 2
        if isodd(length(graph_list))
            vote += 1
        end
    end

    total = sum(graph_list)
    for i = 1:length(total)
        # Reset unreachable edges to -1
        map!.(x -> ifelse(x < 0, -1, x), total[i], total[i])
        # Set all values positive values less than vote to 0
        map!.(x -> ifelse(x > 0 && x < vote, 0, x), total[i], total[i])
        # Set all values larger or equal to vote to 1
        map!.(x -> ifelse(x >= vote, 1, x), total[i], total[i])
    end

    return total

end



"""
Compute the betweenness centralities of each partition of the influence graphs.
"""
function betweenness_centralities(influence_graphs::InfluenceGraphs, df::DataFrame; cuttoff::Real = 0.0, edge_type::AbstractString = "Any Edge")

    actors = sort(unique(df.actor))
    actions = sort(unique(df.action))

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    betweenness = [betweenness_centrality(graph, normalize=true) for graph in simple_graphs]

    corresponding_actors = []
    for i = 1:length(betweenness)
        sorting = sortperm(betweenness[i], rev=true)
        betweenness[i] = betweenness[i][sorting]
        push!(corresponding_actors, actors[sorting])
    end

    return betweenness, corresponding_actors
end



"""
Compute the in-degree centralities of each partition of the influence graphs.
"""
function indegree_centralities(influence_graphs::InfluenceGraphs, df::DataFrame; cuttoff::Real = 0.0, edge_type::AbstractString = "Any Edge")

    actors = sort(unique(df.actor))
    actions = sort(unique(df.action))

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    indegree_centrality = [indegree(graph) for graph in simple_graphs]

    corresponding_actors = []
    for i = 1:length(indegree_centrality)
        sorting = sortperm(indegree_centrality[i], rev=true)
        indegree_centrality[i] = indegree_centrality[i][sorting]
        push!(corresponding_actors, actors[sorting])
    end

    return indegree_centrality, corresponding_actors
end



"""
Compute the out-degree centralities of each partition of the influence graphs.
"""
function outdegree_centralities(influence_graphs::InfluenceGraphs, df::DataFrame; cuttoff::Real = 0.0, edge_type::AbstractString = "Any Edge")

    actors = sort(unique(df.actor))
    actions = sort(unique(df.action))

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    outdegree_centrality = [outdegree(graph) for graph in simple_graphs]

    corresponding_actors = []
    for i = 1:length(outdegree_centrality)
        sorting = sortperm(outdegree_centrality[i], rev=true)
        outdegree_centrality[i] = outdegree_centrality[i][sorting]
        push!(corresponding_actors, actors[sorting])
    end

    return outdegree_centrality, corresponding_actors
end



"""
Merge dictionaries with similar keys key-wise. Does not preserve the type of the container (i.e. OrderedDict will be recast as Dict), nor the type of the dict elements and keys.
"""
function combine_dict(dict_list::Vector{<:AbstractDict}) 

    N = length(dict_list)

    # Check that the keys are the same for all dictionaries
    dict_keys = [collect(keys(dict)) for dict in dict_list]
    for i = 1:N
        if dict_keys[1] != dict_keys[i]
            throw(ArgumentError("One of the dictionary do not have the same keys as the others."))
        end
    end

    combined_dict = Dict()
    for key in dict_keys[1]
        combined_dict[key] = vcat([dict_list[i][key] for i = 1:N]...)
    end

    return combined_dict

end



end # module