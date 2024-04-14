# rankings.rb
- i left my TBA api key is in the file for convenience, better if you go get your own (it's free) 

### Usage
- `ruby rankings.rb 2024cabe`
  - shows stats for 2024cabe teams and how they did in 2024cabe matches
- `ruby rankings.rb 2024hop prev`
  - shows stats for 2024hop teams and how each did in their latest event matches
- `ruby rankings.rb 2024cur`
  - shows stats for how teams are doing in Curie Division (no data yet)
- `ruby rankings.rb 2024cafr prev`
  - technically possible to see how the teams of SFR did in their last completed event

1. **Estimated Points Share** 
   - Penalty points are removed
   - This is mostly aligned with OPR, but much better at dealing with fewer matches played.
   - This is mostly aligned with EPA in terms of results.
2. **EPS vs Week Comp** - This looks at your EPS and subtracts out the FRC averarge EPS for that week.  Ths is to better account for teams that did not play a late season event.  This isn't perfect though as week 6 saw many Championships that artificially raised this average by a lot.
3. **Total Notes** - auto + teleop notes
4. **Auto Notes**
5. **Teleop Notes**
6. **Amplified Note Ratio** - number of amplified speaker notes / (amp notes + unamplified speaker notes)
   - a measure of how efficient the team scores
   - ideally this is 2 max (never score unamped speaker, and score 4 amped speaker for every 2 amp), however, due to estimations, some teams can get a ratio of over 2 here.
   - low ratio means the robot likely has a hgher ceiling after some tactical adjustments
7. **Estimated Penalty Points Share** - Same algorithm but looking at how many foul points the opposing alliance received. So if a team got a "6.4", it means that on average, they gave up 6.4 points worth of penalties to the other alliance.
   - Note: The Blue Alliance insights tab has foul points, but it's based on what your own alliance received for points which is meaningless.
8. **Endgame Stats - climb** - gives full endgame stats, ordered by climbs/match (exact counts, not estimates)
9. **Endgame Stats - trap** - gives full endgame stats, ordered by traps/climb (exact counts, not estimates)
10. **Match Num Pieces Forecast** - looks a schedule and estimates the total notes count.
   - once Hopper schedule is released, you can do "ruby rankings.rb 2024hop prev"
   - you can also try "ruby rankings.rb 2024cabe"
   - this might be useful info in determining if we want to ask for coopertition
<details> 
  <summary>example</summary>
  <pre>
2024cabe_qm10:   	 13 	- 12     	(7419 8852 5430) - (8045 199 4159)
2024cabe_qm11:   	 14 	- 32     	(4255 751 6418) - (2288 5419 6619)
2024cabe_qm12:   	 10 	- 15     	(9470 9519 6814) - (766 1160 5985)
2024cabe_qm13:   	 15 	- 34     	(6238 972 7401) - (254 1700 5940)
2024cabe_qm14:   	 24 	- 25     	(7667 7840 1678) - (3482 841 114)
2024cabe_qm15:   	 13 	- 5     	(7729 6884 9038) - (4186 2204 4973)
2024cabe_qm16:   	 10 	- 25     	(9202 6059 9111) - (5274 4698 649)
2024cabe_qm17:   	 16 	- 11     	(8159 2637 8852) - (7419 9545 9634)
2024cabe_qm18:   	 14 	- 14     	(4904 8793 199) - (4669 4990 3045)
2024cabe_qm19:   	 7 	- 21     	(7137 5430 8045) - (7245 9609 581)
  </pre>
</details>
11. **Match Score Forecast** - similar to what statbotics does (except they use epa)

### Other ideas
1. Can easily do shares of Auto/Teleop/Endgame points, but won't be too different from what statbotics/epa has already
2. Can see where on the stage people climbed, but this doesn't seem useful
3. Can see who can get the 2-pt mobility in auto, but not sure that's too useful
4. A lot more complicated, but based on the calculated Point Share, we can go back to the match data again and see how the other alliance did compared to their expected.. this might give us Defense Efficiency

### Available data from TBA match api
```
    {"adjustPoints"=>0,
     "autoAmpNoteCount"=>0,
     "autoAmpNotePoints"=>0,
     "autoLeavePoints"=>4,
     "autoLineRobot1"=>"No",
     "autoLineRobot2"=>"Yes",
     "autoLineRobot3"=>"Yes",
     "autoPoints"=>34,
     "autoSpeakerNoteCount"=>6,
     "autoSpeakerNotePoints"=>30,
     "autoTotalNotePoints"=>30,
     "coopNotePlayed"=>false,
     "coopertitionBonusAchieved"=>false,
     "coopertitionCriteriaMet"=>false,
     "endGameHarmonyPoints"=>0,
     "endGameNoteInTrapPoints"=>5,
     "endGameOnStagePoints"=>3,
     "endGameParkPoints"=>2,
     "endGameRobot1"=>"Parked",
     "endGameRobot2"=>"Parked",
     "endGameRobot3"=>"StageRight",
     "endGameSpotLightBonusPoints"=>1,
     "endGameTotalStagePoints"=>11,
     "ensembleBonusAchieved"=>false,
     "ensembleBonusOnStageRobotsThreshold"=>2,
     "ensembleBonusStagePointsThreshold"=>10,
     "foulCount"=>0,
     "foulPoints"=>0,
     "g206Penalty"=>false,
     "g408Penalty"=>false,
     "g424Penalty"=>false,
     "melodyBonusAchieved"=>false,
     "melodyBonusThreshold"=>18,
     "melodyBonusThresholdCoop"=>15,
     "melodyBonusThresholdNonCoop"=>18,
     "micCenterStage"=>false,
     "micStageLeft"=>false,
     "micStageRight"=>true,
     "rp"=>0,
     "techFoulCount"=>1,
     "teleopAmpNoteCount"=>8,
     "teleopAmpNotePoints"=>8,
     "teleopPoints"=>68,
     "teleopSpeakerNoteAmplifiedCount"=>9,
     "teleopSpeakerNoteAmplifiedPoints"=>45,
     "teleopSpeakerNoteCount"=>2,
     "teleopSpeakerNotePoints"=>4,
     "teleopTotalNotePoints"=>57,
     "totalPoints"=>102,
     "trapCenterStage"=>false,
     "trapStageLeft"=>false,
     "trapStageRight"=>true}},
```

<details> 
  <summary>Algorithm Explanation</summary>

We run multiple iterations to distribute points among teams based on their performance in matches. Here's a breakdown of how the algorithm processes the data:

#### Match Data:
- **Match 1:** 90 points - Team1, Team2, Team3
- **Match 2:** 70 points - Team4, Team5, Team6
- **Match 3:** 80 points - Team1, Team5, Team6
- **Match 4:** ...

#### Iterations:

##### First Iteration:
- **Team1, Team2, Team3** all receive equal shares of the 90 points from Match 1, which is 30 each.
- **Team4, Team5, Team6** all receive equal shares of the 70 points from Match 2, which is about 23.33 each.

Assuming at the end of this iteration, the points are as follows:
- **Team1:** 35 points
- **Team2:** 30 points
- **Team3:** 20 points

##### Second Iteration:
- **Team1** receives \(35/(35+30+20)\) of the 90 points from Match 1.
- **Team2** receives \(30/(35+30+20)\) of the 90 points.
- **Team3** receives \(20/(35+30+20)\) of the 90 points.

##### Third Iteration:
- **Team1** receives \(34/(34+31+21)\) of the 90 points from Match 1.
- **Team2** receives \(31/(34+31+21)\) of the 90 points.
- **Team3** receives \(21/(34+31+21)\) of the 90 points.

#### Stabilization:
We iterate this process 50 times. After multiple iterations, the percentage shares of points among the teams will stabilize.
</details>

# scout.rb
not maintained, has 2023 stuff (probably won't work for 2024)
but this looked at all events and did global rankings and stuff.

# schedule.rb
can ignore.. was an attempt at coming up with better schedules for quals, but didn't get very far

# rankings_old.rb
- old version where you just cut&paste results from thebluealliance event page (before i found out about TBA api). 
- this script finds Estimated Point Share.
- similar to OPR/EPA, but definitely better than OPR (for fewer match data)


