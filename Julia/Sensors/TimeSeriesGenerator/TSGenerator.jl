using DataFrames
using TimeSeries


mutable struct TimeSeriesGenerator  <: Sensor
    # premise is that each sensor instantiation will be designed to 
    # split itself by some action definition and actor definition
    # the partition is assumed to be already given (eg, by narrative)
    actor_col
    action_col
    part_col
end



function observe(data, tsg::TimeSeriesGenerator)  
# creates a hierachical list of time series 
#   first, split by partition
#   then, split by actor within partitioned set
#   finally, a TimeArray with the each action frequency at 
#           each time step for the actor within the paritioned set 
    times = unique(data.time)
    actors = unique(data[!, tsg.actor_col])
    actions = unique(data[!, tsg.action_col])
    time_series = Vector{Vector{TimeArray}}() # output

    partitioned_data = groupby(data, tsg.part_col)
    for part in partitioned_data
        partitionwise_time_series = Vector{TimeArray}()
        for actor in actors
            actor_ts_temp = fill(0.0, length(times), length(actions))
            for (i,action) in enumerate(actions)
                temp_ts = get_ts(part[(part[!, tsg.actor_col].==actor).&&(part[!, tsg.action_col].==action),:])
                actor_ts_temp[indexin(temp_ts.time, times), i] = Float16.(temp_ts.count)#Int.(temp_ts.count.>0) #occured or didnt
            end
            push!(partitionwise_time_series, TimeArray(times, actor_ts_temp, Symbol.(actions), actor))
        end
        push!(time_series, partitionwise_time_series)
    end

    return time_series

end

function get_ts(data)
    return combine(groupby(data,:time),  :partition => length => :count)
end

