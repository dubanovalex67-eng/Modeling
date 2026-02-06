%% Модель работы радара на плоскости с динамической матрицей стоимостей
%% Включено сопровождение целей (Track-While-Scan) с отрисовкой треков
%% Случайные (непрямолинейные) траектории целей
%% Добавлены защитники и матрица расстояний защитник-цель
%% РАЗМЕР ЦЕЛИ ПАРАМЕТРИЗИРОВАН
%% РАСПРЕДЕЛЕНИЕ ЗАЩИТНИКОВ ПО ЦЕЛЯМ С ИСПОЛЬЗОВАНИЕМ ЖАДНОГО АЛГОРИТМА
%% ОДНО ОКНО ДЛЯ ДИНАМИЧЕСКОГО ОТОБРАЖЕНИЯ РАСПРЕДЕЛЕНИЯ
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
    'Name', sprintf('Модель радара (радиус целей: %d)', target_radius));
ax_main = axes('Parent', figure_main);
hold(ax_main, 'on'); grid(ax_main, 'on'); axis(ax_main, 'equal');
xlim(ax_main, [0 area_size]); ylim(ax_main, [0 area_size]);
xlabel(ax_main, 'X координата'); ylabel(ax_main, 'Y координата');
title(ax_main, sprintf('Сопровождение целей (радиус целей: %d)', target_radius));

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

%% Создание ЕДИНОГО окна для отображения распределения защитников по целям
figure_assignment = figure('Position', [2300, 100, 700, 700], ...
    'Name', 'Распределение защитников по целям (жадный алгоритм) - Динамическое отображение');
ax_assignment = axes('Parent', figure_assignment);
hold(ax_assignment, 'on'); grid(ax_assignment, 'on'); axis(ax_assignment, 'equal');
xlim(ax_assignment, [0 area_size]); ylim(ax_assignment, [0 area_size]);
xlabel(ax_assignment, 'X координата'); ylabel(ax_assignment, 'Y координата');

% Текстовые элементы для информации
assignment_step_text = uicontrol('Parent', figure_assignment, 'Style', 'text', ...
    'String', 'Шаг: 1', ...
    'Position', [280, 10, 150, 30], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.9 0.9 0.9]);

assignment_info_text = uicontrol('Parent', figure_assignment, 'Style', 'text', ...
    'String', 'Инициализация...', ...
    'Position', [20, 650, 660, 40], ...
    'FontSize', 9, ...
    'BackgroundColor', [0.95 0.95 0.95], ...
    'HorizontalAlignment', 'left');

%% Инициализация матриц для сохранения данных
num_steps = 100;
detection_history = cell(num_steps, 1);
cost_matrix_history = cell(num_steps, 1);  % История матриц стоимостей радара
defender_matrix_history = cell(num_steps, 1);  % История матриц защитник-цель
assignment_history = cell(num_steps, 1);  % История распределений защитников
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
    
    % 3. ВЫЧИСЛЕНИЕ МАТРИЦЫ РАССТОЯНИЙ ЗАЩИТНИК-ЦЕЛЬ И РАСПРЕДЕЛЕНИЕ С ИСПОЛЬЗОВАНИЕМ ЖАДНОГО АЛГОРИТМА
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
    
    % Распределение защитников по видимым целям с использованием жадного алгоритма
    assignment_result = zeros(num_defenders, 1); % Результат распределения
    
    if num_visible > 0 && num_defenders > 0
        % Формирование матрицы стоимостей для распределения
        % В качестве стоимости используем расстояние от защитника до цели
        % Если цель вне радиуса действия защитника, устанавливаем большую стоимость
        cost_matrix_assignment = zeros(num_defenders, num_visible);
        
        for d = 1:num_defenders
            for t = 1:num_visible
                target_idx = visible_targets(t);
                distance = norm(defenders(d).pos - targets(target_idx).pos);
                
                % Если цель в пределах радиуса действия защитника
                if distance <= defenders(d).range
                    cost_matrix_assignment(d, t) = distance; % Меньшее расстояние = меньшая стоимость
                else
                    cost_matrix_assignment(d, t) = Inf; % Недостижимая цель
                end
            end
        end
        
        % Вызов функции жадного алгоритма (замените на свою реализацию если необходимо)
        try
            % Временная заглушка - используем простой жадный алгоритм
            assignment_result = simple_greedy_assignment(cost_matrix_assignment);
        catch ME
            fprintf('Ошибка при вызове жадного алгоритма: %s\n', ME.message);
            assignment_result = zeros(num_defenders, 1);
        end
        
        % Сохраняем результат распределения в историю
        assignment_history{step} = struct(...
            'defender_ids', [defenders.id], ...
            'target_ids', visible_target_ids, ...
            'assignment', assignment_result, ...
            'cost_matrix', cost_matrix_assignment);
    else
        % Нет видимых целей или защитников
        assignment_history{step} = struct(...
            'defender_ids', [defenders.id], ...
            'target_ids', [], ...
            'assignment', zeros(num_defenders, 1), ...
            'cost_matrix', []);
    end
    
    % Создание матрицы в формате "защитники × цели" для отображения
    defender_matrix_display = cell(num_defenders + 1, num_visible + 1);

    % Заполнение заголовков
    defender_matrix_display{1, 1} = 'Защ\Цели';

    for t = 1:num_visible
        target_idx = visible_targets(t);
        defender_matrix_display{1, t+1} = sprintf('Цель%d', targets(target_idx).id);
    end

    for d = 1:num_defenders
        defender_matrix_display{d+1, 1} = sprintf('D%d', defenders(d).id);
        
        for t = 1:num_visible
            target_idx = visible_targets(t);
            distance = norm(defenders(d).pos - targets(target_idx).pos);
            
            % Проверяем, назначена ли эта цель данному защитнику
            if assignment_result(d) == t
                % Цель назначена этому защитнику - выделяем жирным
                if distance <= defenders(d).range
                    distance_str = sprintf('<html><font color="red"><b>%.1f*</b></font></html>', distance);
                else
                    distance_str = sprintf('<html><font color="red"><b>%.1f!</b></font></html>', distance);
                end
            else
                % Цель не назначена
                if distance < 50
                    distance_str = sprintf('<html><font color="red">%.1f</font></html>', distance);
                elseif distance < 100
                    distance_str = sprintf('<html><font color="orange">%.1f</font></html>', distance);
                else
                    distance_str = sprintf('<html><font color="green">%.1f</font></html>', distance);
                end
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
                sprintf('Шаг: %d/%d | Защитников: %d | Видимых целей: %d | Назначений: %d', ...
                step, num_steps, num_defenders, num_visible, sum(assignment_result > 0)));
        end
    end
    
    % 6. ОБНОВЛЕНИЕ ЕДИНОГО ОКНА РАСПРЕДЕЛЕНИЯ ЗАЩИТНИКОВ ПО ЦЕЛЯМ
    if ishandle(figure_assignment)
        % Очищаем предыдущий график
        cla(ax_assignment);
        
        % Устанавливаем заголовок
        title(ax_assignment, sprintf('Распределение защитников по целям - Шаг %d', step), ...
            'FontSize', 12, 'FontWeight', 'bold');
        
        % Обновляем текстовые элементы
        if ishandle(assignment_step_text)
            set(assignment_step_text, 'String', ...
                sprintf('Шаг: %d/%d', step, num_steps));
        end
        
        if ishandle(assignment_info_text)
            num_assignments = sum(assignment_result > 0);
            set(assignment_info_text, 'String', ...
                sprintf('Защитников: %d | Видимых целей: %d | Назначений: %d | Свободных защитников: %d', ...
                num_defenders, num_visible, num_assignments, ...
                num_defenders - num_assignments));
        end
        
        % Рисуем радар
        plot(ax_assignment, radar_pos(1), radar_pos(2), 'o', ...
            'MarkerSize', 10, ...
            'MarkerFaceColor', 'r', ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 2);
        
        % Рисуем границу видимости радара (красная тонкая сплошная линия)
        rectangle(ax_assignment, 'Position', [radar_pos(1)-radar_range, radar_pos(2)-radar_range, ...
                                              2*radar_range, 2*radar_range], ...
            'Curvature', [1 1], ...
            'EdgeColor', 'r', ...
            'LineStyle', '-', ...
            'LineWidth', 1.5); % Толщина как у линий защитников
        
        % Рисуем защитников
        for d = 1:num_defenders
            % ЯРКИЕ ЗАЩИТНИКИ С ЧЕРНОЙ ОБВОДКОЙ
            plot(ax_assignment, defenders(d).pos(1), defenders(d).pos(2), 'o', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', defenders(d).color, ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 2);
            
            % Текстовые метки защитников
            text(ax_assignment, defenders(d).pos(1), defenders(d).pos(2)+7, ...
                sprintf('D%d', defenders(d).id), ...
                'FontSize', 10, ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1 1 1 0.9], ...
                'Margin', 1, ...
                'FontWeight', 'bold');
            
            % Зона действия защитника
            rectangle(ax_assignment, 'Position', [defenders(d).pos(1)-defenders(d).range, ...
                                                  defenders(d).pos(2)-defenders(d).range, ...
                                                  2*defenders(d).range, 2*defenders(d).range], ...
                'Curvature', [1 1], ...
                'EdgeColor', [0 0.5 1 0.6], ...
                'LineStyle', '-', ...
                'LineWidth', 1.8);
        end
        
        % Рисуем видимые цели
        for t = 1:num_visible
            target_idx = visible_targets(t);
            
            % Цвет в зависимости от класса
            switch targets(target_idx).class
                case 'drone'
                    color = [0 1 0];
                case 'aircraft'
                    color = [1 1 0];
                case 'missile'
                    color = [1 0 0];
                otherwise
                    color = [0.5 0.5 0.5];
            end
            
            % Рисуем окружность цели
            rectangle(ax_assignment, 'Position', [targets(target_idx).pos(1)-target_radius, targets(target_idx).pos(2)-target_radius, ...
                                                   2*target_radius, 2*target_radius], ...
                'Curvature', [1 1], ...
                'EdgeColor', 'k', ...
                'FaceColor', color, ...
                'LineWidth', 1.5);
            
            % Текстовые метки целей
            text(ax_assignment, targets(target_idx).pos(1), targets(target_idx).pos(2)+text_offset, ...
                sprintf('T%d', targets(target_idx).id), ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1 1 1 0.9], ...
                'Margin', 1, ...
                'FontWeight', 'bold');
        end
        
        % Рисуем линии от защитников к назначенным целям
        for d = 1:num_defenders
            if assignment_result(d) > 0
                t = assignment_result(d);
                target_idx = visible_targets(t);
                
                % Определяем цвет линии в зависимости от расстояния
                distance = norm(defenders(d).pos - targets(target_idx).pos);
                if distance <= defenders(d).range
                    line_color = [0 0.8 0]; % Зеленый для целей в радиусе действия
                    line_style = '-';
                    line_width = 2;
                else
                    line_color = [1 0 0]; % Красный для недостижимых целей
                    line_style = '--';
                    line_width = 1.5;
                end
                
                % Рисуем линию
                plot(ax_assignment, [defenders(d).pos(1), targets(target_idx).pos(1)], ...
                     [defenders(d).pos(2), targets(target_idx).pos(2)], ...
                     'Color', line_color, ...
                     'LineStyle', line_style, ...
                     'LineWidth', line_width);
                
                % Подписываем расстояние на линии
                mid_x = (defenders(d).pos(1) + targets(target_idx).pos(1)) / 2;
                mid_y = (defenders(d).pos(2) + targets(target_idx).pos(2)) / 2;
                text(ax_assignment, mid_x, mid_y, ...
                    sprintf('%.1f', distance), ...
                    'FontSize', 8, ...
                    'BackgroundColor', [1 1 1 0.8], ...
                    'HorizontalAlignment', 'center');
            end
        end
        
        drawnow;
    end
    
    % 7. ОБНАРУЖЕНИЕ ЦЕЛЕЙ В РАДИУСЕ ДЕЙСТВИЯ
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
    
    % 8. ОТРИСОВКА ОСНОВНОГО ОКНА С ТРЕКАМИ СОПРОВОЖДЕНИЯ И ЗАЩИТНИКАМИ
    figure(figure_main);
    cla(ax_main);
    
    % 1. Сначала рисуем все фоновые элементы
    % Отрисовка области радара
    rectangle(ax_main, 'Position', [radar_pos(1)-radar_range, radar_pos(2)-radar_range, ...
        2*radar_range, 2*radar_range], ...
        'Curvature', [1 1], ...
        'EdgeColor', [0 0 1 0.2], ...
        'LineWidth', 1.0, ...
        'FaceColor', [0.1 0.1 0.9 0.05]);
    
    % Круги дальности
    for r = 25:25:radar_range
        rectangle(ax_main, 'Position', [radar_pos(1)-r, radar_pos(2)-r, 2*r, 2*r], ...
            'Curvature', [1 1], ...
            'EdgeColor', [0 0 0.7 0.15], ...
            'LineStyle', '--', ...
            'LineWidth', 0.3);
    end
    
    % Секторы сканирования
    for angle = 0:45:315
        x_end = radar_pos(1) + radar_range * cosd(angle);
        y_end = radar_pos(2) + radar_range * sind(angle);
        plot(ax_main, [radar_pos(1), x_end], [radar_pos(2), y_end], ...
            'Color', [0 0 0.8 0.08], ...
            'LineWidth', 0.3);
    end
    
    % Область расположения защитников (окружность радиусом 75)
    rectangle(ax_main, 'Position', [100-75, 100-75, 2*75, 2*75], ...
        'Curvature', [1 1], ...
        'EdgeColor', [0 0.5 1 0.6], ...
        'LineWidth', 2.0, ...
        'LineStyle', '--', ...
        'FaceColor', [0 0.5 1 0.08]);
    
    % 2. Радар
    plot(ax_main, radar_pos(1), radar_pos(2), 'o', ...
        'MarkerSize', 10, ...
        'MarkerFaceColor', 'r', ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 2);
    
    text(ax_main, radar_pos(1), radar_pos(2)-10, 'РАДАР', ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', ...
        'FontSize', 10, ...
        'BackgroundColor', [1 1 1 0.7]);
    
    % 3. Защитники
    for d = 1:num_defenders
        plot(ax_main, defenders(d).pos(1), defenders(d).pos(2), 'o', ...
            'MarkerSize', 5, ...
            'MarkerFaceColor', defenders(d).color, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 2);
        
        text(ax_main, defenders(d).pos(1), defenders(d).pos(2)+7, ...
            sprintf('D%d', defenders(d).id), ...
            'FontSize', 10, ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1 1 1 0.8], ...
            'Margin', 1, ...
            'FontWeight', 'bold');
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
        
        plot(ax_main, track_data.track(:,1), track_data.track(:,2), ...
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
            
            plot(ax_main, targets(idx).history(:,1), targets(idx).history(:,2), ...
                'Color', track_color, ...
                'LineWidth', 2.5, ...
                'LineStyle', '-');
            
            if mod(step, 5) == 0 && size(targets(idx).history, 1) > 5
                plot_indices = 1:5:size(targets(idx).history, 1);
                plot(ax_main, targets(idx).history(plot_indices,1), ...
                     targets(idx).history(plot_indices,2), ...
                     '.', 'Color', track_color, 'MarkerSize', 12);
            end
        end
    end
    
    % 6. Линии от защитников к назначенным целям
    if num_visible > 0
        for d = 1:num_defenders
            if assignment_result(d) > 0
                t = assignment_result(d);
                target_idx = visible_targets(t);
                distance = norm(defenders(d).pos - targets(target_idx).pos);
                
                if distance <= defenders(d).range
                    line_color = [0 0.8 0 0.8];
                    line_width = 2.0;
                else
                    line_color = [1 0 0 0.7];
                    line_width = 1.5;
                end
                
                plot(ax_main, [defenders(d).pos(1), targets(target_idx).pos(1)], ...
                     [defenders(d).pos(2), targets(target_idx).pos(2)], ...
                     'Color', line_color, ...
                     'LineWidth', line_width, ...
                     'LineStyle', '-');
            end
        end
    end
    
    % 7. Активные цели
    for i = 1:num_active
        idx = active_indices(i);
        
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
        
        rectangle(ax_main, 'Position', [targets(idx).pos(1)-target_radius, targets(idx).pos(2)-target_radius, ...
                                       2*target_radius, 2*target_radius], ...
            'Curvature', [1 1], ...
            'EdgeColor', 'k', ...
            'FaceColor', color, ...
            'LineWidth', 1.5);
        
        text(ax_main, targets(idx).pos(1), targets(idx).pos(2)+text_offset, ...
            num2str(targets(idx).id), ...
            'FontSize', 9, ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1 1 1 0.9], ...
            'Margin', 1, ...
            'FontWeight', 'bold');
        
        % Стрелка скорости
        arrow_length = norm(targets(idx).vel) * 3;
        if arrow_length > 1
            quiver(ax_main, targets(idx).pos(1), targets(idx).pos(2), ...
                   targets(idx).vel(1), targets(idx).vel(2), ...
                   0, 'k', 'LineWidth', 1.2, 'MaxHeadSize', 1.5);
        end
    end
    
    % 8. Линии обнаружения от радара
    if ~isempty(detected_targets_cell)
        for i = 1:length(detected_targets_cell)
            target_data = detected_targets_cell{i};
            
            plot(ax_main, [radar_pos(1), target_data{3}], ...
                [radar_pos(2), target_data{4}], ...
                'Color', [0 1 0 0.3], ...
                'LineStyle', '--', ...
                'LineWidth', 0.8);
        end
    end
    
    % 9. Информационная панель
    num_assignments = sum(assignment_result > 0);
    num_assignments_in_range = 0;
    
    for d = 1:num_defenders
        if assignment_result(d) > 0
            t = assignment_result(d);
            target_idx = visible_targets(t);
            distance = norm(defenders(d).pos - targets(target_idx).pos);
            if distance <= defenders(d).range
                num_assignments_in_range = num_assignments_in_range + 1;
            end
        end
    end
    
    num_completed_tracks = length(fieldnames(track_history));
    
    info_str = sprintf('Шаг: %d/%d\nАктивных целей: %d (радиус: %d)\nВидимых целей: %d\nЗащитников: %d\nНазначений (жадный): %d\nНазначений в радиусе: %d\nОбнаружено радаром: %d\nЗавершенных треков: %d', ...
        step, num_steps, num_active, target_radius, ...
        num_visible, ...
        num_defenders, ...
        num_assignments, ...
        num_assignments_in_range, ...
        length(detected_targets_cell), ...
        num_completed_tracks);
    
    text(ax_main, 5, 195, info_str, ...
        'VerticalAlignment', 'top', ...
        'BackgroundColor', [1 1 1 0.85], ...
        'EdgeColor', [0 0 0 0.7], ...
        'Margin', 5, ...
        'FontSize', 9);
    
    title(ax_main, sprintf('Радарное сопровождение целей (радиус целей: %d) - Шаг %d', target_radius, step), ...
        'FontSize', 12, 'FontWeight', 'bold');
    
    drawnow;
    
    % Небольшая пауза для наблюдения
    if step < num_steps
        pause(0.1);
    end
end

%% Анализ результатов
fprintf('\n=== ФИНАЛЬНАЯ СТАТИСТИКА ===\n');
fprintf('Область сканирования: %dx%d\n', area_size, area_size);
fprintf('Радиус действия радара: %d\n', radar_range);
fprintf('Радиус отображения целей: %d\n', target_radius);
fprintf('Максимальное количество целей: %d\n', max_targets);
fprintf('Всего создано целей: %d\n', length(targets));
fprintf('Количество защитников: %d\n', num_defenders);

%% Сохранение данных в файл
save('radar_tws_random_trajectories_defenders_greedy_single_window.mat', ...
    'cost_matrix_history', 'detection_history', 'defender_matrix_history', ...
    'assignment_history', 'defenders', 'targets', 'radar_range', 'area_size', ...
    'radar_pos', 'target_classes', 'target_radius');
fprintf('\nДанные сохранены в файл\n');

%% Простая реализация жадного алгоритма распределения
function assignment = simple_greedy_assignment(cost_matrix)
    % Простой жадный алгоритм: каждый защитник выбирает ближайшую доступную цель
    [num_defenders, num_targets] = size(cost_matrix);
    assignment = zeros(num_defenders, 1);
    
    % Копируем матрицу стоимостей
    temp_costs = cost_matrix;
    
    for d = 1:num_defenders
        % Находим минимальную стоимость для этого защитника
        [min_cost, target_idx] = min(temp_costs(d, :));
        
        if min_cost < Inf
            assignment(d) = target_idx;
            % Помечаем эту цель как занятую для других защитников
            temp_costs(:, target_idx) = Inf;
        end
    end
end