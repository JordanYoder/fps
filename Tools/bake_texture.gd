@tool
extends EditorScript

func _run():
	# 1. Load the raw PNG image
	var img = Image.load_from_file("C:/Users/jorda/Downloads/PNG/Light/texture_07.png") # Change to your actual PNG path

	# 2. Convert it into an ImageTexture
	var tex = ImageTexture.create_from_image(img)

	# 3. Save it as a permanent standalone resource
	ResourceSaver.save(tex, "res://Assets/Materials/_checkerboard.tres")
	print("Texture baked successfully!")
