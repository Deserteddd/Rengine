package obj_viewer

import "core:fmt"
import lg "core:math/linalg"
import rand "core:math/rand"
import rd "../Redef"
import b3 "vendor:box3d"

EntityID :: distinct i32


Entity :: struct {
    id:         EntityID,
    name:       string,
    asset_name: string,
    renderable: ^Renderable,
    mesh:       ^Mesh,

    material_overrides: struct {
        color: vec4,
        metallic: f32,
        roughness: f32,
        attributes: bit_set[MaterialAttribute; u32],
    },
    physics:    PhysicsComponent,
    in_frustum: bool
}



AABB :: struct {
    min: vec3,
    max: vec3
}

// This isn't really used anywhere, but will become useful at some point (tri collision)
Mesh :: struct {
    tris: [][3]vec3
}

used_ids: map[EntityID]bool

spawn_entity :: proc(scene: ^Scene, asset: string, under_player: bool, shoot: bool, loc := #caller_location) -> EntityID {
    id := entity_from_asset(scene, asset)
    if id < 0 do return -1

    index := entity_index(scene, id)
    assert(index >= 0, loc = loc)
    entity := scene.entities[index]
    defer scene.entities[index] = entity
    assert(b3.Body_IsValid(entity.physics.b3_body), loc = loc)
    if under_player {
        entity.physics.position = get_player_translation().x - {0, get_entity_aabb(entity).max.y + 0.01, 0}
    } else {
        screen_size := rd.get_window_size()
        origin, dir := ray_from_screen(screen_size/2, screen_size)
        entity.physics.position = origin
        if shoot {
            entity.physics.speed = 20*dir
            entity.physics.dyn = true
        }
        entity.physics.position += 1.5*dir
    }

    assert(b3.Body_IsValid(entity.physics.b3_body), loc = loc)
    add_physics_body(&entity)

    return entity.id
}


remove_entity :: proc(scene: ^Scene, id: EntityID) -> bool {
	index := entity_index(scene, id)
    if index < 0 || index >= len(scene.entities) do return false
    entity := scene.entities[index]
    id := entity.id
    destroy_physics_body(&entity)
    unordered_remove_soa(&scene.entities, index)
    assert(used_ids[id] == true)
    used_ids[id] = false
    return true
}

entity_index :: proc(scene: ^Scene, id: EntityID, loc := #caller_location) -> int {
    if id < 0 do return -1
    for e, i in scene.entities {
        if e.id == id do return i
    }
    return -1
}

// Returns: index in entities array, -1 on failure
@(private = "file")
entity_from_asset :: proc(scene: ^Scene, asset_name: string, entity_name: string = "", loc := #caller_location) -> EntityID {
    entity: Entity
    for asset, i in scene.assets {
        if asset.name == asset_name {
            entity.renderable = &scene.renderables[i]
            entity.mesh = &scene.meshes[i]
            entity.physics.aabb = asset.data.header.aabb
            entity.asset_name = asset.name
            break
        }
    }
    if entity == {} do return -1
    id := get_free_id(scene)

    if entity_name == "" do entity.name = fmt.aprintf("%v-%v", asset_name, id)
    else do entity.name = entity_name

    entity.id = id
    entity.physics.scale = 1
    entity.physics.rotation = lg.QUATERNIONF32_IDENTITY

    assert(!b3.Body_IsValid(entity.physics.b3_body), loc = loc)
    add_physics_body(&entity)
    assert(b3.Body_IsValid(entity.physics.b3_body), loc = loc)

    assert(used_ids[id] == false)
    append(&scene.entities, entity)
    used_ids[id] = true
    return entity.id
}


get_entity_aabb :: #force_inline proc(entity: Entity) -> AABB {
    return AABB {
        min = entity.physics.aabb.min * entity.physics.scale + entity.physics.position,
        max = entity.physics.aabb.max * entity.physics.scale + entity.physics.position
    }
}


@(private = "file")
get_free_id :: proc(scene: ^Scene) -> EntityID {
    for {
        id := EntityID(rand.int31())
        if used_ids[id] do continue
        return id
    }
}