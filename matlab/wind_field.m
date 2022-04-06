load wind;
figure(1);
while(1)
    for idx = 1:30
    clf
    X = x(5:10,idx:idx+10,6:10)*50;
    Y = y(5:10,idx:idx+10,6:10)*50;
    Z = z(5:10,idx:idx+10,6:10)*50;
    U = u(5:10,idx:idx+10,6:10)*1000;
    V = v(5:10,idx:idx+10,6:10)*1000;
    W = w(5:10,idx:idx+10,6:10)*1000;
    quiver3(X,Y,Z,U,V,W);
    axis([0, 8000, 0, 2000, -2000, 2000]);
    view(-19, 76);
    pause(0.1);
    end
end
