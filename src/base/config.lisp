(in-package #:net.mfiano.lisp.pyx)

(defmacro define-config (name () &body body)
  (u:with-gensyms (key value)
    (let ((table `(u:plist->hash ',(car body)))
          (default `(u:href (metadata-config-developer =metadata=) 'default)))
      (if (eq name 'default)
          `(setf (u:href (metadata-config-developer =metadata=) ',name) ,table)
          `(progn
             (unless (subtypep ',name 'context)
               (error "Configuration name must be the name of a context."))
             (u:do-plist (,key ,value ',(car body))
               (u:unless-found (#:nil (u:href ,default ,key))
                 (error "Invalid configuration option: ~s." ,key)))
             (setf (u:href (metadata-config-developer =metadata=) ',name)
                   (u:hash-merge ,default ,table)))))))

(defun load-player-config ()
  (u:when-let* ((project (cfg :title))
                (path (uiop:merge-pathnames*
                       (make-pathname :directory `(:relative "Pyx Games"
                                                             ,project)
                                      :name "settings"
                                      :type "conf")
                       (uiop:xdg-config-home)))
                (package (package-name
                          (symbol-package
                           (name =context=)))))
    (ensure-directories-exist path)
    (cond
      ((uiop:file-exists-p path)
       (log:info :pyx.cfg "Loading player configuration from ~a" path)
       (let ((table (metadata-config-player =metadata=)))
         (u:do-plist (k v (u:safe-read-file-forms path :package package))
           (let ((key (u:make-keyword k)))
             (u:if-found (#:nil (u:href table key))
               (progn
                 (setf (u:href table key) v)
                 (log:info :pyx.cfg "Player configuration override: ~(~a~) = ~s"
                           k v))
               (log:warn :pyx.cfg "Invalid configuration option: ~(~a~)" k))))))
      (t
       (log:info :pyx.cfg "No user configuration file found at ~a" path)))))

(defun cfg (key)
  (let ((config (metadata-config-developer =metadata=)))
    (u:if-let ((table (u:href config (name =context=))))
      (u:href table key)
      (u:href config 'default key))))

(defun cfg/player (key)
  (let ((config (metadata-config-player =metadata=)))
    (u:href config key)))

(defun (setf cfg/player) (value key)
  (let ((config (metadata-config-player =metadata=)))
    (setf (u:href config key) value)))

(define-config default ()
  (:anti-alias t
   :delta-time 1/60
   :log-asset-pool nil
   :log-repl-level :debug
   :log-repl-categories (:pyx)
   :opengl-version "4.3"
   :title "Pyx Engine"
   :vsync t))

(setf (metadata-config-player =metadata=)
      (u:dict #'eq
              :allow-screensaver nil
              :threads nil
              :window-width 1920
              :window-height 1080))
