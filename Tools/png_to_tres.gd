@tool
extends EditorScript

const EXTERNAL_SOURCE_DIR = "C:/Users/jorda/OneDrive/Desktop/temp"
const OUTPUT_MAT_DIR = "res://Assets/Materials/"

func _run() -> void:
	var dir = DirAccess.open(EXTERNAL_SOURCE_DIR)
	if not dir:
		push_error("Could not open external directory: " + EXTERNAL_SOURCE_DIR)
		return
	
	DirAccess.make_dir_recursive_absolute(OUTPUT_MAT_DIR)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			var src_path = EXTERNAL_SOURCE_DIR.path_join(file_name)
			
			# Load raw image data from outside the project
			var img = Image.load_from_file(src_path)
			if img:
				var tex = ImageTexture.create_from_image(img)
				
				var mat = StandardMaterial3D.new()
				mat.albedo_texture = tex
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				
				var save_path = OUTPUT_MAT_DIR.path_join(file_name.get_basename() + ".tres")
				ResourceSaver.save(mat, save_path)
				count += 1
				
		file_name = dir.get_next()
		
	dir.list_dir_end()
	EditorInterface.get_resource_filesystem().scan()
	print("Embedded %d external PNGs directly into .tres materials!" % count)
