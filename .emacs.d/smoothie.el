;;; smoothie.el --- Inertia-based smooth scrolling (elisp port of vim-smoothie) -*- lexical-binding: t; -*-

;; Recreates the velocity curve of vim-smoothie:
;;   velocity = sign(d) * (constant + linear * |d|^exponent)
;; which produces fast-then-easing-out (inertia) movement toward the target.

(require 'evil)

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
(defvar smoothie--subline-start 0.0)
(defvar smoothie--subline-point 0.0)
(defvar smoothie--last-time nil)
(defvar smoothie--buffer nil)
(defvar smoothie--window nil)

;; --- Core animation engine ---------------------------------------------------
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
  (when (and smoothie--target-start smoothie--target-point
             (eq (current-buffer) smoothie--buffer)
             (eq (selected-window) smoothie--window))
    (let ((scroll-margin 0))
      (set-window-start nil smoothie--target-start t)
      (goto-char smoothie--target-point)
      (redisplay t)))
  (setq smoothie--target-start nil
        smoothie--target-point nil
        smoothie--target-start-line nil
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
        target-start target-point
        target-start-line target-point-line)
    (let ((inhibit-redisplay t))
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
      (let ((inhibit-redisplay nil))
        (call-interactively command)))
     ((and (= target-start-line (line-number-at-pos orig-start))
           (= target-point-line (line-number-at-pos orig-point)))
      ;; Same lines but cursor/window moved within line: snap to exact positions.
      (let ((scroll-margin 0))
        (set-window-start nil target-start t)
        (goto-char target-point)
        (redisplay t)))
     (t
      (setq smoothie--target-start target-start
            smoothie--target-point target-point
            smoothie--target-start-line target-start-line
            smoothie--target-point-line target-point-line
            smoothie--subline-start 0.0
            smoothie--subline-point 0.0
            smoothie--buffer (current-buffer)
            smoothie--window (selected-window)
            smoothie--last-time (float-time))
      (setq smoothie--timer
            (run-with-timer smoothie-update-interval smoothie-update-interval
                            #'smoothie--tick))))))

;; --- Wrapper commands (match your .vimrc: scroll then `zz` center) -----------
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

;; --- Key bindings (Evil paging keys; prefix arg / count preserved) ----------
(with-eval-after-load 'evil
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
                  (smoothie-do #'my/smoothie-search-previous)))))

(provide 'smoothie)
;;; smoothie.el ends here
