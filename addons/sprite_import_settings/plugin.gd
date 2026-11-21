@tool
extends EditorPlugin

## Every texture under this folder (and its subfolders) gets the import settings below.
const SPRITE_ROOT := "res://assets/sprites/"

const SPRITE_IMPORT_PARAMS := {
	"compress/mode": 0, # Lossless: no color smearing on pixel art
	"mipmaps/generate": false, # No blurring at a distance
	"detect_3d/compress_to": 0, # Stop Godot switching sprites to VRAM compression when first used in 3D
}

var _fs: EditorFileSystem


func _enter_tree() -> void:
	_fs = EditorInterface.get_resource_filesystem()
	_fs.resources_reimported.connect(_on_resources_reimported)
	# Fix sprites that already exist, once the editor has finished scanning the project
	if _fs.is_scanning():
		_fs.filesystem_changed.connect(_fix_all_sprites, CONNECT_ONE_SHOT)
	else:
		_fix_all_sprites.call_deferred()


func _exit_tree() -> void:
	if _fs and _fs.resources_reimported.is_connected(_on_resources_reimported):
		_fs.resources_reimported.disconnect(_on_resources_reimported)
	if _fs and _fs.filesystem_changed.is_connected(_fix_all_sprites):
		_fs.filesystem_changed.disconnect(_fix_all_sprites)


func _on_resources_reimported(resources: PackedStringArray) -> void:
	var sprites := PackedStringArray()
	for path in resources:
		if path.begins_with(SPRITE_ROOT):
			sprites.append(path)
	if not sprites.is_empty():
		# Defer so we don't start a new import while Godot is still finishing this one
		_fix_sprites.call_deferred(sprites)


func _fix_all_sprites() -> void:
	var paths := PackedStringArray()
	_collect_imported_files(SPRITE_ROOT, paths)
	_fix_sprites(paths)


func _collect_imported_files(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	for file in dir.get_files():
		if file.ends_with(".import"):
			out.append(dir_path.path_join(file.trim_suffix(".import")))
	for sub in dir.get_directories():
		_collect_imported_files(dir_path.path_join(sub), out)


func _fix_sprites(paths: PackedStringArray) -> void:
	if _fs.is_scanning():
		# Try again shortly; Godot can't start a reimport mid-scan
		get_tree().create_timer(0.5).timeout.connect(_fix_sprites.bind(paths), CONNECT_ONE_SHOT)
		return

	var to_reimport := PackedStringArray()
	for path in paths:
		var import_path := path + ".import"
		var cfg := ConfigFile.new()
		if cfg.load(import_path) != OK:
			continue
		if cfg.get_value("remap", "importer", "") != "texture":
			continue # Skip sounds and anything else that isn't a 2D texture
		var changed := false
		for key in SPRITE_IMPORT_PARAMS:
			if cfg.get_value("params", key) != SPRITE_IMPORT_PARAMS[key]:
				cfg.set_value("params", key, SPRITE_IMPORT_PARAMS[key])
				changed = true
		if changed:
			cfg.save(import_path)
			to_reimport.append(path)

	if not to_reimport.is_empty():
		print("Sprite Import Settings: reimporting %d sprite(s) as Lossless, no mipmaps" % to_reimport.size())
		_fs.reimport_files(to_reimport)
