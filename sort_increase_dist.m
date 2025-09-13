function pairrow = sort_increase_dist(P,T)

n1 = length(P); 
n2 = length(T);
p = 1:n1; t = 1:n2;
[A,B] = meshgrid(p,t);
pairs = [A(:), B(:)];
% Вычисляем расстояния
D = pdist2(P,T);
Dist = reshape(D',[],1);
pairs = [pairs, Dist];

pairs = sortrows(pairs, 3);

prow = pairs(1, :);
pairrow = pairs;

for i = 1 : n1-1 
pairrow(pairrow(:,1) == prow(i,1), :) = [];
pairrow(pairrow(:,2) == prow(i,2), :) = [];
prow = [prow; pairrow(1,:)];
end;

pairrow = prow;


end 
