;; Host-specific configuration for COMP-KKVCV56XMN

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-mac.el")
(load custom-file)

;; Volta (node/npm) binaries
(let ((volta-bin (expand-file-name "~/.volta/bin")))
  (setenv "PATH" (concat volta-bin ":" (getenv "PATH")))
  (add-to-list 'exec-path volta-bin))

;; Host-specific optional packages (used by :if in init.el)
(setq my-host-packages '(go typescript))

;; Default prefix for new Git branches in magit
(defvar my-magit-branch-prefix "aleksandr.pasechnik/"
  "Default prefix for new Git branches in magit.")

;; Window title: show buffer name (or file path if visiting a file)
(setq frame-title-format '((:eval (if (buffer-file-name)
                                      (abbreviate-file-name (buffer-file-name))
                                    "%b"))))

;; gptel: Anthropic Claude.
;; API key lives in ~/.authinfo (chmod 600) as:
;;   machine api.anthropic.com password sk-ant-...
(setq my-gptel-setup-fn
      (lambda ()
        (setq gptel-model   'claude-haiku-4-5
              gptel-backend (gptel-make-anthropic "Claude"
                              :stream t
                              :key (lambda ()
                                     (auth-source-pick-first-password
                                      :host "api.anthropic.com"))
                              :models '(claude-haiku-4-5)))))
