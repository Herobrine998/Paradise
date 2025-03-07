
//The advanced pea-green monochrome lcd of tomorrow.
// EDIT 2020-09-21: We have had NanoUI PDAs for years, and I am now finally TGUI-ing them
// They arent pea green trash. I DEFY YOU COMMENTS!!! -aa

/// Global list of all PDAs in the world
GLOBAL_LIST_EMPTY(PDAs)


/obj/item/pda
	name = "PDA"
	desc = "A portable microcomputer by Thinktronic Systems, LTD. Functionality determined by a preprogrammed ROM cartridge."
	icon = 'icons/obj/pda.dmi'
	icon_state = "pda"
	w_class = WEIGHT_CLASS_TINY
	slot_flags = SLOT_ID | SLOT_BELT | SLOT_PDA
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 100, "acid" = 100)
	resistance_flags = FIRE_PROOF | ACID_PROOF
	origin_tech = "programming=2"

	//Main variables
	var/owner = null
	var/default_cartridge = 0 // Access level defined by cartridge
	var/obj/item/cartridge/cartridge = null //current cartridge
	var/datum/data/pda/app/current_app = null
	var/datum/data/pda/app/lastapp = null

	//Secondary variables
	var/model_name = "Thinktronic 5230 Personal Data Assistant"
	var/datum/data/pda/utility/scanmode/scanmode = null

	var/lock_code = "" // Lockcode to unlock uplink
	var/honkamt = 0 //How many honks left when infected with honk.exe
	var/mimeamt = 0 //How many silence left when infected with mime.exe
	var/detonate = 1 // Can the PDA be blown up?
	var/ttone = "beep" //The ringtone!
	var/list/ttone_sound = list("beep" = 'sound/machines/twobeep.ogg',
								"boom" = 'sound/effects/explosionfar.ogg',
								"slip" = 'sound/misc/slip.ogg',
								"honk" = 'sound/items/bikehorn.ogg',
								"SKREE" = 'sound/voice/shriek1.ogg',
								"holy" = 'sound/items/PDA/ambicha4-short.ogg',
								"xeno" = 'sound/voice/hiss1.ogg',
								"stalk" = 'sound/items/PDA/stalk1.ogg',
								"stalk2" = 'sound/items/PDA/stalk2.ogg')

	var/list/programs = list(
		new/datum/data/pda/app/main_menu,
		new/datum/data/pda/app/notekeeper,
		new/datum/data/pda/app/messenger,
		new/datum/data/pda/app/manifest,
		new/datum/data/pda/app/atmos_scanner,
		new/datum/data/pda/utility/flashlight)
	var/list/shortcut_cache = list()
	var/list/shortcut_cat_order = list()
	var/list/notifying_programs = list()

	var/obj/item/card/id/id = null //Making it possible to slot an ID card into the PDA so it can function as both.
	var/ownjob = null //related to above
	var/ownrank = null // this one is rank, never alt title

	var/obj/item/paicard/pai = null	// A slot for a personal AI device
	var/retro_mode = 0
	var/iconImage


/*
 *	The Actual PDA
 */
/obj/item/pda/Initialize(mapload)
	. = ..()
	GLOB.PDAs += src
	GLOB.PDAs = sortAtom(GLOB.PDAs)

	// Generate image for the pda for TGUI.
	iconImage = "[icon2base64(icon(icon, icon_state, frame = 1))]"

	update_programs()
	if(default_cartridge)
		cartridge = new default_cartridge(src)
		cartridge.update_programs(src)
	new /obj/item/pen(src)
	start_program(find_program(/datum/data/pda/app/main_menu))

/obj/item/pda/proc/can_use()
	if(!ismob(loc))
		return 0

	var/mob/M = loc
	if(M.incapacitated(ignore_lying = TRUE))
		return 0
	if((src in M.contents) || ( istype(loc, /turf) && in_range(src, M) ))
		return 1
	else
		return 0

/obj/item/pda/GetAccess()
	if(id)
		return id.GetAccess()
	else
		return ..()

/obj/item/pda/GetID()
	return id ? id : ..()


/obj/item/pda/MouseDrop(atom/over)
	. = ..()

	var/mob/user = usr
	if(!ishuman(user) || !Adjacent(user) || user.incapacitated())
		return FALSE

	attack_self(user)
	return TRUE


/obj/item/pda/attack_self(mob/user as mob)
	user.set_machine(src)
	if(active_uplink_check(user))
		return
	ui_interact(user)

/obj/item/pda/proc/start_program(datum/data/pda/P)
	if(P && ((P in programs) || (cartridge && (P in cartridge.programs))))
		return P.start()
	return 0

/obj/item/pda/proc/find_program(type)
	var/datum/data/pda/A = locate(type) in programs
	if(A)
		return A
	if(cartridge)
		A = locate(type) in cartridge.programs
		if(A)
			return A
	return null

// force the cache to rebuild on update_ui
/obj/item/pda/proc/update_shortcuts()
	shortcut_cache.Cut()

/obj/item/pda/proc/update_programs()
	for(var/A in programs)
		var/datum/data/pda/P = A
		P.pda = src

/obj/item/pda/proc/close(mob/user)
	SStgui.close_uis(src)

/obj/item/pda/verb/verb_reset_pda()
	set category = "Object"
	set name = "Reset PDA"
	set src in usr

	if(issilicon(usr))
		return

	if(can_use(usr))
		start_program(find_program(/datum/data/pda/app/main_menu))
		notifying_programs.Cut()
		overlays -= image('icons/obj/pda.dmi', "pda-r")
		to_chat(usr, "<span class='notice'>You press the reset button on \the [src].</span>")
		SStgui.update_uis(src)
	else
		to_chat(usr, "<span class='notice'>You cannot do this while restrained.</span>")

/obj/item/pda/AltClick(mob/living/user)
	if(issilicon(user))
		return
	if(!istype(user) || user.incapacitated())
		to_chat(user, "<span class='warning'>You can't do that right now!</span>")
		return
	if(can_use(user))
		if(id)
			remove_id(user)
		else
			to_chat(user, "<span class='warning'>This PDA does not have an ID in it!</span>")

/obj/item/pda/CtrlClick(mob/user)
	..()
	if(issilicon(user))
		return

	if(can_use(user))
		remove_pen(user)

/obj/item/pda/proc/remove_id(mob/user)
	if(id)
		if(ismob(loc))
			var/mob/M = loc
			M.put_in_hands(id)
			to_chat(user, "<span class='notice'>You remove the ID from the [name].</span>")
			SStgui.update_uis(src)
		else
			id.forceMove(get_turf(src))
		overlays -= image('icons/goonstation/objects/pda_overlay.dmi', id.icon_state)
		id = null

/obj/item/pda/verb/verb_remove_id()
	set category = "Object"
	set name = "Remove id"
	set src in usr

	if(issilicon(usr))
		return

	if( can_use(usr) )
		if(id)
			remove_id(usr)
		else
			to_chat(usr, "<span class='notice'>This PDA does not have an ID in it.</span>")
	else
		to_chat(usr, "<span class='notice'>You cannot do this while restrained.</span>")

/obj/item/pda/verb/verb_remove_pen()
	set category = "Object"
	set name = "Remove pen"
	set src in usr
	remove_pen(usr)

/obj/item/pda/proc/remove_pen(mob/user)

	if(issilicon(user))
		return

	if( can_use(user) )
		var/obj/item/pen/O = locate() in src
		if(O)
			to_chat(user, "<span class='notice'>You remove \the [O] from [src].</span>")
			if(istype(loc, /mob))
				var/mob/M = loc
				if(M.get_active_hand() == null)
					M.put_in_hands(O)
					return
			O.forceMove(get_turf(src))
		else
			to_chat(user, "<span class='warning'>This PDA does not have a pen in it.</span>")
	else
		to_chat(user, "<span class='notice'>You cannot do this while restrained.</span>")

/obj/item/pda/proc/id_check(mob/user as mob, choice as num)//To check for IDs; 1 for in-pda use, 2 for out of pda use.
	if(choice == 1)
		if(id)
			remove_id(user)
		else
			var/obj/item/I = user.get_active_hand()
			if(istype(I, /obj/item/card/id))
				user.drop_transfer_item_to_loc(I, src)
				id = I
	else
		var/obj/item/card/I = user.get_active_hand()
		if(istype(I, /obj/item/card/id) && I:registered_name)
			var/obj/old_id = id
			user.drop_from_active_hand()
			I.forceMove(src)
			id = I
			user.put_in_hands(old_id)
	return

/obj/item/pda/attackby(obj/item/C as obj, mob/user as mob, params)
	..()
	if(istype(C, /obj/item/cartridge) && !cartridge)
		cartridge = C
		user.drop_transfer_item_to_loc(C, src)
		cartridge.update_programs(src)
		update_shortcuts()
		to_chat(user, "<span class='notice'>You insert [cartridge] into [src].</span>")
		SStgui.update_uis(src)
		if(cartridge.radio)
			cartridge.radio.hostpda = src

	else if(istype(C, /obj/item/card/id))
		var/obj/item/card/id/idcard = C
		if(!idcard.registered_name)
			to_chat(user, "<span class='notice'>\The [src] rejects the ID.</span>")
			return
		if(!owner)
			owner = idcard.registered_name
			ownjob = idcard.assignment
			ownrank = idcard.rank
			name = "PDA-[owner] ([ownjob])"
			to_chat(user, "<span class='notice'>Card scanned.</span>")
			SStgui.update_uis(src)
		else
			//Basic safety check. If either both objects are held by user or PDA is on ground and card is in hand.
			if(((src in user.contents) && (C in user.contents)) || (istype(loc, /turf) && in_range(src, user) && (C in user.contents)) )
				if( can_use(user) )//If they can still act.
					id_check(user, 2)
					to_chat(user, "<span class='notice'>You put the ID into \the [src]'s slot.<br>You can remove it with ALT click.</span>")
					overlays += image('icons/goonstation/objects/pda_overlay.dmi', C.icon_state)
					SStgui.update_uis(src)

	else if(istype(C, /obj/item/paicard) && !src.pai)
		user.drop_transfer_item_to_loc(C, src)
		pai = C
		to_chat(user, "<span class='notice'>You slot \the [C] into [src].</span>")
		SStgui.update_uis(src)
	else if(istype(C, /obj/item/pen))
		var/obj/item/pen/O = locate() in src
		if(O)
			to_chat(user, "<span class='notice'>There is already a pen in \the [src].</span>")
		else
			user.drop_transfer_item_to_loc(C, src)
			to_chat(user, "<span class='notice'>You slide \the [C] into \the [src].</span>")
	else if(istype(C, /obj/item/nanomob_card))
		if(cartridge && istype(cartridge, /obj/item/cartridge/mob_hunt_game))
			cartridge.attackby(C, user, params)

/obj/item/pda/attack(mob/living/C as mob, mob/living/user as mob)
	if(istype(C, /mob/living/carbon) && scanmode)
		scanmode.scan_mob(C, user)

/obj/item/pda/afterattack(atom/A as mob|obj|turf|area, mob/user as mob, proximity)
	if(try_item_eat(A, user))
		return FALSE

	if(proximity && scanmode)
		scanmode.scan_atom(A, user)

/obj/item/pda/proc/explode() //This needs tuning.
	if(!detonate)
		return
	var/turf/T = get_turf(src.loc)

	if(ismob(loc))
		var/mob/M = loc
		M.show_message("<span class='danger'>Your [src] explodes!</span>", 1)

	if(T)
		T.hotspot_expose(700,125)

		explosion(T, -1, -1, 2, 3, cause = src)
	qdel(src)
	return

/obj/item/pda/Destroy()
	GLOB.PDAs -= src
	var/T = get_turf(loc)
	if(id)
		id.forceMove(T)
	if(pai)
		pai.forceMove(T)
	current_app = null
	scanmode = null
	QDEL_LIST(programs)
	QDEL_NULL(cartridge)
	return ..()

// Pass along the pulse to atoms in contents, largely added so pAIs are vulnerable to EMP
/obj/item/pda/emp_act(severity)
	for(var/atom/A in src)
		A.emp_act(severity)

/obj/item/pda/proc/play_ringtone()
	var/S

	if(ttone in ttone_sound)
		S = ttone_sound[ttone]
	else
		S = 'sound/machines/twobeep.ogg'
	playsound(loc, S, 50, 1)
	for(var/mob/O in hearers(3, loc))
		O.show_message(text("[bicon(src)] *[ttone]*"))

/obj/item/pda/proc/set_ringtone()
	var/t = input("Please enter new ringtone", name, ttone) as text
	if(in_range(src, usr) && loc == usr)
		if(t)
			if(hidden_uplink && hidden_uplink.check_trigger(usr, trim(lowertext(t)), lowertext(lock_code)))
				to_chat(usr, "The PDA softly beeps.")
				close(usr)
			else
				t = sanitize(copytext_char(t, 1, 20))
				ttone = t
			return 1
	else
		close(usr)
	return 0

/obj/item/pda/process()
	if(current_app)
		current_app.program_process()

/obj/item/pda/extinguish_light(force = FALSE)
	var/datum/data/pda/utility/flashlight/FL = find_program(/datum/data/pda/utility/flashlight)
	if(FL && FL.fon)
		FL.start()
