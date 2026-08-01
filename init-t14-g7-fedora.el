;; Host-specific configuration for t14-g7-fedora
;; Lenovo ThinkPad T14 Gen7, Fedora 44, niri (Wayland).
;;
;; Theme switching is driven externally by the lenovo-t14-gen7 repo's
;; `theme-apply' script (waybar button / `theme-toggle'), which runs
;;   emacsclient --eval "(modus-themes-select 'modus-{operandi,vivendi}-tinted)"
;; So there is NO darkman polling here (unlike the Arch MacBook). We only need
;; to pick up whichever mode is current when Emacs (or a new frame) starts.

;; theme-apply records the active mode in $XDG_STATE_HOME/theme-mode
;; (default ~/.local/state/theme-mode). Read it at startup and match it.
;; The theme functions (my-select-dark-theme etc.) are defined later in
;; init.el, so defer to after-init-hook.
(defun my-t14-current-theme-mode ()
  "Return \"dark\" or \"light\" from the repo's theme-mode state file."
  (let ((f (expand-file-name
            "theme-mode"
            (or (getenv "XDG_STATE_HOME")
                (expand-file-name "~/.local/state")))))
    (if (file-readable-p f)
        (with-temp-buffer
          (insert-file-contents f)
          (string-trim (buffer-string)))
      "light")))

(defun my-t14-sync-theme ()
  "Load the modus theme matching the current desktop mode."
  (let ((is-dark (string= (my-t14-current-theme-mode) "dark")))
    (setq my-current-theme-is-dark is-dark)
    (mapc #'disable-theme custom-enabled-themes)
    (if is-dark (my-select-dark-theme) (my-select-light-theme))))

(add-hook 'after-init-hook #'my-t14-sync-theme)
;; New daemon frames should also match the current mode.
(when (daemonp)
  (add-hook 'server-after-make-frame-hook #'my-t14-sync-theme))

;; ~/.local/bin — user scripts (web-search, web-fetch, theme-*, etc.)
(let ((local-bin (expand-file-name "~/.local/bin")))
  (when (file-directory-p local-bin)
    (setenv "PATH" (concat local-bin ":" (getenv "PATH")))
    (add-to-list 'exec-path local-bin)))

;; When running as a daemon (systemd), import graphical session env vars so
;; browse-url/xdg-open can find the Wayland display. Runs on every new frame
;; since the display can change between sessions.
(when (daemonp)
  (defun my-update-env-from-systemd ()
    "Import WAYLAND_DISPLAY, DISPLAY, etc. from the systemd user session."
    (dolist (var '("DISPLAY" "WAYLAND_DISPLAY" "XDG_SESSION_TYPE"
                   "XDG_CURRENT_DESKTOP" "XDG_RUNTIME_DIR"))
      (let ((val (string-trim
                  (shell-command-to-string
                   (format "systemctl --user show-environment 2>/dev/null | grep '^%s=' | cut -d= -f2-" var)))))
        (unless (string-empty-p val)
          (setenv var val)))))
  (add-hook 'server-after-make-frame-hook #'my-update-env-from-systemd)
  (add-hook 'after-init-hook #'my-update-env-from-systemd))

;; Host-specific optional packages (used by :if in init.el).
;; sbcl is installed system-wide, so enable slime. Node is the system
;; nodejs22 (no nvm/volta here); go/typescript not set up on this host.
(setq my-host-packages '(slime))

;; Fix underline position (draw below descenders, not at baseline).
(setq x-underline-at-descent-line t)

;; Set custom-file for this host (fonts/DPI are per-machine).
(setq custom-file "~/.emacs.d/emacs-custom-t14-g7-fedora.el")
(load custom-file)
