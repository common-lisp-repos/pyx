(in-package #:net.mfiano.lisp.pyx.examples.shader)

(defun window-rain/hash ((n :float))
  (fract (* (sin (* n 51384.508)) 6579.492)))

(defun window-rain/hash-1-3 ((n :float))
  (let* ((n (fract (* (vec3 n) (vec3 0.1031 0.11369 0.13787))))
         (n (+ n (dot n (+ (.yzx n) 19.19)))))
    (fract
     (vec3 (* (+ (.x n) (.y n)) (.z n))
           (* (+ (.x n) (.z n)) (.y n))
           (* (+ (.y n) (.z n)) (.x n))))))

(defun window-rain/drop-layer-1 ((uv :vec2)
                                 (time :float))
  (let* ((uv (* uv 30.0))
         (id (floor uv))
         (uv (- (fract uv) 0.5))
         (n (window-rain/hash-1-3 (+ (* (.x id) 513.50877)
                                     (* (.y id) 6570.492))))
         (p (* (- (.xy n) 0.5) 0.7))
         (d (length (- uv p)))
         (fade (fract (+ time (.z n))))
         (fade (* (smoothstep 0.0 0.02 fade) (smoothstep 1.0 0.02 fade))))
    (* (smoothstep 0.3 0.0 d)
       (fract (* (.z n) 10))
       fade)))

(defun window-rain/drop-layer-2-3 ((uv :vec2)
                                   (time :float))
  (let* ((uv2 uv)
         (uv (+ uv (vec2 0 (* time 0.85))))
         (a (vec2 6 1))
         (grid (* a 2))
         (id (floor (* uv grid)))
         (uv (+ uv (vec2 0 (window-rain/hash (.x id)))))
         (id (floor (* uv grid)))
         (n (window-rain/hash-1-3 (+ (* (.x id) 101.87) (* (.y id) 41480.56))))
         (st (- (fract (* uv grid)) (vec2 0.5 0)))
         (x (- (.x n) 0.5))
         (y (* (.y uv2) 25))
         (wiggle (sin (+ y (sin y))))
         (x (* (+ x (* wiggle (- 0.5 (abs x)) (- (.z n) 0.5))) 0.5))
         (y-time (fract (+ (.z n) time)))
         (y (+ (* (- (* (smoothstep 0.0 0.85 y-time)
                        (smoothstep 1.0 0.85 y-time))
                     0.5)
                  0.9)
               0.5))
         (p (vec2 x y))
         (d (length (* (- st p) (.yx a))))
         (drop (smoothstep 0.4 0.0 d))
         (r (sqrt (smoothstep 1.0 y (.y st))))
         (cd (abs (- (.x st) x)))
         (trail-front (smoothstep -0.02 0.02 (- (.y st) y)))
         (trail (* (smoothstep (* r .23) (* r r 0.15) cd) trail-front r r))
         (y (.y uv2))
         (trail2 (smoothstep (* 0.2 r) 0.0 cd))
         (droplets (* (max 0 (- (sin (* y (- 1 y) 120)) (.y st)))
                      trail2
                      (.z n)))
         (y (+ (fract (* y 10)) (- (.y st) 0.5)))
         (droplets (smoothstep 0.3 0 (length (- st (vec2 x y))))))
    (vec2 (+ (* droplets r trail-front) drop) trail)))

(defun window-rain/drops ((uv :vec2)
                          (time :float)
                          (layer1 :float)
                          (layer2 :float)
                          (layer3 :float))
  (let* ((s (* (window-rain/drop-layer-1 uv time) layer1))
         (m1 (* (window-rain/drop-layer-2-3 uv time) layer2))
         (m2 (* (window-rain/drop-layer-2-3 (* uv 1.85) time) layer3))
         (c (+ s (.x m1) (.x m2)))
         (c (smoothstep 0.3 1.0 c)))
    (vec2 c (max (* (.y m1) layer1) (* (.y m2) layer2)))))

(defun window-rain/f ((uv2 :vec2)
                      &uniforms
                      (time :float)
                      (res :vec2)
                      (blur :float)
                      (speed :float)
                      (zoom :float)
                      (sampler :sampler-2d))
  (let* ((uv (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res)))
         (time (* time speed))
         (rain-amount (+ (* (sin (* time 0.05)) 0.3) 0.7))
         (blur (mix 3 blur rain-amount))
         (uv (* uv (mix 5.0 0.1 (clamp zoom 0 1))))
         (layer1 (* (smoothstep -0.5 1.0 rain-amount) 2.0))
         (layer2 (smoothstep 0.25 0.75 rain-amount))
         (layer3 (smoothstep 0.0 0.5 rain-amount))
         (c (window-rain/drops uv time layer1 layer2 layer3))
         (e (vec2 0.001 0))
         (cx (.x (window-rain/drops (+ uv e) time layer1 layer2 layer3)))
         (cy (.x (window-rain/drops (+ uv (.yx e)) time layer1 layer2 layer3)))
         (n (vec2 (- cx (.x c)) (- cy (.x c))))
         (focus (mix (- blur (.y c)) 2.0 (smoothstep 0.1 0.2 (.x c)))))
    (vec4 (.rgb (texture-lod sampler (+ uv2 n) focus)) 1)))

(define-shader window-rain ()
  (:vertex (full-quad/vert :vec3 :vec2))
  (:fragment (window-rain/f :vec2)))
