;; Host-specific configuration for COMP-KKVCV56XMN

;; Default AI agent for agent-shell
(defvar my-default-agent 'claude-code
  "Preferred agent for agent-shell on this host.")

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
