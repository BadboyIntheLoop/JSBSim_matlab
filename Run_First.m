%% Run 
disp('Run vt2xc01 script');
fprintf('Current directory: %s \n', pwd)
addpath('.\matlab\');
%% Init params to run
% Init States
In.u0 = 1500;
In.v0 = 0;
In.w0 = 0;
In.p0 = 0;
In.q0 = 0;
In.r0 = 0;
In.lat0 = 50.0;
In.long0 = 150.0;
In.h_asl0 = 0;
In.phi0 = 0;
In.theta0 = 0;
In.psi0 = 225.0;
In.init_params = [In.u0 In.v0 In.w0 In.p0 In.q0 In.r0, ...
    In.h_asl0 In.long0 In.lat0 In.phi0 In.theta0 In.psi0];
% Init pilot cmds
In.throt0 = 0;
In.ail0 = 0;
In.elev0 = 0;
In.rud0 = 0;
In.mix0 = 0;
In.runset = 0;
In.flap0 = 0;
In.gear0 = 0;
In.init_pilotCmd = [In.throt0 In.ail0 In.elev0 In.rud0, ...
    In.mix0 In.runset In.flap0 In.gear0];
% Init Winds
In.windNED01 = 0;
In.windNED02 = 0;
In.windNED03 = 0;
In.gustNED01 = 0;
In.gustNED02 = 0;
In.gustNED03 = 0;
In.cosineGust = 0;
In.TurbNED01 = 0;
In.TurbNED02 = 0;
In.TurbNED03 = 0;
In.winds = [In.windNED01 In.windNED02 In.windNED03, ...
            In.gustNED01 In.gustNED02 In.gustNED03 In.cosineGust, ...
            In.TurbNED01 In.TurbNED02 In.TurbNED03];
% Init sampling-time and use_initScript (in JSBsim)
In.dt = 0.01;
In.script_bool = 1; % 0 - using matlab/ 1 - using JSBsim_initScript
%% Sensor Params
% run("./matlab/sensor_param");
% open('simVT2XC01_cruise');

%% Create init xml file
% resetNode = com.mathworks.xml.XMLUtils.createDocument('initialize');
% initCons = resetNode.getDocumentElement;
% initCons.setAttribute('name', "reset00");
% % Add elements
% tagArr = ["ubody" "vbody" "wbody" "latitude" ...
%     "longitude" "altitude" "phi" "theta" "psi"];
% unitArr = ["FT/SEC" "FT/SEC" "FT/SEC" ...
%     "DEG" "DEG" "FT" "DEG" "DEG" "DEG"];
% initValueArr = string([In.u0 In.v0 In.w0 ...
%     In.lat0 In.long0 In.h_asl0 In.phi0 In.theta0 In.psi0]);
% for idx = 1:numel(tagArr)
%     curNode = resetNode.createElement(tagArr(idx));
%     curNode.setAttribute('unit', unitArr(idx));
%     curNode.appendChild(resetNode.createTextNode( initValueArr(idx) ));
%     initCons.appendChild(curNode);
% end
% xmlwrite('./reset00.xml', resetNode);