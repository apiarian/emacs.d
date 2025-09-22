(setq custom-file "~/.emacs.d/emacs-custom.el")
(load custom-file)

(setq dired-isearch-filenames 'dwim)

(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq delete-old-versions t)
(setq kept-old-versions 10)
(setq vc-make-backup-files t)
(setq version-control t)
