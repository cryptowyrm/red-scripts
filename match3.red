Red [
    Title: "Match 3"
    Needs: 'View
    Author: "CryptoWyrm"
    License: "MIT"
    Version: 0.1.0
]

; TODO: Seed random generator
; TODO: After reset, when blocks in first row get destroyed, error msg and no new blocks created

; Game parameters
ROWS: 10
COLS: 10
GEM-SIZE: 50
SPEED: 5
REUSE-GEMS: true
; ---------------

; gems clicked on by user, when both are set tiles are swapped
origin: none
target: none

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
            change at gems ((position/y * COLS + position/x + COLS) + 1) self

            ; create new gem
            either position/y = 0 [
                either REUSE-GEMS [
                    change at gems (position/x + 1) (random-gem/falling/reuse position/x 0)
                ] [
                    change at gems (position/x + 1) (random-gem/falling position/x 0)
                ]
            ] [
                change at gems ((position/y * COLS + position/x) + 1) none
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
gems-buffer: copy []

random-gem: func [x y /falling /reuse /local new-gem] [
    either reuse and (0 < length? gems-buffer) [
        new-gem: take gems-buffer
        new-gem/color: first random [red green blue yellow pink]
        new-gem/position: as-pair x y
        new-gem/falling?: either falling [true] [false]
        new-gem/offset: either falling [GEM-SIZE] [0]
        new-gem/destroyed?: false
        return new-gem
    ] [
        make gem [
            color: first random [red green blue yellow pink]
            position: as-pair x y
            falling?: either falling [true] [false]
            offset: either falling [GEM-SIZE] [0]
        ]
    ]
]

reset-board: func [] [
    gems: copy []

    repeat i (ROWS * COLS) [
        y: i - 1  / COLS
        x: mod i - 1 COLS
        append gems random-gem x y
    ]

    return draw-board
]

board: copy []

draw-board: func [] [
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

    unless none? origin [
        append board compose [
            fill-pen white
            circle (origin * GEM-SIZE + (GEM-SIZE / 2)) 20
        ]
    ]

    return board
]

mark-matches: func [gems [block!] /local marked] [
    marked: copy []

    foreach gem gems [
        either (none? gem) [
            if (length? marked) >= 3 [
                foreach mark marked [
                    mark/destroy
                ]
            ]
            marked: copy []
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
                marked: copy []
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

process-gems: func [/local falling? down gem found] [
    ; -- makes blocks fall and destroys blocks with 3 or more connections

    ; Two passes:
    ; 1) call /fall function of any gem that has an empty space below
    ; 2) if no blocks did fall, call /destroy on any gem that connects to three or more of same color
    ;   -- Go through every row, appending the current color to a block if it's empty or has the same color
    ;       as other gems in block. If it's different color or end of row reached, check length of block, if 3 or more, call /destroy
    ;       on all gems in block and add new blocks at the top, then empty block and add the gem
    ;   -- Do the same for every column

    ; call animate on all gems

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
                    either REUSE-GEMS [
                        change gems (random-gem/falling/reuse gem/position/x gem/position/y)
                    ] [
                        change gems (random-gem/falling gem/position/x gem/position/y)
                    ]
                ] [
                    if REUSE-GEMS [
                        append gems-buffer first gems
                    ]
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
                ; swap origin gem with target gem
                ; TODO: check if valid move
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

view [
    title "Match 3"
    group-box "Game" board

    below
    group-box "Score" [score-label: text "0"]
    group-box "Controls" [
        button "Restart" [
            board-view/draw: reset-board
        ]
    ]
    base 0x0 rate 30 on-time [process-gems]

    do [
        board-view/draw: reset-board
    ]
]