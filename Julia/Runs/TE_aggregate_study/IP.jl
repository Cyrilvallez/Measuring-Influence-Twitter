using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("../../Engine/Engine.jl")
using .Engine

# Define datasets
dataset = COP26

# Define partition, action and actor for each dataset
partitions = cop_26_dates
actions = trust_score

aggregate_sizes = [500, 200, 100, 50, 10]
all_actors = [IP_scores(by_partition=true, min_tweets=3, actor_number=600, aggregate_size=size) for size in aggregate_sizes]

all_agents = [PreProcessingAgents(partitions, actions, actors) for actors in all_actors]

# Create the experiment names
experiment_names = "TE_aggregates_study/IP/" .* ["aggregate_size_$size" for size in aggregate_sizes]


# Define time series arguments
time_resolution = 120
standardize = false

# Define graph generator arguments
method = SimpleTE
Nsurro = 100
threshold = 0.04

# Define influence cascade arguments
cuttoff = WithoutCuttoff

tsg = TimeSeriesGenerator(Minute(time_resolution), standardize=standardize)
igg = InfluenceGraphGenerator(method, Nsurro=Nsurro, threshold=threshold)
icg = InfluenceCascadeGenerator(cuttoff)

pipeline = Pipeline(tsg, igg, icg)

# Run the experiment
for (agents, name) in ProgressBar(zip(all_agents, experiment_names))
    run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)
end