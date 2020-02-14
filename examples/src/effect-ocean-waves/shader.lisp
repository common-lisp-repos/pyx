(in-package #:pyx-examples.shader)

(defun effect/ocean-waves/wave-dx ((position :vec2)
                                   (direction :vec2)
                                   (speed :float)
                                   (frequency :float)
                                   (time-shift :float))
  (let* ((x (+ (* (dot direction position) frequency)
               (* time-shift speed)))
         (wave (exp (- (sin x) 1)))
         (dx (* wave (cos x))))
    (vec2 wave (- dx))))

(defun effect/ocean-waves/get-waves ((position :vec2)
                                     (iterations :int)
                                     (time :float))
  (let* ((iter 0.0)
         (phase 6.0)
         (speed 2.0)
         (weight 1.0)
         (w 0.0)
         (ws 0.0))
    (dotimes (i iterations)
      (let* ((p (vec2 (sin iter) (cos iter)))
             (res (effect/ocean-waves/wave-dx position p speed phase time)))
        (incf position (* (normalize p) (.y res) weight 0.048))
        (incf w (* (.x res) weight))
        (incf iter 12.0)
        (incf ws weight)
        (setf weight (mix weight 0.0 0.2))
        (multf phase 1.18)
        (multf speed 1.07)))
    (/ w ws)))

(defun effect/ocean-waves/raymarch-water ((camera :vec3)
                                          (start :vec3)
                                          (end :vec3)
                                          (depth :float)
                                          (time :float))
  (let* ((pos start)
         (h 0.0)
         (h-upper depth)
         (h-lower 0.0)
         (dir (normalize (- end start))))
    (dotimes (i 320)
      (let ((h (- (* (effect/ocean-waves/get-waves (* (.xz pos) 0.1) 12 time)
                     depth)
                  depth)))
        (when (> (+ h 0.01) (.y pos))
          (return (distance pos camera)))
        (incf pos (* dir (- (.y pos) h)))))
    -1.0))

(defun effect/ocean-waves/normal ((pos :vec2)
                                  (e :float)
                                  (depth :float)
                                  (time :float))
  (let* ((ex (vec2 e 0))
         (h (* (effect/ocean-waves/get-waves (* (.xy pos) 0.1) 48 time) depth))
         (a (vec3 (.x pos) h (.y pos))))
    (normalize
     (cross (- a (vec3 (- (.x pos) e)
                       (* (effect/ocean-waves/get-waves (- (* (.xy pos) 0.1)
                                                           (* (.xy ex) 0.1))
                                                        48
                                                        time)
                          depth)
                       (.y pos)))
            (- a (vec3 (.x pos)
                       (* (effect/ocean-waves/get-waves (+ (* (.xy pos) 0.1)
                                                           (* (.yx ex) 0.1))
                                                        48
                                                        time)
                          depth)
                       (+ (.y pos) e)))))))

(defun effect/ocean-waves/rotmat ((axis :vec3)
                                  (angle :float))
  (let* ((axis (normalize axis))
         (s (sin angle))
         (c (cos angle))
         (oc (- 1.0 c)))
    (mat3 (+ (* oc (.x axis) (.x axis)) c)
          (- (* oc (.x axis) (.y axis)) (* (.z axis) s))
          (+ (* oc (.z axis) (.x axis)) (* (.y axis) s))
          (+ (* oc (.x axis) (.y axis)) (* (.z axis) s))
          (+ (* oc (.y axis) (.y axis)) c)
          (- (* oc (.y axis) (.z axis)) (* (.x axis) s))
          (- (* oc (.z axis) (.x axis)) (* (.y axis) s))
          (+ (* oc (.y axis) (.z axis)) (* (.x axis) s))
          (+ (* oc (.z axis) (.z axis)) c))))

(defun effect/ocean-waves/get-ray ((uv :vec2)
                                   (res :vec2)
                                   (mouse :vec2))
  (let* ((uv (* (- (* uv 2.0) 1.0)
                (vec2 (/ (.x res) (.y res)) 1.0)))
         (proj (normalize
                (+ (vec3 uv 1.0)
                   (* (vec3 uv -1.0) (pow (length uv) 2.0) 0.05)))))
    (when (< (.x res) 400)
      (return proj))
    (* (effect/ocean-waves/rotmat (vec3 0 -1 0)
                                  (* 3.0 (- (* (.x mouse) 2) 1.0)))
       (effect/ocean-waves/rotmat (vec3 1 0 0)
                                  (* 1.5 (- (* (.y mouse) 2) 1.0)))
       proj)))

(defun effect/ocean-waves/intersect-plane ((origin :vec3)
                                           (direction :vec3)
                                           (point :vec3)
                                           (normal :vec3))
  (clamp (/ (dot (- point origin) normal)
            (dot direction normal))
         -1
         9991999))

(defun effect/ocean-waves/atmosphere ((ray-dir :vec3)
                                      (sun-dir :vec3))
  (setf (.y sun-dir) (max (.y sun-dir) -0.07))
  (let* ((st (/ (+ (.y ray-dir) 0.1)))
         (st2 (/ (1+ (* (.y sun-dir) 11.0))))
         (ray-sun-dt (pow (abs (dot sun-dir ray-dir)) 2.0))
         (sun-dt (pow (max 0.0 (dot sun-dir ray-dir)) 8.0))
         (mymie (* sun-dt st 0.2))
         (sun-color (mix (vec3 1)
                         (max (vec3 0)
                              (- (vec3 1) (/ (vec3 5.5 13 22.4) 22.4)))
                         st2))
         (blue-sky (* (/ (vec3 5.5 13 22.4) 22.4) sun-color))
         (blue-sky2 (max (vec3 0)
                         (- blue-sky
                            (* (vec3 5.5 13 22.4)
                               0.002
                               (+ st (* -6 (.y sun-dir) (.y sun-dir))))))))
    (setf blue-sky2 (* blue-sky2 (* st (+ 0.24 (* ray-sun-dt 0.24)))))
    (+ (* blue-sky2 (1+ (pow (- 1 (.y ray-dir)) 3)))
       (* mymie sun-color))))

(defun effect/ocean-waves/get-atm ((ray :vec3))
  (* (effect/ocean-waves/atmosphere ray (normalize (vec3 1))) 0.5))

(defun effect/ocean-waves/sun ((ray :vec3))
  (let ((sd (normalize (vec3 1))))
    (* (pow (max 0 (dot ray sd)) 528) 110)))

(defun effect/ocean-waves/frag (&uniforms
                                (res :vec2)
                                (time :float)
                                (mouse :vec2))
  (let* ((uv (/ (.xy gl-frag-coord) res))
         (water-depth 2.1)
         (w-floor (vec3 0 (- water-depth) 0))
         (w-ceil (vec3 0 0 0))
         (orig (vec3 0 2 0))
         (ray (effect/ocean-waves/get-ray uv res mouse))
         (hi-hit (effect/ocean-waves/intersect-plane
                  orig ray w-ceil (vec3 0 1 0)))
         (lo-hit (effect/ocean-waves/intersect-plane
                  orig ray w-floor (vec3 0 1 0)))
         (hi-pos (+ orig (* ray hi-hit))))
    (if (>= (.y ray) -0.01)
        (let ((c (umbra.color:tone-map/aces
                  (+ (* (effect/ocean-waves/get-atm ray) 2)
                     (effect/ocean-waves/sun ray))
                  0)))
          (vec4 c 1))
        (let* ((lo-pos (+ orig (* ray lo-hit)))
               (dist (effect/ocean-waves/raymarch-water
                      orig hi-pos lo-pos water-depth time))
               (pos (+ orig (* ray dist)))
               (n (effect/ocean-waves/normal (.xz pos) 0.001 water-depth time))
               (velocity (* (.xz n) (- 1.0 (.y n))))
               (n (mix (vec3 0 1 0) n (/ (+ (* dist dist 0.01) 1.0))))
               (r (reflect ray n))
               (fresnel (+ 0.04 (* 0.96 (pow (- 1.0 (max 0 (dot (- n) ray)))
                                             5.0))))
               (c (umbra.color:set-gamma
                   (umbra.color:tone-map/aces
                    (+ (* fresnel (effect/ocean-waves/get-atm r) 2)
                       (* fresnel (effect/ocean-waves/sun r)))
                    -1)
                   2.2)))
          (vec4 c 1)))))

(define-shader effect/ocean-waves ()
  (:vertex (pyx.shader:full-quad-no-uv/vert :vec3))
  (:fragment (effect/ocean-waves/frag)))
