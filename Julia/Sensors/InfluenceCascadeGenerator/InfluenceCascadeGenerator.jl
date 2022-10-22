using DataStructures
using Graphs, GraphPlot
using PlotlyBase

mutable struct InfluenceCascadeGenerator  <: Sensor
    cuttoff::Float64
end


struct InfluenceCascade
    # The influence matrix at each level
    cascade::OrderedDict{AbstractString, Matrix}
    # The tuples representing edges between actors at each level
    actor_edges::OrderedDict{AbstractString, Vector{Tuple{Int, Int}}}
    # The number of different actors per level
    actors_per_level::Vector{Int}
    # The index of the root actor
    root::Int
    # Indicates whether the cascade has been normalized 
    is_normalized::Bool
end


function normalize_cascade(cascade::InfluenceCascade)
    # Normalize the cascades by their total influence values
    total_influence = sum(collect(values(cascade.cascade)))
    M = size(total_influence, 1)

    for key in keys(cascade.cascade)
        # if total_influence is not 0, divide by it (otherwise just put 0 because this means all cascades were 0)
        cascade.cascade[key] = ifelse.(total_influence .> 0, cascade.cascade[key] ./ total_influence, zeros(M,M))
    end
end

"""
    observe(data::Matrix{Matrix}, icg::InfluenceCascadeGenerator, normalize::Bool=true)

Return the influence cascades from the adjacency matrix containing the transfer entropy per actions.
"""
function observe(data::Matrix{Matrix}, icg::InfluenceCascadeGenerator, normalize::Bool=true)

    influencers = Vector{Int}()
    for (j, col) in enumerate(eachcol(data))
        indegree = 0
        for source in col
            if any(source .> icg.cuttoff)
                indegree += 1
            end
        end
        if indegree==0
            # Before labeling it as an influencer, check that there is some outdegree (influence) for that node
            for target in data[j, :]
                # if true, this means that there is at least 1 outdegree, thus we append the influencer
                if any(target .> icg.cuttoff)
                    push!(influencers,j)
                    break
                end
            end
        end
    end

    influence_cascades = []
    M = size(data[1,1], 1)

    for influencer in influencers
        # BFS through influence graph
        queue = Queue{Int}()
        enqueue!(queue, influencer)

        # this will keep track of the current depth in the BFS
        level = 0

        # Will contain the sum of the influence for each level 
        cascade = OrderedDict{AbstractString, Matrix}()
        # Will contains the actors edges of the cascade
        actor_indices = OrderedDict{AbstractString, Vector{Tuple{Int, Int}}}()
        # Will contain the number of actors at each level
        actors_per_level = []
    
        # Initialize the dicts for the first levels
        cascade["$level => $(level+1)"] = zeros(M, M)
        actor_indices["$level => $(level+1)"] = []

        # nodes already visited
        visited = [influencer]

        while (!isempty(queue))
            # number of nodes at the current depth (level)
            level_size = length(queue)
            push!(actors_per_level, level_size)
            while (level_size != 0)
                level_size -= 1
                node = dequeue!(queue)
                # find indices of all subsequent connected nodes
                indices = findall(x -> any(x .> icg.cuttoff), data[node, :]) 
                for ind in indices
                    # Add the value to the cascade even if the nodes have been already visited since 
                    # there can be multiple connection
                    cascade["$level => $(level+1)"] += ifelse.(data[node, ind] .> icg.cuttoff, data[node, ind], zeros(M,M))
                    push!(actor_indices["$level => $(level+1)"], (node, ind))
                    # if we did nor visit it, add it to the queue
                    if !(ind in visited)
                        enqueue!(queue, ind)
                        push!(visited, ind)
                    end
                end
            end
            if !(isempty(queue))
                level += 1
                cascade["$level => $(level+1)"] = zeros(M, M)
                actor_indices["$level => $(level+1)"] = []
            end
        end
        # add number of actors in the last level
        push!(actors_per_level, length(unique([i[2] for i in actor_indices["$level => $(level+1)"]])))
        # Create the influence_cascade objects and add it to the list
        influence_cascade = InfluenceCascade(cascade, actor_indices, actors_per_level, influencer, normalize)
        push!(influence_cascades, influence_cascade)
    end
    
    if normalize
        # Normalize the cascades by their total influence values
        for cascade in influence_cascades
            normalize_cascade(cascade)
        end
    end
    
    return influence_cascades
end


function plot_cascade_sankey(influence_cascade::InfluenceCascade, actions)
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