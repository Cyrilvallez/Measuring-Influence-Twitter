include("../InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")
using DataFrames

mutable struct CascadeClusterer  <: Sensor
    embed
    cluster
end

function naive_embedding(ic::InfluenceCascade; cuttoff=1.0)
    lens = [sum(l.>cuttoff) for l in mean(ic)]
    out = zeros(8)
    out[1:min(8,length(lens))] = lens[1:min(8,length(lens))]
    return out
end

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

function observe(x::Vector{InfluenceCascade}, cc::CascadeClusterer)
    vecs = cc.embed.(x)
    clusters = cc.cluster(vecs)
    return clusters
end

