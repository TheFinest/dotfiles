;;; smoothie.el --- Inertia-based smooth scrolling (elisp port of vim-smoothie) -*- lexical-binding: t; -*-

;; Recreates the velocity curve of vim-smoothie:
;;   velocity = sign(d) * (constant + linear * |d|^exponent)
;; which produces fast-then-easing-out (inertia) movement toward the target.
;;
;; This file contains ONLY the core animation engine. It is framework-agnostic;
;; it does not depend on evil or any other package. Use `smoothie-do' to wrap
;; any movement command: it runs the command once, captures the resulting window
;; and cursor positions, then animates toward them.
;;
;; Example (in your init, after loading evil):
;;
;;   (require 'smoothie)
;;   (defun my/smoothie-c-d ()
;;     (interactive)
;;     (let ((scroll-margin 0)) (call-interactively #'evil-scroll-down))
;;     (evil-scroll-line-to-center nil))
;;   (define-key evil-normal-state-map (kbd "C-d")
;;               (lambda (arg) (interactive "P")
;;                 (let ((current-prefix-arg arg))
;;                   (smoothie-do #'my/smoothie-c-d))))

;; --- User options -----------------------------------------------------------
(defgroup smoothie nil
  "Inertia-based smooth scrolling."
  :group 'convenience)

(defcustom smoothie-update-interval 0.02
  "Seconds between animation frames. Lower values redraw more often."
  :type '(number :tag "Seconds")
  :group 'smoothie)
(defcustom smoothie-speed-constant-factor 10.0
  "Constant term of the velocity curve."
  :type 'number
  :group 'smoothie)
(defcustom smoothie-speed-linear-factor 10.0
  "Linear term of the velocity curve."
  :type 'number
  :group 'smoothie)
(defcustom smoothie-speed-exponentiation-factor 0.9
  "Exponent on remaining distance."
  :type 'number
  :group 'smoothie)

;; --- Internal state ---------------------------------------------------------
(defvar smoothie--timer nil)
(defvar smoothie--last-tick-time nil)
(defvar smoothie--target-start nil)
(defvar smoothie--target-point nil)
(defvar smoothie--subline-start 0.0)
(defvar smoothie--subline-point 0.0)
(defvar smoothie--buffer nil)
(defvar smoothie--window nil)

;; Hook for front-end integration. Run in the target buffer/window context.
(defvar smoothie-finish-hook nil
  "Hook run from `smoothie--finish' after the animation has settled and the
window/cursor have been snapped to their final positions. Use this to refresh
transient UI once the view is stable.")

;; Non-nil only while `smoothie-do' is capturing a command's target position
;; (i.e. while the wrapped command is actually executing). Front-ends may query
;; `smoothie-active-p' to suppress transient UI that should not appear during a
;; smoothie-driven command (e.g. evil's search flash, which would flicker as
;; the window scrolls).
(defvar smoothie--capturing nil)

(defun smoothie-active-p ()
  "Return non-nil while smoothie is capturing a target or animating.
Front-ends use this to decide whether to defer transient UI (e.g. search
highlighting) until `smoothie-finish-hook' fires."
  (or smoothie--capturing smoothie--timer))

;; --- Core animation engine ---------------------------------------------------
(defun smoothie--velocity (distance)
  "Signed velocity for a line DISTANCE (mirrors vim-smoothie)."
  (let ((abs-speed (+ smoothie-speed-constant-factor
                     (* smoothie-speed-linear-factor
                        (expt (abs distance)
                              smoothie-speed-exponentiation-factor)))))
    (if (< distance 0) (- abs-speed) abs-speed)))

(defun smoothie--sign (number)
  "Return -1, 0, or 1 for NUMBER."
  (cond ((< number 0) -1)
        ((> number 0) 1)
        (t 0)))

(defun smoothie--move-element (distance subline-var elapsed)
  "Return (INTEGER-STEP . NEW-SUBLINE) for one axis given DISTANCE.
DISTANCE is remaining lines, SUBLINE-VAR is the carried fractional remainder,
and ELAPSED is seconds since the preceding animation frame."
  (let* ((vel (smoothie--velocity distance))
         (step-total (+ (* vel elapsed)
                        (symbol-value subline-var)))
         (int-step (truncate step-total)))
    (if (>= (abs int-step) (abs distance))
        (cons distance 0.0)
      (cons int-step (- step-total int-step)))))

(defun smoothie--apply-step (window start-step point-step)
  "Apply START-STEP / POINT-STEP (signed line counts) to the window and cursor."
  (when (/= start-step 0)
    (let ((ws (window-start window)))
      (save-excursion
        (goto-char ws)
        (forward-line start-step)
        (set-window-start window (point) t))))
  (when (/= point-step 0)
    (goto-char (window-point window))
    (forward-line point-step)))

(defun smoothie--tick ()
  "Single animation frame, invoked by the timer."
  (if (or (not (window-live-p smoothie--window))
          (not (buffer-live-p smoothie--buffer))
          (not (eq (window-buffer smoothie--window) smoothie--buffer)))
      (smoothie--cancel)
    (with-selected-window smoothie--window
      (condition-case err
          (let* ((now (float-time))
                 (elapsed (max 0.0
                               (if smoothie--last-tick-time
                                   (- now smoothie--last-tick-time)
                                 smoothie-update-interval)))
                 (current-start-line
                  (line-number-at-pos (window-start smoothie--window)))
                 (current-point-line
                  (line-number-at-pos (window-point smoothie--window)))
                 (target-start-line
                  (line-number-at-pos smoothie--target-start))
                 (target-point-line
                  (line-number-at-pos smoothie--target-point))
                 (start-distance (- target-start-line current-start-line))
                 (point-distance (- target-point-line current-point-line)))
            (setq smoothie--last-tick-time now)
            (if (and (= start-distance 0) (= point-distance 0))
                (smoothie--finish)
              (let ((start-move
                     (smoothie--move-element
                      start-distance 'smoothie--subline-start elapsed))
                    (point-move
                     (smoothie--move-element
                      point-distance 'smoothie--subline-point elapsed)))
                (setq smoothie--subline-start (cdr start-move)
                      smoothie--subline-point (cdr point-move))
                (when (or (/= (car start-move) 0)
                          (/= (car point-move) 0))
                  (let ((scroll-margin 0))
                    (smoothie--apply-step
                     smoothie--window (car start-move) (car point-move))
                    (redisplay))))))
        (error
         (message "smoothie error: %S" err)
         (smoothie--finish))))))

(defun smoothie--clear-state ()
  "Clear all animation state except the timer."
  (setq smoothie--target-start nil
        smoothie--target-point nil
        smoothie--last-tick-time nil
        smoothie--subline-start 0.0
        smoothie--subline-point 0.0
        smoothie--buffer nil
        smoothie--window nil))

(defun smoothie--finish ()
  "Snap to the target position and stop the timer."
  (let ((window smoothie--window)
        (buffer smoothie--buffer)
        (start smoothie--target-start)
        (point-position smoothie--target-point))
    (when (timerp smoothie--timer)
      (cancel-timer smoothie--timer))
    (setq smoothie--timer nil)
    (smoothie--clear-state)
    (when (and start point-position
               (window-live-p window)
               (buffer-live-p buffer)
               (eq (window-buffer window) buffer))
      (with-selected-window window
        (let ((scroll-margin 0))
          (set-window-start window start t)
          (goto-char point-position)
          (redisplay t))
        (run-hooks 'smoothie-finish-hook)))))

(defun smoothie--cancel ()
  "Cancel an animation without snapping or running finish hooks."
  (when (timerp smoothie--timer)
    (cancel-timer smoothie--timer)
    (setq smoothie--timer nil))
  (smoothie--clear-state))

(defun smoothie-do (command)
  "Execute COMMAND interactively, then animate to its resulting position.
Mirrors vim-smoothie's `smoothie#do': the command is run once to capture the
target view, the view is restored, and a timer animates toward the target."
  (interactive)
  (let* ((window (selected-window))
         (buffer (window-buffer window))
         (same-animation
          (and (timerp smoothie--timer)
               (eq window smoothie--window)
               (eq buffer smoothie--buffer)))
         (orig-start (window-start window))
         (orig-point (window-point window))
         (was-animating same-animation)
         (old-start-line
          (and was-animating
               (with-current-buffer buffer
                 (line-number-at-pos smoothie--target-start))))
         (old-point-line
          (and was-animating
               (with-current-buffer buffer
                 (line-number-at-pos smoothie--target-point))))
         orig-start-line orig-point-line target-start target-point
         target-start-line target-point-line)
    (when (and (timerp smoothie--timer) (not same-animation))
      (smoothie--finish))
    (let ((inhibit-redisplay t))
      (unwind-protect
          (with-selected-window window
            (when was-animating
              (set-window-start window smoothie--target-start t)
              (goto-char smoothie--target-point))
            (let ((smoothie--capturing t))
              (call-interactively command))
            (setq target-start (window-start window)
                  target-point (window-point window)))
        (when (and (window-live-p window)
                   (eq (window-buffer window) buffer))
          (with-selected-window window
            (set-window-start window orig-start t)
            (goto-char orig-point)))))
    (with-current-buffer buffer
      (setq orig-start-line (line-number-at-pos orig-start)
            orig-point-line (line-number-at-pos orig-point)
            target-start-line (line-number-at-pos target-start)
            target-point-line (line-number-at-pos target-point)))
    (setq smoothie--target-start target-start
          smoothie--target-point target-point
          smoothie--buffer buffer
          smoothie--window window)
    (if (and (= target-start-line orig-start-line)
             (= target-point-line orig-point-line))
        (smoothie--finish)
      (when (or (not was-animating)
                (/= (smoothie--sign (- old-start-line orig-start-line))
                    (smoothie--sign (- target-start-line orig-start-line))))
        (setq smoothie--subline-start 0.0))
      (when (or (not was-animating)
                (/= (smoothie--sign (- old-point-line orig-point-line))
                    (smoothie--sign (- target-point-line orig-point-line))))
        (setq smoothie--subline-point 0.0))
      (unless (timerp smoothie--timer)
        (setq smoothie--last-tick-time (float-time)
              smoothie--timer
              (run-with-timer smoothie-update-interval smoothie-update-interval
                              #'smoothie--tick))))))

(provide 'smoothie)
;;; smoothie.el ends here
