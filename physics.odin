package obj_viewer


import "core:fmt"
import lg "core:math/linalg"
import b3 "vendor:box3d"

PhysicsWorld :: struct {
	id: 		    b3.WorldId,
    ground_body:    b3.BodyId,
	ground_hf:  	b3.ShapeId,
}

PhysicsComponent :: struct {
    dyn: bool,
    position,
    scale,
    speed: vec3,
    rotation: quaternion128,
    aabb: AABB,
    b3_body: b3.BodyId,
    b3_hull: b3.ShapeId // Not sure if necessary to keep
}

init_physics :: proc() {
	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -9.81, 0}
	g.world.id = b3.CreateWorld(world_def)

    {   // Ground heightfield
        body_def := b3.DefaultBodyDef()
            body_def.type = .staticBody
        g.world.ground_body = b3.CreateBody(g.world.id, body_def)

        heights := []f32{
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
        }

        hf_def: b3.HeightFieldDef
        hf_def.heights = raw_data(heights)
        hf_def.countX = 4
        hf_def.countZ = 4
        hf_def.scale = {100000, 1, 100000}
        hf_def.globalMinimumHeight = -10
        hf_def.globalMaximumHeight = 0
        hf_data := b3.CreateHeightField(hf_def)

        shape_def := b3.DefaultShapeDef()
        shape_def.density = 1
        shape_def.baseMaterial.friction = 0.7

        g.world.ground_hf = b3.CreateHeightFieldShape(g.world.ground_body, shape_def, hf_data)
    }



    assert(b3.World_IsValid(g.world.id))
}

// Creates a Box3D body for an entity
add_physics_body :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.id), loc = loc)
    if e.physics.b3_body != {} {
        destroy_physics_body(e)
    }

	body_def := b3.DefaultBodyDef()
    body_def.type = e.physics.dyn ? .dynamicBody : .staticBody
	body_def.position = e.physics.position
	body_def.rotation = e.physics.rotation
    body_def.linearVelocity = e.physics.speed
	e.physics.b3_body = b3.CreateBody(g.world.id, body_def)
    assert(b3.Body_IsValid(e.physics.b3_body), loc = loc)

    aabb := (e.physics.aabb.max + abs(e.physics.aabb.min)) / 2 * e.physics.scale
	box_hull := b3.MakeBoxHull(aabb.x, aabb.y, aabb.z)

	shape_def := b3.DefaultShapeDef()
	shape_def.density = 1
	shape_def.baseMaterial.friction = 0.7
	e.physics.b3_hull = b3.CreateHullShape(e.physics.b3_body, shape_def, &box_hull.base)
    assert(b3.Shape_IsValid(e.physics.b3_hull))
}

// Sets the Box3D position, rotation and velocity for an entity
set_physics_transform :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.id), loc = loc)
    assert(b3.Body_IsValid(e.physics.b3_body), loc = loc)
	b3.Body_SetTransform(
        e.physics.b3_body, 
        e.physics.position, 
        b3.IsValidQuat(e.physics.rotation) ? e.physics.rotation : lg.QUATERNIONF32_IDENTITY
    )
    b3.Body_SetLinearVelocity(e.physics.b3_body, e.physics.speed)
}

destroy_physics_body :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.id), loc = loc)
    assert(b3.Body_IsValid(e.physics.b3_body), loc = loc)
    b3.DestroyBody(e.physics.b3_body)
	e.physics.b3_body = {}
}