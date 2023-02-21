using DataFrames, SparseArrays, LinearAlgebra
using Logging


"""
Define actors using the number of followers. If `by_partition` is true, the actors will be defined using data inside each partition independently, 
otherwise using all the dataset provided. Only users with a tweet rate of at least `min_tweets` will be considered. The first `actor_number` users 
with most followers will be treated as individual actors (pass "all" to use each user), while the other ones will be aggregated in bins of size 
`aggregate_size` people.
It returns both a function and a string that will be used for later logging.
"""
function follower_count(; by_partition::Bool = true, min_tweets::Int = 3, actor_number::Union{Int, AbstractString} = 500, aggregate_size::Int = 1000)

	log = "follower_count(by_partition=$by_partition, min_tweets=$min_tweets, actor_number=$actor_number, aggregate_size=$aggregate_size)"

	# Apply the function on each partition
	if by_partition
		func = df -> combine(_follower_count(min_tweets, actor_number, aggregate_size), groupby(df, "partition"))
	# Directly apply the function on whole dataframe
	else
		func = _follower_count(min_tweets, actor_number, aggregate_size)
	end

	return func, log
end



"""
Define actors using the authors of the tweets, thus every user in the dataset is a different actor. If `by_partition` is true, the actors will be defined 
using data inside each partition independently, otherwise using all the dataset provided (the tweet constraint will be required inside each partition).
Only users with a tweet rate of at least `min_tweets` will be considered.
It returns both a function and a string that will be used for later logging.
"""
function all_users(; by_partition::Bool = true, min_tweets::Int = 3)

	log = "all_users(by_partition=$by_partition, min_tweets=$min_tweets)"

	# Apply the function on each partition
	if by_partition
		func = df -> combine(_all_users(min_tweets), groupby(df, "partition"))
	# Directly apply the function on whole dataframe
	else
		func = _all_users(min_tweets)
	end

	return func, log
end



"""
Define actors using the number of retweets. If `by_partition` is true, the actors will be defined using data inside each partition independently, 
otherwise using all the dataset provided. Only users with a tweet rate of at least `min_tweets` will be considered. 
The first `actor_number` users with highest retweet count will be treated as individual actors (pass "all" to use each user, or "all_positive" 
to use each user having non-zero retweet count), while the other ones will be aggregated in bins of size `aggregate_size` people. 
It returns both a function and a string that will be used for later logging.
"""
function retweet_count(; by_partition::Bool = true, min_tweets::Int = 3, actor_number::Union{Int, AbstractString} = 500, aggregate_size::Int = 1000)

	log = "retweet_count(by_partition=$by_partition, min_tweets=$min_tweets, actor_number=$actor_number, aggregate_size=$aggregate_size)"

	# Apply the function on each partition
	if by_partition
		func = df -> combine(_retweet_count(min_tweets, actor_number, aggregate_size), groupby(df, "partition"))
	# Directly apply the function on whole dataframe
	else
		func = _retweet_count(min_tweets, actor_number, aggregate_size)
	end

	return func, log
end



"""
Define actors using the I score (from paper "Influence and Passivity in Social Media"). If `by_partition` is true, the actors will be defined 
using data inside each partition independently, otherwise using all the dataset provided. Only users with a tweet rate of at least `min_tweets` 
will be considered. The first `actor_number` users with highest I score will be treated as individual actors (pass "all" to use each user, 
or "all_positive" to use each user having non-zero I score), while the other ones will be aggregated in bins of size `aggregate_size` people.
It returns both a function and a string that will be used for later logging.
The `max_iter` and `max_residual` parameters are used for the iterative procedure of the algorithm.
"""
function IP_scores(; by_partition::Bool = true, min_tweets::Int = 3, actor_number::Union{Int, AbstractString} = 500, aggregate_size::Int = 1000, max_iter::Int = 200, max_residual::Real = 1e-3)

	log = "IP_scores(by_partition=$by_partition, min_tweets=$min_tweets, actor_number=$actor_number, aggregate_size=$aggregate_size, max_iter=$max_iter, max_residual=$max_residual)"

	# Apply the function on each partition
	if by_partition
		func = df -> combine(_IP_scores(min_tweets, actor_number, aggregate_size, max_iter, max_residual), groupby(df, "partition"))
	# Directly apply the function on whole dataframe
	else
		func = _IP_scores(min_tweets, actor_number, aggregate_size, max_iter, max_residual)
	end

	return func, log
end




actor_options = [
	follower_count,
	all_users,
	retweet_count,
	IP_scores
]






"""
Contain the logic for the follower_count() function.
"""
function _follower_count(min_tweets::Int, actor_number::Union{Int, AbstractString}, aggregate_size::Int)

	possibilities = ["all"]
	if typeof(actor_number) <: AbstractString
		if !(actor_number in possibilities)
			throw(ArgumentError("Actor number must be either a positive integer or one of $possibilities"))
		end
	end

	function _follower_count_wrapped(df)

		# Need to copy it since we will modify it. Otherwise the change is reflected to all subsequent calls of _follower_count_wrapped(df) !!!
		actor_number_ = actor_number

		# Take only users who tweeted more than min_tweets 
		df = df[df.effective_category .== "tweet", :]
		df = transform(groupby(df, "username"), "created_at" => length => "tweet_count")
		df = df[df.tweet_count .>= min_tweets, :]

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

		if typeof(actor_number_) <: Int && actor_number_ > M
			@warn "The actor number you provided is larger than the maximum of possible actors. Setting actor_number back to \"all\"."
			actor_number_ = "all"
		end
		
		if actor_number_ == "all"
			actor_dict = Dict(users .=> users)
		else
			for i = 1:actor_number_
				actors[i] = users[i]
			end

			L = aggregate_size
			N = actor_number_ += 1
			counter = 0
			while true
				counter += 1
				if N + L <= M
					actors[N:(N+L)] .= "AGG$(counter): $(followers[N]) to $(followers[N+L]) followers"
				else
					actors[N:end] .= "AGG$(counter): $(followers[N]) to $(followers[end]) followers"
					break
				end
				N += L
			end

			actor_dict = Dict(users .=> actors)
		end
		
		df = transform(df, "username" => ByRow(x -> actor_dict[x]) => "actor")

		return df

	end

	return _follower_count_wrapped

end



"""
Contain the logic for the all_user() function.
"""
function _all_users(min_tweets::Int = 3)

	function _all_users_wrapped(df)
		# Take only users who tweeted more than min_tweets 
		df = df[df.effective_category .== "tweet", :]
		df = transform(groupby(df, "username"), "created_at" => length => "tweet_count")
		df = df[df.tweet_count .>= min_tweets, :]
		df.actor = df.username
		return df
	end

	return _all_users_wrapped
end



"""
Contain the logic for the retweet_count() function.
"""
function _retweet_count(min_tweets::Int, actor_number::Union{Int, AbstractString}, aggregate_size::Int)

	possibilities = ["all", "all_positive"]
	if typeof(actor_number) <: AbstractString
		if !(actor_number in possibilities)
			throw(ArgumentError("Actor number must be either a positive integer or one of $possibilities"))
		end
	end

	function _retweet_count_wrapped(df)

		# Need to copy it since we will modify it. Otherwise the change is reflected to all subsequent calls of _follower_count_wrapped(df) !!!
		actor_number_ = actor_number

		tweeters = df[df.effective_category .== "tweet", :]
		retweeters = df[df.effective_category .== "retweet", :]

		tweeters = transform(groupby(tweeters, "username"), "created_at" => length => "tweet_count")
		tweeters = tweeters[tweeters.tweet_count .>= min_tweets, :]
		users = unique(tweeters.username)

		rt_count = zeros(size(users))

		for (i, user) in enumerate(users)
			rt_count[i] = sum(retweeters.retweet_from .== user)
		end

		# Add retweet_count to the dataframe
		rt_dic = Dict(users .=> rt_count)
		df = transform(tweeters, "username" => ByRow(x -> rt_dic[x]) => "retweet_count")

		# sort the users in desending order of follower_count
		sorting = sortperm(rt_count, rev=true)
		rt_count = rt_count[sorting]
		users = users[sorting]

		M = length(users)
		actors = Vector{String}(undef, M)

		if typeof(actor_number_) <: Int && actor_number_ > M
			@warn "The actor number you provided is larger than the maximum of possible actors. Setting actor_number back to \"all\"."
			actor_number_ = "all"
		end

		if actor_number_ == "all"
			df.actor = df.username
			return df
		elseif actor_number_ == "all_positive"
			actor_number_ = sum(rt_count .> 0)
		end


		for i = 1:actor_number_
			actors[i] = users[i]
		end

		L = aggregate_size
		N = actor_number_ += 1
		counter = 0
		while true
			counter += 1
			if N + L <= M
				actors[N:(N+L)] .= "AGG$(counter): $(rt_count[N]) to $(rt_count[N+L]) retweets"
			else
				actors[N:end] .= "AGG$(counter): $(rt_count[N]) to $(rt_count[end]) retweets"
				break
			end
			N += L
		end

		actor_dict = Dict(users .=> actors)
		
		df = transform(df, "username" => ByRow(x -> actor_dict[x]) => "actor")

		return df

	end

	return _retweet_count_wrapped

end





"""
Contain the logic for the IP_scores() function.
"""
function _IP_scores(min_tweets::Int, actor_number::Union{Int, AbstractString}, aggregate_size::Int, max_iter::Int, max_residual::Real)

	possibilities = ["all", "all_positive"]
	if typeof(actor_number) <: AbstractString
		if !(actor_number in possibilities)
			throw(ArgumentError("Actor number must be either a positive integer or one of $possibilities"))
		end
	end

	function _IP_scores_wrapped(df)

		# Need to copy it since we will modify it. Otherwise the change is reflected to all subsequent calls of _follower_count_wrapped(df) !!!
		actor_number_ = actor_number

		weights, u, v, nodes = compute_IP_graph(df, min_tweets=min_tweets)
		I, P, residuals = compute_IP_scores(u, v, max_iter=max_iter, max_residual=max_residual)

		# Pick only tweets by the users considered by the IP scores and discard the others
		isin = (x,y) -> x in y
		df = df[isin.(df.username, Ref(nodes)), :]
		df = df[df.effective_category .== "tweet", :]

		sorting = sortperm(I, rev=true)
		nodes = nodes[sorting]
		I = I[sorting]
		P = P[sorting]

		# Add scores to the dataframe
		I_dict = Dict(nodes .=> I)
		P_dict = Dict(nodes .=> P)
		df = transform(df, "username" => ByRow(x -> I_dict[x]) => "I_score")
		df = transform(df, "username" => ByRow(x -> P_dict[x]) => "P_score")


		M = length(nodes)
		actors = Vector{String}(undef, M)

		if typeof(actor_number_) <: Int && actor_number_ > M
			@warn "The actor number you provided is larger than the maximum of possible actors. Setting actor_number back to \"all\"."
			actor_number_ = "all"
		end
		
		if actor_number_ == "all"
			df.actor = df.username
			return df
		elseif actor_number_ == "all_positive"
			actor_number_ = sum(I .> 0)
		end


		for i = 1:actor_number_
			actors[i] = nodes[i]
		end

		L = aggregate_size
		N = actor_number_ += 1
		counter = 0
		while true
			counter += 1
			if N + L <= M
				actors[N:(N+L)] .= "AGG$(counter): $(I[N]) to $(I[N+L]) I score"
			else
				actors[N:end] .= "AGG$(counter): $(I[N]) to $(I[end]) I score"
				break
			end
			N += L
		end

		actor_dict = Dict(nodes .=> actors)
		
		df = transform(df, "username" => ByRow(x -> actor_dict[x]) => "actor")

		return df

	end

	return _IP_scores_wrapped

end



"""
Create the graph and matrices needed to compute Influence Passivity (IP) scores of users.
"""
function compute_IP_graph(df; min_tweets::Int = 3)

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



"""
Compute the Influence Passivity (IP) scores of users from matrices u and v as returned by IP_graph.
"""
function compute_IP_scores(u, v; max_iter::Int = 200, max_residual::Real = 1e-3)

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
		residual = norm(I_old .- I, 1) + norm(P_old .- P, 1)
        push!(residuals, residual)

		P_old = P
		I_old = I
    end

	I = reshape(I, :)
	P = reshape(P, :)

	return I, P, residuals

end

