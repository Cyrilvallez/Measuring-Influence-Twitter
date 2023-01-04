module Metrics

using DataFrames

using ..Sensors: InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades

export edge_types

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

    for (k, adjacency) in enumerate(influence_graphs)
        linear_index = 0
        for i = 1:N_actions, j = 1:N_actions
            linear_index += 1
            simplifier = x -> (x[i, j] > cuttoff)
            edge_number[k, linear_index] = sum(simplifier.(adjacency))
        end
    end

    # Compute the proportion of each edges
    edge_proportion = edge_number ./ sum(edge_number, dims=2)

    # Reshape everything into a dictionary
    partition = vcat([[partitions[i] for k = 1:N_actions^2] for i = 1:N_partitions]...)
    edges = repeat(edge_types, N_partitions)
    # Reshape the adjoint to reshape row wise
    count = reshape(edge_number', :)
    proportion = reshape(edge_proportion', :)
    data = Dict("partition" => partition, "edge_type" => edges, "count" => count, "proportion" => proportion)

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
Merge dictionaries with similar keys key-wise. Does not preserve the type of the container (i.e. OrderedDict will be recast as Dict), nor the type of the dict elements.
"""
function combine_dict(dict_list::Vector{<:AbstractDict{V, T}}) where {V,T}

    N = length(dict_list)

    # Check that the keys are the same for all dictionaries
    dict_keys = [collect(keys(dict)) for dict in dict_list]
    for i = 1:N
        if dict_keys[1] != dict_keys[i]
            throw(ArgumentError("One of the dictionary do not have the same keys as the others."))
        end
    end

    combined_dict = Dict{V, Any}()
    for key in dict_keys[1]
        combined_dict[key] = vcat([dict_list[i][key] for i = 1:N]...)
    end

    return combined_dict

end



end # module