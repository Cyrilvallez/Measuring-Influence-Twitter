module Visualizations

using DataFrames, Graphs, SimpleWeightedGraphs
using PlotlyBase, GraphPlot, Colors, WordCloud
using StatsBase: mean, countmap, proportionmap
using Printf, Logging
import PyPlot as plt
import Seaborn as sns

# need using ..Sensors without include here (see https://discourse.julialang.org/t/referencing-the-same-module-from-multiple-files/77775/2)
using ..Sensors: SingleInfluenceGraph, InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades
using ..Helpers: make_simplifier
using ..Metrics: edge_types

export plot_cascade_sankey,
       plot_graph,
       plot_graph_map,
       plot_betweenness_centrality,
       plot_edge_types,
       plot_actors_per_level,
       plot_actor_frequency,
       plot_action_frequency,
       plot_actor_wordcloud
       

# Some default parameters for better plots
begin
    rcParams = plt.PyDict(plt.matplotlib."rcParams")
    rcParams["font.family"] = ["serif"]
    rcParams["font.serif"] = ["Computer Modern Roman"]
    rcParams["figure.dpi"] = 100
    rcParams["text.usetex"] = true
    rcParams["legend.fontsize"] = 16
    rcParams["lines.linewidth"] = 2
    rcParams["lines.markersize"] = 6
    rcParams["axes.titlesize"] = 18
    rcParams["axes.labelsize"] = 15
    rcParams["xtick.labelsize"] = 12
    rcParams["ytick.labelsize"] = 12
end



"""
Plot an influence cascade as a Sankey diagram.
"""
function plot_cascade_sankey(influence_cascade::InfluenceCascade, df::DataFrame)

    # Actions are represented in the order they appear in sort(unique(df.action)) in the adjacency matrix
    actions = sort(unique(df.action))

    # Bank of color because PlutoPlotly does not support the `colorant"blue"` colors in
    # Pluto notebooks
    color_bank = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b",
     "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]

    # This give the correct order of the transitions because the dict containing the values is ordered 
    layers = collect(values(influence_cascade.cascade))
    N_actions = length(actions)
    N_layers = length(layers)

    sources = []
    targets = []
    values_ = []

    for (layer_idx, layer) in enumerate(layers)
        for i in 1:size(layer)[1], j in 1:size(layer)[2]
            # We just check if this is not zero since the cuttoff has been applied before and the normalization allows for values < cuttoff
            if layer[i,j] > 0
                # We need the last -1 because Plotly starts indexing at 0 instead
                # of 1 (which contradicts Julia)
                push!(sources, N_actions*(layer_idx-1)+i-1)
                push!(targets, N_actions*layer_idx+j-1)
                push!(values_, layer[i,j])
            end
        end
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
            sources[old_sources .> i] .-= 1
            targets[old_targets .> i] .-= 1
        end
    end

    fig = sankey(
        valueformat = ".2f",
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
          value = values_,
          hovertemplate = "source : %{source.label} on level %{source.customdata} \
          <br />target : %{target.label} on level %{target.customdata}"
        ))
    layout = Layout(title_text="Influence cascade", font_size=10)

    return fig, layout
        
end



"""
Plot the graph corresponding to the matrix adjacency, for one type of edge (edges are matrices).
"""
function plot_graph(adjacency::SingleInfluenceGraph, df::DataFrame, cuttoff::Real; edge_type::AbstractString = "Any Edge", print_node_names::Bool = false)

    # Actors and actions are represented in the order they appear in sort(unique(df."actor")) in the adjacency matrix
    node_labels = sort(unique(df.actor))
    actions = sort(unique(df.action))

    simplifier = make_simplifier(edge_type, cuttoff, actions)

    # reduce the adjacency matrix containing edge matrices to simple adjacency matrix depending on which 
    # connection we are interested in in the edge matrices
    reduced_adjacency = simplifier.(adjacency)
    g = SimpleWeightedDiGraph(reduced_adjacency)
    # remove unconnected nodes from the drawing of the graph
    outdegrees = outdegree(g)
    indegrees = indegree(g)
    connected_vertices = [i for i in vertices(g) if (outdegrees[i] > 0 || indegrees[i] > 0)]
    connected_graph, vmap = induced_subgraph(g, connected_vertices)
    connected_vertices_labels = node_labels[vmap]

    # We draw aggregate actors as red nodes, and individuals as blue nodes
    regex = r"^[0-9]+ to [0-9]+ followers$"
    colors = Vector{RGB}(undef, length(connected_vertices_labels))
    for (i, label) in enumerate(connected_vertices_labels)
        if occursin(regex, label)
            colors[i] = colorant"red"
        else
            colors[i] = colorant"blue"
        end
    end

    # Plot only connected nodes
    if print_node_names
        gplot(connected_graph, nodefillc=colors, nodelabel=connected_vertices_labels, nodelabelc=colorant"white")
    else
        gplot(connected_graph, nodefillc=colors, nodelabelc=colorant"white") 
    end

end



"""
Plot the different edge types count or proportion, for different partitions and/or datasets.
"""
function plot_edge_types(graphs, dfs, cuttoffs; y::String = "count", log::Bool = true, save::Bool = false, filename = nothing, kwargs...)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    acceptable_y = ["count", "count_normalized", "proportion"]
    if !(y in acceptable_y)
        throw(ArgumentError("y must be one of $acceptable_y."))
    end

    data = edge_types(graphs, dfs, cuttoffs)

    plt.figure()
    sns.barplot(data, x="edge_type", y=y, hue="partition", saturation=1, zorder=2; kwargs...)
    plt.xlabel("Edge type")
    plt.ylabel(uppercasefirst(y) * " of total number of edges")
    plt.legend()
    plt.grid(true, which="major", axis="y", zorder=0)
    if log
        plt.yscale("log")
        plt.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
    end
    if save
        plt.savefig(filename, bbox_inches="tight", dpi=400)
    end
    return plt.gcf()

end


function plot_betweenness_centrality(influence_graphs::InfluenceGraphs, df::DataFrame, cuttoff::Real = 0.0; width=1., cut=0,
    save::Bool = false, filename = nothing, reorder = [2,3,1])

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    # Actors and partitions are represented in the order they appear in sort(unique(df)) in the adjacency matrix
    actors = sort(unique(df."actor"))
    partitions = sort(unique(df.partition))

    # In this case remove default value
    if length(partitions) != 3 && reorder == [2,3,1]
        reorder = nothing
    end

    # Create simple graphs by removing weights not needed for the centrality
    simplifier = x -> maximum(x) > cuttoff
    simple_graphs = [SimpleDiGraph(simplifier.(graph)) for graph in influence_graphs]

    betweenness = [betweenness_centrality(graph, normalize=true) for graph in simple_graphs]

    if !isnothing(reorder)
        partitions = partitions[reorder]
        betweenness = betweenness[reorder]
    end

    # plt.figure()
    # for i = 1:length(partitions)
    #     plt.plot(1:length(actors), betweenness[i], label=partitions[i])
    # end
    # plt.xlabel("Node index")
    # plt.ylabel("Betweenness centrality")
    # plt.legend()
    # plt.grid()
    # if save
    #     plt.savefig(filename, bbox_inches="tight", dpi=400)
    # end

    plt.figure()
    sns.violinplot(betweenness, width=width, cut=cut)
    plt.xlabel("Partition")
    plt.ylabel("Betweenness centrality")
    ticks, _ = plt.xticks()
    plt.xticks(ticks, labels=partitions)
    plt.grid()
    if save
        plt.savefig(filename, bbox_inches="tight", dpi=400)
    end

    return plt.gcf()
end



function plot_actors_per_level(influence_cascades::InfluenceCascades, df::DataFrame; split_by_partition::Bool = true, width::Real = 0.25,
    inner_spacing::Real = 0.01, outer_spacing::Real = width, log::Bool = true, save::Bool = false, filename = nothing, reorder=[2, 3, 1])

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        actor_levels = mean_actors_per_level.(influence_cascades)
        max_level = maximum(length, actor_levels)
        # Pad with zeros so that they all have the same length
        actor_levels = [vec([x... [0. for i = (length(x)+1):max_level]...]) for x in actor_levels]
        labels = sort(unique(df.partition))

        # In this case remove default value
        if length(labels) != 3 && reorder == [2,3,1]
            reorder = nothing
        end

        # Optionally reorder the bars in the plot
        if !isnothing(reorder)
            actor_levels = actor_levels[reorder]
            labels = labels[reorder]
        end

    else
        # Shape it as a vector to be consistent with the case when `split_by_partition` is true
        actor_levels = [mean_actors_per_level(vcat(influence_cascades...))]
        max_level = length(actor_levels[1])
        # dummy variable (will not be used)
        labels = [""]
    end

    levels = collect(0:(max_level-1))
    X, tick_position = barplot_layout(length(actor_levels), max_level, width=width, inner_spacing=inner_spacing, outer_spacing=outer_spacing)

    plt.figure()
    for i = 1:length(actor_levels)
        plt.bar(X[i,:], actor_levels[i], width=width, label=labels[i], zorder=2)
    end
    plt.xlabel("Cascade level")
    plt.ylabel("Mean number of actors")
    if split_by_partition
        plt.legend()
    end
    plt.grid(true, which="major", axis="y", zorder=0)
    plt.xticks(tick_position, levels)
    if log
        plt.yscale("log")
        plt.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
    end
    if save
        plt.savefig(filename, bbox_inches="tight", dpi=400)
    end
    return plt.gcf()

end



"""
Plot the number of appearance of each actor in the dataset as a boxplot. 
"""
function plot_actor_frequency(df::DataFrame; split_by_partition::Bool = true, log::Bool = true, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        countmaps = combine(groupby(df, "partition"), "actor" => countmap => "countmap")
        partitions = countmaps."partition"
        stats = collect.(values.(countmaps."countmap"))
    else
        partitions = ["Full dataset"]
        stats = collect(values(countmap(df."actor")))
    end

    plt.figure()
    plt.boxplot(stats)
    plt.xlabel("Partition")
    ticks = plt.xticks()[1]
    plt.xticks(ticks, partitions)
    plt.ylabel("Number of tweets per actor")
    plt.grid(true, which="major", axis="y")
    if log
        plt.yscale("log")
        plt.grid(true, which="minor", axis="y", alpha=0.4)
    end
    if save
        plt.savefig(filename, bbox_inches="tight", dpi=400)
    end
    return plt.gcf()

end



"""
Plot the number of appearance of each action in the dataset as a barplot. 
"""
function plot_action_frequency(df::DataFrame; split_by_partition::Bool = true, width::Real = 0.25, inner_spacing::Real = 0.01, outer_spacing::Real = width,
    log::Bool = true, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        countmaps = combine(groupby(df, "partition"), "action" => countmap => "countmap")
        partitions = countmaps."partition"
        counts = collect.(values.(countmaps."countmap"))
        actions = collect.(keys.(countmaps."countmap"))
        # Sort to ensure that we get the same ordering of the actions each time
        for i in 1:length(counts)
            sorting = sortperm(actions[i])
            counts[i] = counts[i][sorting]
            actions[i] = actions[i][sorting]
        end
        # Keep only the first (they are all identical)
        actions = actions[1]
    else
        countmaps = countmap(df."action")    
        counts = collect(values(countmaps))
        actions = collect(keys(countmaps))
        # sort to be coherent with the case when we split by partition
        sorting = sortperm(actions)
        counts = counts[sorting]
        actions = actions[sorting]
        # Reshape into a vector so that it has the same shape as in the case with `split_by_partition` set to true
        counts = [counts]
        # dummy variable (will not be used)
        partitions = [""]
    end

    X, tick_position = barplot_layout(length(counts), length(actions), width=width, inner_spacing=inner_spacing, outer_spacing=outer_spacing)

    plt.figure()
    for i = 1:length(counts)
        plt.bar(X[i,:], counts[i], width=width, label=partitions[i], zorder=2)
    end
    plt.xlabel("Actions")
    plt.ylabel("Number of tweets per action")
    if split_by_partition
        plt.legend()
    end
    plt.grid(true, which="major", axis="y", zorder=0)
    plt.xticks(tick_position, actions)
    if log
        plt.yscale("log")
        plt.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
    end

    # Compute proportion and put it as a label on top of the bars

    proportionmaps = combine(groupby(df, :partition),  :action  => proportionmap => :proportion)
    proportions = collect.(values.(proportionmaps.proportion))
    actions_ = collect.(keys.(proportionmaps.proportion))
    # Sort to ensure that we get the same ordering of the actions each time
    for i in 1:length(proportions)
        sorting = sortperm(actions_[i])
        proportions[i] = proportions[i][sorting]
    end
    proportions = vcat(proportions...)

   ax = plt.gca()

    for (i, bar) in enumerate(ax.patches)
        ax.annotate(@sprintf("%.2f", proportions[i]*100),
                   (bar.get_x() + bar.get_width() / 2,
                    bar.get_height()), ha="center", va="center",
                   size=12, xytext=(0, 8),
                   textcoords="offset points")
    end

    # Add 8% size to ylim to make sure annotations fit in the plot
    lims = ax.get_ylim()
    ax.set_ylim((lims[1], lims[2]*1.08))

    if save
        plt.savefig(filename, bbox_inches="tight", dpi=400)
    end
    return plt.gcf()
        
end



"""
Plot the principal actors as a wordcloud.

df: The dataframe containing the data.  
by_: The numerical column of df on which to rank the actors  
reduc: Function describing how to treat the numerical values for actors consisting of multiple entities  
Nactor: How much actor to include in the wordcloud  
normalize: whether to normalize the wordcloud (setting text size based on the log of the value)  
save: whether to save the wordcloud  
filename: filename for saving the wordcloud if save is true  
verbose: whether or not to show warnings and indications in the wordcloud creation
"""
function plot_actor_wordcloud(df::DataFrame; by_::String = "follower_count", reduc::Function = mean, Nactor::Int = 300, normalize::Bool = true,
    save::Bool = false, filename = nothing, verbose::Bool = false)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    actors = unique(df."actor")
	M = length(actors)
	weights = Vector{Float64}(undef, M)
	for i = 1:M
		indices = findall(actors[i] .== df."actor")
		weights[i] = reduc(df[!, by_][indices])
	end
	sorting = sortperm(weights, rev=true)
	actors = actors[sorting]
	weights = weights[sorting]

    words = actors[1:Nactor]
    weights = weights[1:Nactor]

    #=
    if maximum(weights)/minimum(weights) > 20
        index = findfirst(weights./minimum(weights) .< 15)
        max_ = maximum(weights[1:index])
        min_ = minimum(weights[1:index])
        weights[1:index] = (weights[1:index] .- min_) ./ (max_ - min_) * (20*minimum(weights) - weights[index]) .+ weights[index]
    end
    =#

    if normalize
        weights = weights ./ minimum(weights)
        weights = log10.(weights .+ 0.01)
    end

    if verbose == false
        # Discard all standard outputs
        redirect_stdout(devnull) do
            wc = wordcloud(words, weights, angles = (0), fonts = "Serif Bold", spacing = 1, colors = :seaborn_dark, maxfontsize = 300,
                mask = shape(ellipse, 800, 600, color="#e6ffff", backgroundcolor=(0,0,0,0)))
            rescale!(wc, 0.8)
            placewords!(wc, style=:gathering)
            # Discard all built in julia logging
            with_logger(NullLogger()) do 
                generate!(wc, reposition=0.7)
            end
        end
    else
        wc = wordcloud(words, weights, angles = (0), fonts = "Serif Bold", spacing = 1, colors = :seaborn_dark, maxfontsize = 300,
                mask = shape(ellipse, 800, 600, color="#e6ffff", backgroundcolor=(0,0,0,0)))
        rescale!(wc, 0.8)
        placewords!(wc, style=:gathering)
        generate!(wc, reposition=0.7)
    end
    if save
        paint(wc, filename)
    else
        return wc
    end
end



############################################# Miscellaneous #############################################


"""
Return the mean number of actors of all the influence cascades, at each level.
"""
function mean_actors_per_level(cascade_collection::CascadeCollection)
    N = length(cascade_collection)
    if N == 0
        return []
    end
    level_max = maximum([length(cascade.actors_per_level) for cascade in cascade_collection])
    mean_actor = zeros(level_max)
    for i = 1:level_max
        mean_ = sum([cascade.actors_per_level[i] for cascade in cascade_collection if length(cascade.actors_per_level) >= i])
        mean_actor[i] = mean_ / N
    end

    return mean_actor
end


"""
Return the x coordinates of each barplot for when we want to plots multiple barplots side by side. It also returns the  
position of the ticks corresponding the middle of each group of bars.
"""
function barplot_layout(Nbar::Int, xaxis_length::Int; width::Real = 0.25, inner_spacing::Real = 0.01, outer_spacing::Real = width)

    interval = Nbar*width + (Nbar-1)*inner_spacing + outer_spacing
    origin = [i*interval for i = 0:(xaxis_length-1)]
    xaxis = zeros(Nbar, xaxis_length)
    xaxis[1, :] = origin

    for i = 2:Nbar
        xaxis[i, :] = origin .+ (i-1)*width .+ (i-1)*inner_spacing
    end

    middle = Nbar ÷ 2

    if iseven(Nbar)
        tick_position = xaxis[middle, :] .+ width/2
    else
        tick_position = xaxis[middle+1, :]
    end

    return xaxis, tick_position

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



########################################### Old versions #######################################


"""
Plot the graph on a world map.
"""
function plot_graph_map(df::DataFrame)

    iso_codes = sort(unique(df.actor))
	indices = indexin(iso_codes, df.actor)
	countries = df."Country"[indices]
	traces = Vector{GenericTrace{Dict{Symbol, Any}}}()
		
	for (i, e) in enumerate(edges(g))
    	trace = scattergeo(  
	    	mode = "markers+lines",
	    	locations = [iso_codes[src(e)], iso_codes[dst(e)]],
	    	marker = attr(size = 8, color="blue"),
			line = attr(color="red", width=1),
			showlegend=false,
			name = "",
			hovertext = [countries[src(e)], countries[dst(e)]],
		)
    	push!(traces, trace)
	end

	layout = Layout(
		title_text = "Influence graph (undirected)",
    	showlegend = false,
    	geo = attr(
        	showland = true,
        	showcountries = true,
        	showocean = true,
        	countrywidth = 0.5,
        	#landcolor = "rgb(230, 145, 56)",
        	#lakecolor = "rgb(0, 255, 255)",
        	#oceancolor = "rgb(0, 255, 255)",
			projection = attr(type = "natural earth"),
			#scope = "africa"
			),
		#modebar = attr(remove = ["zoomOutGeo"]),
		#dragmode = "pan"
		)

        return traces, layout
        
end



"""
Plot the mean number of actors of all the influence cascades, at each level.
"""
function plot_actors_per_level_old(influence_cascades::InfluenceCascades, df::DataFrame; split_by_partition::Bool = true, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        actor_levels = mean_actors_per_level.(influence_cascades)
        levels = [0:(length(x)-1) for x in actor_levels]
        titles = sort(unique(df.partition))
    else
        actor_levels = mean_actors_per_level(vcat(influence_cascades...))
        levels = 0:(length(actor_levels)-1)
    end

    if split_by_partition
        N = length(actor_levels)
        if N == 1
            Nx = 1
            Ny = 1
        elseif N == 2
            Nx = 2
            Ny = 1
            figsize = (8, 4)
        elseif N <= 4
            Nx = min(2, N)
            Ny = N ÷ 2 + 1
            figsize = (8, 8)
        else
            Nx = 3
            Ny = N ÷ 3 + 1
            figsize = (8, 8)
        end

        if !(Nx == 1 && Ny == 1)
            (fig, axes) = plt.subplots(Ny, Nx, figsize=figsize, sharex=true, sharey=true)
            idx = 0
            for ax in axes
                idx += 1
                if idx > N
                    break
                else
                    ax.bar(levels[idx], actor_levels[idx], zorder=2)
                    ax.set(title=titles[idx])
                    ax.grid(true, which="major", axis="y", zorder=0)
                    ax.tick_params(labelbottom=true)
                end
            end
        
            for ax in axes[:,1]
                ax.set(ylabel="Mean number of actors")
            end
            for ax in axes[end, :]
                ax.set(xlabel=" Cascade level")
                left, right = ax.get_xlim()
                xticks = ceil(left):floor(right)
                ax.set(xticks=xticks)
            end

            # Remove unused axes
            idx = 0
            for ax in axes
                idx += 1
                if idx > N
                    plt.delaxes(ax)
                end
            end

            if save
                fig.savefig(filename, bbox_inches="tight", dpi=400)
            end
            return plt.gcf()
        
        # In case we split by partition but the partition is a unique value
        else
            plt.figure()
            plt.bar(levels[1], actor_levels[1], zorder=2)
            plt.xlabel("Level")
            plt.ylabel("Mean number of actors")
            plt.grid(true, which="major", axis="y", zorder=0)
            if save
                plt.savefig(filename, bbox_inches="tight", dpi=400)
            end
            return plt.gcf()
        end

    else
        plt.figure()
        plt.bar(levels, actor_levels, zorder=2)
        plt.xlabel("Level")
        plt.ylabel("Mean number of actors")
        plt.grid(true, which="major", axis="y", zorder=0)
        if save
            plt.savefig(filename, bbox_inches="tight", dpi=400)
        end
        return plt.gcf()
    end
end



"""
Plot the number of appearance of each action in the dataset as a barplot. 
"""
function plot_action_frequency_old(df::DataFrame; split_by_partition::Bool = true, log::Bool = true, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        countmaps = combine(groupby(df, "partition"), "action" => countmap => "countmap")
        partitions = countmaps."partition"
        counts = collect.(values.(countmaps."countmap"))
        actions = collect.(keys.(countmaps."countmap"))
        # Sort to ensure that we get the same ordering of the actions each time
        for i in 1:length(counts)
            sorting = sortperm(actions[i])
            counts[i] = counts[i][sorting]
            actions[i] = actions[i][sorting]
        end
    else
        countmaps = countmap(df."action")    
        counts = collect(values(countmaps))
        actions = collect(keys(countmaps))
        # sort to be coherent with the case when we split by partition
        sorting = sortperm(actions)
        counts = counts[sorting]
        actions = actions[sorting]
    end

    if split_by_partition

        N = length(counts)
        if N == 1
            Nx = 1
            Ny = 1
        elseif N == 2
            Nx = 2
            Ny = 1
            figsize = (8, 4)
        elseif N <= 4
            Nx = min(2, N)
            Ny = N ÷ 2 + 1
            figsize = (8, 8)
        else
            Nx = 3
            Ny = N ÷ 3 + 1
            figsize = (8, 8)
        end

        if !(Nx == 1 && Ny == 1)
            (fig, axes) = plt.subplots(Ny, Nx, figsize=figsize, sharex=true, sharey=true)
            idx = 0
            for ax in axes
                idx += 1
                if idx > N
                    break
                else
                    ax.bar(actions[idx], counts[idx], zorder=2)
                    ax.set(title=partitions[idx])
                    ax.grid(true, which="major", axis="y", zorder=0)
                    ax.tick_params(labelbottom=true)
                    if log
                        ax.set(yscale="log")
                        ax.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
                    end
                end
            end
        
            for ax in axes[:,1]
                ax.set(ylabel="Number of tweets per action")
            end
            for ax in axes[end, :]
                ax.set(xlabel="Action")
            end

            # Remove unused axes
            idx = 0
            for ax in axes
                idx += 1
                if idx > N
                    plt.delaxes(ax)
                end
            end

            if save
                fig.savefig(filename, bbox_inches="tight", dpi=400)
            end
            return plt.gcf()

        # In case we split by partition but the partition is a unique value
        else
            plt.figure()
            plt.bar(actions, counts, zorder=2)
            plt.xlabel("Actions")
            plt.ylabel("Number of tweets per action")
            plt.grid(true, which="major", axis="y", zorder=0)
            if log
                plt.yscale("log")
                plt.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
            end
            if save
                plt.savefig(filename, bbox_inches="tight", dpi=400)
            end
            return plt.gcf()
        end

    else
        plt.figure()
        plt.bar(actions, counts, zorder=2)
        plt.xlabel("Actions")
        plt.ylabel("Number of tweets per action")
        plt.grid(true, which="major", axis="y", zorder=0)
        if log
            plt.yscale("log")
            plt.grid(true, which="minor", axis="y", zorder=0, alpha=0.4)
        end
        if save
            plt.savefig(filename, bbox_inches="tight", dpi=400)
        end
        return plt.gcf()
    end

end


end # module