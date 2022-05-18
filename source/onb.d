/* module onb;

import geometry: Vec, Normal;
Vec[3] createOnbFromZ(Normal normal)


def create_onb_from_z(normal: Union[Vec, Normal]) -> Tuple[Vec, Vec, Vec]:
    sign = 1.0 if (normal.z > 0.0) else -1.0
    a = -1.0 / (sign + normal.z)
    b = normal.x * normal.y * a

    e1 = Vec(1.0 + sign * normal.x * normal.x * a, sign * b, -sign * normal.x)
    e2 = Vec(b, sign + normal.y * normal.y * a, -normal.y)

    return e1, e2, Vec(normal.x, normal.y, normal.z */