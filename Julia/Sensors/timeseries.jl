using DataFrames
using Dates
using StatsBase: minimum, maximum, mean, std


# Contains informations we need to construct the time series
struct TimeSeriesGenerator
    time_interval::Period
    time_column::Union{String, Symbol}
    actor_column::Union{String, Symbol}
    action_column::Union{String, Symbol}
    partition_column::Union{String, Symbol}
    standardize::Bool
end


function TimeSeriesGenerator(time_interval::Period; standardize::Bool = true)
    return TimeSeriesGenerator(time_interval, :created_at, :actor, :action, :partition, standardize)
end


"""
Compute the time series for each actor and actions, inside each partition. The order of each is the natural sorted order  
(as returned by sort(unique()); e.g the first element times_series[1] correspond to the partition returned by
sort(unique(data.partition))[1]). In the same way, the first actor in the first partition is the one returned 
by sort(unique(data.actor))[1]. Same goes for the actions.  
Note that the time series inside each partition are not necessarily the same length, (e.g partitions based on time), however 
they will all include all the actors and actions in the dataset, even if some actors (or actions) are not present for one or more partition.

CAUTION : In order to get the time series correctly, we create column :time_bin and sort the DataFrame according to it inplace. The order of the rows will be modified.
"""
function observe(data::DataFrame, tsg::TimeSeriesGenerator)  

    # Bin the time column into time intervals
    round_time(data, tsg.time_interval, tsg.time_column)
    # We sort the dataframe in place ! The order of the rows will be modified.
    sort!(data, :time_bin)

    # Compute unique values for all quantities, and sort them to give a consistent ordering
    actors = sort(unique(data[!, tsg.actor_column]))
    actions = sort(unique(data[!, tsg.action_column]))
    partitions = sort(unique(data[!, tsg.partition_column]))

    # Compute length of all unique values
    N_actors = length(actors)
    N_actions = length(actions)
    N_partitions = length(partitions)

    # initialize output
    time_series = Vector{Vector{Matrix{Float64}}}(undef, N_partitions) 

    for (i, partition) in enumerate(partitions)

        # Initialize the time serie for one partition and all actors
        partitionwise_time_series = Vector{Matrix{Float64}}(undef, N_actors)
        # Select relevant data portion
        data_per_partition = data[data[!, tsg.partition_column] .== partition, :]

        # Compute unique time values for only inside the given partition (not the whole dataframe), because a partition made 
        # on time of tweets (corresponding to a sliding window) should not contain 0s for all times not accessible for them
        # e.g if the partitions are "Before COP26" and "After COP26" it does not make sense to include times "After COP26"
        # in the time series of the partition "Before COP26", as they will all bo 0s.
        # Note that time_bin is already sorted since we sorted the dataframe by it
        times = unique(data_per_partition.time_bin)
        N_times = length(times)

        # Enumerate over all actors even if some may not be present in current partition
        for (j, actor) in enumerate(actors)

            # Initialize the time serie for one actor and all actions
            actor_time_series = fill(0, N_times, N_actions)
            # Select relevant data portion
            data_per_actor = data_per_partition[data_per_partition[!, tsg.actor_column] .== actor, :]

            # Enumerate over all actions even if some may not be present for current actor/partition
            for (k, action) in enumerate(actions)

                # Select relevant data portion
                data_per_action = data_per_actor[data_per_actor[!, tsg.action_column] .== action, :]
                # Compute time serie for the action (frequency of occurence by time). 
                # We do not sort as we already sorted by :time_bin at the beginning, thus the order of apearance is sufficient (it is sorted).
                # Note that it does not matter what column we use for length : we only want the number of lines corresponding to given time_bin in data
                time_serie = combine(groupby(data_per_action, :time_bin, sort=false),  tsg.partition_column  => length => :count)
                # Cast it into the time series per actor
                actor_time_series[indexin(time_serie.time_bin, times), k] = time_serie.count

            end

            # Cast into the partition wise time series
            if tsg.standardize
                partitionwise_time_series[j] = standardize(actor_time_series)
            else
                partitionwise_time_series[j] = actor_time_series
            end

        end

        # Finally cast it into the total time series
        time_series[i] = partitionwise_time_series

    end
    
    return time_series
    
end




"""
Standardize data, handling the case when one column contains only same value (this happens in our case with vectors of only 0s).
"""
function standardize(x)
    std_ = std(x, dims=1)
    return (x .- mean(x, dims=1)) ./ ifelse.(std_ .> 0, std_, ones(size(std_)))
end


"""
Create an array of time bins of length `time_interval` between `start_time` and `end_time`.  
The last bin may not be the same length as it will be set to `end_time`.
"""
function create_time_intervals(start_time::DateTime, end_time::DateTime, time_interval::Period)

    # Set beginning and end of interval by rounding to the nearest complete minute
    start_time = floor(start_time, Minute)
    end_time = ceil(end_time, Minute)

    intervals = [start_time]
    
    if end_time - start_time > time_interval
        start = start_time
        while start + time_interval < end_time
            push!(intervals, start + time_interval)
            start += time_interval
        end
    else
        throw(ArgumentError("The `time_interval` is too large for even 1 interval between `start_time` and `end_time`."))
    end
            
    push!(intervals, end_time)
    
    return intervals

end


"""
Map `time` inside one of the bins defined by the `bins` vector.  
This will return the value bins[i] if bins[i] <= time < bins[i+1], i.e the left value of the interval  
it is contained in.
"""
function map_to_bin(time::DateTime, bins::Vector{DateTime})

    N = length(bins)

    for i = 1:(N-1)
        if bins[i] <= time < bins[i+1]
            return bins[i]
        end
    end

    # If the time is the last value of the bins, we set to the last interval
    if time == bins[end]
        return bins[N-1]
    end

    # If we don't return any value at this point, there is an issue
    throw(ArgumentError("The `time` provided is not contained is any `bins`."))

end


"""
Create a new column `time_bin` in the dataframe, binning the `time_column` of the dataframe in bins of size `time_interval`.  
Each value of df.time_bin is the value of the left limit of the interval in which the corresponding entry of `time_column` is contained.
"""
function round_time(df::DataFrame, time_interval::Period, time_column::Union{Symbol, String} = :created_at)
    time_intervals = create_time_intervals(minimum(df[!, time_column]), maximum(df[!, time_column]), time_interval)
    df.time_bin = map_to_bin.(df[!, time_column], Ref(time_intervals))
end

