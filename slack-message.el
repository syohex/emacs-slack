;;; slack-message.el --- slack-message                -*- lexical-binding: t; -*-

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
(require 'slack-util)
(require 'slack-buffer)
(require 'slack-reaction)

(defvar slack-groups)
(defvar slack-ims)
(defvar slack-channels)

(defclass slack-message ()
  ((type :initarg :type :type string)
   (room :initarg :room :initform nil)
   (subtype :initarg :subtype)
   (channel :initarg :channel :initform nil)
   (ts :initarg :ts :type string)
   (text :initarg :text)
   (item-type :initarg :item_type)
   (attachments :initarg :attachments :type (or null list))
   (reactions :initarg :reactions :type (or null list))
   (is-starred :initarg :is_starred :type boolean)
   (pinned-to :initarg :pinned_to :type (or null list))
   (edited-at :initarg :edited-at :initform nil)))

(defclass slack-file-message (slack-message)
  ((file :initarg :file)
   ;; (bot-id :initarg :bot_id :type (or null string))
   ;; (username :initarg :username)
   ;; (display-as-bot :initarg :display_as_bot)
   (upload :initarg :upload)
   (user :initarg :user)))

(defclass slack-file ()
  ((id :initarg :id)
   (created :initarg :created)
   (timestamp :initarg :timestamp)
   (name :initarg :name)
   (size :initarg :size)
   (public :initarg :public)
   (url :initarg :url)
   (url-download :initarg :url_download)
   (url-private :initarg :url_private)
   (channels :initarg :channels :type list)
   (groups :initarg :groups :type list)
   (ims :initarg :ims :type list)
   (reactions :initarg :reactions :type list)
   (username :initarg :username)
   (bot-id :initarg :bot_id)
   (ts :initarg :ts :type string)))

(defclass slack-reply (slack-message)
  ((user :initarg :user :initform nil)
   (reply-to :initarg :reply_to :type integer)
   (id :initarg :id :type integer)))

(defclass slack-user-message (slack-message)
  ((user :initarg :user :type string)
   (edited :initarg :edited)
   (id :initarg :id)
   (inviter :initarg :inviter)))

(defclass slack-bot-message (slack-message)
  ((bot-id :initarg :bot_id :type string)
   (username :initarg :username)
   (icons :initarg :icons)))

(defclass slack-attachment ()
  ((fallback :initarg :fallback :type string)
   (title :initarg :title :initform nil)
   (title-link :initarg :title_link :initform nil)
   (pretext :initarg :pretext :initform nil)
   (text :initarg :text :initform nil)
   (author-name :initarg :author_name)
   (author-link :initarg :author_link)
   (author-icon :initarg :author_icon)
   (fields :initarg :fields :type (or null list))
   (image-url :initarg :image_url)
   (thumb-url :initarg :thumb_url)))

(cl-defgeneric slack-message-sender-name  (slack-message))
(cl-defgeneric slack-message-to-string (slack-message))
(cl-defgeneric slack-message-to-alert (slack-message))
(cl-defgeneric slack-message-notify-buffer (slack-message))

(cl-defgeneric slack-room-buffer-name (room))
(cl-defgeneric slack-room-update-messages (room))

(defun slack-room-find (id)
  (cl-labels ((find-room (room)
                         (string= id (oref room id))))
    (cond
     ((string-prefix-p "C" id) (cl-find-if #'find-room slack-channels))
     ((string-prefix-p "G" id) (cl-find-if #'find-room slack-groups))
     ((string-prefix-p "D" id) (cl-find-if #'find-room slack-ims)))))

(defun slack-reaction-create (payload)
  (apply #'slack-reaction "reaction"
         (slack-collect-slots 'slack-reaction payload)))

(defmethod slack-message-set-reactions ((m slack-message) payload)
  (let ((reactions (plist-get payload :reactions)))
    (if (< 0 (length reactions))
        (oset m reactions (mapcar #'slack-reaction-create reactions))))
  m)

(defun slack-attachment-create (payload)
  (plist-put payload :fields
             (append (plist-get payload :fields) nil))
  (apply #'slack-attachment "attachment"
         (slack-collect-slots 'slack-attachment payload)))

(defmethod slack-message-set-attachments ((m slack-message) payload)
  (let ((attachments (plist-get payload :attachments)))
    (if (< 0 (length attachments))
        (oset m attachments
              (mapcar #'slack-attachment-create attachments))))
  m)

(cl-defun slack-message-create (payload &key room)
  (plist-put payload :reactions (append (plist-get payload :reactions) nil))
  (plist-put payload :attachments (append (plist-get payload :attachments) nil))
  (plist-put payload :pinned_to (append (plist-get payload :pinned_to) nil))
  (plist-put payload :room room)
  (cl-labels ((create (m)
                      (let ((subtype (plist-get m :subtype)))
                        (cond
                         ((plist-member m :reply_to)
                          (apply #'slack-reply "reply"
                                 (slack-collect-slots 'slack-reply m)))
                         ((and subtype (string-prefix-p "file" subtype))
                          (apply #'slack-file-message "file-msg"
                                 (slack-collect-slots 'slack-file-message m)))
                         ((and subtype (string= "message_changed" subtype))
                          (slack-message-edited m))
                         ((plist-member m :user)
                          (apply #'slack-user-message "user-msg"
                                 (slack-collect-slots 'slack-user-message m)))
                         ((plist-member m :bot_id)
                          (apply #'slack-bot-message "bot-msg"
                                 (slack-collect-slots 'slack-bot-message m)))))))
    (let ((message (create payload)))
      (when message
        (slack-message-set-attachments message payload)
        (slack-message-set-reactions message payload)))))

(defun slack-message-set (room messages)
  (let ((messages (mapcar #'slack-message-create messages)))
    (puthash "messages" messages room)))

(defmethod slack-message-equal ((m slack-message) n)
  (and (string= (oref m ts) (oref n ts))
       (string= (oref m text) (oref n text))))

(cl-defmethod slack-message-update ((m slack-message) &key replace)
  (with-slots (room channel) m
    (let ((room (or room (slack-room-find channel))))
      (when room
        (slack-room-update-messages room m)
        (slack-buffer-update room
                             m
                             :replace replace)
        (slack-message-notify-buffer m room)
        (slack-message-notify-alert m room)))))

(defun slack-message-edited (payload)
  (let* ((edited-message (plist-get payload :message))
         (room (slack-room-find (plist-get payload :channel)))
         (message (slack-room-find-message room
                                           (plist-get edited-message :ts)))
         (edited-info (plist-get edited-message :edited)))
    (if message
        (progn
          (oset message text (plist-get edited-message :text))
          (oset message edited-at (plist-get edited-info :ts))
          (slack-message-update message :replace t)))))

(defmethod slack-message-sender-name ((m slack-message))
  (slack-user-name (oref m user)))

(provide 'slack-message)
;;; slack-message.el ends here
