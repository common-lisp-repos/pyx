(in-package #:pyx)

(defun load-prefab (name &key viewport parent)
  (let ((factory (factory (meta :prefabs name)))
        (viewport (or viewport (default-viewport (get-scene)))))
    (funcall (func factory) :parent parent :viewport viewport)))

(defun recompile-prefab (name)
  (dolist (entity (u:href (prefabs (get-scene)) name))
    (let ((parent (node/parent entity)))
      (delete-entity entity)
      (load-prefab name :parent parent))))

(defun deregister-prefab-entity (entity)
  (a:when-let* ((prefab (node/prefab entity))
                (table (prefabs (get-scene))))
    (a:deletef (u:href table prefab) entity)
    (unless (u:href table prefab)
      (remhash prefab table))))

(defun update-prefab-subtree (prefab)
  (parse-prefab prefab)
  (enqueue :recompile (list :prefab (name prefab)))
  (dolist (spec (slaves prefab))
    (let ((slave (meta :prefabs spec)))
      (clrhash (nodes slave))
      (update-prefab-subtree slave))))

(defmacro define-prefab (name options &body body)
  (a:with-gensyms (data)
    (u:mvlet ((body decls doc (a:parse-body body :documentation t)))
      `(let ((,data (preprocess-prefab-data ,name ,options ,body)))
         (unless (meta :prefabs)
           (setf (meta :prefabs) (u:dict #'eq)))
         (if (meta :prefabs ',name)
             (reset-prefab ',name ,data)
             (make-prefab ',name ,data))
         (update-prefab-subtree (meta :prefabs ',name))))))
