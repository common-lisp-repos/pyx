(in-package #:net.mfiano.lisp.pyx)

(defstruct (uniform (:predicate nil)
                    (:copier nil))
  key
  type
  resolved-type
  value
  func)

(defun register-uniform-func (material uniform)
  (let* ((material-spec (spec material))
         (program (shadow:find-program (shader material-spec))))
    (unless (u:href (shadow:uniforms program) (uniform-key uniform))
      (error "Material ~s has the uniform ~s but shader ~s does not use it."
             (name material-spec)
             (uniform-key uniform)
             (shader material-spec)))
    (let* ((type (u:href (shadow:uniforms program) (uniform-key uniform) :type))
           (resolved-type (if (search "SAMPLER" (symbol-name type))
                              :sampler
                              type)))
      (setf (uniform-type uniform) type
            (uniform-resolved-type uniform) resolved-type
            (uniform-func uniform) (generate-uniform-func material uniform)))))

(defun %generate-uniform-func (material type)
  (let ((func (u:format-symbol :net.mfiano.lisp.shadow "UNIFORM-~a" type)))
    (lambda (k v)
      (funcall func (shader (spec material)) k v))))

(defun generate-uniform-func/sampler (material)
  (lambda (k v)
    (let ((unit (texture-unit-state material)))
      (incf (texture-unit-state material))
      (bind-texture v unit)
      (shadow:uniform-int (shader (spec material)) k unit))))

(defun generate-uniform-func/array (material type)
  (let ((func (u:format-symbol :net.mfiano.lisp.shadow
                               "UNIFORM-~a-ARRAY" type)))
    (lambda (k v)
      (funcall func (shader (spec material)) k v))))

(defun generate-uniform-func/sampler-array (material dimensions)
  (lambda (k v)
    (loop :with unit-state = (texture-unit-state material)
          :with unit-count = (+ unit-state dimensions)
          :for texture-name :in v
          :for unit :from unit-state :to unit-count
          :do (bind-texture v unit)
          :collect unit :into units
          :finally (incf (texture-unit-state material) dimensions)
                   (shadow:uniform-int-array (shader (spec material))
                                             k
                                             units))))

(defun generate-uniform-func (material uniform)
  (let ((type (uniform-type uniform))
        (resolved-type (uniform-resolved-type uniform)))
    (etypecase type
      (symbol
       (ecase resolved-type
         (:sampler
          (generate-uniform-func/sampler material))
         ((:bool :int :float :vec2 :vec3 :vec4 :mat2 :mat3 :mat4)
          (%generate-uniform-func material type))))
      (cons
       (destructuring-bind (type . dimensions) type
         (ecase resolved-type
           (:sampler
            (generate-uniform-func/sampler-array material dimensions))
           ((:bool :int :float :vec2 :vec3 :vec4 :mat2 :mat3 :mat4)
            (generate-uniform-func/array material type))))))))

(defun as-uniform (func)
  (lambda (entity)
    (declare (ignore entity))
    (funcall func)))

(defun resolve-uniform-value (entity uniform)
  (let ((value (uniform-value uniform)))
    (typecase value
      (boolean value)
      ((or symbol function) (funcall value entity))
      (t value))))

(defun resolve-uniform-func (entity uniform)
  (funcall (uniform-func uniform)
           (uniform-key uniform)
           (resolve-uniform-value entity uniform)))

(defun load-uniform-texture (material uniform)
  (let ((value (uniform-value uniform)))
    (when (eq (uniform-resolved-type uniform) :sampler)
      (let ((material-name (name (spec material)))
            (texture (load-texture value)))
        (setf (uniform-value uniform) texture)
        (pushnew material-name (materials texture))
        (pushnew value (textures material))))))

(defun set-uniforms (entity &rest args)
  (let* ((material (render/current-material entity))
         (uniforms (uniforms material)))
    (u:do-plist (k v args)
      (unless (u:href uniforms k)
        (setf (u:href uniforms k) (make-uniform :key k)))
      (let ((uniform (u:href uniforms k)))
        (setf (uniform-value uniform) v)
        (unless (uniform-func uniform)
          (register-uniform-func material uniform))))))
