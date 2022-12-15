module PreProcessing

using DataFrames, Dates

export no_partition, sentiment, cop_26_dates, cop_27_dates
export trust_score, trust_popularity_score
export country, follower_count, username
export partition_options, action_options, actor_options
export PreProcessingAgents, preprocessing, preprocessing_random

include("partitions.jl")
include("actions.jl")
include("actors.jl")


struct PreProcessingAgents

    partition_function::Function
    action_function::Function
    actor_function::Function

    # Inner constructor to check validity (and order) of arguments
    function PreProcessingAgents(partition, action, actor)
        if !(partition in partition_options)
            throw(ArgumentError("The partition function is not valid (or you provided arguments in the wrong order : it should be partition-action-actor)."))
        end
        if !(action in action_options)
            throw(ArgumentError("The action function is not valid (or you provided arguments in the wrong order : it should be partition-action-actor)."))
        end
        if !(actor in actor_options)
            throw(ArgumentError("The actor function is not valid (or you provided arguments in the wrong order : it should be partition-action-actor)."))
        end
        return new(partition, action, actor)
    end

end


function PreProcessingAgents()
    return PreProcessingAgents(cop_26_dates, follower_count, trust_score)
end


function PreProcessingAgents(partition::Function)
    return PreProcessingAgents(partition, follower_count, trust_score)
end



function preprocessing(data::DataFrame, agents::PreProcessingAgents)

    # Remove possible rows without url domain, and convert string dates to datetimes
    data = data[.~ismissing.(data."domain"), :]
    if eltype(data."created_at") == String
        to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
        data."created_at" = to_datetime.(data."created_at")
    end

    df = data |> agents.partition_function |> agents.action_function |> agents.actor_function

    partitions = sort(unique(df.partition))
    actions = sort(unique(df.action))
    actors = sort(unique(df.actor))

    return df, partitions, actions, actors

end


function preprocessing(data::DataFrame, partition_function::Function, action_function::Function, actor_function::Function)

    # Creating the agents will perform necessary checks
    agents = PreProcessingAgents(partition_function, action_function, actor_function)
    return preprocessing(data, agents)

end



function preprocessing_random(data::DataFrame, agents::PreProcessingAgents)

    # Convert string dates to datetimes if needed
    if eltype(data."created_at") == String
        to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
        data."created_at" = to_datetime.(data."created_at")
    end

    # Shift the random days in the data so that they are consecutive (but we don't touch the time part)
    days = Date.(data.created_at)
    unique_days = sort(unique(days))
    proxy_dates = Vector{DateTime}(undef, length(data.created_at))
    current_day = minimum(unique_days)

    for day in unique_days
        indices = findall(days .== day)
        for ind in indices
            proxy_dates[ind] = DateTime(current_day, Time(data.created_at[ind]))
        end
        current_day += Day(1)
    end

    data.created_at = proxy_dates

    return preprocessing(data, agents)

end


function preprocessing_random(data::DataFrame, partition_function::Function, action_function::Function, actor_function::Function)

    # Creating the agents will perform necessary checks
    agents = PreProcessingAgents(partition_function, action_function, actor_function)
    return preprocessing_random(data, agents)

end


end # module