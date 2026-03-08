;; Host-specific configuration for arch-mac

;; Darkman theme integration
;; darkman pushes changes via emacsclient calling my-darkman-set-theme
;; Startup sync is deferred via after-init-hook since theme functions
;; (my-select-dark-theme etc.) are defined later in init.el.

(defun my-darkman-set-theme (mode)
  "Set theme based on MODE string (\"dark\" or \"light\").
Called externally by darkman via emacsclient."
  (setq my-theme-manual-override nil)
  (let ((is-dark (string= mode "dark")))
    (unless (eq is-dark my-current-theme-is-dark)
      (setq my-current-theme-is-dark is-dark)
      (mapc #'disable-theme custom-enabled-themes)
      (if is-dark
          (my-select-dark-theme)
        (my-select-light-theme)))))

(defun my-darkman-get-mode ()
  "Query darkman for current mode. Returns \"dark\" or \"light\"."
  (string-trim (shell-command-to-string "darkman get")))

(add-hook 'after-init-hook
          (lambda ()
            (let ((mode (my-darkman-get-mode)))
              (if (member mode '("dark" "light"))
                  (my-darkman-set-theme mode)
                (my-select-dark-theme)))))

;; nvm (node/npm) binaries — find the latest installed version
(let* ((nvm-node-dir (expand-file-name "~/.nvm/versions/node"))
       (versions (and (file-directory-p nvm-node-dir)
                      (directory-files nvm-node-dir t "^v")))
       (nvm-bin (when versions
                  (expand-file-name "bin" (car (last (sort versions #'string<)))))))
  (when nvm-bin
    (setenv "PATH" (concat nvm-bin ":" (getenv "PATH")))
    (add-to-list 'exec-path nvm-bin)))

;; When running as a daemon (systemd), import graphical session
;; env vars so browse-url/xdg-open can find the display.
;; Runs on every new frame since DISPLAY can change between sessions.
(when (daemonp)
  (defun my-update-env-from-systemd ()
    "Import DISPLAY, WAYLAND_DISPLAY, etc. from the systemd user session."
    (dolist (var '("DISPLAY" "WAYLAND_DISPLAY" "XDG_SESSION_TYPE"
                   "XDG_CURRENT_DESKTOP" "XDG_RUNTIME_DIR"))
      (let ((val (string-trim
                  (shell-command-to-string
                   (format "systemctl --user show-environment 2>/dev/null | grep '^%s=' | cut -d= -f2-" var)))))
        (unless (string-empty-p val)
          (setenv var val)))))
  (add-hook 'server-after-make-frame-hook #'my-update-env-from-systemd)
  ;; Also run once at init for the first frame
  (add-hook 'after-init-hook #'my-update-env-from-systemd))

;; Host-specific optional packages (used by :if in init.el)
(setq my-host-packages '(slime))

;; Fix underline position (draw below descenders, not at baseline)
(setq x-underline-at-descent-line t)

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-arch-mac.el")
(load custom-file)
