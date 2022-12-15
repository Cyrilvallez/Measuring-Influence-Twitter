module Helpers

using DataFrames, DataStructures
import JSON, JLD2, YAML

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Sensors, ..PreProcessing

export load_json, make_simplifier, save_data, load_data, log_experiment

"""
Conveniently load a file containing lines of json objects into a DataFrame (or as a list of dictionaries).
"""
function load_json(filename::String, to_df::Bool = true, skiprows::Int = 0)

    lines = readlines(filename)
    dics = [JSON.parse(line, null=missing) for line in lines[(skiprows+1):end]]

    if to_df
        return DataFrame(dics)
    else
        return dics
    end
end


"""
Return a function deciding how to select indices of an edge matrix corresponding to the edge we are interested in.
"""
function make_simplifier(edge_type::String, cuttoff::Float64, edge_types::Vector{String})
    if !(edge_type in edge_types)
        throw(ArgumentError("The edge you want is not present in the edge matrix."))
    end
    if edge_type == "Any Edge"
        return x -> (maximum(x) > cuttoff)
    else
        linear_idx = findfirst(edge_type .== edge_types)
        # edge_types is the size of the edge matrix + 1
        N = round(Int, sqrt(length(edge_types)-1))
        matrix_idx_1 = linear_idx ÷ N + 1
        matrix_idx_2 = linear_idx % N
        return x -> (x[matrix_idx_1, matrix_idx_2] > cuttoff)
    end
end


function verify_filename(filename::AbstractString, extension::AbstractString)
    split_on_dot = split(filename, '.')

    if length(split_on_dot) == 1
        filename *= '.' * extension
    elseif length(split_on_dot) == 2
        if split_on_dot[2] != extension
            filename = split_on_dot[1] * '.' * extension
        end
    # In this case, throw an error
    else
        throw(ArgumentError("The filename cannot contain any `.` except for the extension."))
    end

    # Create path if it does not already exist
    mkpath(dirname(filename))

    return filename

end

"""
Conveniently store data to file (using hdf5 variant for julia).
"""
function save_data(data, filename::AbstractString; extension::AbstractString = "jld2")
    filename = verify_filename(filename, extension)
    JLD2.save(filename, "data", data)
end


"""
Easily save the influences graphs and cascades.
"""
function save_data(influence_graphs::InfluenceGraphs, influence_cascades::InfluenceCascades,
    filename::AbstractString; extension::AbstractString = "jld2")
   data = Dict("influence_graphs" => influence_graphs, "influence_cascades" => influence_cascades)
   save_data(data, filename, extension=extension)
end


"""
Easily save the influences graphs and cascades, and the preprocessing agents and pipeline used to generate them.
"""
function save_data(influence_graphs::InfluenceGraphs, influence_cascades::InfluenceCascades, agents::PreProcessingAgents,
    pipeline::Pipeline, filename::AbstractString; extension::AbstractString = "jld2")
   data = Dict("influence_graphs" => influence_graphs, "influence_cascades" => influence_cascades, "agents" => agents, "pipeline" => pipeline)
   save_data(data, filename, extension=extension)
end


"""
Easily save a collection of influences graphs and cascades, and the preprocessing agents and multiple pipelines used to generate them.
"""
function save_data(multiple_influence_graphs::Vector{InfluenceGraphs}, multiple_influence_cascades::Vector{InfluenceCascades}, agents::PreProcessingAgents,
    pipelines::Vector{Pipeline}, filename::AbstractString; extension::AbstractString = "jld2")
   data = Dict("multiple_influence_graphs" => multiple_influence_graphs, "multiple_influence_cascades" => multiple_influence_cascades, "agents" => agents, "multiple_pipeline" => pipelines)
   save_data(data, filename, extension=extension)
end


"""
Conveniently load data from file.
"""
function load_data(filename::AbstractString)
    data = JLD2.load(filename)["data"]
    # Check if this was saved as a Dict containing influence results
    if typeof(data) <: AbstractDict && sort(collect(keys(data))) == ["influence_cascades", "influence_graphs"]
        return data["influence_graphs"], data["influence_cascades"]
    elseif typeof(data) <: AbstractDict && sort(collect(keys(data))) == ["agents", "influence_cascades", "influence_graphs", "pipeline"]
        return data["influence_graphs"], data["influence_cascades"], data["agents"], data["pipeline"]
    elseif typeof(data) <: AbstractDict && sort(collect(keys(data))) == ["agents", "multiple_influence_cascades", "multiple_influence_graphs", "multiple_pipeline"]
        return data["multiple_influence_graphs"], data["multiple_influence_cascades"], data["agents"], data["multiple_pipeline"]
    else
        return data
    end
end


"""
Log the parameters used for an experiment.
"""
function log_experiment(agents::PreProcessingAgents, pipeline::Pipeline, filename::AbstractString; extension::AbstractString = "yml", dump::Bool = true)

    filename = verify_filename(filename, extension)
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

    if dump
        YAML.write_file(filename, dic)
    end

    return dic

end


function log_experiment(agents::PreProcessingAgents, pipelines::Vector{Pipeline}, filename::AbstractString; extension::AbstractString = "yml", dump::Bool = true)

    filename = verify_filename(filename, extension)
    dic = OrderedDict()

    for (i, pipeline) in enumerate(pipelines)
        dic["run $i"] = log_experiment(agents, pipeline, filename, extension=extension, dump=false)
    end

    if dump
        YAML.write_file(filename, dic)
    end

    return dic

end




end # module