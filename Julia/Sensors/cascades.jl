using DataStructures

struct WithoutCuttoff end

struct InfluenceCascadeGenerator 
    cuttoff::Float64
    normalize::Bool
end

function InfluenceCascadeGenerator(cuttoff::Float64)
    return InfluenceCascadeGenerator(cuttoff, true)
end

# Implement a "fake" cuttoff set to 0, for causal measures which are binary (either influence or no influence, but no value)
function InfluenceCascadeGenerator(::Type{WithoutCuttoff}; normalize=true)
    return InfluenceCascadeGenerator(0, normalize)
end


mutable struct InfluenceCascade
    # The influence matrix at each level
    cascade::OrderedDict{AbstractString, Matrix}
    # The tuples representing edges between actors at each level
    actor_edges::OrderedDict{AbstractString, Vector{Tuple{Int, Int}}}
    # The number of different actors per level
    actors_per_level::Vector{Int}
    # The index of the root actor
    root::Int
    # Indicates whether the cascade has been normalized 
    is_normalized::Bool
end


"""
Normalize the cascade by its total influence values
"""
function normalize_cascade(cascade::InfluenceCascade)
    total_influence = sum(collect(values(cascade.cascade)))
    M = size(total_influence, 1)

    for key in keys(cascade.cascade)
        # if total_influence is not 0, divide by it (otherwise just put 0 because this means all cascades were 0)
        cascade.cascade[key] = ifelse.(total_influence .> 0, cascade.cascade[key] ./ total_influence, zeros(M,M))
    end

    cascade.is_normalized = true
end


"""
Return the influence cascades from the adjacency matrix containing the transfer entropy per actions.
"""
function observe(data::Matrix{Matrix{Float64}}, icg::InfluenceCascadeGenerator)

    influencers = Vector{Int}()
    for (j, col) in enumerate(eachcol(data))
        indegree = 0
        for source in col
            if any(source .> icg.cuttoff)
                indegree += 1
            end
        end
        if indegree==0
            # Before labeling it as an influencer, check that there is some outdegree (influence) for that node
            for target in data[j, :]
                # if true, this means that there is at least 1 outdegree, thus we append the influencer
                if any(target .> icg.cuttoff)
                    push!(influencers,j)
                    break
                end
            end
        end
    end

    influence_cascades = Vector{InfluenceCascade}()
    M = size(data[1,1], 1)

    for influencer in influencers
        # BFS through influence graph
        queue = Queue{Int}()
        enqueue!(queue, influencer)

        # this will keep track of the current depth in the BFS
        level = 0

        # Will contain the sum of the influence for each level 
        cascade = OrderedDict{AbstractString, Matrix}()
        # Will contains the actors edges of the cascade
        actor_indices = OrderedDict{AbstractString, Vector{Tuple{Int, Int}}}()
        # Will contain the number of actors at each level
        actors_per_level = []
    
        # Initialize the dicts for the first levels
        cascade["$level => $(level+1)"] = zeros(M, M)
        actor_indices["$level => $(level+1)"] = []

        # nodes already visited
        visited = [influencer]

        while (!isempty(queue))
            # number of nodes at the current depth (level)
            level_size = length(queue)
            push!(actors_per_level, level_size)
            while (level_size != 0)
                level_size -= 1
                node = dequeue!(queue)
                # find indices of all subsequent connected nodes
                indices = findall(x -> any(x .> icg.cuttoff), data[node, :]) 
                for ind in indices
                    # Add the value to the cascade even if the nodes have been already visited since 
                    # there can be multiple connection
                    cascade["$level => $(level+1)"] += ifelse.(data[node, ind] .> icg.cuttoff, data[node, ind], zeros(M,M))
                    push!(actor_indices["$level => $(level+1)"], (node, ind))
                    # if we did nor visit it, add it to the queue
                    if !(ind in visited)
                        enqueue!(queue, ind)
                        push!(visited, ind)
                    end
                end
            end
            if !(isempty(queue))
                level += 1
                cascade["$level => $(level+1)"] = zeros(M, M)
                actor_indices["$level => $(level+1)"] = []
            end
        end
        # add number of actors in the last level
        push!(actors_per_level, length(unique([i[2] for i in actor_indices["$level => $(level+1)"]])))
        # Create the influence_cascade objects and add it to the list
        influence_cascade = InfluenceCascade(cascade, actor_indices, actors_per_level, influencer, icg.normalize)
        push!(influence_cascades, influence_cascade)
    end
    
    if icg.normalize
        # Normalize the cascades by their total influence values
        for cascade in influence_cascades
            normalize_cascade(cascade)
        end
    end
    
    return influence_cascades
end

