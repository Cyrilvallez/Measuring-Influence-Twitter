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
	import PlutoPlotly
	include("../Sensors/sensors.jl")
	include("../PreProcessing/preprocessing.jl")
	include("../helpers.jl")
	include("../visualizations.jl");
end;

# ╔═╡ e8ebe45d-1e7d-433c-93cd-50407798e06e
begin
	datafolder = "../../Data/Twitter/"

	md"""
	## Load the data
	
	Select all the data files you want to use :
	$(@bind datafiles MultiSelect([file for file in readdir(datafolder) if occursin("processed", file)]))
	"""
end

# ╔═╡ 7c344844-5e28-4d10-850b-10697ea64c68
begin
	
	if isempty(datafiles)
		datafolder2 = joinpath(datafolder, "COP26_processed_lightweight")
		frames = [load_json(joinpath(datafolder2, file)) for file in 				readdir(datafolder2) if occursin(".json", file)]
		data = vcat(frames...)
	elseif length(datafiles) == 1 && isdir(datafiles[1])
		frames = [load_json(joinpath(datafolder, datafiles[1], file)) for file in 	readdir(datafiles[1]) if occursin(".json", file)]
		data = vcat(frames...)
	else
		frames = [load_json(datafolder * file) for file in datafiles]
		data = vcat(frames...)
	end

	data = data[.~ismissing.(data."domain"), :]
	
	to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
	data."created_at" = to_datetime.(data."created_at")

end;

# ╔═╡ e24ba873-cbb3-4823-be27-e9dfb2d8db89
begin
		
	md"""
	## Defining Investigation Scope
	
	Choose the way to identify the data partition: $(@bind part_fun Select(partition_options, default=cop_26_dates))
	
	Choose the way to define actor groups: $(@bind actor_fun Select(actor_options,
	default=follower_count))
	
	Choose the way to define distinct action types: $(@bind action_fun Select(action_options, default=trust_score))
	"""
end

# ╔═╡ 7286c17d-87e2-44a1-8a31-ad0d77e24838
begin

	df = data |> part_fun |> action_fun |> actor_fun

	actions = sort(unique(df.action))
	actors = sort(unique(df.actor))
	partitions = sort(unique(df.partition))

	md""" 
	The data is now pre-processed.
	"""
end

# ╔═╡ 30c0bbd9-0f54-4438-9e4c-464beac97c1e
md"""
## Some statistics on the Dataset :

The dataset consists of $(length(df."username")) tweets, from $(length(actors)) unique actors. The tweets are split in
$(length(partitions)) different partitions.

Here is the number of tweets per actors, per partition :
"""

# ╔═╡ d6223bf9-d771-48e6-ab79-6190cc812d6a
begin
	plot_actor_frequency(df)
end

# ╔═╡ 7ba3305e-d040-4caf-984d-b32c4062a91b
md"""
Here, the actors with the most followers are presented. Their size depends on 
the log of their number of followers.
"""

# ╔═╡ cf940b57-849f-4976-920f-37acc38abc97
begin
	plot_actor_wordcloud(df, Nactor=300)
end

# ╔═╡ 91772531-105c-4ce8-aad3-5f3bd2b5b83c
md"""
	Here we show the number of tweets by action, per partition.
	"""

# ╔═╡ 9326b201-85c7-4aaa-8df3-2bd9eec76d6e
begin
	plot_action_frequency(df)
end

# ╔═╡ 80891328-ab47-4b56-a482-ec35cb763add
begin
	function time_input(directions::Vector{String})
	
		return PlutoUI.combine() do Child
		
			inputs = [
				md""" $(directions[1]): $(
				Child(directions[1], Slider(0:10, default=5, show_value=true)))
				""",
				md""" $(directions[2]): $(
				Child(directions[2], Slider(0:5:60, default=0, show_value=true)))
				"""
		]
		
		md"""
		Choose the time resolution to construct the time series:
		$(inputs)
		"""
		end
	end
	
	md"""
	## Now, in term of influence
	
	$(@bind time time_input(["Hours", "Minutes"]))
	"""
end

# ╔═╡ a7d3259b-f540-4e63-bd80-002087535434
begin
	total_min = time[1]*60 + time[2]
	
	clean_dates = x -> floor(x, Dates.Minute(total_min))

	# Set the time column and sort according to it (inplace)
	df.time = clean_dates.(df."created_at")
	
	
	tsg = TimeSeriesGenerator()
	time_series = observe(df, tsg)

	ig = InfluenceGrapher()
	influence_graph = observe(time_series, ig)

	# This needs to be after the creation of the time series (because it sorts the dataframe inplace), thus 
	#actions = unique(df.action)
	#actors = unique(df.actor)
	#partitions = unique(df.partition)

	md"""
	Choose the transfer entropy cuttoff value (above which we will consider influence to occur).  
	Cuttoff: $(@bind cuttoff Slider(0:0.01:4, default=0.5, show_value=true))
	"""
end

# ╔═╡ de10fa0e-2f67-41f5-bcaa-e4fbc2c24582
begin
	icg = InfluenceCascadeGenerator(cuttoff)
	influence_cascades = observe.(influence_graph, Ref(icg))

	edge_types = [string(n1, " to ", n2) for n1 in actions for n2 in actions]
	push!(edge_types, "Any Edge")

	md"""
	The cascades are now computed.

	Choose the partition to use to show the influence graph and influence cascades : $(@bind part Select(partitions))

	Additionally, choose the type of edge to plot between actors in the influence graph : $(@bind edge_type Select(edge_types, default="Any Edge"))
	"""
end

# ╔═╡ 2f95e8f5-7a66-4134-894d-9b4a05cc8006
begin
	function make_simplifier(edge_type)
		if edge_type == "Any Edge"
			return x -> (maximum(x) > cuttoff)
		else
			linear_idx = findfirst(x -> x == edge_type, edge_types)
			N = length(actions)
			matrix_idx_1 = linear_idx ÷ N + 1
			matrix_idx_2 = linear_idx % N
			return x -> (x[matrix_idx_1, matrix_idx_2] > cuttoff)
			#return x->(x[idx]>cuttoff)
		end
	end

	simplifier = make_simplifier(edge_type)

	partition_index = (1:length(partitions))[findfirst(part .== partitions)]
	#xs, ys, influencers = influence_layout(influence_graph[i]; simplifier=s)

	# In this case we plot the graph on a world map
	if actor_fun == country
		PlotlyJS.plot(map_plot(df)...)
	# In this case we plot a simple graph of the actors
	else
		plot_graph(influence_graph[partition_index], df, simplifier=simplifier)
	end
end

# ╔═╡ 3906fdb1-856c-4e39-af2f-83e67960d68f
md"""
Here are the influence cascades :
"""

# ╔═╡ f1899f0e-4b9a-4abf-a495-c36a2c8815d4
begin
	influencer_indices = [ic.root for ic in influence_cascades[partition_index]]
	influencers = actors[influencer_indices]

	if isempty(influencers)
		md"""
		There are no influence cascades.
		"""
	elseif length(influencers) == 1
		md"""
		Here is the only influence cascade :
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
		PlutoPlotly.plot(plot_cascade_sankey(influence_cascades[partition_index][1], df)...)
	else
		[PlutoPlotly.plot(plot_cascade_sankey(
			influence_cascades[partition_index][findfirst(influencer_node1 .== influencers)], df)...),
		
		PlutoPlotly.plot(plot_cascade_sankey(
			influence_cascades[partition_index][findfirst(influencer_node2 .== influencers)], df)...)
		]
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
		plot_actors_per_level(influence_cascades, df)
	end
end

# ╔═╡ Cell order:
# ╟─1e33f69e-247c-11ed-07ff-e9204ff08266
# ╠═e8ebe45d-1e7d-433c-93cd-50407798e06e
# ╠═7c344844-5e28-4d10-850b-10697ea64c68
# ╠═e24ba873-cbb3-4823-be27-e9dfb2d8db89
# ╠═7286c17d-87e2-44a1-8a31-ad0d77e24838
# ╟─30c0bbd9-0f54-4438-9e4c-464beac97c1e
# ╟─d6223bf9-d771-48e6-ab79-6190cc812d6a
# ╟─7ba3305e-d040-4caf-984d-b32c4062a91b
# ╟─cf940b57-849f-4976-920f-37acc38abc97
# ╟─91772531-105c-4ce8-aad3-5f3bd2b5b83c
# ╟─9326b201-85c7-4aaa-8df3-2bd9eec76d6e
# ╠═80891328-ab47-4b56-a482-ec35cb763add
# ╠═a7d3259b-f540-4e63-bd80-002087535434
# ╠═de10fa0e-2f67-41f5-bcaa-e4fbc2c24582
# ╠═2f95e8f5-7a66-4134-894d-9b4a05cc8006
# ╟─3906fdb1-856c-4e39-af2f-83e67960d68f
# ╟─f1899f0e-4b9a-4abf-a495-c36a2c8815d4
# ╟─7defe873-ab21-429d-becc-872af5cf3ec1
# ╟─6847306d-fd38-4f37-81a9-604d03b57ff9
# ╟─d478ea37-41dd-40a2-ba69-f40927b3aaf8
