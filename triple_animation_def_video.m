function triple_animation_def_video()
    % Графическое окно с осями [-2000,2000], зум, панорамирование и построение линий
    %   (сплайна, хищников, жертв, защитников, радаров хищников, радаров жертв)
    %   Добавлена логика защитников: при пересечении хищником Red Line к нему
    %   устремляется ближайший свободный защитник (скорость 15-25). Дуэль 50/50.
    %
    %   Меню: Файл, Red Line (Сплайн, Закончить сплайн, Узлы сплайна невидимы, Записать в файл, Вставить из файла,
    %         Сплайн Compression Line, Закончить Compression Line, Узлы Compression Line невидимы, Записать в файл Compression Line, Вставить из файла Compression Line,
    %         Расстояния жертв до Compression Line, Жертвы с расстоянием до Compression Line < 100),
    %   Хищники (Вставить хищника, Записать хищников в файл, Вставить хищников из файла,
    %            Вставить радар хищников, Записать радары хищников в файл, Вставить радары хищников из файла,
    %            Граница зоны действия радаров хищников, Матрица стоимостей в ЗДР хищников ->
    %                Расстояния хищник-жертва в ЗДР хищников, Расстояния от жертв до Compression Line < 100,
    %            Начальное распределение хищников -> Венгерский алгоритм (Х) -> Матрица стоимостей ЗДР (В), Матрица стоимостей CL (В),
    %                                               Жадный алгоритм (Х), Генетический алгоритм (Х),
    %            Анимация (нач) (Х) -> Венгерский (Х) -> ЗДР (Х), CL (Х),
    %                           Жадный (Х), Генетический (Х)),
    %   Жертвы (Вставить жертву, Записать жертвы в файл, Вставить жертвы из файла,
    %            Вставить радар жертвы, Записать радары жертв в файл, Вставить радары жертв из файла,
    %            Граница зоны действия радаров жертв),
    %   Защитники (Вставить защитника, Записать защитников в файл, Вставить защитников из файла).

    clc; clear; close all;

    % --- Создание фигуры и осей ---
    fig = figure('Name', 'Графическое окно со стандартным меню', ...
                 'NumberTitle', 'off', ...
                 'Position', [200 200 800 600], ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none');

    ax = axes('Parent', fig, 'Units', 'normalized', ...
              'Position', [0.1 0.1 0.8 0.8]);

    % Настройка пределов и вида
    xlim(ax, [-2000, 2000]);
    ylim(ax, [-2000, 2000]);
    axis(ax, 'equal');
    xlim(ax, [-2000, 2000]);
    ylim(ax, [-2000, 2000]);
    grid(ax, 'on');
    xlabel(ax, 'X');
    ylabel(ax, 'Y');

    % --- Рисование осей координат ---
    draw_axes_lines();

    % --- Инициализация переменных для панорамирования ---
    is_panning = false;
    pan_start_point = [0, 0];
    pan_start_limits = [0, 0, 0, 0];

    % --- Инициализация данных для сплайна (Red Line) ---
    node_points = [];           % красные точки (сплайн)
    spline_line = [];
    point_markers = [];
    add_node_mode = false;
    show_nodes = true;          % флаг видимости узлов сплайна

    % --- Инициализация данных для Compression Line (синий сплайн) ---
    comp_node_points = [];      % синие точки (узлы Compression Line)
    comp_spline_line = [];
    comp_point_markers = [];
    add_comp_node_mode = false;
    show_comp_nodes = true;     % флаг видимости узлов Compression Line

    % --- Инициализация данных для хищников (красные точки, без линий) ---
    predator_points = [];       % красные точки
    predator_markers = [];
    add_predator_mode = false;

    % --- Инициализация данных для жертв (синие точки) ---
    prey_points = [];
    prey_markers = [];
    add_prey_mode = false;

    % --- Инициализация данных для защитников (зелёные точки) ---
    defender_points = [];
    defender_markers = [];
    add_defender_mode = false;

    % --- Инициализация данных для радаров хищников (залитые круги радиусом 300) ---
    radar_centers = [];         % центры радаров (N x 2)
    radar_handles = [];         % дескрипторы залитых кругов
    add_radar_mode = false;     % режим добавления радара
    show_predator_radar_borders = false;  % флаг отображения границы радаров хищников

    % --- Инициализация данных для радаров жертв (залитые круги радиусом 150) ---
    prey_radar_centers = [];     % центры радаров жертв (N x 2)
    prey_radar_handles = [];     % дескрипторы залитых кругов
    add_prey_radar_mode = false; % режим добавления радара жертвы
    show_prey_radar_borders = false;  % флаг отображения границ радаров жертв

    % --- Линии назначений (венгерский алгоритм) ---
    assignment_lines = [];       % массив дескрипторов линий

    % --- Текущее распределение хищников по жертвам (для анимации) ---
    current_assignment_zdor = [];     % для ЗДР
    current_assignment_cl = [];       % для CL

    % --- Назначение обработчиков мыши ---
    set(fig, 'WindowScrollWheelFcn', @zoom_callback);
    set(fig, 'WindowButtonDownFcn', @button_down);
    set(fig, 'WindowButtonMotionFcn', @pan_move);
    set(fig, 'WindowButtonUpFcn', @pan_stop);

    % --- Создание меню ---
    file_menu = uimenu(fig, 'Label', 'Файл');
    uimenu(file_menu, 'Label', 'Новый', 'Callback', @(~,~) new_file());
    uimenu(file_menu, 'Label', 'Открыть...', 'Callback', @(~,~) open_file());
    uimenu(file_menu, 'Label', 'Сохранить', 'Callback', @(~,~) save_file());
    uimenu(file_menu, 'Label', 'Сохранить данные...', 'Callback', @(~,~) save_all_data());
    uimenu(file_menu, 'Label', 'Загрузить данные...', 'Callback', @(~,~) load_all_data());
    uimenu(file_menu, 'Label', 'Выход', 'Callback', @(~,~) close(fig));

    red_menu = uimenu(fig, 'Label', 'Red Line');
    uimenu(red_menu, 'Label', 'Сплайн', 'Callback', @(~,~) toggle_add_node_mode());
    uimenu(red_menu, 'Label', 'Закончить сплайн', 'Callback', @(~,~) finish_spline());
    uimenu(red_menu, 'Label', 'Узлы сплайна невидимы', 'Callback', @(~,~) toggle_nodes_visibility());
    uimenu(red_menu, 'Label', 'Записать в файл', 'Callback', @(~,~) save_nodes_to_file());
    uimenu(red_menu, 'Label', 'Вставить из файла', 'Callback', @(~,~) load_nodes_from_file());

    uimenu(red_menu, 'Label', 'Сплайн Compression Line', 'Callback', @(~,~) toggle_add_comp_node_mode());
    uimenu(red_menu, 'Label', 'Закончить Compression Line', 'Callback', @(~,~) finish_comp_spline());
    uimenu(red_menu, 'Label', 'Узлы Compression Line невидимы', 'Callback', @(~,~) toggle_comp_nodes_visibility());
    uimenu(red_menu, 'Label', 'Записать в файл Compression Line', 'Callback', @(~,~) save_comp_nodes_to_file());
    uimenu(red_menu, 'Label', 'Вставить из файла Compression Line', 'Callback', @(~,~) load_comp_nodes_from_file());

    uimenu(red_menu, 'Label', 'Расстояния жертв до Compression Line', 'Callback', @(~,~) prey_to_compression_distances());
    uimenu(red_menu, 'Label', 'Жертвы с расстоянием до Compression Line < 100', 'Callback', @(~,~) prey_within_100_of_compression());

    pred_menu = uimenu(fig, 'Label', 'Хищники');
    uimenu(pred_menu, 'Label', 'Вставить хищника', 'Callback', @(~,~) toggle_add_predator_mode());
    uimenu(pred_menu, 'Label', 'Записать хищников в файл', 'Callback', @(~,~) save_predator_to_file());
    uimenu(pred_menu, 'Label', 'Вставить хищников из файла', 'Callback', @(~,~) load_predator_from_file());
    uimenu(pred_menu, 'Label', 'Вставить радар хищников', 'Callback', @(~,~) toggle_add_radar_mode());
    uimenu(pred_menu, 'Label', 'Записать радары хищников в файл', 'Callback', @(~,~) save_radars_to_file());
    uimenu(pred_menu, 'Label', 'Вставить радары хищников из файла', 'Callback', @(~,~) load_radars_from_file());
    border_pred_menu = uimenu(pred_menu, 'Label', 'Граница зоны действия радаров хищников', ...
                         'Checked', 'off', 'Callback', @(~,~) toggle_predator_radar_borders());
    cost_matrix_menu = uimenu(pred_menu, 'Label', 'Матрица стоимостей в ЗДР хищников');
    uimenu(cost_matrix_menu, 'Label', 'Расстояния хищник-жертва в ЗДР хищников', ...
           'Callback', @(~,~) predator_prey_distances());
    uimenu(cost_matrix_menu, 'Label', 'Расстояния от жертв до Compression Line < 100', ...
           'Callback', @(~,~) predator_prey_distances_compression_100());

    init_distrib_menu = uimenu(pred_menu, 'Label', 'Начальное распределение хищников');
    hungarian_menu = uimenu(init_distrib_menu, 'Label', 'Венгерский алгоритм (Х)');
    uimenu(hungarian_menu, 'Label', 'Матрица стоимостей ЗДР (В)', ...
           'Callback', @(~,~) hungarian_zdor_assignment());
    uimenu(hungarian_menu, 'Label', 'Матрица стоимостей CL (В)', ...
           'Callback', @(~,~) hungarian_cl_assignment());
    uimenu(init_distrib_menu, 'Label', 'Жадный алгоритм (Х)', ...
           'Callback', @(~,~) disp('Жадный алгоритм (Х) пока не реализован.'));
    uimenu(init_distrib_menu, 'Label', 'Генетический алгоритм (Х)', ...
           'Callback', @(~,~) disp('Генетический алгоритм (Х) пока не реализован.'));

    anim_menu = uimenu(pred_menu, 'Label', 'Анимация (нач) (Х)');
    venegr_anim = uimenu(anim_menu, 'Label', 'Венгерский (Х)');
    uimenu(venegr_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_hungarian_zdor());
    uimenu(venegr_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_hungarian_cl());
    uimenu(anim_menu, 'Label', 'Жадный (Х)', 'Callback', @(~,~) disp('Анимация: Жадный (Х) - заглушка'));
    uimenu(anim_menu, 'Label', 'Генетический (Х)', 'Callback', @(~,~) disp('Анимация: Генетический (Х) - заглушка'));

    prey_menu = uimenu(fig, 'Label', 'Жертвы');
    uimenu(prey_menu, 'Label', 'Вставить жертву', 'Callback', @(~,~) toggle_add_prey_mode());
    uimenu(prey_menu, 'Label', 'Записать жертвы в файл', 'Callback', @(~,~) save_prey_to_file());
    uimenu(prey_menu, 'Label', 'Вставить жертвы из файла', 'Callback', @(~,~) load_prey_from_file());
    uimenu(prey_menu, 'Label', 'Вставить радар жертвы', 'Callback', @(~,~) toggle_add_prey_radar_mode());
    uimenu(prey_menu, 'Label', 'Записать радары жертв в файл', 'Callback', @(~,~) save_prey_radars_to_file());
    uimenu(prey_menu, 'Label', 'Вставить радары жертв из файла', 'Callback', @(~,~) load_prey_radars_from_file());
    border_prey_menu = uimenu(prey_menu, 'Label', 'Граница зоны действия радаров жертв', ...
                         'Checked', 'off', 'Callback', @(~,~) toggle_prey_radar_borders());

    defender_menu = uimenu(fig, 'Label', 'Защитники');
    uimenu(defender_menu, 'Label', 'Вставить защитника', 'Callback', @(~,~) toggle_add_defender_mode());
    uimenu(defender_menu, 'Label', 'Записать защитников в файл', 'Callback', @(~,~) save_defender_to_file());
    uimenu(defender_menu, 'Label', 'Вставить защитников из файла', 'Callback', @(~,~) load_defender_from_file());

    % ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

    function draw_axes_lines()
        hold(ax, 'on');
        line(ax, [-2000, 2000], [0, 0], 'Color', 'k', 'LineWidth', 1.5);
        line(ax, [0, 0], [-2000, 2000], 'Color', 'k', 'LineWidth', 1.5);
        hold(ax, 'off');
    end

    function zoom_callback(~, evt)
        scale = 1.2;
        if evt.VerticalScrollCount > 0
            factor = 1 / scale;
        elseif evt.VerticalScrollCount < 0
            factor = scale;
        else
            return;
        end

        x_lim = xlim(ax);
        y_lim = ylim(ax);

        cp = get(ax, 'CurrentPoint');
        if ~isempty(cp) && cp(1,1) >= x_lim(1) && cp(1,1) <= x_lim(2) && ...
           cp(1,2) >= y_lim(1) && cp(1,2) <= y_lim(2)
            center_x = cp(1,1);
            center_y = cp(1,2);
        else
            center_x = mean(x_lim);
            center_y = mean(y_lim);
        end

        new_x = center_x + (x_lim - center_x) * factor;
        new_y = center_y + (y_lim - center_y) * factor;

        xlim(ax, new_x);
        ylim(ax, new_y);
        axis(ax, 'equal');
        xlim(ax, new_x);
        ylim(ax, new_y);
    end

    function button_down(~, ~)
        selection = get(fig, 'SelectionType');

        if strcmp(selection, 'open')
            reset_view();
            return;
        end

        if add_node_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    node_points(end+1, :) = [x, y];
                    update_spline_plot();
                end
            end
            return;
        end

        if add_comp_node_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    comp_node_points(end+1, :) = [x, y];
                    update_comp_spline_plot();
                end
            end
            return;
        end

        if add_predator_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    predator_points(end+1, :) = [x, y];
                    update_predator_plot();
                end
            end
            return;
        end

        if add_prey_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    prey_points(end+1, :) = [x, y];
                    update_prey_plot();
                end
            end
            return;
        end

        if add_defender_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    defender_points(end+1, :) = [x, y];
                    update_defender_plot();
                end
            end
            return;
        end

        if add_radar_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    radar_centers(end+1, :) = [x, y];
                    update_predator_radars();
                end
            end
            return;
        end

        if add_prey_radar_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    prey_radar_centers(end+1, :) = [x, y];
                    update_prey_radars();
                end
            end
            return;
        end

        if ~strcmp(selection, 'normal')
            return;
        end

        cp = get(ax, 'CurrentPoint');
        if isempty(cp)
            return;
        end
        x = cp(1,1);
        y = cp(1,2);
        x_lim = xlim(ax);
        y_lim = ylim(ax);
        if x < x_lim(1) || x > x_lim(2) || y < y_lim(1) || y > y_lim(2)
            return;
        end

        is_panning = true;
        pan_start_point = [x, y];
        pan_start_limits = [x_lim, y_lim];
        set(fig, 'Pointer', 'fleur');
    end

    function pan_move(~, ~)
        if ~is_panning
            return;
        end
        cp = get(ax, 'CurrentPoint');
        if isempty(cp)
            return;
        end
        x_curr = cp(1,1);
        y_curr = cp(1,2);
        dx = x_curr - pan_start_point(1);
        dy = y_curr - pan_start_point(2);
        x_lim = pan_start_limits(1:2) - dx;
        y_lim = pan_start_limits(3:4) - dy;
        xlim(ax, x_lim);
        ylim(ax, y_lim);
        axis(ax, 'equal');
        xlim(ax, x_lim);
        ylim(ax, y_lim);
    end

    function pan_stop(~, ~)
        if is_panning
            is_panning = false;
            set(fig, 'Pointer', 'arrow');
        end
    end

    function reset_view()
        xlim(ax, [-2000, 2000]);
        ylim(ax, [-2000, 2000]);
        axis(ax, 'equal');
        xlim(ax, [-2000, 2000]);
        ylim(ax, [-2000, 2000]);
    end

    % --- Функции для работы с красным сплайном (Red Line) ---
    function toggle_add_node_mode()
        if add_node_mode
            add_node_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления узлов (красные) ВЫКЛЮЧЕН.');
        else
            add_node_mode = true;
            add_comp_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления узлов (красные) ВКЛЮЧЕН. Кликайте по графику.');
        end
    end

    function build_spline()
        if size(node_points, 1) < 2
            errordlg('Недостаточно узлов (минимум 2).', 'Ошибка');
            return;
        end
        update_spline_plot();
        disp('Сплайн построен.');
    end

    function finish_spline()
        if add_node_mode
            toggle_add_node_mode();
        end
        build_spline();
        disp('Построение сплайна завершено.');
    end

    function toggle_nodes_visibility()
        show_nodes = ~show_nodes;
        if show_nodes
            disp('Узлы сплайна ВИДИМЫ.');
        else
            disp('Узлы сплайна НЕВИДИМЫ.');
        end
        update_spline_plot();
    end

    function save_nodes_to_file()
        if isempty(node_points)
            errordlg('Нет узлов для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить узлы (красные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                nodes.x = node_points(:,1);
                nodes.y = node_points(:,2);
                save(full, '-struct', 'nodes');
            else
                writematrix(node_points, full);
            end
            disp(['Узлы сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_nodes_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить узлы (красные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    node_points = [data.x(:), data.y(:)];
                elseif isfield(data, 'nodes') && size(data.nodes,2) == 2
                    node_points = data.nodes;
                else
                    errordlg('Неверный формат .mat (требуются x,y или матрица 2xN).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    node_points = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_spline_plot();
            disp(['Узлы загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_spline_plot()
        if ~isempty(spline_line) && ishandle(spline_line)
            delete(spline_line);
        end
        if ~isempty(point_markers) && ishandle(point_markers)
            delete(point_markers);
        end
        if isempty(node_points)
            return;
        end

        hold(ax, 'on');
        if show_nodes
            point_markers = plot(ax, node_points(:,1), node_points(:,2), 'ro', ...
                                  'MarkerSize', 2, 'MarkerFaceColor', 'r', ...
                                  'LineWidth', 1);
        else
            point_markers = [];
        end

        if size(node_points, 1) >= 2
            t = 1:size(node_points,1);
            tt = linspace(1, size(node_points,1), 100);
            xx = spline(t, node_points(:,1), tt);
            yy = spline(t, node_points(:,2), tt);
            spline_line = plot(ax, xx, yy, 'm-', 'LineWidth', 1);
        end
        hold(ax, 'off');
    end

    % --- Функции для работы с Compression Line (синий сплайн) ---
    function toggle_add_comp_node_mode()
        if add_comp_node_mode
            add_comp_node_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления узлов Compression Line (синие) ВЫКЛЮЧЕН.');
        else
            add_comp_node_mode = true;
            add_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления узлов Compression Line (синие) ВКЛЮЧЕН. Кликайте по графику.');
        end
    end

    function build_comp_spline()
        if size(comp_node_points, 1) < 2
            errordlg('Недостаточно узлов для Compression Line (минимум 2).', 'Ошибка');
            return;
        end
        update_comp_spline_plot();
        disp('Compression Line построен.');
    end

    function finish_comp_spline()
        if add_comp_node_mode
            toggle_add_comp_node_mode();
        end
        build_comp_spline();
        disp('Построение Compression Line завершено.');
    end

    function toggle_comp_nodes_visibility()
        show_comp_nodes = ~show_comp_nodes;
        if show_comp_nodes
            disp('Узлы Compression Line ВИДИМЫ.');
        else
            disp('Узлы Compression Line НЕВИДИМЫ.');
        end
        update_comp_spline_plot();
    end

    function save_comp_nodes_to_file()
        if isempty(comp_node_points)
            errordlg('Нет узлов Compression Line для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить узлы Compression Line');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                nodes.x = comp_node_points(:,1);
                nodes.y = comp_node_points(:,2);
                save(full, '-struct', 'nodes');
            else
                writematrix(comp_node_points, full);
            end
            disp(['Узлы Compression Line сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_comp_nodes_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить узлы Compression Line');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    comp_node_points = [data.x(:), data.y(:)];
                elseif isfield(data, 'nodes') && size(data.nodes,2) == 2
                    comp_node_points = data.nodes;
                else
                    errordlg('Неверный формат .mat (требуются x,y или матрица 2xN).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    comp_node_points = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_comp_spline_plot();
            disp(['Узлы Compression Line загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_comp_spline_plot()
        if ~isempty(comp_spline_line) && ishandle(comp_spline_line)
            delete(comp_spline_line);
        end
        if ~isempty(comp_point_markers) && ishandle(comp_point_markers)
            delete(comp_point_markers);
        end
        if isempty(comp_node_points)
            return;
        end

        hold(ax, 'on');
        if show_comp_nodes
            comp_point_markers = plot(ax, comp_node_points(:,1), comp_node_points(:,2), 'bo', ...
                                       'MarkerSize', 2, 'MarkerFaceColor', 'b', ...
                                       'LineWidth', 1);
        else
            comp_point_markers = [];
        end

        if size(comp_node_points, 1) >= 2
            t = 1:size(comp_node_points,1);
            tt = linspace(1, size(comp_node_points,1), 100);
            xx = spline(t, comp_node_points(:,1), tt);
            yy = spline(t, comp_node_points(:,2), tt);
            comp_spline_line = plot(ax, xx, yy, 'b-', 'LineWidth', 1);
        end
        hold(ax, 'off');
    end

    function prey_to_compression_distances()
        if size(comp_node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для расчёта расстояний.', 'Ошибка');
            return;
        end

        t = 1:size(comp_node_points, 1);
        tt = linspace(1, size(comp_node_points, 1), 100);
        xx = spline(t, comp_node_points(:,1), tt);
        yy = spline(t, comp_node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        distances = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            distances(i) = min(dists);
        end

        dist_fig = figure('Name', 'Расстояния от жертв до Compression Line', ...
                          'NumberTitle', 'off', ...
                          'Position', [300 300 500 400]);

        table_data = [(1:num_prey)', prey_points, distances];
        column_names = {'Жертва №', 'X', 'Y', 'Расстояние'};

        uitable('Parent', dist_fig, ...
                'Data', table_data, ...
                'ColumnName', column_names, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp('Расстояния от жертв до Compression Line отображены в новом окне.');
    end

    function prey_within_100_of_compression()
        if size(comp_node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для анализа.', 'Ошибка');
            return;
        end

        t = 1:size(comp_node_points, 1);
        tt = linspace(1, size(comp_node_points, 1), 100);
        xx = spline(t, comp_node_points(:,1), tt);
        yy = spline(t, comp_node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        distances = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            distances(i) = min(dists);
        end

        idx = distances < 100;
        if ~any(idx)
            msgbox('Нет жертв с расстоянием до Compression Line менее 100.', 'Результат');
            return;
        end

        selected_prey = prey_points(idx, :);
        selected_dist = distances(idx);
        selected_indices = find(idx);

        dist_fig = figure('Name', 'Жертвы с расстоянием до Compression Line < 100', ...
                          'NumberTitle', 'off', ...
                          'Position', [300 300 500 400]);

        table_data = [selected_indices, selected_prey, selected_dist];
        column_names = {'Жертва №', 'X', 'Y', 'Расстояние'};

        uitable('Parent', dist_fig, ...
                'Data', table_data, ...
                'ColumnName', column_names, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp('Жертвы с расстоянием до Compression Line менее 100 отображены в новом окне.');
    end

    % --- Функции для работы с хищниками (красные точки, без линий) ---
    function toggle_add_predator_mode()
        if add_predator_mode
            add_predator_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления хищников (красные точки) ВЫКЛЮЧЕН.');
        else
            add_predator_mode = true;
            add_node_mode = false;
            add_comp_node_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления хищников (красные точки) ВКЛЮЧЕН. Кликайте по графику.');
        end
    end

    function save_predator_to_file()
        if isempty(predator_points)
            errordlg('Нет точек хищников для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить хищников (красные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                pred.x = predator_points(:,1);
                pred.y = predator_points(:,2);
                save(full, '-struct', 'pred');
            else
                writematrix(predator_points, full);
            end
            disp(['Хищники сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_predator_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить хищников (красные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    predator_points = [data.x(:), data.y(:)];
                elseif isfield(data, 'pred') && isstruct(data.pred) && isfield(data.pred, 'x') && isfield(data.pred, 'y')
                    predator_points = [data.pred.x(:), data.pred.y(:)];
                elseif isfield(data, 'predator_points') && size(data.predator_points,2) == 2
                    predator_points = data.predator_points;
                else
                    errordlg('Неверный формат .mat (требуются x,y или структура pred).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    predator_points = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_predator_plot();
            disp(['Хищники загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_predator_plot()
        if ~isempty(predator_markers) && ishandle(predator_markers)
            delete(predator_markers);
        end
        if isempty(predator_points)
            return;
        end

        hold(ax, 'on');
        predator_markers = plot(ax, predator_points(:,1), predator_points(:,2), 'ro', ...
                                 'MarkerSize', 2, 'MarkerFaceColor', 'r', ...
                                 'LineWidth', 1.5);
        hold(ax, 'off');
    end

    % --- Функции для работы с защитниками (зелёные точки) ---
    function toggle_add_defender_mode()
        if add_defender_mode
            add_defender_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления защитников (зелёные точки) ВЫКЛЮЧЕН.');
        else
            add_defender_mode = true;
            add_node_mode = false;
            add_comp_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления защитников (зелёные точки) ВКЛЮЧЕН. Кликайте по графику.');
        end
    end

    function save_defender_to_file()
        if isempty(defender_points)
            errordlg('Нет точек защитников для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить защитников (зелёные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                def.x = defender_points(:,1);
                def.y = defender_points(:,2);
                save(full, '-struct', 'def');
            else
                writematrix(defender_points, full);
            end
            disp(['Защитники сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_defender_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить защитников (зелёные)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    defender_points = [data.x(:), data.y(:)];
                elseif isfield(data, 'def') && isstruct(data.def) && isfield(data.def, 'x') && isfield(data.def, 'y')
                    defender_points = [data.def.x(:), data.def.y(:)];
                elseif isfield(data, 'defender_points') && size(data.defender_points,2) == 2
                    defender_points = data.defender_points;
                else
                    errordlg('Неверный формат .mat (требуются x,y или структура def).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    defender_points = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_defender_plot();
            disp(['Защитники загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_defender_plot()
        if ~isempty(defender_markers) && ishandle(defender_markers)
            delete(defender_markers);
        end
        if isempty(defender_points)
            return;
        end
        hold(ax, 'on');
        defender_markers = plot(ax, defender_points(:,1), defender_points(:,2), 'o', ...
                        'MarkerSize', 3, ...
                        'MarkerEdgeColor', 'k', ...
                        'MarkerFaceColor', 'g', ...
                        'LineWidth', 1);
        hold(ax, 'off');
    end

    % --- Функции для работы с радарами хищников ---
    function toggle_add_radar_mode()
        if add_radar_mode
            add_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления радаров хищников ВЫКЛЮЧЕН.');
        else
            add_radar_mode = true;
            add_node_mode = false;
            add_comp_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления радаров хищников ВКЛЮЧЕН. Кликайте по графику для установки центра радара.');
        end
    end

    function toggle_predator_radar_borders()
        show_predator_radar_borders = ~show_predator_radar_borders;
        if show_predator_radar_borders
            set(border_pred_menu, 'Checked', 'on');
            disp('Отображение границ радаров хищников ВКЛЮЧЕНО.');
        else
            set(border_pred_menu, 'Checked', 'off');
            disp('Отображение границ радаров хищников ВЫКЛЮЧЕНО.');
        end
        update_predator_radars();
    end

    function save_radars_to_file()
        if isempty(radar_centers)
            errordlg('Нет радаров для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить радары хищников');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                radars.x = radar_centers(:,1);
                radars.y = radar_centers(:,2);
                save(full, '-struct', 'radars');
            else
                writematrix(radar_centers, full);
            end
            disp(['Радары хищников сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_radars_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить радары хищников');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    radar_centers = [data.x(:), data.y(:)];
                elseif isfield(data, 'radars') && isstruct(data.radars) && isfield(data.radars, 'x') && isfield(data.radars, 'y')
                    radar_centers = [data.radars.x(:), data.radars.y(:)];
                elseif isfield(data, 'radar_centers') && size(data.radar_centers,2) == 2
                    radar_centers = data.radar_centers;
                else
                    errordlg('Неверный формат .mat (требуются x,y или структура radars).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    radar_centers = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_predator_radars();
            disp(['Радары хищников загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_predator_radars()
        if ~isempty(radar_handles) && all(ishandle(radar_handles))
            delete(radar_handles);
        end
        if isempty(radar_centers)
            radar_handles = [];
            return;
        end

        hold(ax, 'on');
        radius = 300;
        n = size(radar_centers, 1);
        radar_handles = gobjects(n, 1);
        for i = 1:n
            cx = radar_centers(i, 1);
            cy = radar_centers(i, 2);
            theta = linspace(0, 2*pi, 100);
            x_circ = cx + radius * cos(theta);
            y_circ = cy + radius * sin(theta);
            if show_predator_radar_borders
                radar_handles(i) = plot(ax, x_circ, y_circ, 'k-', 'LineWidth', 0.01);
            else
                radar_handles(i) = fill(ax, x_circ, y_circ, [0.7 0.7 0.7], ...
                                         'EdgeColor', 'none', 'FaceAlpha', 0.5);
            end
        end
        hold(ax, 'off');
    end

    % --- Функции для работы с радарами жертв ---
    function toggle_add_prey_radar_mode()
        if add_prey_radar_mode
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления радаров жертв ВЫКЛЮЧЕН.');
        else
            add_prey_radar_mode = true;
            add_node_mode = false;
            add_comp_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления радаров жертв ВКЛЮЧЕН. Кликайте по графику для установки центра радара.');
        end
    end

    function toggle_prey_radar_borders()
        show_prey_radar_borders = ~show_prey_radar_borders;
        if show_prey_radar_borders
            set(border_prey_menu, 'Checked', 'on');
            disp('Отображение границ радаров жертв ВКЛЮЧЕНО.');
        else
            set(border_prey_menu, 'Checked', 'off');
            disp('Отображение границ радаров жертв ВЫКЛЮЧЕНО.');
        end
        update_prey_radars();
    end

    function save_prey_radars_to_file()
        if isempty(prey_radar_centers)
            errordlg('Нет радаров жертв для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить радары жертв');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                radars.x = prey_radar_centers(:,1);
                radars.y = prey_radar_centers(:,2);
                save(full, '-struct', 'radars');
            else
                writematrix(prey_radar_centers, full);
            end
            disp(['Радары жертв сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_prey_radars_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить радары жертв');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    prey_radar_centers = [data.x(:), data.y(:)];
                elseif isfield(data, 'radars') && isstruct(data.radars) && isfield(data.radars, 'x') && isfield(data.radars, 'y')
                    prey_radar_centers = [data.radars.x(:), data.radars.y(:)];
                elseif isfield(data, 'prey_radar_centers') && size(data.prey_radar_centers,2) == 2
                    prey_radar_centers = data.prey_radar_centers;
                else
                    errordlg('Неверный формат .mat (требуются x,y или структура radars).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    prey_radar_centers = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_prey_radars();
            disp(['Радары жертв загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_prey_radars()
        if ~isempty(prey_radar_handles) && all(ishandle(prey_radar_handles))
            delete(prey_radar_handles);
        end
        if isempty(prey_radar_centers)
            prey_radar_handles = [];
            return;
        end

        hold(ax, 'on');
        radius = 150;
        n = size(prey_radar_centers, 1);
        prey_radar_handles = gobjects(n, 1);
        for i = 1:n
            cx = prey_radar_centers(i, 1);
            cy = prey_radar_centers(i, 2);
            theta = linspace(0, 2*pi, 100);
            x_circ = cx + radius * cos(theta);
            y_circ = cy + radius * sin(theta);
            if show_prey_radar_borders
                prey_radar_handles(i) = plot(ax, x_circ, y_circ, 'k-', 'LineWidth', 1);
            else
                prey_radar_handles(i) = fill(ax, x_circ, y_circ, [0.7 0.9 1], ...
                                              'EdgeColor', 'none', 'FaceAlpha', 0.5);
            end
        end
        hold(ax, 'off');
    end

    % --- Функции для работы с жертвами (синие точки) ---
    function toggle_add_prey_mode()
        if add_prey_mode
            add_prey_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления жертв ВЫКЛЮЧЕН.');
        else
            add_prey_mode = true;
            add_node_mode = false;
            add_comp_node_mode = false;
            add_predator_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'crosshair');
            disp('Режим добавления жертв ВКЛЮЧЕН. Кликайте по графику.');
        end
    end

    function save_prey_to_file()
        if isempty(prey_points)
            errordlg('Нет точек жертв для сохранения.', 'Ошибка');
            return;
        end
        [fname, pname] = uiputfile({'*.txt';'*.mat'}, 'Сохранить жертв (синие)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                prey.x = prey_points(:,1);
                prey.y = prey_points(:,2);
                save(full, '-struct', 'prey');
            else
                writematrix(prey_points, full);
            end
            disp(['Жертвы сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_prey_from_file()
        [fname, pname] = uigetfile({'*.txt';'*.mat'}, 'Загрузить жертв (синие)');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.mat')
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    prey_points = [data.x(:), data.y(:)];
                elseif isfield(data, 'prey') && isstruct(data.prey) && isfield(data.prey, 'x') && isfield(data.prey, 'y')
                    prey_points = [data.prey.x(:), data.prey.y(:)];
                elseif isfield(data, 'prey_points') && size(data.prey_points,2) == 2
                    prey_points = data.prey_points;
                else
                    errordlg('Неверный формат .mat (требуются x,y или структура prey).', 'Ошибка');
                    return;
                end
            else
                data = readmatrix(full);
                if size(data,2) >= 2
                    prey_points = data(:,1:2);
                else
                    errordlg('Текстовый файл должен содержать два столбца (x y).', 'Ошибка');
                    return;
                end
            end
            update_prey_plot();
            disp(['Жертвы загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function update_prey_plot()
        if ~isempty(prey_markers) && ishandle(prey_markers)
            delete(prey_markers);
        end
        if isempty(prey_points)
            return;
        end
        hold(ax, 'on');
        prey_markers = plot(ax, prey_points(:,1), prey_points(:,2), 'bo', ...
                            'MarkerSize', 2, 'MarkerFaceColor', 'b', ...
                            'LineWidth', 1);
        hold(ax, 'off');
    end

    % --- Функция для расчёта матрицы расстояний хищник-жертва в ЗДР хищников ---
    function predator_prey_distances()
        if isempty(predator_points)
            errordlg('Нет хищников для расчёта расстояний.', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для расчёта расстояний.', 'Ошибка');
            return;
        end
        if isempty(radar_centers)
            errordlg('Нет радаров хищников для определения зоны действия.', 'Ошибка');
            return;
        end

        pred_in_zone = false(size(predator_points,1), 1);
        for i = 1:size(predator_points,1)
            for r = 1:size(radar_centers,1)
                if norm(predator_points(i,:) - radar_centers(r,:)) <= 300
                    pred_in_zone(i) = true;
                    break;
                end
            end
        end

        if ~any(pred_in_zone)
            errordlg('Нет хищников в зоне действия радаров хищников.', 'Информация');
            return;
        end

        prey_in_zone = false(size(prey_points,1), 1);
        for j = 1:size(prey_points,1)
            for r = 1:size(radar_centers,1)
                if norm(prey_points(j,:) - radar_centers(r,:)) <= 300
                    prey_in_zone(j) = true;
                    break;
                end
            end
        end

        if ~any(prey_in_zone)
            errordlg('Нет жертв в зоне действия радаров хищников.', 'Информация');
            return;
        end

        selected_pred_idx = find(pred_in_zone);
        selected_prey_idx = find(prey_in_zone);
        selected_pred = predator_points(selected_pred_idx, :);
        selected_prey = prey_points(selected_prey_idx, :);
        num_pred_sel = size(selected_pred, 1);
        num_prey_sel = size(selected_prey, 1);

        dist_matrix = zeros(num_pred_sel, num_prey_sel);
        for i = 1:num_pred_sel
            for j = 1:num_prey_sel
                dist_matrix(i,j) = norm(selected_pred(i,:) - selected_prey(j,:));
            end
        end

        dist_fig = figure('Name', 'Матрица расстояний хищник-жертва (в зоне радаров хищников)', ...
                          'NumberTitle', 'off', ...
                          'Position', [300 300 600 400]);

        row_names = cellstr(num2str(selected_pred_idx, 'Хищник %d'));
        col_names = cellstr(num2str(selected_prey_idx, 'Жертва %d'));

        uitable('Parent', dist_fig, ...
                'Data', dist_matrix, ...
                'ColumnName', col_names, ...
                'RowName', row_names, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp('Матрица расстояний хищник-жертва (в зоне радаров хищников) отображена в новом окне.');
    end

    % --- Функция: Расстояния от жертв до Compression Line < 100 (матрица стоимостей) ---
    function predator_prey_distances_compression_100()
        if isempty(predator_points)
            errordlg('Нет хищников для расчёта расстояний.', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для расчёта расстояний.', 'Ошибка');
            return;
        end
        if isempty(radar_centers)
            errordlg('Нет радаров хищников для определения зоны действия.', 'Ошибка');
            return;
        end
        if size(comp_node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end

        pred_in_zone = false(size(predator_points,1), 1);
        for i = 1:size(predator_points,1)
            for r = 1:size(radar_centers,1)
                if norm(predator_points(i,:) - radar_centers(r,:)) <= 300
                    pred_in_zone(i) = true;
                    break;
                end
            end
        end

        if ~any(pred_in_zone)
            errordlg('Нет хищников в зоне действия радаров хищников.', 'Информация');
            return;
        end

        prey_in_radar = false(size(prey_points,1), 1);
        for j = 1:size(prey_points,1)
            for r = 1:size(radar_centers,1)
                if norm(prey_points(j,:) - radar_centers(r,:)) <= 300
                    prey_in_radar(j) = true;
                    break;
                end
            end
        end

        t = 1:size(comp_node_points, 1);
        tt = linspace(1, size(comp_node_points, 1), 100);
        xx = spline(t, comp_node_points(:,1), tt);
        yy = spline(t, comp_node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        dist_to_comp = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            dist_to_comp(i) = min(dists);
        end

        selected_prey_logical = prey_in_radar & (dist_to_comp < 100);
        if ~any(selected_prey_logical)
            msgbox('Нет жертв, удовлетворяющих условиям (в зоне радаров хищников и расстояние до Compression Line < 100).', ...
                   'Результат');
            return;
        end

        selected_pred_idx = find(pred_in_zone);
        selected_prey_idx = find(selected_prey_logical);
        selected_pred = predator_points(selected_pred_idx, :);
        selected_prey = prey_points(selected_prey_idx, :);
        num_pred_sel = size(selected_pred, 1);
        num_prey_sel = size(selected_prey, 1);

        dist_matrix = zeros(num_pred_sel, num_prey_sel);
        for i = 1:num_pred_sel
            for j = 1:num_prey_sel
                dist_matrix(i,j) = norm(selected_pred(i,:) - selected_prey(j,:));
            end
        end

        dist_fig = figure('Name', 'Матрица расстояний (жертвы в ЗДР хищников и расстояние до Compression Line < 100)', ...
                          'NumberTitle', 'off', ...
                          'Position', [300 300 600 400]);

        row_names = cellstr(num2str(selected_pred_idx, 'Хищник %d'));
        col_names = cellstr(num2str(selected_prey_idx, 'Жертва %d'));

        uitable('Parent', dist_fig, ...
                'Data', dist_matrix, ...
                'ColumnName', col_names, ...
                'RowName', row_names, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp('Матрица расстояний (жертвы в ЗДР хищников и расстояние до Compression Line < 100) отображена.');
    end

    % --- Венгерский алгоритм для распределения хищников по жертвам в ЗДР (до 3 хищников на жертву) ---
    function hungarian_zdor_assignment()
        if isempty(predator_points)
            errordlg('Нет хищников для распределения.', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для распределения.', 'Ошибка');
            return;
        end
        if isempty(radar_centers)
            errordlg('Нет радаров хищников для определения зоны действия.', 'Ошибка');
            return;
        end

        pred_in_zone = false(size(predator_points,1), 1);
        for i = 1:size(predator_points,1)
            for r = 1:size(radar_centers,1)
                if norm(predator_points(i,:) - radar_centers(r,:)) <= 300
                    pred_in_zone(i) = true;
                    break;
                end
            end
        end

        if ~any(pred_in_zone)
            errordlg('Нет хищников в зоне действия радаров хищников.', 'Информация');
            return;
        end

        prey_in_zone = false(size(prey_points,1), 1);
        for j = 1:size(prey_points,1)
            for r = 1:size(radar_centers,1)
                if norm(prey_points(j,:) - radar_centers(r,:)) <= 300
                    prey_in_zone(j) = true;
                    break;
                end
            end
        end

        if ~any(prey_in_zone)
            errordlg('Нет жертв в зоне действия радаров хищников.', 'Информация');
            return;
        end

        selected_pred_idx = find(pred_in_zone);
        selected_prey_idx = find(prey_in_zone);
        selected_pred = predator_points(selected_pred_idx, :);
        selected_prey = prey_points(selected_prey_idx, :);
        num_pred_sel = size(selected_pred, 1);
        num_prey_sel = size(selected_prey, 1);

        max_slots = 3 * num_prey_sel;
        costMatrix_ext = zeros(num_pred_sel, max(num_pred_sel, max_slots));
        for i = 1:num_pred_sel
            for j = 1:num_prey_sel
                dist = norm(selected_pred(i,:) - selected_prey(j,:));
                costMatrix_ext(i, j) = dist;
                costMatrix_ext(i, j + num_prey_sel) = dist;
                costMatrix_ext(i, j + 2*num_prey_sel) = dist;
            end
        end
        if num_pred_sel > max_slots
            extra = num_pred_sel - max_slots;
            costMatrix_ext(:, end+1:end+extra) = 1e6;
        end

        try
            assignment_ext = hungarian_assignment(costMatrix_ext);
        catch ME
            errordlg(['Ошибка выполнения венгерского алгоритма: ' ME.message], 'Ошибка');
            return;
        end

        assignment_pairs = [];
        for i_local = 1:num_pred_sel
            col = assignment_ext(i_local);
            if col > 0 && col <= max_slots
                if col <= num_prey_sel
                    prey_local = col;
                elseif col <= 2*num_prey_sel
                    prey_local = col - num_prey_sel;
                else
                    prey_local = col - 2*num_prey_sel;
                end
                orig_pred_idx = selected_pred_idx(i_local);
                orig_prey_idx = selected_prey_idx(prey_local);
                assignment_pairs = [assignment_pairs; orig_pred_idx, orig_prey_idx];
            end
        end

        if ~isempty(assignment_lines) && any(ishandle(assignment_lines))
            delete(assignment_lines);
        end
        assignment_lines = [];

        hold(ax, 'on');
        for k = 1:size(assignment_pairs,1)
            orig_pred_idx = assignment_pairs(k,1);
            orig_prey_idx = assignment_pairs(k,2);
            pred_pt = predator_points(orig_pred_idx,:);
            prey_pt = prey_points(orig_prey_idx,:);
            h = plot(ax, [pred_pt(1), prey_pt(1)], [pred_pt(2), prey_pt(2)], ...
                     'g-', 'LineWidth', 0.5);
            assignment_lines(end+1) = h;
        end
        hold(ax, 'off');

        current_assignment_zdor = assignment_pairs;

        num_assigned = size(assignment_pairs,1);
        result_table = cell(num_assigned, 5);
        totalCost = 0;
        for k = 1:num_assigned
            orig_pred_idx = assignment_pairs(k,1);
            orig_prey_idx = assignment_pairs(k,2);
            dist = norm(predator_points(orig_pred_idx,:) - prey_points(orig_prey_idx,:));
            totalCost = totalCost + dist;
            result_table{k,1} = orig_pred_idx;
            result_table{k,2} = predator_points(orig_pred_idx,1);
            result_table{k,3} = predator_points(orig_pred_idx,2);
            result_table{k,4} = orig_prey_idx;
            result_table{k,5} = dist;
        end

        res_fig = figure('Name', 'Распределение хищников по жертвам (Венгерский алгоритм, ЗДР, до 3 на жертву)', ...
                         'NumberTitle', 'off', ...
                         'Position', [200 200 700 400]);

        uitable('Parent', res_fig, ...
                'Data', result_table, ...
                'ColumnName', {'Хищник №', 'X хищника', 'Y хищника', 'Жертва №', 'Расстояние'}, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp(['Распределение завершено. Назначено пар: ' num2str(num_assigned) ', суммарное расстояние: ' num2str(totalCost)]);
    end

    % --- Венгерский алгоритм для распределения хищников по жертвам с учётом Compression Line (<100, до 3 на жертву) ---
    function hungarian_cl_assignment()
        if isempty(predator_points)
            errordlg('Нет хищников для распределения.', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для распределения.', 'Ошибка');
            return;
        end
        if isempty(radar_centers)
            errordlg('Нет радаров хищников для определения зоны действия.', 'Ошибка');
            return;
        end
        if size(comp_node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end

        pred_in_zone = false(size(predator_points,1), 1);
        for i = 1:size(predator_points,1)
            for r = 1:size(radar_centers,1)
                if norm(predator_points(i,:) - radar_centers(r,:)) <= 300
                    pred_in_zone(i) = true;
                    break;
                end
            end
        end

        if ~any(pred_in_zone)
            errordlg('Нет хищников в зоне действия радаров хищников.', 'Информация');
            return;
        end

        prey_in_radar = false(size(prey_points,1), 1);
        for j = 1:size(prey_points,1)
            for r = 1:size(radar_centers,1)
                if norm(prey_points(j,:) - radar_centers(r,:)) <= 300
                    prey_in_radar(j) = true;
                    break;
                end
            end
        end

        t = 1:size(comp_node_points, 1);
        tt = linspace(1, size(comp_node_points, 1), 100);
        xx = spline(t, comp_node_points(:,1), tt);
        yy = spline(t, comp_node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        dist_to_comp = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            dist_to_comp(i) = min(dists);
        end

        selected_prey_logical = prey_in_radar & (dist_to_comp < 100);
        if ~any(selected_prey_logical)
            msgbox('Нет жертв, удовлетворяющих условиям (в зоне радаров хищников и расстояние до Compression Line < 100).', ...
                   'Результат');
            return;
        end

        selected_pred_idx = find(pred_in_zone);
        selected_prey_idx = find(selected_prey_logical);
        selected_pred = predator_points(selected_pred_idx, :);
        selected_prey = prey_points(selected_prey_idx, :);
        num_pred_sel = size(selected_pred, 1);
        num_prey_sel = size(selected_prey, 1);

        max_slots = 3 * num_prey_sel;
        costMatrix_ext = zeros(num_pred_sel, max(num_pred_sel, max_slots));
        for i = 1:num_pred_sel
            for j = 1:num_prey_sel
                dist = norm(selected_pred(i,:) - selected_prey(j,:));
                costMatrix_ext(i, j) = dist;
                costMatrix_ext(i, j + num_prey_sel) = dist;
                costMatrix_ext(i, j + 2*num_prey_sel) = dist;
            end
        end
        if num_pred_sel > max_slots
            extra = num_pred_sel - max_slots;
            costMatrix_ext(:, end+1:end+extra) = 1e6;
        end

        try
            assignment_ext = hungarian_assignment(costMatrix_ext);
        catch ME
            errordlg(['Ошибка выполнения венгерского алгоритма: ' ME.message], 'Ошибка');
            return;
        end

        assignment_pairs = [];
        for i_local = 1:num_pred_sel
            col = assignment_ext(i_local);
            if col > 0 && col <= max_slots
                if col <= num_prey_sel
                    prey_local = col;
                elseif col <= 2*num_prey_sel
                    prey_local = col - num_prey_sel;
                else
                    prey_local = col - 2*num_prey_sel;
                end
                orig_pred_idx = selected_pred_idx(i_local);
                orig_prey_idx = selected_prey_idx(prey_local);
                assignment_pairs = [assignment_pairs; orig_pred_idx, orig_prey_idx];
            end
        end

        if ~isempty(assignment_lines) && any(ishandle(assignment_lines))
            delete(assignment_lines);
        end
        assignment_lines = [];

        hold(ax, 'on');
        for k = 1:size(assignment_pairs,1)
            orig_pred_idx = assignment_pairs(k,1);
            orig_prey_idx = assignment_pairs(k,2);
            pred_pt = predator_points(orig_pred_idx,:);
            prey_pt = prey_points(orig_prey_idx,:);
            h = plot(ax, [pred_pt(1), prey_pt(1)], [pred_pt(2), prey_pt(2)], ...
                     'm-', 'LineWidth', 0.5);
            assignment_lines(end+1) = h;
        end
        hold(ax, 'off');

        current_assignment_cl = assignment_pairs;

        num_assigned = size(assignment_pairs,1);
        result_table = cell(num_assigned, 5);
        totalCost = 0;
        for k = 1:num_assigned
            orig_pred_idx = assignment_pairs(k,1);
            orig_prey_idx = assignment_pairs(k,2);
            dist = norm(predator_points(orig_pred_idx,:) - prey_points(orig_prey_idx,:));
            totalCost = totalCost + dist;
            result_table{k,1} = orig_pred_idx;
            result_table{k,2} = predator_points(orig_pred_idx,1);
            result_table{k,3} = predator_points(orig_pred_idx,2);
            result_table{k,4} = orig_prey_idx;
            result_table{k,5} = dist;
        end

        res_fig = figure('Name', 'Распределение хищников по жертвам (Венгерский алгоритм, CL<100, до 3 на жертву)', ...
                         'NumberTitle', 'off', ...
                         'Position', [200 200 700 400]);

        uitable('Parent', res_fig, ...
                'Data', result_table, ...
                'ColumnName', {'Хищник №', 'X хищника', 'Y хищника', 'Жертва №', 'Расстояние'}, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp(['Распределение завершено (CL<100). Назначено пар: ' num2str(num_assigned) ', суммарное расстояние: ' num2str(totalCost)]);
    end

    % ====================================================================
    % ===        АНИМАЦИЯ С УЧАСТИЕМ ЗАЩИТНИКОВ (общая логика)        ===
    % ====================================================================
    function run_generic_animation(assignment_pairs, type_string)
        % Общая функция анимации для обоих типов распределения
        % assignment_pairs: матрица [pred_idx, prey_idx]
        % type_string: 'ZDR' или 'CL'

        if isempty(assignment_pairs)
            errordlg('Нет назначений для анимации.', 'Ошибка');
            return;
        end

        % Создание папки для видео
        video_folder = 'animation_videos';
        if ~exist(video_folder, 'dir')
            mkdir(video_folder);
        end
        video_filename = fullfile(video_folder, sprintf('animation_%s_%s.avi', type_string, datestr(now,'yyyymmdd_HHMMSS')));
        v = VideoWriter(video_filename, 'Motion JPEG AVI');
        v.FrameRate = 10;   % соответствует dt=0.1
        open(v);

        duel_distance_threshold = 15;   % расстояние дуэли хищник-жертва
        if strcmp(type_string, 'CL')
            pred_win_prob = 0.6;         % для CL
        else
            pred_win_prob = 0.3;         % для ZDR
        end

        num_pairs = size(assignment_pairs, 1);
        pred_indices = assignment_pairs(:,1);
        prey_indices = assignment_pairs(:,2);

        all_pred_pos = predator_points;
        target_pos = prey_points(prey_indices, :);

        speeds = rand(num_pairs, 1) * 10 + 10;   % скорость хищников
        active = true(num_pairs, 1);
        dt = 0.1;
        tmax = 50;
        t = 0;

        % Удаляем старые маркеры
        if ~isempty(predator_markers) && ishandle(predator_markers)
            delete(predator_markers);
            predator_markers = [];
        end
        if ~isempty(prey_markers) && ishandle(prey_markers)
            delete(prey_markers);
            prey_markers = [];
        end
        if ~isempty(defender_markers) && ishandle(defender_markers)
            delete(defender_markers);
            defender_markers = [];
        end

        hold(ax, 'on');
        h_pred_scatter = scatter(ax, all_pred_pos(:,1), all_pred_pos(:,2), 20, 'r', 'filled');
        h_prey_scatter = scatter(ax, prey_points(:,1), prey_points(:,2), 20, 'b', 'filled');
        h_def_scatter = scatter(ax, defender_points(:,1), defender_points(:,2), 30, 'g', 'filled');
        hold(ax, 'off');

        % ---- Подготовка данных для логики защитников ----
        red_line_pts = [];
        if size(node_points,1) >= 2
            t_spline = 1:size(node_points,1);
            tt_spline = linspace(1, size(node_points,1), 200);
            xx_spline = spline(t_spline, node_points(:,1), tt_spline);
            yy_spline = spline(t_spline, node_points(:,2), tt_spline);
            red_line_pts = [xx_spline(:), yy_spline(:)];
        end

        prev_pred_pos = all_pred_pos;   % предыдущие позиции хищников
        pred_crossed = false(size(all_pred_pos,1), 1);  % флаг, что хищник уже пересёк Red Line

        ndef = size(defender_points, 1);
        def_assigned = zeros(ndef, 1);      % 0 – свободен, иначе индекс целевого хищника
        def_speeds = zeros(ndef, 1);
        def_active = true(ndef, 1);         % жив ли защитник

        current_pred_pos = all_pred_pos;
        current_def_pos = defender_points;

        disp(['Анимация (' type_string ') с участием защитников запущена. Длительность до 50 с.']);
        disp(['Видео сохраняется в ' video_filename]);

        while t < tmax && any(active) && ~isempty(prey_points)
            % 1. Движение хищников к целям
            for i = 1:num_pairs
                if active(i)
                    idx_pred = pred_indices(i);
                    if prey_indices(i) > size(prey_points,1) || prey_indices(i) < 1
                        active(i) = false;
                        continue;
                    end
                    d = prey_points(prey_indices(i),:) - current_pred_pos(idx_pred, :);
                    dist = norm(d);
                    if dist < speeds(i) * dt
                        current_pred_pos(idx_pred, :) = prey_points(prey_indices(i),:);
                    else
                        dir_vec = d / dist;
                        current_pred_pos(idx_pred, :) = current_pred_pos(idx_pred, :) + speeds(i) * dt * dir_vec;
                    end
                end
            end

            % 2. Проверка пересечения Red Line и назначение защитников
            for idx_pred = 1:size(current_pred_pos,1)
                if ~pred_crossed(idx_pred) && ~isempty(red_line_pts)
                    seg_start = prev_pred_pos(idx_pred, :);
                    seg_end   = current_pred_pos(idx_pred, :);
                    crossed = false;
                    for k = 1:size(red_line_pts,1)-1
                        if segments_intersect(seg_start, seg_end, red_line_pts(k,:), red_line_pts(k+1,:))
                            crossed = true;
                            break;
                        end
                    end
                    if crossed
                        pred_crossed(idx_pred) = true;
                        % Ищем ближайшего свободного защитника
                        free_def_mask = def_assigned == 0 & def_active;
                        if any(free_def_mask)
                            free_def_idx = find(free_def_mask);
                            dists = vecnorm(current_def_pos(free_def_idx,:) - current_pred_pos(idx_pred,:), 2, 2);
                            [~, min_idx] = min(dists);
                            chosen_def = free_def_idx(min_idx);
                            def_assigned(chosen_def) = idx_pred;
                            def_speeds(chosen_def) = 15 + rand()*10;  % 15..25
                            fprintf('Защитник %d назначен на хищника %d (скорость %.1f)\n', ...
                                    chosen_def, idx_pred, def_speeds(chosen_def));
                        else
                            fprintf('Хищник %d пересёк Red Line, но свободных защитников нет.\n', idx_pred);
                        end
                    end
                end
            end

            % 3. Движение защитников к назначенным хищникам
            for d = 1:ndef
                if def_active(d) && def_assigned(d) > 0
                    target_idx = def_assigned(d);
                    if target_idx > size(current_pred_pos,1) || target_idx < 1
                        def_assigned(d) = 0;
                        continue;
                    end
                    dvec = current_pred_pos(target_idx, :) - current_def_pos(d, :);
                    dist = norm(dvec);
                    if dist < def_speeds(d) * dt
                        current_def_pos(d, :) = current_pred_pos(target_idx, :);
                    else
                        dir = dvec / dist;
                        current_def_pos(d, :) = current_def_pos(d, :) + def_speeds(d) * dt * dir;
                    end
                end
            end

            % 4. Дуэли хищник-жертва
            for i = 1:num_pairs
                if ~active(i), continue; end
                idx_pred = pred_indices(i);
                idx_prey = prey_indices(i);
                if idx_prey > size(prey_points,1) || idx_prey < 1
                    active(i) = false;
                    continue;
                end
                dist = norm(current_pred_pos(idx_pred,:) - prey_points(idx_prey,:));
                if dist < duel_distance_threshold
                    if rand() < pred_win_prob
                        % Хищник победил – удаляем жертву
                        prey_points(idx_prey,:) = [];
                        fprintf('Хищник %d уничтожил жертву %d.\n', idx_pred, idx_prey);
                        % Обновляем индексы в назначениях
                        for j = 1:num_pairs
                            if prey_indices(j) > idx_prey
                                prey_indices(j) = prey_indices(j) - 1;
                            elseif prey_indices(j) == idx_prey
                                active(j) = false;
                            end
                        end
                    else
                        % Жертва победила – удаляем хищника
                        current_pred_pos(idx_pred,:) = [];
                        predator_points(idx_pred,:) = [];   % обновляем глобальный массив
                        fprintf('Жертва %d уничтожила хищника %d.\n', idx_prey, idx_pred);
                        % Обновляем индексы хищников в назначениях
                        for j = 1:num_pairs
                            if pred_indices(j) > idx_pred
                                pred_indices(j) = pred_indices(j) - 1;
                            elseif pred_indices(j) == idx_pred
                                active(j) = false;
                            end
                        end
                        % Синхронизируем массивы защитников
                        [def_assigned, pred_crossed] = remove_def_refs(def_assigned, pred_crossed, idx_pred);
                    end
                    active(i) = false;
                end
            end

            % 5. Дуэли защитник-хищник
            for d = 1:ndef
                if ~def_active(d) || def_assigned(d) == 0, continue; end
                target_idx = def_assigned(d);
                if target_idx > size(current_pred_pos,1)
                    def_assigned(d) = 0;
                    continue;
                end
                dist = norm(current_def_pos(d,:) - current_pred_pos(target_idx,:));
                if dist < duel_distance_threshold
                    if rand() < 0.5   % 50/50
                        % Защитник победил – удаляем хищника
                        current_pred_pos(target_idx,:) = [];
                        predator_points(target_idx,:) = [];
                        fprintf('Защитник %d уничтожил хищника %d.\n', d, target_idx);
                        % Обновляем индексы хищников в назначениях
                        for j = 1:num_pairs
                            if pred_indices(j) > target_idx
                                pred_indices(j) = pred_indices(j) - 1;
                            elseif pred_indices(j) == target_idx
                                active(j) = false;
                            end
                        end
                        % Обновляем ссылки защитников
                        [def_assigned, pred_crossed] = remove_def_refs(def_assigned, pred_crossed, target_idx);
                        def_assigned(d) = 0;  % этот защитник освобождается
                    else
                        % Хищник победил – удаляем защитника
                        def_active(d) = false;
                        current_def_pos(d,:) = [NaN NaN];   % за пределы
                        fprintf('Хищник %d уничтожил защитника %d.\n', target_idx, d);
                    end
                end
            end

            % 6. Очистка назначений защитников, если цель исчезла
            for d = 1:ndef
                if def_assigned(d) > 0 && (def_assigned(d) > size(current_pred_pos,1) || ~def_active(d))
                    def_assigned(d) = 0;
                end
            end
            % Удаляем уничтоженных защитников из массива
            alive_def = def_active;
            if ~all(alive_def)
                current_def_pos = current_def_pos(alive_def, :);
                def_assigned = def_assigned(alive_def);
                def_speeds = def_speeds(alive_def);
                ndef = size(current_def_pos,1);
                def_active = true(ndef,1);
                fprintf('Удалено %d защитников.\n', sum(~alive_def));
            end

            % 7. Обновление отображения
            set(h_pred_scatter, 'XData', current_pred_pos(:,1), 'YData', current_pred_pos(:,2));
            set(h_prey_scatter, 'XData', prey_points(:,1), 'YData', prey_points(:,2));
            set(h_def_scatter, 'XData', current_def_pos(:,1), 'YData', current_def_pos(:,2));
            drawnow;

            % Запись текущего кадра в видео
            frame = getframe(fig);
            writeVideo(v, frame);

            pause(dt);
            t = t + dt;

            % Обновляем предыдущие позиции хищников
            prev_pred_pos = current_pred_pos;
        end

        % Закрываем видео
        close(v);
        disp(['Видео сохранено в ' video_filename]);

        % Сохраняем финальные позиции
        predator_points = current_pred_pos;
        defender_points = current_def_pos;
        delete(h_pred_scatter);
        delete(h_prey_scatter);
        delete(h_def_scatter);
        update_predator_plot();
        update_prey_plot();
        update_defender_plot();
        if ~isempty(assignment_lines) && any(ishandle(assignment_lines))
            delete(assignment_lines);
            assignment_lines = [];
        end
        disp(['Анимация (' type_string ') завершена.']);
    end

    % Вспомогательная: проверка пересечения двух отрезков
    function yes = segments_intersect(p1, p2, q1, q2)
        d1 = cross2d(q1 - p1, q2 - p1);
        d2 = cross2d(q1 - p2, q2 - p2);
        d3 = cross2d(p1 - q1, p2 - q1);
        d4 = cross2d(p1 - q2, p2 - q2);
        yes = false;
        if d1*d2 < 0 && d3*d4 < 0
            yes = true;
        elseif d1 == 0 && on_segment(p1, q1, q2)
            yes = true;
        elseif d2 == 0 && on_segment(p2, q1, q2)
            yes = true;
        elseif d3 == 0 && on_segment(q1, p1, p2)
            yes = true;
        elseif d4 == 0 && on_segment(q2, p1, p2)
            yes = true;
        end
    end

    function val = cross2d(v, w)
        val = v(1)*w(2) - v(2)*w(1);
    end

    function res = on_segment(pt, a, b)
        res = min(a(1),b(1)) <= pt(1) && pt(1) <= max(a(1),b(1)) && ...
              min(a(2),b(2)) <= pt(2) && pt(2) <= max(a(2),b(2));
    end

    function [new_assigned, new_crossed] = remove_def_refs(assigned, crossed, removed_idx)
        new_assigned = assigned;
        new_crossed = crossed;
        new_assigned(assigned > removed_idx) = assigned(assigned > removed_idx) - 1;
        new_assigned(assigned == removed_idx) = 0;
        new_crossed(removed_idx) = [];
    end

    % ---- Конкретные анимации ----
    function animate_hungarian_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Венгерский алгоритм (Х) -> Матрица стоимостей ЗДР (В)".', 'Ошибка');
            return;
        end
        run_generic_animation(current_assignment_zdor, 'ZDR');
    end

    function animate_hungarian_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Венгерский алгоритм (Х) -> Матрица стоимостей CL (В)".', 'Ошибка');
            return;
        end
        run_generic_animation(current_assignment_cl, 'CL');
    end

    % --- Функции для сохранения и загрузки всех данных ---
    function save_all_data()
        [fname, pname] = uiputfile('*.mat', 'Сохранить все данные');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            data.node_points = node_points;
            data.comp_node_points = comp_node_points;
            data.predator_points = predator_points;
            data.prey_points = prey_points;
            data.defender_points = defender_points;
            data.radar_centers = radar_centers;
            data.prey_radar_centers = prey_radar_centers;
            data.show_nodes = show_nodes;
            data.show_comp_nodes = show_comp_nodes;
            data.show_predator_radar_borders = show_predator_radar_borders;
            data.show_prey_radar_borders = show_prey_radar_borders;
            data.current_assignment_zdor = current_assignment_zdor;
            data.current_assignment_cl = current_assignment_cl;
            save(full, '-struct', 'data');
            disp(['Все данные сохранены в ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

    function load_all_data()
        [fname, pname] = uigetfile('*.mat', 'Загрузить все данные');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            data = load(full);
            if isfield(data, 'node_points')
                node_points = data.node_points;
            else
                node_points = [];
            end
            if isfield(data, 'comp_node_points')
                comp_node_points = data.comp_node_points;
            else
                comp_node_points = [];
            end
            if isfield(data, 'predator_points')
                predator_points = data.predator_points;
            else
                predator_points = [];
            end
            if isfield(data, 'prey_points')
                prey_points = data.prey_points;
            else
                prey_points = [];
            end
            if isfield(data, 'defender_points')
                defender_points = data.defender_points;
            else
                defender_points = [];
            end
            if isfield(data, 'radar_centers')
                radar_centers = data.radar_centers;
            else
                radar_centers = [];
            end
            if isfield(data, 'prey_radar_centers')
                prey_radar_centers = data.prey_radar_centers;
            else
                prey_radar_centers = [];
            end
            if isfield(data, 'show_nodes')
                show_nodes = data.show_nodes;
            else
                show_nodes = true;
            end
            if isfield(data, 'show_comp_nodes')
                show_comp_nodes = data.show_comp_nodes;
            else
                show_comp_nodes = true;
            end
            if isfield(data, 'show_predator_radar_borders')
                show_predator_radar_borders = data.show_predator_radar_borders;
            else
                show_predator_radar_borders = false;
            end
            if isfield(data, 'show_prey_radar_borders')
                show_prey_radar_borders = data.show_prey_radar_borders;
            else
                show_prey_radar_borders = false;
            end
            if isfield(data, 'current_assignment_zdor')
                current_assignment_zdor = data.current_assignment_zdor;
            else
                current_assignment_zdor = [];
            end
            if isfield(data, 'current_assignment_cl')
                current_assignment_cl = data.current_assignment_cl;
            else
                current_assignment_cl = [];
            end

            if show_predator_radar_borders
                set(border_pred_menu, 'Checked', 'on');
            else
                set(border_pred_menu, 'Checked', 'off');
            end
            if show_prey_radar_borders
                set(border_prey_menu, 'Checked', 'on');
            else
                set(border_prey_menu, 'Checked', 'off');
            end

            update_spline_plot();
            update_comp_spline_plot();
            update_predator_plot();
            update_prey_plot();
            update_defender_plot();
            update_predator_radars();
            update_prey_radars();

            disp(['Данные загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    % --- Функции меню Файл ---
    function new_file()
        cla(ax);
        xlim(ax, [-2000, 2000]);
        ylim(ax, [-2000, 2000]);
        axis(ax, 'equal');
        xlim(ax, [-2000, 2000]);
        ylim(ax, [-2000, 2000]);
        grid(ax, 'on');
        xlabel(ax, 'X');
        ylabel(ax, 'Y');
        draw_axes_lines();
        node_points = [];
        comp_node_points = [];
        predator_points = [];
        prey_points = [];
        defender_points = [];
        radar_centers = [];
        prey_radar_centers = [];
        add_node_mode = false;
        add_comp_node_mode = false;
        add_predator_mode = false;
        add_prey_mode = false;
        add_defender_mode = false;
        add_radar_mode = false;
        add_prey_radar_mode = false;
        show_predator_radar_borders = false;
        show_prey_radar_borders = false;
        set(border_pred_menu, 'Checked', 'off');
        set(border_prey_menu, 'Checked', 'off');
        set(fig, 'Pointer', 'arrow');
        if ~isempty(assignment_lines) && any(ishandle(assignment_lines))
            delete(assignment_lines);
        end
        assignment_lines = [];
        current_assignment_zdor = [];
        current_assignment_cl = [];
        update_spline_plot();
        update_comp_spline_plot();
        update_predator_plot();
        update_prey_plot();
        update_defender_plot();
        update_predator_radars();
        update_prey_radars();
        disp('Создана новая координатная плоскость.');
    end

    function open_file()
        [fname, pname] = uigetfile({'*.mat';'*.txt'}, 'Выберите файл');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        if endsWith(fname, '.mat')
            try
                data = load(full);
                if isfield(data, 'x') && isfield(data, 'y')
                    cla(ax);
                    plot(ax, data.x, data.y, 'LineWidth', 2);
                    xlabel(ax, 'X');
                    ylabel(ax, 'Y');
                    grid(ax, 'on');
                    axis(ax, 'equal');
                    xlim(ax, [-2000, 2000]);
                    ylim(ax, [-2000, 2000]);
                    draw_axes_lines();
                else
                    disp('Файл .mat не содержит переменных x и y.');
                end
            catch ME
                errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
            end
        elseif endsWith(fname, '.txt')
            try
                data = readmatrix(full);
                if size(data,2) >= 2
                    cla(ax);
                    plot(ax, data(:,1), data(:,2), 'LineWidth', 2);
                    xlabel(ax, 'X');
                    ylabel(ax, 'Y');
                    grid(ax, 'on');
                    axis(ax, 'equal');
                    xlim(ax, [-2000, 2000]);
                    ylim(ax, [-2000, 2000]);
                    draw_axes_lines();
                else
                    disp('Текстовый файл должен содержать минимум два столбца.');
                end
            catch
                errordlg('Не удалось прочитать текстовый файл.', 'Ошибка');
            end
        end
    end

    function save_file()
        [fname, pname] = uiputfile({'*.png';'*.jpg';'*.fig'}, 'Сохранить график');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            if endsWith(fname, '.fig')
                savefig(fig, full);
            else
                saveas(fig, full);
            end
            disp(['График сохранён как ' full]);
        catch ME
            errordlg(['Ошибка сохранения: ' ME.message], 'Ошибка');
        end
    end

end

% ==================== ФУНКЦИИ ВЕНГЕРСКОГО АЛГОРИТМА ====================
function [assignment, totalCost] = hungarian_assignment(costMatrix)
    % Обёртка над munkres, поддерживающая случай хищников > жертв
    numPred = size(costMatrix, 1);
    numPrey = size(costMatrix, 2);
    
    if numPred == 0 || numPrey == 0
        assignment = zeros(numPred, 1);
        totalCost = 0;
        return;
    end
    
    if numPred <= numPrey
        [assignRows, totalCost] = munkres(costMatrix);
        assignment = assignRows(:);
    else
        [assignSmall, ~] = munkres(costMatrix');
        assignment = zeros(numPred, 1);
        for preyIdx = 1:numPrey
            predIdx = assignSmall(preyIdx);
            if predIdx > 0 && predIdx <= numPred
                assignment(predIdx) = preyIdx;
            end
        end
        totalCost = 0;
        for p = 1:numPred
            if assignment(p) > 0
                totalCost = totalCost + costMatrix(p, assignment(p));
            end
        end
    end
    assignment = assignment(:);
end

function [assignment, cost] = munkres(costMatrix)
    % Входная матрица должна быть квадратной или иметь строк <= столбцов
    costMatrix = double(costMatrix);
    [n, m] = size(costMatrix);
    if n > m
        error('В munkres число строк должно быть <= числа столбцов');
    end
    costMatrix = costMatrix - min(costMatrix,[],2);
    starZ = zeros(n,m);
    primeZ = zeros(n,m);
    coveredRows = false(n,1);
    coveredCols = false(m,1);

    % Шаг 1
    for r = 1:n
        for c = 1:m
            if costMatrix(r,c) == 0 && ~coveredRows(r) && ~coveredCols(c)
                starZ(r,c) = 1;
                coveredRows(r) = true;
                coveredCols(c) = true;
            end
        end
    end
    coveredRows(:) = false;
    coveredCols(:) = false;

    step = 2;
    while true
        switch step
            case 2
                coveredCols = any(starZ,1);
                if sum(coveredCols) == n
                    break;
                end
                step = 3;
            case 3
                [r, c] = find(costMatrix == 0 & ~coveredRows & ~coveredCols, 1);
                if isempty(r)
                    step = 5;
                    continue;
                end
                primeZ(r,c) = 1;
                starCol = find(starZ(r,:),1);
                if isempty(starCol)
                    step = 4;
                    currRow = r;
                    currCol = c;
                else
                    coveredRows(r) = true;
                    coveredCols(starCol) = false;
                    step = 3;
                end
            case 4
                path = [currRow, currCol];
                while true
                    starCol = path(end,2);
                    starRow = find(starZ(:,starCol),1);
                    if isempty(starRow)
                        break;
                    end
                    path = [path; starRow, starCol];
                    primeCol = find(primeZ(starRow,:),1);
                    path = [path; starRow, primeCol];
                end
                for i = 1:size(path,1)
                    r = path(i,1); c = path(i,2);
                    if starZ(r,c)
                        starZ(r,c) = 0;
                    else
                        starZ(r,c) = 1;
                    end
                end
                primeZ(:) = 0;
                coveredRows(:) = false;
                coveredCols(:) = false;
                step = 2;
            case 5
                uncovered = costMatrix(~coveredRows, ~coveredCols);
                if isempty(uncovered)
                    break;
                end
                minVal = min(uncovered(:));
                costMatrix(~coveredRows, ~coveredCols) = costMatrix(~coveredRows, ~coveredCols) - minVal;
                costMatrix(coveredRows, coveredCols) = costMatrix(coveredRows, coveredCols) + minVal;
                step = 3;
        end
    end

    [assRows, assCols] = find(starZ);
    assignment = zeros(1,n);
    for i = 1:length(assRows)
        assignment(assRows(i)) = assCols(i);
    end
    if nargout > 1
        cost = sum(costMatrix(sub2ind([n,m], 1:n, assignment)));
    end
end