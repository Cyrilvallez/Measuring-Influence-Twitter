include("platforms.jl")
include("Sensors/InfluenceGrapher/InfluenceGrapher.jl")
include("Sensors/TimeSeriesGenerator/TSGenerator.jl")
include("Sensors/InfluenceCascadeGenerator/InfluenceCascadeGenerator.jl")
include("Sensors/CascadeClusterer/CascadeCluster.jl")
using GraphPlot, Graphs, Multigraphs
# using TikzGraphs

## Influence cascades
mutable struct InfluenceCascadePlatform <: SensorPlatform

    timeseriesgenerator::TimeSeriesGenerator
    influencegrapher::InfluenceGrapher
    influencecascadegenerator::InfluenceCascadeGenerator

end

function observe(data, icp::InfluenceCascadePlatform)

    return data |> 
            x -> observe(x, icp.timeseriesgenerator) |> 
            x -> observe(x, icp.influencegrapher)    |>
            x -> observe.(x, Ref(icp.influencecascadegenerator))

end
