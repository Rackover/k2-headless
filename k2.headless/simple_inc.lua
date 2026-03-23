
-- "Fresh meat" computer player - spends money as soon as they have them, attacks only if territory got too small, and plays very centered on the capital_region

require("utilities")

local function get_relevant_regions(game)
	local relevant_regions = {}
	
	-- build unique territory
	local territory = game.world.realms[game.player.realm_index].owned_regions
	for i = 1, #territory do
		relevant_regions[territory[i]] = true
	end
	
	-- Add things nearby
	for i = 1, #territory do
		local neighbors = game.world.regions[territory[i]].neighbor_indices
		for neighbor_index = 1, #neighbors do
			local neighbor_region_index = neighbors[neighbor_index]
			if game.world.regions[neighbor_region_index].can_be_attacked then
				relevant_regions[neighbor_region_index] = true
			end
		end
		
	end
	
	-- Remove unplayable
	for region_index, _ in ipairs(relevant_regions) do
		if game.world.regions[region_index].has_played
			or game.world.regions[region_index].building
		then
			relevant_regions[region_index] = nil
		end
	end
	
	return 	utilities.table_keys(relevant_regions)
end

local function needs_money(game)
	local score = game.world.realms[game.player.realm_index].silver_treasury
	
	local planned_buildings = game.world.realms[game.player.realm_index].planned_buildings
	
	for i, building in ipairs(planned_buildings) do
		if building == EBUILDING.FIELDS then
			score = score + 30
		end
	end
	
	
	return score < ai_farming_tendancy_score
end

local function needs_expansion(game)

	local territory = game.world.realms[game.player.realm_index].owned_regions
	
	local territory_size = #territory
	local max_territory_size = math.min(50, #game.world.regions)
	
	
	local target_territory_size = max_territory_size / math.min(1, ai_stays_at_home_score)
	
	local planned_attacks = game.world.realms[game.player.realm_index].planned_attacks;
	
	target_territory_size = target_territory_size - (#planned_attacks) * 2
	
	return territory_size < target_territory_size
end


local function try_build_on_region(game, building, region_index)

	if game.buildings[building].can_afford then
		if game.buildings[building].can_build_on_region(region_index, building) then
			game.player.plan_construction(region_index, building)
			return true
		end
	end

end

local function try_build_farms(game, ordered_regions)
	if game.buildings[EBUILDING.FIELDS].can_afford then
		for i, region in ipairs(ordered_regions) do
			if try_build_on_region(game, EBUILDING.FIELDS, region) then
				return true
			end
		end
	end
	
	return false
end

local function try_build_anything(game, ordered_regions)
	for k, building in ipairs(ai_preferred_buildings) do
		for i, region in ipairs(ordered_regions) do
			if try_build_on_region(game, building, region) then
				return true
			end
		end
	end
	
	return false
end

local function try_attack(game, ordered_regions)
	
	for i, region in ipairs(ordered_regions) do
	
		if game.world.regions[region].can_play then
			local targets = game.world.regions[region].potential_attack_targets
			
			if targets and #targets > 0 then
				local random_index = game.random.int_under(#targets) + 1
				local attack_target = targets[random_index]
				game.player.plan_attack(region, attack_target)
				return true
			end
		
			
		end
	
	end
	
	return false
end


function take_all_actions(game)
	-- Make ordered regions for later use
	local regions_ordered = get_relevant_regions(game)
	
	
	-- Prepare regions
	local capital_region = game.world.realms[game.player.realm_index].capital
	if capital_region ~= nil then
	
		local score_per_region = {}
		
		for i, region in ipairs(regions_ordered) do
			score_per_region[region] = utilities.squared_distance_between_regions(game.world, capital_region, region)
		end
		
		table.sort(regions_ordered, function(a, b) 
			return score_per_region[a] < score_per_region[b]
		end)
	else
		regions_ordered = utilities.shuffle(game, regions_ordered)
	end
			
	while true do
	
		local decisions_remaining = game.world.realms[game.player.realm_index].remaining_decisions
		
		if decisions_remaining <= 0 then
			break;
		end
	
		local random_chance_no_play = game.random.int_under(100)
		if random_chance_no_play < ai_random_chance_no_play then
			-- play a random attack, most probably repeated
			try_attack(game, regions_ordered)
			decisions_remaining = decisions_remaining - 1
		else
			if game.world.realms[game.player.realm_index].can_upgrade_administration then
				game.player.upgrade_administration()
			else
				-- Behaviour
				local has_played = false
				if needs_money(game) and not has_played then
					if try_build_farms(game, regions_ordered) then
						has_played = true
						decisions_remaining = decisions_remaining - 1
					end
					
					
				end
				
				if needs_expansion(game) and not has_played then
					if try_attack(game, regions_ordered) then
						has_played = true
						decisions_remaining = decisions_remaining - 1
					end
				end
					
				if try_build_anything(game, regions_ordered) and not has_played  then
					has_played = true
					decisions_remaining = decisions_remaining - 1
				end
					
				if game.world.realms[game.player.realm_index].can_pay_for_favours and not has_played  then
					game.player.pay_for_favours()
					has_played = true
					decisions_remaining = decisions_remaining - 1
				end
				
				if not has_played then
					-- Last resort, just attack randomly if no other action is available
					try_attack(game, regions_ordered)
					decisions_remaining = decisions_remaining - 1
				end
			end
		end
		
		game:refresh() -- Refresh it once we've played
	end
end



--[[

the "game" object is a table made of the following elements:
"random" = {
	"int" = <MakeAPI>b__0 (),
	"int_under" = <MakeAPI>b__1 (),
},
"player" = {
	"pay_for_favours" = <ToLuaFunction>b__0 (),
	"upgrade_administration" = <ToLuaFunction>b__0 (),
	"plan_attack" = <ToLuaFunction>b__0 (),
	"plan_construction" = <ToLuaFunction>b__0 (),
	"faction" = 16,
	"realm_index" = 0,
},
"world" = {
	"regions" = {
		1 = {
			"neighbor_indices" = {
				1 = 2,
				2 = 10,
				3 = 9,
			},
			"building" = "None",
			"planned_construction" = "None",
			"has_played" = false,
			"subjugation_owner" = nil,
			"silver_revenue" = 1,
			"is_vulnerable" = true,
			"potential_attack_targets" = {
				1 = 2,
				2 = 9,
			},
			"lootable_silver" = 1,
			"position" = {
				"x" = 1,
				"y" = 0,
			},
			"is_reinforced_against_attacks" = false,
			"faction" = 16,
			"can_be_taken" = true,
			"can_be_attacked" = true,
			"potential_attacking_regions" = {
				1 = 0,
			},
			"is_council" = false,
			"can_play" = false,
			"refresh" = <WriteRegionObjectInto>b__2 (),
		},
		2 = {
			"neighbor_indices" = {
				1 = 9,
				2 = 1,
				3 = 2,
				4 = 11,
				5 = 20,
				6 = 19,
			},
			"building" = "None",
			"planned_construction" = "None",
			"planned_attacks" = {
			},
			"has_played" = false,
			"owner" = 0,
			"subjugation_owner" = 0,
			"silver_revenue" = 2,
			"is_vulnerable" = true,
			"potential_attack_targets" = {
				1 = 2,
				2 = 9,
				3 = 1,
			},
			"lootable_silver" = 2,
			"position" = {
				"x" = 1,
				"y" = 1,
			},
			"is_reinforced_against_attacks" = false,
			"faction" = 16,
			"can_be_taken" = true,
			"can_be_attacked" = false,
			"potential_attacking_regions" = {
			},
			"is_council" = false,
			"can_play" = true,
			"refresh" = <WriteRegionObjectInto>b__2 (),
		},
		3 = ...,
	},
	"realms" = {
		1 = {
			"capital" = 20,
			"owned_regions" = {
				1 = 10,
				2 = 11,
				3 = 19,
				4 = 20,
				5 = 21,
				6 = 28,
				7 = 29,
			},
			"is_council" = false,
			"faction" = 16,
			"administration_upgrade_is_planned" = false,
			"any_decisions_remaining" = true,
			"can_pay_for_favours" = false,
			"can_upgrade_administration" = false,
			"administration_upgrade_silver_cost" = 50,
			"max_decisions" = 3,
			"remaining_decisions" = 3,
			"silver_treasury" = 20,
			"is_favoured" = false,
			"planned_attacks" = {
			},
			"any_attack_planned" = 0,
			"planned_buildings" = {
			},
			"is_building_anything" = 0,
			"refresh" = <WriteRealmObjectInto>b__2 (),
		},
		2 = {
			"capital" = 60,
			"owned_regions" = {
				1 = 50,
				2 = 51,
				3 = 59,
				4 = 60,
				5 = 61,
				6 = 68,
				7 = 69,
			},
			"is_council" = false,
			"faction" = 258,
			"refresh" = <WriteRealmObjectInto>b__2 (),
		},
		3 = {
			"capital" = 40,
			"owned_regions" = {
				1 = 40,
			},
			"is_council" = true,
			"faction" = 0,
			"refresh" = <WriteRealmObjectInto>b__2 (),
		},
	},
	"refresh" = <WriteWorldObjectInto>b__0 (),
},
"voting" = {
	"wasted_votes" = 0,
	"scores" = nil,
},
"days_passed" = 0,
"days_before_next_council" = 5,
"councils_passed" = 0,
"buildings" = {
	"Fields" = {
		"can_afford" = true,
		"silver_revenue" = true,
		"can_build_on_region" = <ToLuaFunction>b__0 (),
	},
	"Church" = {
		"can_afford" = false,
		"silver_revenue" = true,
		"can_build_on_region" = <ToLuaFunction>b__0 (),
	},
	"Fort" = {
		"can_afford" = false,
		"silver_revenue" = true,
		"can_build_on_region" = <ToLuaFunction>b__0 (),
	},
},
"refresh" = <WriteGameObjectInto>b__0 (),

--]]