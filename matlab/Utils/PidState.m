classdef PidState
	% PidState stores previous value to caculate current value 
	properties
		enabled logical	% on/off
		output_1  % previous output value
		output_1m % previous value for slew-rate
		D_1 % previous value of D
		eD_1 % previous value of error from part D
		ref_1 % previous value of ref
		I % Integrator (I in PID)
		time100_1 int32 % previous sample time
		computed % True if controller have been caculated 
		timeout	logical
	end
	methods
		function obj = PidState()
			obj.enabled = false;
			obj.output_1 = 0;
			obj.output_1m = 0;
			obj.D_1 = 0;
			obj.eD_1 = 0;
			obj.ref_1 = 0;
			obj.I = 0;
			obj.time100_1 = 0;
			obj.computed = false;
			obj.timeout = false;
		end 
	end 
end 