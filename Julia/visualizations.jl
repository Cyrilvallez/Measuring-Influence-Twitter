using PyPlot
include("Sensors/InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")

begin
    rcParams = PyPlot.PyDict(PyPlot.matplotlib."rcParams")
    rcParams["font.family"] = ["serif"]
    rcParams["font.serif"] = ["Computer Modern Roman"]
    rcParams["savefig.dpi"] = 400
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


function actors_per_level(influence_cascade::InfluenceCascade, level_max::Int)
    levels = [0 for i = 1:level_max]
    if isempty(influence_cascade.nodes)
        return levels
    end
    levels[1] = 1

    # Weird trick to get the same ordering of the influence cascade as the other functions
    # (e.g see the mean method)
    levels[2] = length(influence_cascade[influence_cascade.start_node])>0 ? 
        length(influence_cascade[influence_cascade.start_node]) : 0
    others = [j for j in keys(influence_cascade.nodes) if j != influence_cascade.start_node]
    for (i, key) in enumerate(others)
        levels[i+2] = length(influence_cascade[key])>0 ? length(influence_cascade[key]) : 0
    end

    return levels
end


function mean_actors_per_level(influence_cascades::Vector{InfluenceCascade})
    level_max = maximum(x -> length(x.nodes), influence_cascades) + 1
    mean_levels = mean(actors_per_level.(influence_cascades, Ref(level_max)), dims=1)
    # convert to single dimension
    return [mean_levels[1][i] for i in 1:length(mean_levels[1])]
end


function plot_actors_per_level(influences_cascades::Vector{Vector{InfluenceCascade}}, titles)
    partition_levels = mean_actors_per_level.(influences_cascades)
    levels = [0:(length(x)-1) for x in partition_levels]

    N = length(partition_levels)
    if N <= 4
        Nx = min(2, N)
        Ny = N ÷ 2 + 1
    else
        Nx = 3
        Ny = N ÷ 3 + 1
    end

    (fig, axes) = subplots(Nx, Ny, figsize=(8,8), sharex=true, sharey=true)
    idx = 0
    for ax in axes
        idx += 1
        if idx > N
            break
        else
            ax.bar(levels[idx], partition_levels[idx])
            ax.set(title=titles[idx])
        end
    end
    
    for ax in axes[:,1]
        ax.set(ylabel="Mean number of actors")
    end
    for ax in axes[end, :]
        ax.set(xlabel="Level")
        ax.set_xlim(left=-0.1)
        xticks = ax.get_xticks()
        xticks = xticks[1]:xticks[end]
        ax.set(xticks=xticks)
    end

    # Remove unused axes
    idx = 0
    for ax in axes
        idx += 1
        if idx > N
            delaxes(ax)
        end
    end

    return fig
end


