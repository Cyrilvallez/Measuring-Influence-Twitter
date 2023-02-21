module Metrics

using DataFrames, Graphs, SimpleWeightedGraphs, StatsBase, DataStructures

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Helpers: make_simplifier, partitions_actions_actors, Dataset, COP26, COP27, Skripal, RandomDays, load_dataset
using ..Sensors: InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades
using ..PreProcessing: follower_count, retweet_count, IP_scores, all_users

export edge_types, graph_by_majority_vote, betweenness_centralities, indegree_centralities, outdegree_centralities
export get_general_ranks, get_centrality_ranks, correlation_matrices, find_max_ranks, get_centrality_ranks_all_edges
export correlation_JDD_TE


"""
Return the statistics on the edges for the influence graphs as a dictionary (format for easy visualization with seaborn).
"""
function edge_types(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real) 

   partitions, actions, _ = partitions_actions_actors(df)

    # Small hack to rename the partitions for plotting
    if partitions == ["Full dataset"]
        partitions = ["Control"]
    elseif length(partitions) == 3
        partitions = [split(partition, " ")[1] for partition in partitions]
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
Compute a graph from several different graphs, using majority vote to allocate edges.
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



"""
Rank the users present in a `dataset` according to their tweet count, follower count, retweet count, and I score. If `by_partition` is true, the actors will be defined 
using data inside each partition independently, otherwise using all the dataset provided. The partition will be defined using `partition_function`. Only users with 
a tweet rate of at least `min_tweets` will be considered.
"""
function get_general_ranks(dataset::Type{<:Dataset}, partition_function::Union{Function, Missing}; by_partition::Bool = true, min_tweets::Int = 3)

    df = load_dataset(dataset)

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

    partitions = sort(unique(control.partition))
    dfs = []

    for partition in partitions
        useful = control[control.partition .== partition, :]
        useful = unique(useful, :username)[:, ["username", "partition", "tweet_count", "follower_count", "retweet_count", "I_score", "P_score"]]
        useful.tweet_rank = ordinalrank(useful.tweet_count, rev=true)
        useful.follower_rank = ordinalrank(useful.follower_count, rev=true)
        useful.retweet_rank = ordinalrank(useful.retweet_count, rev=true)
        useful."I score_rank" = ordinalrank(useful.I_score, rev=true)
        sort!(useful, :username)
        push!(dfs, useful)
    end

    return dfs

end


"""
Just a small helper function for mapping column names.
"""
function find_corresponding_col(col::AbstractString)
    if col == "tweet_rank"
        return "tweet_count"
    elseif col == "follower_rank"
        return "follower_count"
    elseif col == "retweet_rank"
        return "retweet_count"
    elseif col == "I score_rank"
        return "I_score"
    elseif occursin("outdegree", col) || occursin("betweenness", col)
        return replace(col, "_rank" => "")
    else
        throw(ArgumentError("column name not known"))
    end

end



"""
Rank the users present in the dataframe `df` according to their centrality measures in the `influence_graphs`. By default, compute the centrality
using the whole graph.
"""
function get_centrality_ranks(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real = 0, edge_type::AbstractString = "Any Edge")

    partitions, actions, actors = partitions_actions_actors(df)

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = make_simplifier(edge_type, cuttoff, actions)
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]

    outdegree_centralities = [outdegree(graph) for graph in simple_graphs]
    betweenness_centralities = [betweenness_centrality(graph, normalize=true) for graph in simple_graphs]

    dfs = []
    for (i, partition) in enumerate(partitions)
        usernames = actors[i]
        dic = Dict("partition" => repeat([partition], length(usernames)), "username" => usernames, "outdegree" => outdegree_centralities[i], "betweenness" => betweenness_centralities[i])
        useful = DataFrame(dic)
        useful.outdegree_rank = ordinalrank(useful.outdegree, rev=true)
        useful.betweenness_rank = ordinalrank(useful.betweenness, rev=true)
        sort!(useful, :username)
        push!(dfs, useful)
    end

    return dfs

end



"""
Rank the users present in the dataframe `df` according to their centrality measures in the `influence_graphs`. Compute the centrality measures 
according to all edge types.
"""
function get_centrality_ranks_all_edges(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real = 0)

    partitions, actions, actors = partitions_actions_actors(df)

    edge_types = [string(a1, " to ", a2) for a1 in actions for a2 in actions]

    dics = [Dict(), Dict(), Dict()]

    for (i, dic) in enumerate(dics)
        dic["username"] = actors[i]
        dic["partition"] = repeat([partitions[i]], length(actors[i]))
    end

    for edge_type in edge_types

        label = replace(edge_type, " " => "_")

        # Create simple graphs by removing weights not needed for the centrality
        simplifier = make_simplifier(edge_type, cuttoff, actions)
        simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]

        outdegree_centralities = [outdegree(graph) for graph in simple_graphs]
        betweenness_centralities = [betweenness_centrality(graph, normalize=true) for graph in simple_graphs]

        for (i, partition) in enumerate(partitions)
            dics[i]["outdegree_$label"] = outdegree_centralities[i]
            dics[i]["betweenness_$label"] = betweenness_centralities[i]

            dics[i]["outdegree_rank_$label"] = ordinalrank(outdegree_centralities[i], rev=true)
            dics[i]["betweenness_rank_$label"] = ordinalrank(betweenness_centralities[i], rev=true)
        end

    end

    dfs = [DataFrame(dic) for dic in dics]
    for df in dfs
        sort!(df, :username)
    end

    return dfs

end


"""
Return the `N` highest ranked users according to each of the measures in `general_ranks_list` and `centrality_ranks_list`, and sort the output 
so that it is in chronological order according to the partitions: before, during and after.
"""
function find_max_ranks(general_ranks_list::Vector, centrality_ranks_list::Vector, N::Int = 10)

    dfs = []
    partitions = []
    for (general_ranks, centrality_ranks) in zip(general_ranks_list, centrality_ranks_list)

        if !(length(unique(general_ranks.partition)) == 1) || !(length(unique(centrality_ranks.partition)) == 1) || general_ranks.partition[1] != centrality_ranks.partition[1]
            throw(ArgumentError("Error in the partitions"))
        end

        if !(general_ranks.username == centrality_ranks.username)
            throw(ArgumentError("Error in the usernames"))
        end

        cols = [name for name in names(general_ranks) if occursin("rank", name)]
        cols2 = [name for name in names(centrality_ranks) if occursin("rank", name)]

        dic = OrderedDict()
        dic["partition"] = repeat([general_ranks.partition[1]], N)

        for col in cols
            sorting = sortperm(general_ranks[!, col])
            users = general_ranks.username[sorting][1:N]

            # Get corresponding value to put missing (-) in case of a 0
            corresponding_col = find_corresponding_col(col)
            vals = general_ranks[!, corresponding_col][sorting][1:N]
            users[vals .== 0] .= "-"

            dic[col] = users
        end
        for col in cols2
            sorting = sortperm(centrality_ranks[!, col])
            users = centrality_ranks.username[sorting][1:N]

            # Get corresponding value to put missing (-) in case of a 0
            corresponding_col = find_corresponding_col(col)
            vals = centrality_ranks[!, corresponding_col][sorting][1:N]
            users[vals .== 0.] .= "-"

            dic[col] = users
        end

        push!(partitions, general_ranks.partition[1])
        # Put partition as first column
        df = DataFrame(dic)
        df = select(df, "partition", :)
        push!(dfs, df)

    end

    if !(occursin("After", partitions[1])) || !(occursin("Before", partitions[2])) || !(occursin("During", partitions[3]))
        throw(ArgumentError("Mixup of partitions."))
    end

    return dfs[[2, 3, 1]]

end


"""
Return the `N` highest ranked users according to each of the measures in `general_ranks_list`, and sort the output 
so that it is in chronological order according to the partitions: before, during and after.
"""
function find_max_ranks(general_ranks_list::Vector, N::Int = 10)

    dfs = []
    partitions = []
    for general_ranks in general_ranks_list

        if !(length(unique(general_ranks.partition)) == 1)
            throw(ArgumentError("Error in the partitions"))
        end

        cols = [name for name in names(general_ranks) if occursin("rank", name)]

        dic = OrderedDict()
        dic["partition"] = repeat([general_ranks.partition[1]], N)

        for col in cols
            sorting = sortperm(general_ranks[!, col])
            users = general_ranks.username[sorting][1:N]

            # Get corresponding value to put missing (-) in case of a 0
            corresponding_col = find_corresponding_col(col)
            vals = general_ranks[!, corresponding_col][sorting][1:N]
            users[vals .== 0] .= "-"

            dic[col] = users
        end
        
        push!(partitions, general_ranks.partition[1])
        # Put partition as first column
        df = DataFrame(dic)
        df = select(df, "partition", :)
        push!(dfs, df)

    end

    if !(occursin("After", partitions[1])) || !(occursin("Before", partitions[2])) || !(occursin("During", partitions[3]))
        throw(ArgumentError("Mixup of partitions."))
    end

    return dfs[[2, 3, 1]]

end


"""
Compute the correlation matrix between each influence measure contained in `general_ranks` and `centrality_ranks`. The correlation is defined as the overlap 
between the `N` highest ranked users according to the centrality measures. Note that this is computed for each partition.
"""
function correlation_matrices(general_ranks, centrality_ranks, N = 50)

    if length(general_ranks) != length(centrality_ranks)
        throw(ArgumentError("Number of partition mismatch."))
    end

    output = []
    labels = []
    partitions = []

    all_ranks = find_max_ranks(general_ranks, centrality_ranks, N)

    for ranks in all_ranks
        partition = ranks.partition[1]
        push!(partitions, partition)

        ranks = ranks[:, Not("partition")]

        cols = [name for name in names(ranks) if occursin("rank", name)]
        labels_ = [split(col, '_')[1] for col in cols]
        corr_matrix = zeros(length(cols), length(cols))

        for (i, col1) in enumerate(cols)
            
            for (j, col2) in enumerate(cols)

                users1 = ranks[!, col1]
                users2 = ranks[!, col2]

                if any(users1 .== "-") || any(users2 .== "-")
                    @warn "Partition $partition : $col1 or $col2 has some missing values"
                end
                # corr_matrix[i,j] = corspearman(users1, users2)
                corr_matrix[i,j] = length(intersect(users1, users2)) / length(users1)

            end
        end

        push!(output, corr_matrix)
        push!(labels, labels_)

    end

    return output, labels, partitions

end


"""
Compute the correlation between each influence measure contained in `general_ranks`. The correlation is defined as the overlap 
between the `N` highest ranked users according to the centrality measures. 
"""
function correlation_matrices(general_ranks::Vector, N = 50)

    output = []
    labels = []
    partitions = []

    all_ranks = find_max_ranks(general_ranks, N)

    for ranks in all_ranks
        partition = ranks.partition[1]
        push!(partitions, partition)

        ranks = ranks[:, Not("partition")]

        cols = [name for name in names(ranks) if occursin("rank", name)]
        labels_ = [split(col, '_')[1] for col in cols]
        corr_matrix = zeros(length(cols), length(cols))

        for (i, col1) in enumerate(cols)
            
            for (j, col2) in enumerate(cols)

                users1 = ranks[!, col1]
                users2 = ranks[!, col2]

                if any(users1 .== "-") || any(users2 .== "-")
                    @warn "Partition $partition : $col1 or $col2 has some missing values"
                end
                # corr_matrix[i,j] = corspearman(users1, users2)
                corr_matrix[i,j] = length(intersect(users1, users2)) / length(users1)

            end
        end

        push!(output, corr_matrix)
        push!(labels, labels_)

    end

    return output, labels, partitions

end


"""
Compute the correlation between centrality measures as computed using JDD and TE based graphs. 
"""
function correlation_JDD_TE(centrality_ranks_JDD, centrality_ranks_TE, N = 50)

    if length(centrality_ranks_JDD) != length(centrality_ranks_TE)
        throw(ArgumentError("Number of partition mismatch."))
    end

    for (r1, r2) in zip(centrality_ranks_JDD, centrality_ranks_TE)

        if names(r1) != names(r2)
            throw(ArgumentError("Dataframes do not have the same columns."))
        end

        if r1.username != r2.username
            throw(ArgumentError("Both do not contain the same usernames."))
        end

    end

    dic = Dict([name => [] for name in names(centrality_ranks_JDD[1]) if occursin("rank", name)]...)
    dic["partition"] = []

    all_ranks1 = find_max_ranks(centrality_ranks_JDD, N)
    all_ranks2 = find_max_ranks(centrality_ranks_TE, N)

    for (ranks1, ranks2) in zip(all_ranks1, all_ranks2)

        partition = ranks1.partition[1]

        cols = [name for name in names(ranks1) if occursin("rank", name)]

        push!(dic["partition"], partition)

        for (i, col) in enumerate(cols)
            
            users1 = ranks1[!, col]
            users2 = ranks2[!, col]

            if any(users1 .== "-") || any(users2 .== "-")
                corr = "-"
            else
                corr = length(intersect(users1, users2)) / length(users1)
            end

            push!(dic[col], corr)
        
        end

    end
    
    df = DataFrame(dic)

    if !(occursin("Before", df.partition[1])) || !(occursin("During", df.partition[2])) || !(occursin("After", df.partition[3]))
        throw(ArgumentError("Mixup of partitions."))
    end

    # Put partition as first column
    df = select(df, "partition", :)

    return df
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