(in-package #:net.mfiano.lisp.pyx)

(defclass collider-plan-spec ()
  ((%name :reader name
          :initarg :name)
   (%layers :accessor layers)
   (%table :reader table
           :initform (u:dict #'eq))))

(u:define-printer (collider-plan-spec stream)
  (format stream "~s" (name collider-plan-spec)))

(defun update-collider-plan-spec (name layers plan)
  (let ((spec (u:href (metadata-collider-plans =metadata=) name)))
    (setf (layers spec) layers)
    (clrhash (table spec))
    (dolist (x plan)
      (destructuring-bind (k v) x
        (unless (find k layers)
          (error "Collider plan layer ~s is not registered." k))
        (dolist (x v)
          (unless (find x layers)
            (error "Collider plan layer ~s is not registered." x))
          (when (find k (u:href (table spec) x))
            (u:deletef v x)))
        (when v
          (setf (u:href (table spec) k) v))))))

(defun make-collider-plan-spec (name layers plan)
  (let ((spec (make-instance 'collider-plan-spec :name name)))
    (setf (u:href (metadata-collider-plans =metadata=) name) spec)
    (update-collider-plan-spec name layers plan)
    spec))

(defmacro define-collider-plan (name options &body body)
  (declare (ignore options))
  (destructuring-bind (&key layers plan) (car body)
    `(if (u:href (metadata-collider-plans =metadata=) ',name)
         (update-collider-plan-spec ',name ',layers ',plan)
         (make-collider-plan-spec ',name ',layers ',plan))))

(define-collider-plan default ())
