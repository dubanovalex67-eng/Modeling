function [P_n, T_n, VP, VT] = mutual_movement(P, T, V_P, V_T, ddt)
    if norm(P - T) < norm(V_P)*ddt
        VT = [0, 0];
        T_n = T + V_T * ddt;
        VP = [0, 0];
        P_n = T_n;
    else
        T_n = T + V_T * ddt;
        u = Control_Vector_of_Chase(P, T);
        VP = norm(V_P) * u;
        P_n = P + VP * ddt;
        VT = V_T;
    end
end