classdef test < handle
	properties (Access = public)
		mode = PidMode.NORMAL_PID;
        state = PidState();
        control = 0;
        str (2,2) int8;
	end
	methods
        function obj = test(n)
            if nargin > 0
                disp(n);
            end
        end     
        function obj = printMode(obj)
            fprintf('Mode is %d\n', obj.mode);
        end 
        function out = isOne(obj, num)
        	if num == 1
%         		out = true;
                return;
            else 
                fprintf('Not one %f \n', 0.01);
            end
        end
        function y = printStruct(obj)
            obj.str = [3 2; 3 4];
            disp(obj.str);
        end
        function y = printSth(obj, num)
            fprintf('Ohhh %f \n', num);
        end
        function out = createArr(obj, num)
            out(1) = num;
            out(2) = out(1) + 1;
            out(3) = out(2) + 1;
            out  = [out(1); out(2); out(3)];
        end
        function [y1 y2] = incEachVar(obj, delta)
            y1 = 1 + delta;
            y2 = 2 + delta;
        end
    end
end