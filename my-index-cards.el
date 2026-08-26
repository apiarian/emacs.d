;;; my-index-cards.el --- Fixed-capacity markdown index cards -*- lexical-binding: t; -*-

;;; Commentary:

;; Index cards are small markdown notes with a knowable size limit.  A
;; saved card is guaranteed to fit entirely within
;; `index-card-cols' x `index-card-rows' with no hidden data.  Overflow
;; is allowed while editing (highlighted and flagged in the mode line)
;; but blocked at save time.
;;
;; Cards live under `index-card-directory' as *.md files and link to
;; each other with file-level `[[card-name]]' wiki links (no extension,
;; no sub-heading anchors); `[[foo]]' resolves to `<dir>/foo.md'.
;;
;; Editing is an overwrite grid: the buffer is padded with spaces to
;; `index-card-cols' x `index-card-rows' so every cell exists, typing
;; replaces the character under the cursor, and the cursor can move
;; anywhere.  Padding is stripped again at save time.

;;; Code:

(require 'picture)
(require 'face-remap)

(defgroup index-card nil
  "Fixed-capacity markdown index cards."
  :group 'text)

(defcustom index-card-directory (expand-file-name "~/index-cards/")
  "Directory holding index card *.md files."
  :type 'directory
  :group 'index-card)

(defcustom index-card-cols 60
  "Maximum number of columns a saved card may occupy."
  :type 'integer
  :group 'index-card)

(defcustom index-card-rows 20
  "Maximum number of lines a saved card may occupy."
  :type 'integer
  :group 'index-card)

(defcustom index-card-overflow-action 'error
  "What to do when saving a card that exceeds its capacity.
`error' blocks the save with a `user-error'.  `warn' allows the
save but reports the violation."
  :type '(choice (const :tag "Block the save" error)
                 (const :tag "Warn but allow" warn))
  :group 'index-card)

(defface index-card-overflow-face
  '((t :inherit error))
  "Face for card content beyond the allowed columns or rows."
  :group 'index-card)

(defface index-card-boundary-face
  '((t :underline t :extend t))
  "Face marking the horizontal boundary at the last allowed row."
  :group 'index-card)

(defvar index-card-mode)
(declare-function markdown-mode "markdown-mode")

(defvar-local index-card--overflow-overlays nil
  "Overlays marking overflowing columns and rows in the current card.")

(defvar-local index-card--adjusting nil
  "Non-nil while padding the grid, to prevent re-entry from change hooks.")

;;; Measurement

(defun index-card--line-columns ()
  "Return the column width of the current line, respecting tabs."
  (save-excursion
    (end-of-line)
    (current-column)))

(defun index-card--max-line-columns ()
  "Return the width in columns of the widest line in the buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((widest 0))
      (while (progn
               (setq widest (max widest (index-card--line-columns)))
               (zerop (forward-line 1)))
        (when (eobp) (setq widest (max widest (index-card--line-columns)))))
      widest)))

(defun index-card--violations ()
  "Return a list of human-readable capacity violations, or nil.
Checks every line's column width and the total line count."
  (let ((violations nil)
        (line 1))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((cols (index-card--line-columns)))
          (when (> cols index-card-cols)
            (push (format "line %d is %d cols (max %d)"
                          line cols index-card-cols)
                  violations)))
        (setq line (1+ line))
        (forward-line 1)))
    (let ((rows (count-lines (point-min) (point-max))))
      (when (> rows index-card-rows)
        (push (format "%d lines (max %d)" rows index-card-rows)
              violations)))
    (nreverse violations)))

;;; Overwrite grid editing

(defun index-card-self-insert (n)
  "Insert the last typed character N times, overwriting in place.
Pads with spaces to reach the current column when past end of line,
then replaces the character under point rather than pushing existing
text right, keeping the line width fixed."
  (interactive "p")
  (let ((char last-command-event)
        (indent-tabs-mode nil)
        (index-card--adjusting t))
    (dotimes (_ n)
      (move-to-column (current-column) t)
      (unless (or (eolp) (= (char-after) ?\n))
        (delete-char 1))
      (insert char))
    (setq-local fill-column index-card-cols)
    (index-card--pad-grid))
  (index-card--refresh-overflow))

;;; Grid padding

(defun index-card--pad-grid ()
  "Pad the buffer with spaces so every grid cell exists.
Ensures at least `index-card-rows' lines and pads each of them to
`index-card-cols' columns so the fill-column line, the row boundary,
and mouse clicks all have real cells to land on.  Content beyond the
grid is left intact.  Padding is kept off the undo list; it is
stripped again at save time by `index-card--clean-whitespace'."
  (let ((buffer-undo-list t)
        (indent-tabs-mode nil))
    (save-excursion
      (goto-char (point-min))
      (let ((have 1))
        (while (search-forward "\n" nil t)
          (setq have (1+ have)))
        (when (< have index-card-rows)
          (goto-char (point-max))
          (insert (make-string (- index-card-rows have) ?\n))))
      (goto-char (point-min))
      (dotimes (_ index-card-rows)
        (end-of-line)
        (let ((col (current-column)))
          (when (< col index-card-cols)
            (insert (make-string (- index-card-cols col) ?\s))))
        (forward-line 1)))))

(defun index-card--after-change (&rest _)
  "Re-pad the grid and refresh overflow decorations after edits.
Also syncs `fill-column' so a card adopts the current size when edited."
  (unless index-card--adjusting
    (let ((index-card--adjusting t))
      (setq-local fill-column index-card-cols)
      (index-card--pad-grid)
      (index-card--refresh-overflow))))

(defun index-card--after-save ()
  "Restore the visual grid padding stripped by the save hooks.
The file on disk holds only real content; the padding is cosmetic,
so the buffer is left unmodified afterward."
  (when index-card-mode
    (let ((index-card--adjusting t))
      (index-card--pad-grid)
      (set-buffer-modified-p nil))
    (index-card--refresh-overflow)))

(defun index-card--set-cursor ()
  "Show a hollow-box cursor while typing in a card.
Card editing always overwrites, so Evil insert state (where typing
happens) gets a hollow box instead of the usual bar; other states
keep Evil's defaults.  Without Evil, the buffer cursor is hollow."
  (setq-local cursor-type 'hollow)
  (when (bound-and-true-p evil-mode)
    (set (make-local-variable 'evil-insert-state-cursor) 'hollow)
    (when (fboundp 'evil-refresh-cursor)
      (evil-refresh-cursor))))

;;; Overflow highlighting

(defun index-card--clear-overflow-overlays ()
  "Remove all overflow overlays from the current buffer."
  (mapc #'delete-overlay index-card--overflow-overlays)
  (setq index-card--overflow-overlays nil))

(defun index-card--overlay (beg end &optional face)
  "Add a decoration overlay from BEG to END using FACE.
FACE defaults to `index-card-overflow-face'."
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'face (or face 'index-card-overflow-face))
    (overlay-put ov 'index-card-overflow t)
    (push ov index-card--overflow-overlays)))

(defun index-card--refresh-overflow (&rest _)
  "Recompute overflow overlays for columns and rows."
  (when index-card-mode
    (index-card--clear-overflow-overlays)
    (save-excursion
      (goto-char (point-min))
      (let ((line 1))
        (while (not (eobp))
          (when (> (index-card--line-columns) index-card-cols)
            (let ((beg (progn (move-to-column index-card-cols) (point)))
                  (end (line-end-position)))
              (index-card--overlay beg end)))
          (when (> line index-card-rows)
            (index-card--overlay (line-beginning-position)
                                 (min (point-max) (1+ (line-end-position)))))
          (setq line (1+ line))
          (forward-line 1))))
    (save-excursion
      (goto-char (point-min))
      (when (and (> index-card-rows 0)
                 (zerop (forward-line (1- index-card-rows))))
        (index-card--overlay (line-beginning-position)
                             (min (point-max) (1+ (line-end-position)))
                             'index-card-boundary-face)))
    (force-mode-line-update)))

;;; Mode line

(defun index-card--mode-line ()
  "Return the mode-line indicator string for the current card."
  (let* ((cols (index-card--max-line-columns))
         (rows (count-lines (point-min) (point-max)))
         (over (or (> cols index-card-cols) (> rows index-card-rows))))
    (if over
        (format " Card \u26a0 %dx%d" cols rows)
      (format " Card %dx%d" index-card-cols index-card-rows))))

;;; Save enforcement

(defun index-card--clean-whitespace ()
  "Strip trailing whitespace and trailing blank lines in the card.
Runs before capacity validation so padding never dirties the file
or triggers false overflow."
  (when index-card-mode
    (let ((index-card--adjusting t))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "[ \t]+$" nil t)
          (replace-match ""))
        (goto-char (point-max))
        (skip-chars-backward " \t\n")
        (delete-region (point) (point-max))))))

(defun index-card--validate-on-save ()
  "Enforce capacity when saving, per `index-card-overflow-action'."
  (when index-card-mode
    (let ((violations (index-card--violations)))
      (when violations
        (let ((msg (concat "index-card: " (mapconcat #'identity violations "; "))))
          (pcase index-card-overflow-action
            ('warn (display-warning 'index-card msg :warning))
            (_ (user-error "%s" msg))))))))

;;; Windowing

(defun index-card--display-buffer (buffer)
  "Show BUFFER in an ordinary window, reusing an existing one if present.
Cards are plain windows the user tiles with normal splits.  Returns
the window showing BUFFER."
  (or (get-buffer-window buffer)
      (progn (pop-to-buffer buffer '(display-buffer-reuse-window))
             (get-buffer-window buffer))))

(defun index-card-fit ()
  "Resize the current window to `index-card-cols' x `index-card-rows'.
Resizes the viewport only; card content and capacity are never
touched.  This works within the current Emacs frame and cannot grow
the window beyond what the frame and other windows allow."
  (interactive)
  (let* ((win (selected-window))
         (width-delta (- index-card-cols (window-body-width win)))
         (height-delta (- index-card-rows (window-body-height win))))
    (ignore-errors (window-resize win width-delta t))
    (ignore-errors (window-resize win height-delta nil))))

(defun index-card-reload ()
  "Reapply the current `index-card-cols' x `index-card-rows' to this card.
Use after changing the size to re-set `fill-column', re-pad the grid,
and refresh the boundary and overflow decorations in this buffer."
  (interactive)
  (unless index-card-mode
    (user-error "index-card: not an index card buffer"))
  (setq-local fill-column index-card-cols)
  (let ((index-card--adjusting t)
        (was-modified (buffer-modified-p)))
    (index-card--pad-grid)
    (unless was-modified (set-buffer-modified-p nil)))
  (index-card--refresh-overflow))

;;; Cards and links

(defun index-card--file (name)
  "Return the absolute *.md path for card NAME."
  (expand-file-name (concat name ".md") index-card-directory))

(defun index-card--names ()
  "Return the list of existing card names (without extension)."
  (when (file-directory-p index-card-directory)
    (mapcar #'file-name-base
            (directory-files index-card-directory nil "\\.md\\'"))))

(defun index-card-new (name)
  "Create or open card NAME and show it in a fixed side window."
  (interactive "sIndex card name: ")
  (make-directory index-card-directory t)
  (let* ((file (index-card--file name))
         (existed (file-exists-p file))
         (buffer (find-file-noselect file)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'markdown-mode)
        (markdown-mode))
      (unless index-card-mode
        (index-card-mode 1)))
    (select-window (index-card--display-buffer buffer))
    (unless existed
      (message "index-card: created %s" (file-relative-name file)))))

(defun index-card-open (name)
  "Open existing card NAME in a fixed side window."
  (interactive
   (list (completing-read "Open card: " (index-card--names) nil t)))
  (let ((buffer (find-file-noselect (index-card--file name))))
    (select-window (index-card--display-buffer buffer))))

(defun index-card-insert-link (name)
  "Insert a `[[NAME]]' wiki link at point."
  (interactive
   (list (completing-read "Link to card: " (index-card--names))))
  (insert (format "[[%s]]" name)))

(defun index-card--link-at-point ()
  "Return the card name of the `[[...]]' link at point, or nil."
  (save-excursion
    (let ((pos (point))
          (bol (line-beginning-position))
          (eol (line-end-position)))
      (goto-char bol)
      (catch 'found
        (while (re-search-forward "\\[\\[\\([^]]+\\)\\]\\]" eol t)
          (when (and (<= (match-beginning 0) pos)
                     (<= pos (match-end 0)))
            (throw 'found (match-string-no-properties 1))))
        nil))))

(defun index-card-follow-link ()
  "Open the card linked at point, offering to create it if missing."
  (interactive)
  (let ((name (index-card--link-at-point)))
    (cond
     ((null name) (user-error "index-card: no [[link]] at point"))
     ((file-exists-p (index-card--file name)) (index-card-open name))
     ((yes-or-no-p (format "Card %s does not exist.  Create it? " name))
      (index-card-new name))
     (t (message "index-card: %s not opened" name)))))

;;; Minor mode

(defvar index-card-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap self-insert-command] #'index-card-self-insert)
    (define-key map (kbd "C-c C-l") #'index-card-follow-link)
    (define-key map (kbd "C-c i") #'index-card-insert-link)
    (define-key map (kbd "C-c C-f") #'index-card-fit)
    (define-key map (kbd "C-c C-r") #'index-card-reload)
    map)
  "Keymap for `index-card-mode'.")

(defvar-local index-card--saved-truncate-lines nil
  "Value of `truncate-lines' before `index-card-mode' changed it.")

(defvar-local index-card--face-cookies nil
  "Face-remap cookies neutralizing Markdown code-block faces in cards.")

(define-minor-mode index-card-mode
  "Minor mode layering fixed-capacity card behavior over `markdown-mode'.

Editing is an overwrite grid (see `index-card-self-insert'): the
buffer is padded so every cell exists and typing replaces in place.
Overflow beyond `index-card-cols' x `index-card-rows' is highlighted
with `index-card-overflow-face' and flagged in the mode line, and is
blocked at save time per `index-card-overflow-action'.

\\{index-card-mode-map}"
  :lighter (:eval (index-card--mode-line))
  :keymap index-card-mode-map
  (if index-card-mode
      (progn
        (index-card--set-cursor)
        (setq-local fill-column index-card-cols)
        (display-fill-column-indicator-mode 1)
        (setq index-card--saved-truncate-lines truncate-lines)
        (when (fboundp 'hl-line-mode) (hl-line-mode -1))
        (setq-local global-hl-line-mode nil)
        (setq index-card--face-cookies
              (delq nil
                    (mapcar (lambda (face)
                              (when (facep face)
                                (face-remap-add-relative face 'default)))
                            '(markdown-pre-face markdown-code-face))))
        (setq-local scroll-margin 0)
        (setq-local scroll-conservatively 100000)
        (setq-local make-cursor-line-fully-visible nil)
        (setq-local auto-hscroll-mode nil)
        (setq-local auto-window-vscroll nil)
        (setq-local truncate-lines t)
        (add-hook 'after-change-functions #'index-card--after-change nil t)
        (add-hook 'before-save-hook #'index-card--validate-on-save nil t)
        (add-hook 'before-save-hook #'index-card--clean-whitespace nil t)
        (add-hook 'after-save-hook #'index-card--after-save nil t)
        (let ((index-card--adjusting t)
              (was-modified (buffer-modified-p)))
          (index-card--pad-grid)
          (unless was-modified (set-buffer-modified-p nil)))
        (index-card--refresh-overflow))
    (remove-hook 'after-change-functions #'index-card--after-change t)
    (remove-hook 'before-save-hook #'index-card--validate-on-save t)
    (remove-hook 'before-save-hook #'index-card--clean-whitespace t)
    (remove-hook 'after-save-hook #'index-card--after-save t)
    (kill-local-variable 'evil-insert-state-cursor)
    (when (fboundp 'evil-refresh-cursor) (evil-refresh-cursor))
    (mapc #'face-remap-remove-relative index-card--face-cookies)
    (setq index-card--face-cookies nil)
    (index-card--clear-overflow-overlays)
    (display-fill-column-indicator-mode -1)
    (kill-local-variable 'fill-column)
    (kill-local-variable 'cursor-type)
    (setq-local truncate-lines index-card--saved-truncate-lines)
    (kill-local-variable 'global-hl-line-mode)
    (kill-local-variable 'scroll-margin)
    (kill-local-variable 'scroll-conservatively)
    (kill-local-variable 'make-cursor-line-fully-visible)
    (kill-local-variable 'auto-hscroll-mode)
    (kill-local-variable 'auto-window-vscroll)))

(defun index-card--maybe-enable ()
  "Enable `index-card-mode' for markdown files under `index-card-directory'."
  (when (and buffer-file-name
             (derived-mode-p 'markdown-mode)
             (file-in-directory-p buffer-file-name index-card-directory))
    (index-card-mode 1)))

(add-hook 'markdown-mode-hook #'index-card--maybe-enable)

(provide 'my-index-cards)

;;; my-index-cards.el ends here
