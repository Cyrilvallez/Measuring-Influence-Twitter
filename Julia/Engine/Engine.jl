module Engine

using DataFrames
using Reexport

include("../Sensors/Sensors.jl")
include("../PreProcessing/PreProcessing.jl")
include("../Utils/Helpers.jl")
include("../Utils/Visualizations.jl")

# Load the modules and reexport them so that they are available when importing only Engine (this removes the need to include every file in the correct order)
@reexport using .Sensors, .PreProcessing, .Visualizations, .Helpers

export run_experiment

RESULT_FOLDER = PreProcessing.PROJECT_FOLDER * "/Results"


"""
Run a single experiment an log the results.
"""
function run_experiment(data::DataFrame, agents::PreProcessingAgents, pipeline::Pipeline; save::Bool = true, experiment_name = nothing)

    if save && isnothing(experiment_name)
        throw(ArgumentError("You must provide an experiment name if you want to save the data."))
    end

    folder = verify_experiment_name(experiment_name)

    # Pre-process the data (partitions, actions and actors)
    df, _, _, _ = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    influence_graphs, influence_cascades = observe(df, pipeline)

    if save
        save_data(influence_graphs, influence_cascades, agents, pipeline, folder * "data.jld2")
        log_experiment(agents, pipeline, folder * "experiment.yml")
    end

    return influence_graphs, influence_cascades

end


"""
Run multiple experiments and log all results.
"""
function run_experiment(data::DataFrame, agents::PreProcessingAgents, pipelines::Vector{Pipeline}; save::Bool = true, experiment_name = nothing)

    if save && isnothing(experiment_name)
        throw(ArgumentError("You must provide an experiment name if you want to save the data."))
    end

    folder = verify_experiment_name(experiment_name)

    # Pre-process the data (partitions, actions and actors)
    df, _, _, _ = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    # Note that most (all) of the time the difference between pipelines will be for graph creation, thus
    # we will recompute the same time-series each time. However, the time needed is negligible compared to creating the graphs
    multiple_influence_graphs = Vector{InfluenceGraphs}(undef, length(pipelines))
    multiple_influence_cascades = Vector{InfluenceCascades}(undef, length(pipelines))
    for (i, pipeline) in enumerate(pipelines)
        influence_graphs, influence_cascades = observe(df, pipeline)
        multiple_influence_graphs[i] = influence_graphs
        multiple_influence_cascades[i] = influence_cascades
    end

    if save
        save_data(multiple_influence_graphs, multiple_influence_cascades, agents, pipelines, folder * "data.jld2")
        log_experiment(agents, pipelines, folder * "experiment.yml")
    end

    return multiple_influence_graphs, multiple_influence_cascades

end


"""
Format and verify the validity of the experiment name to avoid overwriting existing data.
"""
function verify_experiment_name(experiment_name)

    if experiment_name[end] != '/'
        experiment_name *= '/'
    end

    experiment_folder = RESULT_FOLDER * '/' * experiment_name
    if isdir(experiment_folder)
        throw(ArgumentError("This experiment name is already taken. Please choose another one."))
    else
        # Create the directory
        mkpath(experiment_folder)
    end
    return experiment_folder
end


function dataset_description(df::DataFrame; save::Bool = false, save_folder::AbstractString = "../Results/")

    if save_folder[end] != '/'
        save_folder *= '/'
    end

    plot_names = ["actor_frequency.pdf", "action_frequency.pdf", "actor_wordcloud.svg"]
    filenames = save_folder .* plot_names
    effective_save = [save for i = 1:length(filenames)]

    if save == true
        for i = 1:length(filenames)
            if isfile(filenames[i])
                plot_name = uppercase(replace(split(plot_names[i], '.')[1], '_' => ' '))
                @warn "The plot of $plot_name will not be saved because this would overwrite it."
                effective_save[i] = false
            end
        end
    end

    plot_actor_frequency(df, save=effective_save[1], filename=filenames[1])
    plot_action_frequency(df, save=effective_save[2], filename=filenames[2])
    plot_actor_wordcloud(df, Nactor=300, save=effective_save[3], filename=filenames[3])

end


function result_analysis(influence_graphs::InfluenceGraphs, influence_cascades::InfluenceCascades, df::DataFrame,
    save::Bool = false, save_folder::AbstractString = "../Results/")

    if save_folder[end] != '/'
        save_folder *= '/'
    end

    plot_names = ["proportion_edges.pdf", "mean_actors_cascade"]
    filenames = save_folder .* plot_names
    effective_save = [save for i = 1:length(filenames)]

    if save == true
        for i = 1:length(filenames)
            if isfile(filenames[i])
                plot_name = uppercase(replace(split(plot_names[i], '.')[1], '_' => ' '))
                @warn "The plot of $plot_name will not be saved because this would overwrite it."
                effective_save[i] = false
            end
        end
    end

    plot_edge_types(influence_graphs, df, save=effective_save[1], filename=filenames[1])
    plot_actors_per_level(influence_cascades, df, save=effective_save[2], filename=filenames[2])

end


end # module