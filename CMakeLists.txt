cmake_minimum_required(VERSION 3.22)
project(RandomAttractors C)
set(CMAKE_CXX_STANDARD 14)

file(GLOB_RECURSE SOURCE_FILES 
	${CMAKE_SOURCE_DIR}/src/*.c
)
file(GLOB_RECURSE HEADER_FILES 
	${CMAKE_SOURCE_DIR}/src/*.h
)
add_executable(${PROJECT_NAME} ${HEADER_FILES} ${SOURCE_FILES})

#
# Embed GLSL as strings
#

function(embed_shader_glsl SHADER_FILE OUT_HEADER VAR_NAME)
    message("Embedding GLSL shader: ${SHADER_FILE}")
    file(READ ${SHADER_FILE} SHADER_CONTENT)
    string(REPLACE "\\" "\\\\" SHADER_CONTENT "${SHADER_CONTENT}")
    string(REPLACE "\"" "\\\"" SHADER_CONTENT "${SHADER_CONTENT}")
    string(REPLACE "\n" "\\n\"\n\"" SHADER_CONTENT "${SHADER_CONTENT}")
    file(WRITE ${OUT_HEADER} "const char* ${VAR_NAME} = \"${SHADER_CONTENT}\";\n")
endfunction()

set(SHADERS_DIR ${CMAKE_SOURCE_DIR}/src/glsl)
set(OUT_SHADERS_DIR ${CMAKE_BINARY_DIR}/shaders)

file(MAKE_DIRECTORY ${OUT_SHADERS_DIR})
target_include_directories(${PROJECT_NAME} PRIVATE ${OUT_SHADERS_DIR})

embed_shader_glsl(${SHADERS_DIR}/mesh_vertex.glsl ${OUT_SHADERS_DIR}/mesh_vertex_shader.h mesh_vertex_glsl)
embed_shader_glsl(${SHADERS_DIR}/mesh_fragment.glsl ${OUT_SHADERS_DIR}/mesh_fragment_shader.h mesh_fragment_glsl)
embed_shader_glsl(${SHADERS_DIR}/spot_vertex.glsl ${OUT_SHADERS_DIR}/spot_vertex_shader.h spot_vertex_glsl)
embed_shader_glsl(${SHADERS_DIR}/spot_fragment.glsl ${OUT_SHADERS_DIR}/spot_fragment_shader.h spot_fragment_glsl)

add_custom_target(embed_shaders DEPENDS
    ${CMAKE_BINARY_DIR}/shaders/mesh_vertex_shader.h
    ${CMAKE_BINARY_DIR}/shaders/mesh_fragment_shader.h
    ${CMAKE_BINARY_DIR}/shaders/spot_vertex_shader.h
    ${CMAKE_BINARY_DIR}/shaders/spot_fragment_shader.h
)
add_dependencies(RandomAttractors embed_shaders)

#
# Remaining CMake things...
#

set_target_properties(
  ${PROJECT_NAME}
    PROPERTIES 
    OUTPUT_NAME ${PROJECT_NAME}
    SUFFIX ".scr"
)

message(STATUS "Found source files:")
message(STATUS ${SOURCE_FILES})
message(STATUS "Found header files:")
message(STATUS ${SOURCE_FILES})

# Variable for the Libs to add to the Linkers
if (WIN32)
	set(LIBS glfw opengl32 glad)
elseif (UNIX)
	set(LIBS glfw GL glad)
endif ()

set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

set(GLFW_ROOT lib/glfw)
set(GLAD_ROOT lib/glad)
message(STATUS "Using GLFW root:")
message(STATUS ${GLFW_ROOT})
message(STATUS "Using GLAD root:")
message(STATUS ${GLAD_ROOT})
add_subdirectory(lib/glfw)
add_subdirectory(lib/glad)

target_include_directories(${PROJECT_NAME} PUBLIC ${GLFW_ROOT}/include PUBLIC ${GLAD_ROOT}/include/glad)
target_link_directories(${PROJECT_NAME} PRIVATE ${GLFW_ROOT}/src PRIVATE ${GLAD_ROOT}/src)
target_link_libraries(${PROJECT_NAME} ${LIBS})
