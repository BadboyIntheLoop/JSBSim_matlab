function out = conver2draw(uu, In)
%{
This function to convert states from JSBsim to states (in draw function)
%}
persistent lla0

u = uu(1);
v = uu(2);
w = uu(3);
p = uu(4);
q = uu(5);
r = uu(6);
altAsl = uu(7);
long = uu(8);
lat = uu(9);
phi = uu(10);
theta = uu(11);
psi = uu(12);

%% Convert Lat-Long-Altitude to North-East-Down can be use:
% lla2ned: convert normally, down = -h_asl;
% geodetic2ned: convert with WGS84 geodetic, so down not equal to -h_asl
% First, Initialize the position of start point;
lla0 = [In.lat0 In.long0 In.h_asl0];
lla = [lat long altAsl];
pNED = lla2ned(lla, lla0, 'flat');
pn = pNED(1); pe = pNED(2); pd = pNED(3);

out = [pn; pe; pd; u; v; w; ...
    phi; theta; psi; p; q; r];

end