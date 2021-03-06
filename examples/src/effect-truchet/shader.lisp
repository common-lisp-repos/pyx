(in-package #:net.mfiano.lisp.pyx.examples.shader)

(defun effect/truchet/hash ((p :vec2))
  (let* ((p (fract (* p (vec2 385.18692 958.5519))))
         (p (+ p (dot p (+ p 42.4112)))))
    (fract (* (.x p) (.y p)))))

(defun effect/truchet/frag (&uniforms
                            (res :vec2)
                            (time :float))
  (let* ((uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res)) 4))
         (cell-id (floor uv))
         (checker (1- (* (mod (+ (.x cell-id) (.y cell-id)) 2) 2)))
         (hash (effect/truchet/hash cell-id))
         (grid-uv (- (fract (if (< hash 0.5) (* uv (vec2 -1 1)) uv)) 0.5))
         (circle-uv (- grid-uv
                       (* (sign (+ (.x grid-uv) (.y grid-uv) 1e-7)) 0.5)))
         (dist (length circle-uv))
         (width 0.2)
         (angle (atan (.x circle-uv) (.y circle-uv)))
         (mask (smoothstep 0.01 -0.01 (- (abs (- dist 0.5)) width)))
         (mask-uv (vec2 (* (- (abs (fract (- (/ (* angle checker) +half-pi+)
                                             (* time 0.3))))
                              0.5)
                           2.0)
                        (* (abs (- (/ (- dist (- 0.5 width)) (* width 2))
                                   0.5))
                           2)))
         (noise (vec3 (+ (* 0.4 (umbra.noise:perlin (* 2 mask-uv)))
                         (* 0.3 (umbra.noise:perlin-surflet (* 16 mask-uv))))))
         (noise (* noise (vec3 0.6 0.9 0.7) (+ 0.5 (* 0.5 (vec3 uv 1))))))
    (vec4 (* noise mask) 1)))

(define-shader effect/truchet ()
  (:vertex (full-quad-no-uv/vert :vec3))
  (:fragment (effect/truchet/frag)))
