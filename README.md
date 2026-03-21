# The Stoat Stash
A single file utility library for godot 4, aimed to be unopinionated and easy to use. Primarily for game jams and prototyping.

## Install
1. Download stoat_stash.gd
2. Add to godot project
3. Add file as autoload script

## Quick Start
```gdscript
# Camera Shake
StoatStash.shake_light($Camera2D)

# Play sound effect
StoatStash.play_sfx(explosion_sound)

# buffered input (great for platformers)
StoatStash.register_input_tracking("jump")
if is_on_floor() and StoatStash.consume_buffered_input("jump",0.15):
	player.jump()

# combo input
if StoatStash.is_input_sequence_just_pressed(["up","down","left","right","left","right"],1.0):
	# do something

# Scene transition with fade
StoatStash.change_scene_with_simple_transition("res://next_level.tscn")
```

## Included
- Math Utils (Circle points, angle wrapping etc)
- Camera (Screen shake (2d/3d), flash effects, bounds checking, etc)
- Audio System (SFX playback, music with crossfading, volume controls, etc)
- Scene Management (Transitions, scene switching, restarts)
- Input Helpers (Buffered Inputs, Sequence/Combo detection)
- Animations (Fade in/out, pulse effects, UI animations etc)
- File I/O (Simple Save/Load system)

## Examples
See the 'Tests/' folder for working code samples

# Contributing
Feel free to contribute. Currently help simplifying the input utilities or adding docs would be greatly appreciated.
Almost all PR's with net positive contributions will be accepted, exceptions to of course PR's containing obfuscated code etc.

# License
MIT License
