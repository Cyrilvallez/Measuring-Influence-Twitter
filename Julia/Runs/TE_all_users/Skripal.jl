using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("../../Engine/Engine.jl")
using .Engine

# Define datasets
dataset = Skripal

# Define partition, action and actor for each dataset
partitions = skripal_dates
actions = trust_score
actors = all_users(by_partition=true, min_tweets=3)

agents = PreProcessingAgents(partitions, actions, actors)

# Create the experiment names
name = "TE_all_users/Skripal"


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
run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)