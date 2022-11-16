module Sensors

using DataFrames

export TimeSeriesGenerator, InfluenceGraphGenerator, InfluenceCascadeGenerator, Pipeline
export SMeasure, JointDistanceDistribution
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

function Pipeline(cuttoff::Float64)
    tsg = TimeSeriesGenerator()
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
    influence_cascades = observe(influence_graphs, pipeline.influence_cascade_generator)

    return influence_graphs, influence_cascades

end


end # module