#|
  This file is a part of Caveman package.
  URL: http://github.com/fukamachi/caveman
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  Caveman is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage caveman.app
  (:use :cl
        :clack
        :caveman.middleware.context
        :anaphora)
  (:import-from :clack.util.route
                :match)
  (:import-from :caveman.context
                :*request*
                :*response*)
  (:import-from :caveman.request
                :request-method
                :path-info
                :parameter))
(in-package :caveman.app)

(cl-syntax:use-syntax :annot)

(defparameter *next-route-function* nil
  "A function called when `next-route' is invoked. This will be overwritten in `dispatch-with-rules'.")

@export
(defclass <app> (<component>)
     ((routing-rules :initarg routing-rules :initform nil
                     :accessor routing-rules))
  (:documentation "Base class for Caveman Application. All Caveman Application must inherit this class."))

(defmethod call :around ((this <app>) env)
  (call (wrap
         (make-instance '<caveman-middleware-context>)
         (lambda (env)
           (call-next-method this env)))
        env))

(defmethod call ((this <app>) env)
  "Overriding method. This method will be called for each request."
  @ignore env
  (dispatch-with-rules (reverse (routing-rules this))))

(defun dispatch-with-rules (rules)
  (let* ((req *request*)
         (path-info (path-info req))
         (method (request-method req)))
    (acond
     ((and rules
           (member-rule path-info method rules :allow-head t))
      (destructuring-bind ((_ url-rule fn) &rest other-rules) it
        @ignore _
        (let ((*next-route-function* #'(lambda () (dispatch-with-rules other-rules))))
          (multiple-value-bind (_ params)
              (match url-rule method path-info :allow-head t)
            @ignore _
            (setf (slot-value req 'clack.request::query-parameters)
                  (append
                   params
                   (slot-value req 'clack.request::query-parameters)))
            (funcall fn (parameter req))))))
     (t (not-found)))))

@export
(defmethod add-route ((this <app>) routing-rule)
  "Add a routing rule to the Application."
  (setf (routing-rules this)
        (delete (car routing-rule)
                (routing-rules this)
                :key #'car))
  (push routing-rule
        (routing-rules this)))

@export
(defun next-route ()
  (funcall *next-route-function*))

@export
(defun not-found ()
  "An action when no routing rules are found."
  (setf (clack.response:status *response*) 404)
  nil)

@export
(defmethod lookup-route ((this <app>) symbol)
  "Lookup a routing rule with SYMBOL from the application."
  (loop for rule in (reverse (routing-rules this))
        if (eq (first rule) symbol) do
          (return rule)))

(defun member-rule (path-info method rules &key allow-head)
  (member-if #'(lambda (rule)
                 (match rule method path-info :allow-head allow-head))
             rules
             :key #'cadr))

(doc:start)

@doc:NAME "
Caveman.App - Caveman Application Class.
"

@doc:SYNOPSIS "
    (defclass <myapp-app> (<app>) ())
    (defvar *app* (make-instance '<myapp-app>))
    (call *app*)
"

@doc:DESCRIPTION "
Caveman.App provides a base class `<app>' for Caveman Applications.
"

@doc:AUTHOR "
* Eitarow Fukamachi (e.arrows@gmail.com)
"

@doc:SEE "
* Clack.Component
"
