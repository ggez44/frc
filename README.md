## scout.rb
not maintained, has 2023 stuff (probably won't work for 2024)
but this looked at all events and did global rankings and stuff.

## schedule.rb
can ignore.. was an attempt at coming up with better schedules for quals, but didn't get very far

## rankings_old.rb
old version where you can just cut&paste results from thebluealliance event page, and it'll find the Estimated Point Share.

### Algorithm Explanation:

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


## rankings.rb
- updated version that uses TBA's api instead, and uses the same algorithm as the \_old version
- i left my TBA api key is in the file, better if you go get your own (it's free), 

### Usage
- `ruby rankings.rb 2024cabe`
  - shows stats for 2024cabe teams and how they did in 2024cabe matches
- `ruby rankings.rb 2024hop prev`
  - shows stats for 2024hop teams and how each did in their latest event

### Notes
This version has 3 options..

1. **Points Share** - This is able to subtract out penalty points to be more accurate.
   - This is mostly aligned with OPR, but much better at dealing with fewer matches played.
   - This is mostly aligned with EPA in terms of results.
2. **Foul Points Contributed** - Same algorithm but looking at how many foul points the opposing alliance received. So if a team got a "6.4", it means that on average, they gave up 6.4 points worth of penalties to the other alliance.
   - Note: The Blue Alliance insights tab has foul points, but it's based on what your own alliance received for points which is meaningless.
3. **Climb Percentage** - The TBA API gives us who climbed, so this is not an approximation, but rather an exact percentage of how often a team successfully climbed. This ignores "park".

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
