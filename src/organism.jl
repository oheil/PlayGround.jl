
#using GeneralizedGenerated
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

include("expression.jl")

#include("coordinates.jl")
#using .Coordinatesm

let next_id::Int64 = 1
    function randomize!(params::Array{Float64,1})
        delta=0.1  #10%
        for index in eachindex(params)
            params[index] = params[index] * rand( (1-delta):0.01:(1+delta))
        end
    end
    mutable struct Organism
        id::Int64
        energy::Int64
        birth_time::Float64
        is_sibling::Bool
        generation::Int64
        
        trigger_split_expression::Expr
        trigger_split_expression_parameter::Array{Float64,1}
        trigger_split_function

        housekeeping_expression::Expr
        housekeeping_expression_parameter::Array{Float64,1}
        housekeeping_function

        energy_expression::Expr
        energy_expression_parameter::Array{Float64,1}
        energy_function
        
        ϕ_expression::Expr
        ϕ_expression_parameter::Array{Float64,1}
        #ϕ_function::Function
        ϕ_function
        θ_expression::Expr
        θ_expression_parameter::Array{Float64,1}
        #θ_function::Function
        θ_function
        current_position::Coordinates

        target_position::Coordinates
        external_time::Float64

        function Organism(posCoord::PossibleCoordinates, birth_time::Float64,org_max_energie::Int)
            id=next_id
            next_id+=1
            energy=rand(10:org_max_energie)
            is_sibling=false
            generation=0

            (trigger_split_expression,pcount)=create_expression( :life_time, :p, 0, 1 )
            pcount-=1
            trigger_split_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
            #trigger_split_function=mk_function( :(  (life_time, p) -> nothing ) )
            trigger_split_function=@RuntimeGeneratedFunction( :(  (life_time, p) -> nothing ) )
            checked=false
            check_set=zeros(Float64,100)
            entry=floatmin()
            for x in 1:100
                push!(check_set,entry)
                entry=nextfloat(entry)
            end
            while !checked
                checked=true
                try
                    #trigger_split_function=mk_function( :(  (life_time, p) -> $trigger_split_expression ) )
                    trigger_split_function=@RuntimeGeneratedFunction( :(  (life_time, p) -> $trigger_split_expression ) )
                catch
                    checked=false
                end
                if checked
                    for lt in check_set
                        try
                            trigger_split_function(lt,trigger_split_expression_parameter)
                        catch
                            checked=false
                            break
                        end
                    end
                end
                if !checked
                    (trigger_split_expression,pcount)=create_expression( :life_time, :p, 0, 1 )
                    pcount-=1
                    trigger_split_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
                end
            end

            (housekeeping_expression,pcount)=create_expression( :energy, :p, 0, 1 )
            pcount-=1
            housekeeping_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
            #housekeeping_function=mk_function( :(  (energy, p) -> nothing ) )
            housekeeping_function=@RuntimeGeneratedFunction( :(  (energy, p) -> nothing ) )
            checked=false
            while !checked
                checked=true
                try
                    #housekeeping_function=mk_function( :(  (energy, p) -> $housekeeping_expression ) )
                    housekeeping_function=@RuntimeGeneratedFunction( :(  (energy, p) -> $housekeeping_expression ) )
                catch
                    checked=false
                end
                if checked
                    for e in org_max_energie:-1:1
                        try
                            floor(Int,housekeeping_function(e,housekeeping_expression_parameter))
                        catch
                            checked=false
                            break
                        end
                    end
                end
                if !checked
                    (housekeeping_expression,pcount)=create_expression( :energy, :p, 0, 1 )
                    pcount-=1
                    housekeeping_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
                    #housekeeping_function=mk_function( :(  (energy, p) -> $housekeeping_expression ) )
                end
            end

            (energy_expression,pcount)=create_expression( :external_energy, :p, 0, 1 )
            pcount-=1
            energy_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
            #energy_function=mk_function( :(  (external_energy, p) -> nothing ) )
            energy_function=@RuntimeGeneratedFunction( :(  (external_energy, p) -> nothing ) )
            checked=false
            while !checked
                checked=true
                try
                    #energy_function=mk_function( :(  (external_energy, p) -> $energy_expression ) )
                    energy_function=@RuntimeGeneratedFunction( :(  (external_energy, p) -> $energy_expression ) )
                catch e
                    checked=false
                end
                if checked
                    for external_energy in 0:10:100
                        try
                            floor(Int,energy_function(external_energy,energy_expression_parameter))
                        catch e
                            checked=false
                            break
                        end
                    end
                end
                if !checked
                    (energy_expression,pcount)=create_expression( :external_energy, :p, 0, 1 )
                    pcount-=1
                    energy_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
                    #energy_function=mk_function( :(  (external_energy, p) -> $energy_expression ) )
                end
            end

            complexity=1

            (ϕ_expression,pcount)=create_expression( :ϕ, :p, complexity, 1 )
            pcount-=1
            ϕ_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
            #ϕ_function=mk_function( :(  (ϕ, p) -> nothing ) )
            ϕ_function=@RuntimeGeneratedFunction( :(  (ϕ, p) -> nothing ) )
            #ϕ_function=Base.eval( :( (ϕ,p) -> $ϕ_expression ) )
            checked=false
            while !checked
                checked=true
                try
                    #ϕ_function=mk_function( :(  (ϕ, p) -> $ϕ_expression ) )
                    ϕ_function=@RuntimeGeneratedFunction( :(  (ϕ, p) -> $ϕ_expression ) )
                catch e
                    checked=false
                end
                #println("ϕ_expression : ",ϕ_expression," : ",ϕ_expression_parameter)
                if checked
                    for pos_ϕ in posCoord.ϕs
                        #Base.invokelatest(ϕ_function,pos_ϕ,ϕ_expression_parameter)
                        try
                            #Base.invokelatest(ϕ_function,pos_ϕ,ϕ_expression_parameter)
                            new_ϕ=ϕ_function(pos_ϕ,ϕ_expression_parameter)
                            if isnan(new_ϕ)
                                checked=false
                            end
                        catch e
                            checked=false
                            break
                        end
                    end
                end
                if ! checked
                    (ϕ_expression,pcount)=create_expression( :ϕ, :p, complexity, 1 )
                    pcount-=1
                    ϕ_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
                    #ϕ_function=Base.eval( :( (ϕ,p) -> $ϕ_expression ) )
                    #ϕ_function=mk_function( :(  (ϕ, p) -> $ϕ_expression ) )
                end
            end

            (θ_expression,pcount)=create_expression( :θ, :p, complexity, 1 )
            pcount-=1
            θ_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
            #θ_function=mk_function( :( (θ,p) -> nothing ) )
            θ_function=@RuntimeGeneratedFunction( :( (θ,p) -> nothing ) )
            #θ_function=Base.eval( :( (θ,p) -> $θ_expression ) )
            checked=false
            while !checked
                checked=true
                try
                    #θ_function=mk_function( :( (θ,p) -> $θ_expression ) )
                    θ_function=@RuntimeGeneratedFunction( :( (θ,p) -> $θ_expression ) )
                catch e
                    checked=false
                end
                #println("θ_expression : ",θ_expression," : ",θ_expression_parameter)
                if checked
                    for pos_θ in posCoord.θs
                        try
                            new_θ=θ_function(pos_θ,θ_expression_parameter)
                            #Base.invokelatest(θ_function,pos_θ,θ_expression_parameter)
                            if isnan(new_θ)
                                checked=false
                            end
                        catch e
                            checked=false
                            break
                        end
                    end
                end
                if ! checked
                    (θ_expression,pcount)=create_expression( :θ, :p, complexity, 1 )
                    pcount-=1
                    θ_expression_parameter=rand(-5.0:0.1:5.0)*rand(Float64,pcount)
                    #θ_function=Base.eval( :( (θ,p) -> $θ_expression ) )
                    #θ_function=mk_function( :( (θ,p) -> $θ_expression ) )
                end
            end

            current_position=get_random_coordinates(posCoord)
            new(id,
                energy,birth_time,
                is_sibling,generation,
                trigger_split_expression,trigger_split_expression_parameter,trigger_split_function,
                housekeeping_expression,housekeeping_expression_parameter,housekeeping_function,
                energy_expression,energy_expression_parameter,energy_function,
                ϕ_expression,ϕ_expression_parameter,ϕ_function,
                θ_expression,θ_expression_parameter,θ_function,
                current_position
            )
        end
        function Organism(org, randomize = false)
            id=next_id
            next_id+=1
            trigger_split_expression_parameter=deepcopy(org.trigger_split_expression_parameter)
            housekeeping_expression_parameter=deepcopy(org.housekeeping_expression_parameter)
            energy_expression_parameter=deepcopy(org.energy_expression_parameter)
            ϕ_expression_parameter=deepcopy(org.ϕ_expression_parameter)
            θ_expression_parameter=deepcopy(org.θ_expression_parameter)
            if randomize
                randomize!(trigger_split_expression_parameter)
                randomize!(housekeeping_expression_parameter)
                randomize!(energy_expression_parameter)
                randomize!(ϕ_expression_parameter)
                randomize!(θ_expression_parameter)
            end
            new(id,
                org.energy,org.birth_time,
                org.is_sibling,org.generation,
                org.trigger_split_expression,trigger_split_expression_parameter,org.trigger_split_function,
                org.housekeeping_expression,housekeeping_expression_parameter,org.housekeeping_function,
                org.energy_expression,energy_expression_parameter,org.energy_function,
                org.ϕ_expression,ϕ_expression_parameter,org.ϕ_function,
                org.θ_expression,θ_expression_parameter,org.θ_function,
                org.current_position
            )
        end
    end
end