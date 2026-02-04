%% Модель работы радара на плоскости с динамической матрицей стоимостей
%% Включено сопровождение целей (Track-While-Scan) с отрисовкой треков
%% Случайные (непрямолинейные) траектории целей
%% Добавлены защитники и матрица расстояний защитник-цель
%% РАЗМЕР ЦЕЛИ ПАРАМЕТРИЗИРОВАН
clear; clc; close all;

%% Параметры модели
radar_range = 100;           % Радиус действия радара
area_size = 200;             % Размер области (200x200)
radar_pos = [100, 100];      % Позиция радара в центре
target_radius = 1;          % РАДИУС ЦЕЛЕЙ (легко изменяемый параметр)
text_offset = target_radius + 8;  % Смещение текста от центра цели

% Динамические параметры целей
max_targets = 15;            % Максимальное количество целей одновременно
initial_targets = 8;         % Начальное количество целей
spawn_probability = 0.1;     % Вероятность появления новой цели на шаг
trajectory_change_prob = 0.3; % Вероятность изменения траектории на шаг
max_turn_angle = 45;         % Максимальный угол поворота за шаг (градусы)

% Классы целей с разными свойствами
target_classes = struct(...
    'drone',    struct('speed', 2, 'spawn_prob', 0.07, 'priority', 1, 'color', [0 1 0]), ...
    'aircraft', struct('speed', 3, 'spawn_prob', 0.05, 'priority', 2, 'color', [1 1 0]), ...
    'missile',  struct('speed', 5, 'spawn_prob', 0.03, 'priority', 3, 'color', [1 0 0]) ...
);

class_names = fieldnames(target_classes);
num_classes = length(class_names);

%% Инициализация защитников (defenders) в окружности радиусом 75 с центром в [100; 100]
num_defenders = 10;
defenders = struct();

for i = 1:num_defenders
    defenders(i).id = i;
    
    % Генерация случайной позиции в круге радиусом 75 с центром в [100, 100]
    radius = sqrt(rand()) * 75; % Для равномерного распределения по площади
    angle = rand() * 2 * pi;
    
    defenders(i).pos = [100 + radius * cos(angle), 100 + radius * sin(angle)];
    defenders(i).color = [0 0.5 1];  % ЯРКИЙ ГОЛУБОЙ цвет для защитников
    defenders(i).range = 80;  % Максимальная дальность действия защитника
    defenders(i).active = true;
end

%% Инициализация динамических целей (с поддержкой сопровождения)
targets = struct();
next_id = 1;

for i = 1:initial_targets
    % Случайный выбор класса
    class_idx = randi(num_classes);
    class_name = class_names{class_idx};
    class_props = target_classes.(class_name);
    
    targets(i).id = next_id;
    targets(i).class = class_name;
    targets(i).priority = class_props.priority;
    targets(i).color = class_props.color;
    targets(i).pos = rand(1, 2) * area_size;
    
    % Начальная скорость с случайным направлением
    angle = rand() * 2 * pi;
    speed = class_props.speed;
    targets(i).vel = speed * [cos(angle), sin(angle)];
    
    targets(i).active = true;
    targets(i).lifetime = 0;
    targets(i).history = targets(i).pos;  % Инициализация истории для сопровождения
    
    next_id = next_id + 1;
end

%% Создание основного окна моделирования
figure_main = figure('Position', [100, 100, 900, 700], ...
    'Name', sprintf('Модель радара', target_radius));
hold on; grid on; axis equal;
xlim([0 area_size]); ylim([0 area_size]);
xlabel('X координата'); ylabel('Y координата');
title(sprintf('Сопровождение целей', target_radius));

%% Создание окна для матрицы стоимостей (цифровое отображение)
figure_matrix = figure('Position', [1000, 100, 550, 700], 'Name', 'Матрица стоимостей радара');

% Создаем таблицу с правильными параметрами
column_widths = {40, 80, 60, 60, 80, 80}; % Ширина столбцов
column_names = {'ID', 'Класс', 'X', 'Y', 'Расстояние', 'Стоимость'};

matrix_table = uitable(figure_matrix, ...
    'Position', [20, 60, 510, 620], ...
    'ColumnName', column_names, ...
    'ColumnWidth', column_widths, ...
    'ColumnFormat', {'numeric', 'char', 'numeric', 'numeric', 'numeric', 'numeric'}, ...
    'FontSize', 10, ...
    'RowName', []);

% Заголовок окна матрицы
uicontrol('Parent', figure_matrix, 'Style', 'text', ...
    'String', 'ДИНАМИЧЕСКАЯ МАТРИЦА СТОИМОСТЕЙ РАДАРА', ...
    'Position', [100, 10, 350, 30], ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

step_text_handle = uicontrol('Parent', figure_matrix, 'Style', 'text', ...
    'String', 'Шаг: 1', ...
    'Position', [100, 40, 350, 20], ...
    'FontSize', 10, ...
    'Tag', 'step_text');

%% Создание окна для матрица защитник-цель в формате "строки-защитники, столбцы-цели"
figure_defender_matrix = figure('Position', [1570, 100, 700, 700], 'Name', 'Матрица расстояний защитник-цель');

% Создаем таблицу с динамическими столбцами
defender_matrix_table = uitable(figure_defender_matrix, ...
    'Position', [20, 60, 660, 620], ...
    'ColumnName', {'Защитник\Цель'}, ...
    'ColumnWidth', {80}, ...
    'ColumnFormat', {'char'}, ...
    'FontSize', 10, ...
    'RowName', []);

% Заголовок окна матрицы защитников
uicontrol('Parent', figure_defender_matrix, 'Style', 'text', ...
    'String', 'МАТРИЦА РАССТОЯНИЙ ЗАЩИТНИК-ЦЕЛЬ', ...
    'Position', [150, 10, 400, 30], ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

defender_step_text_handle = uicontrol('Parent', figure_defender_matrix, 'Style', 'text', ...
    'String', sprintf('Шаг: 1 | Защитников: %d | Видимых целей: 0', num_defenders), ...
    'Position', [150, 40, 400, 20], ...
    'FontSize', 10, ...
    'Tag', 'defender_step_text');

%% Инициализация матриц для сохранения данных
num_steps = 100;
detection_history = cell(num_steps, 1);
cost_matrix_history = cell(num_steps, 1);  % История матриц стоимостей радара
defender_matrix_history = cell(num_steps, 1);  % История матриц защитник-цель
track_history = struct();  % История треков для сопровождения

%% Главный цикл моделирования с сопровождением
for step = 1:num_steps
    % 1. УПРАВЛЕНИЕ ДИНАМИЧЕСКИМИ ЦЕЛЯМИ С СЛУЧАЙНЫМИ ТРАЕКТОРИЯМИ
    
    % Подсчет активных целей
    if isfield(targets, 'active')
        active_targets = [targets.active];
    else
        active_targets = false(1, length(targets));
    end
    num_active = sum(active_targets);
    
    % Обновление позиций активных целей и истории сопровождения
    for i = 1:length(targets)
        if targets(i).active
            % СЛУЧАЙНОЕ ИЗМЕНЕНИЕ ТРАЕКТОРИИ
            if rand() < trajectory_change_prob
                % Получаем параметры класса цели
                class_props = target_classes.(targets(i).class);
                
                % Случайный поворот вектора скорости
                current_angle = atan2(targets(i).vel(2), targets(i).vel(1));
                turn_angle = (rand() * 2 - 1) * max_turn_angle * (pi/180);
                new_angle = current_angle + turn_angle;
                
                % Нормализация угла
                if new_angle > pi
                    new_angle = new_angle - 2*pi;
                elseif new_angle < -pi
                    new_angle = new_angle + 2*pi;
                end
                
                % Случайное изменение скорости (±20%)
                speed_variation = 0.8 + rand() * 0.4; % от 0.8 до 1.2
                new_speed = norm(targets(i).vel) * speed_variation;
                
                % Ограничение скорости по классу
                new_speed = min(new_speed, class_props.speed * 1.2);
                new_speed = max(new_speed, class_props.speed * 0.5);
                
                % Обновление вектора скорости
                targets(i).vel = new_speed * [cos(new_angle), sin(new_angle)];
            end
            
            % Обновление позиции
            targets(i).pos = targets(i).pos + targets(i).vel;
            
            % СОПРОВОЖДЕНИЕ: Добавление позиции в историю
            if isfield(targets(i), 'history')
                targets(i).history = [targets(i).history; targets(i).pos];
            else
                targets(i).history = targets(i).pos;
            end
            
            % Ограничение длины истории (последние 50 точек)
            if size(targets(i).history, 1) > 50
                targets(i).history = targets(i).history(end-49:end, :);
            end
            
            % Проверка выхода за границы (исчезновение цели)
            if any(targets(i).pos < 0) || any(targets(i).pos > area_size)
                targets(i).active = false;
                fprintf('Шаг %d: Цель ID=%d (класс: %s) исчезла за границами\n', ...
                    step, targets(i).id, targets(i).class);
                
                % Сохранение завершенного трека
                track_history.(['target_' num2str(targets(i).id)]) = ...
                    struct('id', targets(i).id, ...
                           'class', targets(i).class, ...
                           'track', targets(i).history);
            end
        end
    end
    
    % Создание новых целей
    if num_active < max_targets && rand() < spawn_probability
        % Случайный выбор класса с учетом вероятности появления
        class_probs = zeros(1, num_classes);
        for c = 1:num_classes
            class_name = class_names{c};
            class_probs(c) = target_classes.(class_name).spawn_prob;
        end
        class_probs = class_probs / sum(class_probs);
        
        % Выбор класса на основе вероятностей
        r = rand();
        cum_prob = 0;
        selected_class_idx = 1;
        for c = 1:num_classes
            cum_prob = cum_prob + class_probs(c);
            if r <= cum_prob
                selected_class_idx = c;
                break;
            end
        end
        
        class_name = class_names{selected_class_idx};
        class_props = target_classes.(class_name);
        
        % Создание новой цели
        new_target = struct();
        new_target.id = next_id;
        new_target.class = class_name;
        new_target.priority = class_props.priority;
        new_target.color = class_props.color;
        
        % Случайная позиция на границе области
        side = randi(4); % 1: верх, 2: право, 3: низ, 4: лево
        switch side
            case 1 % Верх
                new_target.pos = [rand()*area_size, area_size];
                angle = pi/2 + (rand()-0.5)*pi/2;
                new_target.vel = class_props.speed * [cos(angle), sin(angle)];
            case 2 % Право
                new_target.pos = [area_size, rand()*area_size];
                angle = pi + (rand()-0.5)*pi/2;
                new_target.vel = class_props.speed * [cos(angle), sin(angle)];
            case 3 % Низ
                new_target.pos = [rand()*area_size, 0];
                angle = -pi/2 + (rand()-0.5)*pi/2;
                new_target.vel = class_props.speed * [cos(angle), sin(angle)];
            case 4 % Лево
                new_target.pos = [0, rand()*area_size];
                angle = 0 + (rand()-0.5)*pi/2;
                new_target.vel = class_props.speed * [cos(angle), sin(angle)];
        end
        
        new_target.active = true;
        new_target.lifetime = 0;
        new_target.history = new_target.pos; % Инициализация истории
        
        targets = [targets, new_target];
        next_id = next_id + 1;
        
        fprintf('Шаг %d: Появилась новая цель ID=%d (класс: %s) на позиции [%.1f, %.1f]\n', ...
            step, new_target.id, new_target.class, new_target.pos(1), new_target.pos(2));
    end
    
    % Сбор данных только по активным целям
    active_targets = [targets.active];
    active_indices = find(active_targets);
    
    if ~isempty(active_indices)
        active_positions = vertcat(targets(active_indices).pos);
        active_ids = [targets(active_indices).id];
        active_classes = {targets(active_indices).class};
        active_priorities = [targets(active_indices).priority];
    else
        active_positions = [];
        active_ids = [];
        active_classes = {};
        active_priorities = [];
    end
    
    num_active = length(active_indices);
    
    % 2. ВЫЧИСЛЕНИЕ МАТРИЦЫ СТОИМОСТЕЙ ДЛЯ АКТИВНЫХ ЦЕЛЕЙ (РАДАР)
    cost_matrix_cell = cell(num_active, 6);
    
    for i = 1:num_active
        idx = active_indices(i);
        distance = norm(targets(idx).pos - radar_pos);
        
        % Стоимость на основе расстояния и приоритета класса
        if distance <= radar_range && distance > 0
            base_cost = radar_range / distance;
            priority_multiplier = 1 + (targets(idx).priority * 0.5);
            cost = base_cost * priority_multiplier;
        elseif distance == 0
            cost = 100;
        else
            cost = 0;
        end
        
        cost_matrix_cell(i, :) = {targets(idx).id, ...
                                  targets(idx).class, ...
                                  targets(idx).pos(1), ...
                                  targets(idx).pos(2), ...
                                  distance, ...
                                  cost};
    end
    
    % Сохранение матрицы стоимостей радара в историю
    cost_matrix_history{step} = cost_matrix_cell;
    
    % 3. ВЫЧИСЛЕНИЕ МАТРИЦЫ РАССТОЯНИЙ ЗАЩИТНИК-ЦЕЛЬ В ФОРМАТЕ "СТРОКИ-ЗАЩИТНИКИ, СТОЛБЦЫ-ЦЕЛИ"
    % Получение списка видимых целей (в радиусе действия радара)
    visible_targets = [];
    visible_target_ids = [];
    visible_target_positions = [];

    for i = 1:num_active
        idx = active_indices(i);
        distance = norm(targets(idx).pos - radar_pos);
        
        if distance <= radar_range
            visible_targets = [visible_targets, idx];
            visible_target_ids = [visible_target_ids, targets(idx).id];
            visible_target_positions = [visible_target_positions; targets(idx).pos];
        end
    end

    num_visible = length(visible_targets);

    % Создание матрицы в формате "защитники × цели"
    defender_matrix_display = cell(num_defenders + 1, num_visible + 1);

    % Заполнение заголовков
    defender_matrix_display{1, 1} = 'Защ\Цели';

    for t = 1:num_visible
        target_idx = visible_targets(t);
        defender_matrix_display{1, t+1} = sprintf('Цель%d', targets(target_idx).id);
    end

    for d = 1:num_defenders
        defender_matrix_display{d+1, 1} = sprintf('D%d', defenders(d).id);
        
        % Находим минимальное расстояние для этого защитника
        min_distance_for_defender = Inf;
        min_distance_idx = -1;
        
        for t = 1:num_visible
            target_idx = visible_targets(t);
            distance = norm(defenders(d).pos - targets(target_idx).pos);
            
            if distance < min_distance_for_defender
                min_distance_for_defender = distance;
                min_distance_idx = t;
            end
        end
        
        for t = 1:num_visible
            target_idx = visible_targets(t);
            distance = norm(defenders(d).pos - targets(target_idx).pos);
            
            % Цветовое кодирование ячеек по расстоянию
            if t == min_distance_idx
                % Ближайшая цель для этого защитника - выделяем красным
                distance_str = sprintf('<html><font color="red"><b>%.1f*</b></font></html>', distance);
            elseif distance < 50
                distance_str = sprintf('<html><font color="red">%.1f</font></html>', distance);
            elseif distance < 100
                distance_str = sprintf('<html><font color="orange">%.1f</font></html>', distance);
            else
                distance_str = sprintf('<html><font color="green">%.1f</font></html>', distance);
            end
            
            defender_matrix_display{d+1, t+1} = distance_str;
        end
    end

    % Старый формат для истории (список всех пар защитник-цель)
    defender_matrix_cell = cell(num_defenders * num_visible, 5);
    row_counter = 1;
    
    for d = 1:num_defenders
        for t = 1:num_visible
            target_idx = visible_targets(t);
            distance = norm(defenders(d).pos - targets(target_idx).pos);
            
            defender_matrix_cell{row_counter, 1} = defenders(d).id;
            defender_matrix_cell{row_counter, 2} = targets(target_idx).id;
            defender_matrix_cell{row_counter, 3} = defenders(d).pos(1);
            defender_matrix_cell{row_counter, 4} = defenders(d).pos(2);
            defender_matrix_cell{row_counter, 5} = distance;
            
            row_counter = row_counter + 1;
        end
    end
    
    % Сохранение матрицы защитник-цель в историю
    defender_matrix_history{step} = defender_matrix_cell;
    
    % 4. ОБНОВЛЕНИЕ ОКНА МАТРИЦЫ СТОИМОСТЕЙ РАДАРА
    if ishandle(figure_matrix)
        set(matrix_table, 'Data', cost_matrix_cell);
        
        if ishandle(step_text_handle)
            set(step_text_handle, 'String', ...
                sprintf('Шаг: %d/%d | Активных целей: %d', step, num_steps, num_active));
        end
    end
    
    % 5. ОБНОВЛЕНИЕ ОКНА МАТРИЦЫ ЗАЩИТНИК-ЦЕЛЬ
    if ishandle(figure_defender_matrix)
        % Обновляем заголовки столбцов
        if num_visible > 0
            column_names = defender_matrix_display(1, :);
            column_widths = num2cell([80, repmat(70, 1, num_visible)]);
        else
            column_names = {'Защитник\Цель'};
            column_widths = {80};
            defender_matrix_display = {'Нет видимых целей'};
        end
        
        set(defender_matrix_table, 'ColumnName', column_names);
        set(defender_matrix_table, 'ColumnWidth', column_widths);
        set(defender_matrix_table, 'Data', defender_matrix_display);
        
        if ishandle(defender_step_text_handle)
            set(defender_step_text_handle, 'String', ...
                sprintf('Шаг: %d/%d | Защитников: %d | Видимых целей: %d', ...
                step, num_steps, num_defenders, num_visible));
        end
    end
    
    % 6. ОБНАРУЖЕНИЕ ЦЕЛЕЙ В РАДИУСЕ ДЕЙСТВИЯ
    detected_targets_cell = {};
    for i = 1:num_active
        idx = active_indices(i);
        distance = norm(targets(idx).pos - radar_pos);
        
        if distance <= radar_range
            detected_targets_cell{end+1} = {targets(idx).id, ...
                                            targets(idx).class, ...
                                            targets(idx).pos(1), ...
                                            targets(idx).pos(2), ...
                                            distance, ...
                                            cost_matrix_cell{i, 6}};
        end
    end
    
    % Сохранение истории обнаружений
    detection_history{step} = detected_targets_cell;
    
    % 7. ОТРИСОВКА ОСНОВНОГО ОКНА С ТРЕКАМИ СОПРОВОЖДЕНИЯ И ЗАЩИТНИКАМИ
    figure(figure_main);
    cla;
    hold on;
    
    % 1. Сначала рисуем все фоновые элементы
    % Отрисовка области радара
    rectangle('Position', [radar_pos(1)-radar_range, radar_pos(2)-radar_range, ...
        2*radar_range, 2*radar_range], ...
        'Curvature', [1 1], ...
        'EdgeColor', [0 0 1 0.2], ...
        'LineWidth', 1.0, ...
        'FaceColor', [0.1 0.1 0.9 0.05]);
    
    % Круги дальности
    for r = 25:25:radar_range
        rectangle('Position', [radar_pos(1)-r, radar_pos(2)-r, 2*r, 2*r], ...
            'Curvature', [1 1], ...
            'EdgeColor', [0 0 0.7 0.15], ...
            'LineStyle', '--', ...
            'LineWidth', 0.3);
    end
    
    % Секторы сканирования
    for angle = 0:45:315
        x_end = radar_pos(1) + radar_range * cosd(angle);
        y_end = radar_pos(2) + radar_range * sind(angle);
        plot([radar_pos(1), x_end], [radar_pos(2), y_end], ...
            'Color', [0 0 0.8 0.08], ...
            'LineWidth', 0.3);
    end
    
    % Область расположения защитников (окружность радиусом 75)
    rectangle('Position', [100-75, 100-75, 2*75, 2*75], ...
        'Curvature', [1 1], ...
        'EdgeColor', [0 0.5 1 0.6], ...  % Более яркий цвет
        'LineWidth', 2.0, ...  % Толще
        'LineStyle', '--', ...
        'FaceColor', [0 0.5 1 0.08]);  % Более заметная заливка
    
    % 2. Радар (рисуется ДО защитников для лучшей видимости) - ИЗМЕНЕН НА ОКРУЖНОСТЬ
    plot(radar_pos(1), radar_pos(2), 'o', ...  % Изменено с '^' на 'o'
        'MarkerSize', 10, ...  % Увеличен размер
        'MarkerFaceColor', 'r', ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 2);
    
    text(radar_pos(1), radar_pos(2)-10, 'РАДАР', ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', ...
        'FontSize', 10, ...
        'BackgroundColor', [1 1 1 0.7]);
    
    % 3. Защитники (теперь рисуются ПОСЛЕ радара для лучшей видимости)
    for d = 1:num_defenders
        % ЯРКИЕ ЗАЩИТНИКИ С ЧЕРНОЙ ОБВОДКОЙ
        plot(defenders(d).pos(1), defenders(d).pos(2), 'o', ...
            'MarkerSize', 5, ...  % Увеличиваем размер
            'MarkerFaceColor', defenders(d).color, ...
            'MarkerEdgeColor', 'k', ...  % Черная обводка
            'LineWidth', 2);  % Толщина обводки
        
        % Текстовые метки защитников
        text(defenders(d).pos(1), defenders(d).pos(2)+7, ...
            sprintf('D%d', defenders(d).id), ...
            'FontSize', 10, ...  % Увеличиваем шрифт
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1 1 1 0.8], ...  % Более непрозрачный фон
            'Margin', 1, ...
            'FontWeight', 'bold');  % Жирный шрифт
        
        % Зона действия защитника
        rectangle('Position', [defenders(d).pos(1)-defenders(d).range, ...
                              defenders(d).pos(2)-defenders(d).range, ...
                              2*defenders(d).range, 2*defenders(d).range], ...
            'Curvature', [1 1], ...
            'EdgeColor', [0 0.5 1 0.25], ...  % Более яркий цвет
            'LineStyle', ':', ...
            'LineWidth', 0.8);  % Толще
    end
    
    % 4. Завершенные треки
    track_fields = fieldnames(track_history);
    for i = 1:length(track_fields)
        track_data = track_history.(track_fields{i});
        
        switch track_data.class
            case 'drone'
                track_color = [0 0.7 0 0.8];
            case 'aircraft'
                track_color = [0.8 0.8 0 0.8];
            case 'missile'
                track_color = [0.7 0 0 0.8];
            otherwise
                track_color = [0.5 0.5 0.5 0.8];
        end
        
        plot(track_data.track(:,1), track_data.track(:,2), ...
            'Color', track_color, ...
            'LineWidth', 1.0, ...
            'LineStyle', '--');
    end
    
    % 5. Активные треки
    for i = 1:num_active
        idx = active_indices(i);
        if isfield(targets(idx), 'history') && size(targets(idx).history, 1) > 1
            switch targets(idx).class
                case 'drone'
                    track_color = [0 1 0 0.9];
                case 'aircraft'
                    track_color = [1 1 0 0.9];
                case 'missile'
                    track_color = [1 0 0 0.9];
                otherwise
                    track_color = [0.5 0.5 0.5 0.9];
            end
            
            plot(targets(idx).history(:,1), targets(idx).history(:,2), ...
                'Color', track_color, ...
                'LineWidth', 2.5, ...
                'LineStyle', '-');
            
            if mod(step, 5) == 0 && size(targets(idx).history, 1) > 5
                plot_indices = 1:5:size(targets(idx).history, 1);
                plot(targets(idx).history(plot_indices,1), ...
                     targets(idx).history(plot_indices,2), ...
                     '.', 'Color', track_color, 'MarkerSize', 12);
            end
        end
    end
    
    % 6. Линии от защитников к видимым целям (с улучшенной видимостью)
    if num_visible > 0
        for d = 1:num_defenders
            % Находим ближайшую цель для этого защитника
            min_distance = Inf;
            closest_target_idx = -1;
            
            for t = 1:num_visible
                target_idx = visible_targets(t);
                distance = norm(defenders(d).pos - targets(target_idx).pos);
                
                if distance < min_distance
                    min_distance = distance;
                    closest_target_idx = target_idx;
                end
            end
            
            % Рисуем линию только к ближайшей цели
            if closest_target_idx > 0
                distance = min_distance;
                
                % Цвет линии в зависимости от расстояния (более яркие цвета)
                if distance < 50
                    line_color = [1 0 0 0.8];  % Красный, более непрозрачный
                    line_width = 2.0;  % Толще
                elseif distance < 100
                    line_color = [1 0.5 0 0.7];  % Оранжевый
                    line_width = 1.5;
                else
                    line_color = [0 0.5 1 0.6];  % Голубой, как защитники
                    line_width = 1.2;
                end
                
                plot([defenders(d).pos(1), targets(closest_target_idx).pos(1)], ...
                     [defenders(d).pos(2), targets(closest_target_idx).pos(2)], ...
                     'Color', line_color, ...
                     'LineWidth', line_width, ...
                     'LineStyle', '-');
            end
        end
    end
    
    % 7. Активные цели (ВСЕ ЦЕЛИ - ОКРУЖНОСТИ ЗАДАННОГО РАДИУСА)
    for i = 1:num_active
        idx = active_indices(i);
        
        % Цвет в зависимости от класса
        switch targets(idx).class
            case 'drone'
                color = [0 1 0];
            case 'aircraft'
                color = [1 1 0];
            case 'missile'
                color = [1 0 0];
            otherwise
                color = [0.5 0.5 0.5];
        end
        
        % ВСЕ ЦЕЛИ - ОКРУЖНОСТИ ЗАДАННОГО РАДИУСА
        % Рисуем окружность
        rectangle('Position', [targets(idx).pos(1)-target_radius, targets(idx).pos(2)-target_radius, ...
                               2*target_radius, 2*target_radius], ...
            'Curvature', [1 1], ...
            'EdgeColor', 'k', ...
            'FaceColor', color, ...
            'LineWidth', 1.5);
        
        % Текстовые метки целей (ID) смещаем выше
        text(targets(idx).pos(1), targets(idx).pos(2)+text_offset, ...
            num2str(targets(idx).id), ...
            'FontSize', 9, ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1 1 1 0.9], ...
            'Margin', 1, ...
            'FontWeight', 'bold');
        
        % Стрелка скорости (меньше, чтобы не перекрывать окружность)
        arrow_length = norm(targets(idx).vel) * 3;
        if arrow_length > 1
            quiver(targets(idx).pos(1), targets(idx).pos(2), ...
                   targets(idx).vel(1), targets(idx).vel(2), ...
                   0, 'k', 'LineWidth', 1.2, 'MaxHeadSize', 1.5);
        end
    end
    
    % 8. Линии обнаружения от радара (последние, чтобы не перекрывать цели)
    if ~isempty(detected_targets_cell)
        for i = 1:length(detected_targets_cell)
            target_data = detected_targets_cell{i};
            
            plot([radar_pos(1), target_data{3}], ...
                [radar_pos(2), target_data{4}], ...
                'Color', [0 1 0 0.3], ...
                'LineStyle', '--', ...
                'LineWidth', 0.8);
        end
    end
    
    % 9. Информационная панель (самая верхняя) С ДОБАВЛЕНИЕМ ИНФОРМАЦИИ О ЗАЩИТНИКАХ
    % Вычисление среднего и минимального расстояний от защитников к целям
    if ~isempty(defender_matrix_cell)
        defender_distances = cell2mat(defender_matrix_cell(:, 5));
        avg_defender_distance = mean(defender_distances);
        min_defender_distance = min(defender_distances);
        max_defender_distance = max(defender_distances);
    else
        avg_defender_distance = 0;
        min_defender_distance = 0;
        max_defender_distance = 0;
    end
    
    num_completed_tracks = length(fieldnames(track_history));
    
    info_str = sprintf(['Шаг: %d/%d\n' ...
        'Активных целей: %d (все - окружности радиусом %d)\n' ...
        'Видимых целей: %d\n' ...
        'Защитников: %d (все видны)\n' ...
        'ID защитников: D1-D%d\n' ...
        'Обнаружено радаром: %d\n' ...
        'Завершенных треков: %d\n' ...
        'Ср.расст. защитник-цель: %.1f\n' ...
        'Мин.расст. защитник-цель: %.1f'], ...
        step, num_steps, num_active, target_radius, ...
        num_visible, ...
        num_defenders, ...
        num_defenders, ...  % ID защитников
        length(detected_targets_cell), ...
        num_completed_tracks, ...
        avg_defender_distance, ...
        min_defender_distance);
    
    text(5, 195, info_str, ...
        'VerticalAlignment', 'top', ...
        'BackgroundColor', [1 1 1 0.85], ...
        'EdgeColor', [0 0 0 0.7], ...
        'Margin', 5, ...
        'FontSize', 9);
    
    title(sprintf('Радарное сопровождение целей (окружности радиусом %d) - Шаг %d', target_radius, step), ...
        'FontSize', 12, 'FontWeight', 'bold');
    
    hold off;
    drawnow;
    
    % Небольшая пауза для наблюдения
    if step < num_steps
        pause(0.1);
    end
end

%% Анализ результатов с учетом сопровождения и защитников
fprintf('\n=== ФИНАЛЬНАЯ СТАТИСТИКА С СОПРОВОЖДЕНИЕМ И ЗАЩИТНИКАМИ ===\n');
fprintf('Область сканирования: %dx%d единиц\n', area_size, area_size);
fprintf('Радиус действия радара: %d единиц\n', radar_range);
fprintf('Радиус отображения целей: %d единиц\n', target_radius);
fprintf('Максимальное количество целей одновременно: %d\n', max_targets);
fprintf('Всего создано целей за симуляцию: %d\n', length(targets));
fprintf('Количество защитников: %d\n', num_defenders);
fprintf('Область расположения защитников: окружность радиусом 75 с центром в [100,100]\n');

% Вывод позиций всех защитников
fprintf('\n=== ПОЗИЦИИ ВСЕХ ЗАЩИТНИКОВ ===\n');
for d = 1:num_defenders
    fprintf('Защитник D%d: позиция [%.1f, %.1f]\n', ...
        defenders(d).id, defenders(d).pos(1), defenders(d).pos(2));
end

% Статистика по классам целей
class_stats = struct();
for c = 1:num_classes
    class_name = class_names{c};
    class_stats.(class_name) = 0;
end

for i = 1:length(targets)
    class_name = targets(i).class;
    if isfield(class_stats, class_name)
        class_stats.(class_name) = class_stats.(class_name) + 1;
    end
end

fprintf('\n=== СТАТИСТИКА ПО КЛАССАМ ЦЕЛЕЙ ===\n');
for c = 1:num_classes
    class_name = class_names{c};
    fprintf('%s: %d целей (отображаются как окружности радиусом %d)\n', ...
        class_name, class_stats.(class_name), target_radius);
end

% Статистика по сопровождению
active_targets = [targets.active];
active_indices = find(active_targets);
num_tracked = sum(cellfun(@(x) size(x,1) > 1, {targets(active_indices).history}));
fprintf('\n=== СТАТИСТИКА СОПРОВОЖДЕНИЯ ===\n');
fprintf('Целей с историей сопровождения: %d\n', num_tracked);

% Расчет процента покрытия
coverage_map = zeros(area_size, area_size);
for i = 1:area_size
    for j = 1:area_size
        distance = sqrt((i - radar_pos(1))^2 + (j - radar_pos(2))^2);
        if distance <= radar_range
            coverage_map(i, j) = 1;
        end
    end
end

coverage_percentage = sum(coverage_map(:)) / (area_size * area_size) * 100;
fprintf('\nПокрытие радара: %.1f%% от общей площади\n', coverage_percentage);

%% Сохранение данных в файл
save('radar_tws_random_trajectories_defenders_parametrized.mat', 'cost_matrix_history', 'detection_history', ...
    'defender_matrix_history', 'defenders', 'targets', 'radar_range', 'area_size', ...
    'radar_pos', 'target_classes', 'target_radius');
fprintf('\nДанные сохранены в файл: radar_tws_random_trajectories_defenders_parametrized.mat\n');

%% Вывод последней матрицы стоимостей радара
fprintf('\n=== ПОСЛЕДНЯЯ МАТРИЦА СТОИМОСТЕЙ РАДАРА (шаг %d) ===\n', num_steps);
if ~isempty(cost_matrix_history{end})
    fprintf('%-5s %-10s %-8s %-8s %-12s %-10s\n', ...
        'ID', 'Класс', 'X', 'Y', 'Расстояние', 'Стоимость');
    fprintf('%-5s %-10s %-8s %-8s %-12s %-10s\n', ...
        '---', '-----', '---', '---', '----------', '---------');
    
    for i = 1:size(cost_matrix_history{end}, 1)
        row = cost_matrix_history{end}(i, :);
        fprintf('%-5d %-10s %-8.1f %-8.1f %-12.2f %-10.2f\n', ...
            row{1}, row{2}, row{3}, row{4}, row{5}, row{6});
    end
else
    fprintf('Нет активных целей на последнем шаге\n');
end

%% Вывод последней матрицы защитник-цель в новом формате
fprintf('\n=== ПОСЛЕДНЯЯ МАТРИЦА ЗАЩИТНИК-ЦЕЛЬ (шаг %d, матричный формат) ===\n', num_steps);

% Получаем данные для последнего шага
if ~isempty(defender_matrix_history{end})
    % Создаем заголовки
    fprintf('\nМатрица расстояний (защитники × цели):\n');
    fprintf('%-12s', 'Защ\Цели');
    
    % Извлекаем уникальные ID защитников и целей из истории
    data = defender_matrix_history{end};
    defender_ids = unique(cell2mat(data(:, 1)));
    target_ids = unique(cell2mat(data(:, 2)));
    
    % Выводим заголовки целей
    for t = 1:length(target_ids)
        fprintf('%-12s', sprintf('Цель%d', target_ids(t)));
    end
    fprintf('\n%s\n', repmat('-', 12 * (length(target_ids) + 1)));
    
    % Выводим данные для каждого защитника
    for d_idx = 1:length(defender_ids)
        defender_id = defender_ids(d_idx);
        fprintf('%-12s', sprintf('D%d', defender_id));
        
        % Находим минимальное расстояние для этого защитника
        defender_rows = cell2mat(data(:, 1)) == defender_id;
        defender_distances = cell2mat(data(defender_rows, 5));
        min_distance = min(defender_distances);
        
        for t_idx = 1:length(target_ids)
            target_id = target_ids(t_idx);
            
            % Находим расстояние для этой пары защитник-цель
            row_idx = find(cell2mat(data(:, 1)) == defender_id & cell2mat(data(:, 2)) == target_id);
            
            if ~isempty(row_idx)
                distance = data{row_idx, 5};
                
                % Проверяем, является ли это минимальным расстоянием для защитника
                if abs(distance - min_distance) < 0.01
                    fprintf('%-12s', sprintf('%.1f*', distance));
                else
                    fprintf('%-12.1f', distance);
                end
            else
                fprintf('%-12s', '---');
            end
        end
        fprintf('\n');
    end
    
    % Легенда
    fprintf('\n* - ближайшая цель для защитника\n');
else
    fprintf('Нет видимых целей для защиты на последнем шаге\n');
end

%% Анализ эффективности защитников
fprintf('\n=== АНАЛИЗ ЭФФЕКТИВНОСТИ ЗАЩИТНИКОВ ===\n');

% Собираем все расстояния защитник-цель за всю симуляцию
all_defender_distances = [];
for step = 1:num_steps
    if ~isempty(defender_matrix_history{step})
        step_distances = cell2mat(defender_matrix_history{step}(:, 5));
        all_defender_distances = [all_defender_distances; step_distances];
    end
end

if ~isempty(all_defender_distances)
    fprintf('Общее количество измерений расстояний: %d\n', length(all_defender_distances));
    fprintf('Среднее расстояние защитник-цель за симуляцию: %.2f\n', mean(all_defender_distances));
    fprintf('Минимальное расстояние защитник-цель: %.2f\n', min(all_defender_distances));
    fprintf('Максимальное расстояние защитник-цель: %.2f\n', max(all_defender_distances));
    fprintf('Стандартное отклонение расстояний: %.2f\n', std(all_defender_distances));
else
    fprintf('Не было видимых целей для защиты в течение симуляции\n');
end

fprintf('\n=== МОДЕЛЬ ЗАВЕРШЕНА ===\n');
%fprintf('Все цели отображаются как окружности радиусом %d!\n', target_radius);
fprintf('Для изменения размера целей измените переменную target_radius в начале кода.\n');
fprintf('Текущий размер целей: радиус = %d единиц\n', target_radius);
fprintf('Смещение текстовых меток: %d единиц от центра цели\n', text_offset);