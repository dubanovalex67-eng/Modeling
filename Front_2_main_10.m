function triple_animation_def_video()
    % Графическое окно с осями [-2000,2000], зум, панорамирование и построение линий
    %   (сплайна, хищников, жертв, защитников, радаров хищников, радаров жертв)
    %   Добавлена логика защитников: при пересечении хищником Red Line к нему
    %   устремляется ближайший свободный защитник (скорость 15-25). Дуэль 50/50.
    %
    %   Меню: Файл, Red Line (Сплайн, Закончить сплайн, Узлы сплайна невидимы, Записать в файл, Вставить из файла,
    %         Сплайн Compression Line, Закончить Compression Line, Узлы Compression Line невидимы, Записать в файл Compression Line, Вставить из файла Compression Line,
    %         Расстояния жертв до Compression Line, Жертвы с расстоянием до Compression Line < delta_CL,
    %         delta_CL - толщина линии прорыва),
    %   Хищники (Вставить хищника, Записать хищников в файл, Вставить хищников из файла,
    %            Вставить радар хищников, Записать радары хищников в файл, Вставить радары хищников из файла,
    %            Граница зоны действия радаров хищников, Хищники на защитников,
    %            Матрица стоимостей в ЗДР хищников ->
    %                Расстояния хищник-жертва в ЗДР хищников, Расстояния от жертв до Compression Line < delta_CL,
    %            Начальное распределение хищников -> Венгерский алгоритм (Х) -> Матрица стоимостей ЗДР (В), Матрица стоимостей CL (В),
    %                                               Жадный алгоритм (Х) -> Матрица стоимостей ЗДР (Ж), Матрица стоимостей CL (Ж),
    %                                               Генетический алгоритм (Х) -> Матрица стоимостей ЗДР (Г), Матрица стоимостей CL (Г),
    %                                               Аукционный алгоритм (Х) -> Матрица стоимостей ЗДР (А), Матрица стоимостей CL (А),
    %                                               Ближайший сосед (Х) -> Матрица стоимостей ЗДР (БС), Матрица стоимостей CL (БС),
    %                                               Нейросетевой алгоритм (Х) -> Матрица стоимостей ЗДР (НС), Матрица стоимостей CL (НС),
    %            Анимация (нач) (Х) -> Венгерский (Х) -> ЗДР (Х), CL (Х),
    %                           Жадный (Х) -> ЗДР (Х), CL (Х),
    %                           Генетический (Х) -> ЗДР (Х), CL (Х),
    %                           Аукционный (Х) -> ЗДР (Х), CL (Х),
    %                           Ближайший сосед (Х) -> ЗДР (Х), CL (Х),
    %                           Нейросетевой (Х) -> ЗДР (Х), CL (Х)),
    %   Жертвы (Вставить жертву, Записать жертвы в файл, Вставить жертвы из файла,
    %            Вставить радар жертвы, Записать радары жертв в файл, Вставить радары жертв из файла,
    %            Граница зоны действия радаров жертв),
    %   Защитники (Вставить защитника, Записать защитников в файл, Вставить защитников из файла),
    %   Дуэли (Хищник - жертва, Хищник - защитник).

    clc; clear; close all;

    % ==================== ДОБАВЛЕНИЕ ПУТЕЙ ====================
    % Добавляем папки Algorithm и Graph в путь, если они существуют
    if exist('Algorithm', 'dir')
        addpath('Algorithm');
    else
        warning('Папка Algorithm не найдена. Убедитесь, что внешние функции находятся в ней.');
    end
    % Добавляем подпапку Hungarian для венгерских алгоритмов
    if exist(fullfile('Algorithm', 'Hungarian'), 'dir')
        addpath(fullfile('Algorithm', 'Hungarian'));
    else
        warning('Папка Algorithm/Hungarian не найдена. Убедитесь, что венгерские алгоритмы находятся в ней.');
    end
    % Добавляем подпапку Greedy для жадных алгоритмов
    if exist(fullfile('Algorithm', 'Greedy'), 'dir')
        addpath(fullfile('Algorithm', 'Greedy'));
    else
        warning('Папка Algorithm/Greedy не найдена. Убедитесь, что жадные алгоритмы находятся в ней.');
    end
    % Добавляем подпапку Genetic для генетических алгоритмов
    if exist(fullfile('Algorithm', 'Genetic'), 'dir')
        addpath(fullfile('Algorithm', 'Genetic'));
    else
        warning('Папка Algorithm/Genetic не найдена. Убедитесь, что генетические алгоритмы находятся в ней.');
    end
    % Добавляем подпапку Auction для аукционных алгоритмов
    if exist(fullfile('Algorithm', 'Auction'), 'dir')
        addpath(fullfile('Algorithm', 'Auction'));
    else
        warning('Папка Algorithm/Auction не найдена. Убедитесь, что аукционные алгоритмы находятся в ней.');
    end
    % Добавляем подпапку Nearest для алгоритма ближайшего соседа
    if exist(fullfile('Algorithm', 'Nearest'), 'dir')
        addpath(fullfile('Algorithm', 'Nearest'));
    else
        warning('Папка Algorithm/Nearest не найдена. Убедитесь, что алгоритмы ближайшего соседа находятся в ней.');
    end
    % Добавляем подпапку Neural для нейросетевых алгоритмов
    if exist(fullfile('Algorithm', 'Neural'), 'dir')
        addpath(fullfile('Algorithm', 'Neural'));
    else
        warning('Папка Algorithm/Neural не найдена. Убедитесь, что нейросетевые алгоритмы находятся в ней.');
    end
    % Добавляем подпапку Animation для функций анимации
    if exist(fullfile('Algorithm', 'Animation'), 'dir')
        addpath(fullfile('Algorithm', 'Animation'));
    else
        warning('Папка Algorithm/Animation не найдена. Убедитесь, что функции анимации находятся в ней.');
    end
    if exist('Graph', 'dir')
        addpath('Graph');
    else
        warning('Папка Graph не найдена. Убедитесь, что внешние функции находятся в ней.');
    end
    % ======================================================================

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

    % --- Рисование осей координат (внешняя функция) ---
    draw_axes_lines(ax);

    % --- Инициализация переменных для панорамирования ---
    is_panning = false;
    pan_start_point = [0, 0];
    pan_start_limits = [0, 0, 0, 0];

    % --- Инициализация данных для Red Line (сплайн) ---
    red = struct('node_points', [], 'spline_line', [], 'point_markers', [], ...
                 'show_nodes', true, 'add_node_mode', false);

    % --- Инициализация данных для Compression Line (синий сплайн) ---
    comp = struct('node_points', [], 'spline_line', [], 'point_markers', [], ...
                  'show_nodes', true, 'add_node_mode', false);

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

    % --- Инициализация данных для радаров хищников (залитые круги) ---
    radar_centers = [];         % центры радаров (N x 2)
    radar_handles = [];         % дескрипторы залитых кругов
    add_radar_mode = false;     % режим добавления радара
    show_predator_radar_borders = false;  % флаг отображения границы радаров хищников
    predator_radar_radius = 300; % радиус радаров хищников

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

    % --- Переменная для ограничения числа хищников на жертву (по умолчанию 3) ---
    maxPredPerPrey = 3;

    % --- Переменная для толщины линии прорыва (расстояние до Compression Line) ---
    delta_CL = 100;

    % --- Переменные для настроек дуэлей ---
    duelDistance = 15;      % расстояние начала дуэли
    predWinProb = 0.5;      % вероятность победы хищника над жертвой
    defenderWinProb = 0.5;  % вероятность победы защитника над хищником

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
    uimenu(red_menu, 'Label', 'Сплайн', 'Callback', @(~,~) toggle_add_node_mode_cb());
    uimenu(red_menu, 'Label', 'Закончить сплайн', 'Callback', @(~,~) finish_spline_cb());
    uimenu(red_menu, 'Label', 'Узлы сплайна невидимы', 'Callback', @(~,~) toggle_nodes_visibility_cb());
    uimenu(red_menu, 'Label', 'Записать в файл', 'Callback', @(~,~) save_nodes_to_file_cb());
    uimenu(red_menu, 'Label', 'Вставить из файла', 'Callback', @(~,~) load_nodes_from_file_cb());

    uimenu(red_menu, 'Label', 'Сплайн Compression Line', 'Callback', @(~,~) toggle_add_comp_node_mode_cb());
    uimenu(red_menu, 'Label', 'Закончить Compression Line', 'Callback', @(~,~) finish_comp_spline_cb());
    uimenu(red_menu, 'Label', 'Узлы Compression Line невидимы', 'Callback', @(~,~) toggle_comp_nodes_visibility_cb());
    uimenu(red_menu, 'Label', 'Записать в файл Compression Line', 'Callback', @(~,~) save_comp_nodes_to_file_cb());
    uimenu(red_menu, 'Label', 'Вставить из файла Compression Line', 'Callback', @(~,~) load_comp_nodes_from_file_cb());

    uimenu(red_menu, 'Label', 'Расстояния жертв до Compression Line', 'Callback', @(~,~) prey_to_compression_distances());
    uimenu(red_menu, 'Label', 'Жертвы с расстоянием до Compression Line < delta_CL', 'Callback', @(~,~) prey_within_delta_CL_of_compression());
    uimenu(red_menu, 'Label', 'delta_CL - толщина линии прорыва', 'Callback', @(~,~) set_delta_cl());

    pred_menu = uimenu(fig, 'Label', 'Хищники');
    uimenu(pred_menu, 'Label', 'Вставить хищника', 'Callback', @(~,~) toggle_add_predator_mode());
    uimenu(pred_menu, 'Label', 'Записать хищников в файл', 'Callback', @(~,~) save_predator_to_file());
    uimenu(pred_menu, 'Label', 'Вставить хищников из файла', 'Callback', @(~,~) load_predator_from_file());
    uimenu(pred_menu, 'Label', 'Вставить радар хищников', 'Callback', @(~,~) toggle_add_radar_mode());
    uimenu(pred_menu, 'Label', 'Записать радары хищников в файл', 'Callback', @(~,~) save_radars_to_file());
    uimenu(pred_menu, 'Label', 'Вставить радары хищников из файла', 'Callback', @(~,~) load_radars_from_file());
    border_pred_menu = uimenu(pred_menu, 'Label', 'Граница зоны действия радаров хищников', ...
                         'Checked', 'off', 'Callback', @(~,~) toggle_predator_radar_borders());
    uimenu(pred_menu, 'Label', 'Хищники на защитников', 'Callback', @(~,~) set_max_pred_per_prey());
    uimenu(pred_menu, 'Label', 'Изменить радиус радара хищника', ...
           'Callback', @(~,~) change_predator_radar_radius_cb());
    cost_matrix_menu = uimenu(pred_menu, 'Label', 'Матрица стоимостей в ЗДР хищников');
    uimenu(cost_matrix_menu, 'Label', 'Расстояния хищник-жертва в ЗДР хищников', ...
           'Callback', @(~,~) predator_prey_distances());
    uimenu(cost_matrix_menu, 'Label', 'Расстояния от жертв до Compression Line < delta_CL', ...
           'Callback', @(~,~) predator_prey_distances_compression_delta());

    init_distrib_menu = uimenu(pred_menu, 'Label', 'Начальное распределение хищников');
    hungarian_menu = uimenu(init_distrib_menu, 'Label', 'Венгерский алгоритм (Х)');
    uimenu(hungarian_menu, 'Label', 'Матрица стоимостей ЗДР (В)', ...
           'Callback', @(~,~) assign_hungarian_zdor());
    uimenu(hungarian_menu, 'Label', 'Матрица стоимостей CL (В)', ...
           'Callback', @(~,~) assign_hungarian_cl());

    greedy_menu = uimenu(init_distrib_menu, 'Label', 'Жадный алгоритм (Х)');
    uimenu(greedy_menu, 'Label', 'Матрица стоимостей ЗДР (Ж)', ...
           'Callback', @(~,~) assign_greedy_zdor());
    uimenu(greedy_menu, 'Label', 'Матрица стоимостей CL (Ж)', ...
           'Callback', @(~,~) assign_greedy_cl());

    genetic_menu = uimenu(init_distrib_menu, 'Label', 'Генетический алгоритм (Х)');
    uimenu(genetic_menu, 'Label', 'Матрица стоимостей ЗДР (Г)', ...
           'Callback', @(~,~) assign_genetic_zdor());
    uimenu(genetic_menu, 'Label', 'Матрица стоимостей CL (Г)', ...
           'Callback', @(~,~) assign_genetic_cl());

    auction_menu = uimenu(init_distrib_menu, 'Label', 'Аукционный алгоритм (Х)');
    uimenu(auction_menu, 'Label', 'Матрица стоимостей ЗДР (А)', ...
           'Callback', @(~,~) assign_auction_zdor());
    uimenu(auction_menu, 'Label', 'Матрица стоимостей CL (А)', ...
           'Callback', @(~,~) assign_auction_cl());

    nearest_menu = uimenu(init_distrib_menu, 'Label', 'Ближайший сосед (Х)');
    uimenu(nearest_menu, 'Label', 'Матрица стоимостей ЗДР (БС)', ...
           'Callback', @(~,~) assign_nearest_zdor());
    uimenu(nearest_menu, 'Label', 'Матрица стоимостей CL (БС)', ...
           'Callback', @(~,~) assign_nearest_cl());

    neural_menu = uimenu(init_distrib_menu, 'Label', 'Нейросетевой алгоритм (Х)');
    uimenu(neural_menu, 'Label', 'Матрица стоимостей ЗДР (НС)', ...
           'Callback', @(~,~) assign_neural_zdor());
    uimenu(neural_menu, 'Label', 'Матрица стоимостей CL (НС)', ...
           'Callback', @(~,~) assign_neural_cl());

    anim_menu = uimenu(pred_menu, 'Label', 'Анимация (нач) (Х)');
    venegr_anim = uimenu(anim_menu, 'Label', 'Венгерский (Х)');
    uimenu(venegr_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_hungarian_zdor());
    uimenu(venegr_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_hungarian_cl());

    greedy_anim = uimenu(anim_menu, 'Label', 'Жадный (Х)');
    uimenu(greedy_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_greedy_zdor());
    uimenu(greedy_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_greedy_cl());

    genetic_anim = uimenu(anim_menu, 'Label', 'Генетический (Х)');
    uimenu(genetic_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_genetic_zdor());
    uimenu(genetic_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_genetic_cl());

    auction_anim = uimenu(anim_menu, 'Label', 'Аукционный (Х)');
    uimenu(auction_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_auction_zdor());
    uimenu(auction_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_auction_cl());

    nearest_anim = uimenu(anim_menu, 'Label', 'Ближайший сосед (Х)');
    uimenu(nearest_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_nearest_zdor());
    uimenu(nearest_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_nearest_cl());

    neural_anim = uimenu(anim_menu, 'Label', 'Нейросетевой (Х)');
    uimenu(neural_anim, 'Label', 'ЗДР (Х)', 'Callback', @(~,~) animate_neural_zdor());
    uimenu(neural_anim, 'Label', 'CL (Х)', 'Callback', @(~,~) animate_neural_cl());

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

    duel_menu = uimenu(fig, 'Label', 'Дуэли');
    uimenu(duel_menu, 'Label', 'Хищник - жертва', 'Callback', @(~,~) set_duel_pred_prey());
    uimenu(duel_menu, 'Label', 'Хищник - защитник', 'Callback', @(~,~) set_duel_pred_def());

    % ==================== ФУНКЦИИ ВВОДА ЧИСЕЛ ====================
    function set_max_pred_per_prey()
        prompt = {'Введите максимальное количество хищников на одну жертву (целое положительное число):'};
        dlgtitle = 'Настройка ограничения';
        dims = [1 50];
        definput = {num2str(maxPredPerPrey)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            return;
        end
        val = str2double(answer{1});
        if isnan(val) || val < 1 || mod(val,1) ~= 0
            errordlg('Необходимо ввести целое положительное число. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        maxPredPerPrey = round(val);
        disp(['Установлено ограничение: не более ' num2str(maxPredPerPrey) ' хищников на одну жертву.']);
        msgbox(['Ограничение установлено: ' num2str(maxPredPerPrey) ' хищников на жертву.'], 'Настройка');
    end

    function set_delta_cl()
        prompt = {'Введите значение delta_CL (положительное число, расстояние до Compression Line):'};
        dlgtitle = 'Настройка delta_CL';
        dims = [1 50];
        definput = {num2str(delta_CL)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            return;
        end
        val = str2double(answer{1});
        if isnan(val) || val <= 0
            errordlg('Необходимо ввести положительное число. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        delta_CL = val;
        disp(['Установлено delta_CL = ' num2str(delta_CL)]);
        msgbox(['delta_CL установлено: ' num2str(delta_CL)], 'Настройка');
    end

    function set_duel_pred_prey()
        prompt = {'Расстояние начала дуэли (положительное число):', ...
                  'Вероятность победы хищника (число от 0 до 1):'};
        dlgtitle = 'Настройка дуэли: Хищник - жертва';
        dims = [1 50];
        definput = {num2str(duelDistance), num2str(predWinProb)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            return;
        end
        dist = str2double(answer{1});
        prob = str2double(answer{2});
        if isnan(dist) || dist <= 0
            errordlg('Расстояние должно быть положительным числом. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        if isnan(prob) || prob < 0 || prob > 1
            errordlg('Вероятность должна быть числом от 0 до 1. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        duelDistance = dist;
        predWinProb = prob;
        disp(['Настройки дуэли "Хищник - жертва" обновлены: расстояние = ' num2str(duelDistance) ', вероятность победы хищника = ' num2str(predWinProb)]);
        msgbox(['Настройки обновлены: расстояние = ' num2str(duelDistance) ', вероятность = ' num2str(predWinProb)], 'Настройка дуэли');
    end

    function set_duel_pred_def()
        prompt = {'Расстояние начала дуэли (положительное число):', ...
                  'Вероятность победы защитника (число от 0 до 1):'};
        dlgtitle = 'Настройка дуэли: Хищник - защитник';
        dims = [1 50];
        definput = {num2str(duelDistance), num2str(defenderWinProb)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            return;
        end
        dist = str2double(answer{1});
        prob = str2double(answer{2});
        if isnan(dist) || dist <= 0
            errordlg('Расстояние должно быть положительным числом. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        if isnan(prob) || prob < 0 || prob > 1
            errordlg('Вероятность должна быть числом от 0 до 1. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        duelDistance = dist;
        defenderWinProb = prob;
        disp(['Настройки дуэли "Хищник - защитник" обновлены: расстояние = ' num2str(duelDistance) ', вероятность победы защитника = ' num2str(defenderWinProb)]);
        msgbox(['Настройки обновлены: расстояние = ' num2str(duelDistance) ', вероятность = ' num2str(defenderWinProb)], 'Настройка дуэли');
    end

    % ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

    % ВНИМАНИЕ: функция draw_axes_lines вынесена во внешний файл Graph/draw_axes_lines.m
    % ВНИМАНИЕ: функция update_spline_plot вынесена во внешний файл Graph/update_spline_plot.m
    % ВНИМАНИЕ: функция update_comp_spline_plot вынесена во внешний файл Graph/update_comp_spline_plot.m
    % ВНИМАНИЕ: функция build_spline вынесена во внешний файл Graph/build_spline.m
    % ВНИМАНИЕ: функция build_comp_spline вынесена во внешний файл Graph/build_comp_spline.m
    % ВНИМАНИЕ: функция update_predator_plot вынесена во внешний файл Graph/update_predator_plot.m
    % ВНИМАНИЕ: функция update_prey_plot вынесена во внешний файл Graph/update_prey_plot.m
    % ВНИМАНИЕ: функция update_defender_plot вынесена во внешний файл Graph/update_defender_plot.m
    % ВНИМАНИЕ: функция update_predator_radars вынесена во внешний файл Graph/update_predator_radars.m
    % ВНИМАНИЕ: функция update_prey_radars вынесена во внешний файл Graph/update_prey_radars.m
    % ВНИМАНИЕ: функции hungarian_zdor_assignment и hungarian_cl_assignment вынесены в папку Algorithm/Hungarian/
    % ВНИМАНИЕ: функции greedy_zdor_assignment и greedy_cl_assignment вынесены в папку Algorithm/Greedy/
    % ВНИМАНИЕ: функции genetic_zdor_assignment и genetic_cl_assignment вынесены в папку Algorithm/Genetic/
    % ВНИМАНИЕ: функции auction_zdor_assignment и auction_cl_assignment вынесены в папку Algorithm/Auction/
    % ВНИМАНИЕ: функции nearest_zdor_assignment и nearest_cl_assignment вынесены в папку Algorithm/Nearest/
    % ВНИМАНИЕ: функции neural_zdor_assignment и neural_cl_assignment вынесены в папку Algorithm/Neural/
    % ВНИМАНИЕ: функция run_generic_animation вынесена в папку Algorithm/Animation/

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

        % === РЕЖИМ ДОБАВЛЕНИЯ УЗЛОВ RED LINE ===
        if red.add_node_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    red.node_points(end+1, :) = [x, y];
                    red = update_spline_plot(ax, red); % вызов внешней функции
                end
            end
            return;
        end

        % === РЕЖИМ ДОБАВЛЕНИЯ УЗЛОВ COMPRESSION LINE ===
        if comp.add_node_mode && strcmp(selection, 'normal')
            cp = get(ax, 'CurrentPoint');
            if ~isempty(cp)
                x = cp(1,1);
                y = cp(1,2);
                x_lim = xlim(ax);
                y_lim = ylim(ax);
                if x >= x_lim(1) && x <= x_lim(2) && y >= y_lim(1) && y <= y_lim(2)
                    comp.node_points(end+1, :) = [x, y];
                    comp = update_comp_spline_plot(ax, comp); % вызов внешней функции
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
                    predator_markers = update_predator_plot(ax, predator_points, predator_markers);
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
                    prey_markers = update_prey_plot(ax, prey_points, prey_markers);
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
                    defender_markers = update_defender_plot(ax, defender_points, defender_markers);
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
                    radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                                           show_predator_radar_borders, predator_radar_radius);
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
                    prey_radar_handles = update_prey_radars(ax, prey_radar_centers, prey_radar_handles, ...
                                                            show_prey_radar_borders);
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

    % ==================== ОБЁРТКИ ДЛЯ RED LINE (вызов внешних функций) ====================

    function toggle_add_node_mode_cb()
        red = toggle_add_node_mode(red);
        % Отключаем все другие режимы
        comp.add_node_mode = false;
        add_predator_mode = false;
        add_prey_mode = false;
        add_defender_mode = false;
        add_radar_mode = false;
        add_prey_radar_mode = false;
        if red.add_node_mode
            set(fig, 'Pointer', 'crosshair');
        else
            set(fig, 'Pointer', 'arrow');
        end
        red = update_spline_plot(ax, red);
    end

    function finish_spline_cb()
        if red.add_node_mode
            red = toggle_add_node_mode(red);
            comp.add_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
        end
        red = build_spline(ax, red);
    end

    function toggle_nodes_visibility_cb()
        red = toggle_nodes_visibility(red);
        red = update_spline_plot(ax, red);
    end

    function save_nodes_to_file_cb()
        red = save_nodes_to_file(red);
    end

    function load_nodes_from_file_cb()
        red = load_nodes_from_file(ax, red);
    end

    % ==================== ОБЁРТКИ ДЛЯ COMPRESSION LINE (вызов внешних функций) ====================

    function toggle_add_comp_node_mode_cb()
        comp = toggle_add_comp_node_mode(comp);
        % Отключаем все другие режимы
        red.add_node_mode = false;
        add_predator_mode = false;
        add_prey_mode = false;
        add_defender_mode = false;
        add_radar_mode = false;
        add_prey_radar_mode = false;
        if comp.add_node_mode
            set(fig, 'Pointer', 'crosshair');
        else
            set(fig, 'Pointer', 'arrow');
        end
        comp = update_comp_spline_plot(ax, comp); % вызов внешней функции
    end

    function finish_comp_spline_cb()
        if comp.add_node_mode
            comp = toggle_add_comp_node_mode(comp);
            red.add_node_mode = false;
            add_predator_mode = false;
            add_prey_mode = false;
            add_defender_mode = false;
            add_radar_mode = false;
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
        end
        comp = build_comp_spline(ax, comp);
    end

    function toggle_comp_nodes_visibility_cb()
        comp = toggle_comp_nodes_visibility(comp);
        comp = update_comp_spline_plot(ax, comp); % вызов внешней функции
    end

    function save_comp_nodes_to_file_cb()
        comp = save_comp_nodes_to_file(comp);
    end

    function load_comp_nodes_from_file_cb()
        comp = load_comp_nodes_from_file(ax, comp);
    end

    % --- Функции анализа Compression Line ---
    function prey_to_compression_distances()
        if size(comp.node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для расчёта расстояний.', 'Ошибка');
            return;
        end

        t = 1:size(comp.node_points, 1);
        tt = linspace(1, size(comp.node_points, 1), 100);
        xx = spline(t, comp.node_points(:,1), tt);
        yy = spline(t, comp.node_points(:,2), tt);
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

    function prey_within_delta_CL_of_compression()
        if size(comp.node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end
        if isempty(prey_points)
            errordlg('Нет жертв для анализа.', 'Ошибка');
            return;
        end

        t = 1:size(comp.node_points, 1);
        tt = linspace(1, size(comp.node_points, 1), 100);
        xx = spline(t, comp.node_points(:,1), tt);
        yy = spline(t, comp.node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        distances = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            distances(i) = min(dists);
        end

        idx = distances < delta_CL;
        if ~any(idx)
            msgbox(['Нет жертв с расстоянием до Compression Line менее ' num2str(delta_CL) '.'], 'Результат');
            return;
        end

        selected_prey = prey_points(idx, :);
        selected_dist = distances(idx);
        selected_indices = find(idx);

        dist_fig = figure('Name', ['Жертвы с расстоянием до Compression Line < ' num2str(delta_CL)], ...
                          'NumberTitle', 'off', ...
                          'Position', [300 300 500 400]);

        table_data = [selected_indices, selected_prey, selected_dist];
        column_names = {'Жертва №', 'X', 'Y', 'Расстояние'};

        uitable('Parent', dist_fig, ...
                'Data', table_data, ...
                'ColumnName', column_names, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.9]);

        disp(['Жертвы с расстоянием до Compression Line менее ' num2str(delta_CL) ' отображены в новом окне.']);
    end

    % --- Функции для работы с хищниками ---
    function toggle_add_predator_mode()
        if add_predator_mode
            add_predator_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления хищников (красные точки) ВЫКЛЮЧЕН.');
        else
            add_predator_mode = true;
            red.add_node_mode = false;
            comp.add_node_mode = false;
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
            predator_markers = update_predator_plot(ax, predator_points, predator_markers);
            disp(['Хищники загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    % --- Функции для работы с защитниками ---
    function toggle_add_defender_mode()
        if add_defender_mode
            add_defender_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления защитников (зелёные точки) ВЫКЛЮЧЕН.');
        else
            add_defender_mode = true;
            red.add_node_mode = false;
            comp.add_node_mode = false;
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
            defender_markers = update_defender_plot(ax, defender_points, defender_markers);
            disp(['Защитники загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    % --- Функции для работы с радарами хищников ---
    function toggle_add_radar_mode()
        if add_radar_mode
            add_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления радаров хищников ВЫКЛЮЧЕН.');
        else
            add_radar_mode = true;
            red.add_node_mode = false;
            comp.add_node_mode = false;
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
        radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                               show_predator_radar_borders, predator_radar_radius);
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
            radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                                   show_predator_radar_borders, predator_radar_radius);
            disp(['Радары хищников загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    function change_predator_radar_radius_cb()
        prompt = {'Введите новый радиус радара хищников (положительное число):'};
        dlgtitle = 'Изменение радиуса';
        dims = [1 50];
        definput = {num2str(predator_radar_radius)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        if isempty(answer)
            return;
        end
        val = str2double(answer{1});
        if isnan(val) || val <= 0
            errordlg('Необходимо ввести положительное число. Значение не изменено.', 'Ошибка ввода');
            return;
        end
        predator_radar_radius = val;
        disp(['Радиус радаров хищников установлен: ' num2str(predator_radar_radius)]);
        radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                               show_predator_radar_borders, predator_radar_radius);
    end

    % --- Функции для работы с радарами жертв ---
    function toggle_add_prey_radar_mode()
        if add_prey_radar_mode
            add_prey_radar_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления радаров жертв ВЫКЛЮЧЕН.');
        else
            add_prey_radar_mode = true;
            red.add_node_mode = false;
            comp.add_node_mode = false;
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
        prey_radar_handles = update_prey_radars(ax, prey_radar_centers, prey_radar_handles, ...
                                                show_prey_radar_borders);
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
            prey_radar_handles = update_prey_radars(ax, prey_radar_centers, prey_radar_handles, ...
                                                    show_prey_radar_borders);
            disp(['Радары жертв загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    % --- Функции для работы с жертвами ---
    function toggle_add_prey_mode()
        if add_prey_mode
            add_prey_mode = false;
            set(fig, 'Pointer', 'arrow');
            disp('Режим добавления жертв ВЫКЛЮЧЕН.');
        else
            add_prey_mode = true;
            red.add_node_mode = false;
            comp.add_node_mode = false;
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
            prey_markers = update_prey_plot(ax, prey_points, prey_markers);
            disp(['Жертвы загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
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
                if norm(predator_points(i,:) - radar_centers(r,:)) <= predator_radar_radius
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
                if norm(prey_points(j,:) - radar_centers(r,:)) <= predator_radar_radius
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

    % --- Функция: Расстояния от жертв до Compression Line < delta_CL (матрица стоимостей) ---
    function predator_prey_distances_compression_delta()
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
        if size(comp.node_points, 1) < 2
            errordlg('Недостаточно узлов Compression Line (минимум 2).', 'Ошибка');
            return;
        end

        pred_in_zone = false(size(predator_points,1), 1);
        for i = 1:size(predator_points,1)
            for r = 1:size(radar_centers,1)
                if norm(predator_points(i,:) - radar_centers(r,:)) <= predator_radar_radius
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
                if norm(prey_points(j,:) - radar_centers(r,:)) <= predator_radar_radius
                    prey_in_radar(j) = true;
                    break;
                end
            end
        end

        t = 1:size(comp.node_points, 1);
        tt = linspace(1, size(comp.node_points, 1), 100);
        xx = spline(t, comp.node_points(:,1), tt);
        yy = spline(t, comp.node_points(:,2), tt);
        spline_pts = [xx(:), yy(:)];

        num_prey = size(prey_points, 1);
        dist_to_comp = zeros(num_prey, 1);
        for i = 1:num_prey
            dx = prey_points(i,1) - spline_pts(:,1);
            dy = prey_points(i,2) - spline_pts(:,2);
            dists = sqrt(dx.^2 + dy.^2);
            dist_to_comp(i) = min(dists);
        end

        selected_prey_logical = prey_in_radar & (dist_to_comp < delta_CL);
        if ~any(selected_prey_logical)
            msgbox(['Нет жертв, удовлетворяющих условиям (в зоне радаров хищников и расстояние до Compression Line < ' num2str(delta_CL) ').'], ...
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

        dist_fig = figure('Name', ['Матрица расстояний (жертвы в ЗДР хищников и расстояние до Compression Line < ' num2str(delta_CL) ')'], ...
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

        disp(['Матрица расстояний (жертвы в ЗДР хищников и расстояние до Compression Line < ' num2str(delta_CL) ') отображена.']);
    end

    % ==================== ОБЁРТКИ ДЛЯ ВЕНГЕРСКИХ АЛГОРИТМОВ ====================
    function assign_hungarian_zdor()
        [assignment_lines, current_assignment_zdor] = hungarian_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_hungarian_cl()
        [assignment_lines, current_assignment_cl] = hungarian_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== ОБЁРТКИ ДЛЯ ЖАДНЫХ АЛГОРИТМОВ ====================
    function assign_greedy_zdor()
        [assignment_lines, current_assignment_zdor] = greedy_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_greedy_cl()
        [assignment_lines, current_assignment_cl] = greedy_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== ОБЁРТКИ ДЛЯ ГЕНЕТИЧЕСКИХ АЛГОРИТМОВ ====================
    function assign_genetic_zdor()
        [assignment_lines, current_assignment_zdor] = genetic_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_genetic_cl()
        [assignment_lines, current_assignment_cl] = genetic_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== ОБЁРТКИ ДЛЯ АУКЦИОННЫХ АЛГОРИТМОВ ====================
    function assign_auction_zdor()
        [assignment_lines, current_assignment_zdor] = auction_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_auction_cl()
        [assignment_lines, current_assignment_cl] = auction_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== ОБЁРТКИ ДЛЯ АЛГОРИТМА БЛИЖАЙШЕГО СОСЕДА ====================
    function assign_nearest_zdor()
        [assignment_lines, current_assignment_zdor] = nearest_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_nearest_cl()
        [assignment_lines, current_assignment_cl] = nearest_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== ОБЁРТКИ ДЛЯ НЕЙРОСЕТЕВЫХ АЛГОРИТМОВ ====================
    function assign_neural_zdor()
        [assignment_lines, current_assignment_zdor] = neural_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines);
    end

    function assign_neural_cl()
        [assignment_lines, current_assignment_cl] = neural_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp.node_points, delta_CL, assignment_lines);
    end

    % ==================== АНИМАЦИЯ ДЛЯ ВЕНГЕРСКОГО ====================
    function animate_hungarian_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Венгерский алгоритм (Х) -> Матрица стоимостей ЗДР (В)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_hungarian_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Венгерский алгоритм (Х) -> Матрица стоимостей CL (В)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== АНИМАЦИЯ ДЛЯ ЖАДНОГО ====================
    function animate_greedy_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Жадный алгоритм (Х) -> Матрица стоимостей ЗДР (Ж)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_greedy_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Жадный алгоритм (Х) -> Матрица стоимостей CL (Ж)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== АНИМАЦИЯ ДЛЯ ГЕНЕТИЧЕСКОГО ====================
    function animate_genetic_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Генетический алгоритм (Х) -> Матрица стоимостей ЗДР (Г)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_genetic_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Генетический алгоритм (Х) -> Матрица стоимостей CL (Г)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== АНИМАЦИЯ ДЛЯ АУКЦИОННОГО ====================
    function animate_auction_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Аукционный алгоритм (Х) -> Матрица стоимостей ЗДР (А)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_auction_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Аукционный алгоритм (Х) -> Матрица стоимостей CL (А)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== АНИМАЦИЯ ДЛЯ БЛИЖАЙШЕГО СОСЕДА ====================
    function animate_nearest_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Ближайший сосед (Х) -> Матрица стоимостей ЗДР (БС)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_nearest_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Ближайший сосед (Х) -> Матрица стоимостей CL (БС)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== АНИМАЦИЯ ДЛЯ НЕЙРОСЕТЕВОГО ====================
    function animate_neural_zdor()
        if isempty(current_assignment_zdor)
            errordlg('Сначала выполните распределение "Нейросетевой алгоритм (Х) -> Матрица стоимостей ЗДР (НС)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_zdor, 'ZDR', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    function animate_neural_cl()
        if isempty(current_assignment_cl)
            errordlg('Сначала выполните распределение "Нейросетевой алгоритм (Х) -> Матрица стоимостей CL (НС)".', 'Ошибка');
            return;
        end
        state = struct('predator_points', predator_points, 'prey_points', prey_points, ...
                       'defender_points', defender_points, 'predator_markers', predator_markers, ...
                       'prey_markers', prey_markers, 'defender_markers', defender_markers, ...
                       'assignment_lines', assignment_lines);
        state = run_generic_animation(ax, fig, current_assignment_cl, 'CL', state, red, duelDistance, predWinProb, defenderWinProb);
        predator_points = state.predator_points;
        prey_points = state.prey_points;
        defender_points = state.defender_points;
        predator_markers = state.predator_markers;
        prey_markers = state.prey_markers;
        defender_markers = state.defender_markers;
        assignment_lines = state.assignment_lines;
    end

    % ==================== ФУНКЦИИ СОХРАНЕНИЯ И ЗАГРУЗКИ ВСЕХ ДАННЫХ ====================
    function save_all_data()
        [fname, pname] = uiputfile('*.mat', 'Сохранить все данные');
        if isequal(fname, 0)
            return;
        end
        full = fullfile(pname, fname);
        try
            data.node_points = red.node_points;
            data.comp_node_points = comp.node_points;
            data.predator_points = predator_points;
            data.prey_points = prey_points;
            data.defender_points = defender_points;
            data.radar_centers = radar_centers;
            data.prey_radar_centers = prey_radar_centers;
            data.show_nodes = red.show_nodes;
            data.show_comp_nodes = comp.show_nodes;
            data.show_predator_radar_borders = show_predator_radar_borders;
            data.show_prey_radar_borders = show_prey_radar_borders;
            data.current_assignment_zdor = current_assignment_zdor;
            data.current_assignment_cl = current_assignment_cl;
            data.maxPredPerPrey = maxPredPerPrey;
            data.delta_CL = delta_CL;
            data.duelDistance = duelDistance;
            data.predWinProb = predWinProb;
            data.defenderWinProb = defenderWinProb;
            data.predator_radar_radius = predator_radar_radius;
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
                red.node_points = data.node_points;
            else
                red.node_points = [];
            end
            if isfield(data, 'comp_node_points')
                comp.node_points = data.comp_node_points;
            else
                comp.node_points = [];
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
                red.show_nodes = data.show_nodes;
            else
                red.show_nodes = true;
            end
            if isfield(data, 'show_comp_nodes')
                comp.show_nodes = data.show_comp_nodes;
            else
                comp.show_nodes = true;
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
            if isfield(data, 'maxPredPerPrey')
                maxPredPerPrey = data.maxPredPerPrey;
            else
                maxPredPerPrey = 3;
            end
            if isfield(data, 'delta_CL')
                delta_CL = data.delta_CL;
            else
                delta_CL = 100;
            end
            if isfield(data, 'duelDistance')
                duelDistance = data.duelDistance;
            else
                duelDistance = 15;
            end
            if isfield(data, 'predWinProb')
                predWinProb = data.predWinProb;
            else
                predWinProb = 0.5;
            end
            if isfield(data, 'defenderWinProb')
                defenderWinProb = data.defenderWinProb;
            else
                defenderWinProb = 0.5;
            end
            if isfield(data, 'predator_radar_radius')
                predator_radar_radius = data.predator_radar_radius;
            else
                predator_radar_radius = 300;
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

            red = update_spline_plot(ax, red);
            comp = update_comp_spline_plot(ax, comp);
            predator_markers = update_predator_plot(ax, predator_points, predator_markers);
            prey_markers = update_prey_plot(ax, prey_points, prey_markers);
            defender_markers = update_defender_plot(ax, defender_points, defender_markers);
            radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                                   show_predator_radar_borders, predator_radar_radius);
            prey_radar_handles = update_prey_radars(ax, prey_radar_centers, prey_radar_handles, ...
                                                    show_prey_radar_borders);

            disp(['Данные загружены из ' full]);
        catch ME
            errordlg(['Ошибка загрузки: ' ME.message], 'Ошибка');
        end
    end

    % ==================== ФУНКЦИИ МЕНЮ ФАЙЛ ====================
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
        draw_axes_lines(ax);
        red.node_points = [];
        red.spline_line = [];
        red.point_markers = [];
        red.show_nodes = true;
        red.add_node_mode = false;
        comp.node_points = [];
        comp.spline_line = [];
        comp.point_markers = [];
        comp.show_nodes = true;
        comp.add_node_mode = false;
        predator_points = [];
        prey_points = [];
        defender_points = [];
        radar_centers = [];
        prey_radar_centers = [];
        add_predator_mode = false;
        add_prey_mode = false;
        add_defender_mode = false;
        add_radar_mode = false;
        add_prey_radar_mode = false;
        show_predator_radar_borders = false;
        show_prey_radar_borders = false;
        maxPredPerPrey = 3;
        delta_CL = 100;
        duelDistance = 15;
        predWinProb = 0.5;
        defenderWinProb = 0.5;
        predator_radar_radius = 300;
        set(border_pred_menu, 'Checked', 'off');
        set(border_prey_menu, 'Checked', 'off');
        set(fig, 'Pointer', 'arrow');
        if ~isempty(assignment_lines) && any(ishandle(assignment_lines))
            delete(assignment_lines);
        end
        assignment_lines = [];
        current_assignment_zdor = [];
        current_assignment_cl = [];
        red = update_spline_plot(ax, red);
        comp = update_comp_spline_plot(ax, comp);
        predator_markers = update_predator_plot(ax, predator_points, predator_markers);
        prey_markers = update_prey_plot(ax, prey_points, prey_markers);
        defender_markers = update_defender_plot(ax, defender_points, defender_markers);
        radar_handles = update_predator_radars(ax, radar_centers, radar_handles, ...
                                               show_predator_radar_borders, predator_radar_radius);
        prey_radar_handles = update_prey_radars(ax, prey_radar_centers, prey_radar_handles, ...
                                                show_prey_radar_borders);
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
                    draw_axes_lines(ax);
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
                    draw_axes_lines(ax);
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

end % end of triple_animation_def_video