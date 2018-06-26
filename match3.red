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

    fall: function [] [
        unless falling? [
            falling?: true
            offset: 50
            print [position "moves to" (position + 0x1)]
            change at gems ((position/y * 10 + position/x + 10) + 1) self

            ; create new gem
            either position/y = 0 [
                change at gems ((position/y * 10 + position/x) + 1) (random-gem/falling position/x 0)
            ] [
                change at gems ((position/y * 10 + position/x) + 1) none
            ]

            position/y: position/y + 1
        ]
    ]

    destroy: function [] [
        destroyed?: true
    ]

    animate: function [] [
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

random-gem: func [x y /falling] [
    make gem [
        color: first random [red green blue yellow pink]
        position: as-pair x y
        falling?: either falling [true] [false]
        offset: either falling [50] [0]
    ]
]

reset-board: func [] [
    gems: copy []

    repeat i 100 [
        y: i - 1  / 10
        x: mod i - 1 10
        append gems random-gem x y
    ]

    return draw-board
]

draw-board: func [/local board] [
    board: copy []

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
            circle (origin * 50 + (GEM-SIZE / 2)) 20
        ]
    ]

    return board
]

mark-matches: func [gems [block!]] [
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
        repeat i 90 [
            gem: gems/:i
            if none? gem [continue]
            down: first at gems (i + 10)
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
        repeat row 10 [
            mark-matches copy/part at gems (row - 1 * 10 + 1) 10
        ]
    ]

    ; check vertically for matches
    unless falling? [
        repeat col 10 [
            mark-matches extract at gems col 10
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

    ; paint updated board
    board-view/draw: draw-board
]

board: compose [
    board-view: base (as-pair ROWS * GEM-SIZE COLS * GEM-SIZE) black on-up [
        probe event/offset

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
                origin-pos: origin/y * 10 + origin/x + 1
                target-pos: target/y * 10 + target/x + 1
                origin-gem: gems/:origin-pos
                target-gem: gems/:target-pos
                print "ORIGIN"
                probe origin-gem
                print "TARGET"
                probe target-gem

                origin-gem/position: target
                target-gem/position: origin

                change at gems origin-pos target-gem
                change at gems target-pos origin-gem

                origin: none
                target: none
            ]
        ]
        
        print origin
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