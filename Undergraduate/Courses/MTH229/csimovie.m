% M=csimovie(x,y,z,a,b,N,AZ,EL,size,vel,acc)
% returns movie Matrix M
% where x=x(t), y=y(t), z=z(t) are symbolic
% a=initial t value, b= final t value
% N=number of frames
% El = elevation of view  Az = azimuth of view
% size = size of grid, any positive real number
% vel = constant to multiply velocity vector by
% acc = constant to multiply acceleration vector by

function M=csimovie(x,y,z,a,b,N,EL,AZ,size,vel,acc)
clf
%x=sym(x);
%y=sym(y);
%z=sym(z);
N=10*N;
%maple
syms f t I J K
f=x*I+y*J+z*K;
xp=diff(x,t);
yp=diff(y,t);
zp=diff(z,t);
xpp=diff(xp,t);
ypp=diff(yp,t);
zpp=diff(zp,t);
t=linspace(a,b,N);
xt=eval(vectorize(x));
yt=eval(vectorize(y));
zt=eval(vectorize(z));
xtp=eval(vectorize(xp));
ytp=eval(vectorize(yp));
ztp=eval(vectorize(zp));
xtpp=eval(vectorize(xpp));
ytpp=eval(vectorize(ypp));
ztpp=eval(vectorize(zpp));
if xt==0 & length(xt)==1 xt=zeros(1,N); end
if yt==0 & length(yt)==1 yt=zeros(1,N); end
if zt==0 & length(zt)==1 zt=zeros(1,N); end
if xtp==0 & length(xtp)==1 xtp=zeros(1,N); end
if ytp==0 & length(ytp)==1 ytp=zeros(1,N); end
if ztp==0 & length(ztp)==1 ztp=zeros(1,N); end
if xtpp==0 & length(xtpp)==1 xtpp=zeros(1,N); end
if ytpp==0 & length(ytpp)==1 ytpp=zeros(1,N); end
if ztpp==0 & length(ztpp)==1 ztpp=zeros(1,N); end
if xt~=0 & length(xt)==1 xt=xt*ones(1,N); end
if yt~=0 & length(yt)==1 yt=yt*ones(1,N); end
if zt~=0 & length(zt)==1 zt=zt*ones(1,N); end
if xtp~=0 & length(xtp)==1 xtp=xtp*ones(1,N); end
if ytp~=0 & length(ytp)==1 ytp=ytp*ones(1,N); end
if ztp~=0 & length(ztp)==1 ztp=ztp*ones(1,N); end
if xtpp~=0 & length(xtpp)==1 xtpp=xtpp*ones(1,N); end
if ytpp~=0 & length(ytpp)==1 ytpp=ytpp*ones(1,N); end
if ztpp~=0 & length(ztpp)==1 ztpp=ztpp*ones(1,N); end


r=[xt;yt;zt];
v=[xtp*vel;ytp*vel;ztp*vel];
a=[xtpp*acc;ytpp*acc;ztpp*acc];
plot3(r(1,:),r(2,:),r(3,:))
AX=axis*size;
M=moviein(N/10);
for q=1:N/10
   hold off, plot3(r(1,:),r(2,:),r(3,:))
view(AZ,EL)
grid
xlabel('x'),ylabel('y'),zlabel('z')
hold on
n=10*q;
x0=r(1,n);y0=r(2,n);z0=r(3,n);
plot3(x0,y0,z0,'*r')
plot3([0 r(1,n)],[0 r(2,n)],[0 r(3,n)],'r')
plot3(x0+[0 v(1,n)],y0+[0 v(2,n)],z0+[0 v(3,n)],'g')
plot3(x0+[0 a(1,n)],y0+[0 a(2,n)],z0+[0 a(3,n)],'m')
axis('ij')
axis('equal')
axis('square')
axis(AX)
title(char(f))
M(:,q)=getframe;
end
movie(M,-2)
movie(M,3,18)
% written by Lewis Carbonaro
% The College of Staten Island