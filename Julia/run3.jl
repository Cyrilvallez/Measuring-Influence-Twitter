using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("Engine/Engine.jl")
using .Engine

# Define datasets
dataset = RandomDays

# Define partitions, actions and actors
partitions = no_partition
actions = trust_score
actors = all_users(by_partition=true, min_tweets=3)

agents = PreProcessingAgents(partitions, actions, actors)

# Create the experiment names
name = "JDD_all_users/Random"


# Define time series arguments
time_resolution = 120
standardize = true

# Define graph generator arguments
method = JointDistanceDistribution
Nsurro = 100
threshold = 0.001
B = 10
d = 5
τ = 1

# Define influence cascade arguments
cuttoff = WithoutCuttoff


tsg = TimeSeriesGenerator(Minute(time_resolution), standardize=standardize)
igg = InfluenceGraphGenerator(method, Nsurro=Nsurro, threshold=threshold, B=B, d=d, τ=τ) 
icg = InfluenceCascadeGenerator(cuttoff)

pipeline = Pipeline(tsg, igg, icg)

# Run the experiment
run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)
