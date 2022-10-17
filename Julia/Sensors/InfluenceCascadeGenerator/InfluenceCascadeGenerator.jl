using DataStructures
using Graphs, GraphPlot
using PlotlyBase

mutable struct InfluenceCascadeGenerator  <: Sensor
    simplifier   
end

function InfluenceCascadeGenerator(;cuttoff=.5)
    InfluenceCascadeGenerator(cuttoff)
end


mutable struct InfluenceActor
    source::Int
    sinks::Vector{Int}
    edge_weights::Vector{Matrix}
end

mutable struct InfluenceCascade
    nodes::Dict{Int, Dict{Int, Matrix}}
    start_node::Int
end

function InfluenceCascade(start)
    InfluenceCascade(Dict{Int, Dict{Int, Matrix}}(), start)
end

function InfluenceCascade(start_node::InfluenceActor)
    n = Dict(start_node.source => Dict(start_node.sinks .=> start_node.edge_weights))
    InfluenceCascade(n, start_node.source)
end

import Base: firstindex, getindex, push!, setindex!, length
function getindex(X::InfluenceCascade, i::Int)
    return X.nodes[i]
end
function getindex(X::InfluenceCascade, is::Vector{Int})
    return [X.nodes[i] for i in is]
end
function getindex(X::InfluenceCascade, i::InfluenceActor)
    return X.nodes[i.source]
end
function firstindex(X::InfluenceCascade)
    return X.start_node
end
function push!(X::InfluenceCascade, a::InfluenceActor)
    X[a.source] = a
end
function push!(X::InfluenceCascade, as::Vector{InfluenceActor})
    X[[i.source for i in as]] = as
end
function push!(X::InfluenceCascade, a::Nothing)
end
function setindex!(X::InfluenceCascade, a::InfluenceActor, i::Int)
    X.nodes[i] = Dict(a.sinks .=> a.edge_weights)
end
function setindex!(X::InfluenceCascade, as::Vector{InfluenceActor}, is::Vector{Int})
    for i in is
        X.nodes[i] = Dict(as[i].sinks .=> as[i].edge_weights)
    end
end
#function length(X::InfluenceCascade)
#    return length(X.nodes)
#end
function nodes(X::InfluenceCascade)
    return keys(X.nodes)
end
function mean(X::InfluenceCascade)
    layers = 0
    layer_weight_avg = []

    avail_nodes = nodes(X) |> x->Dict(x .=> x)
    current_nodes = [X.start_node]

    for i in eachindex(X.nodes)
        next_nodes = []
        layers += 1
        for n in current_nodes
            push!(layer_weight_avg, length(X[n])>0 ? sum(values(X[n]))./length(X[n]) : zeros(size(sum(values(X[n])))))
            append!(next_nodes, keys(X[n]))
            pop!(avail_nodes, n)
        end
        if length(avail_nodes)==0
            break
        else
            current_nodes = keys(avail_nodes)
        end
    end
    return layer_weight_avg#, layers
end
function mean(X::Vector{InfluenceCascade})
    ms = mean.(X)
    len = maximum(length.(ms))
    avg_layers = []
    for layer in 1:len
        total = zeros(size(ms[1][1]))
        count = 0
        for ic in ms
            if length(ic)>=layer && length(ic[layer])>0
                total += ic[layer]
                count += 1
            end
        end
        push!(avg_layers, total ./ count)
    end
    return avg_layers
end
function layers(X::InfluenceCascade)
    avail = copy(X.nodes)
    current = [X.start_node]
    layer = [current]
    while length(avail)>0
        current = vcat(collect.(keys.(pop!.(Ref(avail),current)))...)
        push!(layer, current)
        current = current[findall(in(collect(keys(avail))), current)]
    end
    return layer
end

function observe(data, icg::InfluenceCascadeGenerator)
    influencers = Vector{Int}() # CHANGE -> influence_sources
    for (j,sink) in enumerate(eachcol(data))
        indegree = 0
        for source in sink
            indegree += sum(icg.simplifier(source))
        end
        if indegree==0
            append!(influencers,j)
        end
    end

    influence_cascades = Vector{InfluenceCascade}()
    for influencer in influencers
        # BFS through influence graph
        available_nodes = (1:size(data,1))[Not(influencer)]
        fringe = Queue{Int}()
        current = influencer
        cascade_tree = InfluenceCascade(current)
        while (length(available_nodes)>0)
            push!(cascade_tree, get_node!(current, available_nodes, data, icg, fringe))
            if isempty(fringe)
                break
            end
            current = dequeue!(fringe)
        end
        push!(influence_cascades, cascade_tree)
    end
    return influence_cascades
end

function get_node!(current, available_nodes, adj, icg, fringe)

    idx_positive_edges = icg.simplifier.(adj[current, available_nodes])
    neighbor_edges = adj[current, available_nodes[idx_positive_edges]]
    neighbors = []

    new_fringe_idx = (1:length(available_nodes))[idx_positive_edges]
    append!(neighbors, available_nodes[new_fringe_idx])
    deleteat!(available_nodes, new_fringe_idx)
    
    for neighbor in neighbors
        enqueue!(fringe, neighbor)
    end
    if length(neighbors)>0
        return InfluenceActor(current, neighbors, neighbor_edges)
    end
    return nothing
end

function plot_cascade(influence_cascade::InfluenceCascade, actions, num_actions, cuttoff, color_range)
    g, edge_labels = get_cascade_graph(influence_cascade, num_actions; cuttoff=cuttoff)
	xs, ys = cascade_layout(g, num_actions)
	nl = Vector{String}(undef, length(xs))
	ncolor = Vector{Any}(undef, length(xs))

	for i in eachindex(actions)
		nl[i:num_actions:end] .= actions[i]
		ncolor[i:num_actions:end] .= color_range[i]
	end
	gplot(g, xs, ys, nodelabel=nl, edgelabel=round.(edge_labels;digits=3), nodefillc=ncolor)
end


# This is the old version where nodes are not aligned at each level of the cascade
#=
function plot_cascade_sankey(influence_cascade::InfluenceCascade, actions, cuttoff)
    # Bank of color because PlutoPlotly does not support the `colorant"blue"` colors in
    # Pluto notebooks
    color_bank = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b",
     "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]

    layers = mean(influence_cascade)
    num_actions = length(actions)

    labels = repeat(actions, length(layers)+1)
    colors = repeat(color_bank[1:num_actions], length(layers)+1)
    levels = vcat([[i for j = 1:num_actions] for i = 0:length(layers)]...)
    sources = []
    targets = []
    values = []

    for (layer_idx, layer) in enumerate(layers)
        if sum(layer .> cuttoff) == 0
            break
        end
        for i in 1:size(layer)[1], j in 1:size(layer)[2]
            if layer[i,j]>cuttoff
                # We need the last -1 because Plotly starts indexing at 0 instead
                # of 1 (which contradicts Julia)
                push!(sources, num_actions*(layer_idx-1)+i-1)
                push!(targets, num_actions*layer_idx+j-1)
                push!(values, layer[i,j])
            end
        end
    end

    fig = sankey(
        node = attr(
          pad = 15,
          thickness = 20,
          line = attr(color = "black", width = 0.5),
          label = labels,
          color = colors,
          customdata = levels,
          hovertemplate = "%{label} on level %{customdata}"
        ),
        link = attr(
          source = sources,
          target = targets,
          value = values,
          hovertemplate = "source : %{source.label} on level %{source.customdata} \
          <br />target : %{target.label} on level %{target.customdata}"
        ))
    layout = Layout(title_text="Influence cascade", font_size=10)

    return fig, layout
        
end
=#

function plot_cascade_sankey(influence_cascade::InfluenceCascade, actions, cuttoff)
    # Bank of color because PlutoPlotly does not support the `colorant"blue"` colors in
    # Pluto notebooks
    color_bank = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b",
     "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]

    layers = mean(influence_cascade)
    N_actions = length(actions)

    sources = []
    targets = []
    values = []

    N_layers = 0
    for (layer_idx, layer) in enumerate(layers)
        if sum(layer .> cuttoff) == 0
            N_layers = layer_idx - 1
            break
        end
        for i in 1:size(layer)[1], j in 1:size(layer)[2]
            if layer[i,j]>cuttoff
                # We need the last -1 because Plotly starts indexing at 0 instead
                # of 1 (which contradicts Julia)
                push!(sources, N_actions*(layer_idx-1)+i-1)
                push!(targets, N_actions*layer_idx+j-1)
                push!(values, layer[i,j])
            end
        end
        N_layers = layer_idx
    end

    labels = repeat(actions, N_layers+1)
    colors = repeat(color_bank[1:N_actions], N_layers+1)
    levels = vcat([[i for j = 1:N_actions] for i = 0:N_layers]...)

    # We plot between 0.01 and 0.99 in x because 0 and 1 are forbidden values
    dx = 0.98/N_layers
    x = vcat([[i*dx + 0.01 for j in 1:N_actions] for i = 0:N_layers]...)

    # Removes unused nodes so that the layout is correct when specifying x and y positions
    new_labels = []
    new_colors = []
    new_levels = []
    new_x = []
    old_sources = copy(sources)
    old_targets = copy(targets)

    # i is the indices as interpreted by plotly, i.e they start at 0 instead of 1
    for i in range(0, length(labels)-1)
        if (i in old_sources) || (i in old_targets)
            push!(new_labels, labels[i+1])
            push!(new_colors, colors[i+1])
            push!(new_levels, levels[i+1])
            push!(new_x, x[i+1])
        else
            sources[old_sources.>i] .-= 1
            targets[old_targets.>i] .-= 1
        end
    end

    fig = sankey(
        arrangement = "snap",
        node = attr(
          pad = 15,
          thickness = 20,
          line = attr(color = "black", width = 0.5),
          label = new_labels,
          color = new_colors,
          x = new_x,
          # Fake y because only specifying x does not work for some reason
          y = [0.1 for i = 1:length(new_labels)],
          customdata = new_levels,
          hovertemplate = "%{label} on level %{customdata}"
        ),
        link = attr(
          source = sources,
          target = targets,
          value = values,
          hovertemplate = "source : %{source.label} on level %{source.customdata} \
          <br />target : %{target.label} on level %{target.customdata}"
        ))
    layout = Layout(title_text="Influence cascade", font_size=10)

    return fig, layout
        
end


function get_cascade_graph(ic::InfluenceCascade, num_actions; cuttoff=0.5)
    layer = mean(ic)
    labels = []
    g = DiGraph(num_actions)
    for (layer_num,l) in enumerate(layer)
		if sum(l.>cuttoff)>0
            for k = 1:num_actions
			    add_vertex!(g)
			end
		else
			break
		end
        for i in 1:size(l)[1], j in 1:size(l)[2]
            if l[i,j]>cuttoff
                add_edge!(g, num_actions*layer_num+i-num_actions, num_actions*layer_num+j)
                push!(labels, l[i,j])
            end
        end
    end
    return g, labels
end

function cascade_layout(graph, num_actions)
    x_pos = zeros(nv(graph))
    y_pos = zeros(nv(graph))

    y_step = nv(graph)>num_actions ? 2*num_actions/(nv(graph)-num_actions) : 0
    x_step = num_actions>1 ? 2/(num_actions-1) : 0
    for i in 1:num_actions
        x_pos[i:num_actions:end] .= 1-x_step*i
        y_pos[i:num_actions:end]  = y_step>0 ? -1 .+(0:y_step:2) : [0]
    end

    return x_pos, y_pos
end



