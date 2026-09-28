extends RefCounted
## SpriteUtil
##
## Builds a Sprite2D whose on-screen size is based on the VISIBLE part of
## the artwork, not the full image canvas. AI-generated images usually
## have big transparent margins around the character, so scaling the
## whole canvas to a fixed height makes the character itself look tiny.
## This finds the visible bounding box, crops to it, then scales that to
## the requested height -- so every character ends up a consistent size.

const ALPHA_THRESHOLD := 0.1 # ignore near-invisible stray pixels
const MAX_SAMPLES := 256     # scan at most ~256x256 points, keeps this fast


static func build_sprite(texture: Texture2D, target_height: float, feet_y: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # crisp pixel edges

	var visible_height := float(texture.get_height())
	var image := texture.get_image()

	if image != null:
		if image.is_compressed():
			image.decompress()

		var rect := _visible_rect(image)
		if rect.size.x > 0 and rect.size.y > 0:
			sprite.region_enabled = true
			sprite.region_rect = Rect2(rect)
			visible_height = float(rect.size.y)

	var s := target_height / visible_height
	sprite.scale = Vector2(s, s)
	# Bottom of the visible artwork sits on the "ground" line (feet_y).
	sprite.position = Vector2(0, feet_y - target_height / 2.0)
	return sprite


static func _visible_rect(image: Image) -> Rect2i:
	var w := image.get_width()
	var h := image.get_height()
	var step := maxi(1, maxi(w, h) / MAX_SAMPLES)

	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1

	for y in range(0, h, step):
		for x in range(0, w, step):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if max_x < 0:
		return Rect2i() # fully transparent; caller falls back to the whole image

	# Sampling every `step` pixels can undershoot the edge slightly, so pad by one step.
	min_x = maxi(0, min_x - step)
	min_y = maxi(0, min_y - step)
	max_x = mini(w - 1, max_x + step)
	max_y = mini(h - 1, max_y + step)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
