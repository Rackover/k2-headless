utilities = {}

function utilities.squared_distance_between_regions(world, region_a, region_b)

	local a = world.position(region_a)
	local b = world.position(region_b)
	
	local dx = a[1] - b[1]
	local dy = a[2] - b[2]
	
	return dx * dx + dy * dy
  
end

function utilities.shuffle(game, tbl)
  for i = #tbl, 2, -1 do
    local j = game.random.int_under(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

