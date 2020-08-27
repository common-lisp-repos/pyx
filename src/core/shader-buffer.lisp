(in-package #:net.mfiano.lisp.pyx)

(defun select-shader-buffer-binding ()
  (let ((id-count (hash-table-count
                   (shader-manager-buffer-bindings(shaders)))))
    (when (= id-count =max-ssbo-bindings=)
      (error "Cannot create shader buffer. Maximum bindings reached: ~d."
             =max-ssbo-bindings=))
    (or (pop (shader-manager-released-buffer-bindings (shaders)))
        (1+ id-count))))

(defun release-shader-buffer-binding (key)
  (u:when-let* ((shaders (shaders))
                (bindings (shader-manager-buffer-bindings shaders))
                (id (u:href bindings key)))
    (remhash key bindings)
    (pushnew id (shader-manager-released-buffer-bindings shaders))
    (setf (shader-manager-released-buffer-bindings shaders)
          (sort (copy-seq (shader-manager-released-buffer-bindings shaders))
                #'<))))

(defun write-shader-buffer (key path value)
  (shadow:write-buffer-path key path value))

(defun read-shader-buffer (key path)
  (shadow:read-buffer-path key path))

(defun make-shader-buffer (key block-id shader)
  (let ((binding (select-shader-buffer-binding)))
    (setf (u:href (shader-manager-buffer-bindings (shaders)) key) binding)
    (shadow:create-block-alias :buffer block-id shader key)
    (shadow:bind-block key binding)
    (shadow:create-buffer key key)
    (shadow:bind-buffer key binding)
    binding))

(defgeneric update-shader-buffer (object))

(defun delete-shader-buffer (key)
  (release-shader-buffer-binding key)
  (shadow::clear-buffer key)
  (shadow:delete-buffer key)
  (shadow:unbind-block key))

(defun clear-shader-buffer (key)
  (shadow:clear-buffer key))

(defun bind-shader-buffer (key)
  (let ((binding (u:href (shader-manager-buffer-bindings (shaders)) key)))
    (shadow:bind-block key binding)
    (shadow:bind-buffer key binding)))

(defun unbind-shader-buffer (key)
  (shadow:unbind-buffer key)
  (shadow:unbind-block key))

(defmacro with-shader-buffers ((&rest keys) &body body)
  (u:with-gensyms (table)
    (let ((key-syms (mapcar (lambda (x) (list (u:make-gensym x) x)) keys)))
      `(let ((,table (shader-manager-buffer-bindings (shaders)))
             ,@key-syms)
         ,@(mapcar
            (lambda (x)
              `(shadow:bind-block ,(car x) (u:href ,table ,(car x))))
            key-syms)
         ,@body
         ,@(mapcar
            (lambda (x)
              `(unbind-shader-buffer ,(car x)))
            key-syms)))))
