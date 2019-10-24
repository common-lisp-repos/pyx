(in-package #:pyx)

(defun initialize-shaders ()
  (with-slots (%shaders) (database *state*)
    (setf %shaders (shadow:load-shaders
                    (lambda (x)
                      (enqueue :recompile (list :shaders x)))))))

(defun recompile-shaders (program-names)
  (shadow:recompile-shaders program-names)
  (log:info :pyx "Recompiled shader programs: ~{~s~^, ~}" program-names))

(defun make-shader-buffer (name shader)
  (with-slots (%shader-buffer-bindings) (database *state*)
    (a:with-gensyms (alias)
      (incf %shader-buffer-bindings)
      (shadow:create-block-alias :buffer name shader alias)
      (shadow:bind-block alias %shader-buffer-bindings)
      (shadow:create-buffer name alias)
      (shadow:bind-buffer name %shader-buffer-bindings))))

(defgeneric update-shader-buffer (object buffer &key))
