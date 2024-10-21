package scenes

import "../common"

import "editor"
import "project_picker"

Application_Scene :: enum {
    Project_Picker,
    Editor,
}

init_current_scene :: proc(screen: Application_Scene) {
    switch screen {
    case .Editor:
        editor.init_scene()

    case .Project_Picker:
        project_picker.init_scene()
    }
}

update_current_scene :: proc(screen: Application_Scene, project: ^common.Project) {
    switch screen {
    case .Editor:
        editor.update_scene(project)

    case .Project_Picker:
        project_picker.update_scene(project)
    }
}

draw_current_scene :: proc(screen: Application_Scene, project: ^common.Project) {
    switch screen {
    case .Editor:
        editor.draw_scene(project)

    case .Project_Picker:
        project_picker.draw_scene()
    }
}

unload_current_scene :: proc(screen: Application_Scene) {
    switch screen {
    case .Editor:
        editor.unload_scene()

    case .Project_Picker:
        project_picker.unload_scene()
    }
}
