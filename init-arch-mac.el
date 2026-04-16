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

;; mu4e (email)
(use-package mu4e
  :load-path "/usr/share/emacs/site-lisp/mu4e"
  :commands (mu4e)
  :config
  ;; Sync
  (setq mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval 300)  ; auto-sync every 5 minutes

  ;; Fastmail folders
  (setq mu4e-maildir "~/Mail/fastmail"
        mu4e-sent-folder "/Sent"
        mu4e-drafts-folder "/Drafts"
        mu4e-trash-folder "/Trash"
        mu4e-refile-folder "/Archive")

  ;; Fastmail stores sent messages server-side, don't duplicate
  (setq mu4e-sent-messages-behavior 'delete)

  ;; Compose/identity
  (setq mu4e-compose-reply-to-address "al@megamicron.net"
        user-mail-address "al@megamicron.net"
        user-full-name "Aleksandr Pasechnik")

  ;; Send via msmtp
  (setq sendmail-program "msmtp"
        send-mail-function #'smtpmail-send-it
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-send-mail-function #'message-send-mail-with-sendmail)

  ;; Show full addresses, not just names
  (setq mu4e-view-show-addresses t)

  ;; Rename files when moving — required for mbsync compatibility
  (setq mu4e-change-filenames-when-moving t)

  ;; Move to Trash folder without adding Trashed flag,
  ;; otherwise Expunge Both in mbsync permanently deletes them
  (setq mu4e-trash-without-flag t)

  ;; Don't keep message buffers around
  (setq message-kill-buffer-on-exit t)

  ;; Prefer plain text over HTML when both are available
  (with-eval-after-load 'mm-decode
    (add-to-list 'mm-discouraged-alternatives "text/html")
    (add-to-list 'mm-discouraged-alternatives "text/richtext"))

  ;; Ensure temp files for HTML MIME parts get .html extension
  ;; so browsers render them properly
  (defun my-mu4e-mime-temp-file-add-html-ext (orig-fun handle)
    "Add .html extension when the MIME part is text/html."
    (let ((file (funcall orig-fun handle)))
      (if (and (equal (car (mm-handle-type handle)) "text/html")
               (not (string-suffix-p ".html" file)))
          (let ((new-file (concat file ".html")))
            (rename-file file new-file)
            new-file)
        file)))
  (advice-add 'mu4e--view-mime-part-to-temp-file
              :around #'my-mu4e-mime-temp-file-add-html-ext))

;; Fix underline position (draw below descenders, not at baseline)
(setq x-underline-at-descent-line t)

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-arch-mac.el")
(load custom-file)
