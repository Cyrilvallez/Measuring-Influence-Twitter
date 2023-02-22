### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 1e33f69e-247c-11ed-07ff-e9204ff08266
begin
	import Pkg
	Pkg.activate()
	using PlutoUI, Dates
	import PlutoPlotly, Random

	include("../Sensors/Sensors.jl")
	include("../PreProcessing/PreProcessing.jl")
	include("../Utils/Helpers.jl")
	include("../Utils/Metrics.jl")
	include("../Utils/Visualizations.jl")
	include("../Engine/Engine.jl")

	# Cannot do `using .Engine` for local modules in Pluto...
end;

# ╔═╡ 604da907-49cd-4027-9b7e-285908d68af7
begin
	using DataFrames, Graphs, SimpleWeightedGraphs
	using PlotlyBase, GraphPlot, Colors, WordCloud
	using StatsBase: mean, countmap, proportionmap
	using Printf, Logging
	import PyPlot as plt
end

# ╔═╡ e8ebe45d-1e7d-433c-93cd-50407798e06e
begin
	
	md"""
	## Load the data
	
	Select the dataset you want to use :
	$(@bind dataset Select(["COP26", "COP27", "Skripal", "RandomDays"], default="COP26"))
	"""
end

# ╔═╡ e24ba873-cbb3-4823-be27-e9dfb2d8db89
begin
		
	md"""
	## Defining Investigation Scope
	
	Choose how to apply stratification: $(@bind part_fun Select(PreProcessing.partition_options, default=PreProcessing.cop_26_dates))
	
	Choose the way to define actor groups: $(@bind actor_fun Select(PreProcessing.actor_options,
	default=PreProcessing.follower_count)) \
	And the minimum number of tweets per actor: $(@bind min_tweets Slider(0:10, default=3, show_value=true))
	
	Choose the way to define distinct action types: $(@bind action_fun Select(PreProcessing.action_options, default=PreProcessing.trust_score))
	"""
end

# ╔═╡ 7286c17d-87e2-44a1-8a31-ad0d77e24838
begin
	dataset_map = Dict("COP26" => Helpers.COP26, "COP27" => Helpers.COP27,
	"Skripal" => Helpers.Skripal, "RandomDays" => Helpers.RandomDays)
	data = Helpers.load_dataset(dataset_map[dataset])
	
	actor_fun_ = actor_fun(by_partition=true, min_tweets=min_tweets)
	agents = PreProcessing.PreProcessingAgents(part_fun, action_fun, actor_fun_)
	df = PreProcessing.preprocessing(data, agents);

	partitions, actions, actors = Helpers.partitions_actions_actors(df)

	md""" 
	The data is now pre-processed.
	"""
end

# ╔═╡ 30c0bbd9-0f54-4438-9e4c-464beac97c1e
md"""
## Some statistics on the dataset :

Here is the distribution of the number of tweets per actors, per partition :
"""

# ╔═╡ d6223bf9-d771-48e6-ab79-6190cc812d6a
begin
	Visualizations.plot_actor_frequency(df)
end

# ╔═╡ 7ba3305e-d040-4caf-984d-b32c4062a91b
md"""
Here, the actors with the most followers are presented. Their size depends on 
the log of their number of followers.
"""

# ╔═╡ cf940b57-849f-4976-920f-37acc38abc97
begin
	Visualizations.plot_actor_wordcloud(df, Nactor=300)
end

# ╔═╡ 91772531-105c-4ce8-aad3-5f3bd2b5b83c
md"""
	Finally we show the number of tweets by action, per partition.
	"""

# ╔═╡ 9326b201-85c7-4aaa-8df3-2bd9eec76d6e
begin
	Visualizations.plot_action_frequency(df)
end

# ╔═╡ 80891328-ab47-4b56-a482-ec35cb763add
begin
	function time_input(directions::Vector{String})
	
		return PlutoUI.combine() do Child
		
			inputs = [
				md""" $(directions[1]): $(
				Child(directions[1], Slider(0:10, default=2, show_value=true)))
				""",
				md""" $(directions[2]): $(
				Child(directions[2], Slider(0:5:60, default=0, show_value=true)))
				"""
		]
		
		md"""
		Choose the time resolution to construct the time series:
		$(inputs) \
		"""
		end
	end
	
	md"""
	## Now, in term of influence
	
	$(@bind time time_input(["Hours", "Minutes"]))

	Choose the coupling inference method you want to use along with some of its parameters:  

	Inference method: $(@bind inference_method Select(["TE", "JDD"], default="TE")) \
	Number of surrogates: $(@bind Nsurro Slider(10:10:200, default=100, show_value=true))
	"""
end

# ╔═╡ a7d3259b-f540-4e63-bd80-002087535434
begin
	total_min = time[1]*60 + time[2]

	cuttoff = 0.
	standardize = inference_method == "JDD" ? true : false
	method_map = Dict("TE" => Sensors.SimpleTE, "JDD" => Sensors.JointDistanceDistribution)
	
	tsg = Sensors.TimeSeriesGenerator(Minute(total_min), standardize=standardize)
	ig = Sensors.InfluenceGraphGenerator(method_map[inference_method], Nsurro=Nsurro)
	icg = Sensors.InfluenceCascadeGenerator(cuttoff)
	pipeline = Sensors.Pipeline(tsg, ig, icg)
	nothing

end

# ╔═╡ de10fa0e-2f67-41f5-bcaa-e4fbc2c24582
begin
	# Need to be in a different cell than the initialization of the influence graph generator to avoid issues of world age (https://docs.julialang.org/en/v1/manual/methods/#Redefining-Methods  & https://discourse.julialang.org/t/world-age-problem-explanation/9714/4). Indeed Pluto seem to force a cell to run in a single world age without going back to the global scope.
	influence_graphs, influence_cascades = Sensors.observe(df, pipeline)

	
	edge_types = [string(n1, " to ", n2) for n1 in actions for n2 in actions]
	push!(edge_types, "Any Edge")

	md"""
	The influence graphs and cascades are now computed.

	Choose the partition to use to show the influence graph and influence cascades: $(@bind partition Select(partitions))

	Additionally, choose the type of edge to plot between actors in the influence graph: $(@bind edge_type Select(edge_types, default="Any Edge"))
	"""
end

# ╔═╡ 2f95e8f5-7a66-4134-894d-9b4a05cc8006
begin
	
	partition_index = findfirst(partition .== partitions)

	Visualizations.plot_graph(influence_graphs, df, partition, cuttoff, edge_type=edge_type, print_node_names=false)
	
end

# ╔═╡ 3906fdb1-856c-4e39-af2f-83e67960d68f
md"""
Here are the influence cascades :
"""

# ╔═╡ f1899f0e-4b9a-4abf-a495-c36a2c8815d4
begin
	influencer_indices = [ic.root for ic in influence_cascades[partition_index]]
	influencers = actors[partition_index][influencer_indices]

	if isempty(influencers)
		md"""
		There are no influence cascades.
		"""
	elseif length(influencers) == 1
		md"""
		Here is the only influence cascade from $(influencers[1]) :
		"""
	else
		md"""
		Choose the two influence cascades you would like to compare:\
		$(@bind influencer_node1 Select(influencers, default=influencers[1]))	
		$(@bind influencer_node2 Select(influencers, default=influencers[2]))
		"""
	end
end

# ╔═╡ 7defe873-ab21-429d-becc-872af5cf3ec1
begin
	if isempty(influencers)
		nothing
	elseif length(influencers) == 1
		PlutoPlotly.plot(Visualizations.plot_cascade_sankey(influence_cascades[partition_index][1], df)...)
	else
		PlutoPlotly.plot(Visualizations.plot_cascade_sankey(
			influence_cascades[partition_index][findfirst(influencer_node1 .== influencers)], df)...)
	end
end

# ╔═╡ 241a7b87-0ab9-47be-8b78-f141b6e6fd6e
begin
	if length(influencers) > 1
		PlutoPlotly.plot(Visualizations.plot_cascade_sankey(
				influence_cascades[partition_index][findfirst(influencer_node2 .== influencers)], df)...)
	end
end

# ╔═╡ 6847306d-fd38-4f37-81a9-604d03b57ff9
md"""
## Some statistics on the influence cascades

Here is the mean number of actors involved at each level of the cascades,
per partition :
"""

# ╔═╡ d478ea37-41dd-40a2-ba69-f40927b3aaf8
begin
	if all(isempty(cascade) for cascade in influence_cascades)
		nothing
	else
		Visualizations.plot_actors_per_level(influence_cascades, df)
	end
end

# ╔═╡ Cell order:
# ╟─1e33f69e-247c-11ed-07ff-e9204ff08266
# ╟─e8ebe45d-1e7d-433c-93cd-50407798e06e
# ╟─e24ba873-cbb3-4823-be27-e9dfb2d8db89
# ╟─7286c17d-87e2-44a1-8a31-ad0d77e24838
# ╟─30c0bbd9-0f54-4438-9e4c-464beac97c1e
# ╟─d6223bf9-d771-48e6-ab79-6190cc812d6a
# ╟─7ba3305e-d040-4caf-984d-b32c4062a91b
# ╟─cf940b57-849f-4976-920f-37acc38abc97
# ╟─91772531-105c-4ce8-aad3-5f3bd2b5b83c
# ╟─9326b201-85c7-4aaa-8df3-2bd9eec76d6e
# ╟─604da907-49cd-4027-9b7e-285908d68af7
# ╟─80891328-ab47-4b56-a482-ec35cb763add
# ╟─a7d3259b-f540-4e63-bd80-002087535434
# ╟─de10fa0e-2f67-41f5-bcaa-e4fbc2c24582
# ╟─2f95e8f5-7a66-4134-894d-9b4a05cc8006
# ╟─3906fdb1-856c-4e39-af2f-83e67960d68f
# ╟─f1899f0e-4b9a-4abf-a495-c36a2c8815d4
# ╟─7defe873-ab21-429d-becc-872af5cf3ec1
# ╟─241a7b87-0ab9-47be-8b78-f141b6e6fd6e
# ╟─6847306d-fd38-4f37-81a9-604d03b57ff9
# ╟─d478ea37-41dd-40a2-ba69-f40927b3aaf8
