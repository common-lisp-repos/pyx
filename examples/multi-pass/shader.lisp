(in-package #:pyx.examples.shader)

(defun multi-pass/frag ((uv :vec2)
                        &uniforms
                        (sampler :sampler-2d))
  (let ((color (texture sampler (vec2 (.x uv) (- 1 (.y uv))))))
    (vec4 (vec3 (- 1 (.rgb color))) (.a color))))

(define-shader multi-pass ()
  (:vertex (pyx.shader:quad/vert mesh-attrs))
  (:fragment (multi-pass/frag :vec2)))
