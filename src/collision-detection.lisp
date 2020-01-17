(in-package #:pyx)

(defclass collision-system ()
  ((%spec :reader spec
          :initarg :spec)
   (%registered :reader registered
                :initarg :registered
                :initform (u:dict #'eq))
   (%deregistered :reader deregistered
                  :initarg :deregistered
                  :initform (u:dict #'eq))
   (%active :reader active
            :initarg :stable
            :initform (u:dict #'eq))
   (%contacts :reader contacts
              :initarg :contacts
              :initform (u:dict #'eq))
   (%callback-entities :reader callback-entities
                       :initform (u:dict #'eq))
   (%buffer :reader buffer
            :initform (make-array 8 :adjustable t :fill-pointer t))))

(defun make-collision-system (plan-name)
  (a:if-let ((spec (meta :collider-plans plan-name)))
    (let ((system (make-instance 'collision-system :spec spec)))
      (with-slots (%registered %deregistered %active) system
        (dolist (layer (layers spec))
          (setf (u:href %registered layer) (u:dict #'eq)
                (u:href %deregistered layer) (u:dict #'eq)
                (u:href %active layer) (u:dict #'eq))))
      (setf (slot-value (get-scene) '%collision-system) system))
    (error "Collider plan ~s not found." plan-name)))

(defun ensure-collider-referent-unique (collider)
  (when (eq collider (collider/referent collider))
    (error "Collider referent cannot be the same collider object.")))

(defun register-collider (collider)
  (let* ((system (collision-system (get-scene)))
         (registered (registered system)))
    (setf (u:href registered (collider/layer collider) collider) collider)))

(defun deregister-collider (collider)
  (let* ((system (collision-system (get-scene)))
         (deregistered (deregistered system)))
    (setf (u:href deregistered (collider/layer collider) collider) collider)))

(defun collider-contact-p (collider1 collider2)
  (assert (not (eq collider1 collider2)))
  (let ((contacts (contacts (collision-system (get-scene)))))
    (when (u:href contacts collider1)
      (u:href contacts collider1 collider2))))

(defun collider-contact-enter (collider1 collider2)
  (assert (not (eq collider1 collider2)))
  (let ((contacts (contacts (collision-system (get-scene)))))
    (unless (u:href contacts collider1)
      (setf (u:href contacts collider1) (u:dict #'eq)))
    (setf (u:href contacts collider1 collider2) collider2)
    (unless (u:href contacts collider2)
      (setf (u:href contacts collider2) (u:dict #'eq)))
    (setf (u:href contacts collider2 collider1) collider1)
    (%on-collision-enter collider1 collider2)
    (%on-collision-enter collider2 collider1)))

(defun collider-contact-continue (collider1 collider2)
  (assert (not (eq collider1 collider2)))
  (%on-collision-continue collider1 collider2)
  (%on-collision-continue collider2 collider1))

(defun collider-contact-exit (collider1 collider2)
  (assert (not (eq collider1 collider2)))
  (let ((contacts (contacts (collision-system (get-scene)))))
    (a:when-let ((table2 (u:href contacts collider1)))
      (remhash collider2 table2)
      (when (zerop (hash-table-count table2))
        (remhash collider1 contacts)))
    (a:when-let ((table1 (u:href contacts collider2)))
      (remhash collider1 table1)
      (when (zerop (hash-table-count table1))
        (remhash collider2 contacts)))
    (%on-collision-exit collider1 collider2)
    (%on-collision-exit collider2 collider1)))

(defun remove-collider-contacts (collider)
  (let ((contacts (contacts (collision-system (get-scene)))))
    (a:when-let ((colliders (u:href contacts collider)))
      (u:do-hash-keys (k colliders)
        (when (collider-contact-p collider k)
          (collider-contact-exit collider k))))))

(defun compute-collider-contact (collider1 collider2)
  (let ((collided-p (collide-p collider1 collider2))
        (contact-p (collider-contact-p collider1 collider2)))
    (cond
      ((and collided-p contact-p)
       (collider-contact-continue collider1 collider2))
      ((and collided-p (not contact-p))
       (collider-contact-enter collider1 collider2))
      ((and (not collided-p) contact-p)
       (collider-contact-exit collider1 collider2)))))

(defun compute-collisions/active ()
  (let* ((system (collision-system (get-scene)))
         (active (active system))
         (buffer (buffer system)))
    (dolist (collider1-layer (layers (spec system)))
      (dolist (collider2-layer (u:href (plan (spec system)) collider1-layer))
        (if (eq collider1-layer collider2-layer)
            (a:when-let ((colliders (u:href active collider1-layer)))
              (setf (fill-pointer buffer) 0)
              (u:do-hash-keys (k colliders)
                (vector-push-extend k buffer))
              (when (>= (length buffer) 2)
                (a:map-combinations
                 (lambda (x)
                   (compute-collider-contact (aref x 0) (aref x 1)))
                 buffer
                 :length 2
                 :copy nil)))
            (u:do-hash-keys (k1 (u:href active collider1-layer))
              (u:do-hash-keys (k2 (u:href active collider2-layer))
                (compute-collider-contact k1 k2))))))))

(defun compute-collisions/registered ()
  (let* ((system (collision-system (get-scene)))
         (active (active system))
         (registered (registered system)))
    (dolist (c1-layer (layers (spec system)))
      (let ((layer-registered (u:href registered c1-layer)))
        (u:do-hash-keys (c1 layer-registered)
          (remhash c1 layer-registered)
          (unless (u:href active c1)
            (let ((c2-layers (u:href (plan (spec system)) c1-layer)))
              (dolist (c2-layer c2-layers)
                (u:do-hash-keys (c2 (u:href active c2-layer))
                  (compute-collider-contact c1 c2)))
              (setf (u:href active c1-layer c1) c1))))))))

(defun compute-collisions/deregistered ()
  (let* ((system (collision-system (get-scene)))
         (active (active system))
         (registered (registered system))
         (deregistered (deregistered system)))
    (dolist (layer (layers (spec system)))
      (let ((layer-deregistered (u:href deregistered layer)))
        (unless (zerop (hash-table-count layer-deregistered))
          (u:do-hash-keys (k layer-deregistered)
            (remhash k (u:href active layer))
            (remhash k (u:href registered layer))
            (remove-collider-contacts k)
            (remhash k layer-deregistered)))))))

(defun compute-collisions ()
  (compute-collisions/active)
  (compute-collisions/registered)
  (compute-collisions/deregistered))
