; Some useful emacs info (because I'm a n00b)
; C-h v (for variable info)
; C-h f (for function info)
; C-h k <KEY> (for keybinding info)
; C-h m (mode info)
; C-h i (generic info page, all the info!)

(setq load-prefer-newer t) ; Prefer .el files over .elc files when loading configs (i.e. favour recompiling this config file over using stale caches of it)

(defun system-is-windows () (eq system-type 'windows-nt))
(defun system-is-linux () (eq system-type 'gnu/linux))

;; If on Windows, inject Git for Windows Unix paths into Emacs environment
(when (system-is-windows)
  (let ((git-bin-path "C:/Program Files/Git/usr/bin"))
    (when (file-directory-p git-bin-path)
      (setenv "PATH" (concat git-bin-path ";" (getenv "PATH")))
      (add-to-list 'exec-path git-bin-path))))

(setq inhibit-startup-screen t)               ; Disable the welcome splash screen
(setq-default display-line-numbers 'relative) ; set number, set relativenumber
(setq scroll-margin 8)                        ; set scrolloff=8
(setq-default tab-width 4)                    ; set tabstop=4, shiftwidth=4
(setq-default indent-tabs-mode nil)           ; set expandtab
(setq make-backup-files nil)                  ; set nobackup
(setq auto-save-default nil)                  ; set nowritebackup

;; Cleanup UI
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(setq scroll-preserve-screen-position t) ; Keeps cursor at the same relative screen line when jumping
(setq scroll-conservatively 101)          ; Tells Emacs to NEVER violently auto-recenter the page

;; Allow local files (e.g. smoothie.el) to be `require'd
(add-to-list 'load-path user-emacs-directory)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; package-initialize is intentionally omitted here as Emacs handles it natively now.

;; Force Emacs to download the package index if it hasn't yet
(unless package-archive-contents
  (package-refresh-contents))
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
  (setq unfo-fu-session-linear nil) ; Ensure full history tree structure is preserved
  (setq undo-fu-session-compression 'zst)

  (add-hook 'focus-out-hook #'undo-fu-session-save) ; Save if window is focused out of
  (run-with-idle-timer 5 t #'undo-fu-session-save) ; Save every 5 seconds of idle time
  (global-undo-fu-session-mode))


(use-package evil
  :ensure t
  :init
  (setq evil-want-intergration t) ; Required by evil-collection
  (setq evil-want-keybinding nil) ; Required background handshake flag & needed for evil-collection
  (setq evil-vsplit-window-right t) ; Vim-style splitting
  (setq evil-split-window-below t)
  :config
  (evil-mode 1)
  
  ;; Unifies standard y/p mechanics with system clipboard
  (setq evil-into-clipboard t)

  ;; Smoothie: inertia-based smooth scrolling (extracted to its own file)
  (require 'smoothie)
  
  ;; Ctrl+c g -> Smart Project-Aware Magit Status
  (define-key evil-normal-state-map (kbd "C-c g") 
              (lambda () (interactive) (magit-status (or (vc-root-dir) default-directory))))

  ;; Ctrl+c u -> Visual Undo Tree Map (Vundo)
  (define-key evil-normal-state-map (kbd "C-c u") 'vundo)

  ;; Ctrl+c f -> Sidebar Project File Tree
  (define-key evil-normal-state-map (kbd "C-c f") 'dired-sidebar-toggle-sidebar))

(use-package evil-collection
  :ensure t
  :after evil ; Ensure it loads AFTER evil
  :config
  (evil-collection-init)

  (evil-define-key 'normal dired-mode-map
    (kbd "h") 'dired-up-directory ;'h' goes back/up a directory
    (kbd "l") 'dired-find-file)) ;'f' opens/goes into a directory

;; NATIVE TREE-SITTER SETUP (Emacs 29+)
(use-package treesit
  :ensure nil ; Built-in to Emacs 29+
  :config
  ;; Automatically map standard modes to their newer Tree-sitter variants
  (setq major-mode-remap-alist
        '((python-mode . python-ts-mode)
          (js-mode     . js-ts-mode)
          (c-mode      . c-ts-mode)
          (c++-mode    . c++-ts-mode)
          (rust-mode   . rust-ts-mode)
          (css-mode    . css-ts-mode))))


;; Auto-install missing language grammars when you open a file
(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist))

(use-package dired-sidebar
  :ensure t
  :commands (dired-sidebar-toggle-sidebar))

;; CITRE SETUP (Modern Universal Ctags Frontend)
(use-package citre
  :ensure t
  :defer t
  :init
  ;; Bind Citre's powerful navigation keys globally
  (global-set-key (kbd "M-.") #'citre-jump)
  (global-set-key (kbd "M-,") #'citre-jump-back)
  (global-set-key (kbd "M-?") #'citre-peek)
  
  :config
  ;; Tie Citre directly to Emacs' standard cross-reference (xref) system
  (require 'citre-config)
  
  ;; Tell Citre where to find your Universal Ctags binary if it's not in PATH
  ;; (setq citre-ctags-program "/usr/local/bin/ctags") 
  
  ;; Highlight the line you jump to briefly so you don't lose your cursor
  (setq citre-peek-fill-fringe t))


;; EXTENSIBLE STARTUP DASHBOARD
(use-package dashboard
  :ensure t
  :config

  ;; Configure Dashboard Banner & Titles
  (setq dashboard-banner-logo-title "Welcome to Emacs")
  (setq dashboard-startup-banner 'official)
  
  ;; Choose what items appear on your landing screen
  (setq dashboard-items '((recents  . 5)
                          (projects . 5))))

(use-package vundo
  :defer t)

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
;; Only needed on GNU/Linux where Emacs runs in a terminal without GUI
;; clipboard access. On Windows, native clipboard integration works without it.
(unless (system-is-windows)
  (use-package xclip
    :config
    (xclip-mode 1)))

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
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
