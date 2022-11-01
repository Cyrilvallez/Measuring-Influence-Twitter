using DataStructures
using DataFrames
using JSON

function get_username(data)
    return data["author"]["username"]
end


function get_country(data)
    if "geo" in keys(data)
        return data["geo"]["country"]
    else
        return missing
    end
end


function get_country_code(data)
    if "geo" in keys(data)
        return data["geo"]["country_code"]
    else
        return missing
    end
end


function get_tweet_category(data)
    if "referenced_tweets" in keys(data)
        return [dic["type"] for dic in data["referenced_tweets"]] 
    else
        return ["tweeted"]
    end
end

    
function get_original_text(data, category)
    return category == ["retweeted"] ? data["referenced_tweets"][1]["text"] : data["text"]
end


function get_urls(data, category)

    urls = Vector{String}()
    # If it is a retweet, the entities are given in the parent tweet elements most
    # of the time because the text is truncated after 140 characters
    if category == ["retweeted"]
        # get urls from the parent 
        if "entities" in keys(data["referenced_tweets"][1])
            if "urls" in keys(data["referenced_tweets"][1]["entities"])
                for dic in data["referenced_tweets"][1]["entities"]["urls"]
                    if "unwound_url" in keys(dic)
                        push!(urls, dic["unwound_url"])
                    else
                        push!(urls, dic["expanded_url"]) 
                    end
                end
            end     
        end     
        
    else
        # get urls 
        if "entities" in keys(data)
            if "urls" in keys(data["entities"])
                for dic in data["entities"]["urls"]
                    if "unwound_url" in keys(dic)
                        push!(urls, dic["unwound_url"])
                    else
                        push!(urls, dic["expanded_url"])
                    end
                end
            end
        end
    end
                
    if length(urls) == 0
        urls = missing
    end
                
    return urls
end

function get_hashtags(data, category)

    hashtags = missing
    if category == ["retweeted"]
        # get hashtag from the parent if there are any
        if "entities" in keys(data["referenced_tweets"][1])
            if "hashtags" in keys(data["referenced_tweets"][1]["entities"])
                hashtags = [dic["tag"] for dic in data["referenced_tweets"][1]["entities"]["hashtags"]] 
            end
        end
            
    else
        # get hashtag if there are any
        if "entities" in keys(data)
            if "hashtags" in keys(data["entities"])
                hashtags = [dic["tag"] for dic in data["entities"]["hashtags"]] 
            end
        end
    end

    return hashtags
end


ATTRIBUTES_TO_PRESERVE = [
    "id",
    "author_id",
    "created_at",
    "lang",
    "text"
    ]


function load_tweets(filename, to_df=true, skiprows=2)

    dics = Vector()

    for (i, line) in enumerate(eachline(filename))

        if i <= skiprows
            continue
        end
            
        data = JSON.parse(line)
        dic = Dict{String, Any}()
        for attribute in ATTRIBUTES_TO_PRESERVE
            dic[attribute] = data[attribute]
        end
        dic["username"] = get_username(data)
        dic["country"] = get_country(data)
        dic["country_code"] = get_country_code(data)
        dic["category"] = get_tweet_category(data)
        dic["original_text"] = get_original_text(data, dic["category"])
        dic["urls"] = get_urls(data, dic["category"])
        dic["hashtags"] = get_hashtags(data, dic["category"])
            
        push!(dics, dic)
    end

    if to_df
        return DataFrame(dics)
    else
        return dics
    end
end


"""
    load_json(filename::String, to_df::Bool = true, skiprows::Int = 0)

Conveniently load a file containing lines of json objects into a DataFrame (or as a list of dictionaries).
"""
function load_json(filename::String, to_df::Bool = true, skiprows::Int = 0)

    lines = readlines(filename)
    dics = [JSON.parse(line) for line in lines[(skiprows+1):end]]

    if to_df
        return DataFrame(dics)
    else
        return dics
    end
end