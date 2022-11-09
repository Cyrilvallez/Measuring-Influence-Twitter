import Pkg

packages_with_version = [
    ("CSV", "0.10.4"),
    ("CausalityTools", "1.4.1"),
    ("Colors", "0.12.8"),
    ("DataFrames", "1.3.6"),
    ("DataStructures", "0.18.13"),
    ("Graphs", "1.7.4"),
    ("GraphPlot", "0.5.2"),
    ("JSON", "0.21.3"),
    ("PlotlyBase", "0.8.19"),
    ("PlotlyJS", "0.18.9"),
    ("Plots", "1.34.4"),
    ("Pluto", "0.19.9"),
    ("PlutoPlotly", "0.3.4"),
    ("PlutoUI", "0.7.43"),
    ("PyPlot", "2.11.0"),
    ("SimpleWeightedGraphs", "1.2.1"),
    ("StatsBase", "0.33.21"),
    ("WordCloud", "0.10.7"),
    ("URIs", "1.4.0")
]

packages_without_version = [
    "Dates"
]


for (package, version) in packages_with_version
    Pkg.add(name=package, version=version)
end

for package in packages_without_version
    Pkg.add(package)
end