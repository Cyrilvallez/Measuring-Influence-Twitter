using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("../../Engine/Engine.jl")
using .Engine

# Define datasets
dataset = COP26

# Define partitions, actions and actors
partitions = cop_26_dates
actions = trust_score
actors = all_users(by_partition=true, min_tweets=3)

agents = PreProcessingAgents(partitions, actions, actors)

# Define which partition we are going to run on
which_partition = "Before COP26"

# Create the experiment names
name = "JDD_all_users/COP26-$which_partition"


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
run_experiment(dataset, which_partition, agents, pipeline, save=true, experiment_name=name)
