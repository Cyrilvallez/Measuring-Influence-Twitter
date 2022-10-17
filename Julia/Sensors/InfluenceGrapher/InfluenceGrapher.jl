using DataFrames
using TimeSeries
using IterTools: product

#using CausalityTools
include("../../entropy.jl")


mutable struct InfluenceGrapher  <: Sensor
    # premise is that each sensor instantiation will be designed to 
    # split itself by some action definition and actor definition
    # the partition is assumed to be already given (eg, by narrative)
    transfer_entropy
    actiontypes::Vector{String}
end


function InfluenceGrapher(actiontypes::Vector{String})
    #InfluenceGrapher((x,y)->transferentropy(x,y, Kraskov()), cuttoff, actiontypes)
    InfluenceGrapher(TE, actiontypes)
end

function observe(data, ig::InfluenceGrapher)
    adjacencies = Vector{Matrix{Matrix}}()
    adj = fill(0.0, length(ig.actiontypes), length(ig.actiontypes))
    for part in data
        partitionwise_adjecency = Matrix{Matrix}(undef, length(part), length(part))
        for i in eachindex(part), j in eachindex(part)
            adj .= 0 
            if i ≠ j
                for initial in colnames(part[i]), final in colnames(part[j])
                    tr_en = ig.transfer_entropy(Int.(values(part[i][Symbol(initial)]) .> 0), Int.(values(part[j][Symbol(final)]) .> 0))
                    adj[indexin([String(initial)], ig.actiontypes), indexin([String(final)], ig.actiontypes)] .= isnan(tr_en) ? 0 : tr_en
                end
            end
            partitionwise_adjecency[i,j] = copy(adj)
        end
        push!(adjacencies, partitionwise_adjecency)
    end

    return adjacencies
end


function print_graph(adj::Matrix{Matrix}; simplifier = x->(maximum(x)>0.75))
    a = simplifier.(adj)
    g = SimpleDiGraph(a)
    gplot(g)
    return g
end

function influence_layout(adj; simplifier = x->(maximum(x)>0.75))
    graph = simplifier.(adj)
    num_nodes = size(graph)[1]
    influencers = fill(false, num_nodes)
    no_influence = fill(false, num_nodes)
    x_pos = zeros(num_nodes)
    y_pos = zeros(num_nodes)
    for (i,v) in enumerate(eachcol(graph))
        if sum(v)==0
            influencers[i] = true
        end
    end
    for (i,v) in enumerate(eachrow(graph))
        if sum(v)==0
            no_influence[i] = true
        end
    end
    sources = influencers .&& .!no_influence
    if sum(sources)>0
        x_pos[sources] .= sum(sources)>1 ? range(-1,1,sum(sources)) : 0
        y_pos[sources] .= -1
    end
    empties = influencers .&& no_influence
    if sum(empties)>0
        x_pos[empties] .= sum(empties)>1 ? range(-1,1,sum(empties)) : 0
        y_pos[empties] .= 1
    end
    sinks   = .!influencers .&& no_influence
    if sum(sinks)>0
        x_pos[sinks] .= sum(sinks)>1 ? range(-1,1,sum(sinks)) : 0
        y_pos[sinks] .= 0.8
    end
    middle  = .!influencers .&& .!no_influence
    if sum(middle)>=2
        θ = range(0,2*π,sum(middle)+1)[1:(end-1)]
        y_pos[middle] = cos.(θ).*0.5
        x_pos[middle] = sin.(θ)
    elseif sum(middle)==1
        y_pos[middle] .= 0
        x_pos[middle] .= 0
    end

    return x_pos, y_pos, (1:length(x_pos))[influencers.&& .~no_influence]
end

#function print_edges()






