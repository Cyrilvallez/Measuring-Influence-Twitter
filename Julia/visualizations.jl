import PyPlot as plt
#using PlotlyJS
using WordCloud
using StatsBase: maximum, minimum, median, mean, countmap
include("Sensors/InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")

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
        titles = unique(df[!,:partition])
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
Plot the number of appearance of each actor in the dataset as a barplot. 
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