function [P, T_hist, arrival_times, t_hist, arrived_hist, capture_info] = ...
        group_pursuit(P0, V0, target_fun, obstacles, opts)
% GROUP_PURSUIT  Одновременное преследование динамической цели группой.
%
% obstacles — структура:
%   obstacles.R    : [N_obs x 1] радиусы
%   obstacles.fun  : @(t) -> [N_obs x 2] центры в момент t
%   obstacles.vel  : @(t) -> [N_obs x 2] скорости (для компенсации)
%
% Оптимизация синхронизации:
%   * Общее время прибытия T_cons ищется итеративным консенсусом.
%   * Целевая скорость v_i = d_i / (T_cons - t).
%   * Предстартовая нормализация vmax.
%   * Микро-коррекция в последнюю секунду (vmax*1.3).
%
% ИНЕРЦИЯ ПРЕСЛЕДОВАТЕЛЕЙ:
%   * v_eff_des = (1 - inertia_p)*v_des + inertia_p*v
%   * inertia_p = 0  -> мгновенная реакция
%   * inertia_p = 1  -> скорость почти не меняется
%
% ЗАХВАТ ЦЕЛИ:
%   * opts.capture_on_first = true (по умолчанию)
%       Как только ЛЮБОЙ преследователь оказался в arrive_tol от цели —
%       движение ВСЕХ преследователей и цели прекращается, симуляция
%       останавливается. Все «замирают» в текущих позициях.
%   * opts.capture_on_first = false
%       Прежнее поведение: групповая синхронизация и остановка при
%       all(arrived).
%
% Выход capture_info:
%   .captured   : bool — был ли захват
%   .t_capture  : время захвата (NaN, если не было)
%   .who        : индекс преследователя, который поймал (0, если не было)
%   .pos_target : позиция цели в момент захвата (NaN(1,2), если не было)

    if nargin < 5, opts = struct(); end
    opts = set_defaults(opts);

    N = size(P0, 1);
    dt = opts.dt;
    t_end = opts.t_end;

    pos = P0;
    vel = V0;
    vmax = opts.vmax(:);
    amax = opts.amax(:);
    inertia_p = opts.inertia_p;

    N_obs = numel(obstacles.R);
    R_barrier = obstacles.R(:) + opts.R_obs_pad;

    capture_info = struct('captured', false, 't_capture', NaN, ...
                          'who', 0, 'pos_target', [NaN NaN]);

    % ============================================================
    % Предстартовая нормализация vmax
    % ============================================================
    if opts.use_consensus
        d0 = zeros(N, 1);
        T0_ref = target_fun(0);
        for i = 1:N
            d0(i) = norm(T0_ref - P0(i, :));
        end
        valid = d0 > 1e-6;
        if any(valid)
            T0 = mean(d0(valid) ./ vmax(valid));
            for i = 1:N
                if d0(i) > 1e-6
                    vmax(i) = min(vmax(i), d0(i) / T0 * 1.2);
                    vmax(i) = max(vmax(i), opts.vmax(i) * 0.3);
                end
            end
        end
    end

    maxSteps = ceil(t_end / dt) + 1;
    P.pos = nan(N, 2, maxSteps);
    P.vel = nan(N, 2, maxSteps);
    T_hist = nan(maxSteps, 2);
    t_hist = nan(maxSteps, 1);
    arrived_hist = false(N, maxSteps);
    arrival_times = nan(N, 1);
    arrived = false(N, 1);

    bypass_dir = zeros(N, 1);
    bypass_obs = zeros(N, 1);

    k = 1;
    t = 0;
    P.pos(:, :, k) = pos;
    P.vel(:, :, k) = vel;
    T_hist(k, :) = target_fun(t).';
    t_hist(k) = t;
    arrived_hist(:, k) = arrived;

    while t < t_end
        T_now = target_fun(t);

        % ---- текущие позиции и скорости препятствий ----
        obs_c = obstacles.fun(t);          % [N_obs x 2]
        if isfield(obstacles, 'vel')
            obs_v = obstacles.vel(t);      % [N_obs x 2]
        else
            obs_v = zeros(N_obs, 2);
        end

        % ============================================================
        % 1. Консенсус по времени прибытия
        % ============================================================
        etas = inf(N, 1);
        for i = 1:N
            if arrived(i)
                etas(i) = 0;
            else
                d = norm(T_now - pos(i, :));
                penalty = 1.0 + 0.5 * double(bypass_dir(i) ~= 0);
                etas(i) = (d * penalty) / vmax(i);
            end
        end

        active = ~arrived;
        T_cons = max(etas(active)) + 1e-3;
        if opts.use_consensus && any(active)
            feasible = active;
            for iter = 1:20
                d_sum = 0; vcap_sum = 0;
                for i = 1:N
                    if ~feasible(i), continue; end
                    d_i = norm(T_now - pos(i, :)) * ...
                          (1.0 + 0.5 * double(bypass_dir(i) ~= 0));
                    d_sum    = d_sum    + d_i;
                    vcap_sum = vcap_sum + vmax(i);
                end
                if vcap_sum <= 1e-9, break; end
                T_candidate = d_sum / vcap_sum;

                new_feasible = false(N, 1);
                any_feas = false;
                for i = 1:N
                    if ~active(i), continue; end
                    d_i = norm(T_now - pos(i, :)) * ...
                          (1.0 + 0.5 * double(bypass_dir(i) ~= 0));
                    if d_i / max(T_candidate, 1e-3) <= vmax(i) * 1.05
                        new_feasible(i) = true;
                        any_feas = true;
                    end
                end
                if ~any_feas
                    new_feasible = active;
                end

                if abs(T_candidate - T_cons) < 1e-3
                    T_cons = T_candidate;
                    break;
                end
                T_cons = T_candidate;
                feasible = new_feasible;
            end
        end
        t_star = T_cons;

        % ============================================================
        % 2. Управление
        % ============================================================
        for i = 1:N
            if arrived(i), continue; end

            to_target = T_now - pos(i, :);
            dist = norm(to_target);
            if dist < 1e-9
                dir_t = [0 0];
            else
                dir_t = to_target / dist;
            end

            % ----- 2.1 Видимость цели (ray-cast по текущим позициям) -----
            visible = true;
            for oi = 1:N_obs
                if segment_circle_intersect(pos(i,:), T_now, ...
                                            obs_c(oi,:), ...
                                            R_barrier(oi) + 1e-3)
                    visible = false;
                    break;
                end
            end

            % ----- 2.2 Желаемая скорость -----
            remaining = max(t_star - t, dt);

            if opts.use_consensus && remaining < 1.0
                vmax_eff = vmax(i) * 1.3;
            else
                vmax_eff = vmax(i);
            end

            v_mag = dist / remaining;
            v_mag = min(v_mag, vmax_eff);
            v_des = dir_t * v_mag;

            % ----- 2.3 Ближайшее препятствие (по текущим позициям) -----
            nearest_oi = 0;
            nearest_gap = inf;
            nearest_n_out = [0 0];
            for oi = 1:N_obs
                c = obs_c(oi, :);
                diff = pos(i, :) - c;
                dc = norm(diff);
                gap = dc - R_barrier(oi);
                if gap < nearest_gap
                    nearest_gap = gap;
                    nearest_oi = oi;
                    if dc > 1e-6, nearest_n_out = diff / dc; end
                end
            end

            f_obs = [0 0];

            if ~visible
                n_out = nearest_n_out;
                t_out = [-n_out(2), n_out(1)];

                if bypass_dir(i) == 0
                    side = sign( (T_now(1)-pos(i,1))*n_out(2) ...
                               - (T_now(2)-pos(i,2))*n_out(1) );
                    if side == 0, side = 1; end
                    bypass_dir(i) = side;
                    bypass_obs(i) = nearest_oi;
                end
                if bypass_obs(i) ~= nearest_oi
                    bypass_dir(i) = 0;
                end

                v_tan = bypass_dir(i) * vmax_eff * t_out;
                v_rad = -opts.k_attach * max(nearest_gap, -opts.R_obs_pad) * n_out;
                v_des = limit_norm(v_tan + v_rad, vmax_eff);

                % компенсация скорости движущегося препятствия
                v_des = v_des + 0.5 * obs_v(nearest_oi, :);

                f_obs = [0 0];
            else
                bypass_dir(i) = 0;
                bypass_obs(i) = 0;

                for oi = 1:N_obs
                    c = obs_c(oi, :);
                    diff = pos(i, :) - c;
                    dc = norm(diff);
                    d_edge = dc - obstacles.R(oi);
                    if d_edge < opts.R_obs_soft && dc > 1e-6
                        dist_to_barrier = max(d_edge - opts.R_obs_pad, 1e-2);
                        mag = opts.w_obs / (dist_to_barrier^2);
                        % отталкивание с учётом скорости препятствия
                        rel_v = vel(i,:) - obs_v(oi,:);
                        mag = mag * (1 + 0.3 * norm(rel_v));
                        f_obs = f_obs + (diff / dc) * mag;
                    end
                end
            end

            % ----- 2.4 Отталкивание от соседей -----
            f_rep = [0 0];
            for j = 1:N
                if j == i, continue; end
                diff = pos(i, :) - pos(j, :);
                dij = norm(diff);
                if dij < opts.R_safe && dij > 1e-6
                    mag = opts.w_rep * (1/dij - 1/opts.R_safe) / (dij^2);
                    f_rep = f_rep + (diff / dij) * mag;
                end
            end

            % ============================================================
            % 2.5 ИНЕРЦИЯ
            % ============================================================
            v_eff_des = (1 - inertia_p) * v_des + inertia_p * vel(i, :);

            % ----- 2.6 Ослабление K_p у барьера -----
            Kp_eff = opts.K_p;
            if nearest_gap < 0.5
                Kp_eff = opts.K_p * 0.5;
            end

            a = Kp_eff * (v_eff_des - vel(i, :)) + f_obs + f_rep;
            na = norm(a);
            if na > amax(i), a = a * (amax(i) / na); end

            % ----- 2.7 Интегрирование -----
            vel(i, :) = limit_norm(vel(i, :) + a * dt, vmax_eff);
            pos_new = pos(i, :) + vel(i, :) * dt;

            % ----- 2.8 Жёсткий барьер (по текущим позициям) -----
            for oi = 1:N_obs
                c = obs_c(oi, :);
                rb = R_barrier(oi);
                d = pos_new - c;
                dn = norm(d);
                if dn < rb && dn > 1e-6
                    n_out = d / dn;
                    pos_new = c + n_out * rb;
                    % снимаем нормальную компоненту ОТНОСИТЕЛЬНОЙ скорости
                    rel_v = vel(i,:) - obs_v(oi,:);
                    v_n = dot(rel_v, n_out);
                    if v_n < 0
                        vel(i,:) = vel(i,:) - v_n * n_out;
                    end
                end
            end

            pos(i, :) = pos_new;
        end

        % ============================================================
        % 3. Проверка захвата (первый поймавший — конец)
        % ============================================================
        dists = zeros(N, 1);
        for i = 1:N
            dists(i) = norm(T_now - pos(i, :));
        end
        near_goal = dists < opts.arrive_tol;

        if opts.capture_on_first
            % ---- Режим «кто-то поймал — всё стоп» ----
            catcher = find(near_goal & ~arrived, 1, 'first');
            if ~isempty(catcher)
                capture_info.captured   = true;
                capture_info.t_capture  = t;
                capture_info.who        = catcher;
                capture_info.pos_target = T_now;

                % Замораживаем всех
                vel(:) = 0;
                arrived(:) = true;
                for i = 1:N
                    if isnan(arrival_times(i))
                        arrival_times(i) = t;
                    end
                end

                t = t + dt;
                k = k + 1;
                P.pos(:, :, k) = pos;
                P.vel(:, :, k) = vel;
                % цель «останавливается»: повторяем её позицию
                T_hist(k, :) = T_now;
                t_hist(k) = t;
                arrived_hist(:, k) = arrived;

                if opts.verbose
                    fprintf('ЗАХВАТ: преследователь %d поймал цель в t = %.2f c.\n', ...
                            catcher, capture_info.t_capture);
                    fprintf('Движение всех преследователей и цели остановлено.\n');
                end
                break;
            end
        else
            % ---- Прежний групповой режим ----
            not_arrived = ~arrived;
            group_ready = all(near_goal(not_arrived)) || ...
                          (t >= t_star - opts.sync_window);

            for i = 1:N
                if ~arrived(i) && near_goal(i) && group_ready
                    arrived(i) = true;
                    arrival_times(i) = t;
                    bypass_dir(i) = 0;
                end
            end
        end

        t = t + dt;
        k = k + 1;
        P.pos(:, :, k) = pos;
        P.vel(:, :, k) = vel;
        T_hist(k, :) = target_fun(t).';
        t_hist(k) = t;
        arrived_hist(:, k) = arrived;

        if all(arrived)
            if opts.verbose
                fprintf('Все достигли цели к t = %.2f c\n', t);
            end
            break;
        end
    end

    P.pos = P.pos(:, :, 1:k);
    P.vel = P.vel(:, :, 1:k);
    T_hist = T_hist(1:k, :);
    t_hist = t_hist(1:k);
    arrived_hist = arrived_hist(:, 1:k);
end

% ============================================================
% Ray-cast
% ============================================================
function hit = segment_circle_intersect(p1, p2, c, r)
    d = p2 - p1;
    f = p1 - c;
    A = dot(d, d);
    if A < 1e-12
        hit = norm(f) < r;
        return;
    end
    B = 2 * dot(f, d);
    C = dot(f, f) - r^2;
    disc = B^2 - 4*A*C;
    if disc < 0
        hit = false;
        return;
    end
    sq = sqrt(disc);
    t1 = (-B - sq) / (2*A);
    t2 = (-B + sq) / (2*A);
    hit = (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1) || (t1 < 0 && t2 > 1);
end

% ============================================================
% Вспомогательные
% ============================================================
function v = limit_norm(v, vmax)
    n = norm(v);
    if n > vmax, v = v * (vmax / n); end
end

function opts = set_defaults(opts)
    if ~isfield(opts,'dt'),               opts.dt = 0.02;              end
    if ~isfield(opts,'t_end'),            opts.t_end = 120;            end
    if ~isfield(opts,'K_p'),              opts.K_p = 2.0;              end
    if ~isfield(opts,'arrive_tol'),       opts.arrive_tol = 0.6;       end
    if ~isfield(opts,'w_obs'),            opts.w_obs = 4.0;            end
    if ~isfield(opts,'R_obs_pad'),        opts.R_obs_pad = 0.4;        end
    if ~isfield(opts,'R_obs_soft'),       opts.R_obs_soft = 2.0;       end
    if ~isfield(opts,'R_safe'),           opts.R_safe = 1.2;           end
    if ~isfield(opts,'w_rep'),            opts.w_rep = 5;              end
    if ~isfield(opts,'k_attach'),         opts.k_attach = 1.5;         end
    if ~isfield(opts,'vmax'),             opts.vmax = 1.8*ones(4,1);   end
    if ~isfield(opts,'amax'),             opts.amax = 1.0*ones(4,1);   end
    if ~isfield(opts,'verbose'),          opts.verbose = true;         end
    if ~isfield(opts,'use_consensus'),    opts.use_consensus = true;   end
    if ~isfield(opts,'sync_window'),      opts.sync_window = 3.0;      end
    if ~isfield(opts,'inertia_p'),        opts.inertia_p = 0.5;        end
    if ~isfield(opts,'capture_on_first'), opts.capture_on_first = true; end
end