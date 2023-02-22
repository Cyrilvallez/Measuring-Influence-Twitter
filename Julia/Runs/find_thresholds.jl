using ArgParse, StatsBase
import Random
Random.seed!(12)
import PyPlot as plt
using PyPlot: @L_str
import Seaborn as sns

include("../Engine/Engine.jl")
using .Engine

function parse_commandline()

    settings = ArgParseSettings()
    @add_arg_table! settings begin
        "filename"
            help = "filename to save results (only base name, not full path)"
        "--N"
            help = "number of random computation for each loop."
            arg_type = Int
            default = 1000
        "--N_exp"
            help = "number of times to repeat all loops"
            arg_type = Int
            default = 5
        "--N_seeds"
            help = "number of times to change the seeds of the surrogates"
            arg_type = Int
            default = 5
        "--no_TE"
            help = "flag to remove the TE experiment"
            action = :store_true
        "--no_JDD"
            help = "flag to remove the JDD experiment"
            action = :store_true
    end

    return parse_args(settings)

end


function draw_series(N, M = 150, min_ = 3, weights = nothing)
    if isnothing(weights)
        weights = AnalyticWeights([0.965, 0.03, 0.003, 0.001, 0.001])
    end

    sample_ = [sample(0:4, weights, M) for i = 1:N]
    for i = 1:N
        if sum(sample_[i]) < min_
            while sum(sample_[i]) < min_
                sample_[i] = sample(0:4, weights, M)
            end
        end
    end

    return sample_

end


args = parse_commandline()


N = args["N"]
N_redo_all = args["N_exp"]
N_redo_surro = args["N_seeds"]
no_TE = args["no_TE"]
no_JDD = args["no_JDD"]
path = "../Results/Find_thresholds/" * args["filename"]
mkpath(dirname(path))

# Random seeds
seeds_all = sample(1:10000, N_redo_all, replace=false)
seeds_surro = sample(1:10000, N_redo_surro, replace=false)


###################################### TE ######################################


if !no_TE

    thresholds = 0:0.01:0.06
    limits = ["x->-1000", "x->quantile(x, 0.5)", "x->quantile(x, 0.75)", "x->quantile(x, 0.9)", "x->quantile(x, 1)", "x->2*quantile(x, 1)", "x->4*quantile(x, 1)"]
    labels = ["None", "Q(0.5)", "Q(0.75)", "Q(0.9)", L"\max", L"2\cdot \max", L"4\cdot \max"]

    result = Matrix{Matrix{Float64}}(undef, length(limits), length(thresholds))
    for i in eachindex(result)
        result[i] = Matrix{Float64}(undef, N_redo_all, N_redo_surro)
    end


    for (k, seed_all) in ProgressBar(enumerate(seeds_all), "All TE", leave=true)

        Random.seed!(seed_all)
        # X = draw_series(N)
        # Y = draw_series(N)
        X = [sample([0,1], AnalyticWeights([0.9, 0.1]), 200) for i = 1:N]
        Y = [sample([0,1], AnalyticWeights([0.9, 0.1]), 200) for i = 1:N]

        for (l, seed_surro) in ProgressBar(enumerate(seeds_surro), "Seeds", leave=false)

            for (i, limit) in ProgressBar(enumerate(limits), "Limits", leave=false)
                for (j, threshold) in ProgressBar(enumerate(thresholds), "Thresholds", leave=false)

                    Random.seed!(seed_surro)
                    igg = InfluenceGraphGenerator(SimpleTE, threshold=threshold, limit=limit)
                    tot = 0

                    for idx in ProgressBar(1:N, leave=false)
                        if igg.causal_function(X[idx], Y[idx]) == 1
                            tot += 1
                        end  
                    end

                    result[i,j][k,l] = tot/N

                end
            end

        end

    end

    save_data(result, path * "_TE.jld2")

    mean_value = Matrix{Float64}(undef, size(result))
    for i in eachindex(result)
        mean_value[i] = mean(result[i])
    end

    # Set vmin a little lower than minimum, so that 0 appears on a color scale lower than minimum when using clip=true
    if any(mean_value .== 0)
        vmin = minimum(mean_value[mean_value .!= 0])/2
    else
        vmin = minimum(mean_value)
    end

    plt.figure(figsize=[6.4, 4.8].*1.2)
    sns.heatmap(mean_value, annot=true, cmap="rocket_r", norm=plt.matplotlib.colors.LogNorm(vmin=vmin, clip=true))
    plt.xlabel("Threshold")
    plt.ylabel(L"S(\cdot)")
    xloc, xlabels = plt.xticks()
    plt.xticks(xloc, thresholds)
    yloc, ylabels = plt.yticks()
    plt.yticks(yloc, labels, rotation="horizontal")
    plt.savefig(path * "_TE.pdf", bbox_inches="tight")
    plt.gcf()

end



###################################### JDD ######################################



if !no_JDD


    thresholds2 = [1, 1e-1, 5e-2, 1e-2, 5e-3, 1e-3, 5e-4, 1e-4]
    limits2 = ["x->+1000000", "x->quantile(x, 0.5)", "x->quantile(x, 0.25)", "x->quantile(x, 0.1)", "x->quantile(x, 0)", "x->quantile(x, 0)/2", "x->quantile(x, 0)/4", "x->quantile(x, 0)/6"]
    labels2 = ["None", "Q(0.5)", "Q(0.25)", "Q(0.1)", "min", "min/2", "min/4", "min/6"]

    result2 = Matrix{Matrix{Float64}}(undef, length(limits2), length(thresholds2))
    for i in eachindex(result2)
        result2[i] = Matrix{Float64}(undef, N_redo_all, N_redo_surro)
    end


    for (k, seed_all) in ProgressBar(enumerate(seeds_all), "All JDD", leave=true)

        Random.seed!(seed_all)
        # X = draw_series(N)
        # Y = draw_series(N)
        X = [rand(200) for i = 1:N]
        Y = [rand(200) for i = 1:N]

        for (l, seed_surro) in ProgressBar(enumerate(seeds_surro), "Seeds", leave=false)

            for (i, limit) in ProgressBar(enumerate(limits2), "Limits", leave=false)
                for (j, threshold) in ProgressBar(enumerate(thresholds2), "Thresholds", leave=false)

                    Random.seed!(seed_surro)
                    igg = InfluenceGraphGenerator(JointDistanceDistribution, threshold=threshold, limit=limit)
                    tot = 0

                    for idx in ProgressBar(1:N, leave=false)
                        x = Sensors.standardize(X[idx])
                        y = Sensors.standardize(Y[idx])
                        if igg.causal_function(x, y) == 1
                            tot += 1
                        end  
                    end

                    result2[i,j][k,l] = tot/N

                end
            end

        end

    end


    save_data(result2, path * "_JDD.jld2")

    mean_value2 = Matrix{Float64}(undef, size(result2))
    for i in eachindex(result2)
        mean_value2[i] = mean(result2[i])
    end

    # Set vmin a little lower than minimum, so that 0 appears on a color scale lower than minimum when using clip=true
    if any(mean_value2 .== 0)
        vmin = minimum(mean_value2[mean_value2 .!= 0])/2
    else
        vmin = minimum(mean_value2)
    end
 
    plt.figure(figsize=[6.4, 4.8].*1.2)
    sns.heatmap(mean_value2, annot=true, cmap="rocket_r", norm=plt.matplotlib.colors.LogNorm(vmin=vmin, clip=true))
    plt.xlabel("p-value")
    plt.ylabel(L"S(\cdot)")
    xloc, xlabels = plt.xticks()
    plt.xticks(xloc, thresholds2)
    yloc, ylabels = plt.yticks()
    plt.yticks(yloc, labels2, rotation="horizontal")
    plt.savefig(path * "_JDD.pdf", bbox_inches="tight")
    plt.gcf()

end