module Engine

using DataFrames
using ProgressBars: ProgressBar
using Reexport

include("../Sensors/Sensors.jl")
include("../PreProcessing/PreProcessing.jl")
include("../Utils/Helpers.jl")
include("../Utils/Metrics.jl")
include("../Utils/Visualizations.jl")

# Load the modules and reexport them so that they are available when importing only Engine (this removes the need to include every file AND in the correct order)
@reexport using .Sensors, .PreProcessing, .Visualizations, .Helpers, .Metrics

export run_experiment, ProgressBar
export RESULT_FOLDER

RESULT_FOLDER = PROJECT_FOLDER * "/Results"


"""
Run a single experiment an log the results.
"""
function run_experiment(dataset::Type{<:Dataset}, agents::PreProcessingAgents, pipeline::Pipeline; N_days::Int = 13, save::Bool = true, experiment_name = nothing)

    if save && isnothing(experiment_name)
        throw(ArgumentError("You must provide an experiment name if you want to save the data."))
    end

    folder = verify_experiment_name(experiment_name)

    # Load the dataset
    data = load_dataset(dataset, N_days=N_days)

    # Pre-process the data (partitions, actions and actors)
    df = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    influence_graphs, influence_cascades = observe(df, pipeline)

    if save
        save_data(influence_graphs, influence_cascades, df, folder * "data.jld2")
        log_experiment(dataset, agents, pipeline, folder * "experiment.yml")
    end

    return influence_graphs, influence_cascades

end


"""
Run multiple experiments and log all results.
"""
function run_experiment(dataset::Type{<:Dataset}, agents::PreProcessingAgents, pipelines::Vector{Pipeline}; N_days::Int = 13, save::Bool = true, experiment_name = nothing,
    keep_bar::Bool = false)

    if save && isnothing(experiment_name)
        throw(ArgumentError("You must provide an experiment name if you want to save the data."))
    end

    folder = verify_experiment_name(experiment_name)

    # Load the dataset
    data = load_dataset(dataset, N_days=N_days)

    # Pre-process the data (partitions, actions and actors)
    df = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    # Note that most (all) of the time the difference between pipelines will be for graph creation, thus
    # we will recompute the same time-series each time. However, the time needed is negligible compared to creating the graphs
    multiple_influence_graphs = Vector{InfluenceGraphs}(undef, length(pipelines))
    multiple_influence_cascades = Vector{InfluenceCascades}(undef, length(pipelines))
    for (i, pipeline) in ProgressBar(enumerate(pipelines), "Experiment", leave=keep_bar)
        influence_graphs, influence_cascades = observe(df, pipeline)
        multiple_influence_graphs[i] = influence_graphs
        multiple_influence_cascades[i] = influence_cascades
    end

    if save
        save_data(multiple_influence_graphs, multiple_influence_cascades, df, folder * "data.jld2")
        log_experiment(dataset, agents, pipelines, folder * "experiment.yml")
    end

    return multiple_influence_graphs, multiple_influence_cascades

end


"""
Run a single experiment on only one of the partitions. This is used as a "last resort" to reduce running time for very long computations (compute each partition on a 
different machine).
"""
function run_experiment(dataset::Type{<:Dataset}, partition::AbstractString, agents::PreProcessingAgents, pipeline::Pipeline; N_days::Int = 13, save::Bool = true, experiment_name = nothing)

    if save && isnothing(experiment_name)
        throw(ArgumentError("You must provide an experiment name if you want to save the data."))
    end

    folder = verify_experiment_name(experiment_name)

    # Load the dataset
    data = load_dataset(dataset, N_days=N_days)

    # Pre-process the data (partitions, actions and actors)
    df = preprocessing(data, agents)
    partitions, _, _ = partitions_actions_actors(df)

    if !(partition in partitions)
        throw(ArgumentError("The partition you want does not exist. It must be one of $partitions."))
    end

    # Select only one partition
    df = df[df.partition .== partition, :]

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    influence_graphs, influence_cascades = observe(df, pipeline)

    if save
        save_data(influence_graphs, influence_cascades, df, folder * "data.jld2")
        log_experiment(dataset, agents, pipeline, folder * "experiment.yml")
    end

    return influence_graphs, influence_cascades

end



"""
Provide a constructor to easily set the description of the bar (this is lacking in the original package).
Note: this cannot be an optional argument in order to overload the constructor.
"""
function ProgressBar(wrapped::Any, description::AbstractString; leave::Bool = true)
    bar = ProgressBar(wrapped, leave=leave)
    bar.description = description
    return bar
end



"""
Format and verify the validity of the experiment name to avoid overwriting existing data.
"""
function verify_experiment_name(experiment_name)

    if experiment_name[end] != '/'
        experiment_name *= '/'
    end

    experiment_folder = RESULT_FOLDER * '/' * experiment_name
    if isdir(experiment_folder) && length(readdir(experiment_folder)) > 0
        throw(ArgumentError("This experiment name is already taken. Please choose another one."))
    else
        # Create the directory
        mkpath(experiment_folder)
    end
    return experiment_folder
end



end # module