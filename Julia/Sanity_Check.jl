using CSV
using DataFrames
using Transformers, Transformers.Pretrain
using Dates

if split(pwd(),"\\")[end] != "julia"
    cd("julia")
end
include("platforms.jl")
include("narrative_platform.jl")
data = CSV.read("../Data/1_Raw/MIPSTEST.csv", DataFrame; header=7)[:,["Date", "Sentiment", "Title", "Expanded URLs", "Domain", "Author", "Full Text", "Page Type"]];
# only use twitter for now for clarity
df = data[(data."Page Type" .== "twitter") .&& (.~ismissing.(data."Expanded URLs")), :]
# bin the dates by 5 minute intervals
clean_dates = x -> floor(DateTime(split(x, '.')[1], "yyyy-mm-dd HH:MM:ss"), Dates.Minute(15)) 
df.time = clean_dates.(df.Date)
# Our narrative parition will be by pos/neg/neut sentiment as assigned by BW
df.partition = df.Sentiment

ε=0.01
tc = TopicClusterer(x->rand_time_embedding(x, col=:Title, date_col=:time), (D,ε) -> Clustering.dbscan(D, ε, min_cluster_size=10))
feature_mat, words, doctermmat = tc.embed(df)
clusters = tc.cluster(feature_mat, ε)
topic_def = []
for cluster in clusters
    push!(topic_def, words[cluster.core_indices])
end






# Load in our models
ENV["DATADEPS_ALWAYS_ACCEPT"] = true;
bert_model, wordpiece, tokenizer = pretrain"Bert-uncased_L-12_H-768_A-12";
vocab = Transformers.Vocabulary(wordpiece);
bert = (model=bert_model, wordpiece=wordpiece, tokenizer=tokenizer);
@load "Sensors/RelationClassifier/graph_model.BSON" m1


narrative_sensor_platform = NarrativeSensorPlatform(m1, bert);
topic_graphs, topic_def = observe(data[1:10], narrative_sensor_platform)

i = 2
g = make_topic_graph(topic_graphs[i])
gplot(g, nodelabel=topic_defs[i], layout=random_layout)

