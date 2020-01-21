(in-package #:pyx.examples.shader)

(defun effect/kaleidoscope/hash ((p :vec2))
  (let* ((p (fract (vec3 (* p (vec2 385.18692 958.5519))
                         (* (+ (.x p) (.y p)) 534.3851))))
         (p (+ p (dot p (+ p 42.4112)))))
    (fract p)))

(defun effect/kaleidoscope/xor ((a :float) (b :float))
  (+ (* a (- 1 b)) (* b (- 1 a))))

(defun effect/kaleidoscope/frag (&uniforms
                                 (res :vec2)
                                 (frame-count :int)
                                 (frame-time :float)
                                 (zoom :float)
                                 (speed :float)
                                 (strength :float)
                                 (colorize :bool)
                                 (outline :bool)
                                 (detail :float))
  (let* ((angle (/ (float pi) 4))
         (s (sin angle))
         (c (cos angle))
         (uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res))
                (mat2 c (- s) s c)))
         (cell-size (* uv (mix 100 1 (clamp zoom 0 1))))
         (cell-index (floor cell-size))
         (cell-color (if colorize
                         (effect/kaleidoscope/hash cell-index)
                         (vec3 1)))
         (grid-uv (- (fract cell-size) 0.5))
         (circle 0.0)
         (detail (clamp detail 0 1))
         (strength (mix 1.5 0.2 (clamp strength 0 1)))
         (speed (* frame-count frame-time speed)))
    (dotimes (y 3)
      (dotimes (x 3)
        (let* ((offset (1- (vec2 x y)))
               (cell-origin (length (- grid-uv offset)))
               (distance (* (length (+ cell-index offset)) 0.3))
               (radius (mix strength 1.5 (+ (* (sin (- distance speed)) 0.5)
                                            0.5))))
          (setf circle (effect/kaleidoscope/xor
                        circle
                        (smoothstep radius (* radius detail) cell-origin))))))
    (let ((color (* cell-color (vec3 (mod circle (if outline 1 2))))))
      (vec4 color 1))))

(define-shader effect/kaleidoscope ()
  (:vertex (pyx.shader:quad-no-uv/vert mesh-attrs))
  (:fragment (effect/kaleidoscope/frag)))
