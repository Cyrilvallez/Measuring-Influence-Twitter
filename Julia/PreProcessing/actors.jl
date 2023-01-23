using DataFrames, SparseArrays

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


function IP_graph(df, min_tweets::Int = 2)

    tweeters = df[df.effective_category .== "tweet", :]
    retweeters = df[df.effective_category .== "retweet", :]

    tweet_count = combine(groupby(tweeters, "username"), "created_at" => length => "count")
    tweet_count = tweet_count[tweet_count.count .>= min_tweets, :]
    nodes = tweet_count.username
    Q = tweet_count.count
    S = zeros(length(Q), length(Q))

    for (i, author1) in enumerate(nodes)
        indices = findall(retweeters.retweet_from .== author1)
        names = retweeters.username[indices]

        for (j, author2) in enumerate(nodes)

			# We do not allow self loops
			if i != j
                S[i, j] = sum(names .== author2)
			end

        end

    end

    # Matrix-vector division divides row-wise 
    weights = S ./ Q
	# Some edges may be bigger than 1 if someone retweeted older tweets along with new ones. In this case set it back to 1
	weights[weights .> 1] .= 1

    sum_ = sum(weights, dims=1)
    # The broadcasting is in the correct dimensions
    u = weights ./ ifelse.(sum_ .!= 0, sum_, ones(size(sum_)))

    weights_opposed = 1 .- weights
    # Set all non-existing edges back to 0 so that they do not contribute to the sum
    weights_opposed[weights .== 0] .= 0
    sum_ = sum(weights_opposed, dims=2)
    v = weights_opposed ./ ifelse.(sum_ .!= 0, sum_, ones(size(sum_)))

    # Convert to sparse matrices for later efficient computation
    # Note that it was not done before because of the setindex operations (which are costly for sparse arrays)
    weights = sparse(weights)
    u = sparse(u)
    v = sparse(v)

    return weights, u, v, nodes

end


function IP_scores(u, v, max_iter::Int = 200, max_residual::Real = 1e-3)

    # Set singleton dimensions for correct broadcast later
    I_old = ones(size(u)[1], 1)
    P_old = ones(1, size(u)[1])
	I = ones(size(u)[1], 1)
    P = ones(1, size(u)[1])

	count = 0
    residual = Inf
	residuals = []

    while count < max_iter && residual > max_residual
		# Update based on I{i-1} and P{i}. Note that the update of I is with current value of P, not old.
        P = sum(v .* I_old, dims=1)
        I = sum(u .* P, dims=2)

		# Normalize the vectors
        P = P ./ sum(P)
        I = I ./ sum(I)

		count += 1
		residual = sum(abs.(I_old .- I)) + sum(abs.(P_old .- P))
        push!(residuals, residual)

		P_old = P
		I_old = I
    end

	I = reshape(I, :)
	P = reshape(P, :)

	return I, P, residuals

end