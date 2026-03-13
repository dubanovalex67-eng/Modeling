%% Настройка параметров
clear; clc; close all;

% Параметры окна
x_limits = [-500, 500];
y_limits = [-500, 500];

% Параметры анимации
total_time = 50; % секунд
fps = 20; % кадров в секунду
frames = total_time * fps; % всего кадров

% Параметры целей
initial_targets = 15; % начальное количество целей
target_size = 5; % размер маркера цели

% Параметры генерации новых целей
new_target_probability = 0.02; % вероятность появления новой цели на кадр (2%)
max_targets = 100; % максимальное количество целей

% Параметры треков
track_opacity = 0.3; % прозрачность треков (от 0 до 1)
% Толщина треков в зоне радара и вне ее
linewidth_in_radar = 2.5; % толщина трека в зоне радара
linewidth_out_radar = 1.5; % толщина трека вне зоны радара

% Цвета треков
red_color = [1, 0, 0]; % Красный цвет для частей треков вне зоны радара
purple_color = [0.5, 0, 0.5]; % Фиолетовый цвет для частей треков в зоне радара

% Цвета маркеров целей
marker_red_color = [1, 0, 0]; % Красный цвет маркера цели
marker_purple_color = [0.5, 0, 0.5]; % Фиолетовый цвет маркера цели в зоне радара

% Параметры для движения (преследование)
pursuit_enabled = true;        % включить жадное преследование жертв
pursuit_turning_rate = 0.2;    % скорость поворота к цели (0..1)
kill_distance = 8;             % расстояние, при котором цель уничтожает жертву

% Параметры для случайных траекторий (если pursuit_enabled = false)
velocity_change_probability = 0.05; % вероятность изменения скорости на каждом кадре
max_speed_change = 10; % максимальное изменение скорости
min_speed = 5; % минимальная скорость целей
max_speed = 50; % максимальная скорость целей

% ПАРАМЕТРЫ ЗАЩИТНИКОВ
defenders_per_radar = 4;       % количество защитников на радар
defender_color = [0, 0, 1];    % синий цвет
defender_size = 6;             % размер маркера защитника
defender_speed = 30;           % скорость защитников (постоянная)
defender_turning_rate = 0.3;   % скорость поворота к цели

%% ПАРАМЕТРЫ РАДАРОВ
radar_positions = [-300, 0; 300, 200]; % координаты радаров [x1, y1; x2, y2]
radar_radius = 100; % радиус действия радара
num_radars = size(radar_positions, 1); % количество радаров
radar_color = [0, 0.5, 1]; % голубой цвет для радаров
radar_opacity = 0.2; % прозрачность зоны покрытия радара

% Функция для проверки нахождения точки в ОБЪЕДИНЕННОЙ зоне радаров
is_in_radar_zone = @(x, y) any(sqrt((x - radar_positions(:,1)).^2 + (y - radar_positions(:,2)).^2) <= radar_radius);

%% ПАРАМЕТРЫ ЖЕРТВ
num_victims = 50; % начальное количество жертв
victim_color = [0, 1, 0]; % зеленый цвет
victim_edge_color = [0, 0, 0]; % черный цвет окаймления
victim_size = 6; % размер маркера жертвы

% Случайные позиции жертв
victim_x = rand(num_victims, 1) * (x_limits(2) - x_limits(1)) + x_limits(1);
victim_y = rand(num_victims, 1) * (y_limits(2) - y_limits(1)) + y_limits(1);

% Создание структуры для сохранения всех данных треков
all_tracks_data = struct();
all_tracks_data.track_count = 0;
all_tracks_data.tracks = struct('id', {}, 'positions', {}, 'speeds', {}, ...
                               'creation_time', {}, 'total_points', {}, ...
                               'in_radar_segments', {});

% Случайные начальные положения целей
x_pos = rand(initial_targets, 1) * (x_limits(2) - x_limits(1)) + x_limits(1);
y_pos = rand(initial_targets, 1) * (y_limits(2) - y_limits(1)) + y_limits(1);

% Определение начальных цветов маркеров целей
marker_colors = repmat(marker_red_color, initial_targets, 1);
for i = 1:initial_targets
    if is_in_radar_zone(x_pos(i), y_pos(i))
        marker_colors(i, :) = marker_purple_color;
    end
end

% Случайные скорости (с ограничениями по скорости)
x_speed = (rand(initial_targets, 1) - 0.5) * 2 * max_speed;
y_speed = (rand(initial_targets, 1) - 0.5) * 2 * max_speed;

% Корректировка скоростей, чтобы они не были слишком маленькими
for i = 1:initial_targets
    current_speed = sqrt(x_speed(i)^2 + y_speed(i)^2);
    if current_speed < min_speed
        % Увеличиваем скорость до минимальной
        scale_factor = min_speed / current_speed;
        x_speed(i) = x_speed(i) * scale_factor;
        y_speed(i) = y_speed(i) * scale_factor;
    elseif current_speed > max_speed
        % Уменьшаем скорость до максимальной
        scale_factor = max_speed / current_speed;
        x_speed(i) = x_speed(i) * scale_factor;
        y_speed(i) = y_speed(i) * scale_factor;
    end
end

% Инициализация истории позиций для треков
full_track_history_x = cell(initial_targets, 1);
full_track_history_y = cell(initial_targets, 1);
full_track_time = cell(initial_targets, 1); % Время каждой точки

% Инициализация сегментов треков
track_segments = cell(initial_targets, 1); % Сегменты треков для визуализации
current_segment_start = ones(initial_targets, 1); % Начало текущего сегмента
in_radar_status = false(initial_targets, 1); % Текущий статус (в зоне радара или нет)

% Инициализация массивов для ID целей
target_ids = (1:initial_targets)'; % Уникальные ID для каждой цели

for i = 1:initial_targets
    % Инициализация полной истории для визуализации
    full_track_history_x{i} = x_pos(i);
    full_track_history_y{i} = y_pos(i);
    full_track_time{i} = 0; % Время создания цели
    
    % Инициализация статуса
    in_radar_status(i) = is_in_radar_zone(x_pos(i), y_pos(i));
    
    % Инициализация сегментов трека
    track_segments{i} = struct();
    track_segments{i}.x = {full_track_history_x{i}};
    track_segments{i}.y = {full_track_history_y{i}};
    track_segments{i}.color = {in_radar_status(i) * purple_color + ~in_radar_status(i) * red_color};
    track_segments{i}.linewidth = {in_radar_status(i) * linewidth_in_radar + ~in_radar_status(i) * linewidth_out_radar};
    
    % Заполняем структуру данных для каждой начальной цели
    all_tracks_data.tracks(i).id = i;
    all_tracks_data.tracks(i).positions = [x_pos(i), y_pos(i)];
    all_tracks_data.tracks(i).speeds = [x_speed(i), y_speed(i)];
    all_tracks_data.tracks(i).creation_time = 0;
    all_tracks_data.tracks(i).total_points = 1;
    all_tracks_data.tracks(i).in_radar_segments = []; % Будем заполнять позже
end

all_tracks_data.track_count = initial_targets;

% --- ИНИЦИАЛИЗАЦИЯ ЗАЩИТНИКОВ ---
% Для каждого радара создаём defenders_per_radar защитников со случайными позициями внутри круга
total_defenders = num_radars * defenders_per_radar;
defender_x = zeros(total_defenders, 1);
defender_y = zeros(total_defenders, 1);
defender_vx = zeros(total_defenders, 1);
defender_vy = zeros(total_defenders, 1);
defender_radar_idx = zeros(total_defenders, 1); % индекс радара, к которому привязан защитник (только для инициализации)

for r = 1:num_radars
    cx = radar_positions(r, 1);
    cy = radar_positions(r, 2);
    for k = 1:defenders_per_radar
        idx = (r-1)*defenders_per_radar + k;
        % случайная точка внутри круга (равномерно по площади)
        rho = sqrt(rand()) * radar_radius;
        theta = 2*pi*rand();
        defender_x(idx) = cx + rho * cos(theta);
        defender_y(idx) = cy + rho * sin(theta);
        % начальная скорость - нулевая (стоят на месте)
        defender_vx(idx) = 0;
        defender_vy(idx) = 0;
        defender_radar_idx(idx) = r;
    end
end

%% Создание графического окна
fig = figure('Position', [100, 100, 800, 800], ...
             'Name', 'Анимация целей со случайными траекториями и общими радарами', ...
             'NumberTitle', 'off', ...
             'MenuBar', 'figure'); % Включаем стандартное меню

hold on;
grid on;
box on;

% Настройка осей
xlim(x_limits);
ylim(y_limits);
xlabel('X координата');
ylabel('Y координата');
title('Анимация движения целей со случайными траекториями (50 секунд)', 'FontSize', 14);

%% ДОБАВЛЕНИЕ КНОПОК В МЕНЮ
% Создаем меню РАДАРЫ (бывший Desktop)
radarMenu = uimenu('Label', 'РАДАРЫ');

% Добавляем кнопку "Начальное состояние"
uimenu(radarMenu, 'Label', 'Начальное состояние', ...
       'Callback', @resetToInitialState);

% Добавляем кнопку "Запустить анимацию"
uimenu(radarMenu, 'Label', 'Запустить анимацию', ...
       'Callback', @startAnimation);

% Добавляем кнопку "Добавить цель"
uimenu(radarMenu, 'Label', 'Добавить цель', ...
       'Callback', @addTargetViaMenu);

% Добавляем кнопку "Добавить жертву"
uimenu(radarMenu, 'Label', 'Добавить жертву', ...
       'Callback', @addVictimViaMenu);

% Добавляем кнопку "Вставить радар"
uimenu(radarMenu, 'Label', 'Вставить радар', ...
       'Callback', @addRadarViaMenu);

% Добавляем кнопку "Изменить радиус радара"
uimenu(radarMenu, 'Label', 'Изменить радиус радара', ...
       'Callback', @changeRadarRadius);

% Добавляем разделитель
uimenu(radarMenu, 'Label', '', 'Separator', 'on');

% Добавляем кнопку "Пауза"
pauseMenu = uimenu(radarMenu, 'Label', 'Пауза', ...
                   'Callback', @pauseAnimation, ...
                   'Tag', 'pauseMenu');

% Добавляем кнопку "Продолжить"
resumeMenu = uimenu(radarMenu, 'Label', 'Продолжить', ...
                    'Callback', @resumeAnimation, ...
                    'Tag', 'resumeMenu', ...
                    'Enable', 'off');

%% ОТОБРАЖЕНИЕ ЖЕРТВ
victims = gobjects(num_victims, 1);
for i = 1:num_victims
    victims(i) = scatter(victim_x(i), victim_y(i), victim_size^2, ...
                        victim_color, 'filled', ...
                        'MarkerEdgeColor', victim_edge_color, ...
                        'LineWidth', 1.5);
end

%% ВЫЗОВ ФУНКЦИИ ДЛЯ ОТОБРАЖЕНИЯ РАДАРОВ
% Вызываем функцию для отображения начальных радаров
radar_objects = createRadarObjects(radar_positions, radar_radius, radar_color, radar_opacity);

% Получаем графические объекты из структуры
radar_circles = radar_objects.circles;
radar_centers = radar_objects.centers;

% Создание графических объектов для сегментов треков
track_segment_handles = cell(initial_targets, 1);
for i = 1:initial_targets
    track_segment_handles{i} = gobjects(0);
    % Создаем первый сегмент
    if ~isempty(track_segments{i}.x{1})
        h = plot(track_segments{i}.x{1}, track_segments{i}.y{1}, ...
                 'Color', [track_segments{i}.color{1}, track_opacity], ...
                 'LineWidth', track_segments{i}.linewidth{1});
        track_segment_handles{i} = [track_segment_handles{i}, h];
    end
end

% Создание графических объектов для целей (точек)
targets = gobjects(initial_targets, 1);
for i = 1:initial_targets
    targets(i) = scatter(x_pos(i), y_pos(i), target_size^2, ...
                         marker_colors(i, :), 'filled', ...
                         'MarkerEdgeColor', 'k', ...
                         'LineWidth', 1.5);
end

% Создание графических объектов для защитников
defenders = gobjects(total_defenders, 1);
for i = 1:total_defenders
    defenders(i) = scatter(defender_x(i), defender_y(i), defender_size^2, ...
                           defender_color, 'filled', ...
                           'MarkerEdgeColor', 'k', ...
                           'LineWidth', 1);
end

% Текст с временем и количеством целей
time_text = text(x_limits(1)+50, y_limits(2)-50, ...
                 sprintf('Время: %.1f сек | Целей: %d', 0, initial_targets), ...
                 'FontSize', 12, 'FontWeight', 'bold');

% Текст с количеством целей в зоне радара
radar_targets_text = text(x_limits(1)+50, y_limits(2)-80, ...
                         sprintf('Целей в зоне радара: 0'), ...
                         'FontSize', 12, 'FontWeight', 'bold', ...
                         'Color', purple_color);

% Текст с количеством жертв
victims_text = text(x_limits(1)+50, y_limits(2)-110, ...
                   sprintf('Жертв: %d', num_victims), ...
                   'FontSize', 12, 'FontWeight', 'bold', ...
                   'Color', victim_color);

% Инструкция по добавлению жертв и целей
instruction_text = text(x_limits(2)-200, y_limits(2)-50, ...
                       {'Для добавления цели используйте меню "РАДАРЫ" -> "Добавить цель"', ...
                        'Для добавления жертвы используйте меню "РАДАРЫ" -> "Добавить жертву"', ...
                        'Для добавления радара используйте меню "РАДАРЫ" -> "Вставить радар"', ...
                        'Для изменения радиуса используйте меню "РАДАРЫ" -> "Изменить радиус радара"'}, ...
                       'FontSize', 10, 'FontWeight', 'bold', ...
                       'HorizontalAlignment', 'right', ...
                       'Color', [0.3, 0.3, 0.3], ...
                       'BackgroundColor', [1, 1, 0.8], ...
                       'EdgeColor', [0.5, 0.5, 0.5]);

%% Определение глобальных переменных для доступа из функций
global global_victim_x global_victim_y global_num_victims global_victims
global global_victims_text global_x_limits global_y_limits
global global_victim_size global_victim_color global_victim_edge_color
global isAnimationRunning isAnimationPaused
global global_all_tracks_data
global global_fig
global global_x_pos global_y_pos global_x_speed global_y_speed global_targets
global global_marker_colors global_target_ids global_full_track_history_x
global global_full_track_history_y global_full_track_time global_in_radar_status
global global_track_segments global_track_segment_handles
global global_time_text global_radar_targets_text
global global_min_speed global_max_speed global_marker_red_color global_marker_purple_color
global global_linewidth_in_radar global_linewidth_out_radar global_purple_color global_red_color
global global_track_opacity global_target_size global_radar_positions global_radar_radius
global global_max_targets global_num_radars global_radar_color global_radar_opacity
global global_radar_circles global_radar_centers
global global_isRebuilding
global global_pursuit_enabled global_pursuit_turning_rate global_kill_distance
% Новые переменные для защитников
global global_defender_x global_defender_y global_defender_vx global_defender_vy
global global_defenders global_defender_radar_idx global_defenders_per_radar
global global_defender_speed global_defender_turning_rate global_defender_color global_defender_size

% Инициализация флагов анимации
isAnimationRunning = false;
isAnimationPaused = false;
global_isRebuilding = false;

% Копируем значения в глобальные переменные
global_victim_x = victim_x;
global_victim_y = victim_y;
global_num_victims = num_victims;
global_victims = victims;
global_victims_text = victims_text;
global_x_limits = x_limits;
global_y_limits = y_limits;
global_victim_size = victim_size;
global_victim_color = victim_color;
global_victim_edge_color = victim_edge_color;
global_all_tracks_data = all_tracks_data;
global_fig = fig;
global_x_pos = x_pos;
global_y_pos = y_pos;
global_x_speed = x_speed;
global_y_speed = y_speed;
global_targets = targets;
global_marker_colors = marker_colors;
global_target_ids = target_ids;
global_full_track_history_x = full_track_history_x;
global_full_track_history_y = full_track_history_y;
global_full_track_time = full_track_time;
global_in_radar_status = in_radar_status;
global_track_segments = track_segments;
global_track_segment_handles = track_segment_handles;
global_time_text = time_text;
global_radar_targets_text = radar_targets_text;
global_min_speed = min_speed;
global_max_speed = max_speed;
global_marker_red_color = marker_red_color;
global_marker_purple_color = marker_purple_color;
global_linewidth_in_radar = linewidth_in_radar;
global_linewidth_out_radar = linewidth_out_radar;
global_purple_color = purple_color;
global_red_color = red_color;
global_track_opacity = track_opacity;
global_target_size = target_size;
global_radar_positions = radar_positions;
global_radar_radius = radar_radius;
global_max_targets = max_targets;
global_num_radars = num_radars;
global_radar_color = radar_color;
global_radar_opacity = radar_opacity;
global_radar_circles = radar_circles;
global_radar_centers = radar_centers;
global_pursuit_enabled = pursuit_enabled;
global_pursuit_turning_rate = pursuit_turning_rate;
global_kill_distance = kill_distance;
% Защитники
global_defender_x = defender_x;
global_defender_y = defender_y;
global_defender_vx = defender_vx;
global_defender_vy = defender_vy;
global_defenders = defenders;
global_defender_radar_idx = defender_radar_idx;
global_defenders_per_radar = defenders_per_radar;
global_defender_speed = defender_speed;
global_defender_turning_rate = defender_turning_rate;
global_defender_color = defender_color;
global_defender_size = defender_size;

%% ФУНКЦИИ ДЛЯ УПРАВЛЕНИЯ АНИМАЦИЕЙ
function resetToInitialState(~, ~)
    global isAnimationRunning
    isAnimationRunning = false;
    close(gcf);
    evalin('base', 'run(''main_radar_victim_scene.m'')');
end

function startAnimation(~, ~)
    global isAnimationRunning isAnimationPaused
    evalin('base', 'frames = total_time * fps;');
    
    frames = evalin('base', 'frames');
    fps_val = evalin('base', 'fps');
    x_limits = evalin('base', 'x_limits');
    y_limits = evalin('base', 'y_limits');
    velocity_change_probability = evalin('base', 'velocity_change_probability');
    max_speed_change = evalin('base', 'max_speed_change');
    min_speed = evalin('base', 'min_speed');
    max_speed = evalin('base', 'max_speed');
    new_target_probability = evalin('base', 'new_target_probability');
    max_targets = evalin('base', 'max_targets');
    linewidth_in_radar = evalin('base', 'linewidth_in_radar');
    linewidth_out_radar = evalin('base', 'linewidth_out_radar');
    purple_color = evalin('base', 'purple_color');
    red_color = evalin('base', 'red_color');
    track_opacity = evalin('base', 'track_opacity');
    marker_purple_color = evalin('base', 'marker_purple_color');
    marker_red_color = evalin('base', 'marker_red_color');
    radar_positions = evalin('base', 'radar_positions');
    radar_radius = evalin('base', 'radar_radius');
    target_size = evalin('base', 'target_size');
    num_radars = evalin('base', 'num_radars');
    total_time = evalin('base', 'total_time');
    pursuit_enabled = evalin('base', 'pursuit_enabled');
    pursuit_turning_rate = evalin('base', 'pursuit_turning_rate');
    kill_distance = evalin('base', 'kill_distance');
    % параметры защитников
    defender_speed = evalin('base', 'defender_speed');
    defender_turning_rate = evalin('base', 'defender_turning_rate');
    
    if ~isAnimationRunning
        isAnimationRunning = true;
        isAnimationPaused = false;
        set(findobj('Tag', 'pauseMenu'), 'Enable', 'on');
        set(findobj('Tag', 'resumeMenu'), 'Enable', 'off');
        runAnimation(frames, fps_val, x_limits, y_limits, velocity_change_probability, ...
                    max_speed_change, min_speed, max_speed, new_target_probability, ...
                    max_targets, linewidth_in_radar, linewidth_out_radar, purple_color, ...
                    red_color, track_opacity, marker_purple_color, marker_red_color, ...
                    radar_positions, radar_radius, target_size, num_radars, total_time, ...
                    pursuit_enabled, pursuit_turning_rate, kill_distance, ...
                    defender_speed, defender_turning_rate);
    end
end

function pauseAnimation(~, ~)
    global isAnimationPaused
    if ~isAnimationPaused
        isAnimationPaused = true;
        set(findobj('Tag', 'pauseMenu'), 'Enable', 'off');
        set(findobj('Tag', 'resumeMenu'), 'Enable', 'on');
        fprintf('Анимация поставлена на паузу\n');
    end
end

function resumeAnimation(~, ~)
    global isAnimationPaused
    if isAnimationPaused
        isAnimationPaused = false;
        set(findobj('Tag', 'pauseMenu'), 'Enable', 'on');
        set(findobj('Tag', 'resumeMenu'), 'Enable', 'off');
        fprintf('Анимация продолжена\n');
    end
end

function addTargetViaMenu(~, ~)
    fprintf('Режим добавления цели активирован. Щелкните левой кнопкой мыши на графике.\n');
    global global_fig
    oldCallback = get(global_fig, 'WindowButtonDownFcn');
    set(global_fig, 'WindowButtonDownFcn', @addTargetOnClick);
    
    function addTargetOnClick(~, ~)
        point = get(gca, 'CurrentPoint');
        x = point(1,1);
        y = point(1,2);
        global global_x_limits global_y_limits
        if x < global_x_limits(1) || x > global_x_limits(2) || ...
           y < global_y_limits(1) || y > global_y_limits(2)
            fprintf('Клик вне графика. Попробуйте снова.\n');
            return;
        end
        addTargetAtPoint(x, y);
        set(global_fig, 'WindowButtonDownFcn', oldCallback);
        fprintf('Режим добавления цели завершен.\n');
    end
end

function addTargetAtPoint(x, y)
    global global_x_pos global_y_pos global_x_speed global_y_speed
    global global_targets global_marker_colors global_target_ids
    global global_full_track_history_x global_full_track_history_y
    global global_full_track_time global_in_radar_status
    global global_track_segments global_track_segment_handles
    global global_all_tracks_data global_time_text global_radar_targets_text
    global global_min_speed global_max_speed global_marker_red_color global_marker_purple_color
    global global_linewidth_in_radar global_linewidth_out_radar global_purple_color global_red_color
    global global_track_opacity global_target_size global_radar_positions global_radar_radius
    global global_max_targets
    
    if length(global_targets) >= global_max_targets
        fprintf('Достигнуто максимальное количество целей (%d).\n', global_max_targets);
        return;
    end
    
    current_in_radar = any(sqrt((x - global_radar_positions(:,1)).^2 + (y - global_radar_positions(:,2)).^2) <= global_radar_radius);
    
    if current_in_radar
        new_marker_color = global_marker_purple_color;
    else
        new_marker_color = global_marker_red_color;
    end
    
    new_x_speed = (rand() - 0.5) * 2 * global_max_speed;
    new_y_speed = (rand() - 0.5) * 2 * global_max_speed;
    current_speed = sqrt(new_x_speed^2 + new_y_speed^2);
    if current_speed < global_min_speed && current_speed > 0
        scale_factor = global_min_speed / current_speed;
        new_x_speed = new_x_speed * scale_factor;
        new_y_speed = new_y_speed * scale_factor;
    elseif current_speed > global_max_speed
        scale_factor = global_max_speed / current_speed;
        new_x_speed = new_x_speed * scale_factor;
        new_y_speed = new_y_speed * scale_factor;
    end
    
    global_x_pos = [global_x_pos; x];
    global_y_pos = [global_y_pos; y];
    global_x_speed = [global_x_speed; new_x_speed];
    global_y_speed = [global_y_speed; new_y_speed];
    global_marker_colors = [global_marker_colors; new_marker_color];
    
    % Исправление: корректное вычисление нового ID, если массив пуст
    if isempty(global_target_ids)
        new_target_id = 1;
    else
        new_target_id = max(global_target_ids) + 1;
    end
    global_target_ids = [global_target_ids; new_target_id];
    
    new_track_idx = length(global_targets) + 1;
    global_full_track_history_x{new_track_idx} = x;
    global_full_track_history_y{new_track_idx} = y;
    global_full_track_time{new_track_idx} = 0;
    global_in_radar_status(new_track_idx) = current_in_radar;
    global_track_segments{new_track_idx} = struct();
    global_track_segments{new_track_idx}.x = {global_full_track_history_x{new_track_idx}};
    global_track_segments{new_track_idx}.y = {global_full_track_history_y{new_track_idx}};
    new_segment_color = current_in_radar * global_purple_color + ~current_in_radar * global_red_color;
    new_linewidth = current_in_radar * global_linewidth_in_radar + ~current_in_radar * global_linewidth_out_radar;
    global_track_segments{new_track_idx}.color = {new_segment_color};
    global_track_segments{new_track_idx}.linewidth = {new_linewidth};
    global_track_segment_handles{new_track_idx} = gobjects(0);
    h = plot(global_track_segments{new_track_idx}.x{1}, global_track_segments{new_track_idx}.y{1}, ...
             'Color', [new_segment_color, global_track_opacity], ...
             'LineWidth', new_linewidth);
    global_track_segment_handles{new_track_idx} = [global_track_segment_handles{new_track_idx}, h];
    
    new_target = scatter(x, y, global_target_size^2, new_marker_color, 'filled', ...
                        'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    global_targets = [global_targets; new_target];
    
    global_all_tracks_data.track_count = global_all_tracks_data.track_count + 1;
    global_all_tracks_data.tracks(new_track_idx).id = new_target_id;
    global_all_tracks_data.tracks(new_track_idx).positions = [x, y];
    global_all_tracks_data.tracks(new_track_idx).speeds = [new_x_speed, new_y_speed];
    global_all_tracks_data.tracks(new_track_idx).creation_time = 0;
    global_all_tracks_data.tracks(new_track_idx).total_points = 1;
    global_all_tracks_data.tracks(new_track_idx).in_radar_segments = [];
    
    global_time_text.String = sprintf('Время: %.1f сек | Целей: %d', 0, length(global_targets));
    current_targets_in_radar = sum(global_in_radar_status);
    global_radar_targets_text.String = sprintf('Целей в зоне радара: %d', current_targets_in_radar);
    
    fprintf('Добавлена новая цель ID=%d в точке (%.1f, %.1f). Всего целей: %d\n', ...
            new_target_id, x, y, length(global_targets));
end

function addVictimViaMenu(~, ~)
    fprintf('Режим добавления жертвы активирован. Щелкните левой кнопкой мыши на графике.\n');
    global global_fig
    oldCallback = get(global_fig, 'WindowButtonDownFcn');
    set(global_fig, 'WindowButtonDownFcn', @addVictimOnClick);
    
    function addVictimOnClick(~, ~)
        point = get(gca, 'CurrentPoint');
        x = point(1,1);
        y = point(1,2);
        global global_x_limits global_y_limits
        if x < global_x_limits(1) || x > global_x_limits(2) || ...
           y < global_y_limits(1) || y > global_y_limits(2)
            fprintf('Клик вне графика. Попробуйте снова.\n');
            return;
        end
        addVictimAtPoint(x, y);
        set(global_fig, 'WindowButtonDownFcn', oldCallback);
        fprintf('Режим добавления жертвы завершен.\n');
    end
end

function addVictimAtPoint(x, y)
    global global_victim_x global_victim_y global_num_victims global_victims
    global global_victims_text global_x_limits global_y_limits
    global global_victim_size global_victim_color global_victim_edge_color
    global global_fig
    
    global_num_victims = global_num_victims + 1;
    global_victim_x = [global_victim_x; x];
    global_victim_y = [global_victim_y; y];
    new_victim = scatter(x, y, global_victim_size^2, global_victim_color, 'filled', ...
                        'MarkerEdgeColor', global_victim_edge_color, 'LineWidth', 1.5);
    global_victims = [global_victims; new_victim];
    global_victims_text.String = sprintf('Жертв: %d', global_num_victims);
    fprintf('Добавлена новая жертва в точке (%.1f, %.1f). Всего жертв: %d\n', x, y, global_num_victims);
    drawnow;
end

function addRadarViaMenu(~, ~)
    fprintf('Режим добавления радара активирован. Щелкните левой кнопкой мыши на графике.\n');
    global global_fig
    oldCallback = get(global_fig, 'WindowButtonDownFcn');
    set(global_fig, 'WindowButtonDownFcn', @addRadarOnClick);
    
    function addRadarOnClick(~, ~)
        point = get(gca, 'CurrentPoint');
        x = point(1,1);
        y = point(1,2);
        global global_x_limits global_y_limits
        if x < global_x_limits(1) || x > global_x_limits(2) || ...
           y < global_y_limits(1) || y > global_y_limits(2)
            fprintf('Клик вне графика. Попробуйте снова.\n');
            return;
        end
        addRadarAtPoint(x, y);
        set(global_fig, 'WindowButtonDownFcn', oldCallback);
        fprintf('Режим добавления радара завершен.\n');
    end
end

function addRadarAtPoint(x, y)
    global global_radar_positions global_radar_radius global_num_radars
    global global_radar_color global_radar_opacity
    global global_radar_circles global_radar_centers
    global global_in_radar_status global_x_pos global_y_pos
    global global_marker_colors global_marker_purple_color global_marker_red_color
    global global_targets global_radar_targets_text
    global global_defender_x global_defender_y global_defender_vx global_defender_vy
    global global_defenders global_defender_radar_idx global_defenders_per_radar
    global global_defender_speed global_defender_color global_defender_size
    
    % Добавляем новый радар
    new_radar_pos = [x, y];
    global_radar_positions = [global_radar_positions; new_radar_pos];
    global_num_radars = global_num_radars + 1;
    
    % Создаём графику радара
    new_radar_objects = createRadarObjects(new_radar_pos, global_radar_radius, global_radar_color, global_radar_opacity);
    text(x, y + 15, sprintf('Радар %d', global_num_radars), ...
         'FontSize', 10, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', global_radar_color);
    global_radar_circles = [global_radar_circles; new_radar_objects.circles];
    global_radar_centers = [global_radar_centers; new_radar_objects.centers];
    
    % Добавляем защитников для нового радара (с нулевой скоростью)
    for k = 1:global_defenders_per_radar
        rho = sqrt(rand()) * global_radar_radius;
        theta = 2*pi*rand();
        new_x = x + rho * cos(theta);
        new_y = y + rho * sin(theta);
        % начальная скорость - нулевая (стоят)
        new_vx = 0;
        new_vy = 0;
        
        global_defender_x = [global_defender_x; new_x];
        global_defender_y = [global_defender_y; new_y];
        global_defender_vx = [global_defender_vx; new_vx];
        global_defender_vy = [global_defender_vy; new_vy];
        global_defender_radar_idx = [global_defender_radar_idx; global_num_radars];
        
        % Создаём графический объект
        new_def = scatter(new_x, new_y, global_defender_size^2, global_defender_color, 'filled', ...
                         'MarkerEdgeColor', 'k', 'LineWidth', 1);
        global_defenders = [global_defenders; new_def];
    end
    
    % Обновляем статус целей
    num_targets = length(global_targets);
    targets_in_radar_zone = 0;
    for i = 1:num_targets
        current_in_radar = any(sqrt((global_x_pos(i) - global_radar_positions(:,1)).^2 + ...
                                    (global_y_pos(i) - global_radar_positions(:,2)).^2) <= global_radar_radius);
        global_in_radar_status(i) = current_in_radar;
        if current_in_radar
            targets_in_radar_zone = targets_in_radar_zone + 1;
        end
        if current_in_radar
            new_marker_color = global_marker_purple_color;
        else
            new_marker_color = global_marker_red_color;
        end
        if ~isequal(global_marker_colors(i, :), new_marker_color)
            global_marker_colors(i, :) = new_marker_color;
            global_targets(i).CData = new_marker_color;
        end
    end
    
    rebuildAllTracks();
    global_radar_targets_text.String = sprintf('Целей в зоне радара: %d', targets_in_radar_zone);
    fprintf('Добавлен новый радар %d в точке (%.1f, %.1f). Всего радаров: %d\n', ...
            global_num_radars, x, y, global_num_radars);
    drawnow;
end

function changeRadarRadius(~, ~)
    global global_radar_radius global_radar_positions global_radar_color global_radar_opacity
    global global_radar_circles global_radar_centers global_num_radars
    global global_in_radar_status global_x_pos global_y_pos
    global global_marker_colors global_marker_purple_color global_marker_red_color
    global global_targets global_radar_targets_text
    global global_defender_x global_defender_y global_defender_radar_idx

    answer = inputdlg('Введите новый радиус радара (положительное число):', 'Изменение радиуса', [1 50], {num2str(global_radar_radius)});
    if isempty(answer)
        return;
    end
    new_radius = str2double(answer{1});
    if isnan(new_radius) || new_radius <= 0
        errordlg('Радиус должен быть положительным числом!', 'Ошибка');
        return;
    end
    global_radar_radius = new_radius;

    % Перерисовываем круги радаров
    delete(global_radar_circles(ishandle(global_radar_circles)));
    new_circles = gobjects(global_num_radars, 1);
    for r = 1:global_num_radars
        theta = linspace(0, 2*pi, 100);
        x_circle = global_radar_positions(r, 1) + global_radar_radius * cos(theta);
        y_circle = global_radar_positions(r, 2) + global_radar_radius * sin(theta);
        new_circles(r) = fill(x_circle, y_circle, global_radar_color, ...
                              'FaceAlpha', global_radar_opacity, ...
                              'EdgeColor', global_radar_color, ...
                              'LineWidth', 1.5);
    end
    global_radar_circles = new_circles;

    % Перестраиваем треки
    rebuildAllTracks();

    % Обновляем статусы целей и маркеры
    num_targets = length(global_targets);
    targets_in_radar_zone = 0;
    for i = 1:num_targets
        current_in_radar = any(sqrt((global_x_pos(i) - global_radar_positions(:,1)).^2 + ...
                                    (global_y_pos(i) - global_radar_positions(:,2)).^2) <= global_radar_radius);
        global_in_radar_status(i) = current_in_radar;
        if current_in_radar
            targets_in_radar_zone = targets_in_radar_zone + 1;
        end
        if current_in_radar
            new_color = global_marker_purple_color;
        else
            new_color = global_marker_red_color;
        end
        if ~isequal(global_marker_colors(i, :), new_color)
            global_marker_colors(i, :) = new_color;
            global_targets(i).CData = new_color;
        end
    end
    global_radar_targets_text.String = sprintf('Целей в зоне радара: %d', targets_in_radar_zone);

    % При изменении радиуса защитники могут оказаться вне нового радиуса – переместим их внутрь (в свой радар)
    for i = 1:length(global_defender_x)
        r_idx = global_defender_radar_idx(i);
        cx = global_radar_positions(r_idx, 1);
        cy = global_radar_positions(r_idx, 2);
        dx = global_defender_x(i) - cx;
        dy = global_defender_y(i) - cy;
        dist = sqrt(dx^2 + dy^2);
        if dist > global_radar_radius
            % сдвигаем на границу
            scale = global_radar_radius / dist;
            global_defender_x(i) = cx + dx * scale;
            global_defender_y(i) = cy + dy * scale;
            global_defenders(i).XData = global_defender_x(i);
            global_defenders(i).YData = global_defender_y(i);
        end
    end

    hlines = findobj(gca, 'Type', 'line');
    uistack(hlines, 'bottom');
    drawnow;
    fprintf('Радиус радаров изменён на %.1f\n', global_radar_radius);
end

function rebuildAllTracks()
    global global_full_track_history_x global_full_track_history_y
    global global_track_segments global_track_segment_handles
    global global_in_radar_status global_radar_positions global_radar_radius
    global global_purple_color global_red_color
    global global_linewidth_in_radar global_linewidth_out_radar
    global global_track_opacity
    global global_isRebuilding

    global_isRebuilding = true;
    num_targets = length(global_full_track_history_x);
    for i = 1:num_targets
        x_hist = global_full_track_history_x{i};
        y_hist = global_full_track_history_y{i};
        if isempty(x_hist)
            continue;
        end
        num_points = length(x_hist);
        status = false(num_points, 1);
        for p = 1:num_points
            status(p) = any(sqrt((x_hist(p) - global_radar_positions(:,1)).^2 + ...
                                 (y_hist(p) - global_radar_positions(:,2)).^2) <= global_radar_radius);
        end
        change_idx = find(diff([status(1); status]) ~= 0);
        segment_starts = change_idx;
        segment_ends = [change_idx(2:end)-1; num_points];

        new_segments_x = {};
        new_segments_y = {};
        new_segments_color = {};
        new_segments_linewidth = {};

        for s = 1:length(segment_starts)
            start_idx = segment_starts(s);
            end_idx = segment_ends(s);
            seg_status = status(start_idx);
            if seg_status
                color = global_purple_color;
                lw = global_linewidth_in_radar;
            else
                color = global_red_color;
                lw = global_linewidth_out_radar;
            end
            new_segments_x{s} = x_hist(start_idx:end_idx);
            new_segments_y{s} = y_hist(start_idx:end_idx);
            new_segments_color{s} = color;
            new_segments_linewidth{s} = lw;
        end

        if ~isempty(global_track_segment_handles{i})
            % Удаляем только валидные объекты
            valid_handles = global_track_segment_handles{i}(ishandle(global_track_segment_handles{i}));
            delete(valid_handles);
        end

        new_handles = gobjects(1, length(new_segments_x));
        for s = 1:length(new_segments_x)
            h = plot(new_segments_x{s}, new_segments_y{s}, ...
                     'Color', [new_segments_color{s}, global_track_opacity], ...
                     'LineWidth', new_segments_linewidth{s});
            new_handles(s) = h;
        end

        global_track_segment_handles{i} = new_handles;
        global_track_segments{i} = struct('x', {new_segments_x}, ...
                                           'y', {new_segments_y}, ...
                                           'color', {new_segments_color}, ...
                                           'linewidth', {new_segments_linewidth});
        global_in_radar_status(i) = status(end);
    end

    hlines = findobj(gca, 'Type', 'line');
    uistack(hlines, 'bottom');
    drawnow;
    global_isRebuilding = false;
end

function radar_objects = createRadarObjects(radar_positions, radar_radius, radar_color, radar_opacity)
    num_radars = size(radar_positions, 1);
    radar_circles = gobjects(num_radars, 1);
    radar_centers = gobjects(num_radars, 1);
    for r = 1:num_radars
        theta = linspace(0, 2*pi, 100);
        x_circle = radar_positions(r, 1) + radar_radius * cos(theta);
        y_circle = radar_positions(r, 2) + radar_radius * sin(theta);
        radar_circles(r) = fill(x_circle, y_circle, radar_color, ...
                                'FaceAlpha', radar_opacity, ...
                                'EdgeColor', radar_color, ...
                                'LineWidth', 1.5);
        radar_centers(r) = plot(radar_positions(r, 1), radar_positions(r, 2), ...
                               'o', 'MarkerSize', 8, ...
                               'MarkerFaceColor', radar_color, ...
                               'MarkerEdgeColor', 'k', ...
                               'LineWidth', 1.5);
    end
    radar_objects = struct('circles', radar_circles, 'centers', radar_centers);
end

function removeVictim(idx)
    global global_victim_x global_victim_y global_num_victims global_victims
    global global_victims_text
    if idx < 1 || idx > global_num_victims
        return;
    end
    delete(global_victims(idx));
    global_victim_x(idx) = [];
    global_victim_y(idx) = [];
    global_victims(idx) = [];
    global_num_victims = global_num_victims - 1;
    global_victims_text.String = sprintf('Жертв: %d', global_num_victims);
end

function removeTarget(idx)
    global global_x_pos global_y_pos global_x_speed global_y_speed
    global global_targets global_marker_colors global_target_ids
    global global_full_track_history_x global_full_track_history_y
    global global_full_track_time global_in_radar_status
    global global_track_segments global_track_segment_handles
    global global_all_tracks_data

    if idx < 1 || idx > length(global_targets)
        return;
    end
    delete(global_targets(idx));
    if ~isempty(global_track_segment_handles{idx})
        % Удаляем только валидные объекты
        valid_handles = global_track_segment_handles{idx}(ishandle(global_track_segment_handles{idx}));
        delete(valid_handles);
    end
    global_x_pos(idx) = [];
    global_y_pos(idx) = [];
    global_x_speed(idx) = [];
    global_y_speed(idx) = [];
    global_targets(idx) = [];
    global_marker_colors(idx, :) = [];
    global_target_ids(idx) = [];
    global_in_radar_status(idx) = [];
    global_full_track_history_x(idx) = [];
    global_full_track_history_y(idx) = [];
    global_full_track_time(idx) = [];
    global_track_segments(idx) = [];
    global_track_segment_handles(idx) = [];
    global_all_tracks_data.tracks(idx) = [];
    global_all_tracks_data.track_count = global_all_tracks_data.track_count - 1;
end

function removeDefender(idx)
    global global_defender_x global_defender_y global_defender_vx global_defender_vy
    global global_defenders global_defender_radar_idx
    if idx < 1 || idx > length(global_defender_x)
        return;
    end
    delete(global_defenders(idx));
    global_defender_x(idx) = [];
    global_defender_y(idx) = [];
    global_defender_vx(idx) = [];
    global_defender_vy(idx) = [];
    global_defenders(idx) = [];
    global_defender_radar_idx(idx) = [];
end

function runAnimation(frames, fps, x_limits, y_limits, velocity_change_probability, ...
                     max_speed_change, min_speed, max_speed, new_target_probability, ...
                     max_targets, linewidth_in_radar, linewidth_out_radar, purple_color, ...
                     red_color, track_opacity, marker_purple_color, marker_red_color, ...
                     radar_positions, radar_radius, target_size, num_radars, total_time, ...
                     pursuit_enabled, pursuit_turning_rate, kill_distance, ...
                     defender_speed, defender_turning_rate)
    
    global isAnimationRunning isAnimationPaused
    global global_victims_text global_num_victims
    global global_victim_x global_victim_y
    global global_all_tracks_data
    global global_x_pos global_y_pos global_x_speed global_y_speed
    global global_targets global_marker_colors global_target_ids
    global global_full_track_history_x global_full_track_history_y
    global global_full_track_time global_in_radar_status
    global global_track_segments global_track_segment_handles
    global global_time_text global_radar_targets_text
    global global_radar_positions global_radar_radius
    global global_isRebuilding
    global global_defender_x global_defender_y global_defender_vx global_defender_vy
    global global_defenders global_defender_radar_idx
    global global_defender_color global_defender_size
    
    % Функция проверки принадлежности к объединенной зоне радаров
    is_in_radar_zone = @(x, y) any(sqrt((x - global_radar_positions(:,1)).^2 + (y - global_radar_positions(:,2)).^2) <= global_radar_radius);
    
    % Создание объекта VideoWriter
    video_filename = ['simulation_' datestr(now, 'yyyymmdd_HHMMSS') '.avi'];
    vidObj = VideoWriter(video_filename);
    vidObj.FrameRate = fps;
    open(vidObj);
    fprintf('Запись видео в файл: %s\n', video_filename);
    
    start_time = tic;
    
    for frame = 1:frames
        if ~isAnimationRunning
            break;
        end
        while isAnimationPaused && isAnimationRunning
            pause(0.1);
            drawnow;
        end
        while global_isRebuilding
            pause(0.01);
            drawnow;
        end
        
        elapsed_time = (frame - 1) / fps;
        num_targets = length(global_targets);
        targets_in_radar_zone = 0;
        
        % ---- ПРЕСЛЕДОВАНИЕ целей к жертвам (как и ранее) ----
        if pursuit_enabled && global_num_victims > 0
            for i = 1:num_targets
                distances = sqrt((global_victim_x - global_x_pos(i)).^2 + (global_victim_y - global_y_pos(i)).^2);
                [min_dist, idx_min] = min(distances);
                if ~isempty(min_dist)
                    dir_x = global_victim_x(idx_min) - global_x_pos(i);
                    dir_y = global_victim_y(idx_min) - global_y_pos(i);
                    norm_dir = sqrt(dir_x^2 + dir_y^2);
                    if norm_dir > 0
                        dir_x = dir_x / norm_dir;
                        dir_y = dir_y / norm_dir;
                        current_speed = sqrt(global_x_speed(i)^2 + global_y_speed(i)^2);
                        if current_speed < min_speed
                            current_speed = min_speed;
                        elseif current_speed > max_speed
                            current_speed = max_speed;
                        end
                        desired_x = dir_x * current_speed;
                        desired_y = dir_y * current_speed;
                        global_x_speed(i) = (1 - pursuit_turning_rate) * global_x_speed(i) + pursuit_turning_rate * desired_x;
                        global_y_speed(i) = (1 - pursuit_turning_rate) * global_y_speed(i) + pursuit_turning_rate * desired_y;
                        new_speed = sqrt(global_x_speed(i)^2 + global_y_speed(i)^2);
                        if new_speed < min_speed
                            global_x_speed(i) = global_x_speed(i) / new_speed * min_speed;
                            global_y_speed(i) = global_y_speed(i) / new_speed * min_speed;
                        elseif new_speed > max_speed
                            global_x_speed(i) = global_x_speed(i) / new_speed * max_speed;
                            global_y_speed(i) = global_y_speed(i) / new_speed * max_speed;
                        end
                    end
                end
            end
        else
            for i = 1:num_targets
                if rand() < velocity_change_probability
                    global_x_speed(i) = global_x_speed(i) + (rand() - 0.5) * 2 * max_speed_change;
                    global_y_speed(i) = global_y_speed(i) + (rand() - 0.5) * 2 * max_speed_change;
                    current_speed = sqrt(global_x_speed(i)^2 + global_y_speed(i)^2);
                    if current_speed < min_speed
                        scale_factor = min_speed / current_speed;
                        global_x_speed(i) = global_x_speed(i) * scale_factor;
                        global_y_speed(i) = global_y_speed(i) * scale_factor;
                    elseif current_speed > max_speed
                        scale_factor = max_speed / current_speed;
                        global_x_speed(i) = global_x_speed(i) * scale_factor;
                        global_y_speed(i) = global_y_speed(i) * scale_factor;
                    end
                end
            end
        end
        
        % Движение целей (как и ранее)
        for i = 1:num_targets
            global_x_pos(i) = global_x_pos(i) + global_x_speed(i) / fps;
            global_y_pos(i) = global_y_pos(i) + global_y_speed(i) / fps;
            global_full_track_history_x{i} = [global_full_track_history_x{i}; global_x_pos(i)];
            global_full_track_history_y{i} = [global_full_track_history_y{i}; global_y_pos(i)];
            global_full_track_time{i} = [global_full_track_time{i}; elapsed_time];
            
            current_in_radar = is_in_radar_zone(global_x_pos(i), global_y_pos(i));
            if current_in_radar
                targets_in_radar_zone = targets_in_radar_zone + 1;
            end
            
            if current_in_radar
                current_marker_color = marker_purple_color;
            else
                current_marker_color = marker_red_color;
            end
            if ~isequal(global_marker_colors(i, :), current_marker_color)
                global_marker_colors(i, :) = current_marker_color;
                global_targets(i).CData = current_marker_color;
            end
            
            if current_in_radar ~= global_in_radar_status(i)
                last_idx = length(global_track_segments{i}.x);
                if last_idx > 0
                    global_track_segments{i}.x{last_idx} = [global_track_segments{i}.x{last_idx}; global_x_pos(i)];
                    global_track_segments{i}.y{last_idx} = [global_track_segments{i}.y{last_idx}; global_y_pos(i)];
                    if ~isempty(global_track_segment_handles{i}) && last_idx <= length(global_track_segment_handles{i}) ...
                            && ishandle(global_track_segment_handles{i}(last_idx))
                        set(global_track_segment_handles{i}(last_idx), ...
                            'XData', global_track_segments{i}.x{last_idx}, ...
                            'YData', global_track_segments{i}.y{last_idx});
                    end
                end
                new_segment_color = current_in_radar * purple_color + ~current_in_radar * red_color;
                new_linewidth = current_in_radar * linewidth_in_radar + ~current_in_radar * linewidth_out_radar;
                global_track_segments{i}.x{end+1} = global_x_pos(i);
                global_track_segments{i}.y{end+1} = global_y_pos(i);
                global_track_segments{i}.color{end+1} = new_segment_color;
                global_track_segments{i}.linewidth{end+1} = new_linewidth;
                h = plot(global_track_segments{i}.x{end}, global_track_segments{i}.y{end}, ...
                         'Color', [new_segment_color, track_opacity], ...
                         'LineWidth', new_linewidth);
                uistack(h, 'bottom');
                global_track_segment_handles{i} = [global_track_segment_handles{i}, h];
                global_in_radar_status(i) = current_in_radar;
            else
                last_idx = length(global_track_segments{i}.x);
                if last_idx == 0
                    new_segment_color = current_in_radar * purple_color + ~current_in_radar * red_color;
                    new_linewidth = current_in_radar * linewidth_in_radar + ~current_in_radar * linewidth_out_radar;
                    global_track_segments{i}.x{1} = global_x_pos(i);
                    global_track_segments{i}.y{1} = global_y_pos(i);
                    global_track_segments{i}.color{1} = new_segment_color;
                    global_track_segments{i}.linewidth{1} = new_linewidth;
                    h = plot(global_track_segments{i}.x{1}, global_track_segments{i}.y{1}, ...
                             'Color', [new_segment_color, track_opacity], ...
                             'LineWidth', new_linewidth);
                    uistack(h, 'bottom');
                    global_track_segment_handles{i} = [global_track_segment_handles{i}, h];
                    global_in_radar_status(i) = current_in_radar;
                else
                    global_track_segments{i}.x{last_idx} = [global_track_segments{i}.x{last_idx}; global_x_pos(i)];
                    global_track_segments{i}.y{last_idx} = [global_track_segments{i}.y{last_idx}; global_y_pos(i)];
                    if ~isempty(global_track_segment_handles{i}) && last_idx <= length(global_track_segment_handles{i}) ...
                            && ishandle(global_track_segment_handles{i}(last_idx))
                        set(global_track_segment_handles{i}(last_idx), ...
                            'XData', global_track_segments{i}.x{last_idx}, ...
                            'YData', global_track_segments{i}.y{last_idx});
                    end
                end
            end
            
            global_targets(i).XData = global_x_pos(i);
            global_targets(i).YData = global_y_pos(i);
            
            if i <= global_all_tracks_data.track_count
                global_all_tracks_data.tracks(i).positions = [global_full_track_history_x{i}, global_full_track_history_y{i}];
                global_all_tracks_data.tracks(i).speeds = [global_x_speed(i), global_y_speed(i)];
                global_all_tracks_data.tracks(i).total_points = length(global_full_track_history_x{i});
            else
                global_all_tracks_data.track_count = global_all_tracks_data.track_count + 1;
                global_all_tracks_data.tracks(i).id = global_target_ids(i);
                global_all_tracks_data.tracks(i).positions = [global_full_track_history_x{i}, global_full_track_history_y{i}];
                global_all_tracks_data.tracks(i).speeds = [global_x_speed(i), global_y_speed(i)];
                global_all_tracks_data.tracks(i).creation_time = elapsed_time;
                global_all_tracks_data.tracks(i).total_points = length(global_full_track_history_x{i});
                global_all_tracks_data.tracks(i).in_radar_segments = [];
            end
        end
        
        % ---- ЖАДНОЕ РАСПРЕДЕЛЕНИЕ ЦЕЛЕЙ МЕЖДУ ЗАЩИТНИКАМИ (используем локальную функцию Greedy_Pursuit без визуализации) ----
        % Определяем цели, находящиеся в объединенной зоне радаров
        targets_in_union = [];
        target_indices_in_union = [];
        for t = 1:length(global_targets)
            if is_in_radar_zone(global_x_pos(t), global_y_pos(t))
                targets_in_union = [targets_in_union; global_x_pos(t), global_y_pos(t)];
                target_indices_in_union = [target_indices_in_union; t];
            end
        end
        
        % Количество защитников
        num_defenders = length(global_defender_x);
        
        % Инициализация массива назначений (глобальный индекс цели для каждого защитника)
        assigned_target_global = zeros(num_defenders, 1); % 0 - нет цели
        
        if ~isempty(targets_in_union)
            % Формируем матрицу позиций защитников
            defenders_pos = [global_defender_x, global_defender_y];
            
            % Вычисляем матрицу стоимостей (расстояния)
            costMatrix = zeros(num_defenders, size(targets_in_union, 1));
            for d = 1:num_defenders
                for tt = 1:size(targets_in_union, 1)
                    costMatrix(d, tt) = sqrt((defenders_pos(d,1)-targets_in_union(tt,1))^2 + ...
                                              (defenders_pos(d,2)-targets_in_union(tt,2))^2);
                end
            end
            
            % Вызываем локальную функцию жадного алгоритма (без визуализации)
            assignment = Greedy_Pursuit(defenders_pos, targets_in_union, costMatrix);
            
            % Преобразуем назначения в глобальные индексы целей
            for d = 1:num_defenders
                if assignment(d) > 0
                    assigned_target_global(d) = target_indices_in_union(assignment(d));
                end
            end
        else
            % Нет целей в зоне - все защитники без назначений
            assigned_target_global(:) = 0;
        end
        
        % ---- ДВИЖЕНИЕ ЗАЩИТНИКОВ с учётом назначенных целей и ограничением общей зоной ----
        for d = 1:num_defenders
            target_global_idx = assigned_target_global(d);
            if target_global_idx > 0
                % Преследование назначенной цели
                dir_x = global_x_pos(target_global_idx) - global_defender_x(d);
                dir_y = global_y_pos(target_global_idx) - global_defender_y(d);
                norm_dir = sqrt(dir_x^2 + dir_y^2);
                if norm_dir > 0
                    dir_x = dir_x / norm_dir;
                    dir_y = dir_y / norm_dir;
                    desired_vx = dir_x * defender_speed;
                    desired_vy = dir_y * defender_speed;
                    global_defender_vx(d) = (1 - defender_turning_rate) * global_defender_vx(d) + defender_turning_rate * desired_vx;
                    global_defender_vy(d) = (1 - defender_turning_rate) * global_defender_vy(d) + defender_turning_rate * desired_vy;
                    % Нормализация скорости
                    sp = sqrt(global_defender_vx(d)^2 + global_defender_vy(d)^2);
                    if sp > 0
                        global_defender_vx(d) = global_defender_vx(d) / sp * defender_speed;
                        global_defender_vy(d) = global_defender_vy(d) / sp * defender_speed;
                    end
                end
            else
                % Нет назначенной цели – стоим на месте
                global_defender_vx(d) = 0;
                global_defender_vy(d) = 0;
            end

            % Обновляем позицию
            new_x = global_defender_x(d) + global_defender_vx(d) / fps;
            new_y = global_defender_y(d) + global_defender_vy(d) / fps;

            % Проверяем, находится ли новая позиция в объединенной зоне радаров
            if ~is_in_radar_zone(new_x, new_y)
                % Если выходит за пределы общей зоны, оставляем на месте и обнуляем скорость
                % (Защитник останавливается на границе)
                global_defender_vx(d) = 0;
                global_defender_vy(d) = 0;
                % Позиция не меняется
            else
                global_defender_x(d) = new_x;
                global_defender_y(d) = new_y;
            end

            % Обновляем графику
            global_defenders(d).XData = global_defender_x(d);
            global_defenders(d).YData = global_defender_y(d);
        end
        
        % ---- ПРОВЕРКА СТОЛКНОВЕНИЙ ЗАЩИТНИКОВ С ЦЕЛЯМИ (оба исчезают) ----
        if length(global_targets) > 0
            d = 1;
            while d <= length(global_defender_x)
                t = 1;
                found = false;
                while t <= length(global_targets)
                    dist = sqrt((global_x_pos(t) - global_defender_x(d))^2 + (global_y_pos(t) - global_defender_y(d))^2);
                    if dist < kill_distance
                        removeTarget(t);
                        removeDefender(d);
                        found = true;
                        break;
                    else
                        t = t + 1;
                    end
                end
                if ~found
                    d = d + 1;
                end
            end
        end
        
        % ---- ПРОВЕРКА СТОЛКНОВЕНИЙ ЦЕЛЕЙ С ЖЕРТВАМИ (цели убивают жертвы и исчезают) ----
        if pursuit_enabled && global_num_victims > 0
            i = 1;
            while i <= length(global_targets)
                j = 1;
                found = false;
                while j <= global_num_victims
                    dist = sqrt((global_x_pos(i) - global_victim_x(j))^2 + (global_y_pos(i) - global_victim_y(j))^2);
                    if dist < kill_distance
                        removeVictim(j);
                        removeTarget(i);
                        found = true;
                        break;
                    else
                        j = j + 1;
                    end
                end
                if ~found
                    i = i + 1;
                end
            end
        end
        
        % Пересчёт целей в зоне радара
        targets_in_radar_zone = 0;
        for i = 1:length(global_targets)
            if is_in_radar_zone(global_x_pos(i), global_y_pos(i))
                targets_in_radar_zone = targets_in_radar_zone + 1;
            end
        end
        
        % Генерация новых целей (как и ранее)
        if rand() < new_target_probability && length(global_targets) < max_targets
            new_x = rand() * (x_limits(2) - x_limits(1)) + x_limits(1);
            new_y = rand() * (y_limits(2) - y_limits(1)) + y_limits(1);
            new_in_radar = is_in_radar_zone(new_x, new_y);
            if new_in_radar
                new_marker_color = marker_purple_color;
                targets_in_radar_zone = targets_in_radar_zone + 1;
            else
                new_marker_color = marker_red_color;
            end
            new_x_speed = (rand() - 0.5) * 2 * max_speed;
            new_y_speed = (rand() - 0.5) * 2 * max_speed;
            current_speed = sqrt(new_x_speed^2 + new_y_speed^2);
            if current_speed < min_speed
                scale_factor = min_speed / current_speed;
                new_x_speed = new_x_speed * scale_factor;
                new_y_speed = new_y_speed * scale_factor;
            elseif current_speed > max_speed
                scale_factor = max_speed / current_speed;
                new_x_speed = new_x_speed * scale_factor;
                new_y_speed = new_y_speed * scale_factor;
            end
            global_x_pos = [global_x_pos; new_x];
            global_y_pos = [global_y_pos; new_y];
            global_x_speed = [global_x_speed; new_x_speed];
            global_y_speed = [global_y_speed; new_y_speed];
            global_marker_colors = [global_marker_colors; new_marker_color];
            
            % Исправление: корректное вычисление нового ID, если массив пуст
            if isempty(global_target_ids)
                new_target_id = 1;
            else
                new_target_id = max(global_target_ids) + 1;
            end
            global_target_ids = [global_target_ids; new_target_id];
            
            new_track_idx = length(global_targets) + 1;
            global_full_track_history_x{new_track_idx} = new_x;
            global_full_track_history_y{new_track_idx} = new_y;
            global_full_track_time{new_track_idx} = elapsed_time;
            global_in_radar_status(new_track_idx) = new_in_radar;
            global_track_segments{new_track_idx} = struct();
            global_track_segments{new_track_idx}.x = {global_full_track_history_x{new_track_idx}};
            global_track_segments{new_track_idx}.y = {global_full_track_history_y{new_track_idx}};
            new_segment_color = new_in_radar * purple_color + ~new_in_radar * red_color;
            new_linewidth = new_in_radar * linewidth_in_radar + ~new_in_radar * linewidth_out_radar;
            global_track_segments{new_track_idx}.color = {new_segment_color};
            global_track_segments{new_track_idx}.linewidth = {new_linewidth};
            global_track_segment_handles{new_track_idx} = gobjects(0);
            h = plot(global_track_segments{new_track_idx}.x{1}, global_track_segments{new_track_idx}.y{1}, ...
                     'Color', [new_segment_color, track_opacity], ...
                     'LineWidth', new_linewidth);
            uistack(h, 'bottom');
            global_track_segment_handles{new_track_idx} = [global_track_segment_handles{new_track_idx}, h];
            new_target = scatter(new_x, new_y, target_size^2, new_marker_color, 'filled', ...
                                'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            global_targets = [global_targets; new_target];
            global_all_tracks_data.track_count = global_all_tracks_data.track_count + 1;
            global_all_tracks_data.tracks(new_track_idx).id = new_target_id;
            global_all_tracks_data.tracks(new_track_idx).positions = [new_x, new_y];
            global_all_tracks_data.tracks(new_track_idx).speeds = [new_x_speed, new_y_speed];
            global_all_tracks_data.tracks(new_track_idx).creation_time = elapsed_time;
            global_all_tracks_data.tracks(new_track_idx).total_points = 1;
            global_all_tracks_data.tracks(new_track_idx).in_radar_segments = [];
            global_time_text.String = sprintf('Время: %.1f сек | Целей: %d', elapsed_time, length(global_targets));
            fprintf('Создана новая цель ID=%d! Всего целей: %d\n', new_target_id, length(global_targets));
        end
        
        % Обновление текстов
        global_time_text.String = sprintf('Время: %.1f сек | Целей: %d', elapsed_time, length(global_targets));
        global_radar_targets_text.String = sprintf('Целей в зоне радара: %d', targets_in_radar_zone);
        
        drawnow limitrate;
        
        % Захват кадра для видео
        frame_img = getframe(gcf);
        writeVideo(vidObj, frame_img);
        
        pause(1/fps);
    end
    
    % Закрытие видео
    close(vidObj);
    fprintf('Видео сохранено: %s\n', video_filename);
    
    total_elapsed = toc(start_time);
    fprintf('\n=== Анимация завершена! ===\n');
    fprintf('Общее время выполнения: %.2f секунд\n', total_elapsed);
    fprintf('Количество кадров: %d\n', frames);
    fprintf('Итоговое количество целей: %d\n', length(global_targets));
    fprintf('Итоговое количество жертв: %d\n', global_num_victims);
    fprintf('Итоговое количество радаров: %d\n', size(global_radar_positions, 1));
    fprintf('Треки отображаются сегментами\n');
    fprintf('Прозрачность треков: %.2f\n', track_opacity);
    fprintf('Части треков в зоне радара: фиолетовые, толщина %.1f\n', linewidth_in_radar);
    fprintf('Части треков вне зоны радара: красные, толщина %.1f\n', linewidth_out_radar);
    fprintf('Маркеры целей в зоне радара: фиолетовые\n');
    fprintf('Маркеры целей вне зоны радара: красные\n');
    if pursuit_enabled
        fprintf('Режим движения: жадное преследование жертв\n');
    else
        fprintf('Траектории целей случайные (вероятность изменения скорости: %.1f%%)\n', velocity_change_probability * 100);
    end
    fprintf('Диапазон скоростей: от %.1f до %.1f\n', min_speed, max_speed);
    fprintf('Количество радаров: %d\n', size(global_radar_positions, 1));
    fprintf('Радиус действия радаров: %.1f\n', radar_radius);
    
    save('all_tracks_data.mat', 'global_all_tracks_data', 'global_full_track_history_x', ...
         'global_full_track_history_y', 'global_full_track_time', 'global_target_ids', 'x_limits', ...
         'y_limits', 'fps', 'total_time', 'min_speed', 'max_speed', ...
         'velocity_change_probability', 'global_radar_positions', 'global_radar_radius', ...
         'global_marker_colors', 'global_track_segments', 'linewidth_in_radar', 'linewidth_out_radar', ...
         'global_victim_x', 'global_victim_y', 'global_num_victims');
    
    fprintf('\n=== Сохранение данных треков ===\n');
    fprintf('Данные сохранены в файл: all_tracks_data.mat\n');
    
    % Статистика по трекам
    fprintf('\n=== Статистика по трекам ===\n');
    total_points_all_tracks = 0;
    max_points = 0;
    min_points = Inf;
    max_points_id = 0;
    min_points_id = 0;
    red_marker_targets = 0;
    purple_marker_targets = 0;
    
    for i = 1:global_all_tracks_data.track_count
        points = global_all_tracks_data.tracks(i).total_points;
        total_points_all_tracks = total_points_all_tracks + points;
        if i <= size(global_marker_colors, 1) && isequal(global_marker_colors(i, :), marker_red_color)
            red_marker_targets = red_marker_targets + 1;
        elseif i <= size(global_marker_colors, 1) && isequal(global_marker_colors(i, :), marker_purple_color)
            purple_marker_targets = purple_marker_targets + 1;
        end
        if points > max_points
            max_points = points;
            max_points_id = global_all_tracks_data.tracks(i).id;
        end
        if points < min_points
            min_points = points;
            min_points_id = global_all_tracks_data.tracks(i).id;
        end
    end
    avg_points = total_points_all_tracks / global_all_tracks_data.track_count;
    fprintf('Всего точек треков: %d\n', total_points_all_tracks);
    fprintf('Среднее количество точек на трек: %.1f\n', avg_points);
    fprintf('Максимальная длина трека: %d точек (Цель ID=%d)\n', max_points, max_points_id);
    fprintf('Минимальная длина трека: %d точек (Цель ID=%d)\n', min_points, min_points_id);
    fprintf('Целей с красным маркером (вне зоны радара): %d\n', red_marker_targets);
    fprintf('Целей с фиолетовым маркером (в зоне радара): %d\n', purple_marker_targets);
    
    total_segments = 0;
    purple_segments = 0;
    red_segments = 0;
    for i = 1:length(global_track_segments)
        if ~isempty(global_track_segments{i})
            total_segments = total_segments + length(global_track_segments{i}.x);
            for j = 1:length(global_track_segments{i}.color)
                if isequal(global_track_segments{i}.color{j}, purple_color)
                    purple_segments = purple_segments + 1;
                elseif isequal(global_track_segments{i}.color{j}, red_color)
                    red_segments = red_segments + 1;
                end
            end
        end
    end
    fprintf('Всего сегментов треков: %d\n', total_segments);
    fprintf('  - Сегментов в зоне радара (фиолетовые): %d\n', purple_segments);
    fprintf('  - Сегментов вне зоны радара (красные): %d\n', red_segments);
    fprintf('Среднее количество сегментов на трек: %.1f\n', total_segments / global_all_tracks_data.track_count);
    
    isAnimationRunning = false;
end

%% Локальная функция жадного распределения (без визуализации)
function assignment = Greedy_Pursuit(pursuers, targets, costMatrix)
    [N, ~] = size(pursuers);
    [M, ~] = size(targets);
    
    % Проверка размеров (упрощённая)
    if size(costMatrix, 1) ~= N || size(costMatrix, 2) ~= M
        error('Несоответствие размеров матрицы стоимостей.');
    end
    
    assignment = zeros(N, 1);
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
        i = pairs(k, 1);
        j = pairs(k, 2);
        if ~usedPursuers(i) && ~usedTargets(j)
            assignment(i) = j;
            usedPursuers(i) = true;
            usedTargets(j) = true;
        end
        if all(usedPursuers) || all(usedTargets)
            break;
        end
    end
end

%% Информационное сообщение
fprintf('\n=== Программа готова к работе ===\n');
fprintf('Используйте меню РАДАРЫ для управления анимацией:\n');
fprintf('  - "Начальное состояние": сброс к начальным параметрам\n');
fprintf('  - "Запустить анимацию": запуск 50-секундной анимации\n');
fprintf('  - "Добавить цель": добавление цели в указанной точке\n');
fprintf('  - "Добавить жертву": добавление жертвы в указанной точке\n');
fprintf('  - "Вставить радар": добавление радара в указанной точке\n');
fprintf('  - "Изменить радиус радара": изменение радиуса действия всех радаров\n');
fprintf('  - "Пауза": приостановка анимации\n');
fprintf('  - "Продолжить": возобновление анимации\n');
fprintf('\nДля добавления цели используйте меню "РАДАРЫ" -> "Добавить цель"\n');
fprintf('Для добавления жертвы используйте меню "РАДАРЫ" -> "Добавить жертву"\n');
fprintf('Для добавления радара используйте меню "РАДАРЫ" -> "Вставить радар"\n');
fprintf('Для изменения радиуса используйте меню "РАДАРЫ" -> "Изменить радиус радара"\n');
fprintf('\nРежим движения: жадное преследование жертв (можно отключить параметром pursuit_enabled)\n');
fprintf('В каждом радаре размещено по %d синих защитника, которые теперь могут перемещаться по ОБЪЕДИНЕННОЙ зоне всех радаров и преследовать любые цели в этой зоне.\n', defenders_per_radar);
fprintf('При столкновении защитника с целью оба исчезают.\n');