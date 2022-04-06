classdef ControllerProperties
	properties 
		enable logical;
		minValue double;
		maxValue double;
		marginLow double;
		marginHigh double;
		invMargins logical;
		num_bank int8;
	end
	methods
		function obj = ControllerProperties()
			obj.reset();
		end
		function obj = reset(obj)
			obj.enable = false;
			obj.minValue = 0;
			obj.maxValue = 0;
			obj.marginLow = 0;
			obj.marginHigh = 0;
			obj.invMargins = false;
			obj.num_bank = 0;
		end
		function obj = setControllerProperties(obj, minV, maxV, bankV)
			obj.minValue = minV;
			obj.maxValue = maxV;
			obj.num_bank = bankV;
		end
	end
end
