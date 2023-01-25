module Helpers

using DataFrames, DataStructures, Dates
using StatsBase: sample
import JSON, JLD2, YAML
import Random

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Sensors, ..PreProcessing

export load_dataset, make_simplifier, partitions_actions_actors, save_data, load_data, log_experiment
export Dataset, COP26, COP27, Skripal, RandomDays


DATA_FOLDER = PreProcessing.PROJECT_FOLDER * "/Data/"

# Those will be used in an "enum" fashion for dispatch (they do not hold any
# fields, only their name are used)
abstract type Dataset end
struct COP26 <: Dataset end
struct COP27 <: Dataset end
struct Skripal <: Dataset end
struct RandomDays <: Dataset end


"""
Conveniently load a file containing lines of json objects into a DataFrame (or as a list of dictionaries).
"""
function load_json(filename::String; to_df::Bool = true, skiprows::Int = 0)

    lines = readlines(filename)
    dics = [JSON.parse(line, null=missing) for line in lines[(skiprows+1):end]]

    # Convert dates to datetime
    if "created_at" in keys(dics[1]) && typeof(dics[1]["created_at"]) <: AbstractString
        to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
        for dic in dics
            dic["created_at"] = to_datetime(dic["created_at"])
        end
    end

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
        datafolder = DATA_FOLDER * "Twitter/COP26_processed_lightweight/"
    elseif T == COP27
        datafolder = DATA_FOLDER * "Twitter/COP27_processed_lightweight/"
    elseif T == RandomDays 
        datafolder = DATA_FOLDER * "Twitter/Random_days_processed_lightweight/"
    end

    if T == Skripal
        datafiles = [DATA_FOLDER * "BrandWatch/Skripal/skripal_clean_lightweight.json"]
    else
        datafiles = [file for file in readdir(datafolder, join=true) if occursin(".json", file)]
    end

    # Select only a few days randomly
    if T == RandomDays
        Random.seed!(1234)
        indices = sample(1:length(datafiles), N_days, replace=false)
        sort!(indices)
        datafiles = datafiles[indices]
    end

    frames = [load_json(file) for file in datafiles]
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
function make_simplifier(edge_type::String, cuttoff::Real, actions::Vector{String})

    actions = sort(actions)

    edge_types = Matrix{String}(undef, length(actions), length(actions))
    for (i, a1) in enumerate(actions), (j, a2) in enumerate(actions)
        edge_types[i,j] = string(a1, " to ", a2)
    end

    if !(edge_type in edge_types) && edge_type != "Any Edge"
        throw(ArgumentError("The `edge_type` provided is not valid. It should be one of $edge_types, or \"Any Edge\"."))
    end

    if edge_type == "Any Edge"
        return x -> (maximum(x) > cuttoff)
    else
        idx = findfirst(edge_type .== edge_types)
        return x -> (x[idx] > cuttoff)
    end
end



"""
Return the partitions, actions and actors in the correct order as they appear in the indexing of the graphs matrices.
"""
function partitions_actions_actors(df::DataFrame)

    partitions = sort(unique(df.partition))
    actions = sort(unique(df.action))
    actors = [sort(unique(df[df.partition .== partition, "actor"])) for partition in partitions]

    return partitions, actions, actors

end



"""
Format and check validity of a filename and extension. Create path if it does not exist.
"""
function verify_filename(filename::AbstractString, extension::AbstractString)
    final_part = basename(filename)
    if final_part == ""
        throw(ArgumentError("The basename cannot be empty."))
    end
    split_on_dot = split(final_part, '.')

    if length(split_on_dot) == 1
        filename *= '.' * extension
    elseif length(split_on_dot) == 2
        if split_on_dot[2] != extension
            filename = dirname(filename) * '/' * split_on_dot[1] * '.' * extension
        end
    # In this case, throw an error
    else
        throw(ArgumentError("The basename in the filename cannot contain any `.` except for the extension."))
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
Easily save the influences graphs and cascades, and the dataframe associated.
"""
function save_data(influence_graphs::InfluenceGraphs, influence_cascades::InfluenceCascades, df::DataFrame,
     filename::AbstractString; extension::AbstractString = "jld2")
   data = Dict("influence_graphs" => influence_graphs, "influence_cascades" => influence_cascades, "data" => df)
   save_data(data, filename, extension=extension)
end



"""
Easily save a collection of influences graphs and cascades, and the dataframe associated.
"""
function save_data(multiple_influence_graphs::Vector{InfluenceGraphs}, multiple_influence_cascades::Vector{InfluenceCascades}, df::DataFrame,
     filename::AbstractString; extension::AbstractString = "jld2")
   data = Dict("multiple_influence_graphs" => multiple_influence_graphs, "multiple_influence_cascades" => multiple_influence_cascades, "data" => df)
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
    elseif typeof(data) <: AbstractDict && sort(collect(keys(data))) == ["data", "influence_cascades", "influence_graphs"]
        return data["influence_graphs"], data["influence_cascades"], data["data"]
    elseif typeof(data) <: AbstractDict && sort(collect(keys(data))) == ["data", "multiple_influence_cascades", "multiple_influence_graphs"]
        return data["multiple_influence_graphs"], data["multiple_influence_cascades"], data["data"]
    else
        return data
    end
end



"""
Log the parameters used for an experiment.
"""
function log_experiment(dataset::Type{<:Dataset}, agents::PreProcessingAgents, pipeline::Pipeline, filename::AbstractString; extension::AbstractString = "yml", dump::Bool = true)

    if dump
        filename = verify_filename(filename, extension)
    end
    dic = OrderedDict()

    dic["Dataset"] = string(dataset)
    dic["Preprocessing"] = OrderedDict()
    dic["Time_series"] = OrderedDict()
    dic["Graphs"] = OrderedDict()
    dic["Influence_cascades"] = OrderedDict()

    dic["Preprocessing"]["partition"] = string(agents.partition_function)
    dic["Preprocessing"]["action"] = string(agents.action_function)
    if agents.actors_parameters == ""
        dic["Preprocessing"]["actor"] = string(agents.actor_function)
    else
        dic["Preprocessing"]["actor"] = agents.actor_parameters
    end

    dic["Time_series"]["time_resolution"] = pipeline.time_series_generator.time_interval
    dic["Time_series"]["standardize"] = pipeline.time_series_generator.standardize

    dic["Graphs"] = pipeline.influence_graph_generator.parameters

    dic["Influence_cascades"]["cuttoff"] = pipeline.influence_cascade_generator.cuttoff
    dic["Influence_cascades"]["normalize"] = pipeline.influence_cascade_generator.normalize

    if dump
        YAML.write_file(filename, dic)
    end

    return dic

end



"""
Log the parameters used for different experiments.
"""
function log_experiment(dataset::Type{<:Dataset}, agents::PreProcessingAgents, pipelines::Vector{Pipeline}, filename::AbstractString; extension::AbstractString = "yml", dump::Bool = true)

    if dump
        filename = verify_filename(filename, extension)
    end
    dic = OrderedDict()

    for (i, pipeline) in enumerate(pipelines)
        partial_log = log_experiment(dataset, agents, pipeline, filename, extension=extension, dump=false)
        # In the first iteration, save dataset and preprocessing part
        if i == 1
            dic["Dataset"] = partial_log["Dataset"]
            dic["Preprocessing"] = partial_log["Preprocessing"]
        end
        # After, save the log without the dataset and preprocessing part
        delete!(partial_log, "Dataset")
        delete!(partial_log, "Preprocessing")
        dic["Run $i"] = partial_log
    end

    if dump
        YAML.write_file(filename, dic)
    end

    return dic

end



end # module