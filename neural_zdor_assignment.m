function [assignment_lines, current_assignment_zdor] = neural_zdor_assignment(ax, predator_points, prey_points, radar_centers, predator_radar_radius, maxPredPerPrey, assignment_lines)
    % Нейросетевой алгоритм для распределения хищников по жертвам в ЗДР
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

    res_fig = figure('Name', 'Распределение хищников по жертвам (Нейросетевой алгоритм, ЗДР)', ...
                     'NumberTitle', 'off', ...
                     'Position', [200 200 700 400]);

    uitable('Parent', res_fig, ...
            'Data', result_table, ...
            'ColumnName', {'Хищник №', 'X хищника', 'Y хищника', 'Жертва №', 'Расстояние'}, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.05 0.9 0.9]);

    disp(['Распределение завершено (Нейросеть). Назначено пар: ' num2str(num_assigned) ', суммарное расстояние: ' num2str(totalCost)]);
end