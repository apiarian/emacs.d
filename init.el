(setq custom-file "~/.emacs.d/emacs-custom.el")
(load custom-file)

(setenv "PATH" (concat (getenv "PATH") ":/opt/homebrew/bin"))

(setq dired-isearch-filenames 'dwim)

(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq delete-old-versions t)
(setq kept-old-versions 10)
(setq vc-make-backup-files t)
(setq version-control t)

(require 'package)
(add-to-list 'package-archives
	     '("melpa" . "https://melpa.org/packages/") t)

(setq auth-sources '("~/.authinfo"))

(use-package forge
  :after magit)

(add-hook 'org-mode-hook 'org-indent-mode)
(add-hook 'text-mode-hook 'turn-on-visual-line-mode)
(add-hook 'text-mode-hook 'turn-on-auto-fill)
(require 'org-mouse)

					; see also https://www.masteringemacs.org/article/mastering-key-bindings-emacs
(global-set-key (kbd "C-M-o") 'browse-url-at-point)

(setq dumb-jump-force-searcher 'rg)
(add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
