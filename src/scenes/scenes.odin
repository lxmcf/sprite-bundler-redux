package scenes

import "../common"

import "editor"
import "project_picker"

init_current_scene :: proc(scene: common.Application_Scene) {
    switch scene {
    case .Editor:
        editor.init_scene()

    case .Project_Picker:
        project_picker.init_scene()
    }
}

update_current_scene :: proc(scene: common.Application_Scene, project: ^common.Project) -> common.Application_Scene {
    next_scene := scene

    switch scene {
    case .Editor:
        next_scene = editor.update_scene(project)

    case .Project_Picker:
        next_scene = project_picker.update_scene(project)
    }

    return next_scene
}

draw_current_scene :: proc(scene: common.Application_Scene, project: ^common.Project) {
    switch scene {
    case .Editor:
        editor.draw_scene(project)

    case .Project_Picker:
        project_picker.draw_scene()
    }
}

unload_current_scene :: proc(scene: common.Application_Scene) {
    switch scene {
    case .Editor:
        editor.unload_scene()

    case .Project_Picker:
        project_picker.unload_scene()
    }
}
