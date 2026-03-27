;;; Sample .dir-locals.el for projects with a TAGS file.
;;; Copy this file as .dir-locals.el into the project root.
;;;
;;; By default, dumb-jump handles M-. (xref-find-definitions) globally.
;;; In projects with a TAGS file, use one of these to prefer etags instead.
;;;
;;; Emacs will prompt "allow unsafe local variable?" the first time.
;;; Answer `!' to permanently trust it for this project.
;;;
;;; To generate a TAGS file: ctags -Re . (from the project root)

;;; Option 1: etags only (simplest)
((nil . ((eval . (setq-local xref-backend-functions '(etags--xref-backend))))))

;;; Option 2: etags first, dumb-jump fallback
;; ((nil . ((eval . (setq-local xref-backend-functions
;;                              '(etags--xref-backend dumb-jump-xref-activate))))))

;;; Option 3: etags for C/C++ only, dumb-jump for everything else
;; ((c-mode   . ((eval . (setq-local xref-backend-functions '(etags--xref-backend)))))
;;  (c++-mode . ((eval . (setq-local xref-backend-functions '(etags--xref-backend))))))
