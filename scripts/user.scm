;; TuiGram user scripts — Chicken Scheme
;;
;; Здесь живут хоткеи, макросы и фильтры.
;; Всё это дело выполняется прямо в рантайме клиента.

;; --- пример: приветствие при старте ---
(define (on-boot)
  (display "TuiGram scheme layer loaded\n"))

;; --- пример: хоткей g → перейти вверх по списку чатов ---
;; (define-key normal-mode "g" (lambda () (chat-up)))

;; --- пример: фильтр, прячущий каналы с пометкой «噪音» ---
;; (define (hide-noisy? chat)
;;   (string-contains (chat-title chat) "噪音"))

(on-boot)
