;;; -*- lexical-binding: nil; -*-
;;; Some useful emacs info (because I'm a n00b)
;;; C-h v (for variable info)
;;; C-h f (for function info)
;;; C-h k <KEY> (for keybinding info)
;;; C-h m (mode info)
;;; C-h i (generic info page, all the info!)
;;;
;;; C-x p f	project-find-file	Fuzzy find any file in the current project instantly.
;;; C-x p p	project-switch-project	Teleport to a different project from your history.
;;; C-x p g	project-find-regexp	Search for code inside every file in the project (uses ripgrep/grep).
;;; C-x p D	project-dired	Open a file manager (Dired) scoped directly to the root of the project.
;;; C-x p eshell	project-eshell	Spawn a terminal wrapper natively inside that project's directory.
;;;
;;; C-x j dired  Just opens up a dired buffer right where you are

(setq load-prefer-newer t) ; Prefer .el files over .elc files when loading configs (i.e. favour recompiling this config file over using stale caches of it)

(defun system-is-windows () (eq system-type 'windows-nt))

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
(setq make-backup-files nil)                  ; Disable backup files
(setq auto-save-default nil)                  ; Disable auto-save recovery files

;; Cleanup UI
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(setq scroll-preserve-screen-position t) ; Keeps cursor at the same relative screen line when jumping
(setq scroll-conservatively 101)          ; Tells Emacs to NEVER violently auto-recenter the page

(add-to-list 'default-frame-alist '(width . 170))
(add-to-list 'default-frame-alist '(height . 75))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; package-initialize is intentionally omitted here as Emacs handles it natively now.

;; Force Emacs to download the package index if it hasn't yet
(unless package-archive-contents
  (package-refresh-contents))
;; Ensure 'use-package' is downloaded and ready to configure everything
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t) ; Automatically downloads plugins when needed

(setq read-file-name-completion-ignore-case t)

;; Theme Selection (Matches your solarized theme preference)
(use-package solarized-theme
  :config (load-theme 'solarized-light t))

(setq initial-scratch-message nil)

;; PERSISTENT UNDO (Equivalent to Vim's set undofile)
(use-package undo-fu-session
  :ensure t
  :config
  (setq undo-fu-session-directory (expand-file-name "undo-fu-session" user-emacs-directory))
  (setq undo-fu-session-incompatible-files '("\\.git/COMMIT_EDITMSG\\'"))
  (setq undo-fu-session-linear nil) ; Ensure full history tree structure is preserved
  (setq undo-fu-session-compression 'zst)

  (add-hook 'focus-out-hook #'undo-fu-session-save) ; Save if window is focused out of
  (run-with-idle-timer 5 t #'undo-fu-session-save) ; Save every 5 seconds of idle time
  (undo-fu-session-global-mode))


(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t) ; Required by evil-collection
  (setq evil-want-keybinding nil) ; Required background handshake flag & needed for evil-collection
  (setq evil-vsplit-window-right t) ; Vim-style splitting
  (setq evil-split-window-below t)
  :config
  (evil-mode 1)
  
  ;; Smoothie: inertia-based smooth scrolling (core engine; no evil dep)
  (require 'smoothie)

  ;; Evil's search flash (yellow all-matches + purple current-match) is driven
  ;; by a self-rescheduling lazy-highlight loop that re-paints the current
  ;; window region every tick. While smoothie scrolls the window that loop
  ;; flickers. So: suppress evil's flash entirely while smoothie is active,
  ;; then pulse just the landed-on match once the animation settles, using the
  ;; same red fade that `gd'/`xref-find-definitions' uses.
  (require 'pulse)
  ;; Ensure the animated (fading) pulse branch is used. `pulse-flag' defaults to
  ;; (pulse-available-p), which can be nil if pulse loads before the theme sets
  ;; frame colors. Force it on since GUI frames always support pulsing.
  (setq pulse-flag t)
  (defvar my/smoothie-last-match nil
    "Pending search match as (BUFFER WINDOW BEG END).")

  (defun my/smoothie-suppress-evil-flash (orig-fun string &optional all)
    "Skip evil's search flash while smoothie is capturing or animating."
    (unless (smoothie-active-p)
      (funcall orig-fun string all)))
  (advice-add 'evil-flash-search-pattern :around
              #'my/smoothie-suppress-evil-flash)

  (defun my/smoothie-pulse-current-match ()
    "Pulse the current search match (red fade) after a smoothie animation.
Uses match bounds captured by the search wrapper (not live match-data, which
can be clobbered by font-lock during a long scroll animation)."
    (when my/smoothie-last-match
      (let ((pending my/smoothie-last-match))
        (setq my/smoothie-last-match nil)
        (let ((buffer (nth 0 pending))
              (window (nth 1 pending))
              (beg (nth 2 pending))
              (end (nth 3 pending)))
          (when (and (eq buffer (current-buffer))
                     (eq window (selected-window))
                     (integer-or-marker-p beg)
                     (integer-or-marker-p end)
                     (<= (point-min) beg)
                     (< beg end)
                     (<= end (point-max)))
            (pulse-momentary-highlight-region beg end 'next-error))))))
  (add-hook 'smoothie-finish-hook #'my/smoothie-pulse-current-match)

  ;; --- Smoothie wrapper commands (scroll then `zz` center) ---
  (defun my/smoothie-scroll-and-center (command)
    "Run scrolling COMMAND with margins disabled, then center point."
    (setq my/smoothie-last-match nil)
    (let ((scroll-margin 0))
      (condition-case err
          (call-interactively command)
        ((beginning-of-buffer end-of-buffer)
         (goto-char (if (eq (car err) 'beginning-of-buffer)
                        (point-min)
                      (point-max))))))
    (cond
     ((and (memq command '(evil-scroll-up evil-scroll-page-up))
           (= (window-start) (point-min)))
      (goto-char (point-min)))
     ((and (memq command '(evil-scroll-down evil-scroll-page-down))
           (eobp))
      (goto-char (point-max))))
    (evil-scroll-line-to-center nil))

  (defun my/smoothie-c-d ()
    "Smooth C-d: `evil-scroll-down` then center, with scroll-margin disabled."
    (interactive)
    (my/smoothie-scroll-and-center #'evil-scroll-down))

  (defun my/smoothie-c-u ()
    "Smooth C-u: `evil-scroll-up` then center, with scroll-margin disabled."
    (interactive)
    (my/smoothie-scroll-and-center #'evil-scroll-up))

  (defun my/smoothie-page-down ()
    "Smooth Page Down: `evil-scroll-page-down` then center, with scroll-margin disabled."
    (interactive)
    (my/smoothie-scroll-and-center #'evil-scroll-page-down))

  (defun my/smoothie-page-up ()
    "Smooth Page Up: `evil-scroll-page-up` then center, with scroll-margin disabled."
    (interactive)
    (my/smoothie-scroll-and-center #'evil-scroll-page-up))

  (defun my/smoothie-search (command)
    "Run search COMMAND, save its match, and center point."
    (let ((pattern (if evil-regexp-search
                       (car-safe regexp-search-ring)
                     (car-safe search-ring))))
      (setq my/smoothie-last-match nil)
      (call-interactively command)
      (let* ((beg (match-beginning 0))
             (end (match-end 0))
             (match (and (stringp pattern)
                         (> (length pattern) 0)
                         beg end
                         (= (point) beg)
                         (<= (point-min) beg)
                         (<= beg end)
                         (<= end (point-max))
                         (list (current-buffer) (selected-window) beg end))))
        (evil-scroll-line-to-center nil)
        (setq my/smoothie-last-match match))))

  (defun my/smoothie-search-next ()
    "Smooth n: repeat the last search forward, then center."
    (interactive)
    (my/smoothie-search #'evil-search-next))

  (defun my/smoothie-search-previous ()
    "Smooth N: repeat the last search backward, then center."
    (interactive)
    (my/smoothie-search #'evil-search-previous))

  ;; --- Key bindings (Evil paging keys; prefix arg / count preserved) ----------
  (define-key evil-normal-state-map (kbd "C-d")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-c-d))))
  (define-key evil-normal-state-map (kbd "C-u")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-c-u))))
  (define-key evil-normal-state-map (kbd "C-S-d")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg)
                      (evil-scroll-count 10))
                  (smoothie-do #'my/smoothie-c-d))))
  (define-key evil-normal-state-map (kbd "C-S-u")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg)
                      (evil-scroll-count 10))
                  (smoothie-do #'my/smoothie-c-u))))

  (define-key evil-normal-state-map (kbd "<next>") ; Page down
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-page-down))))
  (define-key evil-normal-state-map (kbd "<prior>") ; Page up
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-page-up))))

  (define-key evil-normal-state-map (kbd "n")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-search-next))))
  (define-key evil-normal-state-map (kbd "N")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-search-previous))))

  ;; Ctrl+c g -> Smart Project-Aware Magit Status
  (define-key evil-normal-state-map (kbd "C-c g") 
              (lambda () (interactive) (magit-status (or (vc-root-dir) default-directory))))

  ;; Ctrl+c u -> Visual Undo Tree Map (Vundo)
  (define-key evil-normal-state-map (kbd "C-c u") 'vundo)

  ;; Ctrl+c t -> Project File Tree
  (define-key evil-normal-state-map (kbd "C-c t") #'treemacs)

    ;; Fast Travel: Mnemonic "b" for Bookmark
    (define-key evil-normal-state-map (kbd "C-c b b") #'bookmark-jump)  ; "Bookmark: Bookmarked locations"
    (define-key evil-normal-state-map (kbd "C-c b m") #'bookmark-set)   ; "Bookmark: Mark this location"
    (define-key evil-normal-state-map (kbd "C-c b l") #'bookmark-bmenu-list) ; "Bookmark: List all"
    )

(use-package evil-collection
  :ensure t
  :after evil ; Ensure it loads AFTER evil
  :config
  (evil-collection-init)

  (evil-define-key 'normal dired-mode-map
    (kbd "h") 'dired-up-directory ; 'h' goes back/up a directory
    (kbd "<backspace>") 'dired-up-directory ; Backspace also goes back/up
    (kbd "DEL") 'dired-up-directory ; Backspace alternative (not the delete key... for some reason?)
    (kbd "l") 'dired-find-file) ; 'f' opens/goes into a directory

  (evil-define-key 'normal vundo-mode-map
    (kbd "C-c u") 'vundo-quit
    (kbd "<escape>") 'vundo-quit)
  )

(add-hook 'dired-mode-hook #'dired-hide-details-mode)

(use-package dired-subtree
  :ensure t
  :commands (dired-subtree-insert dired-subtree-remove))

(use-package git-timemachine
  :ensure t
  :commands (git-timemachine))

(use-package imenu-list
  :ensure t
  :commands (imenu-list-smart-toggle))

(use-package move-text
  :ensure t
  :after evil
  :config
  (evil-define-key 'visual 'global
    (kbd "J") #'move-text-down
    (kbd "K") #'move-text-up))

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

(use-package treemacs
  :ensure t
  :commands (treemacs))

(use-package treemacs-evil
  :ensure t
  :after (treemacs evil))

;(defun post-text-scale-callback ()
;  ;; fix line number text size
;  (let ((new-size (floor (* (face-attribute 'default :height)
;                            (expt text-scale-mode-step text-scale-mode-amount)))))
;    (set-face-attribute 'line-number nil :height new-size)
;    (set-face-attribute 'line-number-current-line nil :height new-size)))

;(add-hook 'text-scale-mode-hook 'post-text-scale-callback)

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic)))

(use-package consult
  :ensure t
  :config
  ;; Global default fallback
  (setq consult-find-args "find . -maxdepth 3"))

(defun my/consult-find-project-or-up ()
  "Search files starting from the project root (infinite depth) if it exists, 
otherwise start from the parent directory, max 3 levels deep."
  (interactive)
  (let ((proj (project-current)))
    (if proj
        ;; If in a project, remove the depth limit (-maxdepth) completely
        (let ((default-directory (project-root proj))
              (consult-find-args "find .")) ; Overrides the global -maxdepth 3
          (consult-find))
      ;; Fallback: Go up one level and use the global 3-level depth limit
      (let ((default-directory (expand-file-name ".." default-directory)))
        (consult-find)))))

(use-package vertico
  :init
  (vertico-mode 1)
  :config
  (with-eval-after-load 'evil
    (define-key evil-normal-state-map (kbd "C-p") #'my/consult-find-project-or-up)))

;; Enable rich annotations using the Marginalia package
(use-package marginalia
  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))

  ;; The :init section is always executed.
  :init

  ;; Marginalia must be activated in the :init section of use-package such that
  ;; the mode gets enabled right away. Note that this forces loading the
  ;; package.
  (marginalia-mode))

(use-package vundo
  :defer t
  :config
  (setq vundo-glyph-alist vundo-unicode-symbols)
  (defun my/vundo-live-diff-refresh ()
    "Automatically update the vundo diff buffer on cursor movement."
    (when (derived-mode-p 'vundo-mode)
      ;; ignore errors if we are on the very first node (no parent to diff against)
      (ignore-errors (vundo-diff))))

  (add-hook 'post-command-hook #'my/vundo-live-diff-refresh)
  )

(use-package gptel
  :config
  ;; Define OpenRouter as a backend
  (setq gptel-backend
        (gptel-make-openai "OpenRouter"
          :host "openrouter.ai"
          :endpoint "/api/v1/chat/completions"
          :stream t
           :key (lambda ()
                  (gptel-api-key-from-auth-source "openrouter.ai" "apikey"))
           :models '(openai/gpt-5.6-luna-pro
                     openai/gpt-5.6-luna
                    deepseek/deepseek-v4-flash)))

  ;; Enable tool execution / agent mode
  (setq gptel-expert-commands t))

;; GENERIC LANGUAGE EXTENSIONS FOR SYNTAX HIGHLIGHTING
(use-package lua-mode
  :defer t
  :mode "\\.lua\\'")

(use-package fsharp-mode
  :defer t
  :mode "\\.fs[xi]?\\'"
  :config
  ;; Ensure project.el is loaded, then remove the F# root-finding interference
  (with-eval-after-load 'project
    (setq project-find-functions (delq 'fsharp-mode-project-root project-find-functions))))

;; clipboard access. On Windows, native clipboard integration works without it.
(unless (system-is-windows)
  (use-package xclip
    :config
    (xclip-mode 1)))

(use-package dumb-jump
  :ensure t)

(use-package lsp-mode
  :ensure t
  :defer t)

(defun my/evil-goto-definition ()
  "Use LSP for definitions, falling back to Dumb Jump."
  (interactive)
  (if (and (bound-and-true-p lsp-mode)
           (fboundp 'lsp-workspaces)
           (fboundp 'lsp-find-definition)
           (lsp-workspaces))
      (condition-case _error
          (call-interactively #'lsp-find-definition)
        (error
         (message "LSP lookup failed; trying Dumb Jump")
         (call-interactively #'dumb-jump-go)))
    (call-interactively #'dumb-jump-go)))

(with-eval-after-load 'evil
  (define-key evil-normal-state-map
              (kbd "g d")
              #'my/evil-goto-definition))

;; MAGIT (The Git Engine)
(use-package magit
  :defer t)

; Auto generated stuff below...
; ============================
  
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(gptel-confirm-tool-calls nil)
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
