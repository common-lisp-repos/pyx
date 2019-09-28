(in-package #:pyx)

(defvar *metadata* (u:dict))

(defun meta (&rest keys)
  (apply #'u:href *metadata* keys))

(defun (setf meta) (value &rest keys)
  (setf (apply #'u:href *metadata* keys) value))
