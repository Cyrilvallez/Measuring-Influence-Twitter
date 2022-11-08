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
	$(@bind datafiles MultiSelect([file for file in readdir(datafolder) if occursin("processed.json", file)]))
	"""
end

# ╔═╡ 7c344844-5e28-4d10-850b-10697ea64c68
begin
	
	if isempty(datafiles)
		data = load_json(datafolder * "all_links_processed.json")
	else
		frames = [load_json(datafolder * file) for file in datafiles]
		data = vcat(frames...)
	end

	data = data[.~ismissing.(data."urls"), :]
	
	to_datetime = x -> DateTime(split(x, '.')[1], "yyyy-mm-ddTHH:MM:SS")
	data."created_at" = to_datetime.(data."created_at")

end;

# ╔═╡ e24ba873-cbb3-4823-be27-e9dfb2d8db89
begin
		
	md"""
	## Defining Investigation Scope
	
	Choose the way to identify the data partition: $(@bind part_fun Select(partition_options))
	
	Choose the way to define actor groups: $(@bind actor_fun Select(actor_options,
	default=follower_count))
	
	Choose the way to define distinct action types: $(@bind action_fun Select(action_options, default=trust_popularity_score_v2))
	"""
end

# ╔═╡ 7286c17d-87e2-44a1-8a31-ad0d77e24838
begin

	df = data |> part_fun |> action_fun |> actor_fun

	md""" 
	The data is now pre-processed.
	"""
end

# ╔═╡ 30c0bbd9-0f54-4438-9e4c-464beac97c1e
md"""
## Some statistics on the Dataset :

The dataset consists of $(length(df."username")) tweets, from $(length(unique(df."actor"))) unique actors. The tweets are split in
$(length(unique(df."partition"))) different partitions.

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

	edgeTypes = push!([string(n1," to ", n2) for n1 in unique(df[!, tsg.action_col]) for n2 in unique(df[!, tsg.action_col])], "Any Edge")

	md"""
	Choose the transfer entropy cuttoff value (above which we will consider influence to occur) and the type of edge to plot between actors:  
	
	Cuttoff:   $(@bind cuttoff Slider(0:0.01:4, default=0.5, show_value=true))\
	Edge type: $(@bind et Slider(edgeTypes, show_value=true, default="Any Edge"))\
	
	Choose the partition to look at:
	$(@bind part Slider(unique(df[!,tsg.part_col]), show_value=true))
	"""
end

# ╔═╡ 2f95e8f5-7a66-4134-894d-9b4a05cc8006
begin
	function make_simplifier(edge_type)
		if edge_type=="Any Edge"
			return x->(maximum(x)>cuttoff)
		else
			idx = findfirst(x->(x==et), edgeTypes)
			return x->(x[idx]>cuttoff)
		end
	end
	s = make_simplifier(et)

	icg = InfluenceCascadeGenerator(cuttoff)
	influence_cascades = observe.(influence_graph, Ref(icg))
	all_ics = vcat(influence_cascades...)

	partitions = unique(df[!,tsg.part_col])
	i = (1:length(partitions))[findfirst(x->x==part, partitions)]
	xs, ys, influencers = influence_layout(influence_graph[i]; simplifier=s)
	g = print_graph(influence_graph[i]; simplifier=s)

	# In this case we plot the graph on a world map
	if actor_fun == country
		PlotlyJS.plot(map_plot(df)...)
	# In this case we plot a simple graph of the actors
	else
		gplot(g, xs, ys, nodelabel=unique(df.actor), nodelabelc=colorant"white",
		NODESIZE=0.02, nodelabeldist=5)
	end
end

# ╔═╡ 3906fdb1-856c-4e39-af2f-83e67960d68f
md"""
Here are the influence cascades :
"""

# ╔═╡ f1899f0e-4b9a-4abf-a495-c36a2c8815d4
begin
	infl = unique(df.actor)[influencers]

	if isempty(infl)
		md"""
		There are no influence cascades.
		"""
	elseif length(infl) == 1
		md"""
		Here is the only influence cascade :
		"""
	else
		md"""
		Choose the two influence cascades you would like to compare:\
		$(@bind influencer_node1 Select(infl, default=infl[1]))	
		$(@bind influencer_node2 Select(infl, default=infl[2]))
		"""
	end
end

# ╔═╡ 7defe873-ab21-429d-becc-872af5cf3ec1
begin
	if isempty(infl)
		nothing
	elseif length(infl) == 1
		PlutoPlotly.plot(plot_cascade_sankey(
		influence_cascades[findfirst(x->x==part,unique(df[!, tsg.part_col]))][findfirst(x->x==infl[1], unique(df[!, tsg.actor_col])[influencers])],
		unique(df[!, tsg.action_col]))...)
	else
		[PlutoPlotly.plot(plot_cascade_sankey(
		influence_cascades[findfirst(x->x==part,unique(df[!, tsg.part_col]))][findfirst(x->x==influencer_node1, unique(df[!, tsg.actor_col])[influencers])],
		unique(df[!, tsg.action_col]))...),
		
		PlutoPlotly.plot(plot_cascade_sankey(
		influence_cascades[findfirst(x->x==part,unique(df[!, tsg.part_col]))][findfirst(x->x==influencer_node2, unique(df[!, tsg.actor_col])[influencers])],
		unique(df[!, tsg.action_col]))...)
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
	if isempty(infl)
		nothing
	else
		plot_actors_per_level(influence_cascades, df)
	end
end

# ╔═╡ Cell order:
# ╠═1e33f69e-247c-11ed-07ff-e9204ff08266
# ╠═e8ebe45d-1e7d-433c-93cd-50407798e06e
# ╟─7c344844-5e28-4d10-850b-10697ea64c68
# ╟─e24ba873-cbb3-4823-be27-e9dfb2d8db89
# ╟─7286c17d-87e2-44a1-8a31-ad0d77e24838
# ╟─30c0bbd9-0f54-4438-9e4c-464beac97c1e
# ╟─d6223bf9-d771-48e6-ab79-6190cc812d6a
# ╟─7ba3305e-d040-4caf-984d-b32c4062a91b
# ╟─cf940b57-849f-4976-920f-37acc38abc97
# ╟─91772531-105c-4ce8-aad3-5f3bd2b5b83c
# ╟─9326b201-85c7-4aaa-8df3-2bd9eec76d6e
# ╟─80891328-ab47-4b56-a482-ec35cb763add
# ╟─a7d3259b-f540-4e63-bd80-002087535434
# ╟─2f95e8f5-7a66-4134-894d-9b4a05cc8006
# ╟─3906fdb1-856c-4e39-af2f-83e67960d68f
# ╟─f1899f0e-4b9a-4abf-a495-c36a2c8815d4
# ╟─7defe873-ab21-429d-becc-872af5cf3ec1
# ╟─6847306d-fd38-4f37-81a9-604d03b57ff9
# ╟─d478ea37-41dd-40a2-ba69-f40927b3aaf8
