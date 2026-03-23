
ai_preferred_buildings = {
	EBUILDING.FORT,
	EBUILDING.CHURCH,
	EBUILDING.FIELDS
}

ai_farming_tendancy_score = 50
ai_stays_at_home_score = 3
ai_random_chance_no_play = 0

require("simple_inc")

function PLAY_TURN(game)
	take_all_actions(game)
end

function PLAY_TURN_LATE(game)

	-- Called in the last two seconds after a turn, ONLY if the playing faction has the flag EFACTIONFLAG.SEEENEMYPLANNEDCONSTRUCTIONS
	-- otherwise it's never called
	
end

function GET_PERSONAS()
	-- should return a list of tables of the following format
	--	{ 
	--		gender: int 
	--		name: string
	--		only_for_faction: int?
	--	}
	-- 		gender 0,1,2 = female, male, neutral
	--		name will be truncated to about 16 characters. don't be too weird with accents please!
	--		only_for_faction can be nil, if you put a number there (faction index) it will be picked in priority if the player has said faction, ignored otherwise
	
	-- Factions: 
	-- 0 => Dogs
	-- 1 => Boars
	-- 2 => Mice
	-- 3 => Foxes
	-- 4 => Wolves
	-- 5 => Bunnies

	-- there must be AT LEAST EIGHT PERSONAS !
	
	local personas = {}
	
	table.insert(personas, {
		gender = 1,
		name = "Courtois"
	})
	
	table.insert(personas, {
		gender = 1,
		name = "Vaillant"
	})
	
	table.insert(personas, {
		gender = 2,
		name = "Roenel"
	})
	
	table.insert(personas, {
		gender = 0,
		name = "Fidèle"
	})
	
	table.insert(personas, {
		gender = 0,
		name = "Noble"
	})
	
	table.insert(personas, {
		gender = 0,
		name = "Fiere"
	})
	
	table.insert(personas, {
		gender = 2,
		name = "Corniaud"
	})
	
	table.insert(personas, {
		gender = 1,
		name = "Guinefort"
	})
	
	return personas
	
end


