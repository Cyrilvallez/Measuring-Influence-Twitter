include("TSGenerator.jl")

using CSV
    
if split(pwd(), "\\")[end] != "timeseriesgenerator"
    cd("julia/sensors/TimeSeriesGenerator")
end

df = CSV.read("../../../Data/1_Raw/small_articles1.csv", DataFrame)
df.source = df.publication
df.partition .= 1
df.time = df.date

tsg = TimeSeriesGenerator()

a = observe(df, tsg)

