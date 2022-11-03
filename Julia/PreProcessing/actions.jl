using DataFrames
using CSV
using URIs

# Relative path to the news table csv files
# This way the paths are correct from whenever this file is read
CURRENT_FOLDER = dirname(dirname(@__DIR__))
NEWS_TABLE_RAW = CURRENT_FOLDER * "/Data/news_table-v1-UT60-FM5.csv"
NEWS_TABLE_PROCESSED = CURRENT_FOLDER * "/Data/news_table_clean.csv"



"""
Returns the TUFM classification from the news table.

WARNING : Old version, works with ICE data but not Twitter climate data.
"""
function trust_popularity_score_old(df::DataFrame)

	score = CSV.read(NEWS_TABLE_RAW, DataFrame, header=1)
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
    df = df[.!ismissing.(df."News domain"), :]
	# retrieve action from the table and explicitly convert to String
	# because String3 is not valid later on
	df.action = String.([score."tufm_class"[findfirst(domain .== score."Domain")] 
		for domain in df."News domain"])

	return df
end



"""
Returns the TUFM classification from the news table.
"""
function trust_popularity_score(df::DataFrame)

	news = CSV.read(NEWS_TABLE_PROCESSED, DataFrame, header=1)

	df."full_domain" = [[domain[i] * "." * suffix[i] for i in 1:length(domain)] for (domain, suffix) in zip(df."domain", df."domain_suffix")]
	# Find score associated to urls contained in the news outlets
    df.action = classify.(df."full_domain", Ref(news))
	# remove news source not matching one of the source news table
    df = df[.!ismissing.(df.action), :]
	# Remove the Union{missing, String}
	df.action = String.(df.action)
	return df
end



action_options = [
	trust_popularity_score_old,
	trust_popularity_score,
]



# Miscellaneous helper functions

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
function classify(urls::Vector{String}, news_outlet::DataFrame)
    for url in urls
		index = findfirst(url .== news_outlet."domain")
        if !isnothing(index)
            return news_outlet."tufm_class"[index]
		end
	end
    return missing
end
