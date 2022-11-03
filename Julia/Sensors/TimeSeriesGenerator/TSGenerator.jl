using DataFrames


struct TimeSeriesGenerator
    actor_col::Union{String, Symbol}
    action_col::Union{String, Symbol}
    part_col::Union{String, Symbol}
end

function TimeSeriesGenerator()
    return TimeSeriesGenerator(:actor, :action, :partition)
end


"""
Compute the time series for each actor and actions, inside each partition. The order of each is the natural order  
they appear in the DataFrame (and as returned by unique(); e.g the first element times_series[1] correspond  
to unique(data.partition)[1]). In the same way, the first actor in the first partition is the one returned 
by unique(data.actor)[1]. Same goes for the actions.

CAUTION : In order to get the time series correctly, we sort the DataFrame according to :time inplace. It will be modified.
"""
function observe(data::DataFrame, tsg::TimeSeriesGenerator)  

    # We sort the dataframe in place ! It will be modified.
    sort!(data, :time)

    # Compute unique values for all quantities
    times = unique(data.time)
    actors = unique(data[!, tsg.actor_col])
    actions = unique(data[!, tsg.action_col])
    partitions = unique(data[!, tsg.part_col])

    # Compute length of all unique values
    N_times = length(times)
    N_actors = length(actors)
    N_actions = length(actions)
    N_partitions = length(partitions)

    # initialize output
    time_series = Vector{Vector{Matrix{Int}}}(undef, N_partitions) 

    for (i, partition) in enumerate(partitions)

        # Initialize the time serie for one partition and all actors
        partitionwise_time_series = Vector{Matrix{Int}}(undef, N_actors)
        # Select relevant data portion
        data_per_partition = data[data[!, tsg.part_col] .== partition, :]

        for (j, actor) in enumerate(actors)

            # Initialize the time serie for one actor and all actions
            actor_time_series = fill(0, N_times, N_actions)
            # Select relevant data portion
            data_per_actor = data_per_partition[data_per_partition[!, tsg.actor_col] .== actor, :]

            for (k, action) in enumerate(actions)

                # Select relevant data portion
                data_per_action = data_per_actor[data_per_actor[!, tsg.action_col] .== action, :]
                # Compute time serie for the action (frequency of occurence by time). 
                # We do not sort as we already sorted by :time at the beginning, thus the order of apearance is sufficient (it is sorted).
                # Note that it does not matter what column we use for length : we only want the number of lines corresponding to given time in df
                time_serie = combine(groupby(data_per_action, :time, sort=false),  tsg.part_col  => length => :count)
                # Cast it into the time series per actor
                actor_time_series[indexin(time_serie.time, times), k] = time_serie.count

            end

            # Cast into the partition wise time series
            partitionwise_time_series[j] = actor_time_series

        end

        # Finally cast it into the total time series
        time_series[i] = partitionwise_time_series

    end
    
    return time_series
    
end


