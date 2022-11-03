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

# ╔═╡ 088847ef-2235-4f5e-99ca-5898f9ba8960
begin
	datafolder = "../../Data/Twitter/"


	if isempty(datafiles)
		data = load_json(datafolder * "all_links_processed.json")
	else
		frames = [load_json(datafolder * file) for file in datafiles]
		data = vcat(frames...)
	end

	data = data[.~ismissing.(data."urls"), :]

	md"""
	Select all the data files :
	$(@bind datafiles MultiSelect([file for file in readdir(datafolder) if occursin("processed.json", file)]))
	"""
end

# ╔═╡ f5c7e964-3f9b-4837-8111-d5a61ec20158
begin
	md"""
		fuck you bitch
	"""
end

# ╔═╡ Cell order:
# ╠═088847ef-2235-4f5e-99ca-5898f9ba8960
# ╠═f5c7e964-3f9b-4837-8111-d5a61ec20158
