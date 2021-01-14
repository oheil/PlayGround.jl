using GLFW
using ModernGL
using CSyntax
using CSyntax.CStatic

using CImGui
using CImGui.LibCImGui
using CImGui.GLFWBackend
using CImGui.OpenGLBackend

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

# create window
window = GLFW.CreateWindow(1100, 720, "PlayGround")

@assert window != C_NULL
GLFW.MakeContextCurrent(window)
GLFW.SwapInterval(1)  # enable vsync

# setup Dear ImGui context
ctx = CImGui.CreateContext()

# setup Dear ImGui style
CImGui.StyleColorsClassic()

#
# start to build the font:
#

#fonts_dir = joinpath(pathof(CImGui), "..","..","fonts")
fonts_dir = raw"c:\Windows\Fonts";
fonts = CImGui.GetIO().Fonts

builder=ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder()

#ImFontGlyphRangesBuilder_AddText(builder,"我是中文","") 
ImFontGlyphRangesBuilder_AddChar(builder,'π')
ImFontGlyphRangesBuilder_AddChar(builder,'ϕ')
ImFontGlyphRangesBuilder_AddChar(builder,'θ')
ImFontGlyphRangesBuilder_AddChar(builder,'♐')
ImFontGlyphRangesBuilder_AddChar(builder,'☽')
ImFontGlyphRangesBuilder_AddRanges(builder, ImFontAtlas_GetGlyphRangesDefault(fonts))

ranges=ImVector_ImWchar_create()
ImVector_ImWchar_Init(ranges)
ImFontGlyphRangesBuilder_BuildRanges(builder, ranges)

#set MergeMode to true
config=ImFontConfig_ImFontConfig()
let offset=0
    for i in eachindex(Base.datatype_fieldtypes(ImFontConfig))
        fieldnames(ImFontConfig)[i] == :MergeMode ? break : nothing
        offset+=sizeof(Base.datatype_fieldtypes(ImFontConfig)[i])
    end
    unsafe_store!(Ptr{Bool}(config+offset),true,1)
end


r = unsafe_wrap(Vector{ImVector_ImWchar}, ranges, 1)

CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "JuliaMono-Regular.ttf"), 16, config, r[1].Data )
#CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, C_NULL, r[1].Data )
#CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, C_NULL, CImGui.GetGlyphRangesChineseSimplifiedCommon(fonts) )

#a=[0xf000, 0xf3ff, 0x0]
#a_range=Core.Ptr{ImVector_ImWchar}(Base.pointer_from_objref(a))
#CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "arial.ttf"), 16, config, a_range )


CImGui.Build(fonts)
default_font = CImGui.AddFontDefault(fonts)
#@assert default_font != C_NULL

# setup Platform/Renderer bindings
ImGui_ImplGlfw_InitForOpenGL(window, true)
ImGui_ImplOpenGL3_Init(glsl_version)

try
    clear_color = Cfloat[0.45, 0.55, 0.60, 1.00]

    while  !GLFW.WindowShouldClose(window)
        GLFW.PollEvents()

        # start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame()
        ImGui_ImplGlfw_NewFrame()
        CImGui.NewFrame()
        CImGui.SetNextWindowSize(CImGui.ImVec2(350.0,200.0),CImGui.ImGuiCond_Once);

        CImGui.Begin("Special strings")
        CImGui.Text("我是中文")
        CImGui.Text("π ϕ θ ♐ ☽")
        CImGui.End()

        # rendering
        CImGui.Render()
        GLFW.MakeContextCurrent(window)
        display_w, display_h = GLFW.GetFramebufferSize(window)
        glViewport(0, 0, display_w, display_h)
        glClearColor(clear_color...)
        glClear(GL_COLOR_BUFFER_BIT)
        ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())

        GLFW.MakeContextCurrent(window)
        GLFW.SwapBuffers(window)
    end

catch e
    @error "Error in renderloop!" exception=e
    Base.show_backtrace(stderr, catch_backtrace())
    display_close(display)
finally
    ImGui_ImplOpenGL3_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    ImVector_ImWchar_destroy(ranges)
    ImFontGlyphRangesBuilder_destroy(builder)
    ImFontConfig_destroy(config)
    CImGui.DestroyContext(ctx)
    GLFW.DestroyWindow(window)
end

