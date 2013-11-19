;;; ztree-diff.el --- Text mode diff for directory trees

;; Copyright (C) 2013 Alexey Veretennikov
;;
;; Author: Alexey Veretennikov <alexey dot veretennikov at gmail dot com>
;; Created: 2013-11-1l
;; Version: 1.0.0
;; Keywords: files
;; URL: https://github.com/fourier/ztree
;; Compatibility: GNU Emacs GNU Emacs 24.x
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:

(require 'ztree-view)
(require 'ztree-diff-model)

(defconst ztree-diff-hidden-files-regexp "^\\."
  "Hidden files regexp. By default all filest starting with dot '.',
including . and ..")

(defface ztreep-diff-header-face
  '((((type tty pc) (class color)) :foreground "lightblue" :weight bold)
    (((background dark)) (:height 1.2 :foreground "lightblue" :weight bold))
    (t :height 1.2 :foreground "darkblue" :weight bold))
  "*Face used for the header in Ztree Diff buffer."
  :group 'Ztree-diff :group 'font-lock-highlighting-faces)
(defvar ztreep-diff-header-face 'ztreep-diff-header-face)

(defface ztreep-diff-header-small-face
  '((((type tty pc) (class color)) :foreground "lightblue" :weight bold)
    (((background dark)) (:foreground "lightblue" :weight bold))
    (t :weight bold :foreground "darkblue"))
  "*Face used for the header in Ztree Diff buffer."
  :group 'Ztree-diff :group 'font-lock-highlighting-faces)
(defvar ztreep-diff-header-small-face 'ztreep-diff-header-small-face)

(defface ztreep-diff-model-diff-face
  '((t                   (:foreground "red")))
  "*Face used for different files in Ztree-diff."
  :group 'Ztree-diff :group 'font-lock-highlighting-faces)
(defvar ztreep-diff-model-diff-face 'ztreep-diff-model-diff-face)

(defface ztreep-diff-model-add-face
  '((t                   (:foreground "blue")))
  "*Face used for added files in Ztree-diff."
  :group 'Ztree-diff :group 'font-lock-highlighting-faces)
(defvar ztreep-diff-model-add-face 'ztreep-diff-model-add-face)

(defface ztreep-diff-model-normal-face
  '((t                   (:foreground "#7f7f7f")))
  "*Face used for non-modified files in Ztree-diff."
  :group 'Ztree-diff :group 'font-lock-highlighting-faces)
(defvar ztreep-diff-model-normal-face 'ztreep-diff-model-normal-face)


(defvar ztreediff-dirs-pair nil
  "Pair of the directories stored. Used to perform the full rescan")
(make-variable-buffer-local 'ztrediff-dirs-par)


;;;###autoload
(define-minor-mode ztreediff-mode
  "A minor mode for displaying the difference of the directory trees in text mode."
  ;; initial value
  nil
  ;; modeline name
  " Diff"
  ;; The minor mode keymap
  `(
    (,(kbd "C") . ztree-diff-copy)
    ([f5] . ztree-diff-full-rescan)))


(defun ztree-diff-node-face (node)
  (let ((diff (ztree-diff-node-different node)))
    (cond ((eq diff 'diff) ztreep-diff-model-diff-face)
          ((eq diff 'new)  ztreep-diff-model-add-face)
          (t ztreep-diff-model-normal-face))))  

(defun ztree-diff-insert-buffer-header ()
  (insert-with-face "Differences tree" ztreep-diff-header-face)
  (newline)
  (insert-with-face"Legend:" ztreep-diff-header-small-face)
  (newline)
  (insert-with-face " Normal file " ztreep-diff-model-normal-face)
  (insert-with-face "- same on both sides" ztreep-diff-header-small-face)
  (newline)
  (insert-with-face " Orphan file " ztreep-diff-model-add-face)
  (insert-with-face "- does not exist on other side" ztreep-diff-header-small-face)
  (newline)
  (insert-with-face " Mismatch file " ztreep-diff-model-diff-face)
  (insert-with-face "- different from other side" ztreep-diff-header-small-face)
  (newline)
  (insert-with-face "==============" ztreep-diff-header-face)
  (newline))

(defun ztree-diff-full-rescan ()
  (interactive)
  (when (and ztreediff-dirs-pair
             (yes-or-no-p (format "Force full rescan?")))
    (ztree-diff (car ztreediff-dirs-pair) (cdr ztreediff-dirs-pair))))


(defun ztree-diff-node-action (node)
  (let ((left (ztree-diff-node-left-path node))
        (right (ztree-diff-node-right-path node)))
    (when (and left right)
      (if (not (ztree-diff-node-different node))
          (message (concat "Files "
                           (ztree-diff-node-short-name node)
                           " on left and right side are identical"))
      (ediff left right)))))

  ;; (let ((parent (ztree-diff-node-parent node)))
  ;;   (when parent
  ;;     (message (ztree-diff-node-short-name parent)))))

(defun ztree-diff-copy ()
  (interactive)
  (let ((found (ztree-find-node-at-point)))
    (when found
      (let* ((node (car found))
             (side (cdr found))
             (node-side (ztree-diff-node-side node))
             (copy-to-right t)           ; copy from left to right
             (node-left (ztree-diff-node-left-path node))
             (node-right (ztree-diff-node-right-path node))
             (source-path nil)
             (destination-path nil)
             (parent (ztree-diff-node-parent node)))
        (when parent
          ;; determine a side to copy from/to
          ;; algorithm:
          ;; 1) if both side are present, use the side
          ;;    variable
          (setq copy-to-right (if (eq node-side 'both)
                                  (eq side 'left)
                                ;; 2) if one of sides is absent, copy from
                                ;;    the side where the file is present
                                (eq node-side 'left)))
          ;; 3) in both cases determine if the destination
          ;;    directory is in place
          (setq source-path (if copy-to-right node-left node-right)
                destination-path (if copy-to-right
                                     (ztree-diff-node-right-path parent)
                                   (ztree-diff-node-left-path parent)))
          (when (and source-path destination-path
                     (yes-or-no-p (format "Copy [%s]%s to [%s]%s/ ?"
                                          (if copy-to-right "LEFT" "RIGHT")
                                          (ztree-diff-node-short-name node)
                                          (if copy-to-right "RIGHT" "LEFT")
                                          destination-path)))
            nil                         ; do copy
            ))))))

          
(defun ztree-diff (dir1 dir2)
  "Creates an interactive buffer with the directory tree of the path given"
  (interactive "DLeft directory \nDRight directory ")
  (let* ((difference (ztree-diff-model-create dir1 dir2))
         (buf-name (concat "*" (ztree-diff-node-short-name difference) "*")))
    (setq ztreediff-dirs-pair (cons dir1 dir2))
    (ztree-view buf-name
                difference
                (list ztree-diff-hidden-files-regexp)
                'ztree-diff-insert-buffer-header
                'ztree-diff-node-short-name
                'ztree-diff-node-is-directory
                'equal
                'ztree-diff-node-children
                'ztree-diff-node-face
                'ztree-diff-node-action
                'ztree-diff-node-side)
    (ztreediff-mode)))


(provide 'ztree-diff)
;;; ztree-diff.el ends here
