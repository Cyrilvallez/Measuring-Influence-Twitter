include("../InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")
using DataFrames
using Clustering

struct CascadeClusterer  
    embed
    cluster
end

#=
function naive_embedding(ic::InfluenceCascade; cuttoff=1.0)
    lens = [sum(l.>cuttoff) for l in mean(ic)]
    out = zeros(8)
    out[1:min(8,length(lens))] = lens[1:min(8,length(lens))]
    return out
end
=#

# This is supposed to mimic the old version 
function naive_embedding(ic::InfluenceCascade; cuttoff=1.0)
    lens = [sum(l .> cuttoff) for l in values(ic.cascade)]
    out = zeros(8)
    out[1:min(8,length(lens))] = lens[1:min(8,length(lens))]
    return out
end

#=
function stupid_embedding(ic::InfluenceCascade)
    layer = layers(ic)
    layer_lens = zeros(7)
    for i in eachindex(layer[2:end])
        if length(layer)<i
            break
        end
        layer_lens[i] = length(layer[i+1])
    end

    return layer_lens
end
=#

# This is supposed to mimic the old version 
function stupid_embedding(ic::InfluenceCascade; cuttoff=1)
    layer_lens = zeros(7)
    for (i, val) in enumerate(ic.actors_per_level[2:end])
        layer_lens[i] = val
    end
    return layer_lens
end



function observe(x::Vector{InfluenceCascade}, cc::CascadeClusterer)
    vecs = cc.embed.(x)
    clusters = cc.cluster(vecs)
    return clusters
end


## Cascade Clustering Methods
begin
	function dbscan_clusterer(x; eps=0.005, minpts=10)
		x = transpose(reshape(vcat(transpose.(x)...),(length(x), length(x[1]))))
		return [c.core_indices for c in Clustering.dbscan(x, eps, min_cluster_size=minpts)]
	end
end

