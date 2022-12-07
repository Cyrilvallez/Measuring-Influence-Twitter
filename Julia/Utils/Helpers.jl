module Helpers

using DataFrames
import JSON, JLD2

export load_json, make_simplifier, save_data, load_data

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


"""
Conveniently store data to file (using hdf5 variant for julia).
"""
function save_data(data, filename::AbstractString; extension::AbstractString = "jld2")
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

    JLD2.save(filename, "data", data)
end


"""
Conveniently load data from file.
"""
function load_data(filename::AbstractString)
    return JLD2.load(filename)["data"]
end


end # module