(in-package #:net.mfiano.lisp.pyx)

;;; spec

(defclass asset-pool-spec ()
  ((%name :reader name
          :initarg :name)
   (%path :reader path
          :initarg :path)
   (%asset-specs :reader asset-specs
                 :initform (u:dict #'eq))))

(defclass asset-spec ()
  ((%pool :reader pool
          :initarg :pool)
   (%name :reader name
          :initarg :name)
   (%path :reader path
          :initarg :path)))

(u:define-printer (asset-pool-spec stream)
  (format stream "~s" (name asset-pool-spec)))

(u:define-printer (asset-spec stream :type nil)
  (format stream "~s (pool: ~s)" (name asset-spec) (pool asset-spec)))

(defun find-asset-pool (name)
  (u:href (metadata-asset-pools =metadata=) name))

(defun make-asset-spec (pool-name base-path data)
  (destructuring-bind (name path) data
    (let* ((pool (find-asset-pool pool-name))
           (base-path (uiop:ensure-directory-pathname base-path))
           (path (uiop:merge-pathnames* path base-path))
           (asset (make-instance 'asset-spec
                                 :pool pool-name
                                 :name name
                                 :path path)))
      (setf (u:href (asset-specs pool) name) asset)
      asset)))

(defun find-asset-spec (pool-name spec-name)
  (u:if-let ((pool (find-asset-pool pool-name)))
    (or (u:href (asset-specs pool) spec-name)
        (error "Asset ~s not found in pool ~s." spec-name pool-name))
    (error "Asset pool ~s does not exist." pool-name)))

(defun get-asset-pool-system (pool-name)
  (let ((package-name (package-name (symbol-package pool-name))))
    (or (asdf:find-system (u:make-keyword package-name) nil)
        (error "Asset pool ~s must be defined in a package with the same name ~
                as its ASDF system."
               pool-name))))

(defun make-asset-symbol (path)
  (intern
   (string-upcase
    (cl-slug:slugify
     (pathname-name path)))))

(defun asset-path-collect-p (path filter)
  (flet ((normalize-type (type)
           (string-downcase (string-left-trim "." type))))
    (let ((path-type (string-downcase (pathname-type path))))
      (some
       (lambda (x)
         (string= path-type (normalize-type x)))
       (u:ensure-list filter)))))

(defun update-asset-pool (pool-name path filter)
  (let ((pool (find-asset-pool pool-name)))
    (let* ((path (uiop:ensure-directory-pathname path))
           (system (get-asset-pool-system pool-name))
           (resolved-path (%resolve-path system path)))
      (clrhash (asset-specs pool))
      (u:map-files
       resolved-path
       (lambda (x)
         (let* ((asset-name (make-asset-symbol x))
                (file-name (file-namestring x))
                (spec (list asset-name file-name)))
           (u:if-found (existing (u:href (asset-specs pool) asset-name))
                       (error "Asset pool ~s has ambiguously named assets:~%~
                               File 1: ~a~%File 2: ~a~%Normalized name: ~a"
                              pool-name
                              file-name
                              (file-namestring (path existing))
                              asset-name)
                       (make-asset-spec pool-name path spec))))
       :test (lambda (x) (if filter (asset-path-collect-p x filter) t))
       :recursive-p nil))))

(defun make-asset-pool (name path filter)
  (let* ((path (uiop:ensure-directory-pathname path))
         (pool (make-instance 'asset-pool-spec :name name :path path)))
    (setf (u:href (metadata-asset-pools =metadata=) name) pool)
    (update-asset-pool name path filter)
    pool))

(defmacro define-asset-pool (name options &body body)
  (declare (ignore options))
  (destructuring-bind (&key path filter) body
    `(if (u:href (metadata-asset-pools =metadata=) ',name)
         (update-asset-pool ',name ,path ',filter)
         (make-asset-pool ',name ,path ',filter))))

;;; implementation

(defun find-asset (type key)
  (u:href (assets =context=) type key))

(defun delete-asset (type key)
  (remhash key (u:href (assets =context=) type)))

(defun %resolve-path (system path)
  (if =release=
      #+sbcl
      (uiop:merge-pathnames*
       path
       (uiop:pathname-directory-pathname (first sb-ext:*posix-argv*)))
      #-sbcl
      (error "Release must be deployed on SBCL to load assets.")
      (asdf:system-relative-pathname system path)))

(defun resolve-system-path (path &optional (system :net.mfiano.lisp.pyx))
  (let* ((system (asdf:find-system system))
         (path (uiop:merge-pathnames*
                path
                (uiop:ensure-directory-pathname "data")))
         (resolved-path (%resolve-path system path)))
    resolved-path))

(defgeneric resolve-path (pool/asset))

(defmethod resolve-path ((pool-name symbol))
  (let* ((pool (find-asset-pool pool-name))
         (system (get-asset-pool-system pool-name))
         (path (%resolve-path system (path pool))))
    (ensure-directories-exist path)
    path))

(defmethod resolve-path ((pool asset-pool-spec))
  (resolve-path (name pool)))

(defmethod resolve-path ((asset list))
  (destructuring-bind (pool-name spec-name) asset
    (let* ((spec (find-asset-spec pool-name spec-name))
           (system (get-asset-pool-system pool-name))
           (path (%resolve-path system (path spec))))
      (if (uiop:file-exists-p path)
          (values path spec)
          (error "File path not found for asset ~s of pool ~s.~%Path: ~s."
                 spec-name pool-name path)))))

(defmethod resolve-path ((asset string))
  (resolve-system-path asset :net.mfiano.lisp.pyx))

(defmacro with-asset-cache (type key &body body)
  (u:with-gensyms (table value found-p)
    `(symbol-macrolet ((,table (u:href (assets =context=) ,type)))
       (u:mvlet ((,value ,found-p ,table))
         (unless ,found-p
           (setf ,table (u:dict #'equalp))))
       (u:ensure-gethash ,key ,table (progn ,@body)))))
