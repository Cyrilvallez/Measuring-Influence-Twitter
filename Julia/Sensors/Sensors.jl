module Sensors

using DataFrames
using Dates
import Base: ==

export TimeSeriesGenerator, InfluenceGraphGenerator, InfluenceCascadeGenerator, Pipeline
export SingleInfluenceGraph, InfluenceGraphs, InfluenceCascade, CascadeCollection, InfluenceCascades
export SimpleTE, SMeasure, JointDistanceDistribution, TransferEntropy, WithoutCuttoff
export observe

include("timeseries.jl")
include("graphs.jl")
include("cascades.jl")

struct Pipeline

    time_series_generator::TimeSeriesGenerator
    influence_graph_generator::InfluenceGraphGenerator
    influence_cascade_generator::InfluenceCascadeGenerator

end


# Need to be redefined because each field contain some other fields which are mutables
function ==(a::Pipeline, b::Pipeline)
    return ((a.time_series_generator == b.time_series_generator && a.influence_graph_generator == b.influence_graph_generator)
        && a.influence_cascade_generator == b.influence_cascade_generator)
end


function Pipeline(time_interval::Period, cuttoff::Float64)
    tsg = TimeSeriesGenerator(time_interval)
    igg = InfluenceGraphGenerator()
    icg = InfluenceCascadeGenerator(cuttoff)
    return Pipeline(tsg, igg, icg)
end


"""
Execute all steps of at once : computation of the time series, influence graphs, and influence cascades.  
Return only the influence graphs and influence cascades.
"""
function observe(df::DataFrame, pipeline::Pipeline)

    time_series = observe(df, pipeline.time_series_generator)
    influence_graphs = observe(time_series, pipeline.influence_graph_generator)
    # Broadcast to all influence graphs since this was defined for just one graph for simplicity
    influence_cascades = observe.(influence_graphs, Ref(pipeline.influence_cascade_generator))

    return influence_graphs, influence_cascades

end


end # module