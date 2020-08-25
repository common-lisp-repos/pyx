(in-package #:net.mfiano.lisp.pyx)

(defun register-prefab-viewports (entity &key viewports)
  (let ((viewports-table (table (viewports (current-scene)))))
    (do-nodes (node :parent entity)
      (when (has-component-p node 'render)
        (if viewports
            (dolist (name viewports)
              (let ((viewport (u:href viewports-table name)))
                (register-render-order viewport node)))
            (dolist (viewport (get-entity-viewports node))
              (register-render-order viewport node)))))))

(defun load-prefab (name &key viewports parent)
  (u:if-let ((prefab (u:href =prefabs= name)))
    (let* ((factory (factory (u:href =prefabs= name)))
           (entity (funcall (func factory) :parent parent)))
      (register-prefab-viewports entity :viewports viewports))
    (error "Prefab ~s not defined." name)))

(defun deregister-prefab-entity (entity)
  (u:when-let* ((prefab (node/prefab entity))
                (table (prefabs (current-scene))))
    (u:deletef (u:href table prefab) entity)
    (unless (u:href table prefab)
      (remhash prefab table))))

(defun update-prefab-subtree (prefab)
  (parse-prefab prefab)
  (enqueue :recompile (list :prefab (name prefab)))
  (dolist (spec (slaves prefab))
    (u:when-let ((slave (u:href =prefabs= spec)))
      (clrhash (nodes slave))
      (update-prefab-subtree slave))))

(on-recompile :prefab data ()
  (dolist (entity (u:href (prefabs (current-scene)) data))
    (let ((parent (node/parent entity)))
      (delete-node entity)
      (load-prefab data :parent parent))))

(defmacro define-prefab (name options &body body)
  (u:with-gensyms (data)
    (u:mvlet ((body decls doc (u:parse-body body :documentation t)))
      `(let ((,data (preprocess-prefab-data ,name ,options ,body)))
         (if (u:href =prefabs= ',name)
             (reset-prefab ',name ,data)
             (make-prefab ',name ,data))
         (update-prefab-subtree (u:href =prefabs= ',name))))))
