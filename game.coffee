import * as THREE from 'three'
import {TextGeometry} from 'three/addons/geometries/TextGeometry.js'
import {FontLoader} from 'three/addons/loaders/FontLoader.js'

export TICKER_DONE = Symbol("TICKER_DONE")

export class Base
	constructor: (@radius) ->
		@geometry = new THREE.SphereGeometry @radius, 30, 30
		@material = new THREE.MeshBasicMaterial color: 0xaaaaaa
		
		@object = new THREE.Mesh @geometry, @material

		@base_health = 1.0
	
	hit: =>
		@base_health = 0.0
		text = new Text ("-1")
		@object.add text.object

	tick: (dt) =>
		@base_health += dt*2.0
		@base_health = Math.min 1, @base_health

		

		@material.color.lerpColors(
			new THREE.Color(0xff0000),
			new THREE.Color("white"),
			@base_health**2
		)

# THIS IS BAD!
hack_font = null
(new FontLoader()).load "node_modules/three/examples/fonts/droid/droid_sans_bold.typeface.json", (font) ->
	hack_font = font

class Text
	constructor: (text) ->
		console.log hack_font
		geometry = new TextGeometry text,
			#size: 0.1
			#height: 0.1
			font: hack_font
		material = new THREE.MeshBasicMaterial
			color: 0xffffff
		@object = new THREE.Mesh geometry, material
		#@object.scale.set 0.1, 0.1, 0.1

class Target
	constructor: (opts={}) ->
		{
		@distance=1.0
		@angle=(Math.random() - 0.5)/2*Math.PI
		@speed=0.2
		@radius=0.05
		@death_dur=0.2
		@dead=false
		@fade_in_dur=0.05
		@direction,
		@opacity=0.8
		}=opts
		@done=false

		@blow_up = true
				
		geometry = new THREE.SphereGeometry(@radius, 32, 32)
		material = new THREE.MeshBasicMaterial
			color: 0xffffff
			transparent: true
		@object = new THREE.Mesh geometry, material
		
		geometry = new THREE.SphereGeometry(0.01, 32, 32)
		material = new THREE.MeshBasicMaterial color: 0xffffff, transparent: true, depthTest: false
		@bullseye = new THREE.Mesh geometry, material
		#@bullseye.renderOrder = 1.0
		@object.add @bullseye

		@set_opacity 1.0
		
		dx = Math.sin @angle
		dy = Math.cos @angle
		@object.position.x = dx*@distance
		@object.position.y = dy*@distance
		@set_opacity 0.0
		@object.scale.set 0.0, 0.0, 0.0

		if not @direction?
			@direction = Math.atan2(-dx, -dy)
		
		@vx = Math.sin(@direction)*@speed
		@vy = Math.cos(@direction)*@speed

		@t = 0

	set_opacity: (o) =>
		@object.material.opacity = @opacity*o
		@bullseye.material.opacity = @opacity*o

	set_speed: (@speed) ->
		@vx = Math.sin(@direction)*@speed
		@vy = Math.cos(@direction)*@speed

	tick: (dt) =>
		@t += dt
		@object.position.x += @vx*dt
		@object.position.y += @vy*dt
		
		progress = Math.min(1, @t/@fade_in_dur)
		@set_opacity progress
		@object.scale.set progress, progress, progress
		
		@distance = (@object.position.x**2 + @object.position.y**2)**0.5
		@angle = Math.atan2(@object.position.x, @object.position.y)

		if @distance > 2.0 and not @dead
			@hit()

		if @rush_at? and @t > @rush_at
			@rush_at = null
			@set_speed 3.0

		if @dead and not @done
			t = @t - @death_t
			if t > @death_dur
				@done = true
				return TICKER_DONE
			progress = Math.max(Math.min(1 - t/@death_dur, 1), 0)
			if @blow_up
				s = (0.1 + 1)/(0.1 + progress)
				@object.scale.set s, s, s
			else
				s = 1/((0.1 + 1)/(0.1 + progress))
				@object.scale.set s, s, s
			@set_opacity progress
	
	rush: =>
		@rush_at = @t + 0.1
	
	hit: =>
		@dead = true
		#@set_speed 0.0
		@death_t = @t + 0.1

	vanish: ->
		@dead = true
		@blow_up = false
		@death_t = @t

class RayObject
	constructor: (@dx, @dy, @color, opts={}) ->
		{@duration=0.5, @length=2.0} = opts
		raypoints = [
			new THREE.Vector3(0, 0, 0),
			new THREE.Vector3(@dx*@length, @dy*@length, 0)
		]
		#material = new THREE.LineBasicMaterial color: @color, transparent: true
		#geometry = new THREE.BufferGeometry().setFromPoints raypoints
		#@object = new THREE.Line geometry, material

		material = new THREE.MeshBasicMaterial color: @color, transparent: true
		geometry = new THREE.CylinderGeometry 0.005, 0.005, @length, 32
		@object = new THREE.Mesh geometry, material
		
		angle = Math.atan2 @dx, @dy
		@object.position.x = @dx*@length/2
		@object.position.y = @dy*@length/2
		@object.rotation.z = -angle
		
		@t = 0
		@done = false
	
	tick: (dt) =>
		@t += dt
		return TICKER_DONE if @done
		if @t > @duration
			@done = true
			return TICKER_DONE
		@object.material.opacity = 1 - @t/@duration

class TrialBase
	constructor: (opts) ->
		{
		@runner
		@scene
		@base
		}=opts
		

		@objects = new Set()
		@targets = new Set()
		
		@time = 0.0

		@shot_start = null
		
		@shots_taken = []
		@target_hits = []
		@base_collisions = []
		
	add_object: (object) =>
		@objects.add object
		if object.object
			@scene.add object.object
		return object
	
	add_target: (opts) ->
		target = new Target opts
		@add_object target
		@targets.add target
		return target

	query_shot: (events) =>
		events.on "pointerdown", (ev) =>
			dx = ev.sceneX - @base.object.position.x
			dy = ev.sceneY - @base.object.position.y
			
			return if (dx**2 + dy**2)**0.5 > @base.radius
			@shot_start = ev
		
		shot = null

		launch_ray = (ev) =>
			return if not @shot_start
			
			dx = ev.sceneX - @shot_start.sceneX
			dy = ev.sceneY - @shot_start.sceneY
			
			l = (dx**2 + dy**2)**0.5
			return if l < @base.radius
			
			# TODO: These are weirdly rounded at times!
			# MOST LIKELY DUE TO ACCELERATION ETC!
			#dt = ev.timeStamp - @shot_start.timeStamp
			#console.log dt, dx, dy
			dx /= l
			dy /= l
			@shot_start = null
			
			shot = [dx, dy]
		
		events.on "pointerup", launch_ray
		events.on "pointermove", launch_ray

		return shot

	#shoot: (dx, dy) =>
	#	
	#	@shots.push [dx, dy]
	#	@target_hits.push hits
	#	return hits

	shot_hits: ([dx, dy]) ->
		ray = new THREE.Ray(
			new THREE.Vector3(0, 0, 0),
			new THREE.Vector3(dx, dy, 0.0)
		)
		
		hits = []
		@targets.forEach (target) =>
			sphere = target.object.geometry.boundingSphere
			sphere = new THREE.Sphere target.object.position, target.radius
			if ray.intersectsSphere sphere
				hits.push target
		
		color = if hits.length then 0x00ff00 else 0xff0000
		@add_object new RayObject dx, dy, color
		return hits


	launch_shrapnels: (target) =>
		n_shrapnels = 6
		angle_base = Math.random()*Math.PI*2
		
		for i in [0...n_shrapnels]
			angle = i/n_shrapnels*Math.PI*2
			shrapnel = @add_target
				angle: target.angle
				distance: target.distance
				direction: angle_base + angle
				speed: 1.0
				radius: 0.01
			shrapnel.shrapnel = true
	
	handle_target_hit: (target) =>
		# Shrapnels can't be hit
		return if target.shrapnel
		# What is dead may never die
		return if target.dead
		
		target.hit()

		@target_hits.push target
		@launch_shrapnels target
	
	handle_collisions: =>
		base_sphere = new THREE.Sphere @base.object.position, @base.radius
		
		@targets.forEach (target) =>
			return if target.dead
			target_sphere = new THREE.Sphere target.object.position, target.radius

			collision = base_sphere.intersectsSphere target_sphere
			return if not collision

			target.hit()
			target.set_speed 0
			
			@base_collisions.push target
			@base.hit()
	

	tick: (dt, events) =>
		@time += dt
		
		if @objects.size == 0
			return TICKER_DONE
		
		if not @trial_done()
			@handle_events events
		
		@handle_collisions()
				
		@objects.forEach (object) =>
			return if not object.tick
			if object.tick(dt, events) == TICKER_DONE
				@scene.remove object.object
				@objects.delete object
				@targets.delete object
		return

	dispose: =>
		for object in @objects
			if object.object
				@scene.remove object.object
		@objects = new Set()


uniform = (low, high) ->
	Math.random()*(high - low) + low


default_distance_range = [0.3, 0.8]

export class SingleTargetTrial extends TrialBase
	constructor: (opts) ->
		super opts
		@target = @add_target
			distance: opts.distance ? uniform ...default_distance_range
			speed: opts.speed ? 0.0

	trial_done: =>
		@shots_taken.length > 0

	handle_events: (events) ->
		shot = @query_shot events
		if shot?
			@shots_taken.push shot
			hits = @shot_hits shot
			if hits.length == 0
				@targets.forEach (target) ->
					target.rush()
			else
				@target_hits.push hits
			for target in hits
				@handle_target_hit target





export class TwoTargetTrial extends TrialBase
	constructor: (opts) ->
		super opts
		
		@target_left = @add_target
			distance: uniform ...default_distance_range
			angle: -Math.PI/5
			speed: 0.0
		@target_right = @add_target
			distance: uniform ...default_distance_range
			angle: Math.PI/5
			speed: 0.0
	
	handle_events: (events) ->
		shot = @query_shot events
		return if not shot
		@shots_taken.push shot
		
		[dx, dy] = shot
		
		if dx < 0
			[aim_target, other_target] = [@target_left, @target_right]
		else
			[aim_target, other_target] = [@target_right, @target_left]

		other_target.vanish()

		hits = @shot_hits shot
		if hits.length == 0
			aim_target.rush()
		
		@target_hits.push hits
		for target in hits
			@handle_target_hit target

	trial_done: =>
		@shots_taken.length > 0


