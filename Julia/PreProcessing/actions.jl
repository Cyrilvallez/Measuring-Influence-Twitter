using DataFrames
using CSV
using URIs

# Relative path to the news table csv files
# This way the paths are correct from whenever this file is read
PROJECT_FOLDER = dirname(dirname(@__DIR__))
NEWS_TABLE_TUFM = PROJECT_FOLDER * "/Data/news_table_clean.csv"
FULL_NEWSGUARD_TABLE = PROJECT_FOLDER * "/Data/newsguard_full_table_clean.csv"



"""
Return the trustworthy/untrustworthy category from the newsguard classification.
"""
function trust_score(df::DataFrame)

	news = CSV.read(FULL_NEWSGUARD_TABLE, DataFrame, header=1)

	# Find score associated to urls contained in the news outlets
    df.action = classify.(df."domain", Ref(news))
	# remove news source not matching one of the source news table
    df = df[.!ismissing.(df.action), :]

	# convert to String
	df.action = string.(df.action)
	return df
end



"""
Return the TUFM classification from the news table.
"""
function trust_popularity_score(df::DataFrame)

	news = CSV.read(NEWS_TABLE_TUFM, DataFrame, header=1)

	# Find score associated to urls contained in the news outlets
    df.action = classify.(df."domain", Ref(news), "tufm_class")
	# remove news source not matching one of the source news table
    df = df[.!ismissing.(df.action), :]
	# Remove the Union{missing, String}
	df.action = String.(df.action)
	return df
end



"""
Return the mainstream/fringe portion of the tufm category from the news table.
"""
function mainstream_score(df::DataFrame)

	news = CSV.read(NEWS_TABLE_TUFM, DataFrame, header=1)

	# Find score associated to urls contained in the news outlets
    class = classify.(df."domain", Ref(news), "tufm_class")
	df.action = [ismissing(a) ? missing : a[2] for a in class]
	# remove news source not matching one of the source news table
    df = df[.!ismissing.(df.action), :]

	# convert to String
	df.action = string.(df.action)
	return df
end



action_options = [
	trust_popularity_score,
	trust_score,
	mainstream_score
]



# Miscellaneous helper functions

""" 
Return the first element of `vector` which is a substring of `s`.
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
Return the `class_column` of the first element of `domains` which is contained in `news_outlet`.
If there are none, returns `missing`.
"""
function classify(domains::Vector, news_outlet::DataFrame, class_column::AbstractString = "class")
    for domain in domains
		index = findfirst(domain .== news_outlet."domain")
        if !isnothing(index)
            return news_outlet[!, class_column][index]
		end
	end
    return missing
end

	
