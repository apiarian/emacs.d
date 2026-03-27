;;; Sample .dir-locals.el for large git repos where magit is slow.
;;; Copy this file as .dir-locals.el into the root of the affected repo.
;;;
;;; Removes expensive magit status sections (tags header, upstream/pushremote
;;; comparison) that enumerate all refs — very slow with thousands of tags.

((magit-status-mode
  . ((eval . (progn
               (dolist (fn '(magit-insert-tags-header
                             magit-insert-unpushed-to-pushremote
                             magit-insert-unpulled-from-pushremote
                             magit-insert-unpulled-from-upstream
                             magit-insert-unpushed-to-upstream-or-recent))
                 (setq-local magit-status-sections-hook
                             (remove fn magit-status-sections-hook))))))))
