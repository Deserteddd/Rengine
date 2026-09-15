package obj_viewer

import rd "../Redef"
import "core:encoding/json"
import "core:log"
import lg "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import stbi "vendor:stb/image"


AssetInstance :: struct {
	asset:           string,
	name:            string,
	position, scale: vec3,
}

SaveFile :: struct {
	checkpoint: [2]vec3,
    noclip:     bool,
	assets:     map[string]string, // name, path
	entities:   []EntitySerialized,
}

EntitySerialized :: struct {
	id:      EntityID,
	name:    string,
	asset:   string,
	physics: PhysicsSerialized,
}

PhysicsSerialized :: struct {
	dyn:                              bool,
	position, scale, rotation, speed: vec3,
	aabb:                             AABB,
}

write_save_file :: proc(scene: Scene, loc := #caller_location) {
	save_path := resolve_project_path("savefile.json", loc)
	log.info(save_path)
	save := SaveFile {
        checkpoint = g.player.noclip ? get_player_translation() : g.player.checkpoint,
        noclip   = g.player.noclip,
		entities = make([]EntitySerialized, len(scene.entities), context.temp_allocator),
		assets   = make(map[string]string, context.temp_allocator),
	}

	for a in scene.assets {
		log.infof("Name: %v, Path: %v", a.name, a.path)
		save.assets[a.name] = a.path
	}

	for e, i in scene.entities {
		rx, ry, rz := lg.euler_angles_from_quaternion(e.physics.rotation, .XYZ)
		save.entities[i] = EntitySerialized {
			id = e.id,
			asset = e.asset_name, // TODO: fix this
			name = e.name,
			physics = PhysicsSerialized {
				dyn = e.physics.dyn,
				position = e.physics.position,
				scale = e.physics.scale,
				speed = e.physics.speed,
				rotation = {rx, ry, rz},
				aabb = e.physics.aabb,
			},
		}
	}
	json_data, err := json.marshal(
		save,
		opt = {pretty = true, mjson_keys_use_quotes = true},
		allocator = context.temp_allocator,
	)
	if err != nil {
		log.errorf("Error marshaling json: %v", err)
	}
	write_err := os.write_entire_file(save_path, json_data)
	assert(err == nil)
	log.infof("%v: Save file writing successful", loc)
}

load_save_file :: proc(path: string) -> SaveFile {
	result: SaveFile
	path := resolve_project_path(path)
	// json_filename := strings.concatenate({path, ".json"}, context.temp_allocator)
	json_data, err := os.read_entire_file_from_path(path, context.temp_allocator)
	if err != nil {
		log.errorf("Failed to load save file: %v - %v", path, err)
		return result
	}

	json_err := json.unmarshal(json_data, &result)
	if json_err != nil {
		log.errorf("Failed to read savefile: %v", json_err)
	}

	return result
}

free_save_file :: proc(savefile: SaveFile) {
	delete(savefile.assets)
	delete(savefile.entities)
}

load_sprite :: proc(path: string, loc := #caller_location) -> rd.Texture {
	pixels, size := load_pixels_byte(path); assert(pixels != nil)
	size_u32: [2]u32 = {u32(size.x), u32(size.y)}
	texture := rd.create_texture(pixels, size_u32.x, size_u32.y)
	free_pixels(pixels)

	return texture
}

load_pixels_byte :: proc(path: string, loc := #caller_location) -> (pixels: []byte, size: [2]i32) {
	path := resolve_project_path(path, loc)
	path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
	pixel_data := stbi.load(path_cstr, &size.x, &size.y, nil, 4)
	if pixel_data == nil {
		log.errorf("%v: Pixel data nill", path, location = loc)
		panic("")
	}
	pixels = slice.bytes_from_ptr(pixel_data, int(size.x * size.y * 4))
	assert(pixels != nil)
	return
}

load_cubemap_texture :: proc(paths: [rd.CubeFace]string) -> rd.TextureCube {
	pixels: [rd.CubeFace][]byte
	size: u32
	for path, side in paths {
		side_pixels, img_size := load_pixels_byte(path)
		assert(side_pixels != nil)
		pixels[side] = side_pixels
		assert(img_size.x == img_size.y)
		if size == 0 do size = u32(img_size.x)
		else do assert(u32(img_size.x) == size)
	}

	// texture := upload_cubemap_texture_sides(copy_pass, pixels, size)
	texture := rd.create_texture_cube(size, pixels)
	for side_pixels in pixels do free_pixels(side_pixels)
	return texture
}

free_pixels_byte :: proc(pixels: []byte) {stbi.image_free(raw_data(pixels))}
free_pixels_u16 :: proc(pixels: []u16) {stbi.image_free(raw_data(pixels))}
free_pixels :: proc {
	free_pixels_byte,
	free_pixels_u16,
}

resolve_project_path :: proc(path: string, loc := #caller_location) -> string {
	if path == "" || os.is_absolute_path(path) {
		return path
	}

	base_dir := filepath.dir(loc.file_path)
	resolved, err := os.join_path({base_dir, path}, context.temp_allocator)
	if err != nil {
		log.errorf("Failed to resolve project path %q from %q: %v", path, base_dir, err)
		return path
	}
	return resolved
}

load_pixels_u16 :: proc(path: string) -> (pixels: []u16, size: [2]i32) {
	path := resolve_project_path(path)
	path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
	pixel_data := stbi.load_16(path_cstr, &size.x, &size.y, nil, 1); assert(pixel_data != nil)
	pixels = slice.from_ptr(pixel_data, int(size.x * size.y))
	assert(pixels != nil)
	return
}

