;;; slack-request.el ---slack request function       -*- lexical-binding: t; -*-

;; Copyright (C) 2015  南優也

;; Author: 南優也 <yuyaminami@minamiyuunari-no-MacBook-Pro.local>
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

(require 'json)
(require 'request)

(defvar slack-token)

(defun slack-parse-to-hash ()
  (let ((json-object-type 'hash-table))
    (let ((res (json-read-from-string (buffer-string))))
      res)))

(defun slack-parse-to-plist ()
  (let ((json-object-type 'plist))
    (json-read)))

(defun slack-request-parse-payload (payload)
  (let ((json-object-type 'plist))
    (json-read-from-string payload)))

(cl-defun slack-request (url &key
                             (type "GET")
                             (success)
                             (error nil)
                             (params nil)
                             (parser #'slack-parse-to-plist)
                             (sync t))
  (request
   url
   :type type
   :sync sync
   :params params
   :parser parser
   :success success
   :error error))

(provide 'slack-request)
;;; slack-request.el ends here
