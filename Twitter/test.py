#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 20 15:58:19 2022

@author: cyrilvallez
"""

from datetime import datetime, timedelta
import numpy as np

a = datetime.fromisoformat('2022-10-12T23:18')
b = datetime.fromisoformat('2022-10-13T07:13')
c = datetime.fromisoformat('2022-10-14T12:32')
d = datetime.fromisoformat('2022-10-14T12:31')

def round_dt(dt, delta=timedelta(minutes=30)):
    ref = datetime.min.replace(tzinfo=dt.tzinfo)
    return ref + round((dt - ref) / delta) * delta

a = round_dt(a, timedelta(minutes=5))
b = round_dt(b, timedelta(minutes=5))
c = round_dt(c, timedelta(minutes=5))
d = round_dt(d, timedelta(minutes=5))

test, counts = np.unique([a,b,c,d], return_counts=True)


def timeseries(df, struc):
    
    times = np.unique(df[struc.time])
    partitions = np.unique(df[struc.partition])
    actors = np.unique(df[struc.actors])
    actions = np.unique(df[struc.actions])
    
    for i, partition in enumerate(partitions):
        partition_wise = df[df[struc.partitions] == partition]
        for j, actor in enumerate(actors):
            actor_wise = partition_wise[partition_wise[struc.actors] == actor]
            time_serie = np.zeros((len(times), len(actions))
            for k, action in enumerate(actions):
                action_wise = actor_wise[actor_wise[struc.actions] == action]
                dates, counts = np.unique(action_wise[struc.times])
                
    
"""
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

"""

#%%
import pandas as pd

df = pd.DataFrame({'Animal': ['Falcon', 'Falcon',
                              'Parrot', 'Parrot'],
                   'Max Speed': [380., 370., 24., 26.]})

a = df.groupby('Animal')

for i in a:
    print(i['Animal'])
    print('\n\n')



