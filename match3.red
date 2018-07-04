Red [
    Title: "Match 3"
    Needs: 'View
    Author: "CryptoWyrm"
    License: "MIT"
    Version: 0.1.0
]

; Game parameters
ROWS: 10
COLS: 10
GEM-SIZE: 50
SPEED: 5
PAUSE: false
; ---------------

; gems clicked on by user, when both are set tiles are swapped
origin: none
target: none

RETICLE-SIZE: 8.0

random/seed now/time ; use now/time instead of now due to bug in Red 0.6.3

gem: make object! [
    color: red
    position: 0x0
    offset: 0
    falling?: false
    destroyed?: false

    fall: func [] [
        unless falling? [
            falling?: true
            offset: GEM-SIZE
            change at gems ((to-index position) + COLS) self

            ; create new gem
            either position/y = 0 [
                change at gems (to-index position) (random-gem/falling position/x 0)
            ] [
                change at gems (to-index position) none
            ]

            position/y: position/y + 1
        ]
    ]

    destroy: func [] [
        destroyed?: true
    ]

    animate: func [] [
        if falling? [
            either (offset > 0) [
                offset: offset - SPEED
            ] [
                falling?: false
            ]
        ]
    ]
]

gems: copy []

random-gem: func [
    {Creates a new gem with a random color.}
    x [integer!]
    y [integer!]
    /falling "Gem should be in falling state"
][
    make gem [
        color: first random [red green blue yellow pink]
        position: as-pair x y
        falling?: either falling [true] [false]
        offset: either falling [GEM-SIZE] [0]
    ]
]

reset-board: func [
    {Fills the game board with randomly created gems and returns the new
    DRAW block.}
    /local
        i
][
    clear gems

    repeat i (ROWS * COLS) [
        y: i - 1  / COLS
        x: mod i - 1 COLS
        append gems random-gem x y
    ]

    return draw-board
]

board: copy []

draw-board: func [
    "Draws the game board and returns it as a DRAW block."
    /local
        gem
][
    clear board

    foreach gem gems [
        if none? gem [continue]
        y: gem/position/y
        x: gem/position/x

        pos-y: (GEM-SIZE * y) - gem/offset

        if gem/destroyed? [continue]

        append board compose [
            line-width 3
            fill-pen (gem/color)
            box (as-pair GEM-SIZE * x pos-y) ((as-pair GEM-SIZE * x pos-y) + GEM-SIZE)
        ]
    ]

    ; Draw a white circle on selected gem, green on possible targets
    unless none? origin [
        append board compose [
            fill-pen white
            circle (origin * GEM-SIZE + (GEM-SIZE / 2)) 15
            fill-pen green
            circle (origin + 1x0 * GEM-SIZE + (GEM-SIZE / 2)) (to-integer RETICLE-SIZE)
            circle (origin - 1x0 * GEM-SIZE + (GEM-SIZE / 2)) (to-integer RETICLE-SIZE)
            circle (origin + 0x1 * GEM-SIZE + (GEM-SIZE / 2)) (to-integer RETICLE-SIZE)
            circle (origin - 0x1 * GEM-SIZE + (GEM-SIZE / 2)) (to-integer RETICLE-SIZE)
        ]
    ]

    return board
]

marked: copy []

mark-matches: func [
    {Given a block! of gems, it checks for connections and marks the gems
    that are to be destroyed.}
    gems [block!]
    /local
        gem
        mark
][
    clear marked

    foreach gem gems [
        either (none? gem) [
            if (length? marked) >= 3 [
                foreach mark marked [
                    mark/destroy
                ]
            ]
            clear marked
        ] [
            either any [
                (empty? marked)
                ((select (first marked) 'color) = gem/color)
            ] [
                append marked gem
            ] [
                if (length? marked) >= 3 [
                    foreach mark marked [
                        mark/destroy
                    ]
                ]
                clear marked
                append marked gem
            ]
        ]
    ]
    if (length? marked) >= 3 [
        foreach mark marked [
            mark/destroy
        ]
    ]
]

to-index: func [
    {Converts a pair! position to a block! index.}
    position [pair!]
][
    position/y * COLS + position/x + 1
]

validate-move: func [
    {Checks if target position is valid move for gem at origin.}
    origin [pair!]
    target [pair!]
    /local
        valid-targets
        block-pos
        position
][
    valid-targets: reduce [
        origin + 1x0
        origin + 0x1
        origin - 1x0
        origin - 0x1
    ]

    remove-each position valid-targets [
        block-pos: to-index position
        not ((block-pos > 0) and (block-pos < (ROWS * COLS)))
    ]

    return find valid-targets target
]

process-gems: func [
    {The game loop. Animates gems and destroys those with 3 or more connections.}
    /local
        falling?
        down
        gem
        found
        i
        row
        col
][
    ; check if any gem is falling, if so skip to animate
    falling?: false
    foreach gem gems [
        if none? gem [continue]
        if gem/falling? [
            falling?: true
            break
        ]
    ]

    ; check if gems need to fall
    until [
        found: 0
        repeat i (ROWS * COLS - COLS) [
            gem: gems/:i
            if none? gem [continue]
            down: first at gems (i + COLS)
            if (none? down) [
                unless gem/falling? [
                    found: found + 1
                    gem/fall
                    falling?: true
                ]
            ]
        ]
        found = 0
    ]
    
    ; check horizontally for matches
    unless falling? [
        repeat row ROWS [
            mark-matches copy/part at gems (row - 1 * COLS + 1) COLS
        ]
    ]

    ; check vertically for matches
    unless falling? [
        repeat col COLS [
            mark-matches extract at gems col COLS
        ]
    ]

    ; change destroyed gems to none (or new gem if at y 0)
    while [not tail? gems] [
        gem: first gems

        unless (none? gem) [
            if gem/destroyed? [
                either gem/position/y = 0 [
                    change gems (random-gem/falling gem/position/x gem/position/y)
                ] [
                    change gems none
                ]
            ]
        ]

        gems: next gems
    ]
    gems: head gems

    ; animate gems
    foreach gem gems [
        if none? gem [continue]
        gem/animate
    ]

    ; animate target reticles
    either (RETICLE-SIZE >= 12) [
        RETICLE-SIZE: 8.0
    ] [
        RETICLE-SIZE: RETICLE-SIZE + 0.5
    ]

    ; paint updated board
    board-view/draw: draw-board
]

board: compose [
    board-view: base (as-pair COLS * GEM-SIZE ROWS * GEM-SIZE) black on-up [
        coords: event/offset / GEM-SIZE

        either none? origin [
            origin: coords
        ] [
            either coords = origin [
                origin: none
            ] [
                target: coords

                ; swap origin gem with target gem if move is valid
                if (validate-move origin target) [
                    origin-pos: origin/y * COLS + origin/x + 1
                    target-pos: target/y * COLS + target/x + 1
                    origin-gem: gems/:origin-pos
                    target-gem: gems/:target-pos

                    origin-gem/position: target
                    target-gem/position: origin

                    change at gems origin-pos target-gem
                    change at gems target-pos origin-gem

                    origin: none
                    target: none
                ]
            ]
        ]
    ]
]

view [
    title "Match 3"
    group-box "Game" board

    below
    group-box "Score" [score-label: text "0"]
    group-box "Controls" [
        button "Restart" [
            board-view/draw: reset-board
        ]
        button "Pause" [
            PAUSE: not PAUSE
        ]
    ]
    base 0x0 rate 30 on-time [unless PAUSE [process-gems]]

    do [
        board-view/draw: reset-board
    ]
]