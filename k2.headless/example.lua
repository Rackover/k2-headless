
-- "Fresh meat" computer player - spends money as soon as they have them, attacks only if territory got too small, and plays very centered on the capital_region

-- Factions: 
-- 0 => Dogs
-- 1 => Boars
-- 2 => Mice
-- 3 => Foxes
-- 4 => Wolves
-- 5 => Bunnies

require("example_requirement")
require("utilities")

function PLAY_TURN(game)
	local decisions_remaining = game.player.get_remaining_decisions()
	
	-- Make ordered regions for later use
	local regions_ordered = game.world.get_regions()
	coroutine.yield()
	
	-- Prepare regions
	local capital_region = game.world.get_capital_of_realm(game.player.realm_index)
	if capital_region ~= nil then
	
		local score_per_region = {}
		
		for i, region in ipairs(regions_ordered) do
			score_per_region[region] = utilities.squared_distance_between_regions(game.world, capital_region, region)
		end
		
		coroutine.yield()
	
		table.sort(regions_ordered, function(a, b) 
			return score_per_region[a] < score_per_region[b]
		end)
	else
		regions_ordered = utilities.shuffle(game, regions_ordered)
	end
	
	coroutine.yield()
			
	while (decisions_remaining > 0) do
		if game.player.can_upgrade_administration() then
			game.player.upgrade_administration()
		else
			-- Behaviour
			local has_played = false
			if needs_money(game) and not has_played then
				if try_build_farms(game, regions_ordered) then
					has_played = true
					decisions_remaining = decisions_remaining - 1
				end
				
				coroutine.yield()
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
				
			if game.player.can_pay_for_favours() and not has_played  then
				game.player.pay_for_favours()
				has_played = true
				decisions_remaining = decisions_remaining - 1
			end
			
			if not has_played then
				-- Last resort, just attack randomly if no other action is available
				try_attack(game, regions_ordered)
				decisions_remaining = decisions_remaining - 1
			end
			
			coroutine.yield()
		end
	end
end

function needs_money(game)
	local score = game.player.get_treasury()
	
	local planned_buildings = game.player.get_planned_buildings()
	
	for i, building in ipairs(planned_buildings) do
		if building == EBUILDING.FIELDS then
			score = score + 3
		end
	end
	
	
	return score < 5
end

function needs_expansion(game)

	local territory = game.world.get_territory_of_realm(game.player.realm_index)
	
	local territory_size = #territory
	local max_territory_size = math.min(50, #game.world.get_regions())
	
	
	local target_territory_size = max_territory_size / 4
	
	local planned_attacks = game.player.get_planned_attacks()
	
	target_territory_size = target_territory_size - (#planned_attacks) * 2
	
	return territory_size < target_territory_size
end

function try_build_farms(game, ordered_regions)
	for i, region in ipairs(ordered_regions) do
		if game.player.is_building_something(region) == nil 
		and game.player.can_build(region, EBUILDING.FIELDS) then
			game.player.plan_construction(region, EBUILDING.FIELDS)
			return true
		end
	end
	
	return false
end

function try_build_anything(game, ordered_regions)
	for k, building in ipairs(preferred_buildings) do
		for i, region in ipairs(ordered_regions) do
			if game.player.is_building_something(region) == nil 
			and game.player.can_build(region, building) then
				game.player.plan_construction(region, building)
				return true
			end
		end
		
		coroutine.yield()
	end
	
	return false
end

function try_attack(game, ordered_regions)
	
	for i, region in ipairs(ordered_regions) do
	
		if game.player.can_play_with_region(region) then
			local targets = game.world.get_attack_targets_for_region(region, false)
			
			if #targets > 0 then
				local random_index = game.random.int_under(#targets) + 1
				local attack_target = targets[random_index]
				game.player.plan_attack(region, attack_target)
				return true
			end
		
			coroutine.yield()
		end
	
	end
	
	return false
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



--[[
the "game" object is a table made of the following elements:

	"random" = {
		"int" = int (),
		"int_under" = int (int exclusive_max),
	},
	"player" = {
		"admin_upgrade_is_planned" = bool(),
		"any_decisions_remaining" = bool(),
		"can_extend_attack" = bool (),
		"can_pay_for_favours" = bool (),
		"can_upgrade_administration" = bool (),
		"favours_are_planned" = bool (),
		"get_administration_upgrade_silver_cost" = int (),
		"get_maximum_decisions" = int (),
		"get_remaining_decisions" = int (),
		"get_treasury" = int (),
		"is_favoured" = bool (),
		"can_afford" = bool (EBuilding building),
		"can_build_on" = bool (int region),
		"can_build" = bool (int region, EBuilding building),
		"can_play_with_region" =  bool (int region),
		"get_planned_attacks" = table<table> (),
		"get_planned_buildings" = table<EBuilding> (),
		"has_any_attack_planned" = int (),
		"is_building_anything" = int (),
		"is_building_something" = EBuilding (int region),
		"is_under_attack" = table<(bool, int, bool)> (int region), -- (is_attacked, attack_count, any_extended_attack)
		
		"pay_for_favours" = void (),
		"upgrade_administration" = void (),
		"plan_attack" = void (int from_region, int to_region),
		"plan_construction" = void(int region, EBuilding building),
		
		"faction" = EFactionFlag,
		"realm_index" = int,
	},
	"world" = {
		"position" = table<(int, int)> (int region),
		"can_realm_attack_region" = bool (int realm, int region),
		"get_realm_faction" = EFactionFlag (int realm),
		"get_region_faction" = EFactionFlag (int region),
		"get_region_building" = EBuilding (int region),
		"can_region_be_taken" = bool (int region),
		"get_region_owner" = int? (int region),
		"get_region_lootable_silver_worth" = int? (int region),
		"get_region_silver_worth" = int? (int region), -- aka How much silver it gives each round
		"is_council_realm" = bool (int realm),
		"is_council_region" = bool (int region),
		"get_territory_of_realm" = table<int> (int realm),
		"get_attack_targets_for_region" = table<int> (int from_region, bool can_extend_attacks),
		"get_neighboring_regions" = table<int> (int region),
		"get_capital_of_realm" = int? (int realm),
		"get_regions" = table<int> (),
	},
	"voting" = {
		"wasted_votes" = int,
		"scores" = table<table>
		-- key => realm index,  value looks like this:	
		--	{
		--			"total" = 14,
		--			"has_max_money" = false,
		--			"has_max_lands" = true,
		--			"has_max_development" = false,
		--			"has_favoured" = false,
		--			"has_max_churches" = true,
		--			"has_accident" = false,
		--			"has_council_neighbor" = false,
		--			"has_best_administration" = false,
		--	},
		--
	},
	"days_passed" = int,
	"days_before_next_council" = int,
	"councils_passed" = int,
	"everybody_has_played" = bool (),
	"local_player_index" = int,
	"rules" = {
		"additionalRealmsCount" = int,
		"hasCouncilRealm" = bool,
		"councilRealmRegionSize" = int,
		"initialSafetyMarginBetweenRealms" = int,
		"initialRealmsSize" = int,
		"silverRevenuePerRegion" = int,
		"startingGold" = int,
		"startingDecisionCount" = int,
		"maxDecisionCount" = int,
		"favourGoldPrice" = int,
		"enhanceAdminGoldPrice" = int,
		"enhanceAdminGoldPriceIncreasePerUpgrade" = int,
		"allowLooting" = bool,
		"silverLootedOnCapital" = int,
		"neutralRegionStarvation" = bool,
		"goTakeNeutralOnlyWhenNoContest" = bool,
		"turnsBetweenVotes" = int,
		"initialVoteTurnsDelay" = int,
		"decisionTimeSeconds" = int,
		"additionalDecisionTimeSecondsOnFirstTurn" = int,
		"eatenCorners" = int,
		"eatFirstLastColumns" = int,
		"voting" = {
			"voterCount" = int,
			"criteriasUsedPerVote" = table<int>, -- key is council index (0, 1, 2 ...) and value is  number of criterias used for that voting session (2, 3, 4...)
			"turnoverPercentagePerCouncil" = table<int>, -- key is council index (0, 1, 2 ...) and value is 0-100 percentage integer
			"votingCriterias" = {
				1 = { -- MaxMoney
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				2 = { -- MaxLands
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				3 = { -- MaxDevelopment
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				4 = { -- Favoured
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				5 = { -- MaxChurches
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				6 = { -- Accident
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				7 = { -- CouncilNeighbor
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
				8 = { -- BestAdministration
					"criteria" = int,
					"enabled" = bool,
					"activeAfterCouncils" = int,
					"chancesToBeSelected" = int,
					"influenceWeight" = int,
				},
			},
		},
		"buildings" = {
			1 = { -- Capital
				"building" = int,
				"silverRevenue" = int,
				"silverCost" = int,
				"canBeBuilt" = bool,
			},
			2 = { -- Fields
				"building" = int,
				"silverRevenue" = int,
				"silverCost" = int,
				"canBeBuilt" = bool,
			},
			3 = { -- Fort
				"building" = int,
				"silverRevenue" = int,
				"silverCost" = int,
				"canBeBuilt" = bool,
			},
			4 = { -- Church
				"building" = int,
				"silverRevenue" = int,
				"silverCost" = int,
				"canBeBuilt" = = bool,
			},
		},
		"factions" = {
			"richesSilverMultiplier" = int,
			"richesBuildingMultiplier" = int,
			"richesBuildingDivider" = int,
			"looterRichesMultiplier" = int,
			"looterMinimumSilver" = int,
			"conqueredFortPayout" = int,
			"flagsForFaction" = {
				1 = int,
				2 = int,
				3 = int,
				4 = int,
				5 = int,
				6 = int,
			},
			"FactionCount" = int,
		},
	},
--]]