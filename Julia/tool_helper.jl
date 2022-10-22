using URIs
include("Sensors/TopicClusterer/TrainValidate.jl")
include("Sensors/CascadeClusterer/CascadeCluster.jl")

tc = TopicClusterer(x->rand_time_embedding(x;col=:Title), (x, ε, minpts)->Clustering.dbscan(x, ε, min_cluster_size=minpts))

## Partition functions
begin
	function sentiment(df)
		df.partition = df.Sentiment
		return df
	end

	function no_partition(df)
		df.partition = ["Full dataset" for i = 1:length(df[:,1])]
		return df
	end
end

partition_options = [ 
	sentiment,
	no_partition
]

## Actor Agregators
begin
	function author_first_letter(df)
	    df.actor = lowercase.(SubString.(df.Author, 1, 1))
	    return df
	end
	function country(df)
		df = df[.!ismissing.(df."Country Code"), :]
		df.actor = df."Country Code"
		return df
	end
end

actor_options = [
	author_first_letter,
	country
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

		score = CSV.read("../../Data/BrandWatch/news_table-v1-UT60-FM5.csv", DataFrame; header=1)
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
	isin(s::AbstractString, vector::AbstractVector) 

Returns the first element of `vector` which is a substring of `s`.
If there are none, returns `missing`.

# Arguments
- `s::AbstractString` : the principal string 
- `vector::AbstractVector` : the vector of potential substring
"""
function isin(s::AbstractString, vector::AbstractVector) 
    for s_ in vector
        if occursin(s_, s)
            return s_
        end
    end
    return missing
end
