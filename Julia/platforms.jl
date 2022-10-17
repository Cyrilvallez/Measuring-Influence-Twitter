abstract type Sensor end

# Sensor platforms
abstract type SensorPlatform end

mutable struct Sensor_Platform
    sensors::Vector{Sensor}
    inputs::Vector{Dict{Sensor, Tuple}}
    passthroughs::Vector{Dict{Sensor, Tuple}}
end

function observe(data, platform::Sensor_Platform; all=false)
    outputs = []
    for sensor in platform.sensors
        push!(outputs, observe([data[platform.inputs[sensor]], outputs[platform.inputs[sensor]]], sensor))
    end
    if all
        return outputs
    end
    return outputs[end]
end


