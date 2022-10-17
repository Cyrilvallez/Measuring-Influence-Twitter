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

# default
function TimeSeriesGenerator()
    TimeSeriesGenerator(example_actor_agregator, example_action_labeler)
end

#function print(tsg::TimeSeriesGenerator)

#end

function help(type::typeof(TimeSeriesGenerator))
    println(""" To define a TimeSeriesGenerator sensor, we need two things: an actor_agregaor and an action_labeler. Input data is assumed to be in a DataFrame and include at minimum "time" (timestamp of action) and "parition" (some labeling scheme comparable to the ICE programs narratives)
        
        actor_agregator: function that labels each sample as having been sourced from a particular actor. 
            built-in options include:
                1. example_actor_agregator: assumes the input data has the column "source", which it simply uses to set the actor column
    
        action_labeler: function that labels each sample as being one of a number of action types (should be mutually exclusive)
            build-in options include:
                1. example_action_agregator: assumes the input data has the column "content". The function identifies one of three action types: "talk about economy" (content contains the word "economy"), "talk about war" (content contains the word "war"), and "default" (else). 
        

        To "take a measurement" of the data, call `observe(data)`. This takes in a DataFrame with at least columns "time" and "partition" and outputs a P dimensional vector of N dimensional vectors of TimeArray objects, where P is the number of partitions, N is the number of distinct actors, and each TimeArray object essentially contains a timeseries for each action with the value of 1 if that actor took that action during that time step.

        Use the constructor TimeSeriesGenerator() to use the example functions, or define your own and use TimeSeriesGenerator(func1, func2)

    """)
end

function example_actor_agregator(data)
    # for data pulled from /Data/1_Raw/articles1
    # defines the actor as the news source
    data.actor = data.source
    return data
end

function example_action_labeler(data)
    # for data pulled from /Data/1_Raw/articles1
    # placeholder actions are:
    #   "talk about economy"    - the article says "economy"
    #   "talk about war"        - the article says "war"
    #   "default"               - the article says neither

    actions = []
    for text in data.content
        action = "default"
        if occursin("economy", text)
            action = "talk about economy"
        elseif occursin("war", text)
            action = "talk about war"
        end
        push!(actions, action)
    end
    data.action = actions

    # should always return only time, actor, action, and partition
    return data[:,[:time, :actor, :action, :partition]]
end


function observe(data, tsg::TimeSeriesGenerator)
    data = data |> tsg.actor_agregator |> tsg.action_labeler |> x->sort(x,:time)
    return observe(data)#df_sub, unique(data.action)
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

