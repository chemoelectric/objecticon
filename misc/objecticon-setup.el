;;; objecticon-setup.el --- setup code for editing Object Icon

(autoload 'objecticon-mode "objecticon-mode")
;; Auto-load modes for .icn, .r and .ri files.
(add-to-list 'auto-mode-alist '("\\.icn\\'" . objecticon-mode))
(add-to-list 'auto-mode-alist '("\\.r\\'" . c-mode))
(add-to-list 'auto-mode-alist '("\\.ri\\'" . c-mode))
;; Ignore .u (ucode) files when completing filenames.
(add-to-list 'completion-ignored-extensions ".u")
;;
;; Set some regular expressions to use with the emacs 'compile'
;; command.  This allows error messages to be clicked on and the
;; relevant file displayed.
(eval-after-load 'compile
  '(progn
    (add-to-list 'compilation-error-regexp-alist-alist 
     '(oit "File \\(.*\\); Line \\([0-9]+\\)" 1 2))
    (add-to-list 'compilation-error-regexp-alist 'oit)
    (add-to-list 'compilation-error-regexp-alist-alist 
     '(oix " \\(from\\|at\\) line \\([0-9]+\\) in \\(.*\\)$" 3 2))
    (add-to-list 'compilation-error-regexp-alist 'oix)))
;; Edit the path so the files can be located.
(setq compilation-search-path
      (append compilation-search-path
              (parse-colon-path (getenv "OI_PATH"))
              (parse-colon-path (getenv "OI_INCL"))))
(provide 'objecticon-setup)
