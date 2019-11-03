(in-package #:pyx)

;; Begin parsing the raw data of the prefab. If any part of the parsing fails,
;; clean up by removing the prefab entry from the metadata store.
(defun parse-prefab (prefab)
  (let (success-p)
    (unwind-protect
         (progn
           (populate-explicit-prefab-nodes prefab)
           (parse-prefab-node-templates prefab)
           (populate-implicit-prefab-nodes prefab)
           (resolve-prefab-component-types prefab)
           (resolve-prefab-component-args prefab)
           (populate-prefab-references prefab)
           (build-prefab-factory prefab)
           (setf success-p t))
      (unless success-p
        (remhash (name prefab) (meta :prefabs))))))

;; Populate the prefab object with all of its explicitly defined nodes by
;; recursively parsing the raw data. The resulting nodes are not fully realized
;; yet. NOTE: This does not populate the entire node tree -- only the explicit
;; nodes of the raw data for this prefab definition. When we later fully realize
;; these explicit nodes, we may find out that some use other prefab nodes as
;; templates, and so we must then populate the implicit nodes that are children
;; of those templates.
(defun populate-explicit-prefab-nodes (prefab)
  (with-slots (%name %data %nodes %root) prefab
    (labels ((populate (data &optional parent)
               (destructuring-bind (name options args children) data
                 (let* ((path `(,@parent ,name))
                        (parent (u:href %nodes (butlast path)))
                        (args (u:plist->hash args :test #'eq))
                        (node (make-instance 'prefab-node
                                             :prefab prefab
                                             :path path
                                             :parent parent
                                             :options options)))
                   (setf (u:href (component-args node) :self) args
                         (u:href %nodes path) node)
                   (map nil (lambda (x) (populate x path)) children)))))
      (map nil #'populate %data)
      (setf %root (u:href %nodes (list %name))))))

;; Parse prefab node templates. This iterates through all explicit nodes and
;; assigns the prototype or node template to its template slot if one is
;; specified in its options.
(defun parse-prefab-node-templates (prefab)
  (u:do-hash-values (node (nodes prefab))
    (with-slots (%path %options %template) node
      (let ((spec (getf %options :template)))
        (when spec
          (setf %template (find-prefab-node-template spec %path)))))))

;; Populate the prefab with the implicit nodes. Prefab nodes before this step
;; that have a node-based template only have a node representing that template.
;; This will bring in all of the children nodes of that template node into the
;; correct paths. NOTE: This will error instead of attempting a merge, if a path
;; for a template's child already exists as an explicit node. This may be
;; changed at a later date to employ an intelligent merge strategy.
(defun populate-implicit-prefab-nodes (prefab)
  (flet ((populate (parent template)
           (let ((template-path (path template)))
             (u:do-hash (path node (nodes (meta :prefabs (car template-path))))
               (let ((target-path (append
                                   (path parent)
                                   (nthcdr (length template-path) path))))
                 (when (and (not (equal path template-path))
                            (equal template-path
                                   (subseq path 0 (min
                                                   (length path)
                                                   (length template-path)))))
                   (if (u:href (nodes prefab) target-path)
                       (error "Cannot populate node template ~{~a~^/~} of ~
                               node ~{~a~^/~} because of a conflict with the ~
                               existing child ~{~a~^/~}."
                              template-path (path parent) target-path)
                       (setf (u:href (nodes prefab) target-path)
                             (make-instance 'prefab-node
                                            :prefab prefab
                                            :path target-path
                                            :parent parent
                                            :template node)))))))))
    (u:do-hash-values (node (nodes prefab))
      (let ((template (template node)))
        (when (typep template 'prefab-node)
          (populate (u:href (nodes prefab) (path node)) template))))))

;; Resolve the component types of all nodes. This iterates over all nodes and
;; combines the specified types of that node with the resolved types of its
;; template. Node types are specified with the node options :ADD-TYPES and
;; :REMOVE-TYPES, which is a list of symbols denoting the names of components.
;; The resolution process is as follows: First, get all of the final resolved
;; component types of the node's template if it has one. Then, delete the
;; component types given by :REMOVE-TYPES. Then, add the component types given
;; by :ADD-TYPES. Then, add in any required types that are missing that all
;; nodes must possess. Finally, sort the resulting list of types topologically
;; in the order the game engine uses them.
(defun resolve-prefab-component-types (prefab)
  (u:do-hash-values (node (nodes prefab))
    (with-slots (%options %template %component-types) node
      (let ((types (when %template
                     (copy-seq
                      (u:href (component-types %template) :resolved)))))
        (destructuring-bind (&key add-types remove-types &allow-other-keys)
            %options
          (dolist (type remove-types)
            (a:deletef types type))
          (dolist (type add-types)
            (pushnew type types))
          (let ((types (compute-component-order types)))
            (setf (u:href %component-types :self) add-types
                  (u:href %component-types :removed) remove-types
                  (u:href %component-types :resolved) types)))))))

;; Resolve the component arguments of all nodes. This iterates over all nodes
;; and combines the specified arguments of that node with the resolved arguments
;; of its template. Also, checks are performed to ensure that any specified
;; arguments conform to the component types of that node.
(defun resolve-prefab-component-args (prefab)
  (u:do-hash (path node (nodes prefab))
    (with-slots (%template %component-types %component-args) node
      (let ((removed (mapcan #'compute-component-args
                             (u:href %component-types :removed)))
            (valid (mapcan #'compute-component-args
                           (u:href %component-types :resolved)))
            (args (if %template
                      (u:hash-merge (u:href (component-args %template)
                                            :resolved)
                                    (u:href %component-args :self))
                      (u:href %component-args :self))))
        (u:do-hash-keys (arg args)
          (when (find arg removed)
            (remhash arg args)))
        (u:do-hash-keys (arg args)
          (unless (find arg valid)
            (error "Component argument ~s is invalid for node ~{~a~^/~}."
                   arg path)))
        (setf (u:href %component-args :resolved) args)))))

;; Track node references. This iterates over all the nodes of the prefab that
;; have a node-based template. It then writes into a table of the referenced
;; prefab node containing a mapping of the current prefab to the current node.
;; This is required so that any references in a template can be transformed to
;; the referencing prefab's node hierarchy.
(defun populate-prefab-references (prefab)
  (u:do-hash-values (node (nodes prefab))
    (with-slots (%path %template) node
      (when (typep %template 'prefab-node)
        (push %path (u:href (references %template) (name prefab)))))))

;; Pre-process the prefab definition body to control its evaluation. This wraps
;; raw s-expressions in LIST, and wraps component arguments in a LAMBDA to be
;; lazily evaluated later. It also wraps the special @ macro around the data to
;; allow for concise referencing of the final constructed entity of an arbitrary
;; prefab node, for when a component argument needs such a reference. NOTE: This
;; occurs at compile-time, so we must not do anything that requires a prefab
;; instance - only process the data that is to be later parsed when creating a
;; prefab.
(defmacro preprocess-prefab-data (name options data)
  (labels ((process (data)
             (destructuring-bind (name options args children)
                 (loop :with (name options . rest) = data
                       :for body :on rest :by #'cddr
                       :while (keywordp (first body))
                       :for (k v) = body
                       :collect k :into args
                       :collect v :into args
                       :finally (return (list name options args body)))
               `(list ',name
                      ,(when options `',options)
                      ,(when args
                         `(list
                           ,@(loop :for (k v) :on args :by #'cddr
                                   :collect k
                                   :collect `(lambda () ,v))))
                      ,(when children
                         `(list ,@(mapcar #'process children)))))))
    `(macrolet ((,(a:symbolicate "@") (&rest path/query)
                  `(make-prefab-reference ',path/query)))
       (list ,@(mapcar #'process (list (list* name options data)))))))