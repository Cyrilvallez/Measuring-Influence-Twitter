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
	decide = x -> x < Date(2021, 10, 31) ? "Before COP26" : (x > Date(2021, 11, 13) ? "After COP26" : "During COP26")
	df.partition = decide.(df."created_at")
	return df
end



"""
Partition data based on the relative date of COP27.
"""
function cop_27_dates(df::DataFrame)
	decide = x -> x < Date(2022, 11, 6) ? "Before COP27" : (x > Date(2022, 11, 19) ? "After COP27" : "During COP27")
	df.partition = decide.(df."created_at")
	return df
end



"""
Partition data based on the relative date of COP27.
"""
function skripal_dates(df::DataFrame)
	decide = x -> x < Date(2018, 03, 18) ? "Before campaign" : (x > Date(2018, 04, 25) ? "After campaign" : "During campaign")
	df.partition = decide.(df."created_at")
	return df
end



partition_options = [ 
    no_partition,
	sentiment,
	cop_26_dates,
	cop_27_dates,
	skripal_dates
]
