module Helpers

using DataFrames, DataStructures, Dates
using StatsBase: sample
import JSON, JLD2, YAML
import Random

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Sensors, ..PreProcessing

export load_dataset, make_simplifier, save_data, load_data, log_experiment
export COP26, COP27, RandomDays


DATA_FOLDER = PreProcessing.PROJECT_FOLDER * "/Data/Twitter"

# Those will be used in an "enum" fashion for dispatch (they do not hold any
# fields, only their name are used)
abstract type Dataset end
struct COP26 <: Dataset end
struct COP27 <: Dataset end
struct RandomDays <: Dataset end


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
Easily load a dataset from disk into a DataFrame.
"""
function load_dataset(::Type{T}; N_days::Int = 13) where T <: Dataset

    if T == COP26
        datafolder = DATA_FOLDER * "/COP26_processed_lightweight/"
    elseif T == COP27
        datafolder = DATA_FOLDER * "/COP27_processed_lightweight/"
    elseif T == RandomDays 
        datafolder = DATA_FOLDER * "/Random_days_processed_lightweight/"
    end

    datafiles = [file for file in readdir(datafolder) if occursin(".json", file)]

    # Select only a few days randomly
    if T == RandomDays
        Random.seed!(1234)
        indices = sample(1:length(datafiles), N_days, replace=false)
        sort!(indices)
        datafiles = datafiles[indices]
    end

    frames = [load_json(datafolder * file) for file in datafiles]
    data = vcat(frames...)

    # Artificially change the days 
    if T == RandomDays
        process_random_dataset!(data)
    end

    return data

end



"""
Change the days of the random day dataset so that they are artificially consecutive.
"""
function process_random_dataset!(data::DataFrame)

    # Convert string dates to datetimes 
    to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
    data."created_at" = to_datetime.(data."created_at")

    # Shift the random days in the data so that they are consecutive (but we don't touch the time part)
    days = Date.(data.created_at)
    unique_days = sort(unique(days))
    proxy_dates = Vector{DateTime}(undef, length(data.created_at))
    current_day = minimum(unique_days)

    for day in unique_days
        indices = findall(days .== day)
        for ind in indices
            proxy_dates[ind] = DateTime(current_day, Time(data.created_at[ind]))
        end
        current_day += Day(1)
    end

    data.created_at = proxy_dates

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



"""
Format and check validity of a filename and extension. Create path if it does not exist.
"""
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



"""
Log the parameters used for different experiments.
"""
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