function assignment = Greedy_Pursuit(pursuers, targets, costMatrix)
% Greedy_Pursuit - Распределение преследователей по целям жадным алгоритмом
% Входные параметры:
%   pursuers - матрица преследователей Nx2 [x1,y1; x2,y2; ...]
%   targets - матрица целей Mx2 [x1,y1; x2,y2; ...]
%   costMatrix - матрица стоимостей NxM, где costMatrix(i,j) - стоимость
%                назначения i-го преследователя на j-ю цель
% Выходные параметры:
%   assignment - вектор длины N, где assignment(i) = j, если i-й преследователь 
%                назначен на j-ю цель (0 - если не назначен)

    [N, dimP] = size(pursuers);
    [M, dimT] = size(targets);
    
    % Проверка размеров
    if dimP ~= 2 || dimT ~= 2
        error('Входные матрицы должны иметь 2 столбца (координаты X,Y)');
    end
    
    if size(costMatrix, 1) ~= N || size(costMatrix, 2) ~= M
        error('Несоответствие размеров матрицы стоимостей. Ожидается %dx%d, получено %dx%d', ...
              N, M, size(costMatrix, 1), size(costMatrix, 2));
    end
    
    % Инициализация вектора назначений
    assignment = zeros(N, 1);
    
    % Флаги использованных преследователей и целей
    usedPursuers = false(N, 1);
    usedTargets = false(M, 1);
    
    % Создаем список всех пар (преследователь, цель, стоимость)
    pairs = [];
    for i = 1:N
        for j = 1:M
            pairs = [pairs; i, j, costMatrix(i, j)];
        end
    end
    
    % Сортируем пары по возрастанию стоимости
    pairs = sortrows(pairs, 3);
    
    % Жадное назначение
    for k = 1:size(pairs, 1)
        i = pairs(k, 1); % преследователь
        j = pairs(k, 2); % цель
        
        % Если преследователь и цель еще не использованы
        if ~usedPursuers(i) && ~usedTargets(j)
            assignment(i) = j;
            usedPursuers(i) = true;
            usedTargets(j) = true;
        end
        
        % Если все преследователи или все цели назначены - выходим
        if all(usedPursuers) || all(usedTargets)
            break;
        end
    end
    
    % Визуализация (опционально)
    if N <= 20 && M <= 20
        visualizeAssignment(pursuers, targets, assignment, costMatrix);
    end
end

function visualizeAssignment(pursuers, targets, assignment, costMatrix)
    figure;
    hold on;
    grid on;
    
    scatter(pursuers(:,1), pursuers(:,2), 100, 'b', 'o', 'filled', 'DisplayName', 'Преследователи');
    scatter(targets(:,1), targets(:,2), 100, 'r', 's', 'filled', 'DisplayName', 'Цели');
    
    for i = 1:length(assignment)
        if assignment(i) > 0
            j = assignment(i);
            plot([pursuers(i,1), targets(j,1)], [pursuers(i,2), targets(j,2)], 'g-', 'LineWidth', 1.5);
            midX = (pursuers(i,1) + targets(j,1)) / 2;
            midY = (pursuers(i,2) + targets(j,2)) / 2;
            text(midX, midY, sprintf('%.1f', costMatrix(i,j)), 'BackgroundColor', 'w', 'FontSize', 8);
        end
    end
    
    for i = 1:size(pursuers,1)
        text(pursuers(i,1), pursuers(i,2), sprintf('P%d', i), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
    end
    
    for j = 1:size(targets,1)
        text(targets(j,1), targets(j,2), sprintf('T%d', j), 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
    end
    
    xlabel('X координата');
    ylabel('Y координата');
    title('Результат жадного распределения');
    legend('Location', 'best');
    axis equal;
    hold off;
end