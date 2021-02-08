
using Printf
using Random

using GLFW
using ModernGL
using CSyntax
using CSyntax.CStatic

using CImGui
using CImGui.LibCImGui
using CImGui.GLFWBackend
using CImGui.OpenGLBackend

using ImPlot
import CImGui.LibCImGui: ImGuiCond_Always

import DataStructures.CircularBuffer

#using .World

@static if Sys.isapple()
    # OpenGL 3.2 + GLSL 150
    tmp_glsl_version = 150
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE) # 3.2+ only
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
else
    # OpenGL 3.0 + GLSL 130
    tmp_glsl_version = 130
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 0)
    # GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE) # 3.2+ only
    # GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE) # 3.0+ only
    GLFW.WindowHint(GLFW.FOCUSED,GL_TRUE)
end
const glsl_version=tmp_glsl_version

# setup GLFW error callback
error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"
GLFW.SetErrorCallback(error_callback)

struct GlyphRange
	first::UInt16
	last::UInt16
	zero::UInt16
	function GlyphRange(first::UInt16,last::UInt16)
		new(first,last,0x0)
	end
end
greek=GlyphRange(0x0300, 0x03ff)

font_config=ImFontConfig_ImFontConfig()  #not used
#let offset=0
#	for i in eachindex(Base.datatype_fieldtypes(ImFontConfig))
#		fieldnames(ImFontConfig)[i] == :MergeMode ? break : nothing
#		offset+=sizeof(Base.datatype_fieldtypes(ImFontConfig)[i])
#	end
#	unsafe_store!(Ptr{Bool}(font_config+offset),true,1)
#end

mutable struct Display
    isOpen::Bool
    window::GLFW.Window
    ctx::Ptr{ImGuiContext}
    ctxp::Ptr{ImPlot.LibCImPlot.ImPlotContext}
    ranges::Ptr{ImVector_ImWchar}
    builder::Ptr{ImFontGlyphRangesBuilder}
    config::Ptr{ImFontConfig}
    img_width::Int
    img_height::Int
    image_id::Int
    world_image::Array{GLubyte,3}
    image_cache::Array{Int,2}
    x_values::CircularBuffer{Int}
    y_org::CircularBuffer{Int}
    y_res::CircularBuffer{Int}
end

mutable struct Action
    stop::Bool
    exit::Bool
end

function display_initialize()
    # create window
    window = GLFW.CreateWindow(1100, 720, "PlayGround")

    @assert window != C_NULL
    GLFW.MakeContextCurrent(window)
    GLFW.SwapInterval(1)  # enable vsync

    # setup Dear ImGui context
    ctx = CImGui.CreateContext()
    ctxp = ImPlot.CreateContext()

    # setup Dear ImGui style
    CImGui.StyleColorsClassic()

    #fonts_dir = joinpath(pathof(CImGui), "..","..","fonts")
    fonts_dir = raw"c:\Windows\Fonts";
    fonts = CImGui.GetIO().Fonts

    builder=ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()
    ImFontGlyphRangesBuilder_AddRanges(builder, ImFontAtlas_GetGlyphRangesDefault(fonts))
    greek_ptr=Core.Ptr{ImWchar}(Base.pointer_from_objref(Ref(greek)))
    ImFontGlyphRangesBuilder_AddRanges(builder, greek_ptr)
    
    ranges=ImVector_ImWchar_create()
    ImVector_ImWchar_Init(ranges)
    ImFontGlyphRangesBuilder_BuildRanges(builder, ranges)

    r = unsafe_wrap(Vector{ImVector_ImWchar}, ranges, 1)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, C_NULL, r[1].Data )

    #CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, fonts_config, ImFontAtlas_GetGlyphRangesDefault(fonts) )
    #greek=GlyphRange(0x0300, 0x03ff)
    #greek_ptr=Core.Ptr{UInt16}(Base.pointer_from_objref(Ref(greek)))
    #CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, fonts_config, greek_ptr )
    
    CImGui.Build(fonts)
    default_font = CImGui.AddFontDefault(fonts)
    #@assert default_font != C_NULL

    # setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init(glsl_version)

    img_width=400
    img_height=400
    (world_image,image_cache) = new_display_image(img_width, img_height)
    image_id = ImGui_ImplOpenGL3_CreateImageTexture(img_width, img_height)

    y_org=CircularBuffer{Int}(1000)
    y_res=CircularBuffer{Int}(1000)
    x_values=CircularBuffer{Int}(1000)
    fill!(y_org,0)
    fill!(y_res,0)
    for i in 1:1000
        push!(x_values,i)
    end

    return Display(true,window,ctx,ctxp,ranges,builder,font_config,img_width,img_height,image_id,world_image,image_cache,
        x_values,y_org,y_res
    )
end

function new_display_image(img_width, img_height)
    display_image=zeros(GLubyte, 4, img_width, img_height)
    display_image[4,:,:].=255
    image_cache=zeros(Int,img_width, img_height)
    return (display_image,image_cache)
end

function is_visible(px,py,img_width,img_height)
    return px>0 && px<=img_width && py>0 && py<=img_height
end

#function display_update(display::Display,ws::World.State,action::Action)
function display_update(display::Display,action::Action,ws)
    try
        clear_color = Cfloat[0.45, 0.55, 0.60, 1.00]
        if display.isOpen 
            if !GLFW.WindowShouldClose(display.window)
                GLFW.PollEvents()

                # start the Dear ImGui frame
                ImGui_ImplOpenGL3_NewFrame()
                ImGui_ImplGlfw_NewFrame()
                CImGui.NewFrame()
                CImGui.SetNextWindowSize(CImGui.ImVec2(350.0,250.0),CImGui.ImGuiCond_Once);

                #CImGui.Begin("Special strings")
                #CImGui.Text("ÄÜÖ π ϕ θ ♐ ☽ ")
                #CImGui.End()

                CImGui.Begin("Status")

                CImGui.Text(@sprintf("Application average %.3f ms/frame (%.1f FPS)", 1000 / CImGui.GetIO().Framerate, CImGui.GetIO().Framerate))
                CImGui.Text(@sprintf("Current time: %.20e",World.get(ws,World.currentTime)))
                CImGui.Text(@sprintf("Current steps: %i of %i",World.get_step(ws),World.get_maxsteps(ws)))
                CImGui.BeginChild("Org",CImGui.ImVec2(0, CImGui.GetTextLineHeightWithSpacing() * 2) )
                CImGui.Text(@sprintf("Ancestor count: %i",World.get(ws,org_ancestor_count)))
                CImGui.Text(@sprintf("Max generations: %i",World.get(ws,max_generations)))
                CImGui.EndChild()
                if CImGui.IsItemHovered()
                    CImGui.BeginTooltip()
                    if World.get(ws,max_generations) > 0
                        CImGui.Text(@sprintf("trigger_split_expression: %s",ws.cur_max_ancestor[1].trigger_split_expression))
                        CImGui.Text(@sprintf("trigger_split_expression parameters: %s",ws.cur_max_ancestor[1].trigger_split_expression_parameter))
                        CImGui.Text(@sprintf("housekeeping_expression: %s",ws.cur_max_ancestor[1].housekeeping_expression))
                        CImGui.Text(@sprintf("housekeeping_expression parameters: %s",ws.cur_max_ancestor[1].housekeeping_expression_parameter))
                        CImGui.Text(@sprintf("energy_expression: %s",ws.cur_max_ancestor[1].energy_expression))
                        CImGui.Text(@sprintf("energy_expression parameters: %s",ws.cur_max_ancestor[1].energy_expression_parameter))
                        CImGui.Text(@sprintf("ϕ expression: %s",ws.cur_max_ancestor[1].ϕ_expression))
                        CImGui.Text(@sprintf("ϕ expression parameters: %s",ws.cur_max_ancestor[1].ϕ_expression_parameter))
                        CImGui.Text(@sprintf("θ expression: %s",ws.cur_max_ancestor[1].θ_expression))
                        CImGui.Text(@sprintf("θ expression parameters: %s",ws.cur_max_ancestor[1].θ_expression_parameter))
                    end
                    CImGui.EndTooltip()
                end

                CImGui.Text(@sprintf("Free energy: %i",World.get(ws,World.freeEnergy)))
                CImGui.Text(@sprintf("# Resources: %i",length(ws.resources)))
                CImGui.Text(@sprintf("# organisms: %i",length(ws.organisms)))
                CImGui.Text(@sprintf("Max life time: %.20e",World.get(ws,World.maxLifeTime)))
                CImGui.End()

                CImGui.Begin("Action")
                if !action.stop
                    CImGui.Button("Stop") && (action.stop = true)
                else
                    CImGui.Button("Run") && (action.stop = false)
                end
                CImGui.Button("Exit") && (action.exit = true)
                CImGui.End()

                CImGui.Begin("Print")
                CImGui.BeginChild("Child")

                size=CImGui.GetWindowSize()
                cur_img_width=floor(Int,size.x)
                cur_img_height=floor(Int,size.y)
                if cur_img_width != display.img_width || cur_img_height != display.img_height
                    display.img_width=cur_img_width
                    display.img_height=cur_img_height
                    (display.world_image,display.image_cache) = new_display_image(display.img_width, display.img_height)
                    ImGui_ImplOpenGL3_DestroyImageTexture(display.image_id)
                    display.image_id = ImGui_ImplOpenGL3_CreateImageTexture(display.img_width, display.img_height)
                    #empty!(ws.helper.res_index_positions2resource)
                    draw_all(display,ws)
                    #wipe_resources_incremental(display,ws)
                    #wipe_org_incremental(display,ws)
                    #draw_resource_incremental(display,ws)
                    #draw_org_incremental(display,ws)
                end
                ImGui_ImplOpenGL3_UpdateImageTexture(display.image_id, display.world_image, display.img_width, display.img_height)
                CImGui.Image(Ptr{Cvoid}(display.image_id), (display.img_width, display.img_height))
                
                io = CImGui.GetIO()
                pos = CImGui.GetCursorScreenPos()
                rel_mouse_x=io.MousePos.x-pos.x+1
                rel_mouse_y=display.img_height-(pos.y-io.MousePos.y-5)
                if CImGui.IsItemHovered()
                    CImGui.BeginTooltip()
                    CImGui.Text(@sprintf("Image: (%.2f, %.2f)", display.img_width, display.img_height))
                    CImGui.Text(@sprintf("Region: (%.2f, %.2f)", pos.x, pos.y))
                    CImGui.Text(@sprintf("Mouse: (%.2f, %.2f)",rel_mouse_x,rel_mouse_y))
                    CImGui.Text(@sprintf("pos: %i %i",floor(Int,rel_mouse_x),floor(Int,rel_mouse_y)))
                    CImGui.Text(@sprintf("Resources:"))
                    c=World.Coordinates2dIndex(floor(Int,rel_mouse_x),floor(Int,rel_mouse_y))
                    area_size=5
                    for cx in -area_size:area_size
                        for cy in -area_size:area_size
                            ctmp=World.Coordinates2dIndex(c.x+cx,c.y+cy)
                            #if haskey(ws.helper.res_index_positions2resource,ctmp)
                            #    for res in ws.helper.res_index_positions2resource[ctmp]
                            #        cr=World.polar_to_2d_index(res.position,display.img_width, display.img_height)
                            #        CImGui.Text(@sprintf("Resource: %i %i",cr.x,cr.y))
                            #        for restype in res.resources
                            #            CImGui.Text(@sprintf("  ResourceType: %s %i %i",String(Symbol(restype.name)),restype.energy,restype.free_energy))
                            #        end
                            #    end
                            #end
                        end
                    end
                    CImGui.EndTooltip()
                end

                CImGui.EndChild()
                CImGui.End()

                CImGui.Begin("Plot")
                size=CImGui.GetWindowSize()
                cur_img_width=floor(Int,size.x)
                cur_img_height=floor(Int,size.y)
                if !action.stop
                    push!(display.y_org,length(ws.organisms))
                    push!(display.y_res,length(ws.resources))
                    push!(display.x_values,display.x_values[1000]+1)
                end
                if length(display.y_org) > 0
                    x_min_index=1
                    x_max_index=1000
                    y_org_max = maximum(display.y_org)
                    y_res_min = Float64(minimum(display.y_res))
                    y_res_min -= 0.1*y_res_min
                    y_res_max = Float64(maximum(display.y_res))
                    y_res_max += 0.1*y_res_max
                    
                    ImPlot.SetNextPlotLimits(display.x_values[1], display.x_values[1000], 0.0, y_org_max, ImGuiCond_Always)
                    #ImPlot.SetNextPlotLimitsY(0.0, y_org_max, ImGuiCond_Always,1)
                    #ImPlot.SetNextPlotLimitsY(y_res_min, y_res_max, ImGuiCond_Always,2)
                    #if ImPlot.BeginPlot("##line", "x", "y", CImGui.ImVec2(-1,-1); flags = ImPlot.ImPlotFlags_YAxis2 )
                    if ImPlot.BeginPlot("##line1", C_NULL, "org", CImGui.ImVec2(-1,cur_img_height/2-20); 
                        x_flags = ImPlotAxisFlags_NoTickLabels
                        )
                        ImPlot.PlotLine(display.x_values,display.y_org)
                        #ImPlot.SetPlotYAxis(2)
                        #ImPlot.PlotLine(display.x_values,display.y_res)
                        ImPlot.EndPlot()
                    end
                    ImPlot.SetNextPlotLimits(display.x_values[1], display.x_values[1000], y_res_min, y_res_max, ImGuiCond_Always)
                    #ImPlot.SetNextPlotTicksY([y_res_min,y_res_min+(y_res_max-y_res_min)/2.0,y_res_max], 3)
                    if ImPlot.BeginPlot("##line2", "steps", "res", CImGui.ImVec2(-1,cur_img_height/2-20) )
                        ImPlot.PlotLine(display.x_values,display.y_res)
                        ImPlot.EndPlot()
                    end
                end

                #y1 = rand(1000)
                #y2 = rand(1000).+2.0
                #ImPlot.SetNextPlotLimits(0.0,1000,0.0,4.0,ImGuiCond_Always)
                #ImPlot.SetNextPlotLimitsY(0.0, 1.0, ImGuiCond_Always,1)
                #ImPlot.SetNextPlotLimitsY(0.0, 4.0, ImGuiCond_Always,2)
                #if ImPlot.BeginPlot("##line", "x", "y", CImGui.ImVec2(-1,-1); flags = ImPlot.ImPlotFlags_YAxis2 )
                #    ImPlot.PlotLine(y1)
                #    ImPlot.SetPlotYAxis(2)
                #    ImPlot.PlotLine(y2)
                #    ImPlot.EndPlot()
                #end

                CImGui.End()

                # rendering
                CImGui.Render()
                GLFW.MakeContextCurrent(display.window)
                display_w, display_h = GLFW.GetFramebufferSize(display.window)
                glViewport(0, 0, display_w, display_h)
                glClearColor(clear_color...)
                glClear(GL_COLOR_BUFFER_BIT)
                ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())

                GLFW.MakeContextCurrent(display.window)
                GLFW.SwapBuffers(display.window)
            else
                display=display_close(display)
            end
        end
    catch e
        @error "Error in renderloop!" exception=e
        Base.show_backtrace(stderr, catch_backtrace())
        display_close(display)
    end
    return display
end

function draw_resource(display::Display,res::World.Resource)
    c=World.polar_to_2d_index(res.position,display.img_width,display.img_height)
    color=[0,0,0,255]
    if res.type.name == res_type_a
        color[1]=255
    elseif res.type.name == res_type_b
        color[2]=255
    end
    if res.free_energy>0
        xindex=c.x
        yindex=c.y
        if xindex>=0 && xindex<=display.img_width && yindex>=0 && yindex<=display.img_height
            for rgb in 1:4
                display.world_image[rgb,xindex,yindex]=color[rgb]
            end
            display.image_cache[xindex,yindex]+=1
        end
    end
end

function wipe_resource(display::Display,res::World.Resource)
    c=World.polar_to_2d_index(res.position,display.img_width,display.img_height)
    xindex=c.x
    yindex=c.y
    color=[0,0,0,255]
    if xindex>=0 && xindex<=display.img_width && yindex>=0 && yindex<=display.img_height
        if display.image_cache[xindex,yindex] == 1
            for rgb in 1:4
                display.world_image[rgb,xindex,yindex]=color[rgb]
            end
        end
        display.image_cache[xindex,yindex]-=1
        if display.image_cache[xindex,yindex]<0
            println("res: ",display.image_cache[xindex,yindex])
        end
    end
end

#function wipe_resources_incremental(display::Display,ws::World.State)
#    for res in ws.helper.resource2wipe
#        wipe_resources(display,res)
#    end
#    empty!(ws.helper.resource2wipe)
#end

#function wipe_org_incremental(display::Display,ws::World.State)
#    for org in ws.organisms
#        if org.needs_wipe
#            wipe_org(display,org)
#        end
#    end
#end

function wipe_org(display::Display,org::World.Organism)
    cDel=World.polar_to_2d_index(org.current_position,display.img_width,display.img_height)
    xindexDel=cDel.x
    yindexDel=cDel.y
    colorDel=[0,0,0,255]
    for rx in -3:3
        for ry in [-3,3]
            pxDel=xindexDel+rx
            pyDel=yindexDel+ry
            if is_visible(pxDel,pyDel,display.img_width,display.img_height)
                if display.image_cache[pxDel,pyDel] == 1
                    for rgb in 1:4
                        display.world_image[rgb,pxDel,pyDel]=colorDel[rgb]
                    end
                end
                display.image_cache[pxDel,pyDel]-=1
                if display.image_cache[pxDel,pyDel]<0
                    println("org: ",display.image_cache[pxDel,pyDel])
                end
            end
        end
    end
    for rx in [-3,3]
        for ry in -2:2
            pxDel=xindexDel+rx
            pyDel=yindexDel+ry
            if is_visible(pxDel,pyDel,display.img_width,display.img_height)
                if display.image_cache[pxDel,pyDel] == 1
                    for rgb in 1:4
                        display.world_image[rgb,pxDel,pyDel]=colorDel[rgb]
                    end
                end
                display.image_cache[pxDel,pyDel]-=1
                if display.image_cache[pxDel,pyDel]<0
                    println("org: ",display.image_cache[pxDel,pyDel])
                end
            end
        end
    end
end

function draw_org(display::Display,org::World.Organism)
    c=World.polar_to_2d_index(org.current_position,display.img_width,display.img_height)
    xindex=c.x
    yindex=c.y
    color=[255,255,255,255]
    if org.is_sibling
        color=[0,255,0,255]
    end
    for rx in -3:3
        for ry in [-3,3]
            px=xindex+rx
            py=yindex+ry
            if is_visible(px,py,display.img_width,display.img_height)
                for rgb in 1:4
                    display.world_image[rgb,px,py]=color[rgb]
                end
                display.image_cache[px,py]+=1
            end
        end
    end
    for rx in [-3,3]
        for ry in -2:2
            px=xindex+rx
            py=yindex+ry
            if is_visible(px,py,display.img_width,display.img_height)
                for rgb in 1:4
                    display.world_image[rgb,px,py]=color[rgb]
                end
                display.image_cache[px,py]+=1
            end
        end
    end
end

function draw_all(display::Display,ws)
    for res in ws.resources
        #draw_resource(display,ws,res)
        draw_resource(display,res)
    end
    #empty!(ws.helper.resource2draw)
    #empty!(ws.helper.resource2wipe)
    for org in ws.organisms
        #c=World.polar_to_2d_index(org.current_position,display.img_width,display.img_height)
        #if haskey(ws.helper.org_index_positions2organism,c)
        #    ws.helper.org_index_positions2organism[c]=vcat(ws.helper.org_index_positions2organism[c],org)
        #else
        #    ws.helper.org_index_positions2organism[c]=[org]
        #end
        #if org.energy>0
        draw_org(display,org)
        #end
        #org.last_displayed_position=org.current_position
        #org.needs_draw=false
        #org.needs_wipe=false
    end
end

#function draw_resource_incremental(display::Display,ws::World.State)
#    for res in ws.helper.resource2draw
#        draw_resource(display,ws,res)
#    end
#    empty!(ws.helper.resource2draw)
#end

#function draw_org_incremental(display::Display,ws::World.State)
#    for org in ws.organisms
#        if org.needs_draw
#            draw_org(display,org)
#        end
#    end
#end

function display_close(display::Display)
    if display.isOpen
        display.isOpen = false
        ImGui_ImplOpenGL3_Shutdown()
        ImGui_ImplGlfw_Shutdown()
        ImVector_ImWchar_destroy(display.ranges)
        ImFontGlyphRangesBuilder_destroy(display.builder)
        ImFontConfig_destroy(display.config)
        CImGui.DestroyContext(display.ctx)
        ImPlot.DestroyContext(display.ctxp)
        GLFW.DestroyWindow(display.window)
    end
    return display
end





