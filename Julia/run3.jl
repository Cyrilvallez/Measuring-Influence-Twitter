using Dates, ProgressBars
using StatsBase: sample
import Random

include("Engine/Engine.jl")
using .Engine

# Define datasets
datasets = [COP26]#, COP27, RandomDays]

# Define partition, action and actor for each dataset
agents_cop26 = PreProcessingAgents(cop_26_dates, trust_score, follower_count)
# agents_cop27 = PreProcessingAgents(cop_27_dates, trust_score, follower_count)
# agents_random = PreProcessingAgents(no_partition, trust_score, follower_count)
all_agents = [agents_cop26]#, agents_cop27, agents_random]

# Create the experiment names
experiment_names = ["COP26_JDD_NoSurro"]#, "COP27_TE_NoSurro", "Random_TE_NoSurro"]


# Define time series arguments
time_resolution = 120
standardize = true

# Define graph generator arguments
method = JointDistanceDistribution
surrogate = nothing

# Define influence cascade arguments
cuttoff = 0


tsg = TimeSeriesGenerator(Minute(time_resolution), standardize=standardize)
ig = InfluenceGraphGenerator(method, surrogate=surrogate) 
icg = InfluenceCascadeGenerator(cuttoff)

pipeline = Pipeline(tsg, ig, icg)

# Run the experiment
for (dataset, agents, name) in ProgressBar(zip(datasets, all_agents, experiment_names))
    run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)
end