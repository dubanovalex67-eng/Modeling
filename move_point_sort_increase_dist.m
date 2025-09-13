function move_point_sort_increase_dist
clc
clear

% Определяем пути к папкам, которые нужно добавить в MATLAB path
pathsToAdd = {
    pwd,  % текущая папка
    'C:\Users\Professional\OneDrive\ドキュメント\MATLAB\Movement_5'  % полный путь к папке проекта
};

for k = 1:numel(pathsToAdd)
    if isfolder(pathsToAdd{k}) && ~contains(path, pathsToAdd{k})
        addpath(pathsToAdd{k});
    end
end

t_end = 30; dt = 0.1; % Время
load('Persuers.mat'); load('Targets.mat')
n1 = length(Pers); n2 = length(Targ);
% Инициализация скоростей для преследователей и целей
V_Pers = zeros(size(Pers));
V_Targ = zeros(size(Targ));
% Задаем начальные скорости для преследователей
for i = 1:n1
    random_multiplier = 5 + 4 * rand(); % rand() дает 0-1, умножаем на 2 и добавляем 4
    V_Pers(i,:) = random_multiplier * Control_Vector_of_Chase(Pers(i,:), Targ(i,:));
end
% Задаем начальные скорости для целей (например, случайные направления)
for i = 1:n2
    V_Targ(i,:) = [randn(), randn()] * 1.5; % Случайная скорость
end
figure

% Настройка видеозаписи
v = VideoWriter('simulation_dist.avi', 'Motion JPEG AVI');
v.FrameRate = 1/dt;
open(v);
pairrow = sort_increase_dist(Pers, Targ)
for t = 0:dt:t_end % рабочий цикл
    % Plot all pursuers and targets
    plot(Pers(:,1), Pers(:,2), 'ro', 'MarkerSize', 5, 'LineWidth', 2);
    grid on; grid minor;
    axis([-150 150 -150 150]);
    hold on
    plot(Targ(:,1), Targ(:,2), 'bo', 'MarkerSize', 5, 'LineWidth', 2);   
    hold off
    drawnow
    % Запись кадра в видео
    frame = getframe(gcf);
    writeVideo(v, frame)
    % Update positions and velocities for each pursuer-target pair
    for i=1:n1
        [Pers(pairrow(i,1),:), Targ(pairrow(i,2),:), V_Pers(pairrow(i,1),:), V_Targ(pairrow(i,2),:)] = ...
            mutual_movement(Pers(pairrow(i,1),:), Targ(pairrow(i,2),:), V_Pers(pairrow(i,1),:), V_Targ(pairrow(i,2),:), dt);
    end
    % Сортировка по расстоянию с использованием sort_increase_dist
    pairrow = sort_increase_dist(Pers, Targ);
    pause(dt);
end

% Завершение видеозаписи
close(v);
end