using DataFrames


"""
Returns the same partition for every tweet, thus do not actually partitions the data.
"""
function no_partition(df::DataFrame)
	df.partition = ["Full dataset" for i = 1:length(df[:,1])]
	return df
end



"""
Partitions data based on the sentiment of the tweets.
"""
function sentiment(df::DataFrame)
	df.partition = df.sentiment
	return df
end



"""
Partitions data based on the event.
"""
function event(df::DataFrame)
	decide = x -> x > Date(2022) ? "No event" : "COP26"
	df.partition = decide.(df."created_at")
	return df
end



partition_options = [ 
    no_partition,
	sentiment,
	event
]