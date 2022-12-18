import Pkg

### Note : you will need to have the command `unzip` on your machine for the installation
### to complete correctly. On linux run : "sudo apt install unzip".


packages_with_version = [
    ("CSV", "0.10.4"),
    ("JSON", "0.21.3"),
    ("YAML", "0.4.8"),
    ("JLD2", "0.4.29"),
    ("CausalityTools", "1.4.1"),
    ("Colors", "0.12.8"),
    ("DataFrames", "1.3.6"),
    ("DataStructures", "0.18.13"),
    ("StatsBase", "0.33.21"),
    ("URIs", "1.4.0"),
    ("BenchmarkTools", "1.3.1"),
    ("Graphs", "1.7.4"),
    ("SimpleWeightedGraphs", "1.2.1"),
    ("GraphPlot", "0.5.2"),
    ("Plots", "1.34.4"),
    ("Conda", "1.7.0"),
    ("PyPlot", "2.11.0"),
    ("Seaborn", "1.1.1"),
    ("PlotlyBase", "0.8.19"),
    ("PlotlyJS", "0.18.9"),
    ("WordCloud", "0.10.7"),
    ("Pluto", "0.19.9"),
    ("PlutoUI", "0.7.43"),
    ("PlutoPlotly", "0.3.4"),
    ("IJulia", "1.23.3"),
    ("Reexport", "1.2.2"),
    ("ProgressBars", "1.4.1"),
]

packages_without_version = [
    "Dates",
]


for (package, version) in packages_with_version

    # We need to set this prior to installing PyPlot
    if package == "PyPlot"
        ENV["PYTHON"] = ""
    end

    Pkg.add(name=package, version=version)

    if package == "Conda"
        import Conda
        Conda.add("matplotlib=3.6.2")
        Conda.add("seaborn=0.12.1")
    end

end

for package in packages_without_version
    Pkg.add(package)
end