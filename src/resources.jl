
#include("coordinates.jl")
#using .Coordinatesm

@enum ResourceName res_type_a=1 res_type_b
res_type_energy=[20,50]

mutable struct ResourceType
    name::ResourceName
    energy::Int64
    function ResourceType(name::ResourceName)
        new(name,res_type_energy[Int(name)])
    end
end

mutable struct Resource
    id::Int64
    type::ResourceType
    position::Coordinates
    free_energy::Int64
end

function create_random_resource(id::Int,possible_coordinates::PossibleCoordinates)
    res_type=ResourceType(rand(instances(ResourceName)))
    Resource(id,res_type,get_random_coordinates(possible_coordinates),res_type.energy)
end

