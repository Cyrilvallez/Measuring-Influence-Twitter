module PreProcessing

using DataFrames

export no_partition, sentiment, cop_26_dates
export trust_popularity_score_old, trust_score, trust_popularity_score
export country, follower_count, username
export partition_options, action_options, actor_options

include("partitions.jl")
include("actions.jl")
include("actors.jl")


struct PreProcessingAgents

    partition_function::Function
    action_function::Function
    actor_function::Function

end


function PreProcessingAgents()
    return Agents(cop_26_dates, follower_count, trust_score)
end


function preprocessing(data::DataFrame, agents::PreProcessingAgents)

    df = data |> agents.partition_function |> agents.action_function |> agents.actor_function

    partitions = sort(unique(df.partition))
    actions = sort(unique(df.action))
    actors = sort(unique(df.actor))

    return df, partitions, actions, actors

end


function preprocessing(data::DataFrame, partition_function::Function, action_function::Function, actor_function::Function)

    df = data |> partition_function |> action_function |> actor_function

    partitions = sort(unique(df.partition))
    actions = sort(unique(df.action))
    actors = sort(unique(df.actor))

    return df, partitions, actions, actors

end

end # module