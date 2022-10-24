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
        ax.set_xlim(left=-1)
        xticks = ax.get_xticks()
        xticks = 0:round(xticks[end])
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


