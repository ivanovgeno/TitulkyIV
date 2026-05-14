# 3D Rendering Concept for IvCaptions

## Objective
To render 2D text into a 3D perspective and allow mesh bending (wrapping text along a curve).

## Mathematical Approach

### 1. Euler Angle Rotation Matrices
Every character's vertices are treated as 3D points $(x, y, z)$.
To apply 3D rotation, we multiply the point by three rotation matrices:

$$ R_x = \begin{bmatrix} 1 & 0 & 0 \\ 0 & \cos\theta_x & -\sin\theta_x \\ 0 & \sin\theta_x & \cos\theta_x \end{bmatrix} $$

$$ R_y = \begin{bmatrix} \cos\theta_y & 0 & \sin\theta_y \\ 0 & 1 & 0 \\ -\sin\theta_y & 0 & \cos\theta_y \end{bmatrix} $$

$$ R_z = \begin{bmatrix} \cos\theta_z & -\sin\theta_z & 0 \\ \sin\theta_z & \cos\theta_z & 0 \\ 0 & 0 & 1 \end{bmatrix} $$

$P_{final} = R_z \times R_y \times R_x \times P_{initial}$

### 2. Mesh Bending via Bezier Curves
We use a quadratic Bezier curve to deform the text baseline:
$B(t) = (1-t)^2 P_0 + 2(1-t)t P_1 + t^2 P_2$ for $0 \le t \le 1$

**Algorithm:**
1. Calculate text width $W$.
2. For each character at position $x$, calculate normalized position $t = x / W$.
3. Find point on curve $B(t)$.
4. Calculate derivative $B'(t)$ to find the normal vector.
5. Translate and rotate the character to align with the curve at $B(t)$.
6. Apply 3D rotation matrix (from step 1) to the new curved coordinates.

## Implementation Strategy
FFmpeg's native filters (like `perspective`) are 2.5D and cannot handle true Bezier mesh bending of vector text.
Therefore, the backend rendering pipeline must use a dedicated engine (e.g., Python + Cairo/Pango for vector text, projected using PyOpenGL, or a script executing Blender) to generate an image sequence of the text layer, which is then composited by FFmpeg.
