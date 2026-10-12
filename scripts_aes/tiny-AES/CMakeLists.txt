cmake_minimum_required(VERSION 3.12)

project(tiny-aes-wrapper C)

add_compile_options(-g)

add_subdirectory(tiny-AES-c)


file(GLOB TEST_SCRIPTS "test-scripts/*.c")


foreach(SCRIPT ${TEST_SCRIPTS})

    get_filename_component(SCRIPT_NAME ${SCRIPT} NAME_WLE)

    add_executable(${SCRIPT_NAME}
        ${SCRIPT}
    )

    target_link_libraries(${SCRIPT_NAME} 
        tiny-aes
    )

endforeach()