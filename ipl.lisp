;;;; Copyright (c) 2011-2015 Henry Harrington <henry.harrington@gmail.com>
;;;; This code is licensed under the MIT license.

(in-package :cl-user)
#.(with-open-file (in "ipl-configuration.lisp") (read in))

;; Fast eval mode.
(setf sys.int::*eval-hook* 'mezzano.fast-eval:eval-in-lexenv)

;; Host where the initial system is kept.
(mezzano.file-system.remote:add-simple-file-host :remote *file-server-ip*)
(setf *default-pathname-defaults*            *file-server-root-directory*)
(setf mezzano.file-system::*home-directory*  *file-server-home-directory*)

(defun sys.int::snapshot-and-exit ()
  (mezzano.supervisor:make-thread (lambda ()
                                    (dotimes (i 100)
                                      (mezzano.supervisor:wait-for-heartbeat))
                                    (sys.int::gc)
                                    (mezzano.supervisor:snapshot)))
  (throw 'mezzano.supervisor::terminate-thread nil))

(defun sys.int::cal (path)
  "Compile and load PATH.
If the compiled file is out of date, recompile it."
  (let ((compiled (compile-file-pathname path)))
    (when (or (not (probe-file compiled))
              (<= (file-write-date compiled) (file-write-date path)))
      (format t "; Compiling ~S~%" path)
      (ignore-errors (delete-file compiled))
      (compile-file path))
    (format t "; Loading ~S~%" compiled)
    (load compiled)))

(defun sys.int::copy-file (filespec new-name &optional (element-type 'character) (source-external-format :default) (destination-external-format :default))
  (let* ((source (merge-pathnames filespec))
         (dest (merge-pathnames new-name source)))
    (with-open-file (s source :element-type element-type :external-format source-external-format)
      (with-open-file (d dest :direction :output :element-type element-type :external-format destination-external-format)
        (cond ((subtypep element-type 'character)
               ;; FILE-LENGTH cannot be trusted when doing character IO. Go line-by-line.
               (loop
                  (multiple-value-bind (line missing-newline-p)
                      (read-line s nil)
                    (when (not line)
                      (return))
                    (write-string line d)
                    (when (not missing-newline-p)
                      (terpri d)))))
              (t (let ((seq (make-array (file-length s) :element-type element-type)))
                   (read-sequence seq s)
                   (write-sequence seq d))))))
    dest))

;; Local FS.
(sys.int::cal "file/local.lisp")
(eval (read-from-string "(mezzano.file-system.local:add-local-file-host :local)"))

;; Fonts.
(ensure-directories-exist "LOCAL:>Fonts>")
(dolist (f (directory (merge-pathnames "fonts/**/*.ttf" (user-homedir-pathname))))
  (sys.int::copy-file f
             (merge-pathnames "LOCAL:>Fonts>" f)
             '(unsigned-byte 8)))

;; Icons.
(ensure-directories-exist "LOCAL:>Icons>")
(dolist (f (directory "gui/*.png"))
  (sys.int::copy-file f
                      (merge-pathnames "LOCAL:>Icons>" f)
                      '(unsigned-byte 8)))
(dolist (f (directory (merge-pathnames "icons/**/*.png" (user-homedir-pathname))))
  (sys.int::copy-file f
             (merge-pathnames "LOCAL:>Icons>" f)
             '(unsigned-byte 8)))

;; Hold on to your butts...
(ensure-directories-exist "LOCAL:>Licences>")
(dolist (f (directory (merge-pathnames "Licences/*.*" (user-homedir-pathname))))
  (sys.int::copy-file f
                      (merge-pathnames "LOCAL:>Licences>.text" f)
                      'character))

;; Stuff.
(sys.int::copy-file (merge-pathnames "Mandarin_Pair.jpg" (user-homedir-pathname))
                    "LOCAL:>Desktop.jpeg"
                    '(unsigned-byte 8))

(sys.int::copy-file "README"
                    "LOCAL:>README.text")

;; ASDF.
(sys.int::cal (merge-pathnames "source/asdf.lisp" (user-homedir-pathname)))

;; A bunch of GUI related systems.
(require :zpb-ttf)
(require :cl-vectors)
(require :cl-paths-ttf)
;; TCE is required for Chipz's decompressor.
(let ((sys.c::*perform-tce* t))
  (require :chipz))
(require :png-read)
(require :cl-jpeg)

;; And the GUI.
(sys.int::cal "gui/font.lisp")
(sys.int::cal "gui/widgets.lisp")
(sys.int::cal "gui/desktop.lisp")
(sys.int::cal "line-edit-mixin.lisp")
(sys.int::cal "gui/popup-io-stream.lisp")
(sys.int::cal "gui/xterm.lisp")
(sys.int::cal "applications/telnet.lisp")
(sys.int::cal "applications/mandelbrot.lisp")
(sys.int::cal "applications/irc.lisp")
(sys.int::cal "applications/editor.lisp")
(sys.int::cal "applications/peek.lisp")
(sys.int::cal "applications/fancy-repl.lisp")
(sys.int::cal "gui/desktop.lisp")
(sys.int::cal "gui/image-viewer.lisp")
(sys.int::cal "applications/fs-viewer.lisp")
(setf sys.int::*desktop* (eval (read-from-string "(mezzano.gui.desktop:spawn :image \"LOCAL:>Desktop.jpeg\")")))

;; Done.
(eval (read-from-string "(asdf:clear-configuration)"))
(defun lisp-implementation-version ()
  "Demo 1")
(setf mezzano.file-system::*home-directory* (pathname "LOCAL:>")
      *default-pathname-defaults* mezzano.file-system::*home-directory*)
(setf (mezzano.file-system:find-host :remote) nil)
