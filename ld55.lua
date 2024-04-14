levels={
	{
		"#######",
		"#@#####",
		"#.#####",
		"#...*.#",
		"####.##",
		"####$##",
		"#######",
	},
	{
		"######",
		"###.##",
		"#..*$#",
		"#.#.##",
		"#@#.##",
		"######",
	},
	{
		"#######",
		"#..*..#",
		"###..$#",
		"###.###",
		"#..*###",
		"#.#.###",
		"#@#.###",
		"#######",
	},
	{
		"###########",
		"#@..###.$##",
		"#...*.*..##",
		"###########",
	},
	{
		"#######",
		"#@..###",
		"###*.$#",
		"##.*..#",
		"#######",
	},
	{
		"########",
		"#@...A$#",
		"########",
		"#..*..a#",
		"########",
	},
	{
		"#######",
		"#@....#",
		"#####A#",
		"#$###.#",
		"#.###.#",
		"#a.*..#",
		"#.#####",
		"#######",
	},
	{
		"#########",
		"#@..#..a#",
		"#...*...#",
		"#...#...#",
		"######*##",
		"#...#...#",
		"#...A...#",
		"#$..#..a#",
		"#########",
	},
	{
		"#########",
		"#@......#",
		"#.....a.#",
		"#.......#",
		"#...#####",
		"#...#...#",
		"#.*.A.$.#",
		"#...#...#",
		"#########",
	},
	{
		"##########",
		"#...######",
		"#.@.a*.A$#",
		"#...######",
		"##########",
	},
	{
		"##########",
		"#.A.....$#",
		"#.########",
		"#@.aa*.*.#",
		"##########",
	},
	{
		"########",
		"#..#####",
		"#..#####",
		"#@..*.$#",
		"##A#####",
		"##..*.a#",
		"########",
	},
	{
		"#########",
		"#@......#",
		"#######A#",
		"#.....#$#",
		"#.*.*.###",
		"#.......#",
		"#....a..#",
		"#.......#",
		"#########",
	},
	{
		"#######",
		"#....@#",
		"#A#####",
		"#$#####",
		"####.##",
		"#..a.##",
		"##*#*##",
		"##...a#",
		"##.####",
		"#######",
	},
	{
		"#######",
		"#$ ..A#",
		"#####.#",
		"###.#.#",
		"#...#.#",
		"##@a*.#",
		"##.####",
		"##....#",
		"#######",
	},
	{
		"#########",
		"#@####..#",
		"#....a.##",
		"##*#A#.##",
		"##.#$#.##",
		"##.#A#*##",
		"##.a....#",
		"#..####.#",
		"#########",
	}
}
next_level=1

title_level={
	".......*..........",
	".............*....",
	".....@............",
	"...*..............",
	"...........*......",
}

width=0
height=0
tiles={}
objs={}
player=nil
preparing_summoning=false
completing_summoning=false
summon_target_x=0
summon_target_y=0
summoned=nil
summoned_offset_x=0
summoned_offset_y=0
door_open=false
switch_positions={}

summoned_move_interval=15
summoned_move_timer=summoned_move_interval

level_completed=false
level_completed_interval=40
level_completed_timer=level_completed_interval

effect_length=12
effects={}

obj_move_length=6

title_coroutine=nil

log_message=""

function log(str)
	log_message=str
end

function switch_mode(init,update,draw)
	init()
	_update60=update
	_draw=draw
end

function lpad(s,c,count)
	local result=tostr(s)
	while #result<count do
		result=c..result
	end
	return result
end

function create_obj(kind,sprite,x,y)
	local obj={
		kind=kind,
		sprite=sprite,
		x=x,
		y=y,
		move_timer=0,
		last_x=x,
		last_y=y,
	}
	add(tiles[y][x].obj,obj)
	add(objs,obj)
	return obj
end

function move_obj(obj,x,y)
	del(tiles[obj.y][obj.x].obj,obj)
	obj.last_x=obj.x
	obj.last_y=obj.y
	obj.move_timer=obj_move_length
	obj.x=x
	obj.y=y
	add(tiles[y][x].obj,obj)
end

function update_objs()
	for obj in all(objs) do
		if obj.move_timer>0 then
			obj.move_timer-=1
		end
	end
end

function dispose_obj(obj,x,y)
	del(objs,obj)
	del(tiles[obj.y][obj.x].obj,obj)
end


function create_effect(x,y)
	add(effects,{
		x=x,
		y=y,
		timer=0,
	})
end

function update_effect()
	for effect in all(effects) do
		effect.timer+=1
		if effect.timer>effect_length then
			del(effects,effect)
		end
	end
end

function draw_effect()
	for effect in all(effects) do
		spr(0x18+flr((4*effect.timer)/effect_length),effect.x,effect.y)
	end
end

function main_init()
	-- load level
	load_level(levels[next_level])
	-- menu
	menuitem(1, "restart puzzle",
		function()
			switch_mode(main_init,main_update,main_draw)
		end
	)
	menuitem(2, "back to title",
		function()
			switch_mode(title_init,title_update,title_draw)
		end
	)
end

function update_door()
	door_open=true
	for pos in all(switch_positions) do
		local tile=tiles[pos.y][pos.x]
		if #tile.obj<=0 then
			door_open=false
		end
	end
end

function blocked(x,y)
	if (x<=0) or (y<=0) or (x>width) or (y>height) then
		return true
	end
	local target=tiles[y][x]
	if target.wall then
		return true
	end
	for obj in all(target.obj) do
		return true
	end
	if target.door and (not door_open) then
		return true
	end
	return false
end

function try_player_move(x_offset,y_offset)
	local target_x=player.x+x_offset
	local target_y=player.y+y_offset
	if not blocked(target_x,target_y) then
		sfx(1)
		move_obj(player,target_x,target_y)
	else
		sfx(6)
		player.move_timer=obj_move_length/2
		player.last_x=player.x+x_offset/2
		player.last_y=player.y+y_offset/2
	end
end

function check_player_move()
	if btnp(0) then
		try_player_move(-1,0)
	elseif btnp(1) then
		try_player_move(1,0)
	elseif btnp(2) then
		try_player_move(0,-1)
	elseif btnp(3) then
		try_player_move(0,1)
	elseif btnp(4) then
		sfx(3)
		preparing_summoning=true
		summon_target_x=player.x
		summon_target_y=player.y
	end
end

function try_target_move(x_offset,y_offset)
	local target_x=summon_target_x+x_offset
	local target_y=summon_target_y+y_offset
	if (target_x<=0) or (target_y<=0) or (target_x>width) or (target_y>height) then
		return
	end
	sfx(2)
	summon_target_x=target_x
	summon_target_y=target_y
end

function check_select_target()
	if btnp(0) then
		if summon_target_y==player.y then
			try_target_move(-1,0)
		end
	elseif btnp(1) then
		if summon_target_y==player.y then
			try_target_move(1,0)
		end
	elseif btnp(2) then
		if summon_target_x==player.x then
			try_target_move(0,-1)
		end
	elseif btnp(3) then
		if summon_target_x==player.x then
			try_target_move(0,1)
		end
	elseif btnp(4) then
		if not blocked(summon_target_x,summon_target_y) then
			create_effect(64-width*4+summon_target_x*8-8,64-height*4+summon_target_y*8-8)
			completing_summoning=true
			sfx(4)
		end
	elseif btnp(5) then
		preparing_summoning=false
		sfx(7)
	end
end

function completing_summon(x_offset,y_offset)
	completing_summoning=false
	preparing_summoning=false
	summoned=create_obj("summoned",0x11,summon_target_x,summon_target_y)
	sfx(3)
	summoned_offset_x=x_offset
	summoned_offset_y=y_offset
	summoned_move_timer=summoned_move_interval
end

function check_complete_summon()
	if btnp(0) then
		completing_summon(-1,0)
	elseif btnp(1) then
		completing_summon(1,0)
	elseif btnp(2) then
		completing_summon(0,-1)
	elseif btnp(3) then
		completing_summon(0,1)
	elseif btnp(5) then
		completing_summoning=false
		sfx(7)
	end
end

function can_summoned_move()
	local target_x=summoned.x+summoned_offset_x
	local target_y=summoned.y+summoned_offset_y
	if (target_x<=0) or (target_y<=0) or (target_x>width) or (target_y>height) then
		return false
	end
	local target=tiles[target_y][target_x]
	if target.wall then
		return false
	end
	if target.door and (not door_open) then
		return false
	end
	if #target.obj<=0 then
		return true
	end
	for obj in all(target.obj) do
		if obj.kind~="box" then
			return false
		end
	end
	if blocked(target_x+summoned_offset_x,target_y+summoned_offset_y) then
		return false
	end
	return true
end

function summoned_move()
	if can_summoned_move() then
		local target_x=summoned.x+summoned_offset_x
		local target_y=summoned.y+summoned_offset_y
		local target=tiles[target_y][target_x]
		if #target.obj>0 then
			sfx(0)
		else
			sfx(1)
		end
		for obj in all(target.obj) do
			move_obj(obj,target_x+summoned_offset_x,target_y+summoned_offset_y)
		end
		move_obj(summoned,target_x,target_y)
	else
		dispose_obj(summoned)
		create_effect(64-width*4+summoned.x*8-8,64-height*4+summoned.y*8-8)
		sfx(4)
		summoned=nil
	end
end

function load_level(level)
	height=#level
	width=0
	if height>0 then
		width=#level[1]
	end
	tiles={}
	objs={}
	switch_positions={}
	for i=1,height do
		add(tiles,{})
		for j=1,width do
			add(tiles[i],{
				wall=level[i][j]=="#",
				goal=level[i][j]=="$",
				door=level[i][j]=="A",
				switch=level[i][j]=="a",
				obj={}
			})
			if level[i][j]=="a" then
				add(switch_positions,{x=j,y=i})
			end
			if level[i][j]=="@" then
				player=create_obj("player",0x10,j,i)
			elseif level[i][j]=="*" then
				create_obj("box",0x12,j,i)
			end
		end
	end
	-- reset states
	preparing_summoning=false
	completing_summoning=false
	level_completed=false
	effects={}
	summoned=nil
end

function main_update()
	update_objs()
	update_effect()
	-- summoned movement
	if summoned~=nil then
		summoned_move_timer-=1
		if summoned_move_timer<=0 then
			summoned_move()
			summoned_move_timer=summoned_move_interval
		end
	elseif level_completed then
		level_completed_timer-=1
		if level_completed_timer<=0 then
			if next_level<#levels then
				next_level+=1
				switch_mode(main_init,main_update,main_draw)
			else
				switch_mode(title_init,title_update,title_draw)
			end
		end
	else
		-- idle
		if not preparing_summoning then
			-- player movement
			check_player_move()
		elseif not completing_summoning then
			-- select summon target
			check_select_target()
		else
			-- select summon direction
			check_complete_summon()
		end
		if tiles[player.y][player.x].goal then
			level_completed=true
			level_completed_timer=level_completed_interval
			create_effect(64-width*4+player.x*8-8,64-height*4+player.y*8-8)
			dispose_obj(player)
			player=nil
			sfx(5)
		end
	end
	update_door()
end

function draw_level()
	local offset_x=64-width*4
	local offset_y=64-height*4
	for i=1,height do
		for j=1,width do
			local tile=tiles[i][j]
			local x=offset_x+j*8-8
			local y=offset_y+i*8-8
			if tile.wall then
				spr(0x00,x,y)
			else
				spr(0x01,x,y)
			end
			if tile.goal then
				spr(0x20,x,y)
			end
			if tile.switch then
				spr(0x21,x,y)
			end
		end
	end
	for i=1,height do
		for j=1,width do
			local tile=tiles[i][j]
			local x=offset_x+j*8-8
			local y=offset_y+i*8-8
			for obj in all(tile.obj) do
				local x=offset_x+j*8-8
				local y=offset_y+i*8-8
				local last_x=offset_x+obj.last_x*8-8
				local last_y=offset_y+obj.last_y*8-8
				spr(obj.sprite,x+(last_x-x)*obj.move_timer/obj_move_length,y+(last_y-y)*obj.move_timer/obj_move_length)

			end
		end
	end
	for i=1,height do
		for j=1,width do
			local tile=tiles[i][j]
			local x=offset_x+j*8-8
			local y=offset_y+i*8-8
			if tile.door then
				if door_open then
					spr(0x23,x,y)
				else
					spr(0x22,x,y)
				end
			end
		end
	end
	if preparing_summoning then
		local x=offset_x+summon_target_x*8-8
		local y=offset_y+summon_target_y*8-8
		if completing_summoning then
			spr(0x11,x,y)
			spr(0x33,x-8,y)
			spr(0x34,x+8,y)
			spr(0x35,x,y-8)
			spr(0x36,x,y+8)
		else
			spr(0x30,x,y)
			if summon_target_x==player.x then
				for i=min(summon_target_y,player.y)+1,max(summon_target_y,player.y)-1 do
					spr(0x32,x,offset_y+i*8-8)
				end
			end
			if summon_target_y==player.y then
				for i=min(summon_target_x,player.x)+1,max(summon_target_x,player.x)-1 do
					spr(0x31,offset_x+i*8-8,y)
				end
			end
		end
	end
	draw_effect()
end

function main_draw()
	cls()
	draw_level()
	print("stage "..lpad(next_level,"0",2),48,116,6)
end

function co_wait(frames)
	for i=1,frames do
		yield()
	end
end

function title_animation()
	while true do
		co_wait(60)
		preparing_summoning=true
		summon_target_x=player.x
		summon_target_y=player.y
		for i=1,5 do
			co_wait(15)
			summon_target_x+=1
		end
		co_wait(30)
		create_effect(64-width*4+summon_target_x*8-8,64-height*4+summon_target_y*8-8)
		preparing_summoning=false
		summoned=create_obj("summoned",0x11,summon_target_x,summon_target_y)
		co_wait(15)
		for i=1,7 do
			co_wait(15)
			move_obj(summoned,summoned.x+1,summoned.y)
		end
		co_wait(15)
		dispose_obj(summoned)
		summoned=nil
	end
end

function title_init()
	load_level(title_level)
	menuitem(1)
	menuitem(2)
	effects={}
	title_coroutine=cocreate(title_animation)
end

function title_update()
	update_objs()
	update_effect()
	if (btnp(0)) and next_level>1 then
		next_level-=1
		sfx(2)
	end
	if (btnp(1)) and next_level<#levels then
		next_level+=1
		sfx(2)
	end
	if (btnp(4)) then
		switch_mode(main_init,main_update,main_draw)
		sfx(3)
	end
	assert(coresume(title_coroutine))
end

function title_draw()
	cls()
	draw_level()
	print("cat and box",42,20,6)
	if next_level>1 then
		print("<",36,102,6)
	end
	print("stage "..lpad(next_level,"0",2),48,102,6)
	if next_level<#levels then
		print(">",88,102,6)
	end
end

_update60=main_update
_draw=main_draw

function _init()
	switch_mode(title_init,title_update,title_draw)
end