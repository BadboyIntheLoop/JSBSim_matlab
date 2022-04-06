classdef PidMode < int8
	enumeration 
		SIMPLE_PID (0);
		NORMAL_PID (1);
		STATE_2H (2);
		MULTI_STEP (3);
	end
end