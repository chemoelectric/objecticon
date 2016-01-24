;;; objecticon-setup.el --- setup code for editing Object Icon

(autoload 'objecticon-mode "objecticon-mode")
(add-to-list 'auto-mode-alist '("\\.icn\\'" . objecticon-mode))
(add-to-list 'auto-mode-alist '("\\.r\\'" . c-mode))
(add-to-list 'auto-mode-alist '("\\.ri\\'" . c-mode))
(add-to-list 'completion-ignored-extensions ".u")
(eval-after-load 'compile
  '(progn
    (add-to-list 'compilation-error-regexp-alist-alist 
     '(oit "File \\(.*\\); Line \\([0-9]+\\)" 1 2))
    (add-to-list 'compilation-error-regexp-alist 'oit)
    (add-to-list 'compilation-error-regexp-alist-alist 
     '(oix " \\(from\\|at\\) line \\([0-9]+\\) in \\(.*\\)$" 3 2))
    (add-to-list 'compilation-error-regexp-alist 'oix)))
(setq compilation-search-path
      (append compilation-search-path
              (parse-colon-path (getenv "OI_PATH"))
              (parse-colon-path (getenv "OI_INCL"))))
(provide 'objecticon-setup)
