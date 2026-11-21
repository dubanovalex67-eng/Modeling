function test_pursuit()
clc, clear;
    rng('shuffle');

    % ============================================================
    % ---- Папка для видео ----
    % ============================================================
    video_dir = fullfile(pwd, 'video');
    if ~exist(video_dir, 'dir')
        mkdir(video_dir);
    end
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    video_base = fullfile(video_dir, sprintf('pursuit_%s', stamp));

    % ============================================================
    % ---- Рандомизация ----
    % ============================================================
    N     = ask_num_pursuers();   % <== ИНТЕРАКТИВНЫЙ ВВОД
    N_obs = randi([1, 5]);
    fprintf('Преследователей: %d (задано пользователем), препятствий: %d\n', ...
            N, N_obs);

    % ---- Номинальная траектория цели ----
    p0 = [8 8]; A_amp = [6 4]; omega = 0.3;
    nominal_fun = @(t) p0 + A_amp .* sin(omega * t);
    nominal_vel = @(t) A_amp .* omega .* cos(omega * t);

    % ============================================================
    % ---- Параметры опций (нужны для валидации препятствий) ----
    % ============================================================
    R_obs_pad   = 0.4;    % должен совпадать с opts.R_obs_pad ниже
    R_safe      = 1.2;    % зона комфорта для преследователей
    t_end_sim   = 120;

    % ============================================================
    % ---- Мобильные препятствия (безопасные траектории) ----
    % ============================================================
    [obstacles, obs_center0, obs_amp, obs_omega, obs_phase] = ...
        make_safe_obstacles(N_obs, R_obs_pad, t_end_sim);

    % ============================================================
    % ---- Преследователи (вне препятствий на t = 0) ----
    % ============================================================
    [P0, V0] = make_safe_pursuers(N, obstacles, 0, R_safe);

    opts.dt              = 0.02;
    opts.t_end           = 120;
    opts.K_p             = 2.0;
    opts.arrive_tol      = 0.6;
    opts.w_obs           = 4.0;
    opts.R_obs_pad       = 0.4;
    opts.R_obs_soft      = 2.0;
    opts.R_safe          = 1.2;
    opts.w_rep           = 5;
    opts.k_attach        = 1.5;
    opts.vmax            = 1.8 * ones(N,1);
    opts.amax            = 1.0 * ones(N,1);
    opts.verbose         = true;
    opts.inertia_p       = 0.5;
    opts.capture_on_first = true;   % <== остановка при первом захвате

    tgt.vmax       = 1.2;
    tgt.amax       = 0.8;
    tgt.K_p        = 2.0;
    tgt.R_obs_pad  = 0.4;
    tgt.R_obs_soft = 2.0;
    tgt.k_attach   = 1.5;
    tgt.sigma_ou   = 0.35;
    tgt.tau_ou     = 1.5;
    tgt.inertia    = 0.6;
    tgt.jump_prob  = 0.002;
    tgt.jump_mag   = 0.8;
    tgt.rng_seed   = 42;

    % ============================================================
    % ---- Шаг 1: цель ----
    % ============================================================
    [T_hist_pre, ~] = simulate_target(nominal_fun, nominal_vel, ...
        obstacles, tgt, opts.dt, opts.t_end);

    tt = (0:opts.dt:(size(T_hist_pre,1)-1)*opts.dt).';
    target_fun = @(t) target_lookup(t, tt, T_hist_pre);

    % ============================================================
    % ---- Шаг 2: преследователи ----
    % ============================================================
    [P, T_hist, arrival_times, t_hist, arrived_hist, capture_info] = ...
        group_pursuit(P0, V0, target_fun, obstacles, opts);

    % ============================================================
    % ---- Отчёт: результат миссии ----
    % ============================================================
    fprintf('\n--- Результат миссии ---\n');
    if capture_info.captured
        fprintf('ЦЕЛЬ ЗАХВАЧЕНА преследователем %d в t = %.2f c.\n', ...
                capture_info.who, capture_info.t_capture);
        fprintf('Движение всех преследователей и цели остановлено.\n');
    else
        fprintf('Цель НЕ захвачена за отведённое время (t_end = %.1f c).\n', ...
                opts.t_end);
    end

    % ============================================================
    % ---- Отчёт: времена прибытия ----
    % ============================================================
    fprintf('\nВремя прибытия каждого преследователя (при захвате — момент захвата):\n');
    for i = 1:N
        if isnan(arrival_times(i))
            fprintf('  Преследователь %d: НЕ достиг\n', i);
        else
            fprintf('  Преследователь %d: t = %.2f c\n', i, arrival_times(i));
        end
    end
    if all(~isnan(arrival_times)) && N > 1
        spread = max(arrival_times) - min(arrival_times);
        fprintf('\nРазброс времён прибытия: %.2f c (%s)\n', spread, ...
            ternary(spread < 0.5, 'одновременно', 'синхронизация слабая'));
    end

    % ============================================================
    % ---- Столкновения между преследователями ----
    % ============================================================
    R_collide = 0.8;
    R_warn    = opts.R_safe;

    min_d = inf;
    min_d_pair = [0 0];
    min_d_time = 0;
    collisions = 0;
    collisions_pair = zeros(N);
    warnings = 0;
    collision_events = [];
    prev_in_collision = false(N, N);

    M_steps = size(P.pos,3);
    for k = 1:M_steps
        pts = reshape(P.pos(:,:,k), N, 2);
        for i = 1:N
            for j = i+1:N
                d = norm(pts(i,:) - pts(j,:));
                if d < min_d
                    min_d = d;
                    min_d_pair = [i j];
                    min_d_time = t_hist(k);
                end
                if d < 2*R_collide
                    collisions = collisions + 1;
                    collisions_pair(i,j) = collisions_pair(i,j) + 1;
                    collisions_pair(j,i) = collisions_pair(j,i) + 1;
                    if ~prev_in_collision(i,j)
                        collision_events = [collision_events; ...
                            t_hist(k), i, j, d]; %#ok<AGROW>
                    end
                    prev_in_collision(i,j) = true;
                    prev_in_collision(j,i) = true;
                else
                    prev_in_collision(i,j) = false;
                    prev_in_collision(j,i) = false;
                end
                if d < R_warn
                    warnings = warnings + 1;
                end
            end
        end
    end

    fprintf('\n--- Столкновения между преследователями ---\n');
    if N > 1
        fprintf('Мин. дистанция: %.3f (между %d и %d в t = %.2f c)\n', ...
                min_d, min_d_pair(1), min_d_pair(2), min_d_time);
    else
        fprintf('Только один преследователь — столкновения не применимы\n');
    end
    fprintf('Зона безопасности (d < %.2f): %d случаев\n', R_warn, warnings);
    fprintf('Физические столкновения (d < %.2f): %d замеров\n', ...
            2*R_collide, collisions);

    if isempty(collision_events)
        fprintf('  -> столкновений между преследователями НЕТ\n');
    else
        fprintf('  -> ЗАФИКСИРОВАНО %d событий столкновения:\n', ...
                size(collision_events,1));
        for e = 1:size(collision_events,1)
            fprintf('     t = %6.2f c : агент %d <-> агент %d (d = %.3f)\n', ...
                collision_events(e,1), collision_events(e,2), ...
                collision_events(e,3), collision_events(e,4));
        end
    end

    if collisions > 0
        fprintf('Матрица столкновений (число замеров):\n');
        fprintf('       ');
        for j = 1:N, fprintf('  аг.%d ', j); end
        fprintf('\n');
        for i = 1:N
            fprintf('аг.%d : ', i);
            for j = 1:N
                if i == j
                    fprintf('   --  ');
                else
                    fprintf(' %5d ', collisions_pair(i,j));
                end
            end
            fprintf('\n');
        end
    end

    fprintf('\n--- Сводка по безопасности ---\n');
    fprintf('R_safe       = %.2f\n', opts.R_safe);
    fprintf('R_collide    = %.2f (физ. радиус, столкновение при d < %.2f)\n', ...
            R_collide, 2*R_collide);
    if N > 1
        fprintf('Мин. дистанция в группе: %.3f (%s)\n', min_d, ...
            ternary(min_d > opts.R_safe, 'OK', ...
            ternary(min_d > 2*R_collide, 'зона безопасности', 'СТОЛКНОВЕНИЕ')));
    end

    % ============================================================
    % ---- Зазоры до МОБИЛЬНЫХ препятствий ----
    % ============================================================
    min_obs = inf; viol_p = 0;
    for k = 1:size(P.pos,3)
        obs_c = obstacles.fun(t_hist(k));
        for i = 1:N
            for oi = 1:N_obs
                d = norm(reshape(P.pos(i,:,k), 1, 2) - obs_c(oi,:)) - obstacles.R(oi);
                min_obs = min(min_obs, d);
                if d < -1e-6, viol_p = viol_p + 1; end
            end
        end
    end
    fprintf('\nМин. зазор преследователей до препятствий: %.3f\n', min_obs);
    if viol_p == 0
        fprintf('  -> столкновений преследователей с препятствиями НЕТ\n');
    else
        fprintf('  -> ВНИМАНИЕ: %d случаев проникновения!\n', viol_p);
    end

    min_obs_t = inf; viol_t = 0;
    for k = 1:size(T_hist,1)
        obs_c = obstacles.fun(t_hist(k));
        for oi = 1:N_obs
            d = norm(T_hist(k,:) - obs_c(oi,:)) - obstacles.R(oi);
            min_obs_t = min(min_obs_t, d);
            if d < -1e-6, viol_t = viol_t + 1; end
        end
    end
    fprintf('Мин. зазор ЦЕЛИ до препятствий: %.3f\n', min_obs_t);
    if viol_t == 0
        fprintf('  -> цель тоже обходит препятствия, столкновений НЕТ\n');
    else
        fprintf('  -> ВНИМАНИЕ: цель %d раз вошла в препятствие!\n', viol_t);
    end

    % ============================================================
    % ---- Зазоры МЕЖДУ препятствиями (проверка новой генерации) ----
    % ============================================================
    min_obs_obs = inf; viol_oo = 0;
    for k = 1:numel(t_hist)
        obs_c = obstacles.fun(t_hist(k));
        for oi = 1:N_obs
            for oj = oi+1:N_obs
                d = norm(obs_c(oi,:) - obs_c(oj,:)) ...
                    - (obstacles.R(oi) + obstacles.R(oj));
                min_obs_obs = min(min_obs_obs, d);
                if d < -1e-6, viol_oo = viol_oo + 1; end
            end
        end
    end
    if N_obs > 1
        fprintf('\nМин. зазор МЕЖДУ препятствиями (без учёта pad): %.3f\n', ...
                min_obs_obs);
        if viol_oo == 0
            fprintf('  -> препятствия не пересекаются\n');
        else
            fprintf('  -> ВНИМАНИЕ: %d пересечений препятствий!\n', viol_oo);
        end
    end

    % =========================================================
    % ---- Статическая визуализация ----
    % =========================================================
    colors = lines(max(N,3));
    th = linspace(0, 2*pi, 100);

    figure('Name','Траектории','Color','w'); hold on; axis equal; grid on;

    tk_show = [0, t_hist(end)];
    for oi = 1:N_obs
        obs_traj = zeros(numel(t_hist), 2);
        for kk = 1:numel(t_hist)
            cc = obstacles.fun(t_hist(kk));
            obs_traj(kk,:) = cc(oi,:);
        end
        plot(obs_traj(:,1), obs_traj(:,2), ':', ...
             'Color', [0.7 0.4 0.4], 'LineWidth', 0.8);
        for tt_show = tk_show
            cc = obstacles.fun(tt_show);
            c = cc(oi,:);
            rr = obstacles.R(oi);
            fill(c(1) + rr*cos(th), c(2) + rr*sin(th), [0.6 0.6 0.6], ...
                 'EdgeColor','k', 'FaceAlpha', 0.4);
            rb = rr + opts.R_obs_pad;
            plot(c(1) + rb*cos(th), c(2) + rb*sin(th), '--', ...
                 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
        end
    end

    plot(T_hist_pre(:,1), T_hist_pre(:,2), ':', ...
         'Color', [0.8 0.6 0.2], 'LineWidth', 1.0);

    hLegend = gobjects(1, N+2);
    for i = 1:N
        traj = reshape(P.pos(i,:,:), 2, []).';
        hLegend(i) = plot(traj(:,1), traj(:,2), '-', ...
                          'Color', colors(i,:), 'LineWidth', 1.6);
        plot(traj(1,1), traj(1,2), 'o', 'MarkerFaceColor', colors(i,:), ...
             'MarkerEdgeColor','k', 'MarkerSize', 8);
        if ~isnan(arrival_times(i))
            plot(traj(end,1), traj(end,2), 's', 'MarkerFaceColor', colors(i,:), ...
                 'MarkerEdgeColor','k', 'MarkerSize', 8);
        end
    end
    hLegend(N+1) = plot(T_hist(:,1), T_hist(:,2), 'k--', 'LineWidth', 2);
    hLegend(N+2) = plot(T_hist(end,1), T_hist(end,2), 'kp', ...
                        'MarkerSize', 16, 'MarkerFaceColor','y');
    legend(hLegend, ...
        [arrayfun(@(i) sprintf('Преследователь %d',i), 1:N, 'uni', 0), ...
         {'Цель','Финиш цели'}], 'Location','best');
    xlabel('X'); ylabel('Y');
    title(sprintf('Преследование (N=%d, препятствий=%d, мобильные)', N, N_obs));

    % =========================================================
    % ---- Анимация (на экране) ----
    % =========================================================
    figure('Name','Анимация','Color','w');
    hold on; axis equal; grid on;

    allX = [reshape(P.pos(:,1,:), N, []); T_hist(:,1).'];
    allY = [reshape(P.pos(:,2,:), N, []); T_hist(:,2).'];
    xlim([min(allX,[],'all')-2, max(allX,[],'all')+2]);
    ylim([min(allY,[],'all')-2, max(allY,[],'all')+2]);

    hObsFill = gobjects(N_obs,1);
    hObsRing = gobjects(N_obs,1);
    for oi = 1:N_obs
        hObsFill(oi) = fill(NaN, NaN, [0.6 0.6 0.6], ...
                            'EdgeColor','k', 'FaceAlpha', 0.6);
        hObsRing(oi) = plot(NaN, NaN, '--', ...
                            'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    end

    hTrail = gobjects(N,1);
    for i = 1:N
        hTrail(i) = plot(NaN, NaN, '-', 'Color', colors(i,:), 'LineWidth', 1.2);
    end
    hP = gobjects(N,1);
    for i = 1:N
        hP(i) = plot(P0(i,1), P0(i,2), 'o', 'MarkerFaceColor', colors(i,:), ...
                     'MarkerEdgeColor','k', 'MarkerSize', 10);
    end
    hT = plot(T_hist(1,1), T_hist(1,2), 'kp', 'MarkerFaceColor','y', ...
              'MarkerSize', 16);
    hQuiv = quiver(zeros(1,N), zeros(1,N), zeros(1,N), zeros(1,N), 0.5, ...
                   'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    hTitle = title('Анимация (t = 0.00 c)');
    xlabel('X'); ylabel('Y');

    M = min(size(P.pos,3), size(T_hist,1));
    frame_skip  = 5;
    frame_pause = 0.02;

    for k = 1:frame_skip:M
        obs_c = obstacles.fun(t_hist(k));
        for oi = 1:N_obs
            c = obs_c(oi,:); rr = obstacles.R(oi);
            set(hObsFill(oi), 'XData', c(1)+rr*cos(th), 'YData', c(2)+rr*sin(th));
            rb = rr + opts.R_obs_pad;
            set(hObsRing(oi), 'XData', c(1)+rb*cos(th), 'YData', c(2)+rb*sin(th));
        end

        for i = 1:N
            set(hP(i), 'XData', P.pos(i,1,k), 'YData', P.pos(i,2,k));
            if arrived_hist(i,k)
                set(hP(i), 'Marker', 'p', 'MarkerEdgeColor', 'g', ...
                           'LineWidth', 1.5);
            end
            set(hTrail(i), 'XData', reshape(P.pos(i,1,1:k), 1, []), ...
                           'YData', reshape(P.pos(i,2,1:k), 1, []));
        end
        set(hT, 'XData', T_hist(k,1), 'YData', T_hist(k,2));
        set(hQuiv, 'XData', reshape(P.pos(:,1,k), 1, N), ...
                   'YData', reshape(P.pos(:,2,k), 1, N), ...
                   'UData', reshape(P.vel(:,1,k), 1, N), ...
                   'VData', reshape(P.vel(:,2,k), 1, N));
        set(hTitle, 'String', sprintf('Анимация (t = %.2f c)', t_hist(k)));
        drawnow; pause(frame_pause);
    end

    % =========================================================
    % ---- Запись видео в отдельную папку ----
    % =========================================================
    record_video(video_base, P, T_hist, t_hist, arrived_hist, ...
                 obstacles, opts, P0, colors, th, N, N_obs, frame_skip, 30);

    fprintf('\nГотово. Видео сохранено:\n');
    for f = dir([video_base '.*']).'
        fprintf('  %s\n', fullfile(video_dir, f.name));
    end
end

% =========================================================
% ---- Интерактивный ввод числа преследователей ----
% =========================================================
function N = ask_num_pursuers()
%ASK_NUM_PURSUERS Модальное окно ввода N в диапазоне 1..10.
%
% Возвращает:
%   N — целое 1..10.
%       Если пользователь закрыл окно/нажал «Отмена» — возвращает
%       случайное значение randi([1,10]) (как в прежнем поведении).

    N_MIN = 1;
    N_MAX = 10;
    default_N = randi([N_MIN, N_MAX]);

    % ---------- фигура ----------
    d = dialog('Name','Число преследователей', ...
               'Position',[500 400 360 200]);
    set(d, 'Color', 'w');

    uicontrol(d, 'Style','text', ...
        'String','Введите число преследователей (1..10):', ...
        'FontSize', 11, 'FontWeight','bold', ...
        'Units','normalized', 'Position',[0.05 0.78 0.90 0.16], ...
        'HorizontalAlignment','left', 'BackgroundColor','w');

    hEdit = uicontrol(d, 'Style','edit', ...
        'String', num2str(default_N), ...
        'FontSize', 12, 'FontWeight','bold', ...
        'Units','normalized', 'Position',[0.30 0.56 0.40 0.16], ...
        'BackgroundColor',[1 1 0.95], 'Callback',@onOK);

    uicontrol(d, 'Style','text', ...
        'String', sprintf('Допустимый диапазон: %d..%d', N_MIN, N_MAX), ...
        'FontSize', 9, 'ForegroundColor',[0.4 0.4 0.4], ...
        'Units','normalized', 'Position',[0.05 0.40 0.90 0.12], ...
        'HorizontalAlignment','center', 'BackgroundColor','w');

    uicontrol(d, 'Style','pushbutton', 'String','Случайно', ...
        'FontSize', 10, ...
        'Units','normalized', 'Position',[0.05 0.10 0.28 0.18], ...
        'Callback', @onRandom);

    uicontrol(d, 'Style','pushbutton', 'String','Отмена', ...
        'FontSize', 10, ...
        'Units','normalized', 'Position',[0.36 0.10 0.28 0.18], ...
        'Callback', @onCancel);

    uicontrol(d, 'Style','pushbutton', 'String','OK', ...
        'FontSize', 10, 'FontWeight','bold', ...
        'Units','normalized', 'Position',[0.67 0.10 0.28 0.18], ...
        'BackgroundColor',[0.85 0.95 0.85], ...
        'Callback', @onOK);

    % ---------- состояние ----------
    result_N  = default_N;
    confirmed = false;

    % ---------- модальное ожидание ----------
    uiwait(d);
    if isvalid(d), delete(d); end

    if confirmed
        N = result_N;
    else
        N = randi([N_MIN, N_MAX]);
        fprintf('[ask_num_pursuers] окно закрыто — случайное N = %d\n', N);
    end

    % ============================================================
    % ---- Вложенные колбэки ----
    % ============================================================
    function onOK(~,~)
        v = str2double(get(hEdit, 'String'));
        if isnan(v) || v < N_MIN || v > N_MAX || mod(v,1) ~= 0
            errordlg( ...
                sprintf('Введите ЦЕЛОЕ число от %d до %d.', N_MIN, N_MAX), ...
                'Неверный ввод', 'modal');
            set(hEdit, 'String', num2str(default_N));
            return;
        end
        result_N  = v;
        confirmed = true;
        uiresume(d);
    end

    function onRandom(~,~)
        result_N  = randi([N_MIN, N_MAX]);
        confirmed = true;
        set(hEdit, 'String', num2str(result_N));
        uiresume(d);
    end

    function onCancel(~,~)
        confirmed = false;
        uiresume(d);
    end
end

% =========================================================
% ---- Запись видео ----
% =========================================================
function record_video(video_base, P, T_hist, t_hist, arrived_hist, ...
                      obstacles, opts, P0, colors, th, N, N_obs, frame_skip, fps)
    hFigVid = figure('Name','VideoRender', 'Color','w', ...
                     'Visible','off', 'Position',[100 100 900 720]);
    ax = axes('Parent', hFigVid); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');

    allX = [reshape(P.pos(:,1,:), N, []); T_hist(:,1).'];
    allY = [reshape(P.pos(:,2,:), N, []); T_hist(:,2).'];
    xlim(ax, [min(allX,[],'all')-2, max(allX,[],'all')+2]);
    ylim(ax, [min(allY,[],'all')-2, max(allY,[],'all')+2]);
    xlabel(ax,'X'); ylabel(ax,'Y');

    hObsFill = gobjects(N_obs,1);
    hObsRing = gobjects(N_obs,1);
    for oi = 1:N_obs
        hObsFill(oi) = fill(ax, NaN, NaN, [0.6 0.6 0.6], ...
                            'EdgeColor','k', 'FaceAlpha', 0.6);
        hObsRing(oi) = plot(ax, NaN, NaN, '--', ...
                            'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    end

    hTrail = gobjects(N,1);
    for i = 1:N
        hTrail(i) = plot(ax, NaN, NaN, '-', 'Color', colors(i,:), 'LineWidth', 1.2);
    end
    hP = gobjects(N,1);
    for i = 1:N
        hP(i) = plot(ax, P0(i,1), P0(i,2), 'o', 'MarkerFaceColor', colors(i,:), ...
                     'MarkerEdgeColor','k', 'MarkerSize', 10);
    end
    hT = plot(ax, T_hist(1,1), T_hist(1,2), 'kp', 'MarkerFaceColor','y', ...
              'MarkerSize', 16);
    hQuiv = quiver(ax, zeros(1,N), zeros(1,N), zeros(1,N), zeros(1,N), 0.5, ...
                   'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
    hTitle = title(ax, 'Анимация (t = 0.00 c)');

    nFrames = numel(1:frame_skip:min(size(P.pos,3), size(T_hist,1)));
    vw = [];
    video_path = '';
    try
        video_path = [video_base '.mp4'];
        vw = VideoWriter(video_path, 'MPEG-4');
        vw.FrameRate = fps;
        vw.Quality   = 95;
        open(vw);
    catch ME
        fprintf('MPEG-4 недоступен (%s), переключаюсь на Motion JPEG AVI\n', ...
                ME.message);
        if ~isempty(vw), try, close(vw); catch, end, end
        video_path = [video_base '.avi'];
        vw = VideoWriter(video_path, 'Motion JPEG AVI');
        vw.FrameRate = fps;
        vw.Quality   = 95;
        open(vw);
    end

    M = min(size(P.pos,3), size(T_hist,1));
    for k = 1:frame_skip:M
        obs_c = obstacles.fun(t_hist(k));
        for oi = 1:N_obs
            c = obs_c(oi,:); rr = obstacles.R(oi);
            set(hObsFill(oi), 'XData', c(1)+rr*cos(th), 'YData', c(2)+rr*sin(th));
            rb = rr + opts.R_obs_pad;
            set(hObsRing(oi), 'XData', c(1)+rb*cos(th), 'YData', c(2)+rb*sin(th));
        end
        for i = 1:N
            set(hP(i), 'XData', P.pos(i,1,k), 'YData', P.pos(i,2,k));
            if arrived_hist(i,k)
                set(hP(i), 'Marker', 'p', 'MarkerEdgeColor', 'g', 'LineWidth', 1.5);
            end
            set(hTrail(i), 'XData', reshape(P.pos(i,1,1:k), 1, []), ...
                           'YData', reshape(P.pos(i,2,1:k), 1, []));
        end
        set(hT, 'XData', T_hist(k,1), 'YData', T_hist(k,2));
        set(hQuiv, 'XData', reshape(P.pos(:,1,k), 1, N), ...
                   'YData', reshape(P.pos(:,2,k), 1, N), ...
                   'UData', reshape(P.vel(:,1,k), 1, N), ...
                   'VData', reshape(P.vel(:,2,k), 1, N));
        set(hTitle, 'String', sprintf('Анимация (t = %.2f c)', t_hist(k)));

        drawnow;
        frame = getframe(hFigVid);
        writeVideo(vw, frame);
    end

    close(vw);
    close(hFigVid);

    fprintf('Записано кадров: %d, файл: %s\n', nFrames, video_path);
end

% =========================================================
% ---- Симуляция цели ----
% =========================================================
function [T_hist, V_hist] = simulate_target(nominal_fun, nominal_vel, ...
        obstacles, tgt, dt, t_end)
    N_obs = numel(obstacles.R);
    R_barrier = obstacles.R(:) + tgt.R_obs_pad;

    sigma_ou  = getfield_default(tgt, 'sigma_ou',  0.35);
    tau_ou    = getfield_default(tgt, 'tau_ou',    1.5);
    inertia   = getfield_default(tgt, 'inertia',   0.6);
    jump_prob = getfield_default(tgt, 'jump_prob', 0.0);
    jump_mag  = getfield_default(tgt, 'jump_mag',  0.8);
    rng_seed  = getfield_default(tgt, 'rng_seed',  42);
    rng(rng_seed);

    maxSteps = ceil(t_end / dt) + 1;
    T_hist = nan(maxSteps, 2);
    V_hist = nan(maxSteps, 2);

    p = nominal_fun(0);
    v = nominal_vel(0);
    xi = [0 0];
    bypass_dir = 0;
    bypass_obs = 0;

    k = 1;
    T_hist(k,:) = p;
    V_hist(k,:) = v;
    t = 0;

    while t < t_end
        v_nom = nominal_vel(t);
        dW = randn(1,2) * sqrt(dt);
        xi = xi - (xi / tau_ou) * dt + sigma_ou * sqrt(2/tau_ou) * dW;

        if jump_prob > 0 && rand < jump_prob
            jump = randn(1,2);
            jump = jump / max(norm(jump), 1e-6) * jump_mag;
            v = v + jump;
        end

        lookahead = 0.5;
        p_goal = nominal_fun(t + lookahead);

        to_goal = p_goal - p;
        dist = norm(to_goal);
        if dist < 1e-9, dir_g = [0 0]; else, dir_g = to_goal / dist; end

        v_des = dir_g * min(dist / lookahead, tgt.vmax) + ...
                0.3*(v_nom - v) + xi;
        v_des = limit_norm_local(v_des, tgt.vmax);

        obs_c = obstacles.fun(t);
        if isfield(obstacles, 'vel'), obs_v = obstacles.vel(t);
        else, obs_v = zeros(N_obs, 2); end

        visible = true;
        for oi = 1:N_obs
            if segment_circle_intersect(p, p_goal, ...
                    obs_c(oi,:), R_barrier(oi) + 1e-3)
                visible = false; break;
            end
        end

        nearest_oi = 0; nearest_gap = inf; nearest_n_out = [0 0];
        for oi = 1:N_obs
            c = obs_c(oi, :); diff = p - c; dc = norm(diff);
            gap = dc - R_barrier(oi);
            if gap < nearest_gap
                nearest_gap = gap; nearest_oi = oi;
                if dc > 1e-6, nearest_n_out = diff / dc; end
            end
        end

        f_obs = [0 0];

        if ~visible
            n_out = nearest_n_out;
            t_out = [-n_out(2), n_out(1)];
            if bypass_dir == 0
                side = sign( (p_goal(1)-p(1))*n_out(2) ...
                           - (p_goal(2)-p(2))*n_out(1) );
                if side == 0, side = 1; end
                bypass_dir = side; bypass_obs = nearest_oi;
            end
            if bypass_obs ~= nearest_oi, bypass_dir = 0; end
            v_tan = bypass_dir * tgt.vmax * t_out;
            v_rad = -tgt.k_attach * max(nearest_gap, -tgt.R_obs_pad) * n_out;
            v_des = limit_norm_local(v_tan + v_rad, tgt.vmax);
            v_des = v_des + 0.5 * obs_v(nearest_oi, :);
        else
            bypass_dir = 0; bypass_obs = 0;
            for oi = 1:N_obs
                c = obs_c(oi, :); diff = p - c; dc = norm(diff);
                d_edge = dc - obstacles.R(oi);
                if d_edge < tgt.R_obs_soft && dc > 1e-6
                    dist_to_barrier = max(d_edge - tgt.R_obs_pad, 1e-2);
                    mag = 3.0 / (dist_to_barrier^2);
                    f_obs = f_obs + (diff / dc) * mag;
                end
            end
        end

        v_eff_des = (1 - inertia) * v_des + inertia * v;
        a = tgt.K_p * (v_eff_des - v) + f_obs;
        na = norm(a);
        if na > tgt.amax, a = a * (tgt.amax / na); end

        v = limit_norm_local(v + a * dt, tgt.vmax);
        p_new = p + v * dt;

        for oi = 1:N_obs
            c = obs_c(oi, :); rb = R_barrier(oi);
            d = p_new - c; dn = norm(d);
            if dn < rb && dn > 1e-6
                n_out = d / dn;
                p_new = c + n_out * rb;
                rel_v = v - obs_v(oi, :);
                v_n = dot(rel_v, n_out);
                if v_n < 0, v = v - v_n * n_out; end
            end
        end

        p = p_new; t = t + dt; k = k + 1;
        T_hist(k,:) = p; V_hist(k,:) = v;
    end

    T_hist = T_hist(1:k,:);
    V_hist = V_hist(1:k,:);
end

% =========================================================
% ---- Безопасный доступ к траектории цели ----
% =========================================================
function p = target_lookup(t, tt, T_hist_pre)
    if t <= tt(1), p = T_hist_pre(1, :); return; end
    if t >= tt(end), p = T_hist_pre(end, :); return; end
    idx = t / (tt(2) - tt(1)) + 1;
    i0  = floor(idx);
    i1  = i0 + 1;
    if i1 > size(T_hist_pre, 1)
        p = T_hist_pre(end, :);
    else
        w = idx - i0;
        p = (1 - w) * T_hist_pre(i0, :) + w * T_hist_pre(i1, :);
    end
end

% =========================================================
% ---- Безопасная генерация препятствий ----
% =========================================================
function [obstacles, center0, amp, omega, phase] = ...
        make_safe_obstacles(N_obs, R_pad, t_end)
%MAKE_SAFE_OBSTACLES Мобильные препятствия, не сталкивающиеся друг с другом.
%
% Гарантирует: для всех t in [0, t_end] и любых i ~= j
%   || c_i(t) - c_j(t) ||  >=  R_i + R_j + 2*R_pad
% т.е. даже «мягкие» зоны (R + R_pad) не пересекаются.
%
% Стратегия:
%   1) Случайная генерация в «широкой» области.
%   2) Проверка на сетке времени (грубая + мелкая).
%   3) При неудаче — уменьшаем амплитуды и скорости, ретраим.
%   4) Итеративное расталкивание центров (relaxation).
%   5) Крайний случай — сжимаем амплитуды до нуля (статические, но разнесённые).

    MAX_TRIES = 400;
    N_GRID_COARSE = 40;
    N_GRID_FINE   = 400;

    % ---- 1. Первичная случайная генерация ----
    R = 0.6 + 0.6 * rand(N_obs, 1);

    % Стараемся разнести центры: используем grid-jitter
    center0 = random_centers(N_obs, R_pad, R);

    amp     = 0.3 + 0.5 * rand(N_obs, 2);
    omega   = 0.15 + 0.25 * rand(N_obs, 2);
    phase   = 2*pi * rand(N_obs, 2);

    % Грубая проверка + мелкая
    [ok, ~] = check_obstacle_separation(center0, amp, omega, phase, ...
                                        R, R_pad, t_end, N_GRID_COARSE);

    attempt = 0;
    while ~ok && attempt < MAX_TRIES
        attempt = attempt + 1;

        % ---- 3. Декремент амплитуд и скоростей ----
        scale_amp = 0.85 - 0.5 * rand();     % 0.35..0.85
        scale_omg = 0.85 - 0.5 * rand();
        amp   = amp   * scale_amp;
        omega = omega * scale_omg;

        % ---- 4. Relaxation: расталкиваем центры ----
        center0 = relax_centers(center0, R, R_pad, 30);

        [ok, ~] = check_obstacle_separation(center0, amp, omega, phase, ...
                                            R, R_pad, t_end, N_GRID_COARSE);
    end

    % ---- Финальная мелкая проверка ----
    [ok_fine, min_gap_fine] = check_obstacle_separation( ...
        center0, amp, omega, phase, R, R_pad, t_end, N_GRID_FINE);

    if ~ok_fine
        % Крайняя мера: полностью убираем движение и расталкиваем
        fprintf(['[make_safe_obstacles] Не удалось подобрать движущиеся ' ...
                 'траектории (min gap = %.3f). Делаю статические.\n'], ...
                 min_gap_fine);
        amp   = zeros(N_obs, 2);
        omega = zeros(N_obs, 2);
        center0 = relax_centers(center0, R, R_pad, 200);

        % Если и тут не вышло — увеличиваем область
        [ok2, mg2] = check_obstacle_separation(center0, amp, omega, phase, ...
                                               R, R_pad, t_end, N_GRID_FINE);
        if ~ok2
            warning('make_safe_obstacles:fallback', ...
                'Даже статические препятствия пересекаются (min gap = %.3f).', mg2);
        end
    end

    obstacles.R   = R;
    obstacles.fun = @(t) center0 + amp .* sin(omega .* t + phase);
    obstacles.vel = @(t) amp .* omega .* cos(omega .* t + phase);
end

% ---- Случайные центры с попыткой разнести ----
function C = random_centers(N_obs, R_pad, R)
    % Область: X in [1, 13], Y in [0, 12] (как в оригинале)
    C = [1 + 12*rand(N_obs,1), 0 + 12*rand(N_obs,1)];
    % Несколько шагов «расталкивания» при генерации
    for iter = 1:50
        moved = false;
        for i = 1:N_obs
            for j = i+1:N_obs
                d = norm(C(i,:) - C(j,:));
                need = R(i) + R(j) + 2*R_pad + 0.1;
                if d < need
                    n = (C(i,:) - C(j,:)) / max(d, 1e-6);
                    push = (need - d) * 0.5;
                    C(i,:) = C(i,:) + n * push;
                    C(j,:) = C(j,:) - n * push;
                    moved = true;
                end
            end
        end
        % Ограничим область
        C(:,1) = min(max(C(:,1), 1), 13);
        C(:,2) = min(max(C(:,2), 0), 12);
        if ~moved, break; end
    end
end

% ---- Relaxation: расталкивание центров ----
function C = relax_centers(C, R, R_pad, iters)
    for iter = 1:iters
        moved = false;
        for i = 1:size(C,1)
            for j = i+1:size(C,1)
                d = norm(C(i,:) - C(j,:));
                need = R(i) + R(j) + 2*R_pad + 0.1;
                if d < need
                    n = (C(i,:) - C(j,:)) / max(d, 1e-6);
                    push = (need - d) * 0.5;
                    C(i,:) = C(i,:) + n * push;
                    C(j,:) = C(j,:) - n * push;
                    moved = true;
                end
            end
        end
        if ~moved, break; end
    end
end

% ---- Проверка зазора между препятствиями на сетке ----
function [ok, min_gap] = check_obstacle_separation(center0, amp, omega, ...
                                                   phase, R, R_pad, t_end, N_grid)
    ts = linspace(0, t_end, N_grid);
    min_gap = inf;
    for it = 1:numel(ts)
        t = ts(it);
        C = center0 + amp .* sin(omega * t + phase);
        for i = 1:size(C,1)
            for j = i+1:size(C,1)
                d = norm(C(i,:) - C(j,:));
                gap = d - (R(i) + R(j) + 2*R_pad);
                if gap < min_gap, min_gap = gap; end
            end
        end
    end
    ok = min_gap >= 0;
end

% =========================================================
% ---- Безопасная генерация преследователей ----
% =========================================================
function [P0, V0] = make_safe_pursuers(N, obstacles, t0, R_safe)
%MAKE_SAFE_PURSUERS Стартовые позиции вне препятствий и не ближе R_safe
% друг к другу и к препятствиям (по их положению в t0).

    MAX_TRIES = 500;
    P0 = zeros(N, 2);
    for i = 1:N
        for tr = 1:MAX_TRIES
            cand = [ -2 + 4*rand(), -2 + 13*rand() ];
            ok = true;

            % не внутри препятствий
            C = obstacles.fun(t0);
            for oi = 1:numel(obstacles.R)
                if norm(cand - C(oi,:)) < obstacles.R(oi) + 0.2
                    ok = false; break;
                end
            end

            % не слишком близко к уже поставленным
            if ok
                for j = 1:i-1
                    if norm(cand - P0(j,:)) < R_safe
                        ok = false; break;
                    end
                end
            end

            if ok
                P0(i,:) = cand;
                break;
            end

            if tr == MAX_TRIES
                % Крайний случай: принимаем как есть
                P0(i,:) = cand;
            end
        end
    end

    V0 = [ -0.5 + 1.0*rand(N,1), -0.5 + 1.0*rand(N,1) ];
end

% =========================================================
% ---- Вспомогательные ----
% =========================================================
function val = getfield_default(s, name, default)
    if isfield(s, name), val = s.(name); else, val = default; end
end

function hit = segment_circle_intersect(p1, p2, c, r)
    d = p2 - p1; f = p1 - c;
    A = d(1)^2 + d(2)^2;
    if A < 1e-12, hit = norm(f) < r; return; end
    B = 2 * (f(1)*d(1) + f(2)*d(2));
    C = f(1)^2 + f(2)^2 - r^2;
    disc = B^2 - 4*A*C;
    if disc < 0, hit = false; return; end
    sq = sqrt(disc);
    t1 = (-B - sq) / (2*A);
    t2 = (-B + sq) / (2*A);
    hit = (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1) || (t1 < 0 && t2 > 1);
end

function v = limit_norm_local(v, vmax)
    n = norm(v);
    if n > vmax, v = v * (vmax / n); end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end