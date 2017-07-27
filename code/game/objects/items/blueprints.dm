# define AREA_ERRNONE	0
# define AREA_STATION	1
# define AREA_SPACE		2
# define AREA_SPECIAL	3
# define AREA_BLUEPRINTS 4

# define BORDER_ERROR   0
# define BORDER_NONE    1
# define BORDER_BETWEEN 2
# define BORDER_2NDTILE 3
# define BORDER_SPACE   4

# define ROOM_ERR_LOLWAT    0
# define ROOM_ERR_SPACE    -1
# define ROOM_ERR_TOOLARGE -2


/obj/item/blueprints
	name = "station blueprints"
	desc = "Blueprints of the station. There is a \"Classified\" stamp and several coffee stains on it."
	icon = 'icons/obj/items.dmi'
	icon_state = "blueprints"
	attack_verb = list("attacks", "baps", "hits")

	var/header = "<small>property of Nanotrasen. For heads of staff only. Store in high-secure storage.</small>"

	var/can_create_areas_in = list(AREA_SPACE)
	var/can_rename_areas = list(AREA_STATION, AREA_BLUEPRINTS)
	var/can_edit_areas = list(AREA_BLUEPRINTS)
	var/can_delete_areas = list(AREA_BLUEPRINTS)

	var/area/currently_edited
	var/image/edited_overlay

	//Amount of turfs in the edited area. Exists to minimize performance impact of calling get_area_turfs()
	var/turf_amount_cache

	//Maximum amount of turfs
	var/max_room_size = 300

	var/mob/editor

//MoMMI blueprints
/obj/item/blueprints/mommiprints
	name = "MoMMI station blueprints"
	desc = "Blueprints of the station, designed for the passive aggressive spider bots aboard."
	icon = 'icons/obj/items.dmi'
	icon_state = "blueprints"
	attack_verb = list("attacks", "baps", "hits")

	can_rename_areas = list(AREA_BLUEPRINTS)
	can_delete_areas = list()

	header = "<small>These blueprints are for the creation of new rooms only; you cannot change existing rooms.</small>"

/* construction permits. Think blueprints but accessible to all engies and does NOT count as the antag steal objective
these cannot rename rooms that are in by default BUT can rename rooms that are created via blueprints/permit  */
/obj/item/blueprints/construction_permit
	name = "construction permit"
	desc = "An electronic permit designed to register a room for the use of APC and air alarms"
	icon = 'icons/obj/items.dmi'
	icon_state = "permit"
	attack_verb = list("attacks", "baps", "hits")
	w_class = W_CLASS_TINY

	can_rename_areas = list(AREA_BLUEPRINTS)
	can_delete_areas = list()

	header = "<small>This permit is for the creation of new rooms only; you cannot change existing rooms.</small>"


/obj/item/blueprints/attack_self(mob/living/M)
	if (!ishuman(M) && !issilicon(M))
		to_chat(M, "This stack of blue paper means nothing to you.")//monkeys cannot into projecting

		return

	if(currently_edited)
		if(editor && editor.client)
			stop_editing()
			return

	interact()
	return

/obj/item/blueprints/Topic(href, href_list)
	. = ..()
	if(.)
		return

	switch(href_list["action"])
		if("create_room")
			create_room(usr)

		if("create_area")
			create_area(usr)

		if("rename_area")
			rename_area(usr)

		if("edit_area")
			edit_area(usr)

		if("delete_area")
			delete_area(usr)

/obj/item/blueprints/interact()
	var/area/A = get_area()
	var/text = {"<HTML><head><title>[src]</title></head><BODY>
<h2>[station_name()] blueprints</h2>
<hr>
"}

	var/area_type = get_area_type()
	switch (area_type)
		if (AREA_SPACE)
			text += "<p>According to the blueprints, you are now in <b>outer space</b>.  Hold your breath.</p>"
		if (AREA_STATION)
			text += "<p>According to the blueprints, you are now in <b>\"[A.name]\"</b>.</p>"
		if (AREA_SPECIAL)
			text += "<p>This place isn't noted on the blueprint.</p>"
		if (AREA_BLUEPRINTS)
			text += "<p>According to the blueprints, you are now in <b>\"[A.name]\"</b> This drawing seems to be relatively new.</p>"

		else
			return

	text += "<br>"

	if(area_type in can_create_areas_in)
		text += "<p><a href='?src=\ref[src];action=create_room'>Create a new room</a></p>"
		text += "<p><a href='?src=\ref[src];action=create_area'>Start a new drawing</a></p>"
	if(area_type in can_rename_areas)
		text += "<p><a href='?src=\ref[src];action=rename_area'>Change the drawing's name</a></p>"
	if(area_type in can_edit_areas)
		text += "<p><a href='?src=\ref[src];action=edit_area'>Move an amendment to the drawing</a></p>"
	if(area_type in can_delete_areas)
		text += "<p><a href='?src=\ref[src];action=delete_area'>Erase this drawing</a></p>"

	text += "</BODY></HTML>"
	usr << browse(text, "window=blueprints")
	onclose(usr, "blueprints")


/obj/item/blueprints/proc/get_area()
	var/turf/T = get_turf(usr)
	var/area/A = get_area_master(T)
	return A

/obj/item/blueprints/proc/get_area_type(var/area/A = get_area())
	if (isspace(A))
		return AREA_SPACE
	else if(istype(A, /area/station/custom))
		return AREA_BLUEPRINTS

	var/list/SPECIALS = list(
		/area/shuttle,
		/area/admin,
		/area/arrival,
		/area/centcom,
		/area/asteroid,
		/area/tdome,
		/area/syndicate_station,
		/area/wizard_station,
		/area/prison
		// /area/derelict //commented out, all hail derelict-rebuilders!
	)
	for (var/type in SPECIALS)
		if ( istype(A,type) )
			return AREA_SPECIAL
	return AREA_STATION


/obj/item/blueprints/process()
	//Blueprints must be in hands to be usable
	//Editor must be in the edited area
	if(!istype(editor) || !editor.client || !currently_edited || (loc != editor) || (get_area(src) != get_area(editor)))
		if(editor)
			to_chat(editor, "<span class='info'>You finish modifying \the [src].</span>")

		return stop_editing()


/obj/item/blueprints/proc/stop_editing()
	if(editor && editor.client)
		editor.client.images.Remove(edited_overlay)

	editor = null
	edited_overlay = null
	currently_edited = null
	processing_objects.Remove(src)

/obj/item/blueprints/afterattack(atom/A, mob/user, proximity)
	if(!currently_edited)
		return

	//Click on a turf = add it to the edited area or remove it from the edited area
	var/turf/T = get_turf(A)
	if(isturf(A))
		var/area/space = get_space_area()
		var/area/target_area = T.loc

		if(target_area == currently_edited)
			T.set_area(space) //Remove from current area
			turf_amount_cache--
		else if(target_area == space)
			T.set_area(currently_edited) //Add to current area
			turf_amount_cache++
		else
			#define error_flash_dur 30
			//Create a temporary image that marks the conflicting area's borders
			var/image/bad_area = image('icons/turf/areas.dmi', target_area, "purple")
			animate(bad_area, alpha = 0, time = error_flash_dur)

			var/client/C = editor.client
			C.images.Add(bad_area)
			//The 'editor' might change in two seconds. This will pretty much guarantee the image is removed
			spawn(error_flash_dur)
				C.images.Remove(bad_area)

			#undef error_flash_dur

		//to_chat(editor, "[turf_amount_cache] / [max_room_size] turfs in [currently_edited]")

//Creates a new area and spreads it to cover the current room
/obj/item/blueprints/proc/create_room(mob/user)
	if(!(get_area_type() in can_create_areas_in))
		to_chat(user, "There is no space on \the [src] for another drawing.")
		return

	var/res = detect_room(get_turf(usr))
	if(!istype(res,/list))
		switch(res)
			if(ROOM_ERR_SPACE)
				to_chat(usr, "<span class='warning'>The new area must be completely airtight!</span>")
				return
			if(ROOM_ERR_TOOLARGE)
				to_chat(usr, "<span class='warning'>The new area too large!</span>")
				return
			else
				to_chat(usr, "<span class='warning'>Error! Please notify administration!</span>")
				return

	create_area(user, res)

//Creates a new area
/obj/item/blueprints/proc/create_area(mob/user, list/new_turfs = null)
	if(!(get_area_type() in can_create_areas_in))
		to_chat(user, "There is no space on \the [src] for another drawing.")
		return

	var/str = trim(stripped_input(usr,"New area name:","Blueprint Editing", "", MAX_NAME_LEN))
	if(!str || !length(str) || !Adjacent(user)) //cancel
		return
	if(length(str) > 50)
		to_chat(usr, "<span class='warning'>Name too long.</span>")
		return

	var/area/station/custom/newarea = new
	newarea.name = str
	newarea.tag = "[newarea.type]/[md5(str)]"

	if(islist(new_turfs))
		for(var/turf/T in new_turfs)
			T.set_area(newarea)
	else
		//Enter editing mode immediately, if not given an initial list of turfs
		var/turf/T = get_turf(user)
		T.set_area(newarea)

		edit_area(user)

	newarea.addSorted()

	ghostteleportlocs[newarea.name] = newarea

	sleep(5)
	interact()

/obj/item/blueprints/proc/edit_area(mob/user)
	if(!user || !user.client)
		return
	if(!(get_area_type() in can_edit_areas))
		to_chat(user, "You can't edit this drawing.")
		return

	if(currently_edited)
		stop_editing()

	editor = user

	currently_edited = get_area()
	processing_objects.Add(src)

	//var/list/edited_turfs = currently_edited.get_area_turfs()
	//turf_amount_cache = edited_turfs.len

	//Create a visual effect over the edited area
	edited_overlay = image('icons/turf/areas.dmi', currently_edited, "yellow")
	editor.client.images.Add(edited_overlay)

	to_chat(editor, "<span class='info'>In this mode, you can add or modify tiles to the [currently_edited] area. When you're done, bring up the blueprints or leave the area.</span>")

/obj/item/blueprints/proc/rename_area(mob/user)
	if(!(get_area_type() in can_rename_areas))
		to_chat(user, "This drawing was already signed, and can't be renamed.")
		return

	var/area/A = get_area()

	if(!istype(A) || !istype(user))
		return

	var/prevname = "[A.name]"
	var/str = trim(stripped_input(user, "New area name:","Blueprint Editing", prevname, MAX_NAME_LEN))
	if(!str || !length(str) || str==prevname) //cancel
		return
	if(!istype(A) || !istype(user))
		return
	if(!Adjacent(user))
		return

	if(length(str) > 50)
		to_chat(user, "<span class='warning'>Name too long.</span>")
		return

	A.name = str
	for(var/atom/allthings in A.contents)
		allthings.change_area_name(prevname,str)

	to_chat(user, "<span class='notice'>You change \the [prevname]'s title to '[str]'.</span>")

/obj/item/blueprints/proc/delete_area(var/mob/user) //This functionality is currently commented out!
	var/area/station/custom/areadeleted = get_area()
	var/area/space = get_space_area()

	if(alert(usr,"Are you sure you want to erase \"[areadeleted]\" from the blueprints?","Blueprint Editing","Yes","No") != "Yes")
		return
	else
		if(!Adjacent(user))
			return
		if(!(areadeleted == get_area()))
			return //if the blueprints are no longer in the area, return
		if(!istype(areadeleted))
			return //to make sure AGAIN that the area we're deleting is blueprint

	var/list/C = areadeleted.contents.Copy() //because areadeleted.contents is slow
	for(var/turf/T in C)
		space.contents.Add(T)
		T.change_area(areadeleted,space)

		for(var/atom/movable/AM in T.contents)
			AM.change_area(areadeleted,space)
	to_chat(usr, "You've erased the \"[areadeleted]\" from the blueprints.")

//Room auto-fill procs

/obj/item/blueprints/proc/check_tile_is_border(var/turf/T2,var/dir)
	if (istype(T2, /turf/space))
		return BORDER_SPACE //omg hull breach we all going to die here
	if (istype(T2, /turf/simulated/shuttle))
		return BORDER_SPACE
	if (get_area_type(T2.loc)!=AREA_SPACE)
		return BORDER_BETWEEN
	if (istype(T2, /turf/simulated/wall))
		return BORDER_2NDTILE
	if (!istype(T2, /turf/simulated))
		return BORDER_BETWEEN

	for (var/obj/structure/window/W in T2)
		if(turn(dir,180) == W.dir)
			return BORDER_BETWEEN
		if (W.is_fulltile())
			return BORDER_2NDTILE
	for(var/obj/machinery/door/window/D in T2)
		if(turn(dir,180) == D.dir)
			return BORDER_BETWEEN
	if (locate(/obj/machinery/door) in T2)
		return BORDER_2NDTILE
	if (locate(/obj/structure/falsewall) in T2)
		return BORDER_2NDTILE
	if (locate(/obj/structure/falserwall) in T2)
		return BORDER_2NDTILE

	return BORDER_NONE

/obj/item/blueprints/proc/detect_room(var/turf/first)
	var/list/turf/found = new
	var/list/turf/pending = list(first)
	while(pending.len)
		if (found.len+pending.len > max_room_size)
			return ROOM_ERR_TOOLARGE
		var/turf/T = pending[1] //why byond havent list::pop()?
		pending -= T
		for (var/dir in cardinal)
			var/skip = 0
			for (var/obj/structure/window/W in T)
				if(dir == W.dir || (W.is_fulltile()))
					skip = 1; break
			if (skip)
				continue
			for(var/obj/machinery/door/window/D in T)
				if(dir == D.dir)
					skip = 1; break
			if (skip)
				continue

			var/turf/NT = get_step(T,dir)
			if (!isturf(NT) || (NT in found) || (NT in pending))
				continue

			switch(check_tile_is_border(NT,dir))
				if(BORDER_NONE)
					pending+=NT
				if(BORDER_BETWEEN)
					//do nothing, may be later i'll add 'rejected' list as optimization
				if(BORDER_2NDTILE)
					found+=NT //tile included to new area, but we dont seek more
				if(BORDER_SPACE)
					return ROOM_ERR_SPACE
		found+=T
	return found
