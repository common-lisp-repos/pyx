(in-package #:net.mfiano.lisp.pyx.examples)

(pyx:define-prefab texture-example (:template full-quad))

(pyx:define-scene texture ()
  (:sub-trees (examples texture-example)))
