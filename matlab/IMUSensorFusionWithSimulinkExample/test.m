lat = 21.03;
lon = 105.2;
h = 0;
lat0 = 21.0345451;
lon0 = 105.2235231;
h0 = 0;
wgs84 = wgs84Ellipsoid;;
[n, e, d] = geodetic2ned(lat, lon, h, lat0, lon0, h0, wgs84);
ned = [n, e, d];