include("Engine/Engine.jl")
using ..Engine

using BenchmarkTools
using CausalityTools
import Random

Random.seed!(1)

igg = InfluenceGraphGenerator(Engine.JointDistanceDistribution, surrogate=nothing)

f = (x,y) -> pvalue(jdd(OneSampleTTest, x, y, B=10, D=5, τ=1, μ0=0.0), tail=:right) < 0.001 ? 1 : 0
f2 = (x,y) -> igg.causal_function(x,y)

x = rand(200)
y = rand(200)

@btime f2(x,y)