
Door = require "./Door"
World = require "../World"

module.exports =
class @Player extends (require "../Ent")
	constructor: (props, room, world)->
		# existing_player = world.getPlayer props.id
		# if existing_player
		# 	# console.log "use existing Player!", props.id, existing_player.room.ents
		# 	existing_player.remove()
		# 	existing_player.room = room
		# 	existing_player.world = world
		# 	existing_player.controller.world = world
		# 	world.players[existing_player.id] = existing_player
		# 	return existing_player
		
		super
		# console.log "new Player!", @id, @world.players[@id]
		@world.players[@id] = @
		
		@entering = no
		
		# FIXME: holding a key while going to another World
		# I want it to be *seamless*!
		# (just need to reuse a single KeyboardController instance)
		# (and give it an up-to-date World instance)
		# NOTE: ideally this would use dependency injection,
		# but I'm not sure how that would work when ents can be created generically
		# TODO: gamepad controller support
		if @world.onClientSide
			if @id is global.clientPlayerID
				KeyboardController = require "../controllers/KeyboardController"
				@controller = new KeyboardController @, @world
			else
				Controller = require "../Controller"
				@controller = new Controller @, @world
		else
			RemoteController = require "../controllers/RemoteController"
			@controller = new RemoteController @, @world
	
	step: (t)->
		@controller.step()
		
		unless @entering
			@vx += 0.03 * @controller.moveX
			
			if @controller.jump and @grounded()
				@vy = -0.56
		
		door = ent for ent in @entsAt @x, @y, @w, @h when ent instanceof Door
		if door?.to?
			if @entering
				if Math.abs(door.x - @x) < 0.1
					@enterDoor door
				else
					@vx += 0.01 * Math.sign(door.x - @x)
			else if @controller.enterDoor
				@entering = yes
		else
			@entering = no # in case you get pushed away from the door
			# it would be weird if you automatically entered indefinitely later
		
		super
	
	enterDoor: (door)->
		@entering = no
		
		on_client_side = @world.onClientSide
		server_or_client_side_indication = "(#{if on_client_side then "client" else "server"}-side)"
		log = (args...)->
			if on_client_side
				console.debug "%c#{server_or_client_side_indication}", "color:#05F", args...
			else
				console.log "%c#{server_or_client_side_indication}", "color:gray", args...
		log "Enter door", door
		
		leaving_room = @room
		leaving_world = @world
		@remove()
		
		entering_room_id = door.to
		entering_world =
			if door.address
				log "Leaving world", leaving_world
				if on_client_side and @id is global.clientPlayerID
					World = World.World ? World # XXX: Why is require() returning an Object?
					# FIXME: shouldn't be running in node context on the client side
					client_window.worlds_by_address[door.address] ?= new World onClientSide: yes, serverAddress: door.address, players: @world.players
					client_window.world = client_window.worlds_by_address[door.address]
					log "Entering world", client_window.world
					client_window.world
			else
				@world
		
		if on_client_side and @id is global.clientPlayerID
			entering_world.current_room_id = entering_room_id
			entering_world.socket.sendMessage
				enterDoor:
					player: @
					from: room_id: leaving_room.id, address: leaving_world.serverAddress
					to: room_id: entering_room_id, address: entering_world.serverAddress
