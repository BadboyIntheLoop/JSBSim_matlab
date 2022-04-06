% PID Params
classdef PidParams
    properties
        bank(1,30) = PidBank(); % set 30 param banks for 30 controllers
        maxKas
    end 
    methods 
        function obj = PidParams()
            obj.setDefault();
        end
        function obj = setDefault(obj)
            obj.maxKas = 1;
        end
    end
end