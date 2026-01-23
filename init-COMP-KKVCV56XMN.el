;; Host-specific configuration for COMP-KKVCV56XMN

;; Enable Claude Code integration on this machine
(defvar my-enable-claude-code t
  "When non-nil, load claude-code.el and related packages.")

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-mac.el")
(load custom-file)

;; Default prefix for new Git branches in magit
(defvar my-magit-branch-prefix "aleksandr.pasechnik/"
  "Default prefix for new Git branches in magit.")
