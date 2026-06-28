;; ========================================================================== ;;
;;  1. CROSS-PLATFORM & SYSTEM DETECTION
;; ========================================================================== ;;
(defun system-is-windows () (eq system-type 'windows-nt))
(defun system-is-linux () (eq system-type 'gnu/linux))

;; If on Windows, inject Git for Windows Unix paths into Emacs environment
(when (system-is-windows)
  (let ((git-bin-path "C:/Program Files/Git/usr/bin"))
    (when (file-directory-p git-bin-path)
      (setenv "PATH" (concat git-bin-path ";" (getenv "PATH")))
      (add-to-list 'exec-path git-bin-path))))

;; ========================================================================== ;;
;;  2. QUALITY OF LIFE / CORE SETTINGS (Your .vimrc Translations)
;; ========================================================================== ;;
(setq inhibit-startup-screen t)               ; Disable the welcome splash screen
(setq-default display-line-numbers 'relative) ; set number, set relativenumber
(setq scroll-margin 8)                        ; set scrolloff=8
(setq-default tab-width 4)                    ; set tabstop=4, shiftwidth=4
(setq-default indent-tabs-mode nil)          ; set expandtab
(setq make-backup-files nil)                  ; set nobackup
(setq auto-save-default nil)                  ; set nowritebackup

;; Clean UI - Remove the 1995 desktop toolbars
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(setq scroll-preserve-screen-position t) ; Keeps cursor at the same relative screen line when jumping
(setq scroll-conservatively 101)          ; Tells Emacs to NEVER violently auto-recenter the page

;; ========================================================================== ;;
;;  3. AUTOMATIC PACKAGE BOOTSTRAPPING
;; ========================================================================== ;;
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; package-initialize is intentionally omitted here as Emacs handles it natively now.

;; Ensure 'use-package' is downloaded and ready to configure everything
(unless (package-installed-p 'use-package)
  (package-refresh-repositories)
  (package-install 'use-package))
(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t) ; Automatically downloads plugins when needed

;; Theme Selection (Matches your solarized theme preference)
(use-package solarized-theme
  :config (load-theme 'solarized-light t))

;; PERSISTENT UNDO (Equivalent to Vim's set undofile)
(use-package undo-fu-session
  :ensure t
  :config
  (setq undo-fu-session-directory (expand-file-name "undo-fu-session" user-emacs-directory))
  (setq undo-fu-session-incompatible-files '("\\.git/COMMIT_EDITMSG\\'"))
  (global-undo-fu-session-mode))

;; ========================================================================== ;;
;;  4. THE VIM EMULATION LAYER (Evil-mode)
;; ========================================================================== ;;
(use-package evil
  :init
  (setq evil-want-keybinding nil) ; Required background handshake flag
  (setq evil-toggle-key "")       ; Completely disables Ctrl+z from breaking normal mode
  :config
  (evil-mode 1)
  
  ;; Unifies standard y/p mechanics with system clipboard
  (setq evil-into-clipboard t)

;; NATIVE KEYBOARD SMOOTH SCROLLING (The Definitive Fix)
(use-package smooth-scrolling
  :ensure t
  :init
  ;; Strict configuration to completely eliminate the display engine's snapping panic
  (setq scroll-margin 8)
  (setq scroll-conservatively 101)
  (setq scroll-preserve-screen-position t)
  :config
  (smooth-scrolling-mode 1))

;; Restore native Evil paging mechanics (which now animate smoothly)
  (define-key evil-normal-state-map (kbd "C-d") 'evil-scroll-down)
  (define-key evil-normal-state-map (kbd "C-u") 'evil-scroll-up)

  ;; Center search jumps natively (n / N)
  (advice-add 'evil-search-next :after #'evil-scroll-line-to-center)
  (advice-add 'evil-search-previous :after #'evil-scroll-line-to-center)

  ;; ========================================================================== ;;
  ;; THE NATIVE EMACS CHORD SYSTEM (Stable, Custom Shortcuts)
  ;; ========================================================================== ;;
  
  ;; Ctrl+c g -> Smart Project-Aware Magit Status
  (define-key evil-normal-state-map (kbd "C-c g") 
              (lambda () (interactive) (magit-status (or (vc-root-dir) default-directory))))

  ;; Ctrl+c u -> Visual Undo Tree Map (Vundo)
  (define-key evil-normal-state-map (kbd "C-c u") 'vundo)

  ;; Ctrl+c f -> Sidebar Project File Tree (Dirvish)
  (define-key evil-normal-state-map (kbd "C-c f") 'dirvish-side))

;; ========================================================================== ;;
;;  5. TARGETED PLUGINS
;; ========================================================================== ;;

;; EXTENSIBLE STARTUP DASHBOARD
(use-package dashboard
  :ensure t
  :config
  (dashboard-setup-startup-hook)
  
  ;; Configure Dashboard Banner & Titles
  (setq dashboard-banner-logo-title "Welcome to Emacs")
  (setq dashboard-startup-banner 'official)
  
  ;; Choose what items appear on your landing screen
  (setq dashboard-items '((recents  . 5)
                          (projects . 5)))

  ;; THE MAGIC FOOTER: Package Count + Accurate Boot Metrics
  (setq dashboard-set-footer t)
  (defun my-dashboard-footer-strings ()
    (list (format "Emacs loaded in %s with %d packages ready to go."
                  (emacs-init-time)
                  (length package-activated-list))))
  (setq dashboard-footer-messages (my-dashboard-footer-strings))

  ;; THE EMACSCLIENT COMPATIBILITY LAYER
  ;; Forces new visual client frames to look at the dashboard instead of an empty scratchpad
  (setq initial-buffer-choice (lambda () (get-buffer-create "*dashboard*"))))

;; VISUAL UNDO (Better alternative to undotree)
(use-package vundo
  :defer t)

;; FILE TREE EXTENSION (Modern alternative to NERDTree)
(use-package dirvish
  :init
  (dirvish-override-dired-mode)
  :config
  (setq dirvish-attributes '(file-size file-time vc-state icons))
  
  ;; TOTAL VIM HOME-ROW DIRECTORY NAVIGATION
  (with-eval-after-load 'dired
    (with-eval-after-load 'evil
      ;; --- INSTANT ONE-TAP QUIT ---
      (evil-define-key 'normal dired-mode-map (kbd "q") 'dirvish-quit)

      ;; --- GO IN (Right / Enter) ---
      (evil-define-key 'normal dired-mode-map (kbd "l") 'dired-find-file)
      (evil-define-key 'normal dired-mode-map (kbd "RET") 'dired-find-file)
      (evil-define-key 'normal dired-mode-map (kbd "<return>") 'dired-find-file)
      
      ;; --- GO OUT (Left / Backspace) ---
      (evil-define-key 'normal dired-mode-map (kbd "h") 'dired-up-directory)
      (evil-define-key 'normal dired-mode-map (kbd "<backspace>") 'dired-up-directory)
      (evil-define-key 'normal dired-mode-map (kbd "DEL") 'dired-up-directory)
      
      ;; --- MOVE CURSOR (Down / Up) ---
      (evil-define-key 'normal dired-mode-map (kbd "j") 'dired-next-line)
      (evil-define-key 'normal dired-mode-map (kbd "k") 'dired-previous-line))))

;; FAST SELECTIVE MENUS (Alternative to Ctrl-P)
(use-package vertico
  :init
  (vertico-mode 1)
  :config
  (with-eval-after-load 'evil
    ;; Bind Ctrl+p to find ANY file recursively from your current directory (fzf style!)
    (define-key evil-normal-state-map (kbd "C-p") 'find-file-in-project-or-dir)
    ;; Bind Ctrl+Shift+p to find a file ANYWHERE on your system via a standard prompt
    (define-key evil-normal-state-map (kbd "C-P") 'find-file))
  :init
  (defun find-file-in-project-or-dir ()
    "If inside a Git repo, fuzzy find files in it. Otherwise, fuzzy find from the current directory."
    (interactive)
    (if (vc-root-dir)
        (project-find-file)
      (let ((default-directory default-directory))
        (find-file)))))

;; GENERIC LANGUAGE EXTENSIONS FOR SYNTAX HIGHLIGHTING
(use-package lua-mode
  :defer t
  :mode "\\.lua\\'")

(use-package fsharp-mode
  :defer t
  :mode "\\.fs[xi]?\\'")

;; TERMINAL CLIPBOARD BRIDGE
(use-package xclip
  :config
  (xclip-mode 1))

;; ========================================================================== ;;
;;  6. BUILT-IN LIGHTWEIGHT LSP (Eglot)
;; ========================================================================== ;;
(use-package eglot
  :ensure nil ; Built-in feature, do not download external
  :hook
  ((prog-mode . eglot-ensure)) ; Turn on LSP when entering code files
  :config
  (with-eval-after-load 'evil
    (define-key evil-normal-state-map (kbd "gd") 'xref-find-definitions)
    (define-key evil-normal-state-map (kbd "gr") 'xref-find-references)
    (define-key evil-normal-state-map (kbd "K")  'eldoc)))

;; MAGIT (The Git Engine)
(use-package magit
  :defer t)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(dashboard dirvish evil fsharp-mode inter lua-mode magit
               scroll-on-jump smooth-scrolling solarized-theme
               undo-fu-session vertico vundo xclip)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
