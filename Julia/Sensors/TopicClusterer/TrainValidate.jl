using Clustering
using BSON: @load, @save
using TextAnalysis


# Topic cluster algorithm
mutable struct TopicClusterer <: Sensor
    embed
    cluster
end

function TopicClusterer(; embed = stupid_embedding)
    #ε = 0.5
    minpts = 10

    if embed === nothing
        embed = stupid_embedding
    end
    
    cluster = (D,ε) -> Clustering.dbscan(D, ε, min_cluster_size=minpts)
    TopicClusterer(embed, cluster)
end

#function lda_cluster(m; α, β)
#    ϕ, θ = lda(m, k=)
#end

function stupid_embedding(data; col=:Text)
    docs = StringDocument.(data[!,col])
    remove_corrupt_utf8!.(docs)
    prepare!.(docs, strip_articles| strip_html_tags| strip_stopwords| strip_punctuation)
    crps = Corpus(docs)
    update_lexicon!(crps)
    dtm = DocumentTermMatrix(crps)
    return Matrix{Float32}(dtm.dtm), dtm.terms, dtm
end

function rand_time_embedding(data; col=:Text, date_col=:Time)
    docs = StringDocument.(lowercase.(data[!,col]))
    remove_corrupt_utf8!.(docs)
    prepare!.(docs, strip_articles| strip_html_tags| strip_stopwords| strip_punctuation| strip_non_letters| strip_sparse_terms)
    crps = Corpus(docs)
    stem!(crps)
    update_lexicon!(crps)
    doctermmat = DocumentTermMatrix(crps)
    embedding_df = DataFrame(Matrix(doctermmat.dtm), :auto)
    embedding_df[!, date_col] = data[!, date_col]
    gp = groupby(embedding_df, date_col, sort=true)
    embedding_df = combine(gp, valuecols(gp) .=> sum)
    embedding_df.sums = [sum(r[Not(date_col)]) for r in eachrow(embedding_df)]

    feat_mat = Matrix(embedding_df[:,Not([:sums, date_col])]./embedding_df[:,:sums])
    words = doctermmat.terms

    return feat_mat, words, doctermmat

end

# make this work better with multiple dispatch
function observe(d, topicclusterer::TopicClusterer; ε=0.0001, minpts=10)
    feature_mat, words, doctermmat = topicclusterer.embed(d)
    clusters = topicclusterer.cluster(feature_mat, ε)
    topic_def = []
    for cluster in clusters
        push!(topic_def, words[cluster.core_indices])
    end

    topic_idxs = []
    for c in clusters
        push!(topic_idxs, c.core_indices)
    end

    #println(typeof(topic_idxs))
    return topic_def, feature_mat, doctermmat, topic_idxs
end


function construct_time_series(d, topicclusterer::TopicClusterer; by_channel=false, ε=0.001, date_col=:time, chan_col=:chan)

    topic_def, feature_mat, doctermmat, topic_idxs = observe(d, topicclusterer, ε=ε)

    out_TSs = []
    unique_days = unique(d[!, date_col])
   # ts_mat = fill(0.0, length(unique_days), length(topic_def))# preallocate for speed
    

    df = DataFrame(Matrix(doctermmat.dtm), :auto)
    df[!, date_col] = d[!, date_col]
    df[!, chan_col] = d[!, chan_col]l

    by_channel = groupby(df, chan_col)


    for chan in by_channel
        ts_mat = fill(0.0, length(unique_days), length(topic_def))
        gp = groupby(chan, [date_col, chan_col], sort=true)
        channel_ts = combine(gp, valuecols(gp) .=> sum .=> valuecols(gp))
        channel_ts[!, date_col] = channel_ts[!, date_col] .|> x->findall(y->y==x, unique_days)[1]
        for (i, topic) in enumerate(topic_idxs)
            ts_mat[channel_ts[!, date_col],i] = sum.(eachrow(channel_ts[:, topic.+2]))./length(topic)
        end
        push!(out_TSs, ts_mat)
    end
    
    return out_TSs, topic_def, topic_idxs

end

