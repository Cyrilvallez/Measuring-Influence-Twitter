using Dates
import PlotlyJS

include("Sensors/Sensors.jl")
include("PreProcessing/PreProcessing.jl")
include("Utils/Helpers.jl")
include("Utils/Visualizations.jl")
using .Sensors, .PreProcessing, .Visualizations, .Helpers


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


function run(data::DataFrame, agents::PreProcessingAgents, pipeline::Pipeline)

    # Pre-process the data (partitions, actions and actors)
    df, partitions, actions, actors = preprocessing(data, agents)

    # Performs all computations (create time-series, compute graphs, compute influence cascades)
    influence_graphs, influence_cascades = observe(df, pipeline)

    edge_types = [string(n1, " to ", n2) for n1 in actions for n2 in actions]
    push!(edge_types, "Any Edge") 
    partition = "During COP26"
    edge = "Any Edge"

    simplifier = make_simplifier(edge, pipeline.influence_cascade_generator.cuttoff, edge_types)
    partition_index = (1:length(partitions))[findfirst(partition .== partitions)]

end