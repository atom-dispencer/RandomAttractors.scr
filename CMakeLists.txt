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

# Vertex
embed_shader_glsl(${SHADERS_DIR}/mesh_cs.glsl ${OUT_SHADERS_DIR}/mesh_cs.h mesh_cs_glsl)
embed_shader_glsl(${SHADERS_DIR}/mesh_fs.glsl ${OUT_SHADERS_DIR}/mesh_fs.h mesh_fs_glsl)
embed_shader_glsl(${SHADERS_DIR}/mesh_tcs.glsl ${OUT_SHADERS_DIR}/mesh_tcs.h mesh_tcs_glsl)
embed_shader_glsl(${SHADERS_DIR}/mesh_tes.glsl ${OUT_SHADERS_DIR}/mesh_tes.h mesh_tes_glsl)
embed_shader_glsl(${SHADERS_DIR}/mesh_vs.glsl ${OUT_SHADERS_DIR}/mesh_vs.h mesh_vs_glsl)
embed_shader_glsl(${SHADERS_DIR}/spot_fs.glsl ${OUT_SHADERS_DIR}/spot_fs.h spot_fs_glsl)
embed_shader_glsl(${SHADERS_DIR}/spot_vs.glsl ${OUT_SHADERS_DIR}/spot_vs.h spot_vs_glsl)

add_custom_target(embed_shaders DEPENDS
    # Vertex
    ${CMAKE_BINARY_DIR}/shaders/mesh_cs.h
    ${CMAKE_BINARY_DIR}/shaders/mesh_fs.h
    ${CMAKE_BINARY_DIR}/shaders/mesh_tcs.h
    ${CMAKE_BINARY_DIR}/shaders/mesh_tes.h
    ${CMAKE_BINARY_DIR}/shaders/mesh_vs.h
    ${CMAKE_BINARY_DIR}/shaders/spot_fs.h
    ${CMAKE_BINARY_DIR}/shaders/spot_vs.h
)
add_dependencies(RandomAttractors embed_shaders)

#
# Embed Images
#

function(embed_image IMAGE_FILE OUT_HEADER VAR_NAME)
    message("Embedding image: ${IMAGE_FILE}")

    # Read file as HEX (portable way to handle binary in CMake)
    file(READ ${IMAGE_FILE} IMAGE_HEX HEX)

    # Convert hex string into comma-separated byte values
    string(REGEX MATCHALL ".." IMAGE_BYTES "${IMAGE_HEX}")
    string(JOIN ",0x" IMAGE_BYTES ${IMAGE_BYTES})
    set(IMAGE_BYTES "0x${IMAGE_BYTES}")

    # Get file size
    file(SIZE ${IMAGE_FILE} IMAGE_SIZE)

    # Write header
    file(WRITE ${OUT_HEADER}
        "#pragma once\n"
        "#include <stddef.h>\n\n"
        "static const unsigned char ${VAR_NAME}[] = {${IMAGE_BYTES}};\n"
        "static const size_t ${VAR_NAME}_size = ${IMAGE_SIZE};\n"
    )
endfunction()

set(IMAGES_DIR ${CMAKE_SOURCE_DIR}/src/images)
set(OUT_IMAGES_DIR ${CMAKE_BINARY_DIR}/images)
file(MAKE_DIRECTORY ${OUT_IMAGES_DIR})
target_include_directories(${PROJECT_NAME} PRIVATE ${OUT_IMAGES_DIR})

embed_image(${IMAGES_DIR}/spotlight.png ${OUT_IMAGES_DIR}/spotlight.h spotlight_png_data)

add_custom_target(embed_images DEPENDS
    ${CMAKE_BINARY_DIR}/images/spotlight.h
)
add_dependencies(RandomAttractors embed_images)

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
    set(CMAKE_C_FLAGS "-std=c17 -D_UCRT")
	set(LIBS glfw opengl32 glad ucrt)
elseif (UNIX)
    set(CMAKE_C_FLAGS "-std=c17")
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
