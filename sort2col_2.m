function pairrow = sort2col_2(P,V_P,T)

n1 = length(P); 
n2 = length(T);

p = 1:n1;
t = 1:n2;
[A,B] = meshgrid(p,t);

pairs = [A(:), B(:)];
% Вычисляем расстояния
D = pdist2(P,T);
Dist = reshape(D',[],1);
pairs = [pairs, Dist];
speed = sqrt(sum(V_P.^2, 2));
%speed(pairs(:,1));
pairs = [pairs, speed(pairs(:,1))];
for i=1:length(pairs)
    if pairs(i,4)==0 
        pairs(i,4)=1;
    end;
  %pairs(i,1) ; speed(pairs(i,1));
  Time(i) = pairs(i,3)/pairs(i,4);
end;
Time';
pairs = [pairs,Time'];
pairs = sortrows(pairs, 5);

prow = pairs(1, :);
pairrow = pairs;

for i = 1 : n1-1 
pairrow(pairrow(:,1) == prow(i,1), :) = [];
pairrow(pairrow(:,2) == prow(i,2), :) = [];
prow = [prow; pairrow(1,:)];
end;

pairrow = prow


end 
