using StatsBase: proportionmap, countmap

"""
Simple form of transfer entropy calculation using naive probability estimation (only compute frequency of states inside the time series).
Only look at the current and previous time indices (k=l=1 in Schreiber's paper).
"""
function TE(X, Y)

    N = length(X)
    configurations = [(Y[i+1], Y[i], X[i]) for i = 1:(N-1)]
    states = proportionmap(configurations)

    tot = 0.0

    for state in keys(states)
        state_proba = states[state]
        P_Yn_Xn = sum((Y .== state[2]) .& (X .== state[3])) / N
        P_Yn1_Yn = sum((Y[2:end] .== state[1]) .& (Y[1:(end-1)] .== state[2])) / (N - 1)
        P_Yn = sum(Y .== state[2]) / N

        numerator = state_proba / P_Yn_Xn
        denominator = P_Yn1_Yn / P_Yn

        tot += state_proba * log2(numerator / denominator)

    end

    return tot

end


"""
Old version given by Tom (that I corrected). This is not robust and will issue a lot of NaN because of the states having zero probabilities (see last return line).
"""
function TE_old_revised(X,Y)
    # count the number of each category of occurence for H(yₜ | )
    Yₜ_0_Yₚ_0 = 0
    Yₜ_1_Yₚ_0 = 0
    Yₜ_0_Yₚ_1 = 0
    Yₜ_1_Yₚ_1 = 0
    Yₚ_0 = 0
    Yₚ_1 = 0
    for t in eachindex(Y)[2:end]
        if Y[t-1] == 0
            Yₚ_0 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_0  += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_0 += 1
            end
        elseif Y[t-1] == 1
            Yₚ_1 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_1 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_1 += 1
            end
        end
    end 

    Yₜ_0_Yₚ_0_Xₚ_0 = 0
    Yₜ_1_Yₚ_0_Xₚ_0 = 0
    Yₜ_0_Yₚ_1_Xₚ_0 = 0
    Yₜ_1_Yₚ_1_Xₚ_0 = 0
    Yₜ_0_Yₚ_0_Xₚ_1 = 0
    Yₜ_1_Yₚ_0_Xₚ_1 = 0
    Yₜ_0_Yₚ_1_Xₚ_1 = 0
    Yₜ_1_Yₚ_1_Xₚ_1 = 0
    Yₚ_0_Xₚ_0 = 0
    Yₚ_1_Xₚ_0 = 0
    Yₚ_0_Xₚ_1 = 0
    Yₚ_1_Xₚ_1 = 0
    
    for t in eachindex(Y)[2:end]
        if X[t-1] == 0 && Y[t-1] == 0
            Yₚ_0_Xₚ_0 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_0_Xₚ_0 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_0_Xₚ_0 += 1
            end
        end
        if X[t-1] == 0 && Y[t-1] == 1
            Yₚ_1_Xₚ_0 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_1_Xₚ_0 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_1_Xₚ_0 += 1
            end
        end
        if X[t-1] == 1 && Y[t-1] == 0
            Yₚ_0_Xₚ_1 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_0_Xₚ_1 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_0_Xₚ_1 += 1
            end
        end
        if X[t-1] == 1 && Y[t-1] == 1
            Yₚ_1_Xₚ_1 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_1_Xₚ_1 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_1_Xₚ_1 += 1
            end
        end
    end

    return  Yₜ_0_Yₚ_0_Xₚ_0/(length(Y)-1) * log2((Yₜ_0_Yₚ_0_Xₚ_0/Yₚ_0_Xₚ_0)/(Yₜ_0_Yₚ_0/Yₚ_0)) +
            Yₜ_1_Yₚ_0_Xₚ_0/(length(Y)-1) * log2((Yₜ_1_Yₚ_0_Xₚ_0/Yₚ_0_Xₚ_0)/(Yₜ_1_Yₚ_0/Yₚ_0)) +
            Yₜ_0_Yₚ_1_Xₚ_0/(length(Y)-1) * log2((Yₜ_0_Yₚ_1_Xₚ_0/Yₚ_1_Xₚ_0)/(Yₜ_0_Yₚ_1/Yₚ_1)) +
            Yₜ_1_Yₚ_1_Xₚ_0/(length(Y)-1) * log2((Yₜ_1_Yₚ_1_Xₚ_0/Yₚ_1_Xₚ_0)/(Yₜ_1_Yₚ_1/Yₚ_1)) +
            Yₜ_0_Yₚ_0_Xₚ_1/(length(Y)-1) * log2((Yₜ_0_Yₚ_0_Xₚ_1/Yₚ_0_Xₚ_1)/(Yₜ_0_Yₚ_0/Yₚ_0)) +
            Yₜ_1_Yₚ_0_Xₚ_1/(length(Y)-1) * log2((Yₜ_1_Yₚ_0_Xₚ_1/Yₚ_0_Xₚ_1)/(Yₜ_1_Yₚ_0/Yₚ_0)) +
            Yₜ_0_Yₚ_1_Xₚ_1/(length(Y)-1) * log2((Yₜ_0_Yₚ_1_Xₚ_1/Yₚ_1_Xₚ_1)/(Yₜ_0_Yₚ_1/Yₚ_1)) +
            Yₜ_1_Yₚ_1_Xₚ_1/(length(Y)-1) * log2((Yₜ_1_Yₚ_1_Xₚ_1/Yₚ_1_Xₚ_1)/(Yₜ_1_Yₚ_1/Yₚ_1))
end