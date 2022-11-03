using URIs
import JSON
include("Sensors/CascadeClusterer/CascadeCluster.jl")

## Partition functions
begin
	function sentiment(df)
		df.partition = df.sentiment
		return df
	end

	function no_partition(df)
		df.partition = ["Full dataset" for i = 1:length(df[:,1])]
		return df
	end

	function event(df)
		decide = x -> x > Date(2022) ? "No event" : "COP26"
		df.partition = decide.(df."created_at")
		return df
	end
end

partition_options = [ 
	sentiment,
	no_partition,
	event
]

## Actor Agregators
begin
	function author_first_letter(df)
	    df.actor = lowercase.(SubString.(df.username, 1, 1))
	    return df
	end

	function country(df)
		df = df[.!ismissing.(df."country_code"), :]
		df.actor = df."country_code"
		return df
	end

	function follower_count(df)

		# Get indices resulting on the unique values of df."username"
		x = df."username"
		indices = unique(i -> x[i], 1:length(x))
		# Get unique usernames and corresponding follower_count
		users = x[indices]
		followers = df."follower_count"[indices]

		# sort the users in desending order of follower_count
		sorting = sortperm(followers, rev=true)
		followers = followers[sorting]
		users = users[sorting]

		M = length(users)
		actors = Vector{String}(undef, M)
		N = 500
		for i = 1:N
			actors[i] = users[i]
		end

		L = 10000
		N += 1
		while true
			if N + L <= M
				actors[N:(N+L)] .= "$(followers[N]) to $(followers[N+L]) followers"
			else
				actors[N:end] .= "$(followers[N]) to $(followers[end]) followers"
				break
			end
			N += L
		end

		actor_dict = Dict(zip(users, actors))
		df = transform(df, "username" => ByRow(x -> actor_dict[x]) => "actor")
		return df
	end

	function username(df)
		df."actor" = df."username"
		return df
	end

end

actor_options = [
	author_first_letter,
	country,
	follower_count,
	username
]

## Action Labeler
begin

	function topic_discussed(df)
		df.action = df."Full Text" .|> x -> occursin("war", x) ? "war" : (occursin("economy", x)
		? "economy" : "other")
		return df
	end

	function secure_url(df)
	    df.action = SubString.(df."Expanded URLs", 5, 5) .|> x -> x == "s" ? "Secure" : "Insecure"    
	    return df
	end

	function trust_popularity_score(df)

		score = CSV.read("../../Data/news_table-v1-UT60-FM5.csv", DataFrame; header=1)
		score = score[score."tufm_class" .!= "0", :]
		# get host name from the expanded url
		df."News host domain" = df."Expanded URLs" .|> x -> URI(x).host

		# Match the source host name with those of the news outlet table
		# It needs to be done this way since there are possible subdomain
		# in the host name that cannot be removed with a general rule,
		# thus we need to look for substrings instead of string equality
		# e.g `www.cnn.com` and `info.cnn.com` must both match `cnn.com`
    	df."News domain" = isin.(df."News host domain", Ref(score."Domain"))

		# remove news source not matching one of the source news table
    	df = df[.~ismissing.(df."News domain"), :]
		# retrieve action from the table and explicitly convert to String
		# because String3 is not valid later on
		df.action = String.([score."tufm_class"[findfirst(domain .== score."Domain")]
			for domain in df."News domain"])
		return df
	end


	function trust_popularity_score_v2(df)

		news = CSV.read("../../Data/news_table_clean.csv", DataFrame; header=1)

		df."full_domain" = [[domain[i] * "." * suffix[i] for i in 1:length(domain)] for (domain, suffix) in zip(df."domain", df."domain_suffix")]
		# Find score associated to urls contained in the news outlets
    	df.action = class.(df."full_domain", Ref(news))
		# remove news source not matching one of the source news table
    	df = df[.~ismissing.(df.action), :]
		# Remove the Union{missing, String}
		df.action = String.(df.action)
		return df
	end


	function naive_tufm(df)

		function classify(domain_list)
			for domain in domain_list
				if domain == "cnn"
					return "TM"
				elseif domain == "foxnews"
					return "UM"
				elseif domain == "greenpeace"
					return "TF"
				elseif domain == "permianproud"
					return "UF"
				else
					continue
				end
			end
			return "0"
		end

		df.action = df."domain" .|> classify
		df = df[df.action .!= "0", :]
		return df
	end

end

action_options = [
	secure_url,
	topic_discussed,
	trust_popularity_score,
	trust_popularity_score_v2,
	naive_tufm
]


## Cascade Embedding Method

begin

end

casc_emb_options = [
	naive_embedding,
	stupid_embedding
]


## Cascade Clustering Methods
begin
	function dbscan_clusterer(x; eps=0.005, minpts=10)
		x = transpose(reshape(vcat(transpose.(x)...),(length(x), length(x[1]))))
		return [c.core_indices for c in Clustering.dbscan(x, eps, min_cluster_size=minpts)]
	end
end

casc_clust_options = [
	dbscan_clusterer
]



## Miscellaneous helper function
""" 
Returns the first element of `vector` which is a substring of `s`.
If there are none, returns `missing`.
"""
function isin(s::AbstractString, vector::AbstractVector) 
    for s_ in vector
        if occursin(s_, s)
            return s_
        end
    end
    return missing
end


"""
Returns the tufm class of the first element of `urls` which is contained in `news_outlet`.
If there are none, returns `missing`.
"""
function class(urls::Vector{String}, news_outlet::DataFrame)
    for url in urls
		index = findfirst(url .== news_outlet."domain")
        if !isnothing(index)
            return news_outlet."tufm_class"[index]
		end
	end
    return missing
end





"""
    load_json(filename::String, to_df::Bool = true, skiprows::Int = 0)

Conveniently load a file containing lines of json objects into a DataFrame (or as a list of dictionaries).
"""
function load_json(filename::String, to_df::Bool = true, skiprows::Int = 0)

    lines = readlines(filename)
    dics = [JSON.parse(line, null=missing) for line in lines[(skiprows+1):end]]

    if to_df
        return DataFrame(dics)
    else
        return dics
    end
end