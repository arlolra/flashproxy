(define (exit)
  (gimp-quit 0))

(define file "badge.xcf")

(define (find_layer_by_name image layers name)
  (define (loop ls)
    (cond
      ((null? ls) (error "Could not find layer?"))
      ((string=? (car (gimp-drawable-get-name (car ls))) name) (car ls))
      (else (loop (cdr ls)))
    ))
  (loop (vector->list layers)))

(define (eb lang)
  (let* (
    (image (car (gimp-file-load RUN-NONINTERACTIVE file file)))
    (layers (cadr (gimp-image-get-layers image)))
    (layer (find_layer_by_name image layers (string-append "text-" lang)))
    (filename (string-append "badge-" lang ".png"))
  )
  (gimp-drawable-set-visible layer TRUE)
  (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)
  (file-png-save RUN-NONINTERACTIVE image
    (car (gimp-image-get-active-layer image))
    filename filename FALSE 9 FALSE FALSE FALSE FALSE FALSE)
  ))