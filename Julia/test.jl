using Dates
using StatsBase: sample
import Random

include("Engine/Engine.jl")
using .Engine;

# Load data
data_cop26 = load_dataset(COP26)
data_cop27 = load_dataset(COP27)
data_random = load_dataset(RandomDays)
datasets = [data_cop26, data_cop27, data_random]

# Define partition, action and actor for each dataset
agents_cop26 = PreProcessingAgents(cop_26_dates, trust_score, follower_count)
agents_cop27 = PreProcessingAgents(cop_27_dates, trust_score, follower_count)
agents_random = PreProcessingAgents(no_partition, trust_score, follower_count)
all_agents = [agents_cop26, agents_cop27, agents_random]

# Create the experiment names
experiment_names = ["COP26_foo", "COP27_foo", "Random_foo"]


# Define time series arguments
time_resolution = 240
standardize = true

# Define graph generator arguments
method = JointDistanceDistribution
Nsurro = 100
alpha = 0.001
B = 10
d = 5
τ = 1

# Define influence cascade arguments
cuttoff = WithoutCuttoff


tsg = TimeSeriesGenerator(Minute(time_resolution), standardize=standardize)
igs = InfluenceGraphGenerator(method, Nsurro=Nsurro, alpha=alpha, B=B, d=d, τ=τ, seed=1234)
icg = InfluenceCascadeGenerator(cuttoff)

pipeline = Pipeline(tsg, ig, icg) for ig in igs

# Run the experiment
for (data, agents, name) in zip(datasets, all_agents, experiment_names)
    run_experiment(data, agents, pipeline, save=true, experiment_name=name)
end