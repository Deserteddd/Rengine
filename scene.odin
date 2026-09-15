package obj_viewer

import lg "core:math/linalg"

Scene :: struct {
    assets:             []Asset,
    renderables:        []Renderable,
    meshes:             []Mesh,
    entities:       #soa[dynamic]Entity,
}

load_scene:: proc(path: string) -> Scene {
	entity_from_serialized :: proc(scene: Scene, serialized: EntitySerialized) -> Entity {
		entity: Entity
		entity.id = serialized.id
		assert(used_ids[serialized.id] == false)
		used_ids[serialized.id] = true
		entity.name = serialized.name
		entity.physics = PhysicsComponent {
			dyn      = serialized.physics.dyn,
			position = serialized.physics.position,
			scale    = serialized.physics.scale,
			speed    = serialized.physics.speed,
			rotation = lg.quaternion_from_euler_angles(
				serialized.physics.rotation.x,
				serialized.physics.rotation.y,
				serialized.physics.rotation.z,
				.XYZ,
			),
			aabb     = serialized.physics.aabb,
		}

		for asset, index in scene.assets {
			if asset.name == serialized.asset {
				entity.asset_name = serialized.asset
				entity.renderable = &scene.renderables[index]
				entity.mesh = &scene.meshes[index]
				break
			}
		}
		add_physics_body(&entity)
		return entity
	}

	save_file := load_save_file(path)
	defer free_save_file(save_file)
	create_player(save_file.checkpoint.x, save_file.checkpoint.y)
    g.player.noclip = save_file.noclip

	assets: [dynamic]Asset
	for asset, asset_path in save_file.assets {
		data, ok := load_asset_data(asset_path)
		if ok {
			append(&assets, Asset{asset, asset_path, data})
		}
	}

	scene: Scene
	scene.assets = assets[:]
	scene.renderables = make([]Renderable, len(scene.assets))
	scene.meshes = make([]Mesh, len(scene.assets))
	for &asset, i in scene.assets {
		scene.renderables[i] = create_render_object(&asset)
		scene.meshes[i] = create_mesh(asset)
	}


	for entity in save_file.entities {
		append(&scene.entities, entity_from_serialized(scene, entity))
	}
	for &asset in assets {
		delete(asset.data.file)
	}
	return scene
}