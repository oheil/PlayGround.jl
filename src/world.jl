
module World

using Random

include("coordinates.jl")
#using .Coordinatesm

include("resources.jl")
include("organism.jl")

include("display.jl")

struct Parameters
    time::Float64
    energy::Int
    cells::Int
    org_max_energie::Int
    res_max_count::Int
    org_max_new::Int
    split_boundaries::Tuple{Float64,Float64}
    function Parameters(args...)
        max_res=3000
        max_energy=max_res*50
        new(
            floatmin(),     #start time
            max_energy,           #world energy
            100000,          #number of world cells on the sphere
            100,            #maximun possible energy of an organism
            max_res,           #maximum number of resources
            5,              #maximum number of new organisms per step
            (0.0,10.0)      #arbitrary boundaries for split decision
        )
    end
end

struct DerivedParameters
    possible_coordinates::PossibleCoordinates
    function DerivedParameters(wp::Parameters)
        new(calc_possible_coordinates(wp.cells))
    end
end

struct StateHelpers
    res_pol_positions2resource::Dict{Coordinates,Array{Resource,1}}
    res_index_positions2resource::Dict{Coordinates2dIndex,Array{Resource,1}}
    resource2expunge::Array{Resource,1}

    function StateHelpers()
        res_pol_positions2resource=Dict{Coordinates,Array{Resource,1}}()
        res_index_positions2resource=Dict{Coordinates2dIndex,Array{Resource,1}}()
        resource2expunge=Array{Resource,1}()
        new(res_pol_positions2resource,
            res_index_positions2resource,
            resource2expunge,
            )
    end
end

@enum StateFloatIndices currentTime=1 maxLifeTime
@enum StateIntIndices freeEnergy=1 step maxsteps cells res_id org_ancestor_count max_generations
struct State
    display::Display
    wp::Parameters
    floats::Array{Float64,1}
    ints::Array{Int,1}
    resources::Array{Resource,1}
    organisms::Array{Organism,1}
    cur_max_ancestor::Array{Organism,1}
    helper::StateHelpers
    function State(wp::Parameters)
        display=display_initialize()
        floats=Array{Float64,1}(undef,length(instances(StateFloatIndices)))
        ints=Array{Int,1}(undef,length(instances(StateIntIndices)))
        resources=Array{Resource,1}(undef,0)
        organisms=Array{Organism,1}(undef,0)
        cur_max_ancestor=Array{Organism,1}(undef,1)
        helper=StateHelpers()
        new(display, wp,floats, ints, resources, organisms, cur_max_ancestor, helper)
    end
end

function set!(ws::State,floatIndex::StateFloatIndices,value::Float64)
    ws.floats[Int(floatIndex)]=value
end
function set!(ws::State,intIndex::StateIntIndices,value::Int)
    ws.ints[Int(intIndex)]=value
end
function get(ws::State,floatIndex::StateFloatIndices)
    ws.floats[Int(floatIndex)]
end
function get(ws::State,intIndex::StateIntIndices)
    ws.ints[Int(intIndex)]
end
function do_timestep!(ws::State)
    set!(ws,currentTime,nextfloat(get(ws,currentTime)))
    get(ws,currentTime)
end
function get_time(ws::State)
    get(ws,currentTime)
end
function set_maxsteps!(ws::State,value::Int)
    set!(ws,maxsteps,value)
end
function get_maxsteps(ws::State)
    get(ws,maxsteps)
end
function set_step!(ws::State,value::Int)
    set!(ws,step,value)
end
function get_step(ws::State)
    get(ws,step)
end
function do_step!(ws::State)
    set_step!(ws,get_step(ws)+1)
end

function clean(display)
    display_close(display)
end

function init!(param::Parameters,derived_param::DerivedParameters,ws::State)
    set!(ws,currentTime,param.time)
    set!(ws,maxLifeTime,0.0)
    set!(ws,freeEnergy,param.energy)
    set!(ws,cells,param.cells)
    set!(ws,step,0)
    set!(ws,res_id,0)
    set!(ws,org_ancestor_count,0)
    set!(ws,max_generations,0)
    energy=get(ws,freeEnergy)
    while energy > 500
        #orgOrRes=rand(1:100)
        #if orgOrRes >= 5
            if ! add_single_resource(ws,derived_param)
                break
            end
            energy=get(ws,freeEnergy)
        #else
        #    if ! add_single_organism(ws,derived_param)
        #        break
        #    end
        #end
    end
end

function add_single_resource(ws::State,derived_param::DerivedParameters)
    energy=get(ws,freeEnergy)
    id=get(ws,res_id)
    res=create_random_resource(id,derived_param.possible_coordinates)
    energy-=res.type.energy
    if energy>=0
        push!(ws.resources,res)
        if haskey(ws.helper.res_pol_positions2resource,res.position)
            push!(ws.helper.res_pol_positions2resource[res.position],res)
        else
            ws.helper.res_pol_positions2resource[res.position]=[res]
        end
        set!(ws,res_id,id+1)
        set!(ws,freeEnergy,energy)
        draw_resource(ws.display,res)
        return true
    end
    return false
end

function test_resources(ws::State,wdp::DerivedParameters,N)
    #remove first N resources
    N = N>length(ws.resources) ? length(ws.resources) : N
    i=shuffle(1:length(ws.resources))[1:N]
    for res in ws.resources[i]
        energy=get(ws,freeEnergy)
        energy+=res.free_energy
        set!(ws,freeEnergy,energy)
        res.free_energy=0
        push!(ws.helper.resource2expunge,res)
        wipe_resource(ws.display,res)
    end
end

function expunge_resources(ws::State,img_width::Int,img_height::Int)
    for res in ws.helper.resource2expunge
        #res_pol_positions2resource::Dict{Coordinates,Array{Resource,1}}
        p=res.position
        if haskey(ws.helper.res_pol_positions2resource,p)
            resources=ws.helper.res_pol_positions2resource[p]
            index1=length(resources)
            depleted=zeros(Int,index1)
            index2=1
            for res2 in resources
                if res.id == res2.id
                    depleted[index1]=index2
                end
                index1-=1
                index2+=1
            end
            unique!(depleted)
            for index in depleted
                if index>0
                    deleteat!(resources,index)
                end
            end
        end
        #res_index_positions2resource::Dict{Coordinates2dIndex,Array{Resource,1}}
        pos2d_index=polar_to_2d_index(p,img_width,img_height)
        if haskey(ws.helper.res_index_positions2resource,pos2d_index)
            resources=ws.helper.res_index_positions2resource[pos2d_index]
            index1=length(resources)
            depleted=zeros(Int,index1)
            index2=1
            for res2 in resources
                if res.id == res2.id
                    depleted[index1]=index2
                end
                index1-=1
                index2+=1
            end
            unique!(depleted)
            for index in depleted
                if index>0
                    deleteat!(resources,index)
                end
            end
        end
        #resources::Array{Resource,1}
        index1=length(ws.resources)
        depleted=zeros(Int,index1)
        index2=1
        for res2 in ws.resources
            if res.id == res2.id
                depleted[index1]=index2
            end
            index1-=1
            index2+=1
        end
        unique!(depleted)
        for index in depleted
            if index>0
                deleteat!(ws.resources,index)
            end
        end
    end
    empty!(ws.helper.resource2expunge)
end

function add_single_organism(ws::State,derived_param::DerivedParameters)
    energy=get(ws,freeEnergy)
    cur_time=get(ws,currentTime)
    ancestor_count=get(ws,org_ancestor_count)
    org = Organism(derived_param.possible_coordinates,cur_time,ws.wp.org_max_energie)
    energy-=org.energy
    if energy>=0
        push!(ws.organisms,org)
        set!(ws,freeEnergy,energy)
        set!(ws,org_ancestor_count,ancestor_count+1)
        draw_org(ws.display,org)
        return true
    end
    return false
end

function split_organisms(ws::State,derived_param::DerivedParameters)
    siblings=Array{Organism,1}(undef,0)
    for org in ws.organisms
        if org.energy>1
            life_time=get(ws,currentTime)-org.birth_time
            split=org.trigger_split_function(life_time,org.trigger_split_expression_parameter)
            if split > ws.wp.split_boundaries[1] && split < ws.wp.split_boundaries[2]
                split_organism!(org,ws,derived_param,siblings)
            end
        end
    end
    for org in siblings
        draw_org(ws.display,org)
        push!(ws.organisms,org)
    end
end

function split_organism!(org::Organism,ws::State,derived_param::DerivedParameters,siblings::Array{Organism,1})
    if org.energy>1
        new_energy1=floor(Int,org.energy/2)
        if new_energy1<=0
            println("split: new energy1: ",new_energy1)
        end
        new_energy2=org.energy-new_energy1
        if new_energy2<=0
            println("split: new energy2: ",new_energy2)
        end
        org.energy=new_energy1
        cur_time=get(ws,currentTime)
        sibling=Organism(org)
        sibling.energy=new_energy2
        sibling.is_sibling=true
        sibling.generation=org.generation+1
        sibling.current_position=get_random_coordinates(derived_param.possible_coordinates)
        if( get(ws,max_generations) < sibling.generation )
            set!(ws,max_generations,sibling.generation)
            ws.cur_max_ancestor[1]=deepcopy(org)
        end
        push!(siblings,sibling)
    end
end

function digest_external_energy_org(ws::State)
    res2wipe=Dict{Resource,Bool}()
    for organism in ws.organisms
        if haskey(ws.helper.res_pol_positions2resource,organism.current_position)
            external_energy=0
            for res in ws.helper.res_pol_positions2resource[organism.current_position]
                external_energy+=res.free_energy
            end
            if external_energy>0
                new_energy=floor(Int,organism.energy_function(external_energy,organism.energy_expression_parameter))
                if new_energy>external_energy
                    new_energy=external_energy
                end
                if new_energy<0
                    new_energy=0
                end
                organism.energy+=new_energy
                while new_energy>0
                    for res in ws.helper.res_pol_positions2resource[organism.current_position]
                        if res.free_energy>0
                            if res.free_energy>=new_energy
                                res.free_energy-=new_energy
                                new_energy=0
                            else
                                new_energy-=res.free_energy
                                res.free_energy=0
                            end
                        end
                        if res.free_energy==0
                            res2wipe[res]=true
                        end
                        if new_energy==0
                            break
                        end
                    end
                end
            end
        end
    end
    for res in keys(res2wipe)
        wipe_resource(ws.display,res)
        push!(ws.helper.resource2expunge,res)
    end
end

function expunge_organisms(ws::State)
    index1=length(ws.organisms)
    dead=zeros(Int,index1)
    index2=1
    for organism in ws.organisms
        if organism.energy==0
            dead[index1]=index2
            cur_time=get(ws,currentTime)
            lifeTime=cur_time-organism.birth_time
            if lifeTime>get(ws,maxLifeTime)
                set!(ws,maxLifeTime,lifeTime)
            end
        end
        index1-=1
        index2+=1
    end
    for index in dead
        if index>0
            deleteat!(ws.organisms,index)
        end
    end
end

function housekeeping_organisms(ws::State)
    for organism in ws.organisms
        if organism.energy>0
            new_energy=floor(Int,organism.housekeeping_function(organism.energy,organism.housekeeping_expression_parameter))
            if new_energy>=organism.energy
                new_energy=rand(1:organism.energy)-1
            end
            if new_energy<0
                new_energy=0
            end
            world_energy=get(ws,freeEnergy)
            world_energy+=(organism.energy-new_energy)
            set!(ws,freeEnergy,world_energy)
            organism.energy=new_energy
        end
        if organism.energy==0
            wipe_org(ws.display,organism)
        end
    end
end

function move_organisms(ws::State,wdp::DerivedParameters)
    for organism in ws.organisms
        if organism.energy>0
            new_ϕ = organism.ϕ_function(organism.current_position.ϕ,organism.ϕ_expression_parameter)
            new_θ = organism.θ_function(organism.current_position.θ,organism.θ_expression_parameter)
            organism.target_position = Coordinates(new_ϕ,new_θ)
            new_target_position = align_to_possible_coordinates(organism.target_position,wdp.possible_coordinates)
            if new_target_position.ϕ<0.0 || new_target_position.θ<0.0
                println(organism.target_position," => ",new_target_position)
            end
            organism.target_position = new_target_position
            if organism.current_position!=organism.target_position
                wipe_org(ws.display,organism)
                organism.current_position = organism.target_position
                draw_org(ws.display,organism)
            end
        end
    end
end



end