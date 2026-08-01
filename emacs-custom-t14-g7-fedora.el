;;; -*- lexical-binding: t -*-
;; Per-host custom-file for t14-g7-fedora (Fedora 44, niri).
;; Font family + :height are per-machine: this is a 1920x1200 14" panel
;; (~162 dpi, niri scale 1). Adjust :height to taste on the real panel.
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(helm-minibuffer-history-key "M-p")
 '(inhibit-startup-screen t)
 '(org-hide-emphasis-markers t)
 '(package-selected-packages
   '(adaptive-wrap avy dockerfile-mode dumb-jump evil-collection evil-org
		   evil-surround forge god-mode gptel helm-org-ql
		   highlight-thing jinx markdown-mermaid minions
		   org-tidy paredit slime solarized-theme
		   typescript-mode undo-tree vterm-anti-flicker-filter
		   web-mode yaml-mode))
 '(package-vc-selected-packages 'nil)
 '(tab-bar-mode t)
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :extend nil :stipple nil :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight regular :height 130 :width normal :foundry "UKWN" :family "VictorMono Nerd Font Mono")))))
