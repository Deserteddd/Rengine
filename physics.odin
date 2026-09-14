package obj_viewer


import "core:fmt"
import lg "core:math/linalg"
import b3 "vendor:box3d"

World :: struct {
	world_id: 		b3.WorldId,
	ground_body:	b3.BodyId,
	ground_hull:	b3.ShapeId,
}

PhysicsComponent :: struct {
    dyn: bool,
    position,
    scale,
    speed: vec3,
    rotation: quaternion128,
    aabb: AABB,
    b3: struct {
    	body: b3.BodyId,
     	hull: b3.ShapeId // Not sure if necessary to keep
    }
}

init_physics :: proc() {
	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -9.81, 0}
	g.world.world_id = b3.CreateWorld(world_def)
    assert(b3.World_IsValid(g.world.world_id))
}

add_physics_body :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.world_id), loc = loc)
    if e.physics.b3 != {} {
        destroy_physics_body(e)
    }

	body_def := b3.DefaultBodyDef()
    body_def.type = e.physics.dyn ? .dynamicBody : .staticBody
	body_def.position = e.physics.position
	body_def.rotation = e.physics.rotation
    body_def.linearVelocity = e.physics.speed
	e.physics.b3.body = b3.CreateBody(g.world.world_id, body_def)
    assert(b3.Body_IsValid(e.physics.b3.body), loc = loc)

    aabb := (e.physics.aabb.max + abs(e.physics.aabb.min)) / 2 * e.physics.scale
	box_hull := b3.MakeBoxHull(aabb.x, aabb.y, aabb.z)

	shape_def := b3.DefaultShapeDef()
	shape_def.density = 1
	shape_def.baseMaterial.friction = 0.7
	e.physics.b3.hull = b3.CreateHullShape(e.physics.b3.body, shape_def, &box_hull.base)
    assert(b3.Shape_IsValid(e.physics.b3.hull))
}


set_physics_transform :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.world_id), loc = loc)
    assert(b3.Body_IsValid(e.physics.b3.body), loc = loc)
	b3.Body_SetTransform(
        e.physics.b3.body, 
        e.physics.position, 
        b3.IsValidQuat(e.physics.rotation) ? e.physics.rotation : lg.QUATERNIONF32_IDENTITY
    )
    b3.Body_SetLinearVelocity(e.physics.b3.body, e.physics.speed)
}

destroy_physics_body :: proc(e: ^Entity, loc := #caller_location) {
    assert(b3.World_IsValid(g.world.world_id), loc = loc)
    assert(b3.Body_IsValid(e.physics.b3.body), loc = loc)
    b3.DestroyBody(e.physics.b3.body)
	e.physics.b3 = {}
}