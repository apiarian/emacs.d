					; install missing packages with package-install-selected-packages

;; Load host-specific config if exists
;; To find your hostname, run in terminal: hostname
;; Or in Emacs: M-: (system-name)
;; Then create file: init-{hostname}.el (e.g., init-COMP-KKVCV56XMN.el)
(let ((host-init (concat user-emacs-directory "init-" (system-name) ".el")))
  (when (file-exists-p host-init)
    (load host-init)))

;; Auto-switch theme based on macOS appearance
(if (and (eq system-type 'darwin)
         (display-graphic-p))
    (progn
      (defvar my-current-theme-is-dark nil
        "Track current theme to avoid unnecessary reloads.")

      (defun my-macos-dark-mode-p ()
        "Return t if macOS is in dark mode."
        (string= "Dark"
                 (string-trim
                  (shell-command-to-string
                   "defaults read -g AppleInterfaceStyle 2>/dev/null"))))

      (defun my-sync-theme-with-system ()
        "Sync Emacs theme with macOS appearance."
        (let ((is-dark (my-macos-dark-mode-p)))
          (unless (eq is-dark my-current-theme-is-dark)
            (setq my-current-theme-is-dark is-dark)
            (mapc #'disable-theme custom-enabled-themes)
            (if is-dark
                (load-theme 'wheatgrass t)
              (load-theme 'modus-operandi t)))))

      (my-sync-theme-with-system)
      (run-with-timer 3 3 'my-sync-theme-with-system))
  (load-theme 'wheatgrass t))

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

(defun org-convert-heading-link-to-tag ()
  "Convert links to current heading into tags.

When called on a heading:
1. Prompts for tag name
2. Adds tag to current heading
3. Finds all [[*Heading]] links in file
4. Replaces links with plain text
5. Adds tag to headings that contained links"
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((heading-text (org-get-heading t t t t))  ; Just heading text, no tags/todo
           (tag-name (read-string (format "Tag for '%s': " heading-text)))
           (link-pattern (format "\\[\\[\\*%s\\]\\]" (regexp-quote heading-text)))
           (count 0))

      ;; Add tag to current heading
      (org-set-tags (cons tag-name (org-get-tags)))

      ;; Find and replace all links to this heading
      (goto-char (point-min))
      (while (re-search-forward link-pattern nil t)
        (replace-match (format "_%s_" heading-text))
        (setq count (1+ count))

        ;; Tag the heading that contained this link
        (save-excursion
          (org-back-to-heading t)
          (let ((tags (org-get-tags)))
            (unless (member tag-name tags)
              (org-set-tags (cons tag-name tags))))))

      (message "Converted %d link(s) to tag ':%s:'" count tag-name))))

(defun org-add-custom-id-and-update-links ()
  "Add CUSTOM_ID to current heading and optionally update links.

Auto-generates ID from heading text (lowercase, dashes for spaces).
If ID already exists, uses existing one.
Only prompts to update links if [[*Heading]] links exist."
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((heading-text (org-get-heading t t t t))
           (existing-id (org-entry-get nil "CUSTOM_ID"))
           (custom-id (or existing-id
                         (replace-regexp-in-string
                          "[^a-z0-9-]" ""
                          (replace-regexp-in-string
                           " " "-"
                           (downcase heading-text)))))
           (link-pattern (format "\\[\\[\\*%s\\]\\]" (regexp-quote heading-text)))
           (count 0))

      ;; Add CUSTOM_ID if not present
      (unless existing-id
        (org-set-property "CUSTOM_ID" custom-id)
        (message "Added CUSTOM_ID: %s" custom-id))

      ;; Check if any [[*Heading]] links exist
      (goto-char (point-min))
      (while (re-search-forward link-pattern nil t)
        (setq count (1+ count)))

      ;; Only ask to update if links found
      (when (and (> count 0)
                 (y-or-n-p (format "Found %d link(s). Update to use #%s? " count custom-id)))
        (goto-char (point-min))
        (while (re-search-forward link-pattern nil t)
          (replace-match (format "[[#%s][%s]]" custom-id heading-text)))
        (message "Updated %d link(s) to use #%s" count custom-id)))))

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

(require 'helm)

(global-set-key (kbd "M-x") #'helm-M-x)
(global-set-key (kbd "C-x r b") #'helm-filtered-bookmarks)
(global-set-key (kbd "C-x C-f") #'helm-find-files)
(global-set-key (kbd "C-c h") 'helm-command-prefix)
(global-unset-key (kbd "C-x c"))

(define-key helm-map (kbd "C-z") 'helm-select-action)

(setq helm-move-to-line-cycle-in-source t
      helm-ff-search-library-in-sexp t
      helm-scroll-amount 8
      helm-ff-file-name-history-use-recentf t
      helm-echo-input-in-header-line t)

(setq helm-autoresize-max-height 0
      helm-autoresize-min-height 80)
(helm-autoresize-mode 1)

(helm-mode 1)

(setq project-mode-line 1)
