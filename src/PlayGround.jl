
module PlayGround


using Dates
using Random

include("world.jl")
using .World

#include("display.jl")
global display

#function run(display,ws::World.State,wdp::World.DerivedParameters,action=Action(false))
function run(ws::World.State,wdp::World.DerivedParameters,action=World.Action(false,false))
    time=World.get_time(ws)
    realtime=Dates.now()
    elapsed_realtime=0
    res_count=length(ws.resources)
    while ! action.stop && ! action.exit && ws.display.isOpen && World.get_step(ws) < World.get_maxsteps(ws)
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
            global display=World.display_update(ws.display,action,ws)
        #end

        World.expunge_organisms(ws)
        World.expunge_resources(ws,display.img_width,display.img_height)
        #World.expunge_resources(ws)

        #if length(ws.organisms)==0
        #    action.stop=true
        #end
    end
    action.stop=true
    ws
end

function run(max_steps::Int=typemax(Int),ws=nothing,wdp=nothing)
    #global display=display_initialize()
    wp=World.Parameters()
    wdp=World.DerivedParameters(wp)
    action=World.Action(true,false)
    if isnothing(ws)
        ws=World.State(wp)
        #display=World.display_update(ws.display,action,ws)
        World.init!(wp,wdp,ws)
    end
    global display=ws.display
    try
        World.set_maxsteps!(ws,max_steps)
        while ws.display.isOpen && ! action.exit
            sleep(0.007)
            #display=display_update(display,ws,action)
            global display=World.display_update(ws.display,action,ws)
            #World.expunge_organisms(ws)
            if ! action.stop
                World.set_step!(ws,0)
                #ws=run(display,ws,wdp,action)
                ws=run(ws,wdp,action)
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

end # module
