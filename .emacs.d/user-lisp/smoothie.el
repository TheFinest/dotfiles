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
(defvar smoothie-update-interval 0.02
  "Seconds between animation frames. Lower = smoother (more redraws).")
(defvar smoothie-speed-constant-factor 10.0
  "Constant term of the velocity curve (boosts speed near the end).")
(defvar smoothie-speed-linear-factor 10.0
  "Linear term of the velocity curve (boosts speed at the start).")
(defvar smoothie-speed-exponentiation-factor 0.9
  "Exponent on distance. <=1.0; lower = longer, smoother animation.")

;; --- Internal state ---------------------------------------------------------
(defvar smoothie--timer nil)
(defvar smoothie--target-start nil)
(defvar smoothie--target-point nil)
(defvar smoothie--target-start-line nil)
(defvar smoothie--target-point-line nil)
(defvar smoothie--current-start-line nil)
(defvar smoothie--current-point-line nil)
(defvar smoothie--subline-start 0.0)
(defvar smoothie--subline-point 0.0)
(defvar smoothie--buffer nil)
(defvar smoothie--window nil)

;; Hook for front-end integration. Run in the context of
;; `smoothie--buffer' / `smoothie--window'.
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
        (let ((cur-start-line (or smoothie--current-start-line
                                  (line-number-at-pos (window-start))))
              (cur-point-line (or smoothie--current-point-line
                                  (line-number-at-pos (point)))))
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
                  (setq smoothie--current-start-line (+ cur-start-line (car s))
                        smoothie--current-point-line (+ cur-point-line (car p)))
                  (redisplay)))))))
    (error
     (message "smoothie error: %S" err)
     (smoothie--finish))))

(defun smoothie--finish ()
  "Snap to the target position and stop the timer."
  (when (timerp smoothie--timer)
    (cancel-timer smoothie--timer)
    (setq smoothie--timer nil))
  (when (and smoothie--target-start smoothie--target-point
             (eq (current-buffer) smoothie--buffer)
             (eq (selected-window) smoothie--window))
    (let ((scroll-margin 0))
      (set-window-start nil smoothie--target-start t)
      (goto-char smoothie--target-point)
      (redisplay t))
    ;; Let front-ends refresh transient UI now that the view has settled.
    (run-hooks 'smoothie-finish-hook))
  (setq smoothie--target-start nil
        smoothie--target-point nil
        smoothie--target-start-line nil
        smoothie--target-point-line nil
        smoothie--current-start-line nil
        smoothie--current-point-line nil
        smoothie--subline-start 0.0
        smoothie--subline-point 0.0))

(defun smoothie--cancel ()
  "Cancel any running animation without snapping or running finish hooks.
Used when a new command supersedes an in-progress animation: the previous
animation's target is irrelevant, so we just tear down its state cleanly
without firing `smoothie-finish-hook' (which would e.g. pulse the wrong
match at the wrong time)."
  (when (timerp smoothie--timer)
    (cancel-timer smoothie--timer)
    (setq smoothie--timer nil))
  (setq smoothie--target-start nil
        smoothie--target-point nil
        smoothie--target-start-line nil
        smoothie--target-point-line nil
        smoothie--current-start-line nil
        smoothie--current-point-line nil
        smoothie--subline-start 0.0
        smoothie--subline-point 0.0))

(defun smoothie-do (command)
  "Execute COMMAND interactively, then animate to its resulting position.
Mirrors vim-smoothie's `smoothie#do': the command is run once to capture the
target view, the view is restored, and a timer animates toward the target."
  (interactive)
  (let ((orig-start (window-start))
        (orig-point (point))
        target-start target-point
        target-start-line target-point-line
        (old-target-start-line smoothie--target-start-line)
        (old-target-point-line smoothie--target-point-line)
        (was-animating nil))
    (when (and (timerp smoothie--timer)
               (or (not (eq (current-buffer) smoothie--buffer))
                   (not (eq (selected-window) smoothie--window))))
      (smoothie--cancel))
    (setq was-animating (timerp smoothie--timer))
    (let ((inhibit-redisplay t)
          (smoothie--capturing t))
      (condition-case err
          (call-interactively command)
        (error (message "smoothie-do: %S" err)))
      (setq target-start (window-start)
            target-point (point)
            target-start-line (line-number-at-pos target-start)
            target-point-line (line-number-at-pos target-point))
      (set-window-start nil orig-start t)
      (goto-char orig-point))
    (cond
     ((and (= target-start orig-start) (= target-point orig-point))
      ;; Nothing to animate; re-run for real so side effects (search, etc.) land.
      (when was-animating
        (smoothie--cancel))
      (let ((inhibit-redisplay nil))
        (call-interactively command)))
     ((and (= target-start-line (line-number-at-pos orig-start))
            (= target-point-line (line-number-at-pos orig-point)))
       ;; Same lines but cursor/window moved within line: snap to exact positions.
       (let ((scroll-margin 0))
         (set-window-start nil target-start t)
         (goto-char target-point)
         (redisplay t))
      ;; Flash was suppressed during capture; re-establish it now.
       (when was-animating
         (smoothie--cancel))
       (run-hooks 'smoothie-finish-hook))
      (t
      (setq smoothie--target-start target-start
            smoothie--target-point target-point
            smoothie--target-start-line target-start-line
            smoothie--target-point-line target-point-line
            smoothie--buffer (current-buffer)
            smoothie--window (selected-window))
      ;; Keep an existing timer alive when another scroll command arrives.
      ;; This makes held/repeated C-u/C-d input retarget the current animation
      ;; instead of repeatedly starting from rest.
      (when (or (not was-animating)
                (and old-target-start-line
                     (/= (smoothie--sign (- old-target-start-line (line-number-at-pos orig-start)))
                         (smoothie--sign (- target-start-line (line-number-at-pos orig-start))))))
        (setq smoothie--subline-start 0.0))
      (when (or (not was-animating)
                (and old-target-point-line
                     (/= (smoothie--sign (- old-target-point-line (line-number-at-pos orig-point)))
                         (smoothie--sign (- target-point-line (line-number-at-pos orig-point))))))
        (setq smoothie--subline-point 0.0))
      (unless was-animating
        (setq smoothie--current-start-line (line-number-at-pos orig-start)
              smoothie--current-point-line (line-number-at-pos orig-point)))
      (unless (timerp smoothie--timer)
        (setq smoothie--timer
              (run-with-timer smoothie-update-interval smoothie-update-interval
                              #'smoothie--tick)))))))

(provide 'smoothie)
;;; smoothie.el ends here
