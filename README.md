# Codebase description

## General

This project is an early in development game engine. It currently works like this:

1. Initialize core systems like the platform abstraction layer, renderer and

2. Take in preprocessed asset binaries (the preprocessor is a separate project vibecoded in Rust) and a JSON-savefile describing serialized entities and some miscellanious data, and construct a scene from them.

3. Call a run function on the scene, which will take in user input, simulate the game state and render it.

4. That's it! In it's current state, the program won't do any cleanup before exiting. This will be adressed when i'll come around to implementing userland runtime scene loading.

## Core data structures

### Globals

All global variables are stored in `g`, which is a value of unnamed type with a global lifetime. Reading the code, you will see this alot.

### Entity

***Entity*** contains all the data associated with a single entity (an object in the world). Entities don't own any heap memory. Instead, they store pointers to things like *Renderables* and ***Meshes*** (currently not used for anything).

### Renderable

*Renderables* store everything needed to render an asset. This includes gpu-handles for triangle and material data, as well as cpu-side values such as triangle to material mapping.

### PhysicsComponent

**Note:** Physics are in a sorry state due to WIP implementation of [Box3D](https://box2d.org/documentation3d/index.html) physics. There is currently a multiple-truth problem with assosiated bloat code to synchronize Box3D with the existing physics. I'm thinking about fixing this by making Box3D the only source of trurth and querying it where necessary.

***PhysicsComponents*** store per entity data about their physical attributes, as well as handles for their Box3D bodies. While PhysicsComponents are stack-based, destroying an entity requires destroying the Box3D objects as to not have orphaned bodies.

### Renderer

Currently ***Scenes*** **don't** contain everything that is being drawn on screen. The engine has some hardcoded visual elements such as an ocean, distance fog, skybox and fps-counter. There is also a singe pointlight that always follows the player. The ***Renderer*** struct is mostly comprised of shaders. The main shaders used for rendering the entities are `vs_gfx` and `ps_gfx`.

## GUI

The engine uses Odin bindings for [Dear ImGui](https://github.com/ocornut/imgui). Not much to say here. The GUI code is very self-contained in it's own file.