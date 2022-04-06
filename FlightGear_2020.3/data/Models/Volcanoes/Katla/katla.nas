		var katla_ash_loop_flag = 0;
	
		var katla_main_factor = 1.0;
		var katla_main_probability = 0.985;
		
		var katla_pos = geo.Coord.new().set_latlon(63.65750,  -19.182871);

	
		var katla_ash_loop = func (timer) {

		if (katla_ash_loop_flag == 0) 
			{
			print("Ending Katla ash eruption simulation.");
			return;
			}
			
		if (timer < 0.0) 
			{
			
			if (rand() > 0.6)
				{
				setprop("/environment/volcanoes/katla/ash-main-alpha", (rand() - 0.5) * 60.0);
				setprop("/environment/volcanoes/katla/ash-main-beta", (rand() - 0.5) * 60.0);
				}
			else
				{	
				setprop("/environment/volcanoes/katla/ash-main-alpha", 0.0);
				setprop("/environment/volcanoes/katla/ash-main-beta", 0.0);					
				}
			timer = 2.0 + 3.0 * rand();
			}
			
		var aircraft_pos = geo.aircraft_position();
		var dist = aircraft_pos.distance_to(katla_pos);
		var turbulence = 25000000.0/(dist * dist);
		if (turbulence > 1.0) {turbulence = 1.0;}
		
		setprop("/environment/volcanoes/turbulence", turbulence);
		
		timer = timer - 0.1;
		
		settimer(func {katla_ash_loop(timer);}, 0.1);
		}
	
	
	katla_state_manager = func {
				
		var state_main = getprop("/environment/volcanoes/katla/main-activity");
		
		if ( (state_main > 0) and (katla_ash_loop_flag == 0))
			{
			print ("Starting Katla ash eruption simulation.");
			katla_ash_loop_flag = 1;
			katla_ash_loop(0.0);
			}
		else if  ((state_main < 1) and (katla_ash_loop_flag == 1)) 
			{
			katla_ash_loop_flag = 0;	
			setprop("/environment/volcanoes/turbulence", 0);
			
			}
		
		
		

		}
		
	# call state manager once to get correct autosaved behavior, otherwise use listener
		
	katla_state_manager();
	setlistener("/environment/volcanoes/katla/main-activity", katla_state_manager);