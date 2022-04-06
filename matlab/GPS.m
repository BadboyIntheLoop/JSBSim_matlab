function y = GPS(uu)
%% Inputs & Outputs
%{
Input: 
    truePos (m): True Position in NED frame, PositionInputFormat property is specified as 'Local'
    trueVel (m/s): True Velocity in NED frame, PositionInputFormat property is specified as 'Local'
Ouput:
    pos (geo-deg): Position of the GPS receiver in the geodetic latitude, longitude, and altitude (LLA) coordinate system
    vel (m/s): Velocity of the GPS receiver in the local navigation coordinate system in meters per second
    gSpd (m/s): Magnitude of the horizontal velocity of the GPS receiver in the local navigation coordinate system in meters per second
    course (deg): Direction of the horizontal velocity of the GPS receiver in the local navigation coordinate system in degrees
%}

% Inputs
truePos_n = uu(1);
truePos_e = uu(2);
truePos_d = uu(3);
trueVel_n = uu(4);
trueVel_e = uu(5);
trueVel_d = uu(6);
truePos = [truePos_n truePos_e truePos_d];
trueVel = [trueVel_n trueVel_e trueVel_d];
gps_vt = gpsSensor('ReferenceFrame', 'NED',...
                   'SampleRate', 4,...
                   'ReferenceLocation', [In.lat0 In.long0 In.h_asl0],...
                   'PositionInputFormat', 'Local');
[pos, vel, gSpd, course] = gps_VT(truePos, trueVel);
y = [pos, vel, gSpd, course]';
end