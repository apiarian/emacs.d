					; install missing packages with package-install-selected-packages

;; Load host-specific config if exists
;; To find your hostname, run in terminal: hostname
;; Or in Emacs: M-: (system-name)
;; Then create file: init-{hostname}.el (e.g., init-COMP-KKVCV56XMN.el)
(let ((host-init (concat user-emacs-directory "init-" (system-name) ".el")))
  (when (file-exists-p host-init)
    (load host-init)))

					; based on https://www.rahuljuliato.com/posts/emacs-tab-bar-groups
(use-package tab-bar
  :ensure nil
  :custom
  (tab-bar-close-button-show nil)
  (tab-bar-new-button-show nil)
  (tab-bar-tab-hints t)
  (tab-bar-select-tab-modifiers '(super))
  (tab-bar-auto-width nil)
  (tab-bar-separator " ")
  (tab-bar-format '(tab-bar-format-tabs-groups
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

(use-package magit
  :config
  (defun my-magit-branch-read-with-prefix (orig-fun prompt &optional initial-input &rest args)
    "Add branch prefix when reading branch names in magit.
Prefix is defined by `my-magit-branch-prefix' in host-specific config."
    (if (and (boundp 'my-magit-branch-prefix)
             my-magit-branch-prefix
             (stringp prompt)
             (or (string-match-p "Name for new branch" prompt)
                 (string-match-p "named" prompt)))
        (apply orig-fun prompt my-magit-branch-prefix args)
      (apply orig-fun prompt initial-input args)))

  (advice-add 'magit-read-string-ns :around #'my-magit-branch-read-with-prefix))

(use-package forge
  :after magit)

(add-hook 'org-mode-hook 'org-indent-mode)
(add-hook 'text-mode-hook 'turn-on-visual-line-mode)
(add-hook 'text-mode-hook 'turn-on-auto-fill)
(require 'org-mouse)

(defun org-create-missing-headings ()
  "Find all internal links in current org buffer and create missing headings.
New headings are inserted at top of file as level 1, sorted alphabetically."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not in org-mode buffer"))
  (let* ((ast (org-element-parse-buffer))
         (all-links '())
         (missing-headings '()))
    (org-element-map ast 'link
      (lambda (link)
        (let ((type (org-element-property :type link))
              (path (org-element-property :path link)))
          (when (and (string= type "fuzzy")
                     (string-prefix-p "*" path))
            (push (substring path 1) all-links)))))
    (dolist (heading-name all-links)
      (save-excursion
        (goto-char (point-min))
        (unless (re-search-forward
                 (format org-complex-heading-regexp-format
                         (regexp-quote heading-name))
                 nil t)
          (push heading-name missing-headings))))
    (if (not missing-headings)
        (message "No missing headings found.")
      (let ((sorted-missing (sort (delete-dups missing-headings) 'string<)))
        (when (y-or-n-p (format "Create %d missing heading%s: %s? "
                                (length sorted-missing)
                                (if (> (length sorted-missing) 1) "s" "")
                                (mapconcat 'identity sorted-missing ", ")))
          (save-excursion
            (goto-char (point-min))
            (while (and (not (eobp))
                        (looking-at "^#\\+"))
              (forward-line 1))
            (dolist (heading sorted-missing)
              (unless (bolp) (insert "\n"))
              (insert "* " heading "\n")))
          (message "Created %d heading%s: %s"
                   (length sorted-missing)
                   (if (> (length sorted-missing) 1) "s" "")
                   (mapconcat 'identity sorted-missing ", ")))))))

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
