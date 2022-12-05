


function TE(X,Y)
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
            Yₚ_0_Xₚ_1 += 1
            if Y[t] == 0
                Yₜ_0_Yₚ_1_Xₚ_0 += 1
            elseif Y[t] == 1
                Yₜ_1_Yₚ_1_Xₚ_0 += 1
            end
        end
        if X[t-1] == 1 && Y[t-1] == 0
            Yₚ_1_Xₚ_0 += 1
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

    return  Yₜ_0_Yₚ_0_Xₚ_0/(length(Y)-1) * log((Yₜ_0_Yₚ_0_Xₚ_0/Yₚ_0_Xₚ_0)/(Yₜ_0_Yₚ_0/Yₚ_0)) +
            Yₜ_1_Yₚ_0_Xₚ_0/(length(Y)-1) * log((Yₜ_1_Yₚ_0_Xₚ_0/Yₚ_0_Xₚ_0)/(Yₜ_1_Yₚ_0/Yₚ_0)) +
            Yₜ_0_Yₚ_1_Xₚ_0/(length(Y)-1) * log((Yₜ_0_Yₚ_1_Xₚ_0/Yₚ_1_Xₚ_0)/(Yₜ_0_Yₚ_1/Yₚ_1)) +
            Yₜ_1_Yₚ_1_Xₚ_0/(length(Y)-1) * log((Yₜ_1_Yₚ_1_Xₚ_0/Yₚ_1_Xₚ_0)/(Yₜ_1_Yₚ_1/Yₚ_1)) +
            Yₜ_0_Yₚ_0_Xₚ_1/(length(Y)-1) * log((Yₜ_0_Yₚ_0_Xₚ_1/Yₚ_0_Xₚ_1)/(Yₜ_0_Yₚ_0/Yₚ_0)) +
            Yₜ_1_Yₚ_0_Xₚ_1/(length(Y)-1) * log((Yₜ_1_Yₚ_0_Xₚ_1/Yₚ_0_Xₚ_1)/(Yₜ_1_Yₚ_0/Yₚ_0)) +
            Yₜ_0_Yₚ_1_Xₚ_1/(length(Y)-1) * log((Yₜ_0_Yₚ_1_Xₚ_1/Yₚ_1_Xₚ_1)/(Yₜ_0_Yₚ_1/Yₚ_1)) +
            Yₜ_1_Yₚ_1_Xₚ_1/(length(Y)-1) * log((Yₜ_1_Yₚ_1_Xₚ_1/Yₚ_1_Xₚ_1)/(Yₜ_1_Yₚ_1/Yₚ_1))
end



function transfer_entropy(X, Y)

    N = length(X)
    # configurations = [(Y[i+1], Y[i], X[i]) for i = 1:(N-1)]
    configurations = [(Y[i], Y[i-1], X[i-1]) for i = 2:N]
    states = proportionmap(configurations)

    tot = 0

    for state in keys(states)
        state_proba = states[state]
        # P_Yn_Xn = sum((Y .== state[2]) .& (X .== state[3])) / N
        # P_Yn1_Yn = sum((Y[2:end] .== state[1]) .& (Y[1:(end-1)] .== state[2])) / (N - 1)
        P_Yn_Xn = sum((Y[2:end] .== state[2]) .& (X[2:end] .== state[3])) / (N-1)
        P_Yn1_Yn = sum((Y[2:end] .== state[1]) .& (Y[1:(end-1)] .== state[2])) / (N - 1)
        # P_Yn = sum(Y .== state[2]) / N
        P_Yn = sum(Y[2:end] .== state[2]) / (N-1)

        numerator = state_proba / P_Yn_Xn
        denominator = P_Yn1_Yn / P_Yn

        tot += state_proba * log(numerator / denominator)

    end

    return tot

end