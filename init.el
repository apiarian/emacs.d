					; install missing packages with package-install-selected-packages

(when (eq system-type 'darwin)
  (setq custom-file "~/.emacs.d/emacs-custom-mac.el"))
(when (not (eq system-type 'darwin))
  (setq custom-file "~/.emacs.d/emacs-custom-popos.el"))
(load custom-file)

(global-auto-revert-mode 1)

(when (and (eq system-type 'darwin) (executable-find "gls"))
  (setq insert-directory-program "gls"))

(when (eq system-type 'darwin)
  (setenv "PATH" (concat (getenv "PATH") ":/opt/homebrew/bin")))

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

(defun split-and-follow-vertically ()
  "Split window vertically and switch to new window."
  (interactive)
  (split-window-right)
  (balance-windows)
  (other-window 1))

(defun split-and-follow-horizontally ()
  "Split window horizontally and switch to new window."
  (interactive)
  (split-window-below)
  (balance-windows)
  (other-window 1))

(global-set-key (kbd "C-x 3") 'split-and-follow-vertically)
(global-set-key (kbd "C-x 2") 'split-and-follow-horizontally)

(setq dumb-jump-force-searcher 'rg)
(add-hook 'xref-backend-functions #'dumb-jump-xref-activate)

(defun my-tab-bar-new-tab-dired ()
  "Return dired buffer at current file location, or *scratch* buffer."
  (let ((current-file (buffer-file-name)))
    (if current-file
        (let* ((dir (file-name-directory current-file))
               (dired-buf (dired-noselect dir)))
          (with-current-buffer dired-buf
            (dired-goto-file current-file))
          dired-buf)
      (get-buffer-create "*scratch*"))))

(setq tab-bar-new-tab-choice 'my-tab-bar-new-tab-dired)
