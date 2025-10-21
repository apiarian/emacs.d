					; install missing packages with package-install-selected-packages

(when (eq system-type 'darwin)
  (setq custom-file "~/.emacs.d/emacs-custom-mac.el"))
(when (not (eq system-type 'darwin))
  (setq custom-file "~/.emacs.d/emacs-custom-popos.el"))
(load custom-file)

					; based on https://www.rahuljuliato.com/posts/emacs-tab-bar-groups
(use-package tab-bar
  :ensure nil
  :defer t
  :custom
  (setq tab-bar-close-button-show nil)
  (setq tab-bar-new-button-show nil)
  (setq tab-bar-tab-hints t)
  (setq tab-bar-select-tab-modifiers '(super))
  (setq tab-bar-auto-width nil)
  (setq tab-bar-separator " ")
  (setq tab-bar-format '(tab-bar-format-tabs-groups
			 tab-bar-separator))
  :init
  (defun tab-bar-tab-name-format-hints (name _tab i)
    (if tab-bar-tab-hints (concat (format "%d:" i) name) name))

  (defun tab-bar-tab-group-format-default (tab _i &optional current-p)
    (propertize
     (concat (funcall tab-bar-tab-group-function tab))
     'face (if current-p 'tab-bar-tab-group-current 'tab-bar-tab-group-inactive)))

  (defun my-tab-switch-to-group ()
    "Prompt for a tab group and switch to its first tab. Uses position instead of index field."
    (interactive)
    (let* ((tabs (funcall tab-bar-tabs-function)))
      (let* ((groups (delete-dups (mapcar (lambda (tab)
					    (funcall tab-bar-tab-group-function tab))
					  tabs)))
	     (group (completing-read "Switch to group: " groups nil t)))
	(let ((i 1) (found nil))
	  (dolist (tab tabs)
	    (let ((tab-group (funcall tab-bar-tab-group-function tab)))
	      (when (and (not found)
			 (string= tab-group group))
		(setq found t)
		(tab-bar-select-tab i)))
	    (setq i (1+ i)))))))

  (global-set-key (kbd "C-x t g") #'my-tab-switch-to-group)

  (tab-bar-mode 1))

(global-auto-revert-mode 1)
(if window-system
    (tool-bar-mode -1))

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
