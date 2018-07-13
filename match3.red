Red [
    Title: "Match 3"
    Needs: 'View
    Author: "CryptoWyrm"
    License: "MIT"
    Version: 0.1.0
]

; Game parameters
ROWS: 8
COLS: 8
GEM-SIZE: 60
SPEED: 150
FPS: 60
PAUSE: false
USE-IMAGES: true
; ---------------

; gems clicked on by user, when both are set tiles are swapped
origin: none
target: none

RETICLE-SIZE: 8.0
SCORE: 0
falling?: false
fps-count: 0
fps-time: now/time/precise
seconds-left: 180
last-second: now/time/precise
delta-time: now/time/precise
game-over: false
font-face: make face! [font: make font! [size: 48 color: white]]

; gem images
images: make object! [
    red: load %assets/red.png
    green: load %assets/green.png
    blue: load %assets/blue.png
    purple: load %assets/purple.png
    yellow: load %assets/yellow.png
]

random/seed now/time ; use now/time instead of now due to bug in Red 0.6.3

fall: func [gem] [
    unless gem/falling? [
        gem/falling?: true
        gem/offset: GEM-SIZE
        change at gems (to-index gem/position) + COLS gem

        ; create new gem if falling from the very top
        change at gems to-index gem/position either gem/position/y = 0 [random-gem/falling gem/position/x 0][none]

        gem/position/y: gem/position/y + 1
    ]
]

destroy: func [gem] [
    gem/destroyed?: true
]

animate: func [gem delta] [
    if gem/falling? [
        either (gem/offset > 0) [
            gem/offset: gem/offset - (SPEED * to-float delta)
            if gem/offset < 0 [gem/offset: 0]
        ] [
            gem/falling?: false
        ]
    ]
]

gem: make object! [
    color: red
    position: 0x0
    offset: 0
    falling?: false
    destroyed?: false
]

gems: copy []

random-gem: func [
    {Creates a new gem with a random color.}
    x [integer!]
    y [integer!]
    /falling "Gem should be in falling state"
][
    make gem [
        color: first random [red green blue yellow purple]
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
        pos
        fontpos1
        fontpos2
        pos-y
][
    clear board

    foreach gem gems [
        if any [none? gem gem/destroyed?] [continue]
        y: gem/position/y
        x: gem/position/x

        pos-y: GEM-SIZE * y - to-integer gem/offset

        either USE-IMAGES [
            append board compose [
                image (select images gem/color) (as-pair GEM-SIZE * x pos-y) ((as-pair GEM-SIZE * x pos-y) + GEM-SIZE)
            ]
        ][
            append board compose [
                line-width 3
                fill-pen (gem/color)
                box (as-pair GEM-SIZE * x pos-y) ((as-pair GEM-SIZE * x pos-y) + GEM-SIZE)
            ]
        ]
    ]

    ; Draw a white circle on selected gem, green on possible targets
    unless none? origin [
        append board compose [
            fill-pen white
            circle (origin * GEM-SIZE + (GEM-SIZE / 2)) 15
            fill-pen green
        ]

        foreach pos reduce [origin + 1x0 origin - 1x0 origin + 0x1 origin - 0x1] [
            append board compose [
                circle (pos * GEM-SIZE + (GEM-SIZE / 2)) (to-integer RETICLE-SIZE)
            ]
        ]
    ]

    ; Draw game over screen
    if game-over [
        fontpos1: size-text/with font-face "GAME OVER"
        fontpos2: size-text/with font-face append copy "Score: " score
        append board compose [
            fill-pen 0.0.0.125
            box 0x0 (board-view/size)
            font (font-face/font)
            text (as-pair board-view/size/x - fontpos1/x / 2 board-view/size/y - fontpos1/y / 2 - 50) "GAME OVER"
            pen white
            line-width 5
            line (as-pair board-view/size/x / 2 - 200 board-view/size/y / 2) (as-pair board-view/size/x / 2 + 200 board-view/size/y / 2)
            text (as-pair board-view/size/x - fontpos2/x / 2 board-view/size/y - fontpos2/y / 2 + 50) (append copy "Score: " score)
        ]
    ]

    return board
]

marked: copy []

mark-matches: func [
    {Given a block! of gems, it checks for connections and marks the gems
    that are to be destroyed. Returns number of gems marked.}
    gems [block!]
    /local
        gem
        mark
        count
][
    clear marked
    count: 0

    foreach gem gems [
        either any [
            (empty? marked)
            ((select (first marked) 'color) = gem/color)
        ] [
            append marked gem
        ] [
            if (length? marked) >= 3 [
                foreach mark marked [
                    destroy mark
                    count: count + 1
                ]
            ]
            clear marked
            append marked gem
        ]
    ]
    if (length? marked) >= 3 [
        foreach mark marked [
            destroy mark
            count: count + 1
        ]
    ]
    return count
]

check-matches: function [
    {Check the game board for matches and mark gems.
    Returns number of marked gems.}
][
    count: 0

    ; check horizontally for matches
    repeat row ROWS [
        count: count + mark-matches copy/part at gems (row - 1 * COLS + 1) COLS
    ]

    ; check vertically for matches
    repeat col COLS [
        count: count + mark-matches extract at gems col COLS
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
        not ((block-pos > 0) and (block-pos <= (ROWS * COLS)))
    ]

    return find valid-targets target
]

add-score: func [count [integer!]][
    SCORE: SCORE + case [
        count >= 6 [count * 40]
        count = 5 [count * 20]
        count = 4 [count * 10]
        count = 3 [count * 5]
        true [0]
    ]
    if count > 2 [score-label/data: SCORE]
]

process-gems: func [
    {The game loop. Animates gems and destroys those with 3 or more connections.}
    /local
        down
        gem
        found
        i
        row
        col
        destroyed
        delta
][
    delta: now/time/precise - delta-time
    delta-time: now/time/precise

    ; calculate FPS
    either now/time/precise - fps-time >= 0:0:1 [
        fps-label/data: fps-count
        fps-count: 0
        fps-time: now/time/precise
    ][
        fps-count: fps-count + 1
    ]

    ; display time
    if (not game-over) and (now/time/precise - last-second >= 0:0:1) [
        seconds-left: seconds-left - 1
        seconds-label/data: seconds-left
        last-second: now/time/precise

        if seconds-left = 0 [
            game-over: true
        ]
    ]

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
                    fall gem
                    falling?: true
                ]
            ]
        ]
        found = 0
    ]
    
    unless falling? [check-matches]

    ; change destroyed gems to none (or new gem if at y 0)
    destroyed: 0
    while [not tail? gems] [
        gem: first gems

        unless (none? gem) [
            if gem/destroyed? [
                destroyed: destroyed + 1
                change gems either gem/position/y = 0 [random-gem/falling gem/position/x gem/position/y][none]
            ]
        ]

        gems: next gems
    ]
    gems: head gems
    add-score destroyed

    ; animate gems
    foreach gem gems [
        if none? gem [continue]
        animate gem delta
    ]

    ; animate target reticles
    RETICLE-SIZE: either RETICLE-SIZE >= 12 [8.0][RETICLE-SIZE + 0.25]

    ; swap origin gem with target gem if both set and move is valid
    if all [not falling? origin target validate-move origin target] [
        swap-gems origin target

        either check-matches > 0 [
            origin: none
            target: none
        ][
            ; Invalid move, didn't result in a match
            swap-gems origin target
            target: none
        ]
    ]

    ; paint updated board
    board-view/draw: draw-board
]

swap-gems: function [
    {Swap two gems with each other, given their positions.}
    origin [pair!]
    target [pair!]
][
    origin-pos: to-index origin
    target-pos: to-index target
    origin-gem: gems/:origin-pos
    target-gem: gems/:target-pos

    origin-gem/position: target
    target-gem/position: origin

    change at gems origin-pos target-gem
    change at gems target-pos origin-gem
]

board: compose [
    board-view: base (as-pair COLS * GEM-SIZE ROWS * GEM-SIZE) 50.50.50 on-up [
        coords: event/offset / GEM-SIZE

        either none? origin [
            origin: coords
        ] [
            either coords = origin [
                origin: none
            ] [
                unless falling? [
                    target: coords
                ]
            ]
        ]
    ]
]

view [
    title "Match 3"
    group-box "Game" board

    below
    group-box "FPS" [fps-label: text "0"]
    group-box "Time left" [seconds-label: text "0"]
    group-box "Score" [score-label: text "0"]
    group-box "Controls" [
        button "Restart" [
            board-view/draw: reset-board
            seconds-left: 180
            last-second: now/time/precise
            game-over: false
            seconds-label/data: 180
            score: 0
            score-label/data: 0
            origin: none
            target: none
        ]
        button "Pause" [
            PAUSE: not PAUSE
            delta-time: now/time/precise
        ]
    ]
    base 0x0 rate FPS on-time [unless any [PAUSE game-over] [process-gems]]

    do [
        board-view/draw: reset-board
    ]
]