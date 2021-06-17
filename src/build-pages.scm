(import (r7rs)
	(scheme time)
	(srfi-13)
	(srfi-19-date)
	(srfi-19-io)

	(chicken port)
	(chicken file)
	(chicken file posix)
	(chicken pathname )
	(chicken irregex)
	(chicken string)
	(regex)
	)

(include "lib/s-expressions/s-markup/library.scm")
(include "lib/s-expressions/s-markup/html/library.scm")
(include "lib/s-expressions/s-markup/xml/library.scm")
(import	(s-expressions s-markup)
	(s-expressions s-markup html)
	(s-expressions s-markup xml)
	)

(include "url-encode.scm")
(include "text-svg.scm")
(include "text-elements.scm")



(define get-title
  (lambda (path)
    (string-append "S-expressions - " (string-titlecase (string-substitute* path '(("-" . " ") ("/" . ": ")))))))


(define project-page? (lambda (path) (string-prefix? "projects/" path)))
(define project-name (lambda (path) (cadr (reverse (string-split path "/")))))
(define project-tab
  (lambda (item . rest )
    (let* ((url-name (url-encode (string-downcase item)))
	   (location (if (> (length rest) 0) (list-ref rest 0) (string-append "/" item)))
	   (aliases (if (> (length rest) 1) (list-ref rest 1) #f))

	   (label (string-titlecase item))
	   ;; (href (string-append "https://www.s-expressions.org" location))
	   (href (string-append "https://www." (project-name location) ".s-expressions.org" "/" url-name))
	   
	   (id (string-append "nav-tab_" item))				 
	   )


      (cond ((string-prefix? location (string-append "/" (current-path)))
	     `(div class: "k-project-tab"
		(div ,label))
	     )

	    ((and aliases
		  (call/cc (lambda (return)
			     (map (lambda (alias)
				    (if (string-prefix? alias (current-path)) (return #t))
				    )
				  aliases)
			     #f))
		  
		  )
	     `(div class: "k-project-tab"
		(a href: ,href (div ,label)))
	     )

	    (else `(a id: ,id class: "k-project-tab" href: ,href
		      
		      (div ,label)
		      ))

	    ))))


(define site-url (lambda () "https://www.s-expressions.org"))


(define time-stamp (let ((time-stamp (number->string (inexact->exact (current-second)))))
			 (lambda () time-stamp)))
(define img-src (lambda (image-name) (string-append (site-url) "/images/" image-name "?" (time-stamp))))




(define pg-ref (lambda (page-name) 
		 (if (project-page? page-name)
		     (string-append "https://www." (project-name page-name) ".s-expressions.org" (substring page-name (+ (string-length "projects/")
															  (string-length (project-name page-name)))
													     (string-length page-name)))
		     (string-append (site-url) "/" page-name))))



(define *current-content*)
(define current-content (lambda () *current-content*))

(define *current-path*)
(define current-path (lambda () *current-path*))

(define get-paths 
  (lambda (dir)
    (apply append (map (lambda (file)
			 (let ((file-path (string-append dir "/" file)))
			   (cond ((directory? file-path) (map (lambda (path)
								(string-append file "/" path))
							      (get-paths file-path)))
				 ((equal? (pathname-extension file) "scm") (list (pathname-file file)))
				 (else '()))))
		       (directory dir)))))

(define page-paths (get-paths "src/www/content"))
;; (define page-paths '("projects/dsl/abstract"))




(define page-template (with-input-from-file "src/www/templates/page.scm" (lambda () (read))))




(define build-page-with-content
  (lambda (path content)

    (let ((output-file (string-append "gen/var/www/htdocs/pages/" path ".html" ))
	  )

      (set! *current-content* content)
      (set! *current-path* path)
      (create-directory (pathname-directory output-file) #t)


      (with-output-to-file output-file (lambda () (display-html (eval page-template)) (newline)))
      ;; ( (lambda () (display-html (eval page-template)) (newline)))


      )))


(define build-page
  (lambda (path)
    (let ((content (with-input-from-file (string-append "src/www/content/" path ".scm") (lambda () (set! *current-path* path) 
											     (eval (read))
											     )))
	  )
      (build-page-with-content path content))))



(define build-pages
  (lambda ()
    (display "building pages...")(newline)
    (map build-page page-paths)
    ))

(build-pages)




(define link-paths (let sort-paths ((remainder (map pg-ref page-paths))
				    (sorted-paths '())
				    )
		     (cond ((null? remainder) sorted-paths)
			   ((null? sorted-paths) (sort-paths (cdr remainder) (list (car remainder))))
			   ((string<=? (car remainder) (car sorted-paths)) (sort-paths (cdr remainder) (cons (car remainder) sorted-paths)))
			   (else (sort-paths (cdr remainder) (cons (car sorted-paths) (sort-paths (list (car remainder)) (cdr sorted-paths))))))))


(display "link-paths: ")(write link-paths)(newline)

(let ((links (cons 'ul (map (lambda (path) `(li (a href: ,path ,path))) link-paths))))
  
  (let ((path "site-map")
	(content `((section (h1 "Site Map") (main id: "k-sitemap" ,links)))))
    (build-page-with-content path content))

  (let ((path "page-not-found")
	(content `((section (h1 "Page Not Found")
			   (main id: "k-sitemap" (p "We were unable to find the page you requested.  "
						    "Please select one of the available links below:")
				 ,links)))))
    (build-page-with-content path content)))



(let* ((lastmod (format-date #f "~Y-~m-~d" (seconds->date (string->number (time-stamp)))))
       (sitemap `((?xml version: "1.0" encoding: "UTF-8")
		  ,(append '(urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9")
			   (map (lambda (path)
				  `(url (loc ,path)
					(lastmod ,lastmod)))
				link-paths)))))

  (with-output-to-file "gen/var/www/htdocs/resources/sitemap.xml" (lambda () (display-xml sitemap))))


