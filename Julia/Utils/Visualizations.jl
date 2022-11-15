module Visualizations

using DataFrames, Graphs, SimpleWeightedGraphs
using PlotlyBase, GraphPlot, Colors, WordCloud
using StatsBase: mean, countmap
import PyPlot as plt

include("../Sensors/Sensors.jl")
using .Sensors: InfluenceCascade

export plot_cascade_sankey,
       plot_graph,
       plot_graph_map,
       plot_actors_per_level,
       plot_actor_frequency,
       plot_action_frequency,
       plot_actor_wordcloud
       

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
            sources[old_sources.>i] .-= 1
            targets[old_targets.>i] .-= 1
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
Plot the graph corresponding to the adjacency matrix adjacency, which is being simplified by simplifier.
"""
function plot_graph(adjacency::Matrix{Matrix{Float64}}, df::DataFrame, simplifier::Function)

    # Actors are represented in the order they appear in sort(unique(df."actor")) in the adjacency matrix
    node_labels = sort(unique(df."actor"))

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
    gplot(connected_graph, nodelabel=connected_vertices_labels, nodelabelc=colorant"white")

end



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
Return the mean number of actors of all the influence cascades, at each level.
"""
function mean_actors_per_level(influence_cascades::Vector{InfluenceCascade})
    N = length(influence_cascades)
    level_max = maximum([length(cascade.actors_per_level) for cascade in influence_cascades])
    mean_actor = zeros(level_max)
    for i = 1:level_max
        mean_ = sum([cascade.actors_per_level[i] for cascade in influence_cascades if length(cascade.actors_per_level) >= i])
        mean_actor[i] = mean_ / N
    end

    return mean_actor
end


"""
Plot the mean number of actors of all the influence cascades, at each level.
"""
function plot_actors_per_level(influence_cascades::Vector{Vector{InfluenceCascade}}, df::DataFrame; split_by_partition::Bool = true, save::Bool = false, filename = nothing)

    if save && isnothing(filename)
        throw(ArgumentError("You must provide a filename if you want to save the figure."))
    end

    if split_by_partition
        partition_levels = mean_actors_per_level.(influence_cascades)
        levels = [0:(length(x)-1) for x in partition_levels]
        titles = sort(unique(df.partition))
    else
        partition_levels = mean_actors_per_level(vcat(influence_cascades...))
        levels = 0:(length(partition_levels)-1)
    end

    if split_by_partition
        N = length(partition_levels)
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
                    ax.bar(levels[idx], partition_levels[idx], zorder=2)
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
            plt.bar(levels[1], partition_levels[1], zorder=2)
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
        plt.bar(levels, partition_levels, zorder=2)
        plt.xlabel("Level")
        plt.ylabel("Mean number of actors")
        plt.grid(true, which="major", axis="y", zorder=0)
        if save
            plt.savefig(filename, bbox_inches="tight", dpi=400)
        end
        return plt.gcf()
    end
end



#=
"""
Plot the number of appearance of each actor in the dataset as a barplot. 
"""
function actor_frequency(df::DataFrame, log::Bool=true)

    unique_count = countmap(df."actor")
    actors = Vector{String}(undef, length(unique_count))
    count = Vector{Int}(undef, length(unique_count))
    for (i, key) in enumerate(sort(collect(keys(unique_count))))
        actors[i] = key
        count[i] = unique_count[key]
    end

    plt.figure()
    plt.bar(actors, count)
    plt.xlabel("Actors")
    plt.ylabel("Number of tweet")
    if log
        plt.yscale("log")
    end
    plt.gcf()

end
=#


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
function plot_action_frequency(df::DataFrame; split_by_partition::Bool = true, log::Bool = true, save::Bool = false, filename = nothing)

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


"""
Plot the number of appearance of each action in the dataset as a barplot. 
"""
function plot_action_frequency_v2(df::DataFrame; split_by_partition::Bool = true, log::Bool = true, save::Bool = false, filename = nothing)

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
        barWidth = 0.25
        N = length(counts)
        pos = []
        push!(pos, collect(1:N))
        for i = 2:N
            push!(pos, [x + barWidth for x in pos[i-1]])
        end

        plt.figure()
        for i = 1:N
            plt.bar(pos[i], counts[i], label=partitions[i], width=barWidth, zorder=2)
        end
        plt.xticks(pos[2], actions)
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
"""
function plot_actor_wordcloud(df::DataFrame; by_::String = "follower_count", reduc::Function = mean, Nactor::Int = 300, normalize::Bool = true,
    save::Bool = false, filename = nothing)

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

    wc = wordcloud(words, weights, angles = (0), fonts = "Serif Bold", spacing = 1, colors = :seaborn_dark, maxfontsize = 300,
        mask = shape(ellipse, 800, 600, color="#e6ffff", backgroundcolor=(0,0,0,0)))
    rescale!(wc, 0.8)
    placewords!(wc, style=:gathering)
    generate!(wc, reposition=0.7)
    if save
        paint(wc, filename)
    else
        return wc
    end
end



##### Miscellaneous

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


end # module