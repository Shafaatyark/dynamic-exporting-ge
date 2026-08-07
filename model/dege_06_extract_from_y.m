function [L,N,C,Pd,PC,f0,f1,z,xiLH,rho,K,kap0,xic,xix,xim,kapH,kapL,NH,dVL] = dege_06_extract_from_y(y,num_c)


narrays = 10;            %Number of variables that are arrays (one for each country)
arrays = 1:num_c:narrays*num_c;
count=1;
for i=arrays
    arr.(strcat('a',num2str(count))) = exp(y(i:i+num_c-1));
    count = count+1;
end
L=arr.a1; N=arr.a2; C=arr.a3; Pd=arr.a4; PC=arr.a5; f0=arr.a6; f1=arr.a7; z=arr.a8; xiLH=arr.a9; rho=arr.a10;

nmatr = 9;              %Number of variables that are matrices (one for each country)
matr = narrays*num_c+1:num_c^2:narrays*num_c+nmatr*num_c^2;
count=1;
for i=matr
    mat.(strcat('m',num2str(count))) = reshape(exp(y(i:i+num_c^2-1)),num_c,num_c);
    count = count+1;
end
K=mat.m1; kap0=mat.m2; xic=mat.m3; xix=mat.m4; xim=mat.m5; kapH=mat.m6; kapL=mat.m7; NH=mat.m8; dVL=mat.m9;





end
