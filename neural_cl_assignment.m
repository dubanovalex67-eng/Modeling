function [assignment_lines, current_assignment_cl] = neural_cl_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, comp_node_points, delta_CL, assignment_lines)
    % Нейросетевой алгоритм для распределения хищников по жертвам с учётом CL
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

    max_slots = maxPredPerPrey * num_prey_sel;
    costMatrix_ext = zeros(num_pred_sel, max(num_pred_sel, max_slots));
    for i = 1:num_pred_sel
        for j = 1:num_prey_sel
            dist = norm(selected_pred(i,:) - selected_prey(j,:));
            for k = 0:maxPredPerPrey-1
                costMatrix_ext(i, j + k*num_prey_sel) = dist;
            end
        end
    end
    if num_pred_sel > max_slots
        extra = num_pred_sel - max_slots;
        costMatrix_ext(:, end+1:end+extra) = 1e6;
    end

    try
        assignment_ext = neural_assignment(costMatrix_ext);
    catch ME
        errordlg(['Ошибка выполнения нейросетевого алгоритма: ' ME.message], 'Ошибка');
        return;
    end

    assignment_pairs = [];
    for i_local = 1:num_pred_sel
        col = assignment_ext(i_local);
        if col > 0 && col <= max_slots
            prey_local = mod(col-1, num_prey_sel) + 1;
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

    res_fig = figure('Name', ['Распределение хищников по жертвам (Нейросетевой алгоритм, CL < ' num2str(delta_CL) ')'], ...
                     'NumberTitle', 'off', ...
                     'Position', [200 200 700 400]);

    uitable('Parent', res_fig, ...
            'Data', result_table, ...
            'ColumnName', {'Хищник №', 'X хищника', 'Y хищника', 'Жертва №', 'Расстояние'}, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.05 0.9 0.9]);

    disp(['Распределение завершено (Нейросеть, CL < ' num2str(delta_CL) '). Назначено пар: ' num2str(num_assigned) ', суммарное расстояние: ' num2str(totalCost)]);
end