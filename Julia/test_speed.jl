include("Engine/Engine.jl")
using ..Engine

using BenchmarkTools
using CausalityTools

igg = InfluenceGraphGenerator(Engine.JointDistanceDistribution, surrogate=nothing)

f = (x,y) -> pvalue(jdd(OneSampleTTest, x, y, B=10, D=5, τ=1, μ0=0.0), tail=:right) < 0.001 ? 1 : 0
f2 = (x,y) -> igg.causal_function(x,y)

x = rand(600)
y = rand(600)

@btime f2(x,y)