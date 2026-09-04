cmake_minimum_required(VERSION 3.16)

project(ShokaReader VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Pdf)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appShokaReader
    main.cpp
    ./Libraries/DocumentManager/DocumentBase.h
    ./Libraries/DocumentManager/DocumentBase.cpp
    ./Libraries/DocumentManager/PdfDocument.h
    ./Libraries/DocumentManager/PdfDocument.cpp
    ./Libraries/DocumentManager/DocumentManager.h
    ./Libraries/DocumentManager/DocumentManager.cpp
)

qt_add_qml_module(appShokaReader
    URI ShokaReader
    QML_FILES
        UI/UI_QML_files/Appwindow.qml
        UI/UI_QML_files/Homescreen.qml
        UI/UI_QML_files/Readerscreen.qml
    RESOURCES
    UI/assets/images/Bookmarks.png
    UI/assets/images/Files.png
    UI/assets/images/LastRead.png
    UI/assets/images/Reading.png
    UI/assets/images/Homescreen.png
    UI/assets/images/AppIcon.png
    UI/assets/images/ThreeDots.png
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
set_target_properties(appShokaReader PROPERTIES
#   MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appShokaReader
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appShokaReader PRIVATE
    Qt6::Quick
    Qt6::Pdf
)

install(TARGETS appShokaReader
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)