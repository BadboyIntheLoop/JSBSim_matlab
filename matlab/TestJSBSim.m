%% Run 
disp('Run 737 example');
fprintf('Current directory: %s', pwd)
sim('.\matlab\ex737cruise');
%%Clear SF
clear functions;
clear all;
disp('JSBSim S-Function Reset');
