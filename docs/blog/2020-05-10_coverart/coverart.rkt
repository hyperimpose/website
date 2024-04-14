;; Copyright (c) 2020 drastik.org. All rights reserved.

;; BSD 3-Clause license

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;    (1) Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;;
;;    (2) Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in
;;    the documentation and/or other materials provided with the
;;    distribution.
;;
;;    (3)The name of the author may not be used to
;;    endorse or promote products derived from this software without
;;    specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
;; IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
;; INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
;; STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
;; IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;; POSSIBILITY OF SUCH DAMAGE.

#lang racket

(require net/url
         json)

(provide coverart:itunes coverart:itunes:simple
         coverart:lastfm
         coverart:deezer coverart:deezer:simple
         coverart:coverartarchive)
(provide musicbrainz:get-mbid
         coverartarchive:get-cover-url)
(provide coverart:search-thumb)


(define +lastfm:api-key+ "ENTER YOUR Last.fm API KEY")

;;;===================================================================
;;; APIs and services
;;;===================================================================

;;; iTunes

;;--------------------------------------------------------------------
;; @param term : string : The search query
;; @param size : integer : Cover art resolution
;; @param limit : integer : Max number of results returned. (Range 1-200)
;; @param explicit : boolean : Include explicit results
;; @returns '("url") | '()
;;--------------------------------------------------------------------
(define (coverart:itunes term #:size [size 100] #:limit [limit 1]
                         #:explicit [explicit #t])
  (let* ([url (string-append "https://itunes.apple.com/search"
                             "?term=" term
                             "&limit=" (~a limit)
                             "&explicit=" (if explicit "Yes" "No")
                             "&media=music"
                             "&entity=album")]
         [url (string->url url)]
         [json-out (with-handlers ([exn:fail? (lambda (e) (hash))])
                     (call/input-url url get-pure-port read-json))]
         [size-api (string-append (~a size) "x" (~a size))]
         [set-size (lambda (x) (string-replace x "100x100" size-api))])
    ;; The API returns 2 cover art URLs (sized 60x60 and 100x100), but we can
    ;; edit the URLs to get a cover art of any arbitrary size. This however is
    ;; not guaranteed to always work.
    (map (lambda (x) (set-size (hash-ref x 'artworkUrl100 '())))
         (hash-ref json-out 'results))))

;;--------------------------------------------------------------------
;; @param artist : string : The name of the artist
;; @param release : string : The name of the album/single/EP/etc.
;; @see coverart:itunes for more details
;;--------------------------------------------------------------------
(define (coverart:itunes:simple artist release #:size [size 100]
                                #:limit [limit 1] #:explicit [explicit #t])
  (coverart:itunes (string-append release " " artist) #:size size #:limit limit
                   #:explicit explicit))


;;; Last.fm

;;--------------------------------------------------------------------
;; @param artist : string : The name of the artist
;; @param release : string : The name of the album/single/EP/etc.
;; @param size : integer : Cover art resolution
;; @param autocorrect : boolean : Correct misspelled artist names
;; @returns "url"
;;--------------------------------------------------------------------
(define (coverart:lastfm artist release #:size [size 300]
                         #:autocorrect [autocorrect #t])
  (let* ([autocorrect-api (if autocorrect "1" "0")]
         [url (string-append "http://ws.audioscrobbler.com/2.0/"
                             "?method=album.getInfo"
                             "&format=json"
                             "&artist=" artist
                             "&album=" release
                             "&api_key=" +lastfm:api-key+
                             "&autocorrect=" autocorrect-api)]
         [url (string->url url)]
         [json-out (with-handlers ([exn:fail? (lambda (e) (hash))])
                     (call/input-url url get-pure-port read-json))]
         [covers (hash-ref (hash-ref json-out 'album (hash)) 'image '())]
         [cover-url (if (null? covers) "" (hash-ref (car covers) '\#text ""))])
    ;; The API returns 6 covert art URLs. The URLs are the same except from the
    ;; size field. This field has two formats: /Ys/ or /YxY/ where Y is the
    ;; resolution of the image.
    ;; Editing the URL to request a specific resolution results in an image
    ;; whose resolution is >= Y. Using the format /YxY/ usually produces a wider
    ;; range of results.

    ;; The regex used matches the format /Ys/ because this is the first URL in
    ;; the covers list.
    (string-replace cover-url #rx"/[0-9]*s/"
                    (string-append "/" (~a size) "x" (~a size) "/"))))


;;; deezer

;;--------------------------------------------------------------------
;; @param query : string : The search query
;; @param size : integer : Cover art resolution
;; @param limit : integer : Max number of results returned.
;; @returns '("url") | '()
;;--------------------------------------------------------------------
(define (coverart:deezer query #:size [size 1000] #:limit [limit 1])
  (let* ([url (string-append "http://api.deezer.com/search/album"
                             "?q=" query
                             "&nb_items=" (~a limit)
                             "&output=json")]
         [url (string->url url)]
         [json-out (with-handlers ([exn:fail? (lambda (e) (hash))])
                     (call/input-url url get-pure-port read-json))])
    ;; The API returns 4 covert art URLs. The sizes are 56x56, 250x250, 500x500,
    ;; 1000x1000. We use 'cover_xl which is the 1000x1000 size as a default.
    ;; It is possible to edit the URL to have an image of any arbitrary
    ;; resolution.

    ;; "1000x1000-" is used because this is the URL in 'cover_xl
    (map (lambda (x)
           (string-replace (hash-ref x 'cover_xl) "1000x1000-"
                           (string-append (~a size) "x" (~a size) "-")))
         (hash-ref json-out 'data '()))))


;;--------------------------------------------------------------------
;; @param artist : string : The name of the artist
;; @param release : string : The name of the album/single/EP/etc.
;; @see coverart:deezer for more details
;;--------------------------------------------------------------------
(define (coverart:deezer:simple artist release #:size [size 1000]
                                #:limit [limit 1])
  (coverart:deezer (string-append release " " artist)
                   #:size 1000 #:limit limit))


;;; MusicBrainz / Cover Art Archive

;;--------------------------------------------------------------------
;; @doc Get a list of MusicBrainz IDs related to the query given. One
;; id per release group is returned.
;; @param query : string : The term to search for
;; @param group-limit : integer : Max number of release-groups to include
;; @param rel-limit : integer : Max number of releases per group to include
;; @returns '(("mbid")). '((release-group-list) ("release mbid1" ...) ...)
;; The returned list contains one list for every release group. Each release
;; group list contains strings of mbids to specific releases.
;;--------------------------------------------------------------------
(define (musicbrainz:get-mbid query #:group-limit [group-limit 1]
                              #:rel-limit [rel-limit 1])
  (let* ([url (string-append "http://musicbrainz.org/ws/2/release-group/"
                             "?query=" query
                             "&limit=" (~a group-limit)
                             "&fmt=json")]
         [url (string->url url)]
         [json-out (with-handlers ([exn:fail? (lambda (e) (hash))])
                     (call/input-url url get-pure-port read-json))]
         [apply-rel-limit
          (lambda (x) (if (<= (length x) rel-limit) x (take x rel-limit)))])
    (map (lambda (x) (map (lambda (x) (hash-ref x 'id))
                          (apply-rel-limit (hash-ref x 'releases))))
         (hash-ref json-out 'release-groups '()))))


;;--------------------------------------------------------------------
;; @param mbid : string : MusicBrainz ID
;; @param type : symbol : The kind of cover art to download. Available symbols:
;; 'front -> The front part of the cover art
;; 'back -> The rear part of the cover art
;; 'medium -> Picture(s) of the medium itself (CD/Vinyl/Cassette/etc.)
;; 'booklet -> Picture(s) of the booklet included with the release
;; 'all -> Any image provided
;; @param thumb : symbol : If one of the acceptable symbols is provided the
;; thumbnail URL will be returned instead of the original. The original image is
;; NOT enlarged to meet the suggested thumbnail width. Available symbols:
;; '|250| -> 250px max width thumbnail
;; '|500| -> 500px max width thumbnail
;; '|1200| -> 1200px max width thumbnail
;; @returns '("url")
;;--------------------------------------------------------------------
(define (coverartarchive:get-cover-url mbid #:type [type 'front]
                                       #:thumb [thumb #f])
  (let* ([url (string-append "https://coverartarchive.org/release/" mbid)]
         [url (string->url url)]
         [port-settings (lambda (u) (get-pure-port u #:redirections 10))]
         [json-out (with-handlers ([exn:fail? (lambda (e) (hash))])
                     (call/input-url url port-settings read-json))]
         [get-url (lambda (x)
                    (cond [(eq? thumb '|250|)
                           (hash-ref (hash-ref x 'thumbnails) '|250| #f)]
                          [(eq? thumb '|500|)
                           (hash-ref (hash-ref x 'thumbnails) '|500| #f)]
                          [(eq? thumb '|1200|)
                           (hash-ref (hash-ref x 'thumbnails) '|1200| #f)]
                          [else (hash-ref x 'image #f)]))]
         [get-img (lambda (x)
                    (cond [(eq? type 'all) (get-url x)]
                          [(and (eq? type 'front) (hash-ref x 'front))
                           (get-url x)]
                          [(and (eq? type 'back) (hash-ref x 'back))
                           (get-url x)]
                          [(and (eq? type 'medium)
                                (member "Medium" (hash-ref x 'types)))
                           (get-url x)]
                          [(and (eq? type 'booklet)
                                (member "Booklet" (hash-ref x 'types)))
                           (get-url x)]
                          [else #f]))])
    (filter-map get-img (hash-ref json-out 'images '()))))


;;--------------------------------------------------------------------
;; @param artist : string : The name of the artist
;; @param release : string : The name of the album/single/EP/etc.
;; @param group-limit : integer : Max number of release-groups to include
;; @param rel-limit : integer : Max number of releases per group to include
;; @param type : symbol : The kind of cover art to download.
;; See coverartarchive:get-cover-url for details
;; @param thumb : symbol : Thumbnail settings.
;; See coverartarchive:get-cover-url for details
;; @returns '((("url"))). (group (release ("url1" "url2" ...) ...) ...)
;;--------------------------------------------------------------------
(define (coverart:coverartarchive artist release #:group-limit [group-limit 1]
                                  #:rel-limit [rel-limit 1]
                                  #:type [type 'front] #:thumb [thumb #f])
  (let* ([c:gcu (lambda (x)
                  (coverartarchive:get-cover-url x #:type type #:thumb thumb))]
         [empty->false (lambda (x) (if (null? x) #f x))]
         [mbid-covers (lambda (mbid) (empty->false (c:gcu mbid)))])
    (map (lambda (group) (filter-map mbid-covers group))
         (musicbrainz:get-mbid (string-append artist " " release)
                               #:group-limit group-limit
                               #:rel-limit rel-limit))))

;;;===================================================================
;;; Application Functions
;;;===================================================================

;;--------------------------------------------------------------------
;; @doc Search all provided APIs for the front cover of a release.
;; @param artist : string : The name of the artist
;; @param release : string : The name of the album/single/EP/etc.
;; @param size : integer : Cover art resolution. NOTE: Cover Art Archive returns
;; a fixed size of 500px and Last.fm may return a resolution smaller than the
;; requested one.
;; @param fallback : any : Returned if no result is found
;; @returns "url" | fallback
;;--------------------------------------------------------------------
(define (coverart:search-thumb artist album #:size [size 500]
                             #:fallback [fallback ""])
  (let loop ([l (list (lambda ()
                        (coverart:itunes:simple artist album #:size size))
                      (lambda ()
                        (coverart:deezer:simple artist album #:size size))
                      ;; Returns string
                      (lambda () (coverart:lastfm artist album #:size size))
                      (lambda () (flatten (coverart:coverartarchive
                                           artist album #:thumb '|500|))))])
    (if (null? l)
        fallback
        (let ([ret ((car l))])
          (cond [(or (null? ret) (equal? "" ret)) (loop (cdr l))]
                [(list? ret) (car ret)]
                [else ret])))))

