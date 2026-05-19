function [assignment, totalCost] = hungarian_assignment(costMatrix)
% HUNGARIAN_ASSIGNMENT Solve the assignment problem using the Hungarian (Munkres) algorithm.
%   [assignment, totalCost] = hungarian_assignment(costMatrix)
%   costMatrix must be a nonnegative real matrix (square or rectangular).
%   If rectangular, it is padded with dummy rows/columns.
%   assignment is a column vector of size nRows: assignment(i)=j (or 0 if unassigned)
%   totalCost is the sum of chosen costs.

% Input validation
if ~isnumeric(costMatrix) || ndims(costMatrix) ~= 2
    error('costMatrix must be a 2D numeric matrix.');
end
if any(~isfinite(costMatrix(:)))
    error('costMatrix contains NaN or Inf.');
end

% Make a copy and ensure nonnegative
C = costMatrix;
minVal = min(C(:));
if minVal < 0
    C = C - minVal; % shift to nonnegative
end

[nRows, nCols] = size(C);
N = max(nRows, nCols);
% Pad to square
if nRows < N
    C = [C; zeros(N - nRows, nCols) + max(C(:))];
end
if nCols < N
    C = [C, zeros(size(C,1), N - nCols) + max(C(:))];
end

% Step 1: subtract row minima
C = C - min(C, [], 2);
% Step 2: subtract column minima
C = C - min(C, [], 1);

% Masks and bookkeeping
STAR = 1; PRIME = 2;
mask = zeros(N, N); % 0=none,1=star,2=prime
rowCover = false(N, 1);
colCover = false(1, N);

% Step 3: star zeros greedily (one per row/col)
for i = 1:N
    for j = 1:N
        if C(i,j) == 0 && ~rowCover(i) && ~colCover(j)
            mask(i,j) = STAR;
            rowCover(i) = true;
            colCover(j) = true;
        end
    end
end
rowCover(:) = false; colCover(:) = false;
% Cover columns with starred zeros
for j = 1:N
    if any(mask(:,j) == STAR)
        colCover(j) = true;
    end
end

% Main loop
while true
    if sum(colCover) == N
        break; % optimal starred zeros found
    end
    [r, c] = findZero(C, rowCover, colCover);
    while isempty(r)
        % Step 5: adjust matrix to create more zeros
        m = min(C(~rowCover, ~colCover), [], 'all');
        C(~rowCover, ~colCover) = C(~rowCover, ~colCover) - m;
        C(rowCover, colCover) = C(rowCover, colCover) + m;
        [r, c] = findZero(C, rowCover, colCover);
    end
    % Prime the found zero
    mask(r, c) = PRIME;
    % If there is a starred zero in this row, cover the row and uncover that column
    starCol = find(mask(r, :) == STAR, 1);
    if ~isempty(starCol)
        rowCover(r) = true;
        colCover(starCol) = false;
    else
        % Step 4: augment path starting at (r,c)
        mask = augmentPath(mask, r, c, STAR, PRIME);
        % Reset covers and remove primes
        rowCover(:) = false;
        colCover(:) = false;
        mask(mask == PRIME) = 0;
        % Cover columns with starred zeros again
        for j = 1:N
            if any(mask(:,j) == STAR)
                colCover(j) = true;
            end
        end
    end
end

% Build assignment from STARs
assignment = zeros(nRows, 1);
for i = 1:min(nRows, N)
    j = find(mask(i, :) == STAR, 1);
    if ~isempty(j) && j <= nCols
        assignment(i) = j;
    else
        assignment(i) = 0;
    end
end

% Compute total cost
totalCost = 0;
for i = 1:nRows
    j = assignment(i);
    if j > 0 && j <= nCols
        totalCost = totalCost + costMatrix(i, j);
    end
end

end

function [r, c] = findZero(C, rowCover, colCover)
% Find the first uncovered zero
r = []; c = [];
for i = 1:size(C,1)
    if rowCover(i), continue; end
    for j = 1:size(C,2)
        if ~colCover(j) && C(i,j) == 0
            r = i; c = j; return;
        end
    end
end
end

function mask = augmentPath(mask, r, c, STAR, PRIME)
% Build alternating path of primed and starred zeros starting at (r,c) where (r,c) is primed
path = [r, c];
while true
    % Find star in the column of the last element
    rStar = find(mask(:, path(end,2)) == STAR, 1);
    if isempty(rStar)
        break; % stop when no STAR in this column
    end
    path(end+1, :) = [rStar, path(end,2)]; %#ok<AGROW>
    % Find prime in the row of the last element
    cPrime = find(mask(path(end,1), :) == PRIME, 1);
    path(end+1, :) = [path(end,1), cPrime]; %#ok<AGROW>
end

% Flip stars/primes along the path
for k = 1:size(path,1)
    i = path(k,1); j = path(k,2);
    if mask(i,j) == STAR
        mask(i,j) = 0;
    else
        mask(i,j) = STAR;
    end
end
end 