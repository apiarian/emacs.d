(setq custom-file "~/.emacs.d/emacs-custom.el")
(load custom-file)

(setq dired-isearch-filenames 'dwim)

(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq delete-old-versions t)
(setq kept-old-versions 10)
(setq vc-make-backup-files t)
(setq version-control t)

(add-hook 'org-mode-hook 'org-indent-mode)
(add-hook 'text-mode-hook 'turn-on-visual-line-mode)
(add-hook 'text-mode-hook 'turn-on-auto-fill)
