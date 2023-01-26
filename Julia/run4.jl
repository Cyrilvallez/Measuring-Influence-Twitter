using Dates, ProgressBars
using StatsBase: sample
import Random
Random.seed!(12)

include("Engine/Engine.jl")
using .Engine

# Define datasets
datasets = [COP26, COP27, RandomDays]

# Define partition, action and actor for each dataset
actions = trust_score
actors = all_users(by_partition=true, min_tweets=3)

agents_cop26 = PreProcessingAgents(cop_26_dates, actions, actors)
agents_cop27 = PreProcessingAgents(cop_27_dates, actions, actors)
agents_random = PreProcessingAgents(no_partition, actions, actors)
all_agents = [agents_cop26, agents_cop27, agents_random]

# Create the experiment names
experiment_names = ["TE_all_users/COP26", "TE_all_users/COP27", "TE_all_users/Random"]


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
ig = InfluenceGraphGenerator(method, Nsurro=Nsurro, threshold=threshold) 
icg = InfluenceCascadeGenerator(cuttoff)

pipeline = Pipeline(tsg, ig, icg)

# Run the experiment
for (dataset, agents, name) in ProgressBar(zip(datasets, all_agents, experiment_names))
    run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)
end