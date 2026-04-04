;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;; Adding a package:
;;   1. Add a (use-package foo :ensure t) declaration in the appropriate section
;;   2. Eval it with C-M-x to install immediately, or restart Emacs
;;
;; Reinstalling all packages (e.g. on a fresh machine):
;;   M-x package-refresh-contents, then restart Emacs
;;
;; Updating packages:
;;   Emacs (MELPA):  M-x package-upgrade-all

;; Load host-specific config if exists
;; To find your hostname, run in terminal: hostname
;; Or in Emacs: M-: (system-name)
;; Then create file: init-{hostname}.el (e.g., init-COMP-KKVCV56XMN.el)
;; Host configs set my-host-packages to control optional package loading (go, typescript, slime)
(let ((host-init (concat user-emacs-directory "init-" (system-name) ".el")))
  (when (file-exists-p host-init)
    (load host-init)))

(defvar my-host-packages nil
  "List of optional package features enabled on this host.
Set in host-specific init-{hostname}.el files.
Supported values: go, typescript, slime.")

;;;; Package Infrastructure

(set-language-environment "UTF-8")
(setenv "LC_CTYPE" "en_US.UTF-8")

(require 'package)
(add-to-list 'package-archives
	     '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives
             '("nongnu" . "https://elpa.nongnu.org/nongnu/") t)

(setq auth-sources '("~/.authinfo"))

;;;; General Settings

(if window-system
    (tool-bar-mode -1))
(global-auto-revert-mode 1)
(setq register-preview-delay 0)
(setq project-mode-line 1)

;; New tab default: project root or scratch
(defun my-new-tab-default ()
  (if-let ((proj (project-current)))
      (dired (project-root proj))
    (switch-to-buffer (get-buffer-create "*scratch*"))))

;; Window zoom (tab-based, like tmux Z)
(defvar my-zoom-active nil "Non-nil when current tab is a zoom tab.")

(defun my-toggle-zoom ()
  "Toggle zoom: open current buffer in a new tab, or close zoom tab."
  (interactive)
  (if my-zoom-active
      (progn (setq my-zoom-active nil)
             (tab-close))
    (let ((buf (current-buffer)))
      (tab-new)
      (switch-to-buffer buf)
      (delete-other-windows)
      (setq my-zoom-active t))))

(unless (assq 'my-zoom-active (default-value 'mode-line-format))
  (setq-default mode-line-format
                (cons '(my-zoom-active (:propertize " Z " face (:inverse-video t)))
                      (default-value 'mode-line-format))))

(global-set-key (kbd "C-x t z") #'my-toggle-zoom)

;; Mode-line close button
(progn
  (defun my-mode-line-close-window (event)
    "Close the window whose mode-line was clicked."
    (interactive "e")
    (delete-window (posn-window (event-start event))))

  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'my-mode-line-close-window)
    (setq my-mode-line-close-button
          `(" "
            (:propertize "×"
                         face (:weight bold)
                         mouse-face mode-line-highlight
                         help-echo "mouse-1: Close this window"
                         local-map ,map))))
  (put 'my-mode-line-close-button 'risky-local-variable t)

  (unless (memq 'my-mode-line-close-button (default-value 'mode-line-format))
    (setq-default mode-line-format
                  (append (default-value 'mode-line-format)
                          '(my-mode-line-close-button)))))

;; New frames open *scratch* instead of cloning current buffer
(defun my-frame-scratch (frame)
  (with-selected-frame frame
    (switch-to-buffer "*scratch*")))
(add-hook 'after-make-frame-functions #'my-frame-scratch)

;; Window dividers
(setq window-divider-default-right-width 3)
(setq window-divider-default-bottom-width 3)
(window-divider-mode 1)

;; macOS compatibility
(when (and (eq system-type 'darwin) (executable-find "gls"))
  (setq insert-directory-program "gls"))
(when (and (eq system-type 'darwin)
           (not (string-match-p "/opt/homebrew/bin" (getenv "PATH"))))
  (setenv "PATH" (concat (getenv "PATH") ":/opt/homebrew/bin")))

;; Files and backups
(setq dired-isearch-filenames 'dwim)
(setq isearch-wrap-pause 'no)
(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq delete-old-versions t)
(setq kept-old-versions 10)
(setq vc-make-backup-files t)
(setq version-control t)

;; Keep auto-save files out of project directories
(make-directory "~/.emacs.d/auto-saves/" t)
(setq auto-save-file-name-transforms
      '((".*" "~/.emacs.d/auto-saves/" t)))

;; Don't create lock files (.#foo)
(setq create-lockfiles nil)

;; Prevent accidental quits
(global-unset-key (kbd "C-x C-c"))
(setq confirm-kill-emacs 'y-or-n-p)

;; Disable mail composition
(global-unset-key (kbd "C-x m"))
(global-unset-key (kbd "C-x 4 m"))

;; see also https://www.masteringemacs.org/article/mastering-key-bindings-emacs
(global-set-key (kbd "C-M-o") 'browse-url-at-point)

;;;; Theme

;; modus-themes is built into Emacs 28+
(use-package modus-themes :ensure nil :defer t)

(defvar my-current-theme-is-dark :unknown
  "Track current theme to avoid unnecessary reloads.")

(defvar my-theme-sync-timer nil
  "Timer for macOS theme auto-sync.")

(defvar my-theme-manual-override nil
  "When non-nil, auto-sync is disabled.")

(defun my-select-dark-theme ()
  "Load the dark theme."
  (load-theme 'modus-vivendi-tinted t))

(defun my-select-light-theme ()
  "Load the light theme."
  (load-theme 'modus-operandi-tinted t))

(defun my-toggle-theme ()
  "Toggle between light and dark themes, disabling auto-sync."
  (interactive)
  (setq my-theme-manual-override t)
  (setq my-current-theme-is-dark (not my-current-theme-is-dark))
  (mapc #'disable-theme custom-enabled-themes)
  (if my-current-theme-is-dark
      (my-select-dark-theme)
    (my-select-light-theme)))

;; macOS: auto-switch theme based on system appearance
(when (and (eq system-type 'darwin)
           (display-graphic-p))
  (defun my-macos-dark-mode-p ()
    "Return t if macOS is in dark mode."
    (string= "Dark"
             (string-trim
              (shell-command-to-string
               "defaults read -g AppleInterfaceStyle 2>/dev/null"))))

  (defun my-sync-theme-with-system ()
    "Sync Emacs theme with macOS appearance."
    (unless my-theme-manual-override
      (let ((is-dark (my-macos-dark-mode-p)))
        (unless (eq is-dark my-current-theme-is-dark)
          (setq my-current-theme-is-dark is-dark)
          (mapc #'disable-theme custom-enabled-themes)
          (if is-dark
              (my-select-dark-theme)
            (my-select-light-theme))))))

  (defun my-theme-follow-system ()
    "Re-enable auto-sync and immediately sync with system preference."
    (interactive)
    (setq my-theme-manual-override nil)
    (setq my-current-theme-is-dark :unknown)
    (my-sync-theme-with-system))

  (my-sync-theme-with-system)
  (when my-theme-sync-timer (cancel-timer my-theme-sync-timer))
  (setq my-theme-sync-timer (run-with-timer 3 3 'my-sync-theme-with-system)))

;;;; Undo Tree

(use-package undo-tree
  :ensure t
  :demand t
  :custom
  (undo-tree-auto-save-history nil)
  :config
  (global-undo-tree-mode))

;;;; Evil Mode

(use-package evil
  :ensure t
  :demand t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)  ; let evil-collection handle non-editing buffers
  (setq evil-undo-system 'undo-tree)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-Y-yank-to-eol t)
  (setq evil-want-C-i-jump nil)   ; preserve TAB in org-mode
  :config
  (evil-mode 1)
  ;; Escape quits minibuffer (replaces god-mode escape behavior)
  (define-key minibuffer-local-map (kbd "<escape>") #'abort-recursive-edit)
  (define-key minibuffer-local-ns-map (kbd "<escape>") #'abort-recursive-edit)
  (define-key minibuffer-local-completion-map (kbd "<escape>") #'abort-recursive-edit)
  (define-key minibuffer-local-must-match-map (kbd "<escape>") #'abort-recursive-edit)
  ;; C-z for undo (matches other apps), emacs-state on C-\
  (define-key evil-normal-state-map (kbd "C-z") #'undo-tree-undo)
  (define-key evil-insert-state-map (kbd "C-z") #'undo-tree-undo)
  (define-key evil-normal-state-map (kbd "C-\\") #'evil-emacs-state)
  ;; Avy as evil motion — enables d C-; (delete to avy target), etc.
  (define-key evil-normal-state-map (kbd "C-;") #'avy-goto-char-timer)
  (define-key evil-motion-state-map (kbd "C-;") #'avy-goto-char-timer))

(use-package evil-collection
  :ensure t
  :after evil
  :demand t
  :config
  (evil-collection-init))

(use-package evil-surround
  :ensure t
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-org
  :ensure t
  :after (evil org)
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (evil-define-key 'normal org-mode-map
    (kbd "go") 'org-mark-ring-goto))

;;;; Custom Editing Commands

(defun my-backward-kill-word ()
  "Delete backward intelligently depending on context.
If only whitespace before point on the current line, join with the
previous line by deleting all whitespace back to the previous
non-whitespace character.  Otherwise, `backward-kill-word'."
  (interactive)
  (if (save-excursion
        (skip-chars-backward " \t" (line-beginning-position))
        (bolp))
      (delete-region (point)
                     (progn (skip-chars-backward " \t\n") (point)))
    (backward-kill-word 1)))
(global-set-key (kbd "M-DEL") #'my-backward-kill-word)

(global-set-key (kbd "M-o") #'other-window)
(global-set-key (kbd "M-i") (lambda () (interactive) (other-window -1)))
(global-set-key (kbd "M-O") #'tab-next)
(global-set-key (kbd "M-I") #'tab-previous)

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

(defun kill-buffer-and-close-window (&optional arg)
  "Kill the current buffer and close the window.
With prefix ARG, prompt for a buffer to kill instead."
  (interactive "P")
  (if arg
      (call-interactively #'kill-buffer)
    (kill-this-buffer)
    (if (> (count-windows) 1)
        (delete-window)
      (switch-to-buffer (get-buffer-create "*scratch*")))))

(global-set-key (kbd "C-x k") #'kill-buffer-and-close-window)

(use-package which-key
  :ensure t
  :config (which-key-mode))

;;;; Navigation

(use-package avy
  :ensure t
  :bind ("C-;" . avy-goto-char-timer))

;; Find file at point — opens in other window to preserve current buffer
(ffap-bindings)
(setq ffap-file-finder 'find-file-other-window)
(global-set-key [s-mouse-1] (lambda (event)
                               (interactive "e")
                               (mouse-set-point event)
                               (if-let ((filename (ffap-file-at-point)))
                                   (find-file-other-window filename)
                                 (message "No file at point"))))

;;;; Tab Bar

(use-package tab-bar
  :ensure nil
  :custom
  (tab-bar-show 1)
  (tab-bar-close-button-show t)
  (tab-bar-new-button-show nil)
  (tab-bar-new-tab-choice #'my-new-tab-default)
  :config
  (tab-bar-mode 1))

;;;; Helm

(use-package helm
  :ensure t
  :demand t
  :bind (("M-x" . helm-M-x)
         ("C-x r b" . helm-filtered-bookmarks)
         ("C-x C-f" . helm-find-files)
         :map helm-map
         ("C-z" . helm-select-action))
  :custom
  (helm-move-to-line-cycle-in-source t)
  (helm-ff-search-library-in-sexp t)
  (helm-scroll-amount 8)
  (helm-ff-file-name-history-use-recentf t)
  (helm-echo-input-in-header-line t)
  (helm-autoresize-max-height 0)
  (helm-autoresize-min-height 80)
  :config
  (global-set-key (kbd "C-c h") 'helm-command-prefix)
  (global-unset-key (kbd "C-x c"))
  (helm-autoresize-mode 1)
  (helm-mode 1))

(use-package helm-org
  :ensure t
  :after helm)

;;;; Org Mode

(use-package org
  :ensure nil
  :hook ((org-mode . org-indent-mode)
         (text-mode . turn-on-visual-line-mode)
         (text-mode . turn-on-auto-fill))
  :custom
  (org-auto-align-tags nil)
  (org-tags-column 0)
  (org-agenda-files (list "~/notes/"))
  (org-refile-targets `((,(directory-files-recursively "~/notes" ".*\\.org$") :maxlevel . 1)))
  (org-refile-use-outline-path 'file)
  (org-startup-folded 'fold)
  (org-startup-with-inline-images t)
  (org-image-actual-width '(200))
  :bind (("C-c l" . org-store-link)
         ("C-c L" . my-helm-insert-org-custom-id-link)
         ("C-c C-h" . helm-org-agenda-files-headings)
         ("C-c s" . org-search-current-heading))
  :config
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
             (auto-generated-id (replace-regexp-in-string
                                 "[^a-z0-9-]" ""
                                 (replace-regexp-in-string
                                  " " "-"
                                  (downcase heading-text))))
             (custom-id (if existing-id
                           existing-id
                         (read-string "CUSTOM_ID: " auto-generated-id)))
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

  (defun my-helm-insert-org-custom-id-link ()
    "Insert link to heading with CUSTOM_ID using helm.
Searches all .org files in ~/notes/ directory."
    (interactive)
    (let ((headings '())
          (notes-dir (expand-file-name "~/notes/"))
          (current-file (buffer-file-name)))
      ;; Find all .org files in notes directory
      (dolist (file (directory-files notes-dir t "\\.org$"))
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward org-outline-regexp-bol nil t)
              (let ((heading (org-get-heading t t t t))
                    (id (org-entry-get nil "CUSTOM_ID"))
                    (filename (file-name-nondirectory file)))
                (when id
                  (push (cons (format "[%s] %s  →  #%s" filename heading id)
                             (list id heading file))
                        headings)))))))
      (if (not headings)
          (message "No headings with CUSTOM_ID found in %s" notes-dir)
        (helm :sources (helm-build-sync-source "Headings with CUSTOM_ID"
                         :candidates (nreverse headings)
                         :action '(("Insert link" .
                                   (lambda (choice)
                                     (let ((id (nth 0 choice))
                                           (heading (nth 1 choice))
                                           (file (nth 2 choice)))
                                       (if (string= file current-file)
                                           ;; Same file: use #id
                                           (insert (format "[[#%s][%s]]" id heading))
                                         ;; Different file: use file:path::#id
                                         (insert (format "[[file:%s::#%s][%s]]"
                                                       (file-name-nondirectory file)
                                                       id heading))))))))
              :buffer "*helm org custom id*"))))

  (defun org-search-current-heading ()
    "Search for the current heading."
    (interactive)
    (org-back-to-heading t)
    (let ((heading-text (org-get-heading t t t t)))
      (goto-char (point-min))
      (isearch-resume heading-text nil nil t nil t))))

;;;; Obsidian Import

(use-package obsidian-import
  :ensure nil
  :init
  (defun import-obsidian-markdown--convert-with-pandoc (md-file)
    "Convert markdown file MD-FILE to org-mode format using pandoc.
Returns org-mode content as string."
    (let ((pandoc-cmd (format "pandoc -f markdown+wikilinks_title_after_pipe -t org %s"
                             (shell-quote-argument md-file t))))
      (shell-command-to-string pandoc-cmd)))

  (defun import-obsidian-markdown--fix-wikilinks (org-content)
    "Fix wikilinks in ORG-CONTENT.
Convert [[file:PAGE]] to _PAGE_
Convert [[file:PAGE][ALIAS]] to _ALIAS_ (PAGE) if different, or _ALIAS_ if same"
    (with-temp-buffer
      (insert org-content)
      (goto-char (point-min))
      ;; First handle links with aliases: [[file:PAGE][ALIAS]]
      (while (re-search-forward "\\[\\[file:\\([^]]+\\)\\]\\[\\([^]]+\\)\\]\\]" nil t)
        (let ((page (match-string 1))
              (alias (match-string 2)))
          (if (string= page alias)
              ;; If alias same as page, just show alias underlined
              (replace-match (format "_%s_" alias) t t)
            ;; If different, show both
            (replace-match (format "_%s_ (%s)" alias page) t t))))
      ;; Then handle simple links: [[file:PAGE]] -> _PAGE_
      (goto-char (point-min))
      (while (re-search-forward "\\[\\[file:\\([^]]+\\)\\]\\]" nil t)
        (let ((page (match-string 1)))
          (replace-match (format "_%s_" page) t t)))
      (buffer-string)))

  (defun import-obsidian-markdown--archive-file (md-file project-root)
    "Archive MD-FILE to .obsidian-archive/ preserving directory structure.
PROJECT-ROOT is the root directory of the project."
    (let* ((relative-path (file-relative-name md-file project-root))
           (archive-dir (expand-file-name ".obsidian-archive" project-root))
           (archive-path (expand-file-name relative-path archive-dir))
           (archive-parent-dir (file-name-directory archive-path)))
      ;; Create archive directory structure if needed
      (unless (file-exists-p archive-parent-dir)
        (make-directory archive-parent-dir t))
      ;; Handle filename conflicts by adding timestamp
      (when (file-exists-p archive-path)
        (let ((timestamp (format-time-string "%Y%m%d-%H%M%S"))
              (base-name (file-name-sans-extension archive-path))
              (extension (file-name-extension archive-path t)))
          (setq archive-path (format "%s-%s%s" base-name timestamp extension))))
      ;; Move the file
      (rename-file md-file archive-path)
      (message "Archived to: %s" (file-relative-name archive-path project-root))))

  (defun import-obsidian-markdown--insert-in-org (filename content)
    "Insert org content as child heading under current heading with FILENAME as title."
    (let* ((heading-level (condition-case nil
                              (progn
                                (org-back-to-heading t)
                                (1+ (org-current-level)))  ; One level deeper = child
                            (error 1)))
           (basename (file-name-sans-extension
                     (file-name-nondirectory filename))))
      ;; Move to end of current heading (before any subheadings)
      (condition-case nil
          (progn
            (org-back-to-heading t)
            (outline-next-heading))
        (error (goto-char (point-max))))
      ;; Insert blank line if needed
      (unless (bolp) (insert "\n"))
      ;; Insert new heading as child
      (insert (make-string heading-level ?*) " " basename "\n")
      ;; Insert content under the heading
      (insert content)
      (unless (string-suffix-p "\n" content)
        (insert "\n"))))

  (defun import-obsidian-markdown-to-org ()
    "Import Obsidian markdown file from current project to org-mode.
Uses helm to select .md file, converts to org-mode with pandoc,
fixes wikilinks to underlined text, inserts after current heading,
and archives original file to .obsidian-archive/."
    (interactive)
    (let* ((project (project-current))
           (project-root (if project
                            (project-root project)
                          (user-error "Not in a project. Use M-x project-find-file first"))))
      ;; Find all .md files in project
      (let* ((all-files (project-files project))
             (md-files (seq-filter (lambda (f) (string-suffix-p ".md" f)) all-files))
             (candidates (mapcar (lambda (f)
                                  (cons (file-relative-name f project-root) f))
                                md-files)))
        (if (not md-files)
            (message "No markdown files found in project")
          ;; Show helm selector
          (helm :sources (helm-build-sync-source "Import Markdown File"
                           :candidates candidates
                           :action '(("Import to org-mode" .
                                     (lambda (md-file)
                                       (let* ((org-content (import-obsidian-markdown--convert-with-pandoc md-file))
                                              (fixed-content (import-obsidian-markdown--fix-wikilinks org-content)))
                                         ;; Insert in current buffer
                                         (unless (derived-mode-p 'org-mode)
                                           (user-error "Current buffer must be in org-mode"))
                                         (import-obsidian-markdown--insert-in-org md-file fixed-content)
                                         ;; Archive the original file
                                         (import-obsidian-markdown--archive-file md-file project-root)
                                         (message "Imported %s" (file-name-nondirectory md-file)))))))
                :buffer "*helm import markdown*")))))

  :bind
  ("C-c i" . import-obsidian-markdown-to-org))

;;;; Development Tools

(use-package compile
  :ensure nil
  :custom
  (compilation-scroll-output t)
  :config
  (add-to-list 'display-buffer-alist
               '("\\*compilation\\*"
                 (display-buffer-reuse-window display-buffer-below-selected)
                 (window-height . 0.3)
                 (dedicated . t)))
  (defun my-compilation-auto-close (buf status)
    "Close compilation window after a delay if it succeeded.
Only applies to the *compilation* buffer, not grep or other derivatives."
    (when (and (string-match-p "finished" status)
               (equal (buffer-name buf) "*compilation*"))
      (run-at-time 1 nil
                   (lambda (b)
                     (when-let ((win (get-buffer-window b)))
                       (delete-window win)))
                   buf)))
  (add-hook 'compilation-finish-functions #'my-compilation-auto-close))

(use-package highlight-thing
  :ensure t
  :hook (prog-mode . highlight-thing-mode))

(use-package magit
  :ensure t
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
  :ensure t
  :after magit
  :demand t)

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-force-searcher 'rg)
  :init
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

(use-package go-ts-mode
  :if (memq 'go my-host-packages)
  :mode ("\\.go\\'" . go-ts-mode)
  :mode ("/go\\.mod\\'" . go-mod-ts-mode)
  :config
  (add-to-list 'treesit-language-source-alist '(go "https://github.com/tree-sitter/tree-sitter-go"))
  (add-to-list 'treesit-language-source-alist '(gomod "https://github.com/camdencheek/tree-sitter-go-mod")))

(use-package dockerfile-mode :ensure t :defer t)
(use-package yaml-mode :ensure t :defer t)
(use-package markdown-mode :ensure t :defer t)
(use-package typescript-mode :ensure t :defer t :if (memq 'typescript my-host-packages))
(use-package adaptive-wrap :ensure t :defer t)
(use-package web-mode
  :ensure t
  :mode ("\\.html\\'" . web-mode)
  :hook ((web-mode . visual-line-mode)
         (web-mode . adaptive-wrap-prefix-mode)))

;;;; Lisp Development

(use-package paredit
  :ensure t
  :hook ((emacs-lisp-mode lisp-mode lisp-interaction-mode slime-repl-mode scheme-mode) . paredit-mode)
  :config
  ;; Let paredit win over evil in insert state for structural editing
  (with-eval-after-load 'evil
    (evil-define-key 'insert paredit-mode-map
      (kbd "C-k") #'paredit-kill
      (kbd "C-d") #'paredit-forward-delete)))

(use-package slime
  :if (memq 'slime my-host-packages)
  :ensure t
  :init
  (setq inferior-lisp-program "sbcl")
  :config
  (slime-setup '(slime-fancy slime-quicklisp slime-asdf))
  (load "~/quicklisp/clhs-use-local.el" 'noerror))

