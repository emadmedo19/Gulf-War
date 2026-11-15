extends RefCounted

var texture: Texture2D
var frames: Dictionary

func _init():
	texture = load("res://assets/mummy_eri.png")
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mummy_frames.json"))

func draw_part(canvas: CanvasItem, frame: Dictionary, anchor: Vector2, face: int, tint: Color):
	var r = frame.rect
	var source = Rect2(r[0], r[1], r[2], r[3])
	var scale_value = float(frames.scale)
	var pivot = Vector2(frame.pivot[0], frame.pivot[1]) * scale_value
	var size = source.size * scale_value
	var dest = Rect2(anchor - pivot, size)
	if face < 0:
		dest.position.x = anchor.x + pivot.x
		dest.size.x = -size.x
	canvas.draw_texture_rect_region(texture, dest, source, tint)

func draw_actor(canvas: CanvasItem, pos: Vector2, face: int, moving: bool, firing: bool, airborne: bool, time: float, tint: Color):
	var lower_index = int(time * frames.walk_fps) % frames.walk_lower.size() if moving else 0
	if airborne: lower_index = 4 if moving else 8
	var upper_sequence = frames.fire_upper if firing else frames.walk_upper
	var upper_index = int(time * (frames.fire_fps if firing else 7)) % upper_sequence.size() if moving or firing else 0
	# Fixed shared hip and foot anchors: changing crop dimensions never shifts the character.
	draw_part(canvas, frames.walk_lower[lower_index], pos, face, tint)
	var hip = pos + Vector2(frames.upper_offset[0] * face, frames.upper_offset[1]) * float(frames.scale)
	draw_part(canvas, upper_sequence[upper_index], hip, face, tint)
