module Metrics

using DataFrames, Graphs, SimpleWeightedGraphs, StatsBase

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Helpers: make_simplifier, partitions_actions_actors
using ..Sensors: InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades
using ..PreProcessing: follower_count, retweet_count, IP_scores, all_users

export edge_types, graph_by_majority_vote, betweenness_centralities, indegree_centralities, outdegree_centralities, get_all_ranks


function edge_types(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real) 

   partitions, actions, _ = partitions_actions_actors(df)

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


function edge_types(graph_list::Vector{InfluenceGraphs}, dfs::Vector{DataFrame}, cuttoffs::Vector{<:Real}) 

    data = [edge_types(graph_list[i], dfs[i], cuttoffs[i]) for i = 1:length(graph_list)]
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

    _, actions, actors = partitions_actions_actors(df)

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    betweenness = [betweenness_centrality(graph, normalize=true) for graph in simple_graphs]

    for i = 1:length(betweenness)
        sorting = sortperm(betweenness[i], rev=true)
        betweenness[i] = betweenness[i][sorting]
        actors[i] = actors[i][sorting]
    end

    return betweenness, actors
end



"""
Compute the in-degree centralities of each partition of the influence graphs.
"""
function indegree_centralities(influence_graphs::InfluenceGraphs, df::DataFrame; cuttoff::Real = 0.0, edge_type::AbstractString = "Any Edge")

    _, actions, actors = partitions_actions_actors(df)

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    indegree_centrality = [indegree(graph) for graph in simple_graphs]

    corresponding_actors = []
    for i = 1:length(indegree_centrality)
        sorting = sortperm(indegree_centrality[i], rev=true)
        indegree_centrality[i] = indegree_centrality[i][sorting]
        actors[i] = actors[i][sorting]
    end

    return indegree_centrality, actors
end



"""
Compute the out-degree centralities of each partition of the influence graphs.
"""
function outdegree_centralities(influence_graphs::InfluenceGraphs, df::DataFrame; cuttoff::Real = 0.0, edge_type::AbstractString = "Any Edge")

    _, actions, actors = partitions_actions_actors(df)

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]
    outdegree_centrality = [outdegree(graph) for graph in simple_graphs]

    corresponding_actors = []
    for i = 1:length(outdegree_centrality)
        sorting = sortperm(outdegree_centrality[i], rev=true)
        outdegree_centrality[i] = outdegree_centrality[i][sorting]
        actors[i] = actors[i][sorting]
    end

    return outdegree_centrality, actors
end



function get_all_ranks(df::DataFrame, partition_function::Union{Function, Missing}; by_partition::Bool = true, min_tweets::Int = 3)

    if ismissing(partition_function) && by_partition 
        throw(ArgumentError("If you want to divide ranking by partition you must provide the partition function."))
    end

    if !ismissing(partition_function)
        df = partition_function(df)
    end

    # Extract the functions to apply
    followers, _ = follower_count(by_partition=by_partition, min_tweets=min_tweets, actor_number = "all")
    RT, _ = retweet_count(by_partition=by_partition, min_tweets=min_tweets, actor_number = "all")
    IP, _ = IP_scores(by_partition=by_partition, min_tweets=min_tweets, actor_number = "all")
    All, _ = all_users(by_partition=by_partition, min_tweets=min_tweets)

    # Apply each function to obtain metrics
    df1 = followers(df)
    df2 = RT(df)
    df3 = IP(df)
    control = All(df)

    # Remove retweet_from column
    df1 = df1[!, Not("retweet_from")]
    df2 = df2[!, Not("retweet_from")]
    df3 = df3[!, Not("retweet_from")]
    control = control[!, Not("retweet_from")]

    # Sort each result similarly
    sort!(df1, :created_at)
    sort!(df2, :created_at)
    sort!(df3, :created_at)
    sort!(control, :created_at)

    if !(df1 == control) || !(df2[!, Not("retweet_count")] == control) || !(df3[!, Not(["I_score", "P_score"])] == control[!, Not("tweet_count")])
        throw(ArgumentError("For some reason the different dataframes for different quantities are not the same."))
    end

    control.retweet_count = df2.retweet_count
    control.I_score = df3.I_score
    control.P_score = df3.P_score

    useful = unique(control, :username)[:, ["username", "partition", "tweet_count", "follower_count", "retweet_count", "I_score", "P_score"]]

    if by_partition
        useful = transform(groupby(useful, "partition"), "follower_count" => (x-> ordinalrank(x, rev=true)) => "follower_rank")
        useful = transform(groupby(useful, "partition"), "tweet_count" => (x-> ordinalrank(x, rev=true)) => "tweet_rank")
        useful = transform(groupby(useful, "partition"), "retweet_count" => (x-> ordinalrank(x, rev=true)) => "retweet_rank")
        useful = transform(groupby(useful, "partition"), "I_score" => (x-> ordinalrank(x, rev=true)) => "I_rank")
    else
        useful.follower_rank = ordinalrank(useful.follower_count, rev=true)
        useful.retweet_rank = ordinalrank(useful.retweet_count, rev=true)
        useful.I_rank = ordinalrank(useful.I_score, rev=true)
        useful.tweet_rank = ordinalrank(useful.tweet_count, rev=true)
    end

    return useful

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