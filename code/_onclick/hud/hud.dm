/*
	The hud datum
	Used to show and hide huds for all the different mob types,
	including inventories and item quick actions.
*/

/datum/hud
	var/mob/mymob

	var/hud_shown = TRUE			//Used for the HUD toggle (F12)
	var/hud_version = 1				//Current displayed version of the HUD
	var/inventory_shown = TRUE		//the inventory
	var/hotkey_ui_hidden = FALSE	//This is to hide the buttons that can be used via hotkeys. (hotkeybuttons list of buttons)

	var/obj/screen/lingchemdisplay
	var/obj/screen/lingstingdisplay

	var/obj/screen/guardianhealthdisplay

	var/obj/screen/blobpwrdisplay
	var/obj/screen/blobhealthdisplay
	var/obj/screen/vampire_blood_display
	var/obj/screen/ninja_energy_display
	var/obj/screen/ninja_focus_display
	var/obj/screen/wind_up_timer
	var/obj/screen/alien_plasma_display
	var/obj/screen/nightvisionicon
	var/obj/screen/action_intent
	var/obj/screen/zone_select
	var/obj/screen/move_intent
	var/obj/screen/module_store_icon
	var/obj/screen/combo/combo_display

	var/obj/screen/devil/soul_counter/devilsouldisplay

	var/list/static_inventory = list()		//the screen objects which are static
	var/list/toggleable_inventory = list()	//the screen objects which can be hidden
	var/list/hotkeybuttons = list()			//the buttons that can be used via hotkeys
	var/list/infodisplay = list()			//the screen objects that display mob info (health, alien plasma, etc...)
	var/list/inv_slots[slots_amt]			// /obj/screen/inventory objects, ordered by their slot ID.

	var/obj/screen/movable/action_button/hide_toggle/hide_actions_toggle
	var/action_buttons_hidden = FALSE

	var/list/obj/screen/plane_master/plane_masters = list() // see "appearance_flags" in the ref, assoc list of "[plane]" = object

/mob/proc/create_mob_hud()
	if(client && !hud_used)
		hud_used = new /datum/hud(src)
		update_sight()

/datum/hud/New(mob/owner)
	mymob = owner
	hide_actions_toggle = new
	hide_actions_toggle.InitialiseIcon(mymob)

	for(var/mytype in subtypesof(/obj/screen/plane_master))
		var/obj/screen/plane_master/instance = new mytype()
		plane_masters["[instance.plane]"] = instance
		instance.backdrop(mymob)

/datum/hud/Destroy()
	if(mymob.hud_used == src)
		mymob.hud_used = null

	QDEL_NULL(hide_actions_toggle)

	QDEL_NULL(module_store_icon)

	QDEL_LIST(static_inventory)

	inv_slots.Cut()
	action_intent = null
	zone_select = null
	move_intent = null

	QDEL_LIST(toggleable_inventory)

	QDEL_LIST(hotkeybuttons)

	QDEL_LIST(infodisplay)

	//clear mob refs to screen objects
	mymob.throw_icon = null
	mymob.healths = null
	mymob.healthdoll = null
	mymob.pullin = null
	mymob.stamina_bar = null

	//clear the rest of our reload_fullscreen
	lingchemdisplay = null
	lingstingdisplay = null
	blobpwrdisplay = null
	alien_plasma_display = null
	vampire_blood_display = null
	ninja_energy_display = null
	ninja_focus_display = null
	wind_up_timer = null
	nightvisionicon = null
	devilsouldisplay = null

	QDEL_LIST_ASSOC_VAL(plane_masters)

	mymob = null
	return ..()

/datum/hud/proc/show_hud(version = 0)
	if(!ismob(mymob))
		return FALSE

	if(!mymob.client)
		return FALSE

	mymob.client.screen = list()

	var/display_hud_version = version
	if(!display_hud_version)	//If 0 or blank, display the next hud version
		display_hud_version = hud_version + 1
	if(display_hud_version > HUD_VERSIONS)	//If the requested version number is greater than the available versions, reset back to the first version
		display_hud_version = 1

	switch(display_hud_version)
		if(HUD_STYLE_STANDARD)	//Default HUD
			hud_shown = TRUE	//Governs behavior of other procs
			if(static_inventory.len)
				mymob.client.screen += static_inventory
			if(toggleable_inventory.len && inventory_shown)
				mymob.client.screen += toggleable_inventory
			if(hotkeybuttons.len && !hotkey_ui_hidden)
				mymob.client.screen += hotkeybuttons
			if(infodisplay.len)
				mymob.client.screen += infodisplay

			mymob.client.screen += hide_actions_toggle

			if(action_intent)
				action_intent.screen_loc = initial(action_intent.screen_loc) //Restore intent selection to the original position
			. = TRUE

		if(HUD_STYLE_REDUCED)	//Reduced HUD
			hud_shown = FALSE	//Governs behavior of other procs
			if(static_inventory.len)
				mymob.client.screen -= static_inventory
			if(toggleable_inventory.len)
				mymob.client.screen -= toggleable_inventory
			if(hotkeybuttons.len)
				mymob.client.screen -= hotkeybuttons
			if(infodisplay.len)
				mymob.client.screen += infodisplay

			//These ones are a part of 'static_inventory', 'toggleable_inventory' or 'hotkeybuttons' but we want them to stay
			if(inv_slots[slot_l_hand])
				mymob.client.screen += inv_slots[slot_l_hand]	//we want the hands to be visible
			if(inv_slots[slot_r_hand])
				mymob.client.screen += inv_slots[slot_r_hand]	//we want the hands to be visible
			if(action_intent)
				mymob.client.screen += action_intent		//we want the intent switcher visible
				action_intent.screen_loc = ui_acti_alt	//move this to the alternative position, where zone_select usually is.
			. = FALSE

		if(HUD_STYLE_NOHUD)	//No HUD
			hud_shown = FALSE	//Governs behavior of other procs
			if(static_inventory.len)
				mymob.client.screen -= static_inventory
			if(toggleable_inventory.len)
				mymob.client.screen -= toggleable_inventory
			if(hotkeybuttons.len)
				mymob.client.screen -= hotkeybuttons
			if(infodisplay.len)
				mymob.client.screen -= infodisplay
			. = FALSE

	hud_version = display_hud_version
	persistent_inventory_update()
	mymob.update_action_buttons(1)
	reorganize_alerts()
	reload_fullscreen()
	update_parallax_pref(mymob)
	plane_masters_update()

/datum/hud/proc/plane_masters_update()
	// Plane masters are always shown to OUR mob, never to observers
	for(var/thing in plane_masters)
		var/obj/screen/plane_master/PM = plane_masters[thing]
		PM.backdrop(mymob)
		mymob.client.screen += PM

/datum/hud/human/show_hud(version = 0)
	. = ..()
	if(!.)
		return
	hidden_inventory_update()

/datum/hud/robot/show_hud(version = 0)
	. = ..()
	if(!.)
		return
	update_robot_modules_display()

/datum/hud/proc/hidden_inventory_update()
	return

/datum/hud/proc/persistent_inventory_update()
	return

//Triggered when F12 is pressed (Unless someone changed something in the DMF)
/mob/verb/button_pressed_F12()
	set name = "F12"
	set hidden = TRUE

	if(hud_used && client)
		hud_used.show_hud() //Shows the next hud preset
		to_chat(usr, "<span class ='info'>Switched HUD mode. Press F12 to toggle.</span>")
	else
		to_chat(usr, "<span class ='warning'>This mob type does not use a HUD.</span>")

/datum/hud/proc/update_locked_slots()
	return
