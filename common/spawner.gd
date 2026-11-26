class_name Spawner
extends Object

# One place that decides where spawned things (projectiles, puffs, blood, decals, sounds) go,
# so they don't each assume the level is the scene the game was started with.
#
# If the level has a node in the "spawn_root" group, everything goes under it. Otherwise it
# falls back to the current scene, then to the tree root. Give that node an identity
# transform (a plain Node3D at the origin), since spawned nodes are positioned in its space.

const SPAWN_ROOT_GROUP := &"spawn_root"

## Adds `node` to the level. `context` is any node already in the tree (usually `self`).
## Returns false (and frees `node`) if there is nowhere to put it.
static func add_to_level(node: Node, context: Node) -> bool:
	var parent := get_spawn_parent(context)
	if not parent:
		push_error("Spawner: %s is not in the scene tree, can't spawn %s" % [context, node])
		node.free()
		return false
	parent.add_child(node)
	return true

static func get_spawn_parent(context: Node) -> Node:
	if not context or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root := tree.get_first_node_in_group(SPAWN_ROOT_GROUP)
	if root:
		return root
	if tree.current_scene:
		return tree.current_scene
	return tree.root
