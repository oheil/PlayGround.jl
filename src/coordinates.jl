
#module Coordinatesm
#export Coordinates, PossibleCoordinates, Coordinates2d, Coordinates2dIndex, polar_to_2d, polar_to_2d_index, calc_possible_coordinates, get_random_coordinates

using Random

struct PossibleCoordinates
    ϕs::Array{Float64}
    θs::Array{Float64}
end

struct Coordinates
    ϕ::Float64
    θ::Float64
end
struct Coordinates2d
    x::Float64
    y::Float64
end
struct Coordinates2dIndex
    x::Int
    y::Int
end
function polar_to_2d(p::Coordinates)
    x=sin(p.θ)*cos(p.ϕ)
    y=sin(p.θ)*sin(p.ϕ)
    return Coordinates2d(x,y)
end
function polar_to_2d_index(p::Coordinates,width::Int,height::Int)
    c=polar_to_2d(p)
    if p.θ < pi/2
        xindex=1+floor(Int,((1.0+c.x)/2.0)*(width/2.0)) #left
    else
        xindex=floor(Int,width/2.0)+1+floor(Int,((1.0+c.x)/2.0)*(width/2.0)) #right
    end
    yindex=1+floor(Int,((1.0+c.y)/2.0)*height)
    return Coordinates2dIndex(xindex,yindex)
end

function calc_possible_coordinates(number_cells::Int)
    nθ=floor(Int,sqrt(number_cells/2))
    nϕ=2*nθ
    ϕs=range(0,2π,length=nϕ)
    θs=range(0,π,length=nθ)
    PossibleCoordinates(ϕs,θs)
end

function get_random_coordinates(possible_coordinates::PossibleCoordinates)
    return Coordinates(rand(possible_coordinates.ϕs),rand(possible_coordinates.θs))
end

function align_to_possible_coordinates(c::Coordinates, possible_coordinates::PossibleCoordinates)
    aligned_ϕ=-1.0
    if c.ϕ < possible_coordinates.ϕs[1]
        aligned_ϕ = possible_coordinates.ϕs[1]
    elseif c.ϕ >= possible_coordinates.ϕs[end]
        aligned_ϕ = possible_coordinates.ϕs[1]
    else
        for ϕ_index in 1:(length(possible_coordinates.ϕs)-1)
            if c.ϕ >= possible_coordinates.ϕs[ϕ_index] && c.ϕ < possible_coordinates.ϕs[ϕ_index+1]
                aligned_ϕ = possible_coordinates.ϕs[ϕ_index]
            end
        end
    end
    aligned_θ=-1.0
    if c.θ < possible_coordinates.θs[1]
        aligned_θ = possible_coordinates.θs[1]
    elseif c.θ >= possible_coordinates.θs[end]
        aligned_θ = possible_coordinates.θs[1]
    else
        for θ_index in 1:(length(possible_coordinates.θs)-1)
            if c.θ >= possible_coordinates.θs[θ_index] && c.θ < possible_coordinates.θs[θ_index+1]
                aligned_θ = possible_coordinates.θs[θ_index]
            end
        end
    end
    return Coordinates(aligned_ϕ,aligned_θ)
end

#end