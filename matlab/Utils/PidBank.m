% PID bank
classdef PidBank < handle
    properties
        Kp
        Ti 
        Tt 
        Td 
        N 
        wP
        wD
        wX
        sRef 
        sOut 
        Imin
        Imax
    end
    methods
        function obj = PidBank()
            obj.setDefault();
        end
        function obj = setDefault(obj);
            obj.Kp = 0; obj.Ti = 0; obj.Tt = 0; obj.Td = 0; obj.N = 0;
            obj.wP = 0; obj.wD = 0; obj.sRef = 0; obj.sOut = 0;
            obj.Imin = 0; obj.Imax = 0;
        end
    end
end