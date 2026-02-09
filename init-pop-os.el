;; Host-specific configuration for pop-os

;; Default AI agent for agent-shell
(defvar my-default-agent 'pi
  "Preferred agent for agent-shell on this host.")

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-popos.el")
(load custom-file)
