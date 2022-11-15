module Helpers

using DataFrames
import JSON

export load_json, make_simplifier

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


end # module