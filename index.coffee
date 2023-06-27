scene = new THREE.Scene()
base_radius = 0.1

margin = base_radius*2
area_height = 1 + 2*margin
area_width =  area_height

console.log area_height
top = area_height - margin/2
bottom = -margin/2
console.log top, bottom

camera = new THREE.OrthographicCamera -area_width/2, area_width/2, (area_height-margin), -margin, 0.1, 1000
camera.position.z = 5
#camera.position.y = 1 - base_radius

renderer = new THREE.WebGLRenderer antialias: true

gamearea = document.getElementById("gamearea")
document.getElementById("gamearea").appendChild renderer.domElement

render = ->
	el = gamearea
	w = el.offsetWidth
	h = el.offsetHeight
	#h = w/2
	m = Math.min w,h
	
	#renderer.setSize w, h
	renderer.setSize m, m

	h = h/w
	#h = 1
	#w = 1
	
	#camera.left = -w
	#camera.right = w
	#camera.bottom = -h
	#camera.top = h
	#camera.updateProjectionMatrix() # May be expensive
	renderer.render scene, camera

events_seen = []
_mousedown = null
_mousedelta_x = 0
_mousedelta_y = 0
_last_touch = null
_touch_start = null
_last_shot = 0
"""
document.body.addEventListener("keydown", (ev) -> events_seen.push(ev))
document.body.addEventListener("touchstart", (ev) -> events_seen.push(ev))
document.body.addEventListener("touchend", (ev) -> events_seen.push(ev))
document.body.addEventListener("mousedown", (ev) -> events_seen.push(ev))
document.body.addEventListener("mouseup", (ev) -> events_seen.push(ev))
document.body.addEventListener("mousemove", (ev) -> events_seen.push(ev))
document.body.addEventListener("touchmove", (ev) -> events_seen.push(ev))
"""

ctrl = document.getElementById("controller")

_drag_start = null
_position_delta = null

start_drag = (ev) ->
	return if _drag_start
	#ctrl.style.transition = ""
	_drag_start = ev
do_drag = (ev) ->
	return if not _drag_start
	
	dx = ev.screenX - _drag_start.screenX
	dy = ev.screenY - _drag_start.screenY
	
	#ctrl.style.transform = "translate(#{dx}px, #{dy}px)"
	# TODO: To scale!
	dd = Math.sqrt(dx**2 + dy**2)
	if dd > 100
		end_drag(ev)

end_drag = (ev) ->
	return if not _drag_start
	#ctrl.style.transform = "translate(0px, 0px)"
	#ctrl.style.transition = "0.1s"
	
	dx = ev.screenX - _drag_start.screenX
	dy = ev.screenY - _drag_start.screenY
	
	events_seen.push
		type: "drag"
		movementX: dx
		movementY: dy
	
	_drag_start = null

document.body.addEventListener "pointermove", do_drag
#document.body.addEventListener "pointerup", end_drag
#document.body.addEventListener "pointerup", end_drag
document.body.addEventListener "pointerdown", start_drag


###
ctrl.addEventListener "pointerdown", (down_event) ->
	console.log down_event
	pmove = (ev) ->
		
		ctrl.style.transform = "translate(#{dx}px, #{dy}px)"
		console.log ctrl.style.transform
	pup = ->
		console.log "Drag stop"
		#ctrl.removeEventListener "pointermove", pmove
		document.body.removeEventListener "pointermove", pmove
	document.body.addEventListener "pointermove", pmove
	document.body.addEventListener "pointerup", pup, once: true
	ctrl.addEventListener "pointerup", pup, once: true
###

reset_events = ->
	events_seen = []

next_frame = -> new Promise (resolve, reject) ->
	requestAnimationFrame (time) ->
		prev_time = time
		
		events = []
		
		for event in events_seen
			"""
			if event.type == "mousemove" and _last_shot + 500 < time
				_mousedelta_x += event.movementX
				_mousedelta_y += event.movementY
			#if event.type == "touchmove" and _last_shot + 500 < time
			#	touch = event.touches[0]
			#	console.log touch, _last_touch
			#	if _last_touch
			#		_mousedelta_x += touch.screenX - _last_touch.screenX
			#		_mousedelta_y += touch.screenY - _last_touch.screenY
			#		console.log _mousedelta_x
			#		console.log _mousedelta_y
			#	_last_touch = touch
			
			if event.type == "touchstart"
				_touch_start = event
			if event.type == "touchend" and _touch_start
				et = event.changedTouches[0]
				st = _touch_start.changedTouches[0]

				dx = et.screenX - st.screenX
				dy = et.screenY - st.screenY
				
				events.push
					type: "drag"
					#mouseup: event
					#mousedown: _mousedown
					movementX: dx
					movementY: dy
				
				_touch_start = null

			#if event.type == "mouseup" and _mousedown
			#console.log Math.sqrt(_mousedelta_x**2 + _mousedelta_y**2)
			if _last_shot + 500 < time and Math.sqrt(_mousedelta_x**2 + _mousedelta_y**2) > 100
				events.push
					type: "drag"
					#mouseup: event
					#mousedown: _mousedown
					movementX: _mousedelta_x
					movementY: _mousedelta_y
				
				_mousedelta_x = 0
				_mousedelta_y = 0
				_mousedown = null
				_last_touch = null
				_last_shot = time
			if event.type == "mousedown"
				_mousedown = event
			"""
			events.push event

		events_seen = []
		resolve([time/1000, events])

new_target_object = (size) ->
	geometry = new THREE.SphereGeometry(size, 32, 32)
	material = new THREE.MeshBasicMaterial color: 0xffffff
	geometry.computeBoundingSphere()
	object = new THREE.Mesh geometry, material
	scene.add object
	return object

new_target = (opts={}) ->
	distance = opts.distance ? 0.8
	angle = opts.angle ? Math.random()*360
	speed = opts.speed ? 0.3
	size = opts.size ?= 0.1

	rad = angle/180*Math.PI
	
	dirx = (Math.sin rad)
	diry = (Math.cos rad)
	x = dirx*distance
	y = diry*distance

	object = new_target_object(size)
	object.position.x = x
	object.position.y = y
	
	return
		object: object
		tick: (dt) ->
			object.position.x += -dirx*speed*dt
			object.position.y += -diry*speed*dt
			object.geometry.computeBoundingSphere()

class TargetObject
	constructor: (opts={}) ->
		{
		@distance=1.0
		@angle=(Math.random() - 0.5)/2*Math.PI
		@speed=0.2
		@size=0.07
		@death_dur=0.2
		@dead=false
		@direction
		}=opts
		@done=false
				
		geometry = new THREE.SphereGeometry(@size, 32, 32)
		material = new THREE.MeshBasicMaterial color: 0xffffff, transparent: true
		geometry.computeBoundingSphere()
		@object = new THREE.Mesh geometry, material
		
		dx = Math.sin @angle
		dy = Math.cos @angle
		@object.position.x = dx*@distance
		@object.position.y = dy*@distance
		
		if not @direction?
			@direction = Math.atan2(-dx, -dy)
		
		@vx = Math.sin(@direction)*@speed
		@vy = Math.cos(@direction)*@speed

		@t = 0
		scene.add @object

	set_speed: (@speed) ->
		@vx = Math.sin(@direction)*@speed
		@vy = Math.cos(@direction)*@speed

	tick: (dt) =>
		@t += dt
		@object.position.x += @vx*dt
		@object.position.y += @vy*dt
		
		@distance = (@object.position.x**2 + @object.position.y**2)**0.5
		@angle = Math.atan2(@object.position.x, @object.position.y)

		if @distance > 2.0 and not @dead
			@hit()

		if @dead and not @done
			t = @t - @death_t
			if t > @death_dur
				scene.remove @object
				@done = true
				return true
			progress = 1 - t/@death_dur
			s = (0.1 + 1)/(0.1 + progress)
			@object.scale.set s, s, s
			@object.material.opacity = progress

	
	hit: =>
		@dead = true
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
		
		scene.add @object
		@t = 0
		@done = false
	
	tick: (dt) =>
		@t += dt
		return true if @done
		if @t > @duration
			scene.remove @object
			@done = true
			return true
		@object.material.opacity = 1 - @t/@duration

demo_trial = ->
	game_area_radius = 0.9
	n_trials = 20
	score_elements = []
	score_el = document.getElementById("score")
	template_el = score_el.querySelector(".score_element")
	for i in [0...n_trials]
		sel = template_el.cloneNode()
		sel.style.display = "inline-block"
		score_el.appendChild sel
		score_elements.push sel
	score = 0
	trial = -1
	
	#document.body.addEventListener 'click', (ev) -> console.log "Got click"


	
	render()
	"""
	await new Promise (resolve, reject) ->
		console.log "Adding click listener"
		intro = document.getElementById "intro"
		intro.addEventListener 'click', ->
			#await document.body.requestFullscreen()
			#await document.body.requestPointerLock()
			intro.style.display = 'none'
			resolve()
	"""

	base_geometry = new THREE.SphereGeometry base_radius, 30, 30
	base_material = new THREE.MeshBasicMaterial color: 0xaaaaaa, transparent: true
	base_geometry.computeBoundingSphere()
	base = new THREE.Mesh base_geometry, base_material
	base_health = 1.0
	base_energy = 1.0
	scene.add base

	

	tickers = []
	
	t = 0
	tasks = []
	after = (timedelta, task) ->
		tasks.push [t+timedelta, task]
	
	targets = []
	add_target = (opts={}) ->
		target = new TargetObject(opts)
		tickers.push target
		targets.push target

		return target
	
	main_target = null
	game_over = false
	new_target = (opts={}) ->
		return if main_target
		return if game_over

		trial += 1
		intro = document.getElementById "intro"
		intro.style.display = 'none'

		main_target = add_target(opts)
		base_energy = 1.0
	idle_timer = 0.0
	clear_target = () ->
		idle_timer = 0.0
		main_target = null
		if trial >= n_trials - 1
			game_over = true
		
			after 1.0, ->
				document.getElementById("score_text_hits").innerHTML = score
				document.getElementById("score_text_trials").innerHTML = n_trials
				el = score_el.cloneNode(true)
				el.style.position = "static"
				document.getElementById("final_score_balls").appendChild el
				document.getElementById("outro").style.display = "flex"
	
	document.body.addEventListener "pointerdown", (ev) ->
		after 0.3, new_target
	

	#wtf = add_target(speed: 0)
	#wtf.object.position.y = 1
	#wtf.object.position.x = 0

	while true
		[time, events] = await next_frame()
		if not full_t?
			full_t = time
			t0 = time
		dt = time - full_t
		full_t = time
		t = full_t - t0

		if not main_target
			idle_timer += dt
			if idle_timer > 5.0
				document.getElementById("intro").style.display = "flex"
		
		tasks = tasks.filter ([task_t, task]) ->
			if t > task_t
				task()
				return false
			return true

		for event in events
			if event.type == "drag"
				if base_energy < 1
					continue
				base_energy = 0.0

				dx = event.movementX
				dy = -event.movementY
				
				total_delta = Math.sqrt(dx**2 + dy**2)
				dirx = dx/total_delta
				diry = dy/total_delta

				raypoints = [
					new THREE.Vector3(0, 0, 0),
					new THREE.Vector3(dirx*game_area_radius, diry*game_area_radius, 0)
					]
				geometry = new THREE.BufferGeometry().setFromPoints raypoints
				
				# TODO: This is buggy. Do manually
				ray = new THREE.Raycaster(
					new THREE.Vector3(0, 0, 0),
					new THREE.Vector3(dirx, diry, 0)
					)

				has_hit = false
				for target in targets
					continue if target.shrapnel
					hits = ray.intersectObjects [target.object]
					continue if not hits.length
					has_hit = true
					target.hit()
					
					n_shrapnels = 6
					angle_base = Math.random()*Math.PI*2
					for i in [0...7]
						angle = i/n_shrapnels*Math.PI*2
						shrapnel = add_target
							angle: target.angle
							distance: target.distance
							direction: angle_base + angle
							speed: 1.0
							size: 0.01
						shrapnel.shrapnel = true
					score_elements[trial].classList.add("score_win")
					score += 1
					clear_target()
					#after 0.5, new_target

				if has_hit
					color = 0x00ff00
				else
					color = 0xff0000
					closest = null
					for target in targets
						continue if target.shrapnel
						if not closest
							closest = target
							continue
						if target.distance < closest.distance
							closest = target
					if closest
						after 0.2, ->
							closest.set_speed 2.0
				#line = new THREE.Line geometry, material
				line = new RayObject(dirx, diry, color)
				tickers.push line

		tickers = tickers.filter (ticker) -> ticker.tick(dt) != true
		
		

		base.material.color.lerpColors(
			new THREE.Color(0xff0000),
			new THREE.Color("white"),
			base_health**2
		)

		base_health += dt*2.0
		base_health = Math.min 1, base_health
		
		#base_energy += dt
		#base_energy = Math.min 1, base_energy
		
		if base_energy < 1
			base.material.opacity = 0.5
		else
			base.material.opacity = 1.0

		base_sphere = new THREE.Sphere base.position, base.geometry.boundingSphere.radius
		
		for target in targets
			target_sphere = new THREE.Sphere target.object.position, target.object.geometry.boundingSphere.radius
			collision = base_sphere.intersectsSphere target_sphere
			if collision
				console.log score_elements[trial]
				score_elements[trial].classList.remove("score_win")
				score_elements[trial].classList.add("score_loss")
				target.hit()
				target.set_speed 0
				base_health = 0.0
				if not target.shrapnel
					clear_target()
				else
					console.log "Reducing score!"
					score -= 1
					console.log score
		
		targets = targets.filter (target) -> not target.dead
		
		render()
	
	for obj in objects
		scene.remove obj

do -> await demo_trial()
