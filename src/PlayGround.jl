
module PlayGround

using Dates
using Random
using Serialization

include("world.jl")
using .World

#include("display.jl")
global display

#function run(display,ws::World.State,wdp::World.DerivedParameters,action=Action(false))
function run(ws::World.State,wdp::World.DerivedParameters,action=World.Action())
    start_time=Base.time()
    time=World.get_time(ws)
    realtime=Dates.now()
    elapsed_realtime=0
    res_count=length(ws.resources)
    while ! action.stop && ! action.exit && ws.display[1].isOpen && World.get_step(ws) < World.get_maxsteps(ws)
        ws.display[1].runTime = ( Base.time() - start_time )
        #println(step," - ",time)
        time=World.do_timestep!(ws)
        World.do_step!(ws)
        #if rand(1:100)>80
        #    World.test_resources(ws,wdp,150)
        #end
        #while rand(1:100)>5
        #    if ! World.add_single_resource(ws,wdp)
        #        break
        #    end
        #end

        World.digest_external_energy_org(ws)
        World.housekeeping_organisms(ws)
        World.move_organisms(ws,wdp)
        World.split_organisms(ws,wdp)

        energy=World.get(ws,World.freeEnergy)
        if energy > 500 && World.add_single_resource(ws,wdp)
            while energy > 500 && World.add_single_resource(ws,wdp)
                energy=World.get(ws,World.freeEnergy)
            end
        else
            if length(ws.organisms)==0
                World.add_single_organism(ws,wdp)
            end
            #if length(ws.organisms)==0
            #    while ! World.add_single_organism(ws,wdp)
            #        energy=World.get(ws,World.freeEnergy)
            #        rem_res=rand(1:length(ws.resources))
            #        res=ws.resources[rem_res]
            #        energy+=res.free_energy
            #        World.set!(ws,World.freeEnergy,energy)
            #        World.wipe_resource(ws.display,res)
            #        push!(ws.helper.resource2expunge,res)
            #    end
            #end
        end

        elapsed_realtime=Dates.now()-realtime
        #if Dates.value(elapsed_realtime) > 16
            realtime=Dates.now()
            elapsed_realtime=0
            #display=display_update(display,ws,action)
            ws.display[1].showLoad=false
            global display=World.display_update(ws.display[1],action,ws)
        #end

        World.expunge_organisms(ws)
        World.expunge_resources(ws,display.img_width,display.img_height)
        #World.expunge_resources(ws)

        #if length(ws.organisms)==0
        #    action.stop=true
        #end
        if action.save
            eos=findfirst(c->c==UInt8('\0'),display.filename_buffer)
            fn=join(Char.(display.filename_buffer[1:(eos-1)]))
            save_current_world_state(ws,fn)
            action.save=false
        end
    end
    action.stop=true
    ws.display[1].runTime = ( Base.time() - start_time )
    ws
end

function run(max_steps::Int=typemax(Int),ws=nothing,wdp=nothing)
    #global display=display_initialize()
    wp=Vector{World.Parameters}(undef,1)
    wp[1]=World.Parameters()
    wdp=World.DerivedParameters(wp)
    action=World.Action(true)
    if isnothing(ws)
        ws=World.State(wp)
        #display=World.display_update(ws.display,action,ws)
        World.init!(wp[1],wdp,ws)
    else
        ws.display[1]=World.display_initialize()
    end
    global display=ws.display[1]
    try
        World.set_maxsteps!(ws,max_steps)
        while ws.display[1].isOpen && ! action.exit
            sleep(0.007)
            #display=display_update(display,ws,action)
            ws.display[1].showLoad=true
            global display=World.display_update(ws.display[1],action,ws)
            #World.expunge_organisms(ws)
            if ! action.stop
                World.set_step!(ws,0)
                #ws=run(display,ws,wdp,action)
                ws=run(ws,wdp,action)
            end
            if action.save
                eos=findfirst(c->c==UInt8('\0'),display.filename_buffer)
                fn=join(Char.(display.filename_buffer[1:(eos-1)]))
                save_current_world_state(ws,fn)
                action.save=false
            end
            if action.load
                eos=findfirst(c->c==UInt8('\0'),display.filename_buffer)
                fn=join(Char.(display.filename_buffer[1:(eos-1)]))
                load_world_state!(ws,fn)
                action.load=false
            end
        end
    catch e
        World.clean(display)
        rethrow()
    end
    World.clean(display)
    ws
end

Base.@ccallable function julia_main()::Cint
    run()
    return 0
end

function clean()
    World.clean(display)
end

function save_current_world_state(ws,file="ws.serialize")
    serialize(file,ws)
end

function load_world_state!(ws,file="ws.serialize")
    ws2=deserialize(file)
    World.State(ws,ws2)
    World.draw_all(ws.display[1],ws)
end

end # module
