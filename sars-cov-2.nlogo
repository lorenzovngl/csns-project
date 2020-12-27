;;; SARS-CoV-2 pandemic in NetLogo
;;;
;;; Author: Lorenzo Vainigli
;;;         lorenzo.vainigli@studio.unibo.it
;;;         matr. 0000842756
;;;
;;; Based on a work of Uri Wilensky

breed [people person]
undirected-link-breed [contacts contact]

people-own [
  ; Every people, at each time, must belong to only one class
  susceptible?
  exposed?
  quarantined?
  infected?
  isolated?

  degree-centrality
]

contacts-own [
  contact-age
]

globals [
  days
  ticks-per-day
  avg-degree-centrality
  std-dev-degree-centrality
]

to reset
  set number-people 150

  set infection-rate 50
  set exposed-transmission-factor 50
  set exposed-to-infected-rate 50

  set quarantine-perfection-rate 50
  set quarantines-per-tick-rate 50
  set quarantined-to-isolated-rate 50

  set isolation-perfection-rate 50
  set isolations-per-tick-rate 50

  set infected-chance-recover 50
  set isolated-chance-recover 50

  set social-distance false
  set social-distance-perfection-rate 50
  set lockdown-strictness 0

  set contact-time 20
end

to setup
  clear-all

  set days 0
  set ticks-per-day 5

  setup-turtles
  update-display
  reset-ticks
end

to setup-turtles
  create-people number-people [
    setxy random-xcor random-ycor
    set susceptible? true
    set infected? false
    set exposed? false
    set isolated? false
    set quarantined? false
    set degree-centrality 0
    set size 1.5
    get-healthy
  ]

  ask n-of 10 people
    [ get-exposed ]
  ask n-of 2 people with [ exposed? ]
    [ get-infected ]
end

to go

  ; once-per-tick actions
  ask people [
    move
    infect
    update-contacts
  ]

  ; once-per-day actions
  if ticks mod ticks-per-day = 0 [
    ask people [
      ifelse exposed? [
        if random-float 100 < exposed-to-infected-rate [
          get-infected
        ]
      ] [
        ifelse infected? [
          if random-float 100 < infected-chance-recover [
            get-recovered
          ]
        ] [
          if isolated? [
            if random-float 100 < isolated-chance-recover [
              get-recovered
            ]
          ]
        ]
      ]

      quarantine-exposed
      isolate-infected
      isolate-quarantined

    ]

    ask contacts [
      set contact-age contact-age + 1
      if contact-age > contact-time [
        die
      ]
    ]

    update-metrics
    set days days + 1
  ]

  update-display
  tick
end

to get-exposed ;; turtle procedure
  if not susceptible? [
    show "Only susceptible people can become exposed"
    error -1
  ]
  set susceptible? false
  set exposed? true
end

to get-quarantined ;; turtle procedure
  if not exposed? [
    show "Only exposed people can become quarantined"
    error -1
  ]
  set exposed? false
  set quarantined? true
end

to get-infected ;; turtle procedure
  if not exposed? [
    show "Only exposed people can become infected"
    error -1
  ]
  set exposed? false
  set infected? true
end

to get-isolated ;; turtle procedure
  if not infected? and not quarantined? [
    show "Only infected and quarantined people can become isolated"
    error -1
  ]
  set quarantined? false
  set infected? false
  set isolated? true
end

to get-recovered ;; turtle procedure
  if not infected? and not isolated? [
    show "Only infected or isolated people can become recovered"
    error -1
  ]
  set infected? false
  set isolated? false
  set susceptible? true
end

to quarantine-exposed
  let max-quarantines-per-time count people with [exposed? and not quarantined? ] * quarantines-per-tick-rate / 100
  let counter 0
  ask people with [exposed? and not quarantined? ] [
    if counter < max-quarantines-per-time [
      set exposed? false
      set quarantined? true
      set counter counter + 1
    ]
  ]
end

to isolate-infected
  let max-isolate-per-time count people with [infected? and not isolated? ] * isolations-per-tick-rate / 100
  let counter 0
  ask people with [infected? and not isolated? ] [
    if counter < max-isolate-per-time [
      set infected? false
      set isolated? true
      set counter counter + 1
    ]
  ]
end

to isolate-quarantined
  let max-isolations-per-time count people with [ quarantined? and not isolated? ] * quarantined-to-isolated-rate / 100
  let counter 0
  ask people with [ quarantined? and not isolated? ] [
    if counter < max-isolations-per-time [
      set quarantined? false
      set isolated? true
      set counter counter + 1
    ]
  ]
end

to get-healthy ;; turtle procedure
  set infected? false
  set exposed? false
end

to update-metrics
  let sum-degree-centrality 0
  let sum-std-dev-degree-centrality 0
  ask people [
    set degree-centrality count my-links
    set sum-degree-centrality sum-degree-centrality + degree-centrality
  ]
  set avg-degree-centrality sum-degree-centrality / count people
  ask people [
    set sum-std-dev-degree-centrality sum-std-dev-degree-centrality + (degree-centrality - avg-degree-centrality) ^ 2
  ]
  set std-dev-degree-centrality sqrt (sum-std-dev-degree-centrality / count people)
end

to update-contacts
  create-contacts-with other people-here [
    set contact-age 0
  ]
end

to update-display
  let maxdc (max [degree-centrality] of people)
  ask people [
    if shape != turtle-shape [
      set shape turtle-shape
    ]
    set color ifelse-value (turtle-color = "class") [
      ifelse-value infected? [ red ] [
        ifelse-value exposed? [ orange ] [
          ifelse-value isolated? [ magenta ] [
            ifelse-value quarantined? [ blue ] [ green ]
          ]
        ]
      ]
    ] [
      ifelse-value (turtle-color = "health status") [
        ifelse-value infected? [ red ] [
          ifelse-value exposed? [ orange ][ green ]
        ]
      ] [
        ifelse-value (turtle-color = "mobility status") [
          ifelse-value isolated? [ magenta ] [
            ifelse-value quarantined? [ blue ] [ cyan ]
          ]
        ] [
          ifelse-value (degree-centrality > 0) [scale-color red degree-centrality 0 maxdc] [ gray ] ]
      ]
    ]
  ]
end

;; Turtles move about at random.
to move ;; turtle procedure
  rt random 100
  lt random 100

  if not quarantined? and not isolated? [
    if random-float 100 > lockdown-strictness [
      ifelse not social-distance [
        fd 1
      ] [
        let busy-patch false
        ask patch-ahead 1 [
          if count people-here > 0 [ set busy-patch true ]
        ]
        if not busy-patch or random-float 100 > social-distance-perfection-rate [
          fd 1
        ]
      ]
    ]
  ]
end

;; If a turtle is sick, it infects other turtles on the same patch.
;; Immune turtles don't get sick.
to infect ;; turtle procedure
  ifelse exposed? [
    ask other people-here with [ susceptible? ] [
      if random-float 100 <  infection-rate * exposed-transmission-factor [
        get-exposed
      ]
    ]
  ] [
    ifelse quarantined? [
      ask other people-here with [ susceptible? ] [
        if random-float 100 <  infection-rate * exposed-transmission-factor * (1 - quarantine-perfection-rate) [
          get-exposed
        ]
      ]
    ] [
      ifelse isolated? [
        ask other people-here with [ susceptible? ] [
          if random-float 100 <  infection-rate * (1 - isolation-perfection-rate) [
            get-exposed
          ]
        ]
      ] [
        ask other people-here with [ susceptible? ] [
          if random-float 100 < infection-rate [
            get-exposed
          ]
        ]
      ]
    ]
  ]
end

; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
280
10
946
509
-1
-1
14.0
1
10
1
1
1
0
1
1
1
-23
23
-17
17
1
1
1
ticks
30.0

SLIDER
65
365
260
398
infected-chance-recover
infected-chance-recover
0.0
100
50.0
1.0
1
%
HORIZONTAL

SLIDER
65
52
259
85
infection-rate
infection-rate
0.0
99.0
50.0
1.0
1
%
HORIZONTAL

BUTTON
355
515
425
550
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
505
515
576
551
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
0

PLOT
960
10
1410
320
Population
days
people
0.0
52.0
0.0
200.0
true
true
"" ""
PENS
"susceptible" 1.0 0 -10899396 true "" "plotxy days count people with [ susceptible? ]"
"exposed" 1.0 0 -955883 true "" "plotxy days count people with [ exposed? ]"
"quarantined" 1.0 0 -13345367 true "" "plotxy days count people with [ quarantined? ]"
"infected" 1.0 0 -2674135 true "" "plotxy days count people with [ infected? ]"
"isolated" 1.0 0 -5825686 true "" "plotxy days count people with [ isolated? ]"

SLIDER
65
10
259
43
number-people
number-people
10
300
150.0
1
1
NIL
HORIZONTAL

MONITOR
1210
325
1320
370
I - Infected (%)
(count people with [ infected? ] / count people) * 100
1
1
11

MONITOR
960
375
1072
420
Days
ticks / ticks-per-day
1
1
11

CHOOSER
730
515
822
560
turtle-shape
turtle-shape
"person" "circle"
0

BUTTON
280
515
350
550
NIL
reset
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
430
515
500
550
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
585
515
720
548
contact-time
contact-time
0
100
20.0
1
1
days
HORIZONTAL

PLOT
960
430
1255
560
Degree centrality
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
"Average" 1.0 0 -16777216 true "" "plotxy days avg-degree-centrality"
"Std. dev." 1.0 0 -7500403 true "" "plotxy days std-dev-degree-centrality"

MONITOR
1265
430
1415
475
Average degree centrality
avg-degree-centrality
1
1
11

MONITOR
1265
485
1415
530
Std. dev. of degree centrality
std-dev-degree-centrality
1
1
11

CHOOSER
830
515
945
560
turtle-color
turtle-color
"class" "health status" "mobility status" "degree centrality"
0

SWITCH
65
440
260
473
social-distance
social-distance
1
1
-1000

SLIDER
65
475
260
508
social-distance-perfection-rate
social-distance-perfection-rate
0
100
100.0
1
1
%
HORIZONTAL

SLIDER
65
165
260
198
quarantine-perfection-rate
quarantine-perfection-rate
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
65
285
260
318
isolation-perfection-rate
isolation-perfection-rate
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
80
70
111
ε
25
0.0
1

TEXTBOX
30
165
50
196
ε
25
0.0
1

TEXTBOX
30
280
65
311
ε
25
0.0
1

TEXTBOX
45
100
65
118
E
11
0.0
1

TEXTBOX
45
185
60
203
Q
11
0.0
1

TEXTBOX
45
300
60
318
J
11
0.0
1

MONITOR
960
325
1075
370
S - Susceptible (%)
(count people with [ not susceptible? ] / count people) * 100
1
1
11

MONITOR
1085
325
1200
370
E - Exposed (%)
(count people with [ exposed? ] / count people) * 100
1
1
11

MONITOR
1085
375
1200
420
Q - Quarantined (%)
(count people with [ quarantined? ] / count people) * 100
1
1
11

MONITOR
1210
375
1320
420
J - Isolated (%)
(count people with [ isolated? ] / count people) * 100
1
1
11

SLIDER
65
200
260
233
quarantines-per-tick-rate
quarantines-per-tick-rate
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
195
45
226
c
25
0.0
1

TEXTBOX
45
215
60
233
Q
11
0.0
1

SLIDER
65
320
260
353
isolations-per-tick-rate
isolations-per-tick-rate
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
315
55
346
c
25
0.0
1

TEXTBOX
45
335
60
353
J
11
0.0
1

SLIDER
65
399
260
432
isolated-chance-recover
isolated-chance-recover
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
364
45
395
b
25
0.0
1

TEXTBOX
45
389
60
407
I
11
0.0
1

TEXTBOX
30
399
45
430
b
25
0.0
1

TEXTBOX
45
419
60
437
J
11
0.0
1

TEXTBOX
30
50
45
81
a
25
0.0
1

SLIDER
65
85
260
118
exposed-transmission-factor
exposed-transmission-factor
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
65
120
260
153
exposed-to-infected-rate
exposed-to-infected-rate
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
115
55
146
k
25
0.0
1

TEXTBOX
45
135
60
153
E
11
0.0
1

SLIDER
65
235
260
268
quarantined-to-isolated-rate
quarantined-to-isolated-rate
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
30
230
45
261
k
25
0.0
1

TEXTBOX
45
250
60
268
Q
11
0.0
1

SLIDER
65
510
260
543
lockdown-strictness
lockdown-strictness
0
100
0.0
1
1
%
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model simulates the transmission and perpetuation of a virus in a human population.

Ecological biologists have suggested a number of factors which may influence the survival of a directly transmitted virus within a population. (Yorke, et al. "Seasonality and the requirements for perpetuation and eradication of viruses in populations." Journal of Epidemiology, volume 109, pages 103-123)

## HOW IT WORKS

The model is initialized with 150 people, of which 10 are infected.  People move randomly about the world in one of three states: healthy but susceptible to infection (green), sick and infectious (red), and healthy and immune (gray). People may die of infection or old age.  When the population dips below the environment's "carrying capacity" (set at 300 in this model) healthy people may produce healthy (but susceptible) offspring.

Some of these factors are summarized below with an explanation of how each one is treated in this model.

### The density of the population

Population density affects how often infected, immune and susceptible individuals come into contact with each other. You can change the size of the initial population through the NUMBER-PEOPLE slider.

### Population turnover

As individuals die, some who die will be infected, some will be susceptible and some will be immune.  All the new individuals who are born, replacing those who die, will be susceptible.  People may die from the virus, the chances of which are determined by the slider CHANCE-RECOVER, or they may die of old age.

In this model, people die of old age at the age of 50 years.  Reproduction rate is constant in this model.  Each turn, if the carrying capacity hasn't been reached, every healthy individual has a 1% chance to reproduce.

### Degree of immunity

If a person has been infected and recovered, how immune are they to the virus?  We often assume that immunity lasts a lifetime and is assured, but in some cases immunity wears off in time and immunity might not be absolutely secure.  In this model, immunity is secure, but it only lasts for a year.

### Infectiousness (or transmissibility)

How easily does the virus spread?  Some viruses with which we are familiar spread very easily.  Some viruses spread from the smallest contact every time.  Others (the HIV virus, which is responsible for AIDS, for example) require significant contact, perhaps many times, before the virus is transmitted.  In this model, infectiousness is determined by the INFECTIOUSNESS slider.

### Duration of infectiousness

How long is a person infected before they either recover or die?  This length of time is essentially the virus's window of opportunity for transmission to new hosts. In this model, duration of infectiousness is determined by the DURATION slider.

### Hard-coded parameters

Four important parameters of this model are set as constants in the code (See `setup-constants` procedure). They can be exposed as sliders if desired. The turtles’ lifespan is set to 50 years, the carrying capacity of the world is set to 300, the duration of immunity is set to 52 weeks, and the birth-rate is set to a 1 in 100 chance of reproducing per tick when the number of people is less than the carrying capacity.

## HOW TO USE IT

Each "tick" represents a week in the time scale of this model.

The INFECTIOUSNESS slider determines how great the chance is that virus transmission will occur when an infected person and susceptible person occupy the same patch.  For instance, when the slider is set to 50, the virus will spread roughly once every two chance encounters.

The DURATION slider determines the number of weeks before an infected person either dies or recovers.

The CHANCE-RECOVER slider controls the likelihood that an infection will end in recovery/immunity.  When this slider is set at zero, for instance, the infection is always deadly.

The SETUP button resets the graphics and plots and randomly distributes NUMBER-PEOPLE in the view. All but 10 of the people are set to be green susceptible people and 10 red infected people (of randomly distributed ages).  The GO button starts the simulation and the plotting function.

The TURTLE-SHAPE chooser controls whether the people are visualized as person shapes or as circles.

Three output monitors show the percent of the population that is infected, the percent that is immune, and the number of years that have passed.  The plot shows (in their respective colors) the number of susceptible, infected, and immune people.  It also shows the number of individuals in the total population in blue.

## THINGS TO NOTICE

The factors controlled by the three sliders interact to influence how likely the virus is to thrive in this population.  Notice that in all cases, these factors must create a balance in which an adequate number of potential hosts remain available to the virus and in which the virus can adequately access those hosts.

Often there will initially be an explosion of infection since no one in the population is immune.  This approximates the initial "outbreak" of a viral infection in a population, one that often has devastating consequences for the humans concerned. Soon, however, the virus becomes less common as the population dynamics change.  What ultimately happens to the virus is determined by the factors controlled by the sliders.

Notice that viruses that are too successful at first (infecting almost everyone) may not survive in the long term.  Since everyone infected generally dies or becomes immune as a result, the potential number of hosts is often limited.  The exception to the above is when the DURATION slider is set so high that population turnover (reproduction) can keep up and provide new hosts.

## THINGS TO TRY

Think about how different slider values might approximate the dynamics of real-life viruses.  The famous Ebola virus in central Africa has a very short duration, a very high infectiousness value, and an extremely low recovery rate. For all the fear this virus has raised, how successful is it?  Set the sliders appropriately and watch what happens.

The HIV virus, which causes AIDS, has an extremely long duration, an extremely low recovery rate, but an extremely low infectiousness value.  How does a virus with these slider values fare in this model?

## EXTENDING THE MODEL

Add additional sliders controlling the carrying capacity of the world (how many people can be in the world at one time), the average lifespan of the people and their birth-rate.

Build a similar model simulating viral infection of a non-human host with very different reproductive rates, lifespans, and population densities.

Add a slider controlling how long immunity lasts. You could also make immunity imperfect, so that immune turtles still have a small chance of getting infected. This chance could get higher over time.

## VISUALIZATION

The circle visualization of the model comes from guidelines presented in
Kornhauser, D., Wilensky, U., & Rand, W. (2009). http://ccl.northwestern.edu/papers/2009/Kornhauser,Wilensky&Rand_DesignGuidelinesABMViz.pdf.

At the lowest level, perceptual impediments arise when we exceed the limitations of our low-level visual system. Visual features that are difficult to distinguish can disable our pre-attentive processing capabilities. Pre-attentive processing can be hindered by other cognitive phenomena such as interference between visual features (Healey 2006).

The circle visualization in this model is supposed to make it easier to see when agents interact because overlap is easier to see between circles than between the "people" shapes. In the circle visualization, the circles merge to create new compound shapes. Thus, it is easier to perceive new compound shapes in the circle visualization.
Does the circle visualization make it easier for you to see what is happening?

## RELATED MODELS

* AIDS
* Virus on a Network

## CREDITS AND REFERENCES

This model can show an alternate visualization of the Virus model using circles to represent the people. It uses visualization techniques as recommended in the paper:

Kornhauser, D., Wilensky, U., & Rand, W. (2009). Design guidelines for agent based model visualization. Journal of Artificial Societies and Social Simulation, JASSS, 12(2), 1.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Virus model.  http://ccl.northwestern.edu/netlogo/models/Virus.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1998 2001 -->
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
1
@#$#@#$#@
