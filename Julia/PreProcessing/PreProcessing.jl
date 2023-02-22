module PreProcessing

using DataFrames, Dates, DataStructures

export no_partition, sentiment, cop_26_dates, cop_27_dates, skripal_dates
export trust_score, trust_popularity_score, mainstream_score
export follower_count, all_users, retweet_count, IP_scores
export PROJECT_FOLDER

export PreProcessingAgents, preprocessing

include("partitions.jl")
include("actions.jl")
include("actors.jl")


struct PreProcessingAgents

    partition_function::Function
    action_function::Function
    actor_function::Function
    # Dump some parameters so we can log them later
    actor_parameters::AbstractString


    # Inner constructor to check validity (and order) of arguments
    function PreProcessingAgents(partition, action, actor)
        if !(partition in partition_options)
            throw(ArgumentError("The partition function is not valid (or you provided arguments in the wrong order : it should be partition-action-actor)."))
        end
        if !(action in action_options)
            throw(ArgumentError("The action function is not valid (or you provided arguments in the wrong order : it should be partition-action-actor)."))
        end
        if typeof(actor) <: Function
            actor_func = actor
            params = ""
        elseif typeof(actor) <: Tuple
            if !(length(actor) == 2 && typeof(actor[1]) <: Function && typeof(actor[2]) <: AbstractString)
                throw(ArgumentError("If you pass a Tuple as actor, it must be a function and a String."))
            end
            actor_func = actor[1]
            params = actor[2]
        else
            throw(ArgumentError("Actor must be a function or a Tuple consisting of a function and a String."))
        end
        return new(partition, action, actor_func, params)
    end

end


function PreProcessingAgents()
    return PreProcessingAgents(cop_26_dates, trust_score, follower_count())
end


function PreProcessingAgents(partition::Function)
    return PreProcessingAgents(partition, trust_score, follower_count())
end



"""
Preprocess the dataset.
"""
function preprocessing(data::DataFrame, agents::PreProcessingAgents)

    # Remove possible rows without url domain, and convert string dates to datetimes
    data = data[.~ismissing.(data."domain"), :]

    df = data |> agents.partition_function |> agents.action_function |> agents.actor_function

    return df

end



"""
Preprocess the dataset.
"""
function preprocessing(data::DataFrame, partition_function::Function, action_function::Function, actor_function::Function)

    # Creating the agents will perform necessary checks
    agents = PreProcessingAgents(partition_function, action_function, actor_function)
    return preprocessing(data, agents)

end


end # module