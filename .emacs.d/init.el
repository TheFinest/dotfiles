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

  ;; ========================================================================== ;;
  ;;  SMOOTHIE: Inertia-based smooth scrolling (elisp port of vim-smoothie)
  ;; ========================================================================== ;;
  ;; Recreates the velocity curve of vim-smoothie:
  ;;   velocity = sign(d) * (constant + linear * |d|^exponent)
  ;; which produces fast-then-easing-out (inertia) movement toward the target.
  (defvar smoothie-update-interval 0.02
    "Seconds between animation frames. Lower = smoother (more redraws).")
  (defvar smoothie-speed-constant-factor 10.0
    "Constant term of the velocity curve (boosts speed near the end).")
  (defvar smoothie-speed-linear-factor 10.0
    "Linear term of the velocity curve (boosts speed at the start).")
  (defvar smoothie-speed-exponentiation-factor 0.9
    "Exponent on distance. <=1.0; lower = longer, smoother animation.")

  (defvar smoothie--timer nil)
  (defvar smoothie--target-start-line nil)
  (defvar smoothie--target-point-line nil)
  (defvar smoothie--subline-start 0.0)
  (defvar smoothie--subline-point 0.0)
  (defvar smoothie--last-time nil)
  (defvar smoothie--buffer nil)
  (defvar smoothie--window nil)

  (defun smoothie--velocity (distance)
    "Signed velocity for a line DISTANCE (mirrors vim-smoothie)."
    (let ((abs-speed (+ smoothie-speed-constant-factor
                       (* smoothie-speed-linear-factor
                          (expt (abs distance)
                                smoothie-speed-exponentiation-factor)))))
      (if (< distance 0) (- abs-speed) abs-speed)))

  (defun smoothie--move-element (distance subline-var)
    "Return (INTEGER-STEP . NEW-SUBLINE) for one axis given DISTANCE.
DISTANCE is remaining lines; SUBLINE-VAR is the carried fractional remainder."
    (let* ((vel (smoothie--velocity distance))
           (step-total (+ (* vel smoothie-update-interval)
                          (symbol-value subline-var)))
           (int-step (truncate step-total)))
      (if (>= (abs int-step) (abs distance))
          (cons distance 0.0)
        (cons int-step (- step-total int-step)))))

  (defun smoothie--apply-step (start-step point-step)
    "Apply START-STEP / POINT-STEP (signed line counts) to the window and cursor."
    (when (/= start-step 0)
      (let ((ws (window-start)))
        (save-excursion
          (goto-char ws)
          (forward-line start-step)
          (set-window-start nil (point) t))))
    (when (/= point-step 0)
      (forward-line point-step)))

  (defun smoothie--tick ()
    "Single animation frame, invoked by the timer."
    (condition-case err
        (if (or (not (eq (current-buffer) smoothie--buffer))
                (not (eq (selected-window) smoothie--window)))
            (smoothie--finish)
          (let ((cur-start-line (line-number-at-pos (window-start)))
                (cur-point-line (line-number-at-pos (point))))
            (let ((dist-start (- smoothie--target-start-line cur-start-line))
                  (dist-point (- smoothie--target-point-line cur-point-line)))
              (if (and (= dist-start 0) (= dist-point 0))
                  (smoothie--finish)
                (let ((s (smoothie--move-element dist-start 'smoothie--subline-start))
                      (p (smoothie--move-element dist-point 'smoothie--subline-point)))
                  (setq smoothie--subline-start (cdr s)
                        smoothie--subline-point (cdr p))
                  (let ((scroll-margin 0))
                    (smoothie--apply-step (car s) (car p))
                    (redisplay t)))))))
      (error
       (message "smoothie error: %S" err)
       (smoothie--finish))))

  (defun smoothie--finish ()
    "Snap to the target position and stop the timer."
    (when (timerp smoothie--timer)
      (cancel-timer smoothie--timer)
      (setq smoothie--timer nil))
    (when (and smoothie--target-start-line smoothie--target-point-line
               (eq (current-buffer) smoothie--buffer)
               (eq (selected-window) smoothie--window))
      (let ((scroll-margin 0))
        (set-window-start
         nil
         (save-excursion
           (goto-char (point-min))
           (forward-line (1- smoothie--target-start-line))
           (point))
         t)
        (goto-char (save-excursion
                     (goto-char (point-min))
                     (forward-line (1- smoothie--target-point-line))
                     (point)))
        (redisplay t)))
    (setq smoothie--target-start-line nil
          smoothie--target-point-line nil
          smoothie--subline-start 0.0
          smoothie--subline-point 0.0))

  (defun smoothie-do (command)
    "Execute COMMAND interactively, then animate to its resulting position.
Mirrors vim-smoothie's `smoothie#do': the command is run once to capture the
target view, the view is restored, and a timer animates toward the target."
    (interactive)
    (when smoothie--timer (smoothie--finish))
    (let ((orig-start (window-start))
          (orig-point (point))
          (target-start-line)
          (target-point-line))
      (let ((inhibit-redisplay t))
        (condition-case err
            (call-interactively command)
          (error (message "smoothie-do: %S" err)))
        (setq target-start-line (line-number-at-pos (window-start))
              target-point-line (line-number-at-pos (point)))
        (set-window-start nil orig-start t)
        (goto-char orig-point))
      (if (and (= target-start-line (line-number-at-pos orig-start))
               (= target-point-line (line-number-at-pos orig-point)))
          ;; Nothing to animate; re-run for real so side effects (search, etc.) land.
          (let ((inhibit-redisplay nil))
            (call-interactively command))
        (setq smoothie--target-start-line target-start-line
              smoothie--target-point-line target-point-line
              smoothie--subline-start 0.0
              smoothie--subline-point 0.0
              smoothie--buffer (current-buffer)
              smoothie--window (selected-window)
              smoothie--last-time (float-time))
        (setq smoothie--timer
              (run-with-timer smoothie-update-interval smoothie-update-interval
                              #'smoothie--tick)))))

  ;; --- Wrapper commands (match your .vimrc: scroll then `zz` center) ---
  (defun my/smoothie-c-d ()
    "Smooth C-d: `evil-scroll-down` then center, with scroll-margin disabled."
    (interactive)
    (let ((scroll-margin 0))
      (call-interactively #'evil-scroll-down))
    (evil-scroll-line-to-center nil))

  (defun my/smoothie-c-u ()
    "Smooth C-u: `evil-scroll-up` then center, with scroll-margin disabled."
    (interactive)
    (let ((scroll-margin 0))
      (call-interactively #'evil-scroll-up))
    (evil-scroll-line-to-center nil))

  (defun my/smoothie-search-next ()
    "Smooth n: `evil-search-next` then center."
    (interactive)
    (call-interactively #'evil-search-next)
    (evil-scroll-line-to-center nil))

  (defun my/smoothie-search-previous ()
    "Smooth N: `evil-search-previous` then center."
    (interactive)
    (call-interactively #'evil-search-previous)
    (evil-scroll-line-to-center nil))

  ;; Bind Evil paging keys through smoothie (prefix arg / count preserved)
  (define-key evil-normal-state-map (kbd "C-d")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-c-d))))
  (define-key evil-normal-state-map (kbd "C-u")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-c-u))))
  (define-key evil-normal-state-map (kbd "n")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-search-next))))
  (define-key evil-normal-state-map (kbd "N")
              (lambda (arg) (interactive "P")
                (let ((current-prefix-arg arg))
                  (smoothie-do #'my/smoothie-search-previous))))

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
