;;; syncthing-status.el --- Quickly see sync status of folders and devices on Syncthing -*-lexical-binding:t; -*-

;;; Copyright (C) 2023 Bharadwaj Swaminathan

;;; Author: Bharadwaj Swaminathan
;;; Keywords: syncthing
;;; URL: https://github.com/bharadswami/syncthing-status.el
;;; Package-Requires: (request)

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; This code provides functions to get the sync status of
;; folders and devices on Syncthing.  Run the function
;; (syncthing-status) or bind it to a convenient keybinding
;; to quickly pull up a buffer that shows the sync percentage
;; and the number of files and bytes out of sync.

;;; Code:

(require 'request)

(defgroup syncthing-status syncthing-status ()
  "Show Syncthing status")

(defcustom syncthing-url "http://localhost:8384"
  "URL of Syncthing GUI.  Default is localhost:8384."
  :type '(string)
  :group 'syncthing-status)

(defcustom syncthing-api-key nil
  "Syncthing API key.  Find in GUI under Actions > Settings > General."
  :type '(string)
  :group 'syncthing-status)

(defun bytes-to-human-readable (bytes)
  "Convert the given number of BYTES to a human-friendly format."
  (let ((units '("B" "KiB" "MiB" "GiB"))
        (size bytes))
    (while (and (>= size 1024) (cdr units))
      (setq size (/ size 1024.0)
            units (cdr units)))
    (format "%.2f %s" size (car units))))

(defun get-sync-status-of-element (id folderp &optional name)
  "Get the syncthing status of item ID.
Set FOLDERP to t if ID refers to a folder,
otherwise it is assumed as a device id.
Optional parameter NAME to easily identify element."
(request (url-encode-url (format "%s/rest/db/completion?%s=%s" syncthing-url (if folderp "folder" "device") id))
  :sync t
  :headers `(("X-API-KEY" . ,api-key))
  :parser 'json-read
  :complete (cl-function (lambda (&key data &allow-other-keys)
               (with-current-buffer (get-buffer-create "*syncthing-status*")
                 (insert (format "%s: %g%% synced%s\n"
				 (propertize (or name id) 'face 'bold)
				 (assoc-default 'completion data)
				 (let ((out-sync-items-num (assoc-default 'needItems data))
				       (out-of-sync-bytes (assoc-default 'needBytes data)))
				   (if (> out-sync-items-num 0)
				       (format (propertize " (%d items, %s out of sync)" 'face '(:foreground "#dd3333"))
					       out-sync-items-num
					       (bytes-to-human-readable out-of-sync-bytes))
				     " ✅")))))))))

(defun syncthing-status ()
   "Get syncthing sync status of all folders and devices."
   (interactive)
   (with-current-buffer (get-buffer-create "*syncthing-status*")
     (erase-buffer)
     ;; Add syncthing logo
     (request (url-encode-url (format "%s/assets/img/logo-horizontal.svg" syncthing-url))
       :timeout 5
       :sync t
       :error (cl-function (lambda (&rest args &allow-other-keys)
			     (insert "+-----------------------+\n| Syncthing sync status |\n+-----------------------+\n")))
       :success (cl-function (lambda (&key data &allow-other-keys)
			       (insert-image (create-image data nil 1))
			       (insert "\n"))))

     (insert (format "\n%s:\n" (propertize "Folders" 'face 'underline))))

  ;; Get sync status of all folders
  (request (url-encode-url (format "%s/rest/config/folders" syncthing-url))
    :sync t
    :headers `(("X-API-KEY" . ,api-key))
    :parser 'json-read
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (dotimes (fol (length data))
                  (let ((folderid (assoc-default 'id (aref data fol)))
                        (foldername (assoc-default 'label (aref data fol))))
                    (get-sync-status-of-element folderid 1 foldername))))))

  (with-current-buffer (get-buffer-create "*syncthing-status*")
    (insert (format "\n%s:\n" (propertize "Devices" 'face 'underline))))

  ;; Get sync status of all devices
  (request (url-encode-url (format "%s/rest/config/devices" syncthing-url))
    :sync t
    :headers `(("X-API-KEY" . ,api-key))
    :parser 'json-read
    :success (cl-function (lambda (&key data &allow-other-keys)
			    (dotimes (dev (length data))
			      (let ((deviceid (assoc-default 'deviceID (aref data dev)))
				    (devicename (assoc-default 'name (aref data dev))))
				(get-sync-status-of-element deviceid nil devicename)
                     )))))
  (pop-to-buffer "*syncthing-status*"))

(provide 'syncthing-status)

;;; syncthing-status.el ends here
