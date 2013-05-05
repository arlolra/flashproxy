; This is a Gimp script-fu script that selects and exports the appropriate
; language layers from an input XCF containing multiple layers.

(define xcf-filename "badge.xcf")

(define (export lang)
  (let* ((image (car (gimp-file-load RUN-NONINTERACTIVE xcf-filename xcf-filename)))
         (shine-layer (car (gimp-image-get-layer-by-name image "shine")))
         (text-layer (car (gimp-image-get-layer-by-name image (string-append "text-" lang))))
         (output-filename (string-append "badge-" lang ".png")))
    ; Turn off all layers.
    (for-each (lambda (x) (gimp-item-set-visible x FALSE))
              (vector->list (cadr (gimp-image-get-layers image))))
    ; Except the shine and the wanted text.
    (gimp-item-set-visible shine-layer TRUE)
    (gimp-item-set-visible text-layer TRUE)
    (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)
    (file-png-save RUN-NONINTERACTIVE image
                   (car (gimp-image-get-active-layer image))
                   output-filename output-filename FALSE 9 FALSE FALSE FALSE FALSE FALSE)
    ))
