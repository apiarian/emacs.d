;; Host-specific configuration for pop-os

;; Default AI agent for agent-shell
(defvar my-default-agent 'pi
  "Preferred agent for agent-shell on this host.")

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

;; Set custom-file for this host
(setq custom-file "~/.emacs.d/emacs-custom-popos.el")
(load custom-file)
