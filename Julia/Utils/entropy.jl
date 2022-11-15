


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