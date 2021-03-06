(in-package #:net.mfiano.lisp.pyx.examples)

(pyx:define-material noise ()
  (:uniforms (:time (pyx:as-uniform 'pyx:get-running-time))))

(pyx:define-material noise/perlin-3d (noise)
  (:shader shader:noise/perlin-3d))

(pyx:define-material noise/perlin-surflet-3d (noise)
  (:shader shader:noise/perlin-surflet-3d))

(pyx:define-material noise/perlin-improved-3d (noise)
  (:shader shader:noise/perlin-improved-3d))

(pyx:define-material noise/perlin-4d (noise)
  (:shader shader:noise/perlin-4d))

(pyx:define-material noise/cellular-3d (noise)
  (:shader shader:noise/cellular-3d))

(pyx:define-material noise/cellular-fast-3d (noise)
  (:shader shader:noise/cellular-fast-3d))

(pyx:define-material noise/hermite-3d (noise)
  (:shader shader:noise/hermite-3d))

(pyx:define-material noise/simplex-perlin-3d (noise)
  (:shader shader:noise/simplex-perlin-3d))

(pyx:define-material noise/simplex-cellular-3d (noise)
  (:shader shader:noise/simplex-cellular-3d))

(pyx:define-material noise/simplex-polkadot-3d (noise)
  (:shader shader:noise/simplex-polkadot-3d))

(pyx:define-material noise/value-3d (noise)
  (:shader shader:noise/value-3d))

(pyx:define-material noise/value-4d (noise)
  (:shader shader:noise/value-4d))

(pyx:define-material noise/value-hermite-3d (noise)
  (:shader shader:noise/value-hermite-3d))

(pyx:define-material noise/value-perlin-3d (noise)
  (:shader shader:noise/value-perlin-3d))

(pyx:define-material noise/polkadot-3d (noise)
  (:shader shader:noise/polkadot-3d))

(pyx:define-material noise/polkadot-box-3d (noise)
  (:shader shader:noise/polkadot-box-3d))

(pyx:define-material noise/cubist-3d (noise)
  (:shader shader:noise/cubist-3d))

(pyx:define-prefab noise-tile (:template quad)
  :transform/scale (v3:vec 90 90))

(pyx:define-prefab noise-grid ()
  ((perlin-3d :template noise-tile)
   :transform/translate (v3:vec -540 202.5)
   :render/materials '(noise/perlin-3d))
  ((perlin-surflet-3d :template noise-tile)
   :transform/translate (v3:vec -325 202.5)
   :render/materials '(noise/perlin-surflet-3d))
  ((perlin-improved-3d :template noise-tile)
   :transform/translate (v3:vec -110 202.5)
   :render/materials '(noise/perlin-improved-3d))
  ((perlin-4d :template noise-tile)
   :transform/translate (v3:vec 110 202.5)
   :render/materials '(noise/perlin-4d))
  ((cellular-3d :template noise-tile)
   :transform/translate (v3:vec 325 202.5)
   :render/materials '(noise/cellular-3d))
  ((cellular-fast-3d :template noise-tile)
   :transform/translate (v3:vec 540 202.5)
   :render/materials '(noise/cellular-fast-3d))
  ((hermite-3d :template noise-tile)
   :transform/translate (v3:vec -540 -22.5)
   :render/materials '(noise/hermite-3d))
  ((simplex-perlin-3d :template noise-tile)
   :transform/translate (v3:vec -325 -22.5)
   :render/materials '(noise/simplex-perlin-3d))
  ((simplex-cellular-3d :template noise-tile)
   :transform/translate (v3:vec -110 -22.5)
   :render/materials '(noise/simplex-cellular-3d))
  ((simplex-polkadot-3d :template noise-tile)
   :transform/translate (v3:vec 110 -22.5)
   :render/materials '(noise/simplex-polkadot-3d))
  ((value-3d :template noise-tile)
   :transform/translate (v3:vec 325 -22.5)
   :render/materials '(noise/value-3d))
  ((value-4d :template noise-tile)
   :transform/translate (v3:vec 540 -22.5)
   :render/materials '(noise/value-4d))
  ((value-hermite-3d :template noise-tile)
   :transform/translate (v3:vec -540 -247.5)
   :render/materials '(noise/value-hermite-3d))
  ((value-perlin-3d :template noise-tile)
   :transform/translate (v3:vec -325 -247.5)
   :render/materials '(noise/value-perlin-3d))
  ((polkadot-3d :template noise-tile)
   :transform/translate (v3:vec -110 -247.5)
   :render/materials '(noise/polkadot-3d))
  ((polkadot-box-3d :template noise-tile)
   :transform/translate (v3:vec 110 -247.5)
   :render/materials '(noise/polkadot-box-3d))
  ((cubist-3d :template noise-tile)
   :transform/translate (v3:vec 325 -247.5)
   :render/materials '(noise/cubist-3d)))

(pyx:define-scene noise ()
  (:sub-trees (examples camera/orthographic noise-grid)))
