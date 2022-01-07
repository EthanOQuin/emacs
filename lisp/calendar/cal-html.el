;;; cal-html.el --- functions for printing HTML calendars  -*- lexical-binding: t; -*-

;; Copyright (C) 2002-2022 Free Software Foundation, Inc.

;; Author: Anna M. Bigatti <bigatti@dima.unige.it>
;; Keywords: calendar
;; Human-Keywords: calendar, diary, HTML
;; Created: 23 Aug 2002
;; Package: calendar

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package writes HTML calendar files using the user's diary
;; file.  See the Emacs manual for details.


;;; Code:

(require 'calendar)
(require 'diary-lib)


(defgroup calendar-html nil
  "Options for HTML calendars."
  :prefix "cal-html-"
  :group 'calendar)

(defcustom cal-html-directory "~/public_html"
  "Directory for HTML pages generated by cal-html."
  :type 'string
  :group 'calendar-html)

(defcustom cal-html-print-day-number-flag nil
  "Non-nil means print the day-of-the-year number in the monthly cal-html page."
  :type 'boolean
  :group 'calendar-html)

(defcustom cal-html-year-index-cols 3
  "Number of columns in the cal-html yearly index page."
  :type 'integer
  :group 'calendar-html)

(defcustom cal-html-day-abbrev-array calendar-day-abbrev-array
  "Array of seven strings for abbreviated day names (starting with Sunday)."
  :set-after '(calendar-day-abbrev-array)
  :type '(vector (string :tag "Sun")
                 (string :tag "Mon")
                 (string :tag "Tue")
                 (string :tag "Wed")
                 (string :tag "Thu")
                 (string :tag "Fri")
                 (string :tag "Sat"))
  :group 'calendar-html)

(defcustom cal-html-holidays t
  "If non-nil, include holidays as well as diary entries."
  :version "24.3"
  :type 'boolean
  :group 'calendar-html)

(defcustom cal-html-css-default
  (concat
   "<STYLE TYPE=\"text/css\">\n"
   "  BODY { background: #bde; }\n"
   "  H1   { text-align: center; }\n"
   "  TABLE  { padding: 2pt; }\n"
   "  TH { background: #dee; }\n"
   "  TABLE.year   { width: 100%; }\n"
   "  TABLE.agenda { width: 100%; }\n"
   "  TABLE.header { width: 100%; text-align: center; }\n"
   "  TABLE.minical TD { background: white; text-align: center; }\n"
   "  TABLE.agenda TD  { background: white; text-align: left; }\n"
   "  TABLE.agenda TH  { text-align: left; width: 20%; }\n"
   "  SPAN.NO-YEAR  { color: #0b3; font-weight: bold; }\n"
   "  SPAN.ANN      { color: #0bb; font-weight: bold; }\n"
   "  SPAN.BLOCK    { color: #048; font-style: italic; }\n"
   "  SPAN.HOLIDAY  { color: #f00; font-weight: bold; }\n"
   "</STYLE>\n\n")
  "Default cal-html css style.  You can override this with a \"cal.css\" file."
  :type 'string
  :version "24.3"                       ; added SPAN.HOLIDAY
  :group 'calendar-html)

;;; End customizable variables.


;;; HTML and CSS code constants.

(defconst cal-html-e-document-string "<BR><BR>\n</BODY>\n</HTML>"
  "HTML code for end of page.")

(defconst cal-html-b-tablerow-string "<TR>\n"
  "HTML code for beginning of table row.")

(defconst cal-html-e-tablerow-string "</TR>\n"
  "HTML code for end of table row.")

(defconst cal-html-b-tabledata-string "  <TD>"
  "HTML code for beginning of table data.")

(defconst cal-html-e-tabledata-string "  </TD>\n"
  "HTML code for end of table data.")

(defconst cal-html-b-tableheader-string "  <TH>"
  "HTML code for beginning of table header.")

(defconst cal-html-e-tableheader-string "  </TH>\n"
  "HTML code for end of table header.")

(defconst cal-html-e-table-string
  "</TABLE>\n<!-- ================================================== -->\n"
  "HTML code for end of table.")

(defconst cal-html-minical-day-format "  <TD><a href=%s#%d>%d</TD>\n"
  "HTML code for a day in the minical - links NUM to month-page#NUM.")

(defconst cal-html-b-document-string
  (concat
   "<HTML>\n"
   "<HEAD>\n"
   "<TITLE>Calendar</TITLE>\n"
   "<!--This buffer was produced by cal-html.el-->\n\n"
   cal-html-css-default
   "<LINK REL=\"stylesheet\" TYPE=\"text/css\" HREF=\"cal.css\">\n"
   "</HEAD>\n\n"
   "<BODY>\n\n")
  "Initial block for html page.")

(defconst cal-html-html-subst-list
  '(("&" . "&amp;")
    ("\n" . "<BR>\n"))
  "Alist of symbols and their HTML replacements.")



(defun cal-html-comment (string)
  "Return STRING as html comment."
  (format "<!--  ======  %s  ======  -->\n"
          (string-replace "--" "++" string)))

(defun cal-html-href (link string)
  "Return a hyperlink to url LINK with text STRING."
  (format "<A HREF=\"%s\">%s</A>" link string))

(defun cal-html-h3 (string)
  "Return STRING as html header h3."
  (format "\n        <H3>%s</H3>\n" string))

(defun cal-html-h1 (string)
  "Return STRING as html header h1."
  (format "\n        <H1>%s</H1>\n" string))

(defun cal-html-th (string)
  "Return STRING as html table header."
  (format "%s%s%s" cal-html-b-tableheader-string string
          cal-html-e-tableheader-string))

(defun cal-html-b-table (arg)
  "Return table tag with attribute ARG."
  (format "\n<TABLE %s>\n" arg))

(defun cal-html-monthpage-name (month year)
  "Return name of html page for numeric MONTH and four-digit YEAR.
For example, \"2006-08.html\" for 8 2006."
  (format "%d-%.2d.html" year month))


(defun cal-html-insert-link-monthpage (month year &optional change-dir)
  "Insert a link to the html page for numeric MONTH and four-digit YEAR.
If optional argument CHANGE-DIR is non-nil and MONTH is 1 or 2,
the link points to a different year and so has a directory part."
  (insert (cal-html-h3
           (cal-html-href
            (concat (and change-dir
                         (member month '(1 12))
                         (format "../%d/" year))
                    (cal-html-monthpage-name month year))
            (calendar-month-name month)))))


(defun cal-html-insert-link-yearpage (month year)
  "Insert a link tagged with MONTH name, to index page for four-digit YEAR."
  (insert (cal-html-h1
           (format "%s %s"
                   (calendar-month-name month)
                   (cal-html-href "index.html" (number-to-string year))))))


(defun cal-html-year-dir-ask-user (year)
  "Prompt for the html calendar output directory for four-digit YEAR.
Return the expanded directory name, which is based on
`cal-html-directory' by default."
  (expand-file-name (read-directory-name
                     "Enter HTML calendar directory name: "
                     (expand-file-name (format "%d" year)
                                       cal-html-directory))))

;;------------------------------------------------------------
;; page header
;;------------------------------------------------------------
(defun cal-html-insert-month-header (month year)
  "Insert the header for the numeric MONTH page for four-digit YEAR.
Contains links to previous and next month and year, and current minical."
  (insert (cal-html-b-table "class=header"))
  (insert cal-html-b-tablerow-string)
  (insert cal-html-b-tabledata-string)          ; month links
  (calendar-increment-month month year -1)      ; previous month
  (cal-html-insert-link-monthpage month year t) ; t --> change-dir
  (calendar-increment-month month year 1)       ; current month
  (cal-html-insert-link-yearpage month year)
  (calendar-increment-month month year 1)       ; next month
  (cal-html-insert-link-monthpage month year t) ; t --> change-dir
  (insert cal-html-e-tabledata-string)
  (insert cal-html-b-tabledata-string)  ; minical
  (calendar-increment-month month year -1)
  (cal-html-insert-minical month year)
  (insert cal-html-e-tabledata-string)
  (insert cal-html-e-tablerow-string)   ; end
  (insert cal-html-e-table-string))

;;------------------------------------------------------------
;; minical: a small month calendar with links
;;------------------------------------------------------------
(autoload 'holiday-in-range "holidays")

(defun cal-html-insert-minical (month year)
  "Insert a minical for numeric MONTH of YEAR."
  (let* ((blank-days                    ; at start of month
          (mod (- (calendar-day-of-week (list month 1 year))
                  calendar-week-start-day)
               7))
         (last (calendar-last-day-of-month month year))
         (end-blank-days                ; at end of month
          (mod (- 6 (- (calendar-day-of-week (list month last year))
                       calendar-week-start-day))
               7))
         (monthpage-name (cal-html-monthpage-name month year))
         ) ;; date
    ;; Start writing table.
    (insert (cal-html-comment "MINICAL")
            (cal-html-b-table "class=minical border=1 align=center"))
    ;; Weekdays row.
    (insert cal-html-b-tablerow-string)
    (dotimes (i 7)
      (insert (cal-html-th
               (aref cal-html-day-abbrev-array
                     (mod (+ i calendar-week-start-day) 7)))))
    (insert cal-html-e-tablerow-string)
    ;; Initial empty slots.
    (insert cal-html-b-tablerow-string)
    (dotimes (_i blank-days)
      (insert
       cal-html-b-tabledata-string
       cal-html-e-tabledata-string))
    ;; Numbers.
    (dotimes (i last)
      (insert (format cal-html-minical-day-format monthpage-name i (1+ i)))
      ;; New row?
      (if (and (zerop (mod (+ i 1 blank-days) 7))
               (/= (1+ i) last))
          (insert cal-html-e-tablerow-string
                  cal-html-b-tablerow-string)))
    ;; End empty slots (for some browsers like konqueror).
    (dotimes (_ end-blank-days)
      (insert
       cal-html-b-tabledata-string
       cal-html-e-tabledata-string)))
  (insert cal-html-e-tablerow-string
          cal-html-e-table-string
          (cal-html-comment "MINICAL end")))


;;------------------------------------------------------------
;; year index page with minicals
;;------------------------------------------------------------
(defun cal-html-insert-year-minicals (year cols)
  "Make a one page yearly mini-calendar for four-digit YEAR.
There are 12/cols rows of COLS months each."
  (insert cal-html-b-document-string)
  (insert (cal-html-h1 (number-to-string year)))
  (insert (cal-html-b-table "class=year")
          cal-html-b-tablerow-string)
  (dotimes (i 12)
    (insert cal-html-b-tabledata-string)
    (cal-html-insert-link-monthpage (1+ i) year)
    (cal-html-insert-minical (1+ i) year)
    (insert cal-html-e-tabledata-string)
    (if (zerop (mod (1+ i) cols))
        (insert cal-html-e-tablerow-string
                cal-html-b-tablerow-string)))
  (insert cal-html-e-tablerow-string
          cal-html-e-table-string
          cal-html-e-document-string))


;;------------------------------------------------------------
;; HTMLify
;;------------------------------------------------------------

(defun cal-html-htmlify-string (string)
  "Protect special characters in STRING from HTML.
Characters are replaced according to `cal-html-html-subst-list'."
  (if (stringp string)
      (replace-regexp-in-string
       (regexp-opt (mapcar 'car cal-html-html-subst-list))
       (lambda (x)
         (cdr (assoc x cal-html-html-subst-list)))
       string)
    ""))


(defun cal-html-htmlify-entry (entry &optional class)
  "Convert a diary entry ENTRY to html with the appropriate class specifier.
Optional argument CLASS is the class specifier to use."
  (let ((start
         (cond
          (class)
          ((string-match "block" (nth 2 entry)) "BLOCK")
          ((string-match "anniversary" (nth 2 entry)) "ANN")
          ((not (string-match
                 (number-to-string (nth 2 (car entry)))
                 (nth 2 entry)))
           "NO-YEAR")
          (t "NORMAL"))))
    (format "<span class=%s>%s</span>" start
            (cal-html-htmlify-string (cadr entry)))))


(defun cal-html-htmlify-list (date-list date &optional holidays)
  "Return a string of concatenated, HTML-ified diary entries.
DATE-LIST is a list of diary entries.  Return only those matching DATE.
Optional argument HOLIDAYS non-nil means the input is actually a list
of holidays, rather than diary entries."
  (mapconcat (lambda (x) (cal-html-htmlify-entry x (if holidays "HOLIDAY")))
             (let (result)
               (dolist (p date-list (reverse result))
                 (and (car p)
                      (calendar-date-equal date (car p))
                      (setq result (cons p result)))))
               "<BR>\n     "))


;;------------------------------------------------------------
;;  Monthly calendar
;;------------------------------------------------------------

(defun cal-html-list-diary-entries (d1 d2)
  "Generate a list of all diary-entries from absolute date D1 to D2."
  (if (with-demoted-errors "Not adding diary entries: %S"
        (diary-check-diary-file))
      (diary-list-entries (calendar-gregorian-from-absolute d1)
                          (1+ (- d2 d1)) t)))

(defun cal-html-insert-agenda-days (month year diary-list holiday-list)
  "Insert HTML commands for a range of days in monthly calendars.
HTML commands are inserted for the days of the numeric MONTH in
four-digit YEAR.  Includes diary entries in DIARY-LIST, and
holidays in HOLIDAY-LIST."
  (let ((blank-days                     ; at start of month
         (mod (- (calendar-day-of-week (list month 1 year))
                 calendar-week-start-day)
              7))
        (last (calendar-last-day-of-month month year))
        date)
    (insert "<a name=0>\n")
    (insert (cal-html-b-table "class=agenda border=1"))
    (dotimes (i last)
      (setq date (list month (1+ i) year))
      (insert
       (format "<a name=%d></a>\n" (1+ i)) ; link
       cal-html-b-tablerow-string
       ;; Number & day name.
       cal-html-b-tableheader-string
       (if cal-html-print-day-number-flag
           (format "<em>%d</em>&nbsp;&nbsp;"
                   (calendar-day-number date))
         "")
       (format "%d&nbsp;%s" (1+ i)
               (aref calendar-day-name-array
                     (calendar-day-of-week date)))
       cal-html-e-tableheader-string
       ;; Diary entries.
       cal-html-b-tabledata-string
       (cal-html-htmlify-list holiday-list date t)
       (if (and holiday-list diary-list) "<BR>\n" "")
       (cal-html-htmlify-list diary-list date)
       cal-html-e-tabledata-string
       cal-html-e-tablerow-string)
      ;; If end of week and not end of month, make new table.
      (if (and (zerop (mod (+ i 1 blank-days) 7))
               (/= (1+ i) last))
          (insert cal-html-e-table-string
                  (cal-html-b-table
                   "class=agenda border=1")))))
  (insert cal-html-e-table-string))


(defun cal-html-one-month (month year dir)
  "Write an HTML calendar file for numeric MONTH of YEAR in directory DIR."
  (let* ((d1 (calendar-absolute-from-gregorian (list month 1 year)))
         (d2 (calendar-absolute-from-gregorian
                      (list month
                            (calendar-last-day-of-month month year)
                            year)))
         (diary-list (cal-html-list-diary-entries d1 d2))
         (holiday-list (if cal-html-holidays (holiday-in-range d1 d2))))
    (with-temp-buffer
      (insert cal-html-b-document-string)
      (cal-html-insert-month-header month year)
      (cal-html-insert-agenda-days month year diary-list holiday-list)
      (insert cal-html-e-document-string)
      (write-file (expand-file-name
                   (cal-html-monthpage-name month year) dir)))))


;;; User commands.

;;;###cal-autoload
(defun cal-html-cursor-month (month year dir &optional _event)
  "Write an HTML calendar file for numeric MONTH of four-digit YEAR.
The output directory DIR is created if necessary.  Interactively,
MONTH and YEAR are taken from the calendar cursor position.
Note that any existing output files are overwritten."
  (interactive (let* ((event last-nonmenu-event)
                      (date (calendar-cursor-to-date t event))
                      (month (calendar-extract-month date))
                      (year (calendar-extract-year date)))
                 (list month year (cal-html-year-dir-ask-user year) event)))
  (make-directory dir t)
  (cal-html-one-month month year dir))

;;;###cal-autoload
(defun cal-html-cursor-year (year dir &optional _event)
  "Write HTML calendar files (index and monthly pages) for four-digit YEAR.
The output directory DIR is created if necessary.  Interactively,
YEAR is taken from the calendar cursor position.
Note that any existing output files are overwritten."
  (interactive (let* ((event last-nonmenu-event)
                      (year (calendar-extract-year
                             (calendar-cursor-to-date t event))))
                 (list year (cal-html-year-dir-ask-user year) event)))
  (make-directory dir t)
  (with-temp-buffer
    (cal-html-insert-year-minicals year cal-html-year-index-cols)
    (write-file (expand-file-name "index.html" dir)))
  (dotimes (i 12)
    (cal-html-one-month (1+ i) year dir)))


(provide 'cal-html)

;;; cal-html.el ends here
