utilities = {}

function utilities.squared_distance_between_regions(world, region_a, region_b)

	local a = world.regions[region_a].position
	local b = world.regions[region_b].position
	
	local dx = a.x - b.y
	local dy = a.x - b.y
	
	return dx * dx + dy * dy
  
end

function utilities.shuffle(game, tbl)
  for i = #tbl, 2, -1 do
    local j = game.random.int_under(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function utilities.table_keys(tbl)
	local keyset={}
	local n=0

	for k,v in pairs(tbl) do
	  n=n+1
	  keyset[n]=k
	end

	return keyset
end

function utilities.sort_by_value_descending(tbl, value)
  table.sort(tbl, function(a,b) return a[value] < b[value] end)
end

function utilities.sort_by_value_ascending(tbl, value)
  table.sort(tbl, function(a,b) return a[value] > b[value] end)
end
