function agro_drone_swarm()
% AGRO_DRONE_SWARM  Симуляция роя агродронов: покрытие поля, payload, ветер, RTH.
% Запуск: agro_drone_swarm
% Версия: увеличенное поле, сниженная скорость, удлинённая миссия.

    %% ==================== ПАРАМЕТРЫ ====================
    N = 4;                       % число дронов
    worldW = 200; worldH = 160;  % габариты мира, м (было 100x80)

    % Полигон поля (~2.5 га вместо ~0.6 га)
    fieldPoly = [10 10; 190 10; 180 90; 140 150; 50 144; 16 80];

    % Грядки
    rowStep    = 10;             % м между проходами (было 8)
    sweepAngle = 0;              % град

    % Дрон (DJI Agras T40, упрощённо)
    speed      = 4;              % м/с рабочая (было 7)
    sprayWidth = 12;             % м (было 11)
    payloadMax = 40;             % л
    drainBase  = 100/(18*60);    % %/с
    payloadFactorMax = 2.5;

    % Ветер
    wind      = [3.5, 1.0];
    windLimit = 8;

    % База
    home = [0, 0];

    % RTH-резерв
    reservePct = 15;

    %% ==================== МАРШРУТ ====================
    [wp, totalDist] = serpentineInPoly(fieldPoly, rowStep, sweepAngle);

    if size(wp,1) < 2
        error('Маршрут не построен: проверьте полигон и шаг грядок.');
    end

    segs = splitPathByLength(wp, N);

    fprintf('Поле: %.2f га, маршрут: %.0f м, сегментов: %d\n', ...
        polyarea(fieldPoly(:,1), fieldPoly(:,2))/10000, totalDist, N);
    fprintf('Скорость: %.1f м/с | ширина распыла: %.0f м | payload: %.0f л\n', ...
        speed, sprayWidth, payloadMax);

    %% ==================== ЦВЕТА ====================
    cmap = lines(N);

    %% ==================== ДРОНЫ ====================
    drones = struct();
    for n = 1:N
        if isempty(segs{n})
            segs{n} = wp(end,:);
        end
        drones(n).path      = segs{n};
        drones(n).idx       = 1;
        drones(n).pos       = home;
        drones(n).battery   = 100;
        drones(n).payload   = payloadMax;
        drones(n).state     = 'toField';
        drones(n).covered   = 0;
        drones(n).sprayUsed = 0;
        drones(n).color     = cmap(n,:);
        drones(n).trail     = home;
    end

    %% ==================== ОКНО ====================
    fig = figure('Name','Agro Drone Swarm (large field)', 'Color','k', ...
        'Position',[50 50 1200 820]);
    ax = axes('Parent',fig,'Color',[0.06 0.06 0.09], ...
        'XColor','w','YColor','w','XTick',[],'YTick',[]);
    axis(ax,[-5 worldW+5 -5 worldH+5]); axis(ax,'square'); hold(ax,'on');

    patch(ax, fieldPoly(:,1), fieldPoly(:,2), [0.12 0.28 0.12], ...
        'EdgeColor',[0.4 0.9 0.4], 'LineWidth',1.5, 'FaceAlpha',0.35);
    plot(ax, wp(:,1), wp(:,2), '--', 'Color',[0.5 0.8 0.5 0.4], 'LineWidth',0.6);

    plot(ax, home(1), home(2), 's', 'MarkerSize',14, ...
        'MarkerFaceColor',[0.9 0.7 0.2], 'MarkerEdgeColor','w');
    text(ax, home(1)+4, home(2)+4, 'BASE', 'Color',[1 0.9 0.5], 'FontSize',10);

    hD = gobjects(N,1); hT = gobjects(N,1); hTrail = gobjects(N,1);
    for n = 1:N
        hTrail(n) = plot(ax, NaN, NaN, '-', 'Color',[drones(n).color 0.4], ...
            'LineWidth',1);
        hD(n) = plot(ax, home(1), home(2), 'o', 'MarkerSize',11, ...
            'MarkerFaceColor',drones(n).color, 'MarkerEdgeColor','w','LineWidth',1.2);
        hT(n) = text(ax, home(1), home(2)-6, '', 'Color','w', ...
            'FontSize',8, 'HorizontalAlignment','center');
    end

    title(ax, sprintf('N=%d | поле=%.1f га | скорость=%.1f м/с | payload=%.0f л | ветер=%.1f м/с', ...
        N, polyarea(fieldPoly(:,1), fieldPoly(:,2))/10000, speed, payloadMax, norm(wind)), ...
        'Color','w','FontSize',12);
    hud = uicontrol('Style','text','Parent',fig, ...
        'Units','normalized','Position',[0.02 0.01 0.96 0.05], ...
        'BackgroundColor','k','ForegroundColor','w', ...
        'FontName','Courier','FontSize',10,'String','');

    %% ==================== ГЛАВНЫЙ ЦИКЛ ====================
    dt = 0.1; t = 0;
    while ishandle(fig)
        anyActive = false;

        for n = 1:N
            dr = drones(n);

            if strcmp(dr.state,'done')
                continue;
            end
            anyActive = true;

            % Сильный ветер -> возврат
            if norm(wind) > windLimit && ~strcmp(dr.state,'charging') ...
                    && ~strcmp(dr.state,'returning')
                dr.state = 'returning';
            end

            switch dr.state
                case 'toField'
                    tgt = dr.path(1,:);
                    [dr.pos, arrived] = stepToward(dr.pos, tgt, speed*1.3, dt);
                    dr.battery = dr.battery - drainBase*dt*1.2;
                    if arrived
                        dr.state = 'working';
                        dr.idx = 1;
                    end

                case 'working'
                    if dr.idx > size(dr.path,1)
                        dr.state = 'returning';
                    else
                        tgt = dr.path(dr.idx,:);
                        stepDist = speed*dt;
                        [dr.pos, arrived] = stepToward(dr.pos, tgt, speed, dt);

                        pFactor = 1 + (dr.payload/payloadMax)*(payloadFactorMax-1);
                        wFactor = 1 + (norm(wind)/windLimit)^2*0.8;
                        dr.battery = dr.battery - drainBase*dt*pFactor*wFactor;

                        areaStep  = stepDist * sprayWidth;
                        sprayStep = areaStep * 15/10000;   % 15 л/га
                        dr.payload   = max(0, dr.payload - sprayStep);
                        dr.sprayUsed = dr.sprayUsed + sprayStep;
                        dr.covered   = dr.covered + areaStep;

                        if arrived
                            dr.idx = dr.idx + 1;
                        end

                        % RTH-проверка
                        distHome   = norm(dr.pos - home);
                        energyHome = drainBase * (distHome/speed) * 1.2;
                        if dr.battery - energyHome < reservePct || dr.payload < 1
                            dr.state = 'returning';
                        end
                    end

                case 'returning'
                    [dr.pos, arrived] = stepToward(dr.pos, home, speed*1.2, dt);
                    dr.battery = dr.battery - drainBase*dt*1.2;
                    if arrived
                        dr.state = 'charging';
                    end

                case 'charging'
                    dr.battery = min(100, dr.battery + 6*dt);
                    if dr.battery >= 99
                        if dr.idx <= size(dr.path,1)
                            dr.payload = payloadMax;
                            dr.state   = 'toField';
                        else
                            dr.state = 'done';
                        end
                    end
            end

            dr.trail(end+1,:) = dr.pos;
            if size(dr.trail,1) > 500, dr.trail(1,:) = []; end

            drones(n) = dr;
        end

        % --- Отрисовка ---
        for n = 1:N
            dr = drones(n);
            set(hD(n),'XData',dr.pos(1),'YData',dr.pos(2));
            set(hTrail(n),'XData',dr.trail(:,1),'YData',dr.trail(:,2));
            set(hT(n),'Position',[dr.pos(1),dr.pos(2)-6], ...
                'String',sprintf('B%.0f P%.0f',dr.battery,dr.payload));
            set(hD(n),'MarkerFaceColor', dr.color*0.4 + dr.color*0.6*(dr.battery/100));
        end

        nDone     = sum(strcmp({drones.state},'done'));
        avgB      = mean([drones.battery]);
        totalArea = sum([drones.covered])/10000;
        totalSpray= sum([drones.sprayUsed]);
        set(hud,'String',sprintf( ...
            't=%7.1f c | готово=%d/%d | покрыто=%.2f га | жидкость=%.1f л | ср.заряд=%.0f%%', ...
            t, nDone, N, totalArea, totalSpray, avgB));

        drawnow limitrate;
        t = t + dt;

        if ~anyActive
            title(ax, sprintf('Миссия завершена: %.2f га за %.1f с (%.1f мин)', ...
                totalArea, t, t/60), 'Color','g','FontSize',14);
            break;
        end
    end
end

%% ==================== ВСПОМОГАТЕЛЬНЫЕ ====================

function [wp, totalDist] = serpentineInPoly(poly, rowStep, angleDeg)
    if nargin < 3, angleDeg = 0; end
    ca = cosd(angleDeg); sa = sind(angleDeg);
    R  = [ca -sa; sa ca];
    pr = (R' * poly')';

    ymin = min(pr(:,2)); ymax = max(pr(:,2));
    ys   = ymin:rowStep:ymax;
    wp   = zeros(0,2);

    for k = 1:numel(ys)
        y  = ys(k);
        xs = [];
        for e = 1:size(pr,1)
            p1 = pr(e,:); p2 = pr(mod(e,size(pr,1))+1,:);
            if (p1(2)-y)*(p2(2)-y) < 0
                tt = (y - p1(2))/(p2(2)-p1(2));
                xs(end+1) = p1(1) + tt*(p2(1)-p1(1)); %#ok<AGROW>
            end
        end
        if numel(xs) < 2, continue; end
        xs = sort(xs);
        for j = 1:2:numel(xs)-1
            if mod(k,2)==1
                seg = [xs(j) y; xs(j+1) y];
            else
                seg = [xs(j+1) y; xs(j) y];
            end
            segWorld = (R * seg')';
            wp = [wp; segWorld]; %#ok<AGROW>
        end
    end

    if size(wp,1) >= 2
        totalDist = sum(vecnorm(diff(wp),2,2));
    else
        totalDist = 0;
    end
end

function segs = splitPathByLength(wp, N)
    if size(wp,1) < 2
        segs = repmat({wp}, N, 1);
        return;
    end
    total  = sum(vecnorm(diff(wp),2,2));
    target = total/N;
    segs   = cell(N,1);
    start  = 1;
    for n = 1:N
        acc = 0; idx = start;
        while idx < size(wp,1) && (acc < target || n==N)
            acc = acc + norm(wp(idx+1,:)-wp(idx,:));
            idx = idx + 1;
        end
        segs{n} = wp(start:idx,:);
        start   = idx;
    end
    for n = 1:N
        if isempty(segs{n})
            segs{n} = wp(end,:);
        end
    end
end

function [pos, arrived] = stepToward(pos, tgt, spd, dt)
    d    = tgt - pos;
    dist = norm(d);
    step = spd*dt;
    if dist <= step || dist < 1e-9
        pos = tgt;
        arrived = true;
    else
        pos = pos + (d/dist)*step;
        arrived = false;
    end
end