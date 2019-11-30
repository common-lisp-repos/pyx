(in-package #:pyx)

(defun load-config (&rest args)
  (setf (slot-value *state* '%config)
        (u:hash-merge (u:dict #'eq
                              :debug t
                              :game-title "Pyx Engine"
                              :release nil
                              :threads 8
                              :vsync nil
                              :window-width 1280
                              :window-height 720)
                      (apply #'u:dict #'eq args))))

(defun cfg (key)
  (u:href (config *state*) key))

(defun (setf cfg) (value key)
  (setf (u:href (config *state*) key) value))
