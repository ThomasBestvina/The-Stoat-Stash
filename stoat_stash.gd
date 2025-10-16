"""
MIT License

Copyright (c) 2025 Thomas Bestvina

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

extends Node

##################################################################################
################################## MATH UTILS ####################################
##################################################################################

## Returns true with given probablity (0.0 to 1.0)
func chance(probability: float) -> bool:
	return randf() < clamp(probability, 0.0, 1.0)

## Returns random point within a circle
func random_point_in_circle(radius: float) -> Vector2:
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	return Vector2(cos(angle) * r, sin(angle) * r)

## Returns random point on perimeter of circle
func random_point_on_circle_perimeter(radius: float) -> Vector2:
	var angle = randf() * TAU
	return Vector2(cos(angle) * radius, sin(angle) * radius)

## Wraps angle to 0 to TAU (2*PI) range
func wrap_angle(angle: float) -> float:
	var result = fmod(angle, TAU)
	if result < 0.0:
		result += TAU
	return result

## Returns shortest signed angular distance from `from` to `to` in range [-PI, PI)
func angle_difference(from: float, to: float) -> float:
	var diff = fmod((to - from) + PI, TAU) - PI
	return diff

## Returns snapped position on grid
func snap_to_grid(pos: Vector2, grid_size: float) -> Vector2:
	if grid_size <= 0.0:
		push_warning("snap_to_grid: grid_size must be positive")
		return pos
	return Vector2(round(pos.x/grid_size) * grid_size, round(pos.y / grid_size) * grid_size)

## Returns random color
func random_color() -> Color:
	return Color(randf(), randf(), randf(), 1.0)

## Creates vector from angle and length
func vector_from_angle(angle: float, length: float = 1.0) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * length

## Rotates point around center by angle
func rotate_around_point(point: Vector2, center: Vector2, angle: float) -> Vector2:
	var cos_a = cos(angle)
	var sin_a = sin(angle)
	var dx = point.x - center.x
	var dy = point.y - center.y
	return Vector2(
		center.x + dx * cos_a - dy * sin_a,
		center.y + dx * sin_a - dy * cos_a
	)

##################################################################################
################################## CAMERA UTILS ##################################
##################################################################################

var _active_shake_tweens: Array[Tween] = []
var _active_shake_timers: Array[SceneTreeTimer] = []
var _camera_tween_associations: Dictionary = {}

## Shakes camera and returns tween for optional control
func shake(camera: Camera2D, intensity: float, time: float) -> Tween:
	if not camera or not is_instance_valid(camera):
		push_warning("shake: invalid camera provided")
		return null
	
	if intensity < 0.0 or time < 0.0:
		push_warning("shake: intensity and time must be positive")
		return null
	stop_camera_shake(camera)
	
	var original_offset = camera.offset
	var tween = create_tween()
	tween.set_loops()
	
	# Store reference for cleanup
	_active_shake_tweens.append(tween)
	
	var shake_callable = func():
		if is_instance_valid(camera) and is_instance_valid(tween):
			var random_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			camera.offset = original_offset + random_offset
	
	tween.tween_callback(shake_callable).set_delay(1/Engine.get_frames_per_second())
	
	# Create cleanup timer
	var cleanup_timer = get_tree().create_timer(time)
	_active_shake_timers.append(cleanup_timer)
	
	_camera_tween_associations[camera] = [tween, original_offset, cleanup_timer]
	
	cleanup_timer.timeout.connect(func():
		# Only clean up if this is still the current association for this camera
		if !_camera_tween_associations.has(camera): 
			return
			
		var current_association = _camera_tween_associations[camera]
		# Verify this timer and tween are still the active ones for this camera
		if current_association[0] != tween || current_association[2] != cleanup_timer:
			return  # A new shake has replaced this one
			
		# Proceed with cleanup
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(camera):
			camera.offset = original_offset
		
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
	)
	
	# Clean up if tween is manually killed
	tween.finished.connect(func():
		_active_shake_tweens.erase(tween)
	)
	
	return tween

## Shakes camera with light shake
func shake_light(camera: Camera2D, time: float = 0.2) -> void:
	shake(camera, 3.0, time)

## Shakes camera with medium shake
func shake_medium(camera: Camera2D, time: float = 0.3) -> void:
	shake(camera, 5.0, time)

## Shakes camera with heavy shake
func shake_heavy(camera: Camera2D, time: float = 0.5) -> void:
	shake(camera, 8.0, time)

## Stop all active shakes for specific camera
func stop_camera_shake(camera: Camera2D) -> bool:
	if _camera_tween_associations.has(camera):
		var association = _camera_tween_associations[camera]
		var tween = association[0]
		var original_offset = association[1]
		var cleanup_timer = association[2]
		
		if is_instance_valid(tween):
			tween.kill()
		
		if is_instance_valid(camera):
			camera.offset = original_offset
		
		# Clean up arrays
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
		
		return true
	return false

## Flashes screen for some duration
func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if duration <= 0.0:
		push_warning("flash_screen: duration must be positive")
		return
	
	var flash = ColorRect.new()
	flash.color = color
	flash.modulate.a = 0.8
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)

## Gets the visible bounds of a camera
func get_camera_bounds(camera: Camera2D) -> Rect2:
	if not camera or not is_instance_valid(camera):
		push_warning("get_camera_bounds: invalid camera provided")
		return Rect2()
	
	var zoom = camera.zoom
	if zoom.x <= 0 or zoom.y <= 0:
		push_warning("get_camera_bounds: invalid camera zoom")
		return Rect2()
	
	var viewport_size = get_viewport().size
	var size = Vector2(viewport_size.x, viewport_size.y) / zoom # viewport size is a vector2i
	var top_left = camera.global_position - size / 2
	return Rect2(top_left, size)

## Wraps object position to camera bounds with extra buffer zone
func wrap_node_to_screen(object: Node2D, camera: Camera2D, buffer: float = 0.0) -> void:
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		push_warning("wrap_node_to_screen: invalid object or camera provided")
		return
	
	var bounds = get_camera_bounds(camera)
	if(bounds.size.x <= 0 or bounds.size.y <= 0):
		return
	bounds = bounds.grow(buffer)
	var pos = object.global_position
	
	if pos.x > bounds.position.x + bounds.size.x:
		pos.x = bounds.position.x - buffer
	elif pos.x < bounds.position.x - buffer:
		pos.x = bounds.position.x + bounds.size.x
	
	if pos.y > bounds.position.y + bounds.size.y:
		pos.y = bounds.position.y - buffer
	elif pos.y < bounds.position.y - buffer:
		pos.y = bounds.position.y + bounds.size.y
	
	object.global_position = pos

## Checks if object is completely off screen
func is_off_screen(object: Node2D, camera: Camera2D, buffer: float = 0.0) -> bool:
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		return true
	
	var bounds = get_camera_bounds(camera).grow(buffer)
	return not bounds.has_point(object.global_position)

## Clamps object position to stay withen camera bounds
func clamp_node_to_screen(object: Node2D, camera: Camera2D, margin: float = 0.0) -> Vector2:
	if not object or not is_instance_valid(object) or not camera or not is_instance_valid(camera):
		push_warning("clamp_node_to_screen: invalid object or camera provided")
		return Vector2.ZERO
	
	var bounds = get_camera_bounds(camera).grow(-margin)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return object.global_position
	
	var pos = object.global_position
	pos.x = clamp(pos.x, bounds.position.x, bounds.position.x + bounds.size.x)
	pos.y = clamp(pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
	object.global_position = pos
	return pos

## Shakes 3D camera and returns tween for optional control
func shake_3d(camera: Camera3D, intensity: float, time: float) -> Tween:
	if not camera or not is_instance_valid(camera):
		push_warning("shake_3d: invalid camera provided")
		return null
	
	if intensity < 0.0 or time < 0.0:
		push_warning("shake_3d: intensity and time must be positive")
		return null
	
	stop_camera_shake_3d(camera)
	
	var original_position = camera.position
	var tween = create_tween()
	tween.set_loops()
	
	# Store reference for cleanup
	_active_shake_tweens.append(tween)
	
	
	var shake_callable = func():
		if is_instance_valid(camera) and is_instance_valid(tween):
			var random_offset = Vector3(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			camera.position = original_position + random_offset
	
	tween.tween_callback(shake_callable).set_delay(1/Engine.get_frames_per_second())
	
	# Create cleanup timer
	var cleanup_timer = get_tree().create_timer(time)
	_active_shake_timers.append(cleanup_timer)
	
	_camera_tween_associations[camera] = [tween, original_position, cleanup_timer]
	
	cleanup_timer.timeout.connect(func():
		if !_camera_tween_associations.has(camera):
			return
		
		var current_association = _camera_tween_associations[camera]
		# Verify this timer and tween are still the active ones for this camera
		if current_association[0] != tween || current_association[2] != cleanup_timer:
			return  # A new shake has replaced this one
			
		# Proceed with cleanup
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(camera):
			camera.position = original_position
		
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
	)
	
	# Clean up if tween is manually killed
	tween.finished.connect(func():
		_active_shake_tweens.erase(tween)
	)
	
	return tween

## Shakes 3D camera with light shake
func shake_light_3d(camera: Camera3D, time: float = 0.2) -> void:
	shake_3d(camera, 0.05, time)

## Shakes 3D camera with medium shake
func shake_medium_3d(camera: Camera3D, time: float = 0.3) -> void:
	shake_3d(camera, 0.1, time)

## Shakes 3D camera with heavy shake
func shake_heavy_3d(camera: Camera3D, time: float = 0.5) -> void:
	shake_3d(camera, 0.2, time)

## Stop all active shakes for specific camera
func stop_camera_shake_3d(camera: Camera3D) -> bool:
	if _camera_tween_associations.has(camera):
		var association = _camera_tween_associations[camera]
		var tween = association[0]
		var original_position = association[1]
		var cleanup_timer = association[2]
		
		if is_instance_valid(tween):
			tween.kill()
		
		if is_instance_valid(camera):
			camera.position = original_position
		
		# Clean up arrays
		_active_shake_tweens.erase(tween)
		_active_shake_timers.erase(cleanup_timer)
		_camera_tween_associations.erase(camera)
		
		return true
	return false

## Gets mouse position projected to 3D world on a plane
func get_mouse_world_position_3d_plane(camera: Camera3D) -> Vector3:
	if not camera or not is_instance_valid(camera):
		push_warning("get_mouse_world_position_3d: invalid camera provided")
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if ray_direction.y != 0:
		var t = -ray_origin.y / ray_direction.y
		return ray_origin + ray_direction * t
	
	return Vector3.ZERO

## Gets mouse position projected to 3D world based on ray collision
func get_mouse_world_position_3d_collision(camera: Camera3D) -> Vector3:
	if not camera or not is_instance_valid(camera):
		push_warning("get_mouse_world_position_3d_collision: invalid camera provided")
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

## Cleans up all active camera shake effects and timers
func cleanup_camera_effects() -> void:
	for tween in _active_shake_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_active_shake_tweens.clear()
	
	_active_shake_timers.clear()

##################################################################################
################################## AUDIO UTILS ###################################
##################################################################################
signal current_music_finished

var _music_player: AudioStreamPlayer
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0
var _sfx_muted: bool = false
var _music_muted: bool = false
var _should_loop_music: bool = false
var _music_fade_tween: Tween
var _crossfade_tween: Tween

## Plays an sfx sound
func play_sfx(sound: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not sound or _sfx_muted:
		return
	
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	player.volume_db = _to_db(_sfx_volume * volume)
	player.pitch_scale = clamp(pitch, 0.1, 3.0)
	player.play()
	
	# Auto cleanup
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)

func play_sfx_2d(sound: AudioStream, position: Vector2, volume: float = 1.0, pitch: float = 1.0, max_distance: float = 2000.0) -> void:
	if not sound or _sfx_muted:
		return
	
	var player = AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = sound
	player.volume_db = _to_db(_sfx_volume * volume)
	player.pitch_scale = clamp(pitch, 0.1, 3.0)
	player.max_distance = max_distance
	player.global_position = position
	player.play()
	
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)

func play_sfx_3d(sound: AudioStream, position: Vector3, volume: float = 1.0, pitch: float = 1.0, max_distance: float = 2000.0) -> void:
	if not sound or _sfx_muted:
		return
	
	var player = AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = sound
	player.volume_db = _to_db(_sfx_volume * volume)
	player.pitch_scale = clamp(pitch, 0.1, 3.0)
	player.max_distance = max_distance
	player.global_position = position
	player.play()
	
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)

## Plays music
func play_music(music: AudioStream, volume: float = 1.0, loop: bool = true, fade_in_duration: float = 0.0) -> void:
	if(_music_player == null):
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	if not music:
		push_warning("play_music: invalid audiostream")
		return
	
	# Stop current music and clean up any existing connections
	_music_player.stop()
	_cleanup_music_connections()
	_cleanup_music_tweens()
	
	_should_loop_music = loop
	
	# Create a copy to avoid modifying the original resource
	var music_copy = music.duplicate()
	
	_music_player.stream = music_copy
	
	var target_volume_db = _to_db(_music_volume * volume) if not _music_muted else -80.0
	
	if fade_in_duration > 0.0:
		_music_player.volume_db = -80.0
		_music_player.play()
		
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db", target_volume_db, fade_in_duration)
	else:
		_music_player.volume_db = target_volume_db
		_music_player.play()
	
	if loop:
		_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)

## Crossfades from current music to new music over specified duration
func crossfade_music(new_music: AudioStream, volume: float = 1.0, loop: bool = true, crossfade_duration: float = 1.0) -> void:
	if(_music_player == null):
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	if not new_music:
		return
	
	if crossfade_duration <= 0.0:
		play_music(new_music, volume, loop)
		return
	
	if not _music_player.playing or not _music_player.stream:
		play_music(new_music, volume, loop, crossfade_duration)
		return
	
	var old_player = _music_player
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	
	var music_copy = new_music.duplicate()
	new_player.stream = music_copy
	var target_volume_db = _to_db(_music_volume * volume) if not _music_muted else -80.0
	new_player.volume_db = -80.0  # Start silent
	new_player.play()
	
	_cleanup_music_connections()
	_cleanup_music_tweens()
	_music_player = new_player
	_should_loop_music = loop
	
	if loop:
		_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)
	
	# old player fades out, new player fades in
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)  # Allow multiple simultaneous tweens
	
	# Fade out old player
	_crossfade_tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)
	
	# Fade in new player
	_crossfade_tween.tween_property(new_player, "volume_db", target_volume_db, crossfade_duration)
	
	# Clean up old player when crossfade is complete
	_crossfade_tween.tween_callback(func():
		if is_instance_valid(old_player):
			old_player.queue_free()
	).set_delay(crossfade_duration)

## Helper function called when music finished
func _on_music_finished() -> void:
	current_music_finished.emit()
	
	if _should_loop_music and _music_player and _music_player.stream:
		_music_player.play()
		
		if not _music_player.finished.is_connected(_on_music_finished):
			_music_player.finished.connect(_on_music_finished, CONNECT_ONE_SHOT)

## Stops music
func stop_music() -> void:
	_cleanup_music_connections()
	_should_loop_music = false
	_music_player.stop()

## Clean up any existing music connections
func _cleanup_music_connections() -> void:
	if _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.disconnect(_on_music_finished)

## Clean up any existing music tweens
func _cleanup_music_tweens() -> void:
	if _music_fade_tween and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()
	if _crossfade_tween and is_instance_valid(_crossfade_tween):
		_crossfade_tween.kill()

## Sets volume of all sfx sounds
func set_sfx_volume(volume: float) -> void:
	_sfx_volume = clamp(volume, 0.0, 1.0)

## Sets volume of all music sounds
func set_music_volume(volume: float) -> void:
	if(_music_player == null): return
	_music_volume = clamp(volume, 0.0, 1.0)
	if _music_player.playing and not _music_muted:
		_music_player.volume_db = _to_db(_music_volume)

## Mutes all sfx
func mute_sfx(muted: bool) -> void:
	_sfx_muted = muted

## Mutes all music
func mute_music(muted: bool) -> void:
	if _music_player == null: return
	_music_muted = muted
	if _music_player.playing:
		_music_player.volume_db = -80.0 if muted else _to_db(_music_volume)

## (0.0, 1.0) made into a deciable scale non linearly
func _to_db(linear: float) -> float:
	return -80.0 if linear <= 0.0 else 20.0 * log(linear) / log(10.0)

## Returns whether music is playing
func is_music_playing() -> bool:
	return _music_player != null && _music_player.playing

##################################################################################
################################## SCENE UTILS ###################################
##################################################################################

## Changes scene to target scene path
func change_scene(scene_path: String):
	cleanup_camera_effects()
	clear_input_buffer()
	get_tree().change_scene_to_file(scene_path)

## Changes scene with fade transition
func change_scene_with_simple_transition(scene_path: String, transition_duration: float = 0.5) -> void:
	if transition_duration <= 0.0:
		push_warning("change_scene_with_simple_transition: transition duration must be positive")
		return
	
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, transition_duration / 2)
	tween.tween_callback(change_scene.bind(scene_path))
	tween.tween_property(fade, "modulate:a", 0.0, transition_duration / 2)
	tween.tween_callback(fade.queue_free)

## Restarts current scene
func restart_scene():
	clear_input_buffer()
	get_tree().reload_current_scene()

##################################################################################
################################## INPUT UTILS ###################################
##################################################################################
var _tracked_inputs: Dictionary = {}
var _sequences: Dictionary = {}

enum BufferType {
	TIME,
	FRAMES
}

## Register an action to be tracked for buffering
func register_input_tracking(action: String) -> void:
	if not InputMap.has_action(action):
		push_warning("register_input_tracking: action '" + action + "' does not exist")
		return
	
	_tracked_inputs[action] = {
		"last_pressed_time": 0.0,
		"last_pressed_frame": 0,
		"consumed": true  # Start as consumed so first check doesn't immediately trigger
	}

## Unregister an action from tracking
func unregister_input_tracking(action: String) -> bool:
	return _tracked_inputs.erase(action)

## Check if a tracked action has been pressed within the buffer time
func is_buffered_input_available(action: String, buffer_time: float = 0.1) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	return elapsed <= max(0.0, buffer_time)

## Check if a tracked action has been pressed within the buffer frames
func is_buffered_input_available_frames(action: String, buffer_frames: int = 6) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	return frames_passed <= max(0, buffer_frames)

## Consume a buffered input if it's available within the buffer time
func consume_buffered_input(action: String, buffer_time: float = 0.1) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	
	if elapsed <= max(0.0, buffer_time):
		data.consumed = true
		return true
	
	return false

## Consume a buffered input if it's available within the buffer frames
func consume_buffered_input_frames(action: String, buffer_frames: int = 6) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	
	if frames_passed <= max(0, buffer_frames):
		data.consumed = true
		return true
	
	return false

## Check if buffered input is available without consuming it
func peek_buffered_input(action: String, buffer_time: float = 0.1) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed = current_time - data.last_pressed_time
	return elapsed <= max(0.0, buffer_time)

## Check if buffered input is available without consuming it (frame-based)
func peek_buffered_input_frames(action: String, buffer_frames: int = 6) -> bool:
	if not _tracked_inputs.has(action):
		return false
	
	var data = _tracked_inputs[action]
	
	if data.consumed:
		return false
	
	var current_frame = Engine.get_process_frames()
	var frames_passed = current_frame - data.last_pressed_frame
	return frames_passed <= max(0, buffer_frames)

## Get time elapsed since the tracked action was last pressed
func get_input_elapsed_time(action: String) -> float:
	if not _tracked_inputs.has(action):
		return -1.0
	
	var data = _tracked_inputs[action]
	var current_time = Time.get_unix_time_from_system()
	return current_time - data.last_pressed_time

## Get frames elapsed since the tracked action was last pressed
func get_input_elapsed_frames(action: String) -> int:
	if not _tracked_inputs.has(action):
		return -1
	
	var data = _tracked_inputs[action]
	var current_frame = Engine.get_process_frames()
	return current_frame - data.last_pressed_frame

## Update all tracked inputs - call this every frame
func _update_tracked_inputs() -> void:
	var current_time = Time.get_unix_time_from_system()
	var current_frame = Engine.get_process_frames()
	
	for action in _tracked_inputs.keys():
		if Input.is_action_just_pressed(action):
			var data = _tracked_inputs[action]
			data.last_pressed_time = current_time
			data.last_pressed_frame = current_frame
			data.consumed = false

## Returns true if an entire input sequence has been pressed
func is_input_sequence_just_pressed(sequence: Array[String], timeout: float = 2.0) -> bool:
	if sequence.is_empty():
		push_warning("is_input_sequence_just_pressed: empty sequence provided")
		return false
	
	for action in sequence:
		if not InputMap.has_action(action):
			push_warning("is_input_sequence_just_pressed: action '" + action + "' does not exist")
			return false
	
	var sequence_key = "_".join(sequence)
	
	if not _sequences.has(sequence_key):
		_sequences[sequence_key] = {
			"target_sequence": sequence,
			"current_inputs": [],
			"last_input_time": 0.0,
			"timeout": max(0.1, timeout)
		}
	
	var seq_data = _sequences[sequence_key]
	var current_time = Time.get_unix_time_from_system()
	
	var new_input = ""
	for action in sequence:
		if Input.is_action_just_pressed(action):
			new_input = action
			break
	
	if new_input == "":
		return false
	
	# Check if too much time has passed since last input
	if seq_data.current_inputs.size() > 0:
		var time_diff = current_time - seq_data.last_input_time
		if time_diff > seq_data.timeout:
			seq_data.current_inputs.clear()
	
	seq_data.last_input_time = current_time
	
	var expected_index = seq_data.current_inputs.size()
	
	if expected_index < sequence.size() and sequence[expected_index] == new_input:
		seq_data.current_inputs.append(new_input)
		
		# Check if sequence is complete
		if seq_data.current_inputs.size() == sequence.size():
			seq_data.current_inputs.clear()
			return true
	else:
		# Wrong input - check if it's the start of the sequence
		if sequence[0] == new_input:
			seq_data.current_inputs = [new_input]
		else:
			seq_data.current_inputs.clear()
	
	return false

## Returns progress of sequence completion (0.0 to 1.0), or 0.0 if sequence doesn't exist
func get_sequence_progress(sequence: Array[String]) -> float:
	if sequence.is_empty():
		return 0.0
	
	var sequence_key = "_".join(sequence)
	
	if not _sequences.has(sequence_key):
		return 0.0
	
	var seq_data = _sequences[sequence_key]
	
	# Check if sequence has timed out
	var current_time = Time.get_unix_time_from_system()
	if seq_data.current_inputs.size() > 0:
		var time_diff = current_time - seq_data.last_input_time
		if time_diff > seq_data.timeout:
			seq_data.current_inputs.clear()
			return 0.0
	
	return float(seq_data.current_inputs.size()) / float(sequence.size())

## Clears all input buffers and sequences, useful when changing scenes
func clear_input_buffer():
	_tracked_inputs.clear()
	_sequences.clear()

## Clears only input sequences, keeping input buffers
func clear_input_sequences():
	_sequences.clear()

## Returns array of currently tracked actions
func get_tracked_actions() -> Array[String]:
	var actions: Array[String] = []
	for action in _tracked_inputs.keys():
		actions.append(action)
	return actions

## Helper function to update sequence timeouts
func _update_sequence_timeouts(_delta: float) -> void:
	var current_time = Time.get_unix_time_from_system()
	
	for sequence_name in _sequences.keys():
		var seq_data = _sequences[sequence_name]
		if seq_data.current_inputs.size() > 0:
			var time_diff = current_time - seq_data.last_input_time
			if time_diff > seq_data.timeout:
				seq_data.current_inputs.clear()

##################################################################################
################################## TIMER UTILS ###################################
##################################################################################
## Calls a function after delay
func delayed_call(callback: Callable, delay: float) -> void:
	if delay < 0.0:
		push_warning("delayed_call: delay must be positive")
		delay = 0.0
	
	await get_tree().create_timer(delay).timeout
	if(callback.is_valid()):
		callback.call()

## Repeats a function call at intervals
func repeat_call(callback: Callable, interval: float, times: int = -1) -> void:
	if interval <= 0.0:
		push_warning("repeat_call: interval must be positive")
		return
	
	var count = 0
	while times == -1 or count < times:
		if callback.is_valid():
			callback.call()
			await get_tree().create_timer(interval).timeout
			count += 1
		else:
			return

##################################################################################
################################## NODE UTILS ####################################
##################################################################################

## Safely connects a signal, avoiding duplicate connections
func safe_signal_connect(signal_obj: Signal, callable: Callable) -> bool:
	if not callable.is_valid():
		push_warning("safe_connect: invalid callable provided")
		return false
	if not signal_obj.is_connected(callable):
		signal_obj.connect(callable)
		return true
	return false

## Safely disconnects a signal, avoiding duplicate connections
func safe_signal_disconnect(signal_obj: Signal, callable: Callable) -> bool:
	if not callable.is_valid():
		push_warning("safe_disconnect: invalid callable provided")
		return false
	if signal_obj.is_connected(callable):
		signal_obj.disconnect(callable)
		return true
	return false

##################################################################################
################################# ANIMATION UTILS ################################
##################################################################################

## Makes node pulse by scaling
func pulse_node(node: CanvasItem, scale_mult: float = 1.2, duration: float = 0.2) -> void:
	if not node or not is_instance_valid(node):
		push_warning("pulse_node: invalid node provided")
		return
	
	if duration <= 0.0:
		push_warning("pulse_node: duration must be positive")
		return
	
	var original_scale = node.scale
	var target_scale = original_scale * abs(scale_mult)
	
	var tween = create_tween()
	tween.tween_property(node, "scale", target_scale, duration/2)
	tween.tween_property(node, "scale", original_scale, duration/2)

## Fades node in
func fade_in(node: CanvasItem, duration: float = 0.3) -> void:
	if not node or not is_instance_valid(node):
		push_warning("fade_in: invalid node provided")
		return
	
	if duration <= 0.0:
		node.modulate.a = 1.0
		node.visible = true
		return
	
	node.modulate.a = 0.0
	node.visible = true
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

## Fades node out
func fade_out(node: CanvasItem, duration: float = 0.3, hide_when_done: bool = true) -> void:
	if not node or not is_instance_valid(node):
		push_warning("fade_out: invalid node provided")
		return
	
	if duration <= 0.0:
		node.modulate.a = 0.0
		if hide_when_done:
			node.visible = false
		return
	
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	if hide_when_done:
		tween.tween_callback(func(): if is_instance_valid(node): node.visible = false)

func create_floating_text(
	text: String,
	position: Vector2,
	duration: float = 1.0,
	text_color: Color = Color.WHITE,
	outline_color: Color = Color.BLACK,
	outline_size: int = 0,
	font_size: int = 16,
	movement: Vector2 = Vector2(0, -50),
	fade_out_effect: bool = true,
	scale_effect: bool = false,
	easing: Tween.TransitionType = Tween.TRANS_LINEAR,
	font: Font = null # always the most annoying to specify
) -> Label:
	if duration <= 0.0:
		push_warning("create_floating_text: duration must be positive")
		return null
	
	var label = Label.new()
	label.text = text
	label.modulate = text_color
	label.position = position
	label.z_index = 100
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = font_size
	label_settings.font_color = text_color
	
	if font:
		label_settings.font = font
	
	# Apply outline
	if outline_size > 0:
		label_settings.outline_size = outline_size
		label_settings.outline_color = outline_color
	
	label.label_settings = label_settings
	
	# Center the label on the position (need to wait one frame for size to update)
	await get_tree().process_frame
	if not is_instance_valid(label):
		return null
	
	label.pivot_offset = label.size / 2
	label.position -= label.size / 2
	
	var tween = create_tween()
	tween.set_trans(easing)
	tween.set_parallel(true)
	
	# Movement animation
	if movement != Vector2.ZERO:
		var target_pos = position + movement - label.size / 2
		tween.tween_property(label, "position", target_pos, duration)
	
	# Fade out animation
	if fade_out_effect:
		tween.tween_property(label, "modulate:a", 0.0, duration)
	
	# Scale effect (pop in then fade)
	if scale_effect:
		label.scale = Vector2.ZERO
		tween.tween_property(label, "scale", Vector2.ONE, duration * 0.2).set_trans(Tween.TRANS_BACK)
	
	# Cleanup
	tween.tween_callback(label.queue_free).set_delay(duration)
	
	return label

##################################################################################
################################## EASING FUNCTIONS ##############################
##################################################################################
# Standalone easing functions
func ease_in_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - cos((t * PI) / 2.0)

func ease_out_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return sin((t * PI) / 2.0)

func ease_in_out_sine(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return -(cos(PI * t) - 1.0) / 2.0

func ease_in_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t

func ease_out_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_out_quad(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

func ease_in_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * t

func ease_out_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func ease_in_out_cubic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0

func ease_in_elastic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	elif t == 1.0:
		return 1.0
	else:
		var c4 = (2.0 * PI) / 3.0
		return -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * c4)

func ease_out_elastic(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	if t == 0.0:
		return 0.0
	elif t == 1.0:
		return 1.0
	else:
		var c4 = (2.0 * PI) / 3.0
		return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0

func ease_in_bounce(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return 1.0 - ease_out_bounce(1.0 - t)

func ease_out_bounce(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	var n1 = 7.5625
	var d1 = 2.75
	
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375

##################################################################################
#################################### UI UTILS ####################################
##################################################################################

## Animates text with a typewriter effect
func typewriter_text(label: Label, text: String, speed: float = 0.05) -> void:
	if not label or not is_instance_valid(label):
		push_warning("typewriter_text: invalid label provided")
		return
	
	var safe_speed = max(0.001, speed) # prevent infinite loops
	
	label.text = ""
	for i in range(text.length()):
		if not is_instance_valid(label):
			return
		label.text += text[i]
		await get_tree().create_timer(safe_speed).timeout

## Scales UI element in from specified direction
func animate_ui_slide_in(control: Control, direction: Vector2, duration: float = 0.3, easing: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	if not control or not is_instance_valid(control):
		push_warning("animate_ui_slide_in: invalid control provided")
		return
	
	if duration <= 0.0:
		control.visible = true
		return
	
	direction = -direction # this allows us to pass in simpley Vector2.UP and it makes sense.
	
	var original_pos = control.position
	var start_pos = original_pos + direction * 500
	
	control.position = start_pos
	control.visible = true
	
	var tween = create_tween()
	tween.set_trans(easing)
	tween.tween_property(control, "position", original_pos, duration)

## Scales UI element in with scale effect
func animate_ui_scale_in(control: Control, duration: float = 0.3, easing: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	if not control or not is_instance_valid(control):
		push_warning("animated_ui_scale_in: invalid control provided")
		return
	
	if duration <= 0.0:
		control.visible = true
		return
	
	var original_scale = control.scale
	control.scale = Vector2.ZERO
	control.visible = true
	
	var tween = create_tween()
	tween.set_trans(easing)
	tween.tween_property(control, "scale", original_scale, duration)

##################################################################################
#################################### FILE UTILS ##################################
##################################################################################

## Saves data to file, returns bool of success
func save_data(data: Dictionary, filename: String = "save_game.dat") -> bool:
	if filename.is_empty():
		push_warning("save_data: filename cannot be empty")
		return false
	
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
		return true
	push_warning("save_data: failed to open file for writing: " + filename)
	return false

## Loads data from file
func load_data(filename: String = "save_game.dat") -> Dictionary:
	if filename.is_empty():
		push_warning("load_data: filename cannot be empty")
		return {}
	
	var file = FileAccess.open("user://" + filename, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		if json_string.is_empty():
			return {}
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK and json.data is Dictionary:
			return json.data
		else:
			push_warning("load_data: failed to parse JSON from file: " + filename)
	return {}

## Deletes save file
func delete_save(filename: String = "save_game.dat"):
	if filename.is_empty():
		push_warning("delete_save: filename cannot be empty")
		return false
	
	var full_path = "user://" + filename
	if FileAccess.file_exists(full_path):
		var error = DirAccess.remove_absolute(full_path)
		if error != OK:
			push_warning("delete_save: failed to delete file: " + filename)
			return false
		return true
	return true  # File doesn't exist, consider it "successfully deleted"

##################################################################################
###################################### UPDATE ####################################
##################################################################################
func _ready():
	set_process(true)

func _process(delta: float) -> void:
	_update_tracked_inputs()
	_update_sequence_timeouts(delta)
