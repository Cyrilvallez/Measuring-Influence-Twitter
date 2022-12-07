module Sensors

using DataFrames
using Dates

export TimeSeriesGenerator, InfluenceGraphGenerator, InfluenceCascadeGenerator, Pipeline
export SMeasure, JointDistanceDistribution, TransferEntropy
export WithoutCuttoff
export observe

include("timeseries.jl")
include("graphs.jl")
include("cascades.jl")

struct Pipeline

    time_series_generator::TimeSeriesGenerator
    influence_grapher::InfluenceGraphGenerator
    influence_cascade_generator::InfluenceCascadeGenerator

end

function Pipeline(time_interval::Period, cuttoff::Float64)
    tsg = TimeSeriesGenerator(time_interval)
    ig = InfluenceGraphGenerator()
    icg = InfluenceCascadeGenerator(cuttoff)
    return Pipeline(tsg, ig, icg)
end


"""
Execute all steps of at once : computation of the time series, influence graphs, and influence cascades.  
Return only the influence graphs and influence cascades.
"""
function observe(df::DataFrame, pipeline::Pipeline)

    time_series = observe(df, pipeline.time_series_generator)
    influence_graphs = observe(time_series, pipeline.influence_grapher)
    # Broadcast to all influence graphs since this was defined for just one graph for simplicity
    influence_cascades = observe.(influence_graphs, Ref(pipeline.influence_cascade_generator))

    return influence_graphs, influence_cascades

end


end # module