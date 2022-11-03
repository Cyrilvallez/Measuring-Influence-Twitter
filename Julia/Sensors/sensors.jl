using DataFrames

# Include this file to import all others at once
include("TimeSeriesGenerator/TSGenerator.jl")
include("InfluenceGrapher/InfluenceGrapher.jl")
include("InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")

struct Pipeline

    time_series_generator::TimeSeriesGenerator
    influence_grapher::InfluenceGrapher
    influence_cascade_generator::InfluenceCascadeGenerator

end

function Pipeline(cuttoff::Float64)
    tsg = TimeSeriesGenerator()
    ig = InfluenceGrapher()
    icg = InfluenceCascadeGenerator(cuttoff)
    return Pipeline(tsg, ig, icg)
end

function observe(df::DataFrame, pipeline::Pipeline)

    time_series = observe(df, pipeline.time_series_generator)
    influence_graphs = observe(time_series, pipeline.influence_grapher)
    influence_cascades = observe(influence_graphs, pipeline.influence_cascade_generator)

    return influence_graphs, influence_cascades

end
