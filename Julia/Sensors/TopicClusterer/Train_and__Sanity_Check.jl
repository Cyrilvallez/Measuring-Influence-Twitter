include("TrainValidate.jl")
using CSV
using BenchmarkTools

## Data wrangling

data = CSV.read("X0.csv", DataFrame; delim='\t')
data.Date = [1,1,2,2,3,3,4,4,5,5]
rename!(data, [:Index, :Text, :Date])

## Initialize our models

dumb_cluster = TopicClusterer()
rand_cluster = TopicClusterer(rand_time_embedding)


## Validate 

@benchmark observe(data.Text, dumb_cluster)
@benchmark observe(data, rand_cluster)

topic_defs_dumb = observe(data.Text, dumb_cluster)
topic_defs_rand = observe(data, rand_cluster)