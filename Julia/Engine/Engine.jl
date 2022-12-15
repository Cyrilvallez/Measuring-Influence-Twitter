module Engine

using DataFrames, Dates, DataStructures
using Reexport
import YAML

include("../Sensors/Sensors.jl")
include("../PreProcessing/PreProcessing.jl")
include("../Utils/Helpers.jl")
include("../Utils/Visualizations.jl")

# Load the modules and reexport them so that they are available when importing only Engine (this removes the need to include every file in the correct order)
@reexport using .Sensors, .PreProcessing, .Visualizations, .Helpers

export run

function run(data::DataFrame, agents::PreProcessingAgents, pipeline::Pipeline, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the data."))
    end

    # Pre-process the data (partitions, actions and actors)
    df, partitions, actions, actors = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    influence_graphs, influence_cascades = observe(df, pipeline)

    if save
        save_data(influence_graphs, influence_cascades, agents, pipeline, filename)
    end

    return influence_graphs, influence_cascades

end


function log_experiment(agents::PreProcessingAgents, pipeline::Pipeline, filename::AbstractString)

    dic = OrderedDict()

    dic["preprocessing"] = OrderedDict()
    dic["time_series"] = OrderedDict()
    dic["graphs"] = OrderedDict()
    dic["influence_cascades"] = OrderedDict()

    dic["preprocessing"]["partition"] = string(agents.partition_function)
    dic["preprocessing"]["action"] = string(agents.action_function)
    dic["preprocessing"]["actor"] = string(agents.actor_function)

    dic["time_series"]["time_resolution"] = pipeline.time_series_generator.time_interval
    dic["time_series"]["standardize"] = pipeline.time_series_generator.standardize

    dic["graphs"] = pipeline.influence_graph_generator.parameters

    dic["influence_cascades"]["cuttoff"] = pipeline.influence_cascade_generator.cuttoff
    dic["influence_cascades"]["normalize"] = pipeline.influence_cascade_generator.normalize

    YAML.write_file(filename, dic)

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


function result_analysis(influence_graphs::Vector{Matrix{Matrix{Float64}}}, influence_cascades::Vector{Vector{InfluenceCascade}}, df::DataFrame,
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