(use-modules (minecraft))
(use-modules (minecraft base))
(use-modules (minecraft tick))
(use-modules (minecraft dbus))
(use-modules (minecraft chat))
(use-modules (minecraft form))
(use-modules (minecraft command))
(use-modules (minecraft transfer))
(use-modules (system repl coop-server))
(use-modules (json))
(use-modules (megacut))
(use-modules (sqlite3))

(use-modules (ice-9 match))

(log-trace "test" "default spawn point: ~a" (world-spawnpoint))

(log-debug "uuid"
           (uuid->string (uuid "107d46e0-4d59-4e51-97ab-6585fe429d94")))

(add-hook! player-joined
           #%(let [(pname (actor-name %))]
                   (log-debug "player-joined" "~a ~a ~a" pname (uuid->string (player-uuid %)) (player-xuid %))
                   (for-each-player! other (send-message other (format #f "~a joined." pname)))))

(add-hook! player-left
           #%(let [(pname (actor-name %))]
                   (log-debug "player-left" "~a ~a ~a" pname (uuid->string (player-uuid %)) (player-xuid %))
                   (for-each-player! other (send-message other (format #f "~a left." pname)))))

(add-hook! player-login
           #%(log-debug "player-login" (uuid->string %)))

(add-hook! player-chat
           #%(let [(pname (actor-name %1))]
                   (for-each-player! other (send-message other (format #f "~a: ~a" pname %2)))
                   (log-info "chat" "~a: ~a" pname %2)
                   (cancel-chat #t)))

(add-hook! server-exec
           #%(cond ((string-prefix? "/" %) (exec-result #f))
                   (else (for-each-player! player (send-message player (format #f "server: ~a" %)))
                         (log-info "chat" "server: ~a" %)
                         (exec-result ""))))

(delay-run! 5 (log-debug "delay" "test 5"))
(delay-run! 7 (log-debug "delay" "test 7"))

(interval-run! 20 (for-each-player! player (send-message player (apply format #f "ping: ~ams(avg ~ams) loss: ~1,2f(avg ~1,2f)" (player-stats player)) 5)))

(register-dbus-interface ""
                         "one.codehz.bedrockserver.test"
                         (megacut (define-dbus-signal % 0 "test_signal" "s")
                                  (define-dbus-method % 0 "test_method" "s" "s"
                                                      (λ (m u e)
                                                         (let [(data (dbus-read m #\s))]
                                                              (dbus-reply m "s" data))))))

(reg-simple-command "script"
                    "Custom command from script"
                    0
                    #%(outp-success "Hello guile!"))

(reg-command "message"
             "Custom command for testing message"
             0
             (list (command-vtable (list (parameter-optional parameter-message "test")) #%(outp-success (format #f "You typed ~a" (command-args))))))

(reg-command "select"
             "Custom command for testing selector"
             0
             (list (command-vtable (list (parameter-optional parameter-selector "sth")) #%(outp-success (format #f "Selected ~a" (command-args))))))

(reg-command "string"
             "Custom command for testing string"
             0
             (list (command-vtable (list (parameter-optional parameter-string "test")) #%(outp-success (format #f "String ~a" (command-args))))))

(reg-command "text"
             "Custom command for testing text"
             0
             (list (command-vtable (list (parameter-optional parameter-text "test")) #%(outp-success (format #f "Text ~a" (command-args))))))

(reg-command "int"
             "Custom command for testing int"
             0
             (list (command-vtable (list (parameter-optional parameter-int "test")) #%(outp-success (format #f "Integer ~a" (command-args))))))

(reg-command "float"
             "Custom command for testing float"
             0
             (list (command-vtable (list (parameter-optional parameter-float "test")) #%(outp-success (format #f "Float ~a" (command-args))))))

(reg-command "bool"
             "Custom command for testing boolean"
             0
             (list (command-vtable (list (parameter-optional parameter-bool "test")) #%(outp-success (format #f "Boolean ~a" (command-args))))))

(reg-command "position"
             "Custom command for testing position"
             0
             (list (command-vtable (list (parameter-optional parameter-position "test")) #%(outp-success (format #f "Pos ~a" (command-args))))))

(reg-command "multiple"
             "Custom command for testing multiple parameters"
             0
             (list (command-vtable (list (parameter-position "pos") (parameter-selector "sel") (parameter-text "text"))
                                 #%(outp-success (format #f "Multiple parameters ~a" (command-args))))
                   (command-vtable (list (parameter-selector "sel") (parameter-text "text"))
                                 #%(outp-success (format #f "Multiple parameters ~a" (command-args))))))

(defmacro checked-player! (name . body)
         `(lambda () (let [(,name (orig-player))]
                           (if (not ,name)
                               (outp-error "Only available for player")
                               (begin ,@body)))))

(reg-simple-command "home"
                    "Teleport to spawnpoint"
                    0
                    (checked-player! player
                                     (let* [(pos (player-spawnpoint player))
                                            (point (blockpos->vec3 pos))]
                                            (teleport player point 0)
                                            (outp-success))))

(reg-simple-command "spawn"
                    "Teleport to world spawnpoint"
                    0
                    (checked-player! player
                                     (let* [(pos (world-spawnpoint))
                                            (point (blockpos->vec3 pos))]
                                            (teleport player point 0)
                                            (outp-success))))

(reg-command "tpa"
             "Send a teleport request to other player"
             0
             (list (command-vtable (list (parameter-selector "target" #t))
                                   (checked-player! self
                                                    (let [(targets (car (command-args)))]
                                                          (if (not (eq? (length targets) 1))
                                                              (outp-error "Must have 1 player selected")
                                                              (let [(target (car targets))]
                                                                    (send-form target
                                                                               (scm->json-string `((title   . "Teleport request")
                                                                                                   (type    . "modal")
                                                                                                   (content . ,(format #f "From ~a" (actor-name self)))
                                                                                                   (button1 . "Accept")
                                                                                                   (button2 . "Reject")))
                                                                             #%(if (json-string->scm %)
                                                                                   (let* [(pos (actor-pos target))
                                                                                          (dim (actor-dim target))]
                                                                                          (f32vector-set! pos 1 (- (f32vector-ref pos 1) 1.5))
                                                                                          (teleport self pos dim)
                                                                                          (send-message self "Teleported."))
                                                                                   (send-message self "Request rejected.")))
                                                                    (outp-success "Request sent."))))))))

(reg-command "tpahere"
             "Send a teleport here request to other player"
             0
             (list (command-vtable (list (parameter-selector "target" #t))
                                   (checked-player! self
                                                    (let [(targets (car (command-args)))]
                                                          (if (not (eq? (length targets) 1))
                                                              (outp-error "Must have 1 player selected")
                                                              (let [(target (car targets))]
                                                                    (send-form target
                                                                               (scm->json-string `((title   . "Teleport here request")
                                                                                                   (type    . "modal")
                                                                                                   (content . ,(format #f "To ~a" (actor-name self)))
                                                                                                   (button1 . "Accept")
                                                                                                   (button2 . "Reject")))
                                                                             #%(if (json-string->scm %)
                                                                                   (let* [(pos (actor-pos self))
                                                                                          (dim (actor-dim self))]
                                                                                          (f32vector-set! pos 1 (- (f32vector-ref pos 1) 1.5))
                                                                                          (teleport target pos dim)
                                                                                          (send-message target "Teleported."))
                                                                                   (send-message self "Request rejected.")))
                                                                    (outp-success "Request sent."))))))))

(reg-command "transfer"
             "Transfer player to another server"
             1
             (list (command-vtable (list (parameter-selector "target" #t) (parameter-string "address") (parameter-int "port"))
                                 #%(match (command-args)
                                          (((player) address port) (player-transfer player address port) (outp-success))
                                          (_                       (outp-error "Must have 1 player selected"))))))

(reg-simple-command "test"
                    "Test form"
                    0
                    (checked-player! player
                                     (send-form player
                                                (scm->json-string '((title   . "test")
                                                                    (type    . "modal")
                                                                    (content . "test")
                                                                    (button1 . "ok")
                                                                    (button2 . "cancel")))
                                              #%(log-debug "result" "form: ~a" (json-string->scm %)))
                                     (outp-success)))

(reg-simple-command "ping"
                    "Get network stats"
                    0
                    (checked-player! player (outp-success (format #f "~a" (player-stats player)))))

(let [(server (spawn-coop-repl-server))]
      (interval-run! 1 (poll-coop-repl-server server)))