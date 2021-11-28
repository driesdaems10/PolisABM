;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                   DEFINITIONS                  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [communities community]

globals [
  population-sizes       ;;;; list of community sizes
]

patches-own [
  patch-affiliation      ;;;; variable used to affiliate patches with communities
]

communities-own [
  community-id           ;;;; unique identifier per community
  community-size         ;;;; population size
  scalar-stress          ;;;; level of scalar stress
  status                 ;;;; settlement status
  loyalty                ;;;; variable to allow the creation of hierarchies through incorporation of dependent settlements
  nearest-neighbour      ;;;; variable storing nearest neighbour for the distance-report procedure to find minimum distances between communities
  ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                   SETUP                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-patches
  setup-communities
  reset-ticks
end

to setup-patches
  ask patches[
    set patch-affiliation -1
    set pcolor 140
  ]
end

to setup-communities
  let r 1
  set population-sizes []
  create-communities communities-number [
    setxy random-xcor random-ycor
    set color random 140
    set shape "house"
    set community-size round random-normal face-to-face (face-to-face / 5)   ;;;; population based on number drawn from normal distribution (mean and sd) determined by slider on interface for size of face-to-face communities
    set size round sqrt (community-size / 5) ;;;; set settlement size in visualization proportional to population
    ask patches in-radius buffer-zone with [patch-affiliation = -1] [     ;;;; assign patches within buffer zone to this community
      set patch-affiliation [community-id] of myself
     ]
    set community-id r      ;;;; give each community unique identifier
    set r r + 1   ;;;; add number for each new community
    set scalar-stress 0
    set status "hamlet"
    set loyalty 0
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                   GO                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
;  distance-report
;  energized-crowding
  fission-fusion
;  central-place
  reproduce
  update-viz
  tick
  if ticks = time-limit [
    ask communities [set population-sizes lput community-size population-sizes]   ;;;; add community sizes of still existing sites to the population size list
    file-open "site-size.txt"
    file-write population-sizes
    file-close
    stop
  ]
end

to energized-crowding
  ;;;; if population size increases, scalar stress threshold is reached --> either fission occurs or innovation-potential needs to be used for polis formation
end

to fission-fusion
  ask communities [
    if (community-size >= village-threshold) [     ;;;; fission can be initiated once population reaches threshold --> TO DO: switch to scalar stress from energized-crowding
    if random-float 1.0 < fission-probability [    ;;;; probability of fission event
        ;;;; select one patch in area beyond own territory that is not yet affiliated with another community
        ;let new-home one-of patches in-radius (buffer-zone * 2) with [patch-affiliation = -1]
        let potential-home patches with [patch-affiliation = -1]   ;;;; pick a location for new settlement that is not yet affiliated with other site
        let new-home one-of potential-home with [not any? communities in-radius buffer-zone] ;;;; and has no other sites within buffer zone distance
        ;let new-home one-of patches with [(patch-affiliation = -1) AND not any? communities in-radius buffer-zone]
          ifelse new-home != nobody [     ;;;; fission only possible if space if available, otherwise only fusion is possible
          let population-move round (community-size / 2)    ;;;; half the population is to move away
          hatch 1 [
            set color random 140
            set shape "house"
            move-to new-home
            let id-number max [community-id] of communities + 1 ;;;; give each community unique identifier counting up from the last ID assigned in setup
            set community-id id-number
            set scalar-stress 0
            set loyalty 0
            set community-size population-move
            set size round sqrt (community-size / 5)   ;;;; set settlement size in visualization proportional to population
            ifelse community-size > face-to-face
              [set status "village"]
              [set status "hamlet"]
            ask patches in-radius buffer-zone with [patch-affiliation = -1] [
              set patch-affiliation [community-id] of myself
             ]
            ]
           ]
          [
      let potential-fusion one-of nearby-communities with [community-size < [community-size] of myself]  ;;;; pick one of nearby settlements that is smaller to attempt fusion
       ifelse potential-fusion != nobody [
          let added-population [community-size] of potential-fusion
          set community-size community-size + added-population   ;;;; update community size
          set size round sqrt (community-size / 5)  ;;;; set settlement size in visualization proportional to population
          if community-size > polis-threshold [
             set status "polis"
             ]
          ask patches with [patch-affiliation = [community-id] of potential-fusion] [
             set patch-affiliation [community-id] of myself
             ]
       ask potential-fusion [
           set population-sizes lput community-size population-sizes
           ask patches with [patch-affiliation = [community-id] of myself] [set patch-affiliation -1]  ;;;; reset patch-affiliation
           die        ;;;; fused partner abanoned
          ]
       ]
       [
        ask patches with [patch-affiliation = [community-id] of myself] [set patch-affiliation -1]  ;;;; reset patch-affiliation
        set population-sizes lput community-size population-sizes
        die   ;;;; if no suitable fusion partner is found the settlement collapses --> to be updated!
        ]
      ]
      ]
      ]
    ]
end

to reproduce  ;;;; population growth depending on population size of each community, population growth percentage and carrying capacity set by sliders on interface
  ask communities [
    let new-population round ((pop-growth * community-size) * (1 - (community-size / carrying-capacity)))  ;;;; population growth --> DN = rN (1 - N/K)
    set community-size community-size + new-population   ;;;; update community size
    set size round sqrt (community-size / 5) ;;;; update settlement size in visualization proportional to community size
  ]
end

to central-place
  ;;;; TO DO: something with polis threshold --> limit growth or expansion through fusion/conquest? + use loyalty variable
end

to update-viz ;;;; visualize territories of communities if toggled on
  if territory-viz = true [
    ask communities [ask patches with [patch-affiliation = [community-id] of myself] [
        set pcolor ([color + 1] of myself)] ;;;; color patches based on the colour of community, but with slight difference for visuals
    ]
    ask patches with [patch-affiliation = -1] [set pcolor 140]
    ]
end

to distance-report ;;;; procedure to check whether all communities are positioned properly outside of buffer-zone, not necessary outside of testing times
  ask communities [
    set nearest-neighbour min-one-of other communities [distance myself]
    let distance-communities 0
    if nearest-neighbour != nobody [
    set distance-communities distance nearest-neighbour
    show distance-communities
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 REPORTERS                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; reporter used in creation of community affiliation for patches and persons based on nearest community
to-report nearest-community
  report min-n-of 5 communities [distance myself]   ;;;; look for 5 closest communities
end

to-report nearby-communities
  report communities in-radius (buffer-zone * 2)
end
@#$#@#$#@
GRAPHICS-WINDOW
176
11
647
483
-1
-1
2.3035
1
10
1
1
1
0
0
0
1
-100
100
-100
100
1
1
1
ticks
30.0

BUTTON
3
88
92
121
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
92
88
173
121
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
155
175
188
communities-number
communities-number
1
30
1.0
1
1
NIL
HORIZONTAL

SLIDER
3
188
175
221
face-to-face
face-to-face
1
200
150.0
1
1
NIL
HORIZONTAL

SLIDER
3
221
175
254
village-threshold
village-threshold
200
600
500.0
1
1
NIL
HORIZONTAL

SLIDER
3
317
175
350
pop-growth
pop-growth
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
3
415
175
448
innovation-rate
innovation-rate
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
3
122
175
155
time-limit
time-limit
1
1000
500.0
1
1
NIL
HORIZONTAL

PLOT
646
10
846
160
Number communities
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count communities"

SLIDER
3
382
175
415
fission-probability
fission-probability
0
1
0.2
0.05
1
NIL
HORIZONTAL

SLIDER
3
254
175
287
polis-threshold
polis-threshold
600
1500
1000.0
1
1
NIL
HORIZONTAL

PLOT
646
159
846
309
Community types
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Villages" 1.0 0 -16777216 true "" "plot count communities with [status = \"village\"]"
"Poleis" 1.0 0 -1184463 true "" "plot count communities with [status = \"polis\"]"

SLIDER
3
349
175
382
buffer-zone
buffer-zone
0
50
30.0
1
1
NIL
HORIZONTAL

SWITCH
3
10
174
43
territory-viz
territory-viz
0
1
-1000

MONITOR
846
56
943
101
Villages
count communities with [status = \"village\"]
0
1
11

MONITOR
943
55
1045
100
Poleis
count communities with [status = \"polis\"]
17
1
11

PLOT
647
310
847
460
Total population
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [community-size] of communities"

CHOOSER
3
43
175
88
scaling-exponent
scaling-exponent
0.83 1 1.17
1

MONITOR
844
10
943
55
Largest community
max [community-size] of communities
0
1
11

SLIDER
3
285
175
318
carrying-capacity
carrying-capacity
0
10000
5000.0
1
1
NIL
HORIZONTAL

PLOT
846
100
1046
250
Largest community
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot max [community-size] of communities"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Submission-experiment" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count communities</metric>
    <metric>count communities with [status = "village"]</metric>
    <metric>count communities with [status = "polis"]</metric>
    <enumeratedValueSet variable="innovation-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="communities-number">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone-polis">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-size">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polis-threshold">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone-village">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fission-probability">
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-growth">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-limit">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="village-threshold">
      <value value="200"/>
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fusion-probability">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="interaction-mode">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="CAA-basic-results" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>population-sizes</metric>
    <enumeratedValueSet variable="interaction-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="innovation-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="communities-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polis-threshold">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fission-probability">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-growth">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scaling-exponent">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-limit">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="village-threshold">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="face-to-face">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-viz">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="CAA-basic-500-ticks" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>population-sizes</metric>
    <enumeratedValueSet variable="interaction-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="innovation-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="communities-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polis-threshold">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fission-probability">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-growth">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scaling-exponent">
      <value value="1.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-limit">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="village-threshold">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="face-to-face">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-viz">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="CAA-carrying-capacity" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>population-sizes</metric>
    <enumeratedValueSet variable="interaction-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="innovation-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="communities-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="3000"/>
      <value value="5000"/>
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polis-threshold">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fission-probability">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-growth">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scaling-exponent">
      <value value="1.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-limit">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="village-threshold">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="face-to-face">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-viz">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="CAA-fission" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>population-sizes</metric>
    <enumeratedValueSet variable="interaction-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-zone">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="innovation-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="communities-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying-capacity">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polis-threshold">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fission-probability">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-growth">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scaling-exponent">
      <value value="1.17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-limit">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="village-threshold">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="face-to-face">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-viz">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
