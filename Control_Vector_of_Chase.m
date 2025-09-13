function u = Control_Vector_of_Chase(P, T)
    d = T - P;
    if norm(d) == 0
        u = [0, 0];
    else
        u = d / norm(d);
    end
end