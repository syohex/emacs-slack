;;; slack-reaction.el ---  deal with reactions       -*- lexical-binding: t; -*-

;; Copyright (C) 2015  yuya.minami

;; Author: yuya.minami <yuya.minami@yuyaminami-no-MacBook-Pro.local>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'eieio)

(defclass slack-reaction ()
  ((name :initarg :name :type string)
   (count :initarg :count :type integer)
   (users :initarg :users :initform ())))

(defmethod join ((r slack-reaction) other)
  (if (string= (oref r name) (oref other name))
      (progn
        (cl-incf (oref r count))
        (oset r users (nconc (oref other users) (oref r users)))
        r)))

(defmethod slack-reaction-equalp ((r slack-reaction) other)
  (string= (oref r name) (oref other name)))

(defmethod slack-reaction-to-string ((r slack-reaction))
  (format ":%s:: %d" (oref r name) (oref r count)))


(provide 'slack-reaction)
;;; slack-reaction.el ends here

