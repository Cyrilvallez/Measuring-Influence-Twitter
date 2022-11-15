using DataFrames, Dates

"""
Return the same partition for every tweet, thus do not actually partition the data.
"""
function no_partition(df::DataFrame)
	df.partition = ["Full dataset" for i = 1:length(df[:,1])]
	return df
end



"""
Partition data based on the sentiment of the tweets.
"""
function sentiment(df::DataFrame)
	df.partition = df.sentiment
	return df
end



"""
Partition data based on the relative date of COP26.
"""
function cop_26_dates(df::DataFrame)
	decide = x -> x < Date(2021, 10, 31) ? "Before COP26" : (x > Date(2021, 11, 12) ? "After COP26" : "During COP26")
	df.partition = decide.(df."created_at")
	return df
end



partition_options = [ 
    no_partition,
	sentiment,
	cop_26_dates
]
