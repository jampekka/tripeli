import * as THREE from 'three'
import $ from 'jquery'
import {FontLoader} from 'three/addons/loaders/FontLoader.js'

class Events
	constructor: () ->
		@events = []
	
	add: (name, data) =>
		@events.push [name, data]
	
	on: (name, func) ->
		for [name_, data] in @events
			continue if name != name_
			done = func(data)
			return if done

# TODO: Hack, don't know where to put this yet

BASE_RADIUS = 0.1

# Handles all the cruft with DOM and Three.js
class GameRunner
	constructor: (container) ->
		@container = $ container
		@renderer = new THREE.WebGLRenderer antialias: true

		@el = $ @renderer.domElement
		@container.append @el

		margin = BASE_RADIUS*2
		area_height = 1 + 2*margin
		area_width =  area_height

		@camera = new THREE.OrthographicCamera(
			-area_width/2,
			area_width/2,
			(area_height-margin),
			-margin,
			0.1,
			1000,
		)

		@camera.position.z = 5
		
		@time = null
		@start_time = null
		@tickers = []
		
		@events = new Events()

		pointer_event = (ev) =>
			ev = @_pointer_xy ev
			@events.add ev.type, ev
		
		@el.on "click", pointer_event
		@el.on "pointerdown", pointer_event
		@el.on "pointerup", pointer_event
		@el.on "pointermove", pointer_event

	_pointer_xy: (ev) ->
		el = ev.target
		rect = el.getBoundingClientRect()
		
		rx = (ev.clientX - rect.left)/rect.width*2 - 1
		ry = -(ev.clientY - rect.top)/rect.height*2 + 1
		
		ray = new THREE.Raycaster()
		ray.setFromCamera (new THREE.Vector2(rx, ry)), @camera
		
		ev.ray = ray
		ev.sceneX = ray.ray.origin.x
		ev.sceneY = ray.ray.origin.y
		return ev
	
	
	pop_events: ->
		events = @events
		@events = new Events()
		return events
	
	render: (scene) ->
		w = @container.width()
		h = @container.height()
		m = Math.min w,h
		@renderer.setSize m, m
		
		@renderer.render scene, @camera



next_frame = -> new Promise (resolve, reject) ->
	requestAnimationFrame (time) ->
		resolve(time/1000)

frames = ->
	prev_time = null
	while true
		time = await next_frame()
		if not prev_time?
			prev_time = time
		dt = time - prev_time
		prev_time = time

		yield dt

import * as Game from './game.coffee'

do ->
	runner = new GameRunner($ "#gamearea")
	
	scene = new THREE.Scene
	
	env =
		runner: runner
		scene: scene
	
	base = new Game.Base env, BASE_RADIUS
	scene.add base.object
	
	env.base = base
	
	# TODO: Better path!
	env.font = await new Promise (resolve, reject) ->
		loader = new FontLoader()
		path = "node_modules/three/examples/fonts/droid/droid_sans_bold.typeface.json"
		loader.load path,
			(font) -> resolve(font)
			null,
			(error) -> reject(error)
	
	tickers = []
	
	add_ticker = (ticker) ->
		tickers.push ticker

	tick_tickers = (...args) ->
		current_tickers = tickers
		tickers = []
		old_tickers = current_tickers.filter (ticker) ->
			result = ticker dt, events
			if result == Game.TICKER_DONE
				return false
			return true
		tickers = old_tickers.concat tickers


	after = (dur, callback) ->
		time_left = dur
		add_ticker (dt) ->
			time_left -= dt
			return if time_left > 0
			
			callback()
			return Game.TICKER_DONE
	

	single_oncoming = ->
		new Game.SingleTargetTrial env,
			distance: 0.9
			speed: 0.3
	
	two_target_static = ->
		new Game.TwoTargetTrial env

	new_trial = ->
		trial = two_target_static()
		#trial = single_oncoming()
		add_ticker trial.tick
		return trial


	active_trial = null
	active_trial = new_trial()
	for await dt from frames()
		events = runner.pop_events()
		
		tick_tickers(dt, events)

		runner.render scene
		if active_trial? and active_trial.trial_done()
			active_trial = null
			after 1.0, ->
				active_trial = new_trial()

	#game = new Game($ "#gamearea")
