using Dates, ProgressBars
using StatsBase: sample
import Random

include("Engine/Engine.jl")
using .Engine

# Define datasets
datasets = [COP26, RandomDays]#, COP27, RandomDays]

# Define partition, action and actor for each dataset
agents_cop26 = PreProcessingAgents(cop_26_dates, trust_score, follower_count)
# agents_cop27 = PreProcessingAgents(cop_27_dates, trust_score, follower_count)
agents_random = PreProcessingAgents(no_partition, trust_score, follower_count)
all_agents = [agents_cop26, agents_random]#agents_cop27, agents_random]

# Create the experiment names
experiment_names = ["COP26_JDD_10_seeds_new", "Random_JDD_10_seeds_new"]#"COP27_JDD_10_seeds", "Random_JDD_10_seeds"]


# Define time series arguments
time_resolution = 120
standardize = true

# Define graph generator arguments
method = JointDistanceDistribution
Nsurro = 100
B = 10
d = 5
τ = 1

# Define influence cascade arguments
cuttoff = WithoutCuttoff


# Create all pipelines based on different seeds for the same methods
seeds = sample(Random.Xoshiro(12), 1:10000, 10, replace=false)

tsg = TimeSeriesGenerator(Minute(time_resolution), standardize=standardize)
igs = [InfluenceGraphGenerator(method, Nsurro=Nsurro, B=B, d=d, τ=τ, seed=seed) for seed in seeds]
icg = InfluenceCascadeGenerator(cuttoff)

pipelines = [Pipeline(tsg, ig, icg) for ig in igs]

# Run the experiment
for (dataset, agents, name) in ProgressBar(zip(datasets, all_agents, experiment_names))
    run_experiment(dataset, agents, pipelines, save=true, experiment_name=name)
end