using PlotlyBase
using Graphs, SimpleWeightedGraphs, GraphPlot
using Colors

#using CausalityTools
include("../../entropy.jl")


struct InfluenceGrapher 
    transfer_entropy::Function
end


# Default constructor without argument
function InfluenceGrapher()
    return InfluenceGrapher(TE)
end


"""
Construct the adjacencies matrices (one per partition) from the time series per partition.
"""
function observe(time_series::Vector{Vector{Matrix{Int}}}, ig::InfluenceGrapher)

    N_actions = size(time_series[1][1])[2]

    # Initialize final output
    adjacencies = Vector{Matrix{Matrix{Float64}}}(undef, length(time_series))

    # Iterate on partitions
    for (m, partition) in enumerate(time_series)

        # Initialize adjacency matrix for the partition
        partitionwise_adjacency = Matrix{Matrix{Float64}}(undef, length(partition), length(partition))

        # Iterate 2 times on all actors
        for i = 1:length(partition), j = 1:length(partition)

            # Initialize the transfer entropy matrix between 2 actors (which is an edge in the actor graph)
            edge_matrix = fill(0.0, N_actions, N_actions)

            if i != j
                # Iterate on actions of each actor i and j
                for k = 1:N_actions, l = 1:N_actions
                    # Compute transfer entropy between actor i and j and actions k and l
                    if ig.transfer_entropy == TE
                        tr_en = ig.transfer_entropy(Int.(partition[i][:, k] .> 0), Int.(partition[j][:, l] .> 0))
                    else
                        tr_en = ig.transfer_entropy(partition[i][:, k], partition[j][:, l])
                    end
                    edge_matrix[k, l] = isnan(tr_en) ? 0 : tr_en
                end
            end
            # cast it into the partition-wise adjacency matrix
            partitionwise_adjacency[i,j] = edge_matrix
        end
        # cast it in the total output vector
        adjacencies[m] = partitionwise_adjacency
    end

    return adjacencies
end



function plot_graph(adjacency::Matrix{Matrix{Float64}}, df::DataFrame; simplifier = x->(maximum(x)>0.75))

    # Actors are represented in the order they appear in unique(df."actor") in the adjacency matrix
    node_labels = unique(df."actor")

    # reduce the adjacency matrix containing edge matrices to simple adjacency matrix depending on which 
    # connection we are interested in in the edge matrices
    reduced_adjacency = simplifier.(adjacency)
    g = SimpleWeightedDiGraph(reduced_adjacency)
    # remove unconnected nodes from the drawing of the graph
    outdegrees = outdegree(g)
    indegrees = indegree(g)
    connected_vertices = [i for i in vertices(g) if (outdegrees[i] > 0 && indegrees[i] > 0)]
    connected_graph, vmap = induced_subgraph(g, connected_vertices)
    connected_vertices_labels = node_labels[vmap]
    # Plot only connected nodes
    #gplot(connected_graph, nodelabel=connected_vertices_labels, nodelabelc=colorant"white")
    return connected_graph, connected_vertices_labels

end

function influence_layout(adj::Matrix{Matrix}; simplifier = x->(maximum(x)>0.75))
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


function map_plot(df::DataFrame)

    iso_codes = unique(df.actor)
	indices = indexin(iso_codes, df.actor)
	countries = df."Country"[indices]
	traces = Vector{GenericTrace{Dict{Symbol, Any}}}()
		
	for (i, e) in enumerate(edges(g))
    	trace = PlotlyBase.scattergeo(  
	    	mode = "markers+lines",
	    	locations = [iso_codes[src(e)], iso_codes[dst(e)]],
	    	marker = PlotlyBase.attr(size = 8, color="blue"),
			line = PlotlyBase.attr(color="red", width=1),
			showlegend=false,
			name = "",
			hovertext = [countries[src(e)], countries[dst(e)]],
		)
    	push!(traces, trace)
	end

	layout = PlotlyBase.Layout(
		title_text = "Influence graph (undirected)",
    	showlegend = false,
    	geo = PlotlyBase.attr(
        	showland = true,
        	showcountries = true,
        	showocean = true,
        	countrywidth = 0.5,
        	#landcolor = "rgb(230, 145, 56)",
        	#lakecolor = "rgb(0, 255, 255)",
        	#oceancolor = "rgb(0, 255, 255)",
			projection = PlotlyBase.attr(type = "natural earth"),
			#scope = "africa"
			),
		#modebar = attr(remove = ["zoomOutGeo"]),
		#dragmode = "pan"
		)

        return traces, layout
end