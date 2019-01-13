;;; objecticon-mode.el --- mode for editing Object Icon code

;; Copyright (C) 1989 Free Software Foundation, Inc.

;; Author: Robert Parlett <parlett@dial.pipex.com>
;;         -very substantially based on icon.el by
;;          Chris Smith <csmith@convex.com>
;; Created: 15 Mar 99
;; Keywords: languages

;; This file is part of XEmacs.

;; XEmacs is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; XEmacs is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;; 02111-1307, USA.

;;; Synched up with: FSF 19.34.

;;; Commentary:

;; A major mode for editing the Object Icon programming language.

;;; Code:

;;; History:
;;; 12-6-99   Fixed handling of variables called end_???, if_??? and else_???
;;;  8-6-08   Converted from unicon to object icon
;;;
(defvar objecticon-mode-abbrev-table nil
  "Abbrev table in use in Object Icon-mode buffers.")
(define-abbrev-table 'objecticon-mode-abbrev-table ())

(defvar objecticon-mode-map ()
  "Keymap used in Object Icon mode.")
(if objecticon-mode-map
    ()
  (setq objecticon-mode-map (make-sparse-keymap))
  (define-key objecticon-mode-map "\r" 'electric-objecticon-terminate-line)
  (define-key objecticon-mode-map "{" 'electric-objecticon-brace)
  (define-key objecticon-mode-map "}" 'electric-objecticon-brace)
  (define-key objecticon-mode-map "\e\C-h" 'mark-objecticon-function)
  (define-key objecticon-mode-map "\e\C-a" 'beginning-of-objecticon-defun)
  (define-key objecticon-mode-map "\e\C-e" 'end-of-objecticon-defun)
  (define-key objecticon-mode-map "\e\C-q" 'indent-objecticon-exp)
  (define-key objecticon-mode-map "\177" 'backward-delete-char-untabify)
  (define-key objecticon-mode-map "\t" 'objecticon-indent-command))

(defvar objecticon-mode-syntax-table nil
  "Syntax table in use in Object Icon-mode buffers.")

(if objecticon-mode-syntax-table
    ()
  (setq objecticon-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\\ "\\" objecticon-mode-syntax-table)
  (modify-syntax-entry ?# "<" objecticon-mode-syntax-table)
  (modify-syntax-entry ?\n ">" objecticon-mode-syntax-table)
  (modify-syntax-entry ?$ "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?/ "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?* "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?+ "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?- "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?= "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?% "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?< "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?> "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?& "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?| "." objecticon-mode-syntax-table)
  (modify-syntax-entry ?\' "\"" objecticon-mode-syntax-table))

(defvar objecticon-indent-use-only-spaces nil
  "*Non-nil means use only spaces when indenting; otherwise use spaces and tabs.")
(defvar objecticon-indent-level 4
  "*Indentation of Object Icon statements with respect to containing block.")
(defvar objecticon-class-indent-level 4
  "*Indentation of methods within classes.")
(defvar objecticon-brace-imaginary-offset 0
  "*Imagined indentation of a Object Icon open brace that actually follows a statement.")
(defvar objecticon-brace-offset -4
  "*Extra indentation for braces, compared with other text in same context.")
(defvar objecticon-continued-statement-offset 4
  "*Extra indent for lines not starting new statements.")
(defvar objecticon-continued-brace-offset 0
  "*Extra indent for substatements that start with open-braces.
This is in addition to objecticon-continued-statement-offset.")

(defvar objecticon-auto-newline nil
  "*Non-nil means automatically newline before and after braces
inserted in Object Icon code.")

(defvar objecticon-electric-newline nil
  "*Non-nil means automatically indent current and new line whenever
return is pressed.")

(defvar objecticon-tab-always-indent t
  "*Non-nil means TAB in Object Icon mode should always reindent the current line,
regardless of where in the line point is when the TAB command is used.")

(defvar objecticon-font-lock-keywords-1
  (list
   ;; Top-level keywords.
   (cons
    (concat "\\_<" (regexp-opt '("procedure" "class" "record" "global" 
                                 "invocable" "import")) "\\_>")
     'font-lock-keyword-face)
   ;; Top-level end or package.  package has to be treated specially since it is
   ;; also a field modifier (which we don't want to highlight).
   (cons
    (concat "^\\_<" (regexp-opt '("end" "package")) "\\_>")
     'font-lock-keyword-face))
  "Subdued level highlighting for Objecticon mode.")

(defvar objecticon-font-lock-keywords-2
  (list
   ;; Fontify all reserved words.
   (cons
    (concat 
     "\\_<" 
     (regexp-opt '("abstract" "break" "by" "case" "class" "const" "create" "default" "do"
                   "else" "end" "every" "fail" "final" "global" "if" "import" "initial"
                   "invocable" "local" "native" "next" "not" "of" "optional" "override"
                   "package" "private" "procedure" "protected" "public" "readable" "record"
                   "repeat" "return" "static" "succeed" "suspend" "then" "to"
                   "until" "while"))
     "\\_>")
    'font-lock-keyword-face)

   ;; Fontify all icon keywords.
   (cons
    (regexp-opt
     '("&ascii" "&break" "&clock" "&cset" "&current" "&date" "&dateline"
       "&digits" "&dump" "&errorcoexpr" "&errornumber" "&errortext" "&errorvalue"
       "&fail" "&features" "&file" "&handler" "&host" "&lcase" "&letters"
       "&level" "&line" "&main" "&maxlevel" "&no" "&null"
       "&pos" "&progname" "&random" "&source" "&subject" "&time"
       "&trace" "&ucase" "&uset" "&version" "&why" "&yes") t)
    'font-lock-constant-face)

   ;; Preprocessor directives
   (cons
    (concat "^"
            (regexp-opt
             '("$define" "$undef" "$if" "$elsif" "$else" "$endif" "$load" "$uload"
               "$include" "$line" "$error" "$encoding") t))
    'font-lock-preprocessor-face))
  "Gaudy level highlighting for Objecticon mode.")

(defvar objecticon-font-lock-keywords objecticon-font-lock-keywords-1
  "Default expressions to highlight in `objecticon-mode'.")

;;;###autoload
(defun objecticon-mode ()
  "Major mode for editing Object Icon code.
Expression and list commands understand all Object Icon brackets.
Tab indents for Object Icon code.
Paragraphs are separated by blank lines only.
Delete converts tabs to spaces as it moves back.
\\{objecticon-mode-map}
Variables controlling indentation style:
 objecticon-tab-always-indent
    Non-nil means TAB in Object Icon mode should always reindent the current line,
    regardless of where in the line point is when the TAB command is used.
 objecticon-auto-newline
    Non-nil means automatically newline before and after braces
    inserted in Object Icon code.
 objecticon-indent-level
    Indentation of Object Icon statements within surrounding block.
    The surrounding block's indentation is the indentation
    of the line on which the open-brace appears.
 objecticon-continued-statement-offset
    Extra indentation given to a substatement, such as the
    then-clause of an if or body of a while.
 objecticon-continued-brace-offset
    Extra indentation given to a brace that starts a substatement.
    This is in addition to `objecticon-continued-statement-offset'.
 objecticon-brace-offset
    Extra indentation for line if it starts with an open brace.
 objecticon-brace-imaginary-offset
    An open brace following other text is treated as if it were
    this far to the right of the start of its line.

Turning on Object Icon mode calls the value of the variable `objecticon-mode-hook'
with no args, if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map objecticon-mode-map)
  (setq major-mode 'objecticon-mode)
  (setq mode-name "Object Icon")
  (setq local-abbrev-table objecticon-mode-abbrev-table)
  (set-syntax-table objecticon-mode-syntax-table)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'objecticon-indent-line)
  (make-local-variable 'require-final-newline)
  (setq require-final-newline t)
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable 'comment-column)
  (setq comment-column 32)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "# *")
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function 'objecticon-comment-indent)
  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'objecticon-fill-paragraph)
  ;; font-lock support
  (setq font-lock-defaults
	'((objecticon-font-lock-keywords
           objecticon-font-lock-keywords-1 objecticon-font-lock-keywords-2)
	  nil nil nil nil))
  (run-hooks 'objecticon-mode-hook))

;; This is used by indent-for-comment to decide how much to
;; indent a comment in Object Icon code based on its context.
(defun objecticon-comment-indent ()
  (if (looking-at "^#")
      0	
    (save-excursion
      (skip-chars-backward " \t")
      (max (if (bolp) 0 (1+ (current-column)))
	   comment-column))))

(defun electric-objecticon-brace (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (let (insertpos)
    (if (and (not arg)
	     (eolp)
	     (or (save-excursion
		   (skip-chars-backward " \t")
		   (bolp))
		 (if objecticon-auto-newline
		     (progn (objecticon-indent-line) (newline) t)
                     nil)))
	(progn
	  (insert last-command-event)
	  (objecticon-indent-line)
	  (if objecticon-auto-newline
	      (progn
		(newline)
		;; (newline) may have done auto-fill
		(setq insertpos (- (point) 2))
		(objecticon-indent-line)))
	  (save-excursion
	    (if insertpos (goto-char (1+ insertpos)))
	    (delete-char -1))))
    (if insertpos
	(save-excursion
	  (goto-char insertpos)
	  (self-insert-command (prefix-numeric-value arg)))
        (self-insert-command (prefix-numeric-value arg)))))

(defun objecticon-indent-command (&optional whole-exp)
  (interactive "P")
  "Indent current line as Object Icon code, or in some cases insert a tab character.
If `objecticon-tab-always-indent' is non-nil (the default), always indent current
line.  Otherwise, indent the current line only if point is at the left margin
or in the line's indentation; otherwise insert a tab.

A numeric argument, regardless of its value, means indent rigidly all the
lines of the expression starting after point so that this line becomes
properly indented.  The relative indentation among the lines of the
expression are preserved."
  (if whole-exp
      ;; If arg, always indent this line as Object Icon
      ;; and shift remaining lines of expression the same amount.
      (let ((shift-amt (objecticon-indent-line))
	    beg end)
	(save-excursion
	  (if objecticon-tab-always-indent
	      (beginning-of-line))
	  (setq beg (point))
	  (forward-sexp 1)
	  (setq end (point))
	  (goto-char beg)
	  (forward-line 1)
	  (setq beg (point)))
	(if (> end beg)
	    (indent-code-rigidly beg end shift-amt "#")))
    (if (and (not objecticon-tab-always-indent)
	     (save-excursion
	       (skip-chars-backward " \t")
	       (not (bolp))))
	(insert-tab)
        (objecticon-indent-line))))

(defun objecticon-indent-line ()
  "Indent current line as Object Icon code.
Return the amount the indentation changed by."
  (let ((indent (calculate-objecticon-indent nil))
	beg shift-amt
	(case-fold-search nil)
	(pos (- (point-max) (point))))
    (beginning-of-line)
    (setq beg (point))
    (cond ((eq indent nil)
	   (setq indent (current-indentation)))
	  ((eq indent t)
	   (setq indent (calculate-objecticon-indent-within-comment)))
	  ((looking-at "[ \t]*#")
	   ())        ;; rpp - was  (setq indent 0))
	  (t
	   (skip-chars-forward " \t")
	   (if (listp indent) (setq indent (car indent)))
	   (cond ((objecticon-looking-at-ident "else")
		  (setq indent (save-excursion
				 (objecticon-backward-to-start-of-if)
				 (current-indentation))))
		 ((objecticon-looking-at-ident "end")
		  (setq indent objecticon-end-indent-level))

		 ((= (following-char) ?})
		  (setq indent (- indent objecticon-indent-level)))

		 ((= (following-char) ?{)
		  (setq indent (+ indent objecticon-brace-offset))))))
    (skip-chars-forward " \t")
    (setq shift-amt (- indent (current-column)))
    (if (zerop shift-amt)
	(if (> (- (point-max) pos) (point))
	    (goto-char (- (point-max) pos)))
      (delete-region beg (point))
      (indent-to-spaces indent)
      ;; If initial point was within line's indentation,
      ;; position after the indentation.  Else stay at same point in text.
      (if (> (- (point-max) pos) (point))
	  (goto-char (- (point-max) pos))))
    shift-amt))

(defun objecticon-forward-ident ()
    (skip-syntax-forward "^w_")
    (skip-syntax-forward "w_"))


(defun objecticon-backward-ident ()
    (skip-syntax-backward "^w_")
    (skip-syntax-backward "w_"))

(defun objecticon-looking-at-ident (x)
  (string= x (buffer-substring 
              (point)
              (save-excursion (skip-syntax-forward "w_") (point)))))

(defconst objecticon-field-starters "\\(public\\|private\\|package\\|protected\\|readable\\|const\\|final\\s-public\\|final\\s-private\\|final\\s-package\\|final\\s-protected\\|static\\s-public\\|static\\s-private\\|static\\s-package\\|static\\s-protected\\|static\\s-readable\\|static\\s-const\\)")

(defconst objecticon-class-starters "\\(\\(final\\s-\\|abstract\\s-\\|package\\s-\\)*class\\)")

(defun calculate-objecticon-indent (&optional parse-start)
  "Return appropriate indentation for current line as Object Icon code.
In usual case returns an integer: the column to indent to.
Returns nil if line starts inside a string, t if in a comment."
  (save-excursion
    (beginning-of-line)
    (let ((indent-point (point))
	  (case-fold-search nil)
	  (line-no (count-lines 1 (point)))
	  containing-sexp-line
	  state
	  containing-sexp)
      (if parse-start
	  (goto-char parse-start)
          (beginning-of-objecticon-defun))

      (while (< (point) indent-point)
	(setq parse-start (point))
	(setq state (parse-partial-sexp (point) indent-point 0))
	(setq containing-sexp (car (cdr state))))

      (cond 
        ((or (nth 3 state) (nth 4 state))
         ;; return nil or t if should not change this line
         (nth 4 state))

        ((and containing-sexp
              (/= (char-after containing-sexp) ?{))
         ;; line is expression, not statement:
         (setq containing-sexp-line (count-lines 1 containing-sexp))
         (if (= line-no containing-sexp-line)
             (goto-char (1+ containing-sexp))
             (progn
               (forward-line -1)
               (beginning-of-line)
               (skip-chars-forward " \t")))
         (current-column))

        (t
         (if objecticon-toplevel
             ;; Outside any procedures.
             (progn (objecticon-backward-to-noncomment (point-min))
                    (if (objecticon-is-continuation-line)
                        (+ objecticon-continued-statement-offset objecticon-extra-indent) 
                        objecticon-extra-indent))

             ;; Statement level.
             (if (null containing-sexp)
                 (progn (beginning-of-objecticon-defun)
                        (setq containing-sexp (point))))
             (goto-char indent-point)
             ;; Is it a continuation or a new statement?
             ;; Find previous non-comment character.
             (objecticon-backward-to-noncomment containing-sexp)
             ;; Now we get the answer.
             (if (objecticon-is-continuation-line)
                 ;; This line is continuation of preceding line's statement;
                 ;; indent  objecticon-continued-statement-offset  more than the
                 ;; first line of the statement.
                 (progn
                   (objecticon-backward-to-start-of-continued-exp containing-sexp)
                   (+ objecticon-continued-statement-offset (current-column)
                      (if (save-excursion (goto-char indent-point)
                                          (skip-chars-forward " \t")
                                          (eq (following-char) ?{))
                          objecticon-continued-brace-offset 0)))

		 ;; This line starts a new statement.
		 ;; Position following last unclosed open.
		 (goto-char containing-sexp)
		 ;; Is line first statement after an open-brace?
		 (or
		  ;; If no, find that first statement and indent like it.
		  (save-excursion
                    (cond
                      ((looking-at (concat "procedure\\s-\\|"
                                           objecticon-field-starters "\\s-"))
                       (search-forward "(")
                       (backward-char 1)
                       (forward-sexp 1))
		      (t
                       (forward-char 1)))

                    (while (progn (skip-chars-forward " \t\n")
				(looking-at "#"))
                      ;; Skip over comments following openbrace.
                      (forward-line 1))

                    ;; The first following code counts
                    ;; if it is before the line we want to indent.
                    (and (< (point) indent-point)
                         (current-column)))
                  
		  ;; If no previous statement,
		  ;; indent it relative to line brace is on.
		  ;; For open brace in column zero, don't let statement
                  ;; start there too.  If objecticon-indent-level is zero,
                  ;; use objecticon-brace-offset + objecticon-continued-statement-offset
                  ;; instead.
                  ;; For open-braces not the first thing in a line,
                  ;; add in objecticon-brace-imaginary-offset.
                  (+ (if (and (bolp) (zerop objecticon-indent-level))
                         (+ objecticon-brace-offset
                            objecticon-continued-statement-offset)
			 objecticon-indent-level)
                     ;; Move back over whitespace before the openbrace.
                     ;; If openbrace is not first nonwhite thing on the line,
                     ;; add the objecticon-brace-imaginary-offset.
                     (progn (skip-chars-backward " \t")
			      (if (bolp) 0 objecticon-brace-imaginary-offset))
                     ;; Get initial indentation of the line we are on.
                     (current-indentation))))))))))

;; List of words to check for as the last thing on a line.
;; If cdr is t, next line is a continuation of the same statement,
;; if cdr is nil, next line starts a new (possibly indented) statement.

(defconst objecticon-resword-alist
  '(("by" . t) ("case" . t) ("create") ("do") ("else")
    ("every" . t) ("if" . t) ("global" . t) ("initial" . t)
    ("local" . t) ("of") ("record" . t) ("repeat" . t)
    ("static" . t) ("then") ("to" . t) ("until" . t) ("while" . t)
    ("const" . t) ("readable" . t) ("public" . t) ("private" . t)
    ("package" . t) ("protected" . t) ("import" . t) ("class" . t) ))

(defun objecticon-is-continuation-line ()
  (let* ((ch (preceding-char))
	 (ch-syntax (char-syntax ch)))
    (if (eq ch-syntax ?w)
	(assoc (buffer-substring
		(progn (objecticon-backward-ident) (point))
		(progn (objecticon-forward-ident) (point)))
	       objecticon-resword-alist)
        (not (memq ch '(0 ?\; ?\} ?\{ ?\) ?\] ?\" ?\' ?\n))))))

(defun objecticon-backward-to-noncomment (lim)
  (let (opoint stop)
    (while (not stop)
      (skip-chars-backward " \t\n\f" lim)
      (setq opoint (point))
      (beginning-of-line)
      (if (and (nth 4 (parse-partial-sexp (point) opoint))
	       (< lim (point)))
	  (search-backward "#")
          (setq stop t)))))

(defun objecticon-backward-to-start-of-continued-exp (lim)
  (if (memq (preceding-char) '(?\) ?\]))
      (forward-sexp -1))
  (beginning-of-line)
  (skip-chars-forward " \t")
  (cond
   ((<= (point) lim) (goto-char (1+ lim)))
   ((not (objecticon-is-continued-line)) 0)
   ((and (eq (char-syntax (following-char)) ?w)
	 (cdr
	  (assoc (buffer-substring (point)
				   (save-excursion (objecticon-forward-ident) (point)))
		 objecticon-resword-alist))) 0)
   (t (end-of-line 0) (objecticon-backward-to-start-of-continued-exp lim))))

(defun objecticon-is-continued-line ()
  (save-excursion
    (end-of-line 0)
    (objecticon-is-continuation-line)))

(defun objecticon-backward-to-start-of-if (&optional limit)
  "Move to the start of the last \"unbalanced\" if."
  (or limit (setq limit (save-excursion (beginning-of-objecticon-defun) (point))))
  (let ((if-level 1)
	(case-fold-search nil))
    (while (not (zerop if-level))
      (backward-sexp 1)
      (cond ((objecticon-looking-at-ident "else")
	     (setq if-level (1+ if-level)))
	    ((objecticon-looking-at-ident "if")
	     (setq if-level (1- if-level)))
	    ((< (point) limit)
	     (setq if-level 0)
	     (goto-char limit))))))

(defun mark-objecticon-function ()
  "Put mark at end of Object Icon function, point at beginning."
  (interactive)
  (push-mark (point))
  (end-of-objecticon-defun)
  (push-mark (point) nil t)
  (beginning-of-line 0)
  (beginning-of-objecticon-defun))

(defun beginning-of-objecticon-defun (&optional arg)
  "Go to the start of the enclosing procedure; return t if at top level."
  (interactive "_p")
  (cond
      ((re-search-backward (concat "^\\s-*\\(package\\s-\\)?procedure\\s-\\|"
                                   "^\\s-+" objecticon-field-starters "\\s-\\|"
                                   "^" objecticon-class-starters "\\s-\\|"
                                   "^\\s-*end\\s-*$") (point-min) 'move)
       (skip-chars-forward " \t")
       (cond
         ((looking-at objecticon-class-starters)
          (setq objecticon-extra-indent objecticon-class-indent-level)
          (setq objecticon-end-indent-level 0)
          (setq objecticon-toplevel t))

         ((looking-at (concat objecticon-field-starters ".*\\s-\\(optional\\|native\\|abstract\\)\\s-"))
          (setq objecticon-extra-indent (current-column))
          (setq objecticon-end-indent-level 0)
          (setq objecticon-toplevel t))

         ((looking-at (concat objecticon-field-starters "\\s-.*\("))
          (setq objecticon-extra-indent (current-column))
          (setq objecticon-end-indent-level (current-column))
          (setq objecticon-toplevel nil))

         ((looking-at (concat objecticon-field-starters "\\s-"))
          (setq objecticon-extra-indent (current-column))
          (setq objecticon-end-indent-level 0)
          (setq objecticon-toplevel t))

         ((looking-at "end")
          (setq objecticon-extra-indent (current-column))
          (setq objecticon-end-indent-level 0)
          (setq objecticon-toplevel t))

         (t
          (setq objecticon-extra-indent (current-column))
          (setq objecticon-end-indent-level (current-column))
          (setq objecticon-toplevel nil))))
      (t
       (setq objecticon-extra-indent 0)
       (setq objecticon-end-indent-level 0)
       (setq objecticon-toplevel t))))

(defun end-of-objecticon-defun (&optional arg)
  (interactive "_p")
  (if (not (bobp)) (forward-char -1))
  (re-search-forward "^\\s-*end\\s-*$" (point-max) 'move)
  (forward-word -1)
  (forward-line 1))

(defun indent-objecticon-exp ()
  "Indent each line of the Object Icon grouping following point."
  (interactive)
  (let ((indent-stack (list nil))
	(contain-stack (list (point)))
	(case-fold-search nil)
	restart outer-loop-done inner-loop-done state ostate
	this-indent last-sexp
	at-else at-brace at-do
	(opoint (point))
	(next-depth 0))
    (save-excursion
      (forward-sexp 1))
    (save-excursion
      (setq outer-loop-done nil)
      (while (and (not (eobp)) (not outer-loop-done))
	(setq last-depth next-depth)
	;; Compute how depth changes over this line
	;; plus enough other lines to get to one that
	;; does not end inside a comment or string.
	;; Meanwhile, do appropriate indentation on comment lines.
	(setq innerloop-done nil)
	(while (and (not innerloop-done)
		    (not (and (eobp) (setq outer-loop-done t))))
	  (setq ostate state)
	  (setq state (parse-partial-sexp (point) (progn (end-of-line) (point))
					  nil nil state))
	  (setq next-depth (car state))
	  (if (and (car (cdr (cdr state)))
		   (>= (car (cdr (cdr state))) 0))
	      (setq last-sexp (car (cdr (cdr state)))))
	  (if (or (nth 4 ostate))
	      (objecticon-indent-line))
	  (if (or (nth 3 state))
	      (forward-line 1)
	    (setq innerloop-done t)))
	(if (<= next-depth 0)
	    (setq outer-loop-done t))
	(if outer-loop-done
	    nil
	  (if (/= last-depth next-depth)
	      (setq last-sexp nil))
	  (while (> last-depth next-depth)
	    (setq indent-stack (cdr indent-stack)
		  contain-stack (cdr contain-stack)
		  last-depth (1- last-depth)))
	  (while (< last-depth next-depth)
	    (setq indent-stack (cons nil indent-stack)
		  contain-stack (cons nil contain-stack)
		  last-depth (1+ last-depth)))
	  (if (null (car contain-stack))
	      (setcar contain-stack (or (car (cdr state))
					(save-excursion (forward-sexp -1)
							(point)))))
	  (forward-line 1)
	  (skip-chars-forward " \t")
	  (if (eolp)
	      nil
	    (if (and (car indent-stack)
		     (>= (car indent-stack) 0))
		;; Line is on an existing nesting level.
		;; Lines inside parens are handled specially.
		(if (/= (char-after (car contain-stack)) ?{)
		    (setq this-indent (car indent-stack))
		  ;; Line is at statement level.
		  ;; Is it a new statement?  Is it an else?
		  ;; Find last non-comment character before this line
		  (save-excursion
		    (setq at-else (looking-at "else\\W"))
		    (setq at-brace (= (following-char) ?{))
		    (objecticon-backward-to-noncomment opoint)
		    (if (objecticon-is-continuation-line)
			;; Preceding line did not end in comma or semi;
			;; indent this line  objecticon-continued-statement-offset
			;; more than previous.
			(progn
			  (objecticon-backward-to-start-of-continued-exp (car contain-stack))
			  (setq this-indent
				(+ objecticon-continued-statement-offset (current-column)
				   (if at-brace objecticon-continued-brace-offset 0))))
		      ;; Preceding line ended in comma or semi;
		      ;; use the standard indent for this level.
		      (if at-else
			  (progn (objecticon-backward-to-start-of-if opoint)
				 (setq this-indent (current-indentation)))
			(setq this-indent (car indent-stack))))))
	      ;; Just started a new nesting level.
	      ;; Compute the standard indent for this level.
	      (let ((val (calculate-objecticon-indent
			   (if (car indent-stack)
			       (- (car indent-stack))))))
		(setcar indent-stack
			(setq this-indent val))))
	    ;; Adjust line indentation according to its contents
	    (if (or (= (following-char) ?})
                    (objecticon-looking-at-ident "end"))
		(setq this-indent (- this-indent objecticon-indent-level)))
	    (if (= (following-char) ?{)
		(setq this-indent (+ this-indent objecticon-brace-offset)))
	    ;; Put chosen indentation into effect.
	    (or (= (current-column) this-indent)
		(progn
		  (delete-region (point) (progn (beginning-of-line) (point)))
		  (indent-to-spaces this-indent)))
	    ;; Indent any comment following the text.
	    (or (looking-at comment-start-skip)
		(if (re-search-forward comment-start-skip (save-excursion (end-of-line) (point)) t)
		    (progn (indent-for-comment) (beginning-of-line))))))))))

(defun indent-to-spaces (n)
  (if objecticon-indent-use-only-spaces
     (while (< (current-column) n)
       (insert " "))
     (indent-to n)))

(defun electric-objecticon-terminate-line ()
  "Terminate line and indent next line."
  (interactive)
  (if objecticon-electric-newline
      (progn
         (save-excursion
	    (objecticon-indent-line))
         (newline)
         ;; Indent next line
         (objecticon-indent-line))
      (newline)))

;; The following fill functions adapted from python mode :-
;; http://courses.csail.mit.edu/6.01/spring08/software/python-mode.el
;;

(defun objecticon-fill-comment (&optional justify)
  "Fill the comment paragraph around point"
  (let (;; Non-nil if the current line contains a comment.
	has-comment

	;; If has-comment, the appropriate fill-prefix for the comment.
	comment-fill-prefix)

    ;; Figure out what kind of comment we are looking at.
    (save-excursion
      (beginning-of-line)
      (cond
        ;; A line with nothing but a comment on it?
        ((looking-at "[ \t]*#[# \t]*")
         (setq has-comment t
               comment-fill-prefix (buffer-substring (match-beginning 0)
                                                     (match-end 0))))

        ;; A line with some code, followed by a comment? Remember that the hash
        ;; which starts the comment shouldn't be part of a string or character.
        ((progn
           (while (not (looking-at "#\\|$"))
             (skip-chars-forward "^#\n\"'\\")
             (cond
               ((eq (char-after (point)) ?\\) (forward-char 2))
               ((memq (char-after (point)) '(?\" ?')) (forward-sexp 1))))
           (looking-at "#+[\t ]*"))
         (setq has-comment t)
         (setq comment-fill-prefix
               (concat (make-string (current-column) ? )
                       (buffer-substring (match-beginning 0) (match-end 0)))))))

    (if (not has-comment)
	(fill-paragraph justify)

        ;; Narrow to include only the comment, and then fill the region.
        (save-restriction
          (narrow-to-region

           ;; Find the first line we should include in the region to fill.
           (save-excursion
             (while (and (zerop (forward-line -1))
                         (looking-at "^[ \t]*#")))

             ;; We may have gone to far.  Go forward again.
             (or (looking-at "^[ \t]*#")
                 (forward-line 1))
             (point))

           ;; Find the beginning of the first line past the region to fill.
           (save-excursion
             (while (progn (forward-line 1)
                           (looking-at "^[ \t]*#")))
             (point)))

          ;; Lines with only hashes on them can be paragraph boundaries.
          (let ((paragraph-start (concat paragraph-start "\\|[ \t#]*$"))
                (paragraph-separate (concat paragraph-separate "\\|[ \t#]*$"))
                (fill-prefix comment-fill-prefix))
            (fill-paragraph justify))))
    t))


(defun objecticon-fill-string (start &optional justify)
  "Fill the paragraph around (point) in the string starting at start"
  ;; basic strategy: narrow to the string and call the default
  ;; implementation
  (let (;; the start of the string's contents
	string-start
	;; the end of the string's contents
	string-end
	;; length of the string's delimiter
	delim-length
	;; The string delimiter
	delim
	)

    (save-excursion
      (goto-char start)
      (if (looking-at "\\('''\\|\"\"\"\\|'\\|\"\\)\\\\?\n?")
	  (setq string-start (match-end 0)
		delim-length (- (match-end 1) (match-beginning 1))
		delim (buffer-substring-no-properties (match-beginning 1)
						      (match-end 1)))
          (error "The parameter start is not the beginning of a python string"))

      ;; if the string is the first token on a line and doesn't start with
      ;; a newline, fill as if the string starts at the beginning of the
      ;; line. this helps with one line docstrings
      (save-excursion
	(beginning-of-line)
	(and (/= (char-before string-start) ?\n)
	     (looking-at (concat "[ \t]*" delim))
	     (setq string-start (point))))

      (forward-sexp (if (= delim-length 3) 2 1))

      ;; with both triple quoted strings and single/double quoted strings
      ;; we're now directly behind the first char of the end delimiter
      ;; (this doesn't work correctly when the triple quoted string
      ;; contains the quote mark itself). The end of the string's contents
      ;; is one less than point
      (setq string-end (1- (point))))

    ;; Narrow to the string's contents and fill the current paragraph
    (save-restriction
      (narrow-to-region string-start string-end)
      (let ((ends-with-newline (= (char-before (point-max)) ?\n)))
	(fill-paragraph justify)
	(if (and (not ends-with-newline)
		 (= (char-before (point-max)) ?\n))
	    ;; the default fill-paragraph implementation has inserted a
	    ;; newline at the end. Remove it again.
	    (save-excursion
	      (goto-char (point-max))
	      (delete-char -1)))))

    ;; return t to indicate that we've done our work
    t))

(defun objecticon-fill-paragraph (&optional justify)
  "Like \\[fill-paragraph], but handle Python comments and strings.
If any of the current line is a comment, fill the comment or the
paragraph of it that point is in, preserving the comment's indentation
and initial `#'s.
If point is inside a string, narrow to that string and fill.
"
  (interactive "P")
  (let* ((bod (objecticon-point 'bod))
	 (pps (parse-partial-sexp bod (point))))
    (cond
      ;; are we inside a comment or on a line with only whitespace before
      ;; the comment start?
      ((or (nth 4 pps)
           (save-excursion (beginning-of-line) (looking-at "[ \t]*#")))
       (objecticon-fill-comment justify))
      ;; are we inside a string?
      ((nth 3 pps)
       (objecticon-fill-string (nth 8 pps)))
      ;; are we at the opening quote of a string, or in the indentation?
      ((save-excursion
         (forward-word 1)
         (eq (objecticon-in-literal) 'string))
       (save-excursion
         (objecticon-fill-string (objecticon-point 'boi))))
      ;; are we at or after the closing quote of a string?
      ((save-excursion
         (backward-word 1)
         (eq (objecticon-in-literal) 'string))
       (save-excursion
         (objecticon-fill-string (objecticon-point 'boi))))
      ;; otherwise use the default
      (t
       (fill-paragraph justify)))))

(defun objecticon-in-literal ()
  "Return non-nil if point is in a Icon literal (a comment or string)."
  ;; This is the version used for non-XEmacs, which has a nicer
  ;; interface.
  ;;
  ;; WARNING: Watch out for infinite recursion.
  (let* ((lim (objecticon-point 'bod))
	 (state (parse-partial-sexp lim (point))))
    (cond
     ((nth 3 state) 'string)
     ((nth 4 state) 'comment)
     (t nil))))
;; XEmacs has a built-in function that should make this much quicker.
(if (fboundp 'buffer-syntactic-context)
    (defalias 'objecticon-in-literal 'buffer-syntactic-context))

(defsubst objecticon-point (position)
  "Returns the value of point at certain commonly referenced POSITIONs.
POSITION can be one of the following symbols:

  bol  -- beginning of line
  eol  -- end of line
  bod  -- beginning of def or class
  eod  -- end of def or class
  bob  -- beginning of buffer
  eob  -- end of buffer
  boi  -- back to indentation

This function does not modify point or mark."
  (let ((here (point)))
    (cond
      ((eq position 'bol) (beginning-of-line))
      ((eq position 'eol) (end-of-line))
      ((eq position 'bod) (beginning-of-objecticon-defun))
      ((eq position 'eod) (end-of-objecticon-defun))
      ((eq position 'bob) (beginning-of-buffer))
      ((eq position 'eob) (end-of-buffer))
      ((eq position 'boi) (back-to-indentation))
      (t (error "Unknown buffer position requested: %s" position))
      )
    (prog1
	(point)
      (goto-char here))))

;;; objecticon-mode.el ends here
