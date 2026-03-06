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

;; Host-specific optional packages (used by :if in init.el)
(setq my-host-packages '(slime))

;; Fix underline position (draw below descenders, not at baseline)
(setq x-underline-at-descent-line t)

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-arch-mac.el")
(load custom-file)
