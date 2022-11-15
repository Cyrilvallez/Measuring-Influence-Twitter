using DataFrames

"""
Define actor as countries, using the country_code in the tweeets.
"""
function country(df::DataFrame)
	df = df[.!ismissing.(df."country_code"), :]
	df.actor = df."country_code"
	return df
end



"""
Define actor using the number of followers of each individual in the dataset.  
The first N=500 individuals with most followers will be treated as individual actors,  
while the other ones will be aggregated in bins of 10,000 people.
"""
function follower_count(df::DataFrame)

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



"""
Define actor using the username in the tweets, thus every people in the dataset is a different actor.
"""
function username(df::DataFrame)
	df."actor" = df."username"
	return df
end



actor_options = [
	country,
	follower_count,
	username
]

