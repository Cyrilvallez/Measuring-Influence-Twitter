using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("Engine/Engine.jl")
using .Engine

# Define datasets
dataset = COP26

# Define partition, action and actor for each dataset
actions = trust_score
actors = follower_count(by_partition=true, min_tweets=3, actor_number=10, aggregate_size=100000000)

agents = PreProcessingAgents(cop_26_dates, actions, actors)

# Create the experiment names
name = "Dummy_test2"


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
run_experiment(dataset, "Before COP26", agents, pipeline, save=true, experiment_name=name)