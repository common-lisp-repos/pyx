(in-package #:%pyx.collision-detection)

(defstruct (picking-ray (:conc-name nil)
                        (:predicate nil)
                        (:copier nil))
  (start (v3:vec))
  (end (v3:vec)))

(defgeneric pick-shape (ray shape)
  (:method (ray shape)))

(defmethod pick-shape (ray (shape shape/sphere))
  (with-slots (%entity %center %radius) shape
    (let* ((line (v3:- (end ray) (start ray)))
           (direction (v3:normalize line))
           (m (v3:- (start ray) (c/transform:transform-point %entity %center)))
           (b (v3:dot m direction))
           (c (- (v3:dot m m) (expt %radius 2))))
      (unless (and (plusp c) (plusp b))
        (let ((discriminant (- (expt b 2) c)))
          (unless (minusp discriminant)
            (let ((x (max 0 (- (- b) (sqrt discriminant)))))
              (when (<= x (v3:length line))
                x))))))))

(defun update-picking-ray ()
  (u:mvlet ((x y dx dy (in:get-mouse-position)))
    (a:when-let* ((viewport (vp:get-by-coordinates x y))
                  (ray (vp:picking-ray viewport))
                  (camera (vp:camera viewport))
                  (view (c/camera:view camera))
                  (proj (c/camera:projection camera))
                  (viewport (v4:vec (vp:x viewport)
                                    (vp:y viewport)
                                    (vp:width viewport)
                                    (vp:height viewport))))
      (math:unproject! (start ray) (v3:vec x y) view proj viewport)
      (math:unproject! (end ray) (v3:vec x y 1) view proj viewport)
      (values (start ray) (end ray)))))

;;; Public API

(defun pick-entity ()
  (let* ((viewport (vp:active (vp:get-manager)))
         (ray (vp:picking-ray viewport))
         (object-tree (vp:draw-order viewport))
         (picked nil))
    (update-picking-ray)
    (avl:walk
     object-tree
     (lambda (x)
       (when (and (ent:has-component-p x 'c/collider:collider))
         (a:when-let ((n (pick-shape ray (c/collider:shape x))))
           (push (cons n x) picked)))))
    (when picked
      (let ((entity (cdar (stable-sort picked #'< :key #'car))))
        (on-collision-picked (c/collider:target entity) nil entity)))))