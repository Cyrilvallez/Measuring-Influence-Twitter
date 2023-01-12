using StatsBase
using ProgressBars
import Random
import PyPlot as plt
using PyPlot: @L_str
import Seaborn as sns

include("Engine/Engine.jl")
using .Engine

Random.seed!(123)

N = 1000
N_seeds = 10
seeds = sample(1:10000, N_seeds, replace=false)

###################################### TE #############################

thresholds = 0:0.001:0.01
limits = [x->-1000, x->quantile(x, 0.5), x->quantile(x, 0.6), x->quantile(x, 0.7), x->quantile(x, 0.8), x->quantile(x, 0.9), x->quantile(x, 1), x->2*quantile(x, 1), x->4*quantile(x, 1)]
labels = ["None", "Q(0.5)", "Q(0.6)", "Q(0.7)", "Q(0.8)", "Q(0.9)", L"\max", L"2\cdot \max", L"4\cdot \max"]

res = Matrix{Vector{Float64}}(undef, length(limits), length(thresholds))
for i in eachindex(res)
    res[i] = []
end

X = [sample([0,1], AnalyticWeights([0.9, 0.1]), 200) for i = 1:N]
Y = [sample([0,1], AnalyticWeights([0.9, 0.1]), 200) for i = 1:N]

for seed in ProgressBar(seeds)
    for (i, limit) in ProgressBar(enumerate(limits), leave=false)
        for (j, threshold) in ProgressBar(enumerate(thresholds), leave=false)

            igg = InfluenceGraphGenerator(SimpleTE, threshold=threshold, limit=limit, seed=seed)
            tot = 0

            for i in ProgressBar(1:N, leave=false)
                if igg.causal_function(X[i], Y[i]) == 1
                    tot += 1
                end  
            end

            push!(res[i,j], tot/N)

        end
    end
end

save_data(res, "../Results/Find_thresholds/TE.jld2")

mean_value = Matrix{Float64}(undef, size(res))
for i in eachindex(res)
    mean_value[i] = mean(res[i])
end

plt.figure(figsize=[6.4, 4.8].*1.2)
sns.heatmap(mean_value, annot=true, cmap="rocket_r")
plt.xlabel("Threshold")
plt.ylabel("Limit value")
xloc, xlabels = plt.xticks()
plt.xticks(xloc, thresholds)
yloc, ylabels = plt.yticks()
plt.yticks(yloc, labels, rotation="horizontal")
plt.savefig("thresholds_te.pdf", bbox_inches="tight")
plt.gcf()



####################################### JDD ###############################


thresholds = [1, 0.05, 0.01, 0.005, 0.001]
limits = [x->+1000000, x->quantile(x, 0.5), x->quantile(x, 0.4), x->quantile(x, 0.3), x->quantile(x, 0.2), x->quantile(x, 0.1), x->quantile(x, 0), x->quantile(x, 0)/2, x->quantile(x, 0)/4]
labels = ["None", "Q(0.5)", "Q(0.4)", "Q(0.3)", "Q(0.2)", "Q(0.1)", "min", "min/2", "min/4"]

res = Matrix{Vector{Float64}}(undef, length(limits), length(thresholds))
for i in eachindex(res)
    res[i] = []
end

X = [rand(200) for i = 1:N]
Y = [rand(200) for i = 1:N]


for seed in ProgressBar(seeds)
    for (i, limit) in ProgressBar(enumerate(limits), leave=false)
        for (j, threshold) in ProgressBar(enumerate(thresholds), leave=false)

            igg = InfluenceGraphGenerator(JointDistanceDistribution, alpha=threshold, limit=limit, seed=seed)
            tot = 0

            for i in ProgressBar(1:N, leave=false)
                if igg.causal_function(X[i], Y[i]) == 1
                    tot += 1
                end     
            end

            push!(res[i,j], tot/N)

        end
    end
end


save_data(res, "../Results/Find_thresholds/JDD.jld2")

mean_value = Matrix{Float64}(undef, size(res))
for i in eachindex(res)
    mean_value[i] = mean(res[i])
end

plt.figure(figsize=[6.4, 4.8].*1.2)
sns.heatmap(mean_value, annot=true, cmap="rocket_r")
plt.xlabel("p-value")
plt.ylabel("Limit value")
xloc, xlabels = plt.xticks()
plt.xticks(xloc, thresholds)
yloc, ylabels = plt.yticks()
plt.yticks(yloc, labels, rotation="horizontal")
plt.savefig("thresholds_jdd.pdf", bbox_inches="tight")
plt.gcf()