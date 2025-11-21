extends SceneTree

func _init():
	print("Starting asset processing...")
	var image = Image.load_from_file("res://assets/sprites/defense_tower.jpg")
	
	if not image:
		print("Failed to load image!")
		quit(1)
		return
		
	# Convert to RGBA8 to ensure we have alpha channel
	image.convert(Image.FORMAT_RGBA8)
	
	# Remove background (simple threshold)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color = image.get_pixel(x, y)
			# Check if pixel is dark (background)
			if color.r < 0.2 and color.g < 0.2 and color.b < 0.2:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				
	# Resize to 32x32 using Nearest Neighbor to preserve pixel art
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	
	# Save back
	var err = image.save_png("res://assets/sprites/defense_tower.png")
	if err != OK:
		print("Failed to save image: %d" % err)
		quit(1)
	else:
		print("Successfully processed image!")
		quit(0)
